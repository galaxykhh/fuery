part of 'core.dart';

/// What a [QueryObserver] reports to its listeners.
@immutable
class QueryResult<TData extends Object> {
  const QueryResult({
    required this.status,
    required this.fetchStatus,
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isPlaceholderData,
    required this.isStale,
    required this.isEnabled,
  }) : _observer = null;

  /// A result reported by [observer], so it can act on its query.
  const QueryResult._reported({
    required this.status,
    required this.fetchStatus,
    required this.data,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdatedAt,
    required this.errorUpdateCount,
    required this.failureCount,
    required this.failureReason,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isPlaceholderData,
    required this.isStale,
    required this.isEnabled,
    required QueryObserver<TData> observer,
  }) : _observer = observer;

  /// [base], reported by [_observer], for results that extend it.
  QueryResult._copy(QueryResult<TData> base, this._observer)
      : status = base.status,
        fetchStatus = base.fetchStatus,
        data = base.data,
        dataUpdatedAt = base.dataUpdatedAt,
        error = base.error,
        errorUpdatedAt = base.errorUpdatedAt,
        errorUpdateCount = base.errorUpdateCount,
        failureCount = base.failureCount,
        failureReason = base.failureReason,
        isFetched = base.isFetched,
        isFetchedAfterMount = base.isFetchedAfterMount,
        isPlaceholderData = base.isPlaceholderData,
        isStale = base.isStale,
        isEnabled = base.isEnabled;

  final QueryObserver<TData>? _observer;

  /// Whether there is data ([QueryStatus.success]), an error with no data
  /// ([QueryStatus.error]), or neither yet ([QueryStatus.pending]).
  final QueryStatus status;

  /// Whether the query function is running, paused, or idle.
  final FetchStatus fetchStatus;

  /// The data, or `null` if there is none yet.
  final TData? data;

  /// When [data] was last updated, in milliseconds since epoch. `0` if
  /// never.
  final int dataUpdatedAt;

  /// The error of the last fetch, or `null`. Cleared when a fetch succeeds.
  final Object? error;

  /// When [error] was last set, in milliseconds since epoch. `0` if never.
  final int errorUpdatedAt;

  /// How many times the query resolved with an error.
  final int errorUpdateCount;

  /// Failures during the current fetch, including retries.
  final int failureCount;

  /// The latest failure during the current fetch, including retries.
  final Object? failureReason;

  /// Whether the query has resolved at least once.
  final bool isFetched;

  /// Whether the query resolved since this observer got its first listener.
  /// Starts over when the observer is listened to again after all its
  /// listeners left.
  final bool isFetchedAfterMount;

  /// Whether [data] comes from `placeholderData`.
  final bool isPlaceholderData;

  /// Whether the data is older than `staleTime`, invalidated, or missing.
  /// Always false for a disabled query. Stale data refetches on mount,
  /// focus, and reconnect.
  final bool isStale;

  /// Whether the query fetches automatically (`enabled` isn't `false`).
  final bool isEnabled;

  /// No data yet.
  bool get isPending => status == QueryStatus.pending;

  bool get isSuccess => status == QueryStatus.success;

  bool get isError => status == QueryStatus.error;

  bool get hasData => data != null;

  /// Fetching for the first time: pending and fetching.
  bool get isLoading => isPending && isFetching;

  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Fetching while data is already shown.
  bool get isRefetching => isFetching && !isPending;

  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Failed before getting any data.
  bool get isLoadingError => isError && !hasData;

  /// Failed while refetching; [data] still holds the last good data.
  bool get isRefetchError => isError && hasData;

  /// Refetches like [QueryObserver.refetch] on the observer that reported
  /// this result, for example from a builder. That is the observer's current
  /// query: after a widget moved to another key, the new one.
  Future<QueryResult<TData>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _reporter.refetch(
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
  }

  QueryObserver<TData> get _reporter {
    final observer = _observer;
    if (observer == null) {
      throw StateError(
        'This result was created by hand, not reported by an observer, so it '
        'has no query to act on.',
      );
    }
    return observer;
  }

  @override
  bool operator ==(Object other) {
    return other is QueryResult<TData> &&
        other.runtimeType == runtimeType &&
        other.status == status &&
        other.fetchStatus == fetchStatus &&
        other.data == data &&
        other.dataUpdatedAt == dataUpdatedAt &&
        other.error == error &&
        other.errorUpdatedAt == errorUpdatedAt &&
        other.errorUpdateCount == errorUpdateCount &&
        other.failureCount == failureCount &&
        other.failureReason == failureReason &&
        other.isFetched == isFetched &&
        other.isFetchedAfterMount == isFetchedAfterMount &&
        other.isPlaceholderData == isPlaceholderData &&
        other.isStale == isStale &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode => Object.hash(
        status,
        fetchStatus,
        data,
        dataUpdatedAt,
        error,
        errorUpdatedAt,
        errorUpdateCount,
        failureCount,
        failureReason,
        isFetched,
        isFetchedAfterMount,
        isPlaceholderData,
        isStale,
        isEnabled,
      );

  @override
  String toString() {
    return 'QueryResult(status: ${status.name}, fetchStatus: '
        '${fetchStatus.name}, data: $data, error: $error, isStale: $isStale)';
  }
}
