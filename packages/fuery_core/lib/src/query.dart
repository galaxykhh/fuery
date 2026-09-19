part of 'core.dart';

/// A single cached query: its key, options, state, and the observers watching
/// it.
///
/// Queries are created and owned by the [QueryCache]. Application code usually
/// works with a [QueryObserver] from [Query.use], or with [QueryClient].
class Query<TData extends Object> extends Removable {
  Query._({
    required QueryClient client,
    required this.queryKey,
    required this.queryHash,
    required QueryOptions<TData> options,
    QueryState<TData>? state,
  })  : _client = client,
        _cache = client.queryCache {
    _setOptions(options);
    _initialState = _defaultState(_options);
    _state = state ?? _initialState;
    scheduleGc();
  }

  /// Watches the query for [queryKey] and returns an observer for it.
  ///
  /// The query fetches when the observer gets its first listener, for example
  /// when a `QueryBuilder` mounts or a bloc listens to [QueryObserver.stream].
  ///
  /// ```dart
  /// late final todos = Query.use(
  ///   queryKey: ['todos'],
  ///   queryFn: (_) => api.getTodos(),
  /// );
  /// ```
  static QueryObserver<TData> use<TData extends Object>({
    required QueryKey queryKey,
    required QueryFn<TData> queryFn,
    bool? enabled,
    Duration? staleTime,
    Duration? gcTime,
    Duration? refetchInterval,
    bool? refetchIntervalInBackground,
    bool Function(QueryResult<TData> result)? refetchWhile,
    RefetchMode? refetchOnMount,
    RefetchMode? refetchOnFocus,
    RefetchMode? refetchOnReconnect,
    bool? retryOnMount,
    RetryPolicy? retry,
    RetryDelay? retryDelay,
    NetworkMode? networkMode,
    TData? initialData,
    int? initialDataUpdatedAt,
    PlaceholderDataFn<TData>? placeholderData,
    bool? structuralSharing,
    QueryPersist<TData>? persist,
    Map<String, Object?>? meta,
    QueryClient? client,
  }) {
    return QueryObserver<TData>(
      client ?? Fuery.instance,
      QueryOptions<TData>(
        queryKey: queryKey,
        queryFn: queryFn,
        enabled: enabled,
        staleTime: staleTime,
        gcTime: gcTime,
        refetchInterval: refetchInterval,
        refetchIntervalInBackground: refetchIntervalInBackground,
        refetchWhile: refetchWhile,
        refetchOnMount: refetchOnMount,
        refetchOnFocus: refetchOnFocus,
        refetchOnReconnect: refetchOnReconnect,
        retryOnMount: retryOnMount,
        retry: retry,
        retryDelay: retryDelay,
        networkMode: networkMode,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
        placeholderData: placeholderData,
        structuralSharing: structuralSharing,
        persist: persist,
        meta: meta,
      ),
    );
  }

  final QueryKey queryKey;
  final String queryHash;
  final QueryClient _client;
  final QueryCache _cache;

  late QueryOptions<TData> _options;
  QueryState<TData>? _state;
  late QueryState<TData> _initialState;
  QueryState<TData>? _revertState;
  Retryer<TData>? _retryer;
  final List<QueryObserver<TData>> _observers = [];
  bool _abortSignalConsumed = false;
  bool _restoreAttempted = false;
  Future<void>? _restoring;
  bool _persistScheduled = false;

  QueryOptions<TData> get options => _options;

  Type get _dataType => TData;

  QueryState<TData> get state => _state!;

  Map<String, Object?>? get meta => _options.meta;

  /// The in-flight fetch, if any.
  Future<TData>? get future => _retryer?.future;

  List<QueryObserver<TData>> get observers => List.unmodifiable(_observers);

  void _setOptions(QueryOptions<TData> options) {
    _options =
        options._defaulted ? options : _client.defaultQueryOptions(options);
    updateGcTime(_options.gcTime);

    final state = _state;
    if (state != null && state.data == null) {
      final defaultState = _defaultState(_options);
      final initialData = defaultState.data;
      if (initialData != null) {
        setState(state.copyWith(
          data: initialData,
          dataUpdatedAt: defaultState.dataUpdatedAt,
          error: null,
          isInvalidated: false,
          status: QueryStatus.success,
        ));
        _initialState = defaultState;
      }
    }
    if (state != null) _maybeRestore();
  }

  @override
  @protected
  void optionalRemove() {
    if (_observers.isEmpty && state.fetchStatus == FetchStatus.idle) {
      _cache.remove(this);
    }
  }

  TData _setData(TData newData, {int? updatedAt, bool manual = false}) {
    final data = replaceData(
      state.data,
      newData,
      structuralSharing: _options.structuralSharing ?? true,
    );
    _dispatch(QuerySuccessAction<TData>(
      data: data,
      dataUpdatedAt: updatedAt,
      manual: manual,
    ));
    return data;
  }

