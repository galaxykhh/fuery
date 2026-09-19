part of 'core.dart';

/// Watches a query with its own options and reports [QueryResult]s.
///
/// Several observers can watch the same query with different options, such as
/// different `staleTime`s. The observer subscribes to its query when it gets
/// its first listener, and unsubscribes when the last one leaves. It can be
/// listened to again afterwards.
class QueryObserver<TData extends Object>
    extends Subscribable<QueryResult<TData>> {
  QueryObserver(this._client, QueryOptions<TData> options) {
    setOptions(options);
  }

  final QueryClient _client;
  QueryOptions<TData>? _options;
  Query<TData>? _query;
  late QueryState<TData> _currentQueryInitialState;
  QueryResult<TData>? _currentResult;
  QueryState<TData>? _currentResultState;
  QueryOptions<TData>? _currentResultOptions;
  Query<TData>? _lastQueryWithDefinedData;
  Timer? _staleTimer;
  Timer? _refetchTimer;
  Duration? _currentRefetchInterval;

  QueryOptions<TData> get options => _options!;

  Query<TData> get currentQuery => _query!;

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
    currentQuery._addObserver(this);

    if (_shouldFetchOnMount(currentQuery, options)) {
      _executeFetch();
    } else {
      updateResult();
    }

    _updateTimers();
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners()) destroy();
  }

  bool _shouldFetchOnReconnect() {
    return _shouldFetchOn(currentQuery, options, options.refetchOnReconnect);
  }

  bool _shouldFetchOnFocus() {
    return _shouldFetchOn(currentQuery, options, options.refetchOnFocus);
  }

  /// Removes all listeners and stops watching the query.
  void destroy() {
    listeners = {};
    _clearStaleTimeout();
    _clearRefetchInterval();
    _query?._removeObserver(this);
  }

  /// Updates the options. Changing the key switches to another query.
  void setOptions(QueryOptions<TData> options) {
    final prevOptions = _options;
    final prevQuery = _query;
    final defaulted = _client.defaultQueryOptions(options);

    // Throws before anything changes if the key holds another data type.
    _client.queryCache.build<TData>(_client, defaulted);
    _options = defaulted;

    _updateQuery();
    currentQuery._setOptions(this.options);

    if (prevOptions != null && !prevOptions._sameAs(this.options)) {
      _client.queryCache.notify(
        QueryObserverOptionsUpdatedEvent(currentQuery, this),
      );
    }

    final mounted = hasListeners();

    if (mounted &&
        _shouldFetchOptionally(
          currentQuery,
          prevQuery,
          this.options,
          prevOptions,
        )) {
      _executeFetch();
    }

    updateResult();

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
    final query = _client.queryCache.build<TData>(_client, options);
    final result = _createResult(query, options, optimistic: true);
    if (result != _currentResult) {
      _currentResult = result;
      _currentResultOptions = options;
      _currentResultState = query.state;
    }
    return result;
  }

  /// Refetches the query.
  ///
  /// With [cancelRefetch], an in-flight fetch is cancelled and restarted.
  /// Errors are reported in the result, unless [throwOnError] is true.
  Future<QueryResult<TData>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _fetch(FetchOptions(cancelRefetch: cancelRefetch), throwOnError);
  }

  Future<QueryResult<TData>> _fetch(
    FetchOptions fetchOptions,
    bool throwOnError,
  ) async {
    await _executeFetch(fetchOptions, throwOnError);
    updateResult();
    return result;
  }

  Future<TData?> _executeFetch([
    FetchOptions? fetchOptions,
    bool throwOnError = false,
  ]) {
    _updateQuery();
    final future = currentQuery.fetch(options, fetchOptions);
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
      if (!result.isStale) updateResult();
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
          focusManager.isFocused()) {
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
    Query<TData> query,
    QueryOptions<TData> options, {
    bool optimistic = false,
  }) {
    final prevQuery = _query;
    final prevOptions = _options;
    final prevResult = _currentResult;
    final prevResultOptions = _currentResultOptions;
    final queryChanged = !identical(query, prevQuery);
    final queryInitialState =
        queryChanged ? query.state : _currentQueryInitialState;

    var state = query.state;

    if (optimistic) {
      final mounted = hasListeners();
      final fetchOnMount = !mounted && _shouldFetchOnMount(query, options);
      final fetchOptionally = mounted &&
          _shouldFetchOptionally(query, prevQuery, options, prevOptions);
      if (fetchOnMount || fetchOptionally) {
        state = _fetchState(state, query.options.networkMode);
      }
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
        placeholder = placeholderFn(_lastQueryWithDefinedData?.state.data);
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

    return _buildResult(
      query,
      options,
      QueryResult<TData>(
        status: status,
        fetchStatus: state.fetchStatus,
        data: data,
        dataUpdatedAt: state.dataUpdatedAt,
        error: state.error,
        errorUpdatedAt: state.errorUpdatedAt,
        errorUpdateCount: state.errorUpdateCount,
        failureCount: state.fetchFailureCount,
        failureReason: state.fetchFailureReason,
        isFetched: query.isFetched(),
        isFetchedAfterMount:
            state.dataUpdateCount > queryInitialState.dataUpdateCount ||
                state.errorUpdateCount > queryInitialState.errorUpdateCount,
        isPlaceholderData: isPlaceholderData,
        isStale: _isStale(query, options),
        isEnabled: options.enabled != false,
      ),
    );
  }

  /// Lets subclasses extend the base result.
  QueryResult<TData> _buildResult(
    Query<TData> query,
    QueryOptions<TData> options,
    QueryResult<TData> base,
  ) {
    return base;
  }

  /// Recomputes the result and notifies listeners if it changed.
  void updateResult() {
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
      for (final listener in listeners.toList()) {
        listener(nextResult);
      }
      _client.queryCache.notify(QueryObserverResultsUpdatedEvent(currentQuery));
    });
  }

  void _updateQuery() {
    final query = _client.queryCache.build<TData>(_client, options);
    if (identical(query, _query)) return;

    final prevQuery = _query;
    _query = query;
    _currentQueryInitialState = query.state;

    if (hasListeners()) {
      prevQuery?._removeObserver(this);
      query._addObserver(this);
    }
  }

  void _onQueryUpdate() {
    updateResult();
    if (hasListeners()) _updateTimers();
  }
}

bool _shouldLoadOnMount<TData extends Object>(
  Query<TData> query,
  QueryOptions<TData> options,
) {
  return options.enabled != false &&
      query.state.data == null &&
      !(query.state.status == QueryStatus.error &&
          options.retryOnMount == false);
}

bool _shouldFetchOnMount<TData extends Object>(
  Query<TData> query,
  QueryOptions<TData> options,
) {
  return _shouldLoadOnMount(query, options) ||
      (query.state.data != null &&
          _shouldFetchOn(query, options, options.refetchOnMount));
}

bool _shouldFetchOn<TData extends Object>(
  Query<TData> query,
  QueryOptions<TData> options,
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
  Query<TData> query,
  Query<TData>? prevQuery,
  QueryOptions<TData> options,
  QueryOptions<TData>? prevOptions,
) {
  return (!identical(query, prevQuery) || prevOptions?.enabled == false) &&
      _isStale(query, options);
}

bool _isStale<TData extends Object>(
  Query<TData> query,
  QueryOptions<TData> options,
) {
  return options.enabled != false && query.isStaleByTime(options.staleTime);
}
