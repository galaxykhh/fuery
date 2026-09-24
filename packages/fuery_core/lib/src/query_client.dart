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
    this.onUncaughtError,
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

  /// Receives the errors no caller can: errors thrown by the callbacks of a
  /// [QueryCacheConfig] or a [MutateOptions], or by `onError` and
  /// `onSettled` of a mutation that failed, and mistakes Fuery finds while
  /// running, such as a page param of the wrong type or a mutation key that
  /// can't be stored. The query or mutation goes on as if the callback
  /// hadn't thrown. A mistake is reported once per client.
  ///
  /// Without it, these errors go to the current zone, which in Flutter
  /// reports them to `PlatformDispatcher.onError`.
  final void Function(Object error, StackTrace stackTrace)? onUncaughtError;

  /// What [_reportOnce] reported, by its key.
  final Set<String> _reported = {};

  /// Entries read by [restore], by query hash, until a query uses them.
  Map<String, Map<String, Object?>>? _preloaded;

  /// Asynchronous deletions in flight. Reads wait for them, so deleted data
  /// is never restored.
  final Set<Future<void>> _deletions = {};

  /// Changes whenever persisted data is deleted, so a [restore] that was
  /// reading at the time reads again.
  int _deletionEpoch = 0;

  /// Storage keys of the stored mutations this client is running, started
  /// here or loaded by [restore], so a restore doesn't run them again.
  final Set<String> _loadedMutationKeys = {};
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
        queryCache._resumePausedLoads();
        await resumePausedMutations();
        queryCache._onFocus();
      }
    });
    _unsubscribeOnline = onlineManager.subscribe((online) async {
      if (online) {
        queryCache._resumePausedLoads();
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
    bool Function(CachedQuery<Object> query)? predicate,
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
    bool Function(AnyCachedMutation mutation)? predicate,
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
  /// asynchronously. Optional for queries: without it, each query restores
  /// when it's first used.
  ///
  /// Stored mutations only come back this way. Pass the options of every
  /// mutation with a `persist`, and each stored run of them is started again
  /// with its stored variables: right away while online, or when the network
  /// is back.
  ///
  /// ```dart
  /// await Fuery.client.restore(mutations: [addCommentMutation()]);
  /// runApp(const App());
  /// ```
  Future<void> restore({
    List<AnyMutation> mutations = const [],
  }) async {
    final storage = this.storage;
    if (storage == null) return;
    // Without a snapshot, queries read on their own, and stored mutations
    // stay for the next restore.
    final entries = await _readAllStored(storage);
    if (entries == null) return;
    final preloaded = <String, Map<String, Object?>>{};
    final loaded = {
      for (final query in queryCache.getAll()) query._storageHash
    };
    for (final MapEntry(:key, :value) in entries.entries) {
      if (!key.startsWith(persistKeyPrefix) ||
          key.startsWith(_mutationKeyPrefix)) {
        continue;
      }
      final storedHash = key.substring(persistKeyPrefix.length);
      final entry = _decodeEntry(value);
      // A loaded query may be writing newer data, and decides for itself.
      if (!loaded.contains(storedHash) &&
          (entry == null || _isExpired(entry))) {
        // It would never be restored, so it isn't kept either.
        _deleteStored(key);
      } else if (entry != null) {
        preloaded[storedHash] = entry;
      }
    }
    _preloaded = preloaded;
    notifyManager.batch(() {
      for (final query in queryCache.getAll()) {
        query._restoreFromPreload();
      }
      _restoreMutations(entries, mutations);
    });
  }

  /// Reads every stored entry, or returns null when the storage fails or
  /// something is deleted during every read.
  Future<Map<String, String>?> _readAllStored(QueryStorage storage) async {
    // A deletion during the read may have removed entries it returned, so
    // read again once deletions are done.
    for (var attempt = 0; attempt < 3; attempt++) {
      await _deletionsDone();
      final epoch = _deletionEpoch;
      final Map<String, String> entries;
      try {
        entries = await storage.readAll();
      } catch (_) {
        return null; // A failing storage is treated as empty.
      }
      if (epoch == _deletionEpoch) return entries;
    }
    return null;
  }

  /// Starts the stored mutations in [entries] that have options in
  /// [mutations], oldest first. Entries that can't be read, or were stored
  /// by another version of their options, are deleted.
  void _restoreMutations(
    Map<String, String> entries,
    List<AnyMutation> mutations,
  ) {
    final stored =
        <(int submittedAt, String key, Map<String, Object?> entry)>[];
    for (final MapEntry(:key, :value) in entries.entries) {
      if (!key.startsWith(_mutationKeyPrefix) ||
          _loadedMutationKeys.contains(key)) {
        continue;
      }
      try {
        final entry = jsonDecode(value) as Map<String, Object?>;
        stored.add((entry['t']! as int, key, entry));
      } catch (_) {
        _deleteStored(key); // Entries that can't be read are discarded.
      }
    }
    stored.sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
    });

    // Each definition by its stored key, hashed once. One that can't be
    // hashed is reported, matches no entry, and leaves the entries of the
    // others alone.
    final byKey = <String, AnyMutation?>{};
    final keysInMemory = <String, String>{};
    for (final options in mutations) {
      final mutationKey = options.mutationKey;
      if (mutationKey == null) continue;
      try {
        final stored = storageHash(mutationKey);
        final inMemory = hashKey(mutationKey);
        final first = keysInMemory.putIfAbsent(stored, () => inMemory);
        if (first == inMemory) {
          byKey.putIfAbsent(stored, () => options);
          continue;
        }
        // Stored keys leave out enum types, so a stored run of either key
        // could belong to the other. Neither is restored, and the runs stay.
        if (byKey[stored] != null) {
          _reportError(
            StateError(
              'The mutation keys $first and $inMemory differ only in enum '
              'types, which stored keys leave out, so neither is restored. '
              'Add a string to one of them that tells them apart.',
            ),
            StackTrace.current,
          );
        }
        byKey[stored] = null;
      } catch (error, stackTrace) {
        _reportOnce('mutationKey $mutationKey', error, stackTrace);
      }
    }

    for (final (submittedAt, key, entry) in stored) {
      try {
        final options = byKey[storageHash(entry['k']! as List<Object?>)];
        // An entry nothing was passed for is kept: the app may restore it
        // later, with the options it belongs to.
        if (options == null) continue;
        if (options.persist?.version != entry['v']) {
          _deleteStored(key);
          continue;
        }
        _loadedMutationKeys.add(key);
        options._restore(this, key, entry['d'], submittedAt);
      } catch (_) {
        // Variables that can't be decoded are discarded.
        _loadedMutationKeys.remove(key);
        _deleteStored(key);
      }
    }
  }

  /// Reports [error] to [onUncaughtError], or without it to the current
  /// zone. When [onUncaughtError] throws, both errors go to the zone.
  void _reportError(Object error, StackTrace stackTrace) {
    final onUncaughtError = this.onUncaughtError;
    if (onUncaughtError == null) {
      return Zone.current.handleUncaughtError(error, stackTrace);
    }
    try {
      onUncaughtError(error, stackTrace);
    } catch (reportError, reportStackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
      Zone.current.handleUncaughtError(reportError, reportStackTrace);
    }
  }

  /// Reports [error] like [_reportError], once per [key], for mistakes that
  /// would otherwise be reported every time the same code runs.
  void _reportOnce(String key, Object error, StackTrace stackTrace) {
    if (_reported.add(key)) _reportError(error, stackTrace);
  }

  /// Runs a callback of the app without waiting for it, reporting what it
  /// throws, also from the future of an `async` callback.
  void _guardCallback(void Function() callback) {
    try {
      // An async function passed where a void one is expected still
      // returns its future.
      final result = callback() as Object?;
      if (result is Future<Object?>) {
        result.then<void>((_) {}, onError: _reportError).ignore();
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  /// Like [_guardCallback], for callbacks that can be asynchronous.
  Future<void> _guardAsyncCallback(FutureOr<void> Function() callback) async {
    try {
      await callback();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Map<String, Object?>? _takePreloaded(String storedHash) =>
      _preloaded?.remove(storedHash);

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
  /// key, persisted queries that aren't loaded are deleted as well, and with
  /// [mutations] the stored mutations too.
  void _forgetStored(
    QueryFilters filters,
    Iterable<CachedQuery<Object>> queries, {
    bool mutations = false,
  }) {
    final storage = this.storage;
    if (storage == null) return;

    for (final query in queries) {
      _preloaded?.remove(query._storageHash);
      _deleteStored(query._storageKey);
    }

    final byKeyOnly = filters.type == QueryTypeFilter.all &&
        filters.stale == null &&
        filters.fetchStatus == null &&
        filters.predicate == null;
    if (!byKeyOnly) return;

    // Queries loaded now were handled above, and may get new data before an
    // asynchronous storage lists its entries.
    final loaded = {
      for (final query in queryCache.getAll()) query._storageHash
    };

    // Entries stored before 1.4.1 are under hashKey, with enums' type names;
    // match those too, so a key's old entries are deleted with it in builds
    // that keep type names.
    final queryKey = filters.queryKey;
    final bool Function(String storedHash) matchesKey;
    if (queryKey == null) {
      matchesKey = (_) => true;
    } else if (filters.exact) {
      matchesKey = {storageHash(queryKey), hashKey(queryKey)}.contains;
    } else {
      final matcher = storedKeyMatcher(queryKey);
      matchesKey =
          (storedHash) => matcher(jsonDecode(storedHash) as List<Object?>);
    }
    bool matches(String storedHash) =>
        !loaded.contains(storedHash) && matchesKey(storedHash);

    _preloaded?.removeWhere((storedHash, _) => matches(storedHash));
    _trackDeletion(() {
      // Reads synchronously when the storage does, so a query created right
      // after this call can't see the deleted entries.
      FutureOr<void> deleteMatching(Map<String, String> entries) {
        final deletions = [
          for (final key in entries.keys)
            if (key.startsWith(_mutationKeyPrefix)
                ? mutations
                : key.startsWith(persistKeyPrefix) &&
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
    bool Function(CachedQuery<Object> query)? predicate,
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

  /// Updates the data of every matching query that holds a [TData], for
  /// example a post in every list under `['posts']`. Queries of other types
  /// under the same key are left alone, and so are queries without data.
  /// Returning `null` from [updater] leaves that query unchanged.
  ///
  /// The data type comes from the parameter of [updater], so give it a type:
  /// exactly the data type of the queries, since a query of another type,
  /// even a subtype, is skipped. Without a type it throws an [ArgumentError]:
  ///
  /// ```dart
  /// client.updateQueriesData(
  ///   queryKey: ['posts', 'search'],
  ///   (List<Post> posts) => [
  ///     for (final post in posts) post.id == id ? post.liked() : post,
  ///   ],
  /// );
  /// ```
  void updateQueriesData<TData extends Object>(
    TData? Function(TData data) updater, {
    QueryKey? queryKey,
    bool exact = false,
    bool Function(CachedQuery<Object> query)? predicate,
    int? updatedAt,
  }) {
    // An updater whose parameter has no type makes TData Object, which no
    // query holds, so nothing would be updated without a word.
    if (TData == Object) {
      throw ArgumentError(
        'updateQueriesData needs the data type. Give the parameter of the '
        'updater a type, such as (List<Post> posts) => ...',
      );
    }
    final filters = QueryFilters(
      queryKey: queryKey,
      exact: exact,
      predicate: predicate,
    );
    notifyManager.batch(() {
      for (final query in queryCache.findAll(filters)) {
        if (query._dataType != TData) continue;
        final typed = query as CachedQuery<TData>;
        final data = typed.state.data;
        if (data == null) continue;
        final next = updater(data);
        if (next != null) {
          typed._setData(next, updatedAt: updatedAt, manual: true);
        }
      }
    });
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
      Query<TData>._key(queryKey),
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

  /// The cached data of the query that [options] describe, or `null`. The
  /// data type comes from [options].
  ///
  /// ```dart
  /// final Post? post = client.getData(postOptions(id));
  /// ```
  TData? getData<TData extends Object>(Query<TData> options) {
    return getQueryData<TData>(options.queryKey);
  }

  /// Writes [data] to the query that [options] describe. Like
  /// [setQueryData], but a query this creates gets all of [options], so it
  /// persists the data with [Query.persist] and can refetch.
  TData setData<TData extends Object>(
    Query<TData> options,
    TData data, {
    int? updatedAt,
  }) {
    final query = queryCache._build<TData>(this, options);
    return query._setData(data, updatedAt: updatedAt, manual: true);
  }

  /// Updates the cached data of the query that [options] describe from its
  /// current value. Returning `null` from [updater] leaves the cache
  /// unchanged.
  ///
  /// ```dart
  /// client.updateData(postOptions(id), (post) => post?.copyWith(liked: true));
  /// ```
  TData? updateData<TData extends Object>(
    Query<TData> options,
    TData? Function(TData? previous) updater, {
    int? updatedAt,
  }) {
    final data = updater(getData(options));
    if (data == null) return null;
    return setData(options, data, updatedAt: updatedAt);
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
  /// final cached = await client.query(Query(
  ///   queryKey: ['todos'],
  ///   queryFn: (_) => api.getTodos(),
  ///   staleTime: staticStaleTime,
  /// ));
  /// ```
  Future<TData> query<TData extends Object>(Query<TData> options) async {
    var defaulted = _defaultQueryOptions(options);
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
  /// `pages` passed to [InfiniteQuery] (default: one); otherwise it
  /// reloads the pages already cached.
  Future<InfiniteData<TPage, TParam>> infiniteQuery<TPage, TParam>(
    InfiniteQuery<TPage, TParam> options,
  ) {
    return query(options);
  }

  /// Removes matching queries from the cache.
  void removeQueries({
    QueryKey? queryKey,
    bool exact = false,
    QueryTypeFilter type = QueryTypeFilter.all,
    bool? stale,
    bool Function(CachedQuery<Object> query)? predicate,
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
  void _moveObservers(Iterable<CachedQuery<Object>> removed) {
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
    bool Function(CachedQuery<Object> query)? predicate,
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
    bool Function(CachedQuery<Object> query)? predicate,
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
    bool Function(CachedQuery<Object> query)? predicate,
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
    bool Function(CachedQuery<Object> query)? predicate,
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
              !query.isDisabled &&
              !(query.isStatic && query.state.data != null))
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
    if (onlineManager.isOnline) return mutationCache._resumePausedMutations();
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
  Query<TData> _defaultQueryOptions<TData extends Object>(
    Query<TData> options,
  ) {
    if (options._defaulted) return options;
    final defaults = defaultOptions.queries.merge(
      getQueryDefaults(options.queryKey),
    );
    return options._withDefaults(defaults);
  }

  Mutation<TData, TVariables, TContext>
      _defaultMutationOptions<TData, TVariables, TContext>(
    Mutation<TData, TVariables, TContext> options,
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
      _loadedMutationKeys.clear();
      _reported.clear();
      _forgetStored(const QueryFilters(), const [], mutations: true);
      _moveObservers(queries);
    });
  }
}
