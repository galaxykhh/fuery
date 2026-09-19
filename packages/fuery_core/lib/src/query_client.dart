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
/// A mounted client refetches on focus and reconnect. Assigning [Fuery.client]
/// and `FueryProvider` mount their clients; call [mount] and [unmount]
/// yourself for other clients.
class QueryClient {
  QueryClient({
    QueryCache? queryCache,
    MutationCache? mutationCache,
    this.defaultOptions = const DefaultOptions(),
    this.storage,
    this.persistMaxAge = const Duration(days: 1),
  })  : queryCache = queryCache ?? QueryCache(),
        mutationCache = mutationCache ?? MutationCache();

  final QueryCache queryCache;
  final MutationCache mutationCache;
  DefaultOptions defaultOptions;

  /// Where queries with a [QueryPersist] store their data. Without a storage,
  /// `persist` options do nothing.
  final QueryStorage? storage;

  /// How long persisted data can be restored, unless [QueryPersist.maxAge]
  /// says otherwise.
  final Duration persistMaxAge;

  /// Entries read by [restore], by query hash, until a query uses them.
  Map<String, String>? _preloaded;

  /// Asynchronous deletions in flight. Reads wait for them, so deleted data
  /// is never restored.
  final Set<Future<void>> _deletions = {};

  /// Changes whenever persisted data is deleted, so a [restore] that was
  /// reading at the time drops what it read.
  int _deletionEpoch = 0;
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
        queryCache._onFocus();
      }
    });
    _unsubscribeOnline = onlineManager.subscribe((online) async {
      if (online) {
        await resumePausedMutations();
        queryCache._onOnline();
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

  /// Reads every persisted query ahead of time, so queries created afterwards
  /// restore their data right away, even with a storage that reads
  /// asynchronously. Optional: without it, each query restores when it's
  /// first used.
  ///
  /// ```dart
  /// await Fuery.client.restore();
  /// runApp(const App());
  /// ```
  Future<void> restore() async {
    final storage = this.storage;
    if (storage == null) return;
    await _deletionsDone();
    final epoch = _deletionEpoch;
    final Map<String, String> entries;
    try {
      entries = await storage.readAll();
    } catch (_) {
      return; // A failing storage is treated as empty.
    }
    // Something was deleted while reading; queries read on their own instead.
    if (epoch != _deletionEpoch) return;
    _preloaded = {
      for (final MapEntry(:key, :value) in entries.entries)
        if (key.startsWith(persistKeyPrefix))
          key.substring(persistKeyPrefix.length): value,
    };
    notifyManager.batch(() {
      for (final query in queryCache.getAll()) {
        query._restoreFromPreload();
      }
    });
  }

  String? _takePreloaded(String queryHash) => _preloaded?.remove(queryHash);

  void _deleteStored(String storageKey) {
    final storage = this.storage;
    if (storage != null) _trackDeletion(() => storage.delete(storageKey));
  }

  /// Runs [delete], and tracks it until done if it is asynchronous.
  void _trackDeletion(FutureOr<void> Function() delete) {
    _deletionEpoch++;
    final FutureOr<void> result;
    try {
      result = delete();
    } catch (_) {
      return; // A failing storage is ignored.
    }
    if (result is Future<void>) {
      late final Future<void> tracked;
      tracked = result
          .catchError((Object _) {})
          .whenComplete(() => _deletions.remove(tracked));
      _deletions.add(tracked);
    }
  }

  /// Completes when the deletions in flight are done, or returns null when
  /// there are none.
  Future<void>? _deletionsDone() {
    if (_deletions.isEmpty) return null;
    return Future.wait(_deletions.toList());
  }

  /// Deletes the persisted data of [queries]. When [filters] only select by
  /// key, persisted queries that aren't loaded are deleted as well.
  void _forgetStored(QueryFilters filters, Iterable<Query<Object>> queries) {
    final storage = this.storage;
    if (storage == null) return;

    for (final query in queries) {
      _preloaded?.remove(query.queryHash);
      _deleteStored(query._storageKey);
    }

    final byKeyOnly = filters.type == QueryTypeFilter.all &&
        filters.stale == null &&
        filters.fetchStatus == null &&
        filters.predicate == null;
    if (!byKeyOnly) return;

    // Queries loaded now were handled above, and may get new data before an
    // asynchronous storage lists its entries.
    final loaded = {for (final query in queryCache.getAll()) query.queryHash};

    bool matches(String queryHash) {
      if (loaded.contains(queryHash)) return false;
      final queryKey = filters.queryKey;
      if (queryKey == null) return true;
      if (filters.exact) return queryHash == hashKey(queryKey);
      return partialMatchKey(jsonDecode(queryHash) as List<Object?>, queryKey);
    }

    _preloaded?.removeWhere((queryHash, _) => matches(queryHash));
    _trackDeletion(() {
      // Reads synchronously when the storage does, so a query created right
      // after this call can't see the deleted entries.
      FutureOr<void> deleteMatching(Map<String, String> entries) {
        final deletions = [
          for (final key in entries.keys)
            if (key.startsWith(persistKeyPrefix) &&
                matches(key.substring(persistKeyPrefix.length)))
              Future<void>.sync(() => storage.delete(key)),
        ];
        return Future.wait(deletions).then((_) {}, onError: (Object _) {});
      }

      final entries = storage.readAll();
      if (entries is Future<Map<String, String>>) {
        return entries.then(deleteMatching);
      }
      deleteMatching(entries);
    });
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
            // The next value is emitted even if it equals the one before.
            hasValue = false;
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
        void onChange() {
          if (scheduled) return;
          scheduled = true;
          notifyManager.schedule(update);
        }

        final unsubscribeQueries = queryCache._subscribe(onChange);
        final unsubscribeMutations = mutationCache._subscribe(onChange);
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
    final query = queryCache._build<TData>(
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

    final query = queryCache._build<TData>(this, defaulted);
    if (query.isStaleByTime(defaulted.staleTime)) {
      return query._fetch(defaulted);
    }
    return query.state.data!;
  }

  /// Like [query], for infinite queries. With nothing cached it loads the
  /// `pages` passed to [infiniteQueryOptions] (default: one); otherwise it
  /// reloads the pages already cached.
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
      final queries = queryCache.findAll(filters);
      for (final query in queries) {
        queryCache._remove(query);
      }
      _forgetStored(filters, queries);
      _moveObservers(queries);
    });
  }

  /// Moves observers still subscribed to [removed] queries to new ones, which
  /// load again. Runs after stored data is deleted, so the new queries don't
  /// restore it.
  void _moveObservers(Iterable<Query<Object>> removed) {
    for (final query in removed) {
      for (final observer in query._observers.toList()) {
        observer._onQueryRemoved();
      }
    }
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
        query._reset();
      }
      _forgetStored(filters, matched);
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
          .map((query) => query._cancel(revert: revert, silent: silent))
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
        query._invalidate();
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
    final fetchOptions = _FetchOptions(cancelRefetch: cancelRefetch);
    final futures = notifyManager.batch(() {
      return queryCache
          .findAll(filters)
          // A static query is only skipped while it has data.
          .where((query) =>
              !query.isDisabled() &&
              !(query.isStatic() && query.state.data != null))
          .map((query) {
        var future = query._refetch(fetchOptions).then<void>((_) {});
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
    if (onlineManager.isOnline()) return mutationCache._resumePausedMutations();
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

  /// Removes every query and mutation, and deletes all persisted data.
  void clear() {
    notifyManager.batch(() {
      final queries = queryCache.getAll();
      queryCache._clear();
      mutationCache._clear();
      _forgetStored(const QueryFilters(), const []);
      _moveObservers(queries);
    });
  }
}
