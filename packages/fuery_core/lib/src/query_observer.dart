part of 'core.dart';

/// Watches a query with its own options and reports [QueryResult]s.
///
/// Several observers can watch the same query with different options, such as
/// different `staleTime`s. The observer subscribes to its query when it gets
/// its first listener, and unsubscribes when the last one leaves. It can be
/// listened to again afterwards.
class QueryObserver<TData extends Object>
    extends Subscribable<QueryResult<TData>> implements QuerySource<TData> {
  QueryObserver(this._client, Query<TData> options) {
    setOptions(options);
  }

  final QueryClient _client;
  Query<TData>? _options;

  /// A copy of the key that the hash of [options] was made from, for
  /// [_hashIfSame], or null for a key that [sameKey] leaves to hashing. A
  /// copy, so a key changed in place gets its new hash. Made once options
  /// come a second time: an observer created for code outside widgets may
  /// never get new ones. Null after options that came already defaulted,
  /// whose hash this observer didn't make.
  List<Object?>? _hashedKey;
  CachedQuery<TData>? _query;
  late QueryState<TData> _currentQueryInitialState;
  QueryResult<TData>? _currentResult;
  QueryState<TData>? _currentResultState;
  Query<TData>? _currentResultOptions;
  CachedQuery<TData>? _lastQueryWithDefinedData;
  Timer? _staleTimer;
  Timer? _refetchTimer;
  Duration? _currentRefetchInterval;

  /// The client this observer reads and writes, fixed for its whole life.
  QueryClient get client => _client;

  Query<TData> get options => _options!;

  CachedQuery<TData> get currentQuery => _query!;

  /// The latest result.
  QueryResult<TData> get result => _currentResult!;

  /// Results as a stream. Each listener first receives the current result,
  /// then every change. Listening subscribes the observer to its query, which
  /// can trigger a fetch.
  late final Stream<QueryResult<TData>> stream = Stream.multi(
    (controller) {
      QueryResult<TData>? last;
      void emit(QueryResult<TData> result) {
        if (result == last) return;
        last = result;
        controller.add(result);
      }

      final unsubscribe = subscribe(notifyManager.batchCalls(emit));
      emit(result);
      controller.onCancel = unsubscribe;
    },
    isBroadcast: true,
  );

  @override
  void onSubscribe() {
    if (listeners.length != 1) return;

    // The query may have been garbage collected while nobody listened.
    _updateQuery();
    // Observers outlive their listeners, so "after mount" starts here, not
    // when the observer was created.
    _currentQueryInitialState = currentQuery.state;
    currentQuery._addObserver(this);

    _fetchOnMount();
    // A fetch that joins one already running doesn't dispatch, so update the
    // result either way.
    _updateResult();

    _updateTimers();
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) destroy();
  }

  /// Follows the key to a new query after the old one was removed from the
  /// cache, and loads it like a new subscriber would.
  void _onQueryRemoved() {
    _updateQuery();
    _fetchOnMount();
    _updateResult();
    _updateTimers();
  }

  /// Fetches as a new subscriber should, deciding after stored data is
  /// restored so [Query.refetchOnMount] applies to it.
  void _fetchOnMount() {
    final query = currentQuery;
    final restoring = query._restoring;
    if (restoring == null) {
      if (_shouldFetchOnMount(query, options)) _executeFetch();
      return;
    }
    restoring.then((_) {
      if (hasListeners &&
          identical(query, currentQuery) &&
          _shouldFetchOnMount(query, options)) {
        _executeFetch();
      }
    });
  }

  bool _shouldFetchOnReconnect() {
    return _shouldFetchOn(currentQuery, options, options.refetchOnReconnect);
  }

  bool _shouldFetchOnFocus() {
    return _shouldFetchOn(currentQuery, options, options.refetchOnFocus);
  }

  /// Removes all listeners and stops watching the query.
  void destroy() {
    clearListeners();
    _clearStaleTimeout();
    _clearRefetchInterval();
    _query?._removeObserver(this);
  }

  /// The hash of the key of [options] if [key] has the same one, told
  /// without hashing [key], or null.
  String? _hashIfSame(QueryKey key) {
    final hashed = _hashedKey;
    return hashed != null && sameKey(key, hashed) ? options.queryHash : null;
  }

  /// Updates the options. Changing the key switches to another query.
  void setOptions(Query<TData> options) {
    final prevOptions = _options;
    final prevQuery = _query;
    // A key built again with the same content keeps its hash. Options
    // defaulted before, such as an observer's `options`, keep theirs.
    final alreadyDefaulted = options._defaulted;
    final knownHash = alreadyDefaulted ? null : _hashIfSame(options.queryKey);
    final defaulted = _client._defaultQueryOptions(options, knownHash);

    // Throws before anything changes if the key holds another data type.
    _client.queryCache._build<TData>(_client, defaulted);
    _options = defaulted;
    if (alreadyDefaulted) {
      // Their hash is the one their key had when they were defaulted, which
      // a key changed in place since no longer has: the next key is hashed.
      _hashedKey = null;
    } else if (knownHash == null && prevOptions != null) {
      _hashedKey = keyCopy(defaulted.queryKey);
    }

    _updateQuery();
    currentQuery._setOptions(this.options);

    if (prevOptions != null && !prevOptions._sameConfig(this.options)) {
      _client.queryCache._notify();
    }

    final mounted = hasListeners;

    if (mounted &&
        _shouldFetchOptionally(
          currentQuery,
          prevQuery,
          this.options,
          prevOptions,
        )) {
      _executeFetch();
    }

    _updateResult();

    final queryChanged = !identical(currentQuery, prevQuery);
    final enabledChanged = this.options.enabled != prevOptions?.enabled;

    if (mounted &&
        (queryChanged ||
            enabledChanged ||
            this.options.staleTime != prevOptions?.staleTime)) {
      _updateStaleTimeout();
    }

    final nextInterval = _computeRefetchInterval();
    if (mounted &&
        (queryChanged ||
            enabledChanged ||
            nextInterval != _currentRefetchInterval)) {
      _updateRefetchInterval(nextInterval);
    }
  }

  /// The result as it will look right after subscribing, for example with
  /// `isFetching` already true if subscribing starts a fetch. Useful for the
  /// first build of a widget.
  QueryResult<TData> getOptimisticResult() {
    final query = _client.queryCache._build<TData>(_client, options);
    if (hasListeners) {
      // Already subscribed: nothing will fetch on subscribe, and a changed
      // result must reach the other listeners too.
      _updateResult();
      return result;
    }
    final optimistic = _createResult(query, options, optimistic: true);
    if (optimistic != _currentResult) {
      _currentResult = optimistic;
      _currentResultOptions = options;
      _currentResultState = query.state;
    }
    return optimistic;
  }

  /// Refetches the query.
  ///
  /// With [cancelRefetch], an in-flight fetch is cancelled and restarted if
  /// the query already has data; otherwise the in-flight fetch is reused.
  /// Errors are reported in the result, unless [throwOnError] is true.
  Future<QueryResult<TData>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _fetch(_FetchOptions(cancelRefetch: cancelRefetch), throwOnError);
  }

  Future<QueryResult<TData>> _fetch(
    _FetchOptions fetchOptions,
    bool throwOnError,
  ) async {
    await _executeFetch(fetchOptions, throwOnError);
    _updateResult();
    return result;
  }

  Future<TData?> _executeFetch([
    _FetchOptions? fetchOptions,
    bool throwOnError = false,
  ]) {
    _updateQuery();
    final future = currentQuery._fetch(options, fetchOptions);
    if (throwOnError) return future;
    return future.then<TData?>((data) => data, onError: (Object _) => null);
  }

  bool _shouldScheduleTimer(Duration? timeout) {
    return options.enabled != false && isValidTimeout(timeout);
  }

  void _updateStaleTimeout() {
    _clearStaleTimeout();
    final staleTime = options.staleTime;

    if (result.isStale || !_shouldScheduleTimer(staleTime)) return;

    final time = timeUntilStale(result.dataUpdatedAt, staleTime);

    // Timers can fire a little early, so wait one extra millisecond to make
    // sure the data is stale when the timer runs.
    _staleTimer = Timer(Duration(milliseconds: time + 1), () {
      if (!result.isStale) _updateResult();
    });
  }

  Duration? _computeRefetchInterval() {
    final interval = options.refetchInterval;
    final refetchWhile = options.refetchWhile;
    if (interval == null || refetchWhile == null) return interval;
    return refetchWhile(result) ? interval : null;
  }

  void _updateRefetchInterval(Duration? nextInterval) {
    _clearRefetchInterval();
    _currentRefetchInterval = nextInterval;

    if (nextInterval == null ||
        nextInterval == Duration.zero ||
        !_shouldScheduleTimer(nextInterval)) {
      return;
    }

    _refetchTimer = Timer.periodic(nextInterval, (_) {
      if (options.refetchIntervalInBackground == true ||
          focusManager.isFocused) {
        _executeFetch();
      }
    });
  }

  void _updateTimers() {
    _updateStaleTimeout();
    _updateRefetchInterval(_computeRefetchInterval());
  }

  void _clearStaleTimeout() {
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  void _clearRefetchInterval() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
  }

  QueryResult<TData> _createResult(
    CachedQuery<TData> query,
    Query<TData> options, {
    bool optimistic = false,
  }) {
    final prevQuery = _query;
    final prevResult = _currentResult;
    final prevResultOptions = _currentResultOptions;
    final queryChanged = !identical(query, prevQuery);
    // An optimistic result shows the first result after subscribing, which
    // starts counting from the query's state now.
    final queryInitialState =
        queryChanged || optimistic ? query.state : _currentQueryInitialState;

    var state = query.state;

    // Only observers without listeners compute an optimistic result: show
    // the fetch that subscribing will start. It reloads everything, never a
    // single page.
    if (optimistic && _shouldFetchOnMount(query, options)) {
      state = _fetchState(state, query.options.networkMode)
          ._withFetchDirection(null);
    }

    var status = state.status;
    var data = state.data;
    var isPlaceholderData = false;

    final placeholderFn = options.placeholderData;
    if (placeholderFn != null && data == null && status.isPending) {
      TData? placeholder;
      if (prevResult != null &&
          prevResult.isPlaceholderData &&
          placeholderFn == prevResultOptions?.placeholderData) {
        placeholder = prevResult.data;
      } else {
        placeholder = placeholderFn(
          _lastQueryWithDefinedData?.state.data,
          _client,
        );
      }

      if (placeholder != null) {
        status = QueryStatus.success;
        data = replaceData(
          prevResult?.data,
          placeholder,
          structuralSharing: options.structuralSharing ?? true,
        );
        isPlaceholderData = true;
      }
    }

    final base = QueryResult<TData>._reported(
      status: status,
      fetchStatus: state.fetchStatus,
      data: data,
      dataUpdatedAt: state.dataUpdatedAt,
      error: state.error,
      errorUpdatedAt: state.errorUpdatedAt,
      errorUpdateCount: state.errorUpdateCount,
      failureCount: state.fetchFailureCount,
      failureReason: state.fetchFailureReason,
      isFetched: query.isFetched,
      isFetchedAfterMount:
          state.dataUpdateCount > queryInitialState.dataUpdateCount ||
              state.errorUpdateCount > queryInitialState.errorUpdateCount,
      isPlaceholderData: isPlaceholderData,
      isStale: _isStale(query, options),
      isEnabled: options.enabled != false,
      observer: this,
    );
    return _buildResult(state, options, base);
  }

  /// Lets subclasses extend the base result.
  QueryResult<TData> _buildResult(
    QueryState<TData> state,
    Query<TData> options,
    QueryResult<TData> base,
  ) {
    return base;
  }

  /// Recomputes the result and notifies listeners if it changed.
  void _updateResult() {
    final prevResult = _currentResult;
    final nextResult = _createResult(currentQuery, options);

    _currentResultState = currentQuery.state;
    _currentResultOptions = options;

    if (_currentResultState!.data != null) {
      _lastQueryWithDefinedData = currentQuery;
    }

    if (nextResult == prevResult) return;

    _currentResult = nextResult;

    notifyManager.batch(() {
      for (final listener in listeners) {
        // A listener that throws is reported, so the other listeners still
        // get the result and this observer still updates its timers.
        _client._guardCallback(() => listener(nextResult));
      }
      _client.queryCache._notify();
    });
  }

  void _updateQuery() {
    final query = _client.queryCache._build<TData>(_client, options);
    if (identical(query, _query)) return;

    final prevQuery = _query;
    _query = query;
    _currentQueryInitialState = query.state;

    if (hasListeners) {
      prevQuery?._removeObserver(this);
      query._addObserver(this);
    }
  }

  void _onQueryUpdate() {
    _updateResult();
    if (hasListeners) _updateTimers();
  }
}

