part of 'core.dart';

/// What to refetch after [QueryClient.invalidateQueries].
enum RefetchType { active, inactive, all, none }

@immutable
class DefaultOptions {
  const DefaultOptions({
    this.queries = const QueryDefaults(),
    this.mutations = const MutationDefaults(),
  });

  final QueryDefaults queries;
  final MutationDefaults mutations;
}

/// Owns the query and mutation caches and is the main way to read, write, and
/// invalidate cached data.
///
/// Call [mount] to refetch on focus and reconnect, and [unmount] when the
/// client is no longer used.
class QueryClient {
  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    this.defaultOptions = const DefaultOptions(),
  })  : queryCache = queryCache ?? QueryCache(),
        mutationCache = mutationCache ?? MutationCache();

  final QueryCache queryCache;
  final MutationCache mutationCache;
  DefaultOptions defaultOptions;
  final Map<String, (QueryKey, QueryDefaults)> _queryDefaults = {};
  final Map<String, (MutationKey, MutationDefaults)> _mutationDefaults = {};
  int _mountCount = 0;
  void Function()? _unsubscribeFocus;
  void Function()? _unsubscribeOnline;

  /// Starts refetching on focus and reconnect, and resuming paused mutations.
  void mount() {
    _mountCount++;
    if (_mountCount != 1) return;

    _unsubscribeFocus = focusManager.subscribe((focused) async {
      if (focused) {
        await resumePausedMutations();
        queryCache.onFocus();
      }
    });
    _unsubscribeOnline = onlineManager.subscribe((online) async {
      if (online) {
        await resumePausedMutations();
        queryCache.onOnline();
      }
    });
  }

  void unmount() {
    _mountCount--;
    if (_mountCount != 0) return;

    _unsubscribeFocus?.call();
    _unsubscribeFocus = null;
    _unsubscribeOnline?.call();
    _unsubscribeOnline = null;
  }

  /// Number of matching queries that are fetching.
  int isFetching({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
  }) {
    return queryCache
        .findAll(QueryFilters(
          queryKey: queryKey,
          exact: exact,
          type: type,
          stale: stale,
          fetchStatus: FetchStatus.fetching,
          predicate: predicate,
        ))
        .length;
  }

  /// Number of matching mutations that are pending.
  int isMutating({
    MutationKey? mutationKey,
    bool exact = false,
    bool Function(AnyMutation mutation)? predicate,
  }) {
    return mutationCache
        .findAll(MutationFilters(
          mutationKey: mutationKey,
          exact: exact,
          status: MutationStatus.pending,
          predicate: predicate,
        ))
        .length;
  }

  /// Watches a value computed from the client, such as a count or cached
  /// data.
  ///
  /// Each listener first receives `selector(client)`, then a new value
  /// whenever a query or mutation changes and the value is different. Lists,
  /// maps, and sets are compared by content, other values with `==`. Watching
  /// doesn't fetch anything.
  ///
  /// ```dart
  /// client.watch((client) => client.isFetching() > 0);
  /// client.watch((client) => client.isMutating(mutationKey: ['todos']));
  /// client.watch((client) => client.getQueryData<List<Todo>>(['todos']));
  /// ```
  Stream<T> watch<T>(T Function(QueryClient client) selector) {
    return Stream.multi(
      (controller) {
        var hasValue = false;
        late T value;
        var scheduled = false;

        void update() {
          scheduled = false;
          final T next;
          try {
            next = selector(this);
          } catch (error, stackTrace) {
            controller.addError(error, stackTrace);
            return;
          }
          if (hasValue) {
            final shared = replaceData(value, next, structuralSharing: true);
            if (identical(shared, value)) return;
            value = shared;
          } else {
            value = next;
            hasValue = true;
          }
          controller.add(value);
        }

        // Many changes can arrive in one batch; compute once after it.
        void onChange(Object _) {
          if (scheduled) return;
          scheduled = true;
          notifyManager.schedule(update);
        }

        final unsubscribeQueries = queryCache.subscribe(onChange);
        final unsubscribeMutations = mutationCache.subscribe(onChange);
        update();
        controller.onCancel = () {
          unsubscribeQueries();
          unsubscribeMutations();
        };
      },
      isBroadcast: true,
    );
  }

  /// The cached data for [queryKey], or `null`.
  TData? getQueryData<TData extends Object>(QueryKey queryKey) {
    return queryCache.get(hashKey(queryKey))?.state.data as TData?;
  }

  /// The cached state for [queryKey], or `null`.
  QueryState<Object>? getQueryState(QueryKey queryKey) {
    return queryCache.get(hashKey(queryKey))?.state;
  }

  /// Key and data of every matching query.
  List<(QueryKey, TData?)> getQueriesData<TData extends Object>({
    QueryKey? queryKey,
    bool exact = false,
    bool Function(Query<Object> query)? predicate,
  }) {
    return queryCache
        .findAll(QueryFilters(
          queryKey: queryKey,
          exact: exact,
          predicate: predicate,
        ))
        .map((query) => (query.queryKey, query.state.data as TData?))
        .toList();
  }

  /// Writes [data] to the cache for [queryKey], creating the query if needed.
  ///
  /// Use the same [TData] as the query that reads this key.
  TData setQueryData<TData extends Object>(
    QueryKey queryKey,
    TData data, {
    int? updatedAt,
  }) {
    final query = queryCache.build<TData>(
      this,
      QueryOptions<TData>(queryKey: queryKey),
    );
    return query._setData(data, updatedAt: updatedAt, manual: true);
  }

  /// Updates the cached data for [queryKey] from its current value. Returning
  /// `null` from [updater] leaves the cache unchanged.
  TData? updateQueryData<TData extends Object>(
    QueryKey queryKey,
    TData? Function(TData? previous) updater, {
    int? updatedAt,
  }) {
    final data = updater(getQueryData<TData>(queryKey));
    if (data == null) return null;
    return setQueryData<TData>(queryKey, data, updatedAt: updatedAt);
  }

  /// Returns the cached data if it is fresh, otherwise fetches it. Throws if
  /// the fetch fails. Does not retry unless `retry` is set.
  ///
  /// ```dart
  /// final todos = await client.query(todosOptions);
  ///
  /// // Prefetch: ignore the result and errors.
  /// client.query(todosOptions).ignore();
  ///
  /// // Use cached data whenever there is some.
  /// final cached = await client.query(QueryOptions(
  ///   queryKey: ['todos'],
  ///   queryFn: (_) => api.getTodos(),
  ///   staleTime: staticStaleTime,
  /// ));
  /// ```
  Future<TData> query<TData extends Object>(QueryOptions<TData> options) async {
    var defaulted = defaultQueryOptions(options);
    if (defaulted.retry == null) {
      defaulted = defaulted._withRetry(const RetryPolicy.never());
    }

    final query = queryCache.build<TData>(this, defaulted);
    if (query.isStaleByTime(defaulted.staleTime)) {
      return query.fetch(defaulted);
    }
    return query.state.data!;
  }

  /// Like [query], for infinite queries. Fetches `pages` pages when there is
  /// no cached data.
  Future<InfiniteData<TPage, TParam>> infiniteQuery<TPage, TParam>(
    InfiniteQueryOptions<TPage, TParam> options,
  ) {
    return query(options);
  }

  /// Removes matching queries from the cache.
  void removeQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
  }) {
    final filters = QueryFilters(
      queryKey: queryKey,
      exact: exact,
      type: type,
      stale: stale,
      predicate: predicate,
    );
    notifyManager.batch(() {
      for (final query in queryCache.findAll(filters)) {
        queryCache.remove(query);
      }
    });
  }

  /// Resets matching queries to their initial state and refetches the active
  /// ones.
  Future<void> resetQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    final filters = QueryFilters(
      queryKey: queryKey,
      exact: exact,
      type: type,
      stale: stale,
      predicate: predicate,
    );

    return notifyManager.batch(() {
      final matched = queryCache.findAll(filters).toSet();
      for (final query in matched) {
        query.reset();
      }
      return _refetch(
        QueryFilters(
          type: QueryTypeFilter.active,
          predicate: matched.contains,
        ),
        cancelRefetch: cancelRefetch,
        throwOnError: throwOnError,
      );
    });
  }

  /// Cancels fetches of matching queries. By default their state reverts to
  /// what it was before the fetch.
  Future<void> cancelQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
    bool revert = true,
    bool silent = false,
  }) async {
    final filters = QueryFilters(
      queryKey: queryKey,
      exact: exact,
      type: type,
      stale: stale,
      predicate: predicate,
    );
    final futures = notifyManager.batch(() {
      return queryCache
          .findAll(filters)
          .map((query) => query.cancel(revert: revert, silent: silent))
          .toList();
    });
    await Future.wait(futures);
  }

  /// Marks matching queries as stale and refetches the active ones.
  ///
  /// Set [refetchType] to choose which matching queries refetch, or
  /// [RefetchType.none] to only mark them stale.
  Future<void> invalidateQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter? type,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
    RefetchType? refetchType,
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    final filters = QueryFilters(
      queryKey: queryKey,
      exact: exact,
      type: type ?? QueryTypeFilter.all,
      stale: stale,
      predicate: predicate,
    );

    return notifyManager.batch(() {
      for (final query in queryCache.findAll(filters)) {
        query.invalidate();
      }

      if (refetchType == RefetchType.none) return Future.value();

      final refetchFilter = switch (refetchType) {
        RefetchType.all => QueryTypeFilter.all,
        RefetchType.inactive => QueryTypeFilter.inactive,
        RefetchType.active => QueryTypeFilter.active,
        RefetchType.none || null => type ?? QueryTypeFilter.active,
      };

      return _refetch(
        filters._copyWith(type: refetchFilter),
        cancelRefetch: cancelRefetch,
        throwOnError: throwOnError,
      );
    });
  }

  /// Refetches matching queries that are neither disabled nor static.
  Future<void> refetchQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(Query<Object> query)? predicate,
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _refetch(
      QueryFilters(
        queryKey: queryKey,
        exact: exact,
        type: type,
        stale: stale,
        predicate: predicate,
      ),
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
  }

  Future<void> _refetch(
    QueryFilters filters, {
    required bool cancelRefetch,
    required bool throwOnError,
  }) async {
    final fetchOptions = FetchOptions(cancelRefetch: cancelRefetch);
    final futures = notifyManager.batch(() {
      return queryCache
          .findAll(filters)
          .where((query) => !query.isDisabled() && !query.isStatic())
          .map((query) {
        var future = query.fetch(null, fetchOptions).then<void>((_) {});
        if (!throwOnError) {
          future = future.then<void>((_) {}, onError: (Object _) {});
        }
        // A paused fetch may never finish; don't wait for it.
        if (query.state.fetchStatus == FetchStatus.paused) {
          future.ignore();
          return Future<void>.value();
        }
        return future;
      }).toList();
    });
    await Future.wait(futures);
  }

  /// Resumes mutations that were paused while offline.
  Future<void> resumePausedMutations() {
    if (onlineManager.isOnline()) return mutationCache.resumePausedMutations();
    return Future.value();
  }

  /// Sets defaults for every query whose key starts with [queryKey].
  void setQueryDefaults(QueryKey queryKey, QueryDefaults defaults) {
    _queryDefaults[hashKey(queryKey)] = (queryKey, defaults);
  }

  QueryDefaults getQueryDefaults(QueryKey queryKey) {
    var result = const QueryDefaults();
    for (final (key, defaults) in _queryDefaults.values) {
      if (partialMatchKey(queryKey, key)) result = result.merge(defaults);
    }
    return result;
  }

  /// Sets defaults for every mutation whose key starts with [mutationKey].
  void setMutationDefaults(MutationKey mutationKey, MutationDefaults defaults) {
    _mutationDefaults[hashKey(mutationKey)] = (mutationKey, defaults);
  }

  MutationDefaults getMutationDefaults(MutationKey mutationKey) {
    var result = const MutationDefaults();
    for (final (key, defaults) in _mutationDefaults.values) {
      if (partialMatchKey(mutationKey, key)) result = result.merge(defaults);
    }
    return result;
  }

  /// Fills unset values in [options] with client and per-key defaults.
  QueryOptions<TData> defaultQueryOptions<TData extends Object>(
    QueryOptions<TData> options,
  ) {
    if (options._defaulted) return options;
    final defaults = defaultOptions.queries.merge(
      getQueryDefaults(options.queryKey),
    );
    return options._withDefaults(defaults);
  }

  MutationOptions<TData, TVariables, TContext>
      defaultMutationOptions<TData, TVariables, TContext>(
    MutationOptions<TData, TVariables, TContext> options,
  ) {
    if (options._defaulted) return options;
    final mutationKey = options.mutationKey;
    final defaults = defaultOptions.mutations.merge(
      mutationKey == null ? null : getMutationDefaults(mutationKey),
    );
    return options._withDefaults(defaults);
  }

  /// Removes every query and mutation.
  void clear() {
    queryCache.clear();
    mutationCache.clear();
  }
}