  /// Replaces the query state and notifies observers.
  void setState(QueryState<TData> state) {
    _dispatch(QuerySetStateAction<TData>(state));
  }

  /// Cancels the in-flight fetch, if any.
  ///
  /// With [revert], the state goes back to what it was before the fetch.
  Future<void> cancel({bool revert = false, bool silent = false}) {
    final future = _retryer?.future;
    _retryer?.cancel(revert: revert, silent: silent);
    if (future == null) return Future.value();
    return future.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  void destroy() {
    super.destroy();
    cancel(silent: true);
  }

  /// Resets the query to its initial state.
  void reset() {
    destroy();
    setState(_initialState);
  }

  /// Whether at least one observer is enabled.
  bool isActive() => _observers.any((o) => o.options.enabled != false);

  /// Whether the query will not fetch on its own.
  bool isDisabled() {
    if (_observers.isNotEmpty) return !isActive();
    return !isFetched();
  }

  /// Whether the query resolved with data or an error at least once.
  bool isFetched() => state.dataUpdateCount + state.errorUpdateCount > 0;

  /// Whether the query is stale, as seen by its observers.
  bool isStale() {
    if (_observers.isNotEmpty) {
      return _observers.any((o) => o.result.isStale);
    }
    return state.data == null || state.isInvalidated;
  }

  /// Whether an observer uses [staticStaleTime], so the query is never stale
  /// and never refetched.
  bool isStatic() =>
      _observers.any((o) => o.options.staleTime == staticStaleTime);

  /// Whether the data is older than [staleTime].
  bool isStaleByTime([Duration? staleTime]) {
    if (state.data == null) return true;
    if (staleTime == staticStaleTime) return false;
    if (state.isInvalidated) return true;
    return timeUntilStale(state.dataUpdatedAt, staleTime) == 0;
  }

  void _onFocus() {
    _observers
        .firstWhereOrNull((o) => o._shouldFetchOnFocus())
        ?.refetch(cancelRefetch: false);
    _retryer?.resume();
  }

  void _onOnline() {
    _observers
        .firstWhereOrNull((o) => o._shouldFetchOnReconnect())
        ?.refetch(cancelRefetch: false);
    _retryer?.resume();
  }

  void _addObserver(QueryObserver<TData> observer) {
    if (_observers.contains(observer)) return;
    _observers.add(observer);
    clearGcTimeout();
    _cache.notify(QueryObserverAddedEvent(this, observer));
  }

  void _removeObserver(QueryObserver<TData> observer) {
    if (!_observers.remove(observer)) return;

    if (_observers.isEmpty) {
      final retryer = _retryer;
      if (retryer != null) {
        // Abort only if the query function can be aborted. Otherwise let it
        // finish so the result is cached.
        if (_abortSignalConsumed ||
            (state.fetchStatus == FetchStatus.paused &&
                state.status == QueryStatus.pending)) {
          retryer.cancel(revert: true);
        } else {
          retryer.cancelRetry();
        }
      }
      scheduleGc();
    }

    _cache.notify(QueryObserverRemovedEvent(this, observer));
  }

  int get observersCount => _observers.length;

  /// Marks the query as stale. Does not refetch by itself.
  void invalidate() {
    if (!state.isInvalidated) _dispatch(const QueryInvalidateAction());
  }

  /// Runs the query function and updates the state with the result.
  ///
  /// Returns the in-flight fetch if one is running, unless
  /// [FetchOptions.cancelRefetch] is set and the query already has data.
  Future<TData> fetch([
    QueryOptions<TData>? options,
    FetchOptions? fetchOptions,
  ]) async {
    final restoring = _restoring;
    if (restoring != null) {
      await restoring;
      final data = state.data;
      // Fresh restored data doesn't need a fetch, unless one was asked for.
      if (data != null &&
          !(fetchOptions?.cancelRefetch ?? false) &&
          !isStaleByTime((options ?? _options).staleTime)) {
        return data;
      }
    }

    final current = _retryer;
    if (state.fetchStatus != FetchStatus.idle &&
        current != null &&
        current.status != RetryerStatus.rejected) {
      if (state.data != null && (fetchOptions?.cancelRefetch ?? false)) {
        cancel(silent: true);
      } else {
        current.continueRetry();
        return current.future;
      }
    }

    if (options != null) _setOptions(options);

    // Queries created by setQueryData have no query function yet.
    if (_options.queryFn == null && _options.behavior == null) {
      final observer = _observers.firstWhereOrNull(
        (o) => o.options.queryFn != null || o.options.behavior != null,
      );
      if (observer != null) _setOptions(observer.options);
    }

    final abortController = AbortController();
    AbortSignal consumeSignal() {
      _abortSignalConsumed = true;
      return abortController.signal;
    }

    Future<TData> fetchFn() {
      final queryFn = _options.queryFn;
      if (queryFn == null) {
        return Future.error(StateError("Missing queryFn: '$queryHash'"));
      }
      _abortSignalConsumed = false;
      return queryFn(QueryFunctionContext._(
        client: _client,
        queryKey: queryKey,
        meta: meta,
        signal: consumeSignal,
        peekSignal: () => abortController.signal,
      ));
    }

    final context = FetchContext<TData>._(
      fetchFn: fetchFn,
      fetchOptions: fetchOptions,
      options: _options,
      client: _client,
      queryKey: queryKey,
      state: state,
      signal: consumeSignal,
    );
    _options.behavior?.onFetch(context, this);

    _revertState = state;

    // A new retryer starts here, so reset the failure count and fetch status
    // even if a paused or cancelled fetch left the query non-idle.
    _dispatch(QueryFetchAction(fetchOptions?.meta));

    final retryer = _retryer = Retryer<TData>(
      fn: context.fetchFn,
      onCancel: (error) {
        final revertState = _revertState;
        if (error.revert && revertState != null) {
          setState(revertState.copyWith(fetchStatus: FetchStatus.idle));
        }
        abortController.abort(error);
      },
      onFail: (failureCount, error) {
        _dispatch(QueryFailedAction(failureCount, error));
      },
      onPause: () => _dispatch(const QueryPauseAction()),
      onContinue: () => _dispatch(const QueryContinueAction()),
      retry: context.options.retry,
      retryDelay: context.options.retryDelay,
      networkMode: context.options.networkMode,
      canRun: () => true,
    );

    try {
      final data = await retryer.start();
      _setData(data);
      _cache.config.onSuccess?.call(data, this);
      _cache.config.onSettled?.call(data, null, this);
      return data;
    } on CancelledError catch (error) {
      if (error.silent) {
        // A new fetch replaced this one; follow it.
        return (_retryer ?? retryer).future;
      }
      if (error.revert) {
        final data = state.data;
        if (data == null) rethrow;
        return data;
      }
      _onFetchError(error);
      rethrow;
    } catch (error) {
      _onFetchError(error);
      rethrow;
    } finally {
      if (identical(_retryer, retryer)) _retryer = null;
      scheduleGc();
    }
  }

  void _onFetchError(Object error) {
    _dispatch(QueryErrorAction(error));
    _cache.config.onError?.call(error, this);
    _cache.config.onSettled?.call(state.data, error, this);
  }

  void _dispatch(QueryAction action) {
    _state = _reduce(state, action);
    if (action is QuerySuccessAction && state.fetchStatus == FetchStatus.idle) {
      _schedulePersist();
    }

    notifyManager.batch(() {
      for (final observer in _observers.toList()) {
        observer._onQueryUpdate();
      }
      _cache.notify(QueryUpdatedEvent(this, action));
    });
  }

  QueryState<TData> _reduce(QueryState<TData> state, QueryAction action) {
    switch (action) {
      case QueryFailedAction(:final failureCount, :final error):
        return state.copyWith(
          fetchFailureCount: failureCount,
          fetchFailureReason: error,
        );
      case QueryPauseAction():
        return state.copyWith(fetchStatus: FetchStatus.paused);
      case QueryContinueAction():
        return state.copyWith(fetchStatus: FetchStatus.fetching);
      case QueryFetchAction(:final meta):
        return _fetchState(state, _options.networkMode).copyWith(
          fetchMeta: meta,
        );
      case QuerySuccessAction<TData>(
          :final data,
          :final dataUpdatedAt,
          :final manual,
        ):
        var next = state.copyWith(
          data: data,
          dataUpdateCount: state.dataUpdateCount + 1,
          dataUpdatedAt: dataUpdatedAt ?? now(),
          error: null,
          isInvalidated: false,
          status: QueryStatus.success,
        );
        if (!manual) {
          next = next.copyWith(
            fetchStatus: FetchStatus.idle,
            fetchFailureCount: 0,
            fetchFailureReason: null,
          );
        }
        // After a successful fetch there is nothing to revert to. After a
        // manual update, a cancelled fetch should revert to this new data.
        _revertState = manual ? next : null;
        return next;
      case QueryErrorAction(:final error):
        return state.copyWith(
          error: error,
          errorUpdateCount: state.errorUpdateCount + 1,
          errorUpdatedAt: now(),
          fetchFailureCount: state.fetchFailureCount + 1,
          fetchFailureReason: error,
          fetchStatus: FetchStatus.idle,
          status: QueryStatus.error,
          // A background error means the existing data should be refetched.
          isInvalidated: true,
        );
      case QueryInvalidateAction():
        return state.copyWith(isInvalidated: true);
      case QuerySetStateAction<TData>(state: final newState):
        return newState;
      // Actions are created by this query with its own TData, so this only
      // exists to make the switch exhaustive.
      // coverage:ignore-start
      case QuerySuccessAction() || QuerySetStateAction():
        throw StateError('Action data type does not match query $queryHash');
      // coverage:ignore-end
    }
  }

  String get _storageKey => '$persistKeyPrefix$queryHash';

  /// Restores persisted data the first time the query has a [QueryPersist]
  /// and no data. Synchronous storage restores right away; otherwise [fetch]
  /// waits for the restore.
  void _maybeRestore() {
    final storage = _client.storage;
    if (_restoreAttempted ||
        storage == null ||
        _options.persist == null ||
        state.data != null) {
      return;
    }
    _restoreAttempted = true;

    final preloaded = _client._takePreloaded(queryHash);
    if (preloaded != null) return _applyRestored(preloaded);

    final deletions = _client._deletionsDone();
    final FutureOr<String?> value;
    try {
      value = deletions == null
          ? storage.read(_storageKey)
          : deletions.then((_) => storage.read(_storageKey));
    } catch (_) {
      return; // A failing storage is treated as empty.
    }
    if (value is Future<String?>) {
      _restoring = value
          .then(_applyRestored, onError: (Object _) {})
          .whenComplete(() => _restoring = null);
    } else {
      _applyRestored(value);
    }
  }

  /// Restores data that [QueryClient.restore] read ahead of time.
  void _restoreFromPreload() {
    if (_options.persist == null || state.data != null) return;
    final preloaded = _client._takePreloaded(queryHash);
    if (preloaded != null) _applyRestored(preloaded);
  }

  void _applyRestored(String? raw) {
    final persist = _options.persist;
    if (raw == null || persist == null || state.data != null) return;
    try {
      final entry = jsonDecode(raw) as Map<String, Object?>;
      final updatedAt = entry['t']! as int;
      final maxAge = persist.maxAge ?? _client.persistMaxAge;
      if (entry['v'] != persist.version ||
          now() - updatedAt > maxAge.inMilliseconds) {
        return _client._deleteStored(_storageKey);
      }
      setState(state.copyWith(
        data: persist._decode(entry['d']),
        dataUpdatedAt: updatedAt,
        error: null,
        isInvalidated: false,
        status: QueryStatus.success,
      ));
    } catch (_) {
      // Stored data that can't be read is discarded.
      _client._deleteStored(_storageKey);
    }
  }

  /// Writes the data once the current batch of updates is done.
  void _schedulePersist() {
    if (_persistScheduled ||
        _client.storage == null ||
        _options.persist == null) {
      return;
    }
    _persistScheduled = true;
    notifyManager.schedule(() {
      _persistScheduled = false;
      _writeStored();
    });
  }

  void _writeStored() {
    final storage = _client.storage!;
    final persist = _options.persist;
    final data = state.data;
    // A removed query must not write back what was just deleted.
    if (persist == null ||
        data == null ||
        !identical(_cache.get(queryHash), this)) {
      return;
    }
    final String value;
    try {
      value = jsonEncode({
        'v': persist.version,
        't': state.dataUpdatedAt,
        'd': persist._encode(data),
      });
    } catch (_) {
      return; // Data that can't be encoded isn't stored.
    }
    // Write after deletions in flight, so they can't remove the new data.
    final deletions = _client._deletionsDone();
    if (deletions == null) {
      _ignoreErrors(() => storage.write(_storageKey, value));
    } else {
      deletions.then((_) => storage.write(_storageKey, value)).ignore();
    }
  }

  @override
  String toString() => 'Query($queryHash, ${state.status.name})';
}

QueryState<TData> _fetchState<TData extends Object>(
  QueryState<TData> state,
  NetworkMode? networkMode,
) {
  final next = state.copyWith(
    fetchFailureCount: 0,
    fetchFailureReason: null,
    fetchStatus:
        canFetch(networkMode) ? FetchStatus.fetching : FetchStatus.paused,
  );
  if (state.data != null) return next;
  return next.copyWith(error: null, status: QueryStatus.pending);
}

QueryState<TData> _defaultState<TData extends Object>(
  QueryOptions<TData> options,
) {
  final data = options.initialData;
  final hasData = data != null;
  return QueryState<TData>(
    data: data,
    dataUpdatedAt: hasData ? (options.initialDataUpdatedAt ?? now()) : 0,
    status: hasData ? QueryStatus.success : QueryStatus.pending,
  );
}
