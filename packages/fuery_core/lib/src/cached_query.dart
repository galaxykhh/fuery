part of 'core.dart';

/// A single cached query: its key, options, state, and the observers watching
/// it.
///
/// Queries are created and owned by the [QueryCache]. Application code usually
/// describes a query with [Query], and works with [QueryClient].
class CachedQuery<TData extends Object> extends _Removable {
  CachedQuery._({
    required QueryClient client,
    required this.queryKey,
    required this.queryHash,
    required Query<TData> options,
  })  : _client = client,
        _cache = client.queryCache {
    _setOptions(options);
    _initialState = _defaultState(_options);
    _state = _initialState;
    _scheduleGc();
  }

  final QueryKey queryKey;
  final String queryHash;
  final QueryClient _client;
  final QueryCache _cache;

  late Query<TData> _options;
  QueryState<TData>? _state;
  late QueryState<TData> _initialState;
  QueryState<TData>? _revertState;
  Retryer<TData>? _retryer;
  final List<QueryObserver<TData>> _observers = [];
  bool _abortSignalConsumed = false;
  bool _removed = false;
  bool _restoreAttempted = false;
  Future<void>? _restoring;

  /// Increased by a reset, so a read that started before it is dropped.
  int _restoreGeneration = 0;
  bool _persistScheduled = false;

  Query<TData> get options => _options;

  Type get _dataType => TData;

  QueryState<TData> get state => _state!;

  Map<String, Object?>? get meta => _options.meta;

  /// The in-flight fetch, if any.
  Future<TData>? get future => _retryer?.future;

  List<QueryObserver<TData>> get observers => List.unmodifiable(_observers);