bool _shouldLoadOnMount<TData extends Object>(
  CachedQuery<TData> query,
  Query<TData> options,
) {
  return options.enabled != false &&
      query.state.data == null &&
      !(query.state.status == QueryStatus.error &&
          options.retryOnMount == false);
}

bool _shouldFetchOnMount<TData extends Object>(
  CachedQuery<TData> query,
  Query<TData> options,
) {
  return _shouldLoadOnMount(query, options) ||
      (query.state.data != null &&
          _shouldFetchOn(query, options, options.refetchOnMount));
}

bool _shouldFetchOn<TData extends Object>(
  CachedQuery<TData> query,
  Query<TData> options,
  RefetchMode? mode,
) {
  if (options.enabled == false || options.staleTime == staticStaleTime) {
    return false;
  }
  final value = mode ?? RefetchMode.ifStale;
  return value == RefetchMode.always ||
      (value != RefetchMode.never && _isStale(query, options));
}

bool _shouldFetchOptionally<TData extends Object>(
  CachedQuery<TData> query,
  CachedQuery<TData>? prevQuery,
  Query<TData> options,
  Query<TData>? prevOptions,
) {
  return (!identical(query, prevQuery) || prevOptions?.enabled == false) &&
      _isStale(query, options);
}

bool _isStale<TData extends Object>(
  CachedQuery<TData> query,
  Query<TData> options,
) {
  return options.enabled != false && query.isStaleByTime(options.staleTime);
}