  void _setOptions(Query<TData> options) {
    _options =
        options._defaulted ? options : _client._defaultQueryOptions(options);
    _updateGcTime(_options.gcTime);

    final state = _state;
    if (state != null && state.data == null) {
      final defaultState = _defaultState(_options);
      final initialData = defaultState.data;
      if (initialData != null) {
        _setState(state.copyWith(
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
  void _scheduleGc() {
    // Once removed from the cache, there is nothing left to collect, and a
    // timer would outlive the query.
    if (!_removed) super._scheduleGc();
  }

  @override
  void _optionalRemove() {
    if (_observers.isEmpty && state.fetchStatus == FetchStatus.idle) {
      _cache._remove(this);
    }
  }

  TData _setData(TData newData, {int? updatedAt, bool manual = false}) {
    final data = replaceData(
      state.data,
      newData,
      structuralSharing: _options.structuralSharing ?? true,
    );
    _dispatch(_QuerySuccessAction<TData>(
      data: data,
      dataUpdatedAt: updatedAt,
      manual: manual,
    ));
    return data;
  }

  /// Replaces the query state and notifies observers.
  void _setState(QueryState<TData> state) {
    _dispatch(_QuerySetStateAction<TData>(state));
  }

  /// Cancels the in-flight fetch, if any.
  ///
  /// With [revert], the state goes back to what it was before the fetch.
  Future<void> _cancel({bool revert = false, bool silent = false}) {
    final future = _retryer?.future;
    _retryer?.cancel(revert: revert, silent: silent);
    if (future == null) return Future.value();
    return future.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  void _destroy() {
    super._destroy();
    _cancel(silent: true);
  }

  /// Resets the query to its initial state.
  void _reset() {
    _restoreGeneration++;
    _destroy();
    _setState(_initialState);
    if (_observers.isEmpty) _scheduleGc();
  }

  /// Whether at least one observer is enabled.
  bool get isActive => _observers.any((o) => o.options.enabled != false);

  /// Whether the query will not fetch on its own.
  bool get isDisabled {
    if (_observers.isNotEmpty) return !isActive;
    return !isFetched;
  }

  /// Whether the query resolved with data or an error at least once.
  bool get isFetched => state.dataUpdateCount + state.errorUpdateCount > 0;

  /// Whether the query is stale, as seen by its observers.
  bool get isStale {
    if (_observers.isNotEmpty) {
      return _observers.any((o) => o.result.isStale);
    }
    return state.data == null || state.isInvalidated;
  }

  /// Whether an observer uses [staticStaleTime], so the query is never stale
  /// and never refetched.
  bool get isStatic =>
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
    _clearGcTimeout();
    _cache._notify();
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
      _scheduleGc();
    }

    _cache._notify();
  }

  int get observersCount => _observers.length;

  /// Marks the query as stale. Does not refetch by itself.
  void _invalidate() {
    if (!state.isInvalidated) _dispatch(const _QueryInvalidateAction());
  }

  /// Refetches with the options of an observer when there is one, so options
  /// passed to [QueryClient.query], like its retry default, don't stick.
  Future<TData> _refetch(_FetchOptions fetchOptions) {
    return _fetch(_observers.firstOrNull?.options, fetchOptions);
  }

  /// Runs the query function and updates the state with the result.
  ///
  /// Returns the in-flight fetch if one is running, unless
  /// [_FetchOptions.cancelRefetch] is set and the query already has data.
  Future<TData> _fetch([
    Query<TData>? options,
    _FetchOptions? fetchOptions,
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
        _cancel(silent: true);
      } else {
        current.continueRetry();
        return current.future;
      }
    }

    if (options != null) _setOptions(options);

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

    final context = _FetchContext<TData>._(
      fetchFn: fetchFn,
      fetchOptions: fetchOptions,
      options: _options,
      client: _client,
      queryKey: queryKey,
      state: state,
      signal: consumeSignal,
    );
    _options._behavior?.onFetch(context, this);

    _revertState = state;

    // A new retryer starts here, so reset the failure count and fetch status
    // even if a paused or cancelled fetch left the query non-idle.
    _dispatch(_QueryFetchAction(fetchOptions?.direction));

    final retryer = _retryer = Retryer<TData>(
      fn: context.fetchFn,
      onCancel: (error) {
        // Update the state right away, so a write or fetch that follows the
        // cancel isn't overwritten when the cancelled fetch settles.
        final revertState = _revertState;
        if (error.revert && revertState != null) {
          _setState(revertState.copyWith(fetchStatus: FetchStatus.idle));
        } else if (!error.silent) {
          _dispatch(_QueryErrorAction(error));
        }
        abortController.abort(error);
      },
      onFail: (failureCount, error) {
        _dispatch(_QueryFailedAction(failureCount, error));
      },
      onPause: () => _dispatch(const _QueryPauseAction()),
      onContinue: () => _dispatch(const _QueryContinueAction()),
      retry: context.options.retry,
      retryDelay: context.options.retryDelay,
      networkMode: context.options.networkMode,
      canRun: () => true,
    );

    try {
      final data = await retryer.start();
      _setData(data);
      _client._guardCallback(() => _cache.config.onSuccess?.call(data, this));
      _client._guardCallback(
        () => _cache.config.onSettled?.call(data, null, this),
      );
      return data;
    } on CancelledError catch (error) {
      if (error.silent) {
        // Follow the fetch that replaced this one, if any.
        final current = _retryer;
        if (current != null && !identical(current, retryer)) {
          return current.future;
        }
        if (state.fetchStatus != FetchStatus.idle) {
          _setState(state.copyWith(fetchStatus: FetchStatus.idle));
        }
        rethrow;
      }
      if (error.revert) {
        final data = state.data;
        if (data == null) rethrow;
        return data;
      }
      rethrow;
    } catch (error) {
      _onFetchError(error);
      rethrow;
    } finally {
      if (identical(_retryer, retryer)) _retryer = null;
      _scheduleGc();
    }
  }

  void _onFetchError(Object error) {
    _dispatch(_QueryErrorAction(error));
    _client._guardCallback(() => _cache.config.onError?.call(error, this));
    _client._guardCallback(
      () => _cache.config.onSettled?.call(state.data, error, this),
    );
  }

  void _dispatch(_QueryAction action) {
    _state = _reduce(state, action);
    if (action is _QuerySuccessAction &&
        state.fetchStatus == FetchStatus.idle) {
      _schedulePersist();
    }

    notifyManager.batch(() {
      for (final observer in _observers.toList()) {
        observer._onQueryUpdate();
      }
      _cache._notify();
    });
  }

  QueryState<TData> _reduce(QueryState<TData> state, _QueryAction action) {
    switch (action) {
      case _QueryFailedAction(:final failureCount, :final error):
        return state.copyWith(
          fetchFailureCount: failureCount,
          fetchFailureReason: error,
        );
      case _QueryPauseAction():
        return state.copyWith(fetchStatus: FetchStatus.paused);
      case _QueryContinueAction():
        return state.copyWith(fetchStatus: FetchStatus.fetching);
      case _QueryFetchAction(:final direction):
        return _fetchState(state, _options.networkMode)
            ._withFetchDirection(direction);
      case _QuerySuccessAction<TData>(
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
      case _QueryErrorAction(:final error):
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
      case _QueryInvalidateAction():
        return state.copyWith(isInvalidated: true);
      case _QuerySetStateAction<TData>(state: final newState):
        return newState;
      // Actions are created by this query with its own TData, so this only
      // exists to make the switch exhaustive.
      // coverage:ignore-start
      case _QuerySuccessAction() || _QuerySetStateAction():
        throw StateError('Action data type does not match query $queryHash');
      // coverage:ignore-end
    }
  }

  /// The hash data is stored under, the same in every build.
  late final String _storageHash = storageHash(queryKey);

  /// [queryKey] converted once, for filters that match keys by prefix.
  late final Object? _keyForm = keyForm(queryKey);

  String get _storageKey => '$persistKeyPrefix$_storageHash';

  /// Restores persisted data the first time the query has a [QueryPersist]
  /// and no data. Synchronous storage restores right away; otherwise [_fetch]
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

    final preloaded = _client._takePreloaded(_storageHash);
    if (preloaded != null) return _applyEntry(preloaded);

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
      final generation = _restoreGeneration;
      _restoring = value.then(
        (raw) {
          if (generation == _restoreGeneration) _applyRestored(raw);
        },
        onError: (Object _) {},
      ).whenComplete(() => _restoring = null);
    } else {
      _applyRestored(value);
    }
  }

  /// Restores data that [QueryClient.restore] read ahead of time.
  void _restoreFromPreload() {
    // Take the entry either way: a query that already has data must not
    // restore this snapshot after it's garbage collected.
    final preloaded = _client._takePreloaded(_storageHash);
    if (preloaded != null) _applyEntry(preloaded);
  }

  void _applyRestored(String? raw) {
    if (raw == null || _options.persist == null || state.data != null) return;
    final entry = _decodeEntry(raw);
    // Stored data that can't be read is discarded.
    if (entry == null) return _client._deleteStored(_storageKey);
    _applyEntry(entry);
  }

  void _applyEntry(Map<String, Object?> entry) {
    final persist = _options.persist;
    if (persist == null || state.data != null) return;
    try {
      final updatedAt = entry['t']! as int;
      final maxAge = persist.maxAge ?? _client.persistMaxAge;
      if (entry['v'] != persist.version ||
          now() - updatedAt > maxAge.inMilliseconds) {
        return _client._deleteStored(_storageKey);
      }
      _setState(state.copyWith(
        data: persist._decode(entry['d']),
        dataUpdatedAt: updatedAt,
        error: null,
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
    final maxAge = persist.maxAge ?? _client.persistMaxAge;
    final String value;
    try {
      value = jsonEncode({
        'v': persist.version,
        't': state.dataUpdatedAt,
        // Lets restore() delete it once expired, even if the query is never
        // used again.
        'e': state.dataUpdatedAt + maxAge.inMilliseconds,
        'd': persist._encode(data),
      });
    } catch (_) {
      return; // Data that can't be encoded isn't stored.
    }
    // A snapshot read by restore() is older than this data now.
    _client._takePreloaded(_storageHash);
    // Write after deletions in flight, so they can't remove the new data.
    final deletions = _client._deletionsDone();
    if (deletions == null) {
      _ignoreErrors(() => storage.write(_storageKey, value));
    } else {
      deletions.then((_) => storage.write(_storageKey, value)).ignore();
    }
  }

  @override
  String toString() => 'CachedQuery($queryHash, ${state.status.name})';
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
  Query<TData> options,
) {
  final data = options.initialData;
  final hasData = data != null;
  return QueryState<TData>(
    data: data,
    dataUpdatedAt: hasData ? (options.initialDataUpdatedAt ?? now()) : 0,
    status: hasData ? QueryStatus.success : QueryStatus.pending,
  );
}
