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
  });

  final QueryStatus status;
  final FetchStatus fetchStatus;

  /// The data, or `null` if there is none yet.
  final TData? data;

  final int dataUpdatedAt;
  final Object? error;
  final int errorUpdatedAt;
  final int errorUpdateCount;

  /// Failures during the current fetch, including retries.
  final int failureCount;
  final Object? failureReason;

  /// Whether the query has resolved at least once.
  final bool isFetched;

  /// Whether the query resolved after this observer started watching it.
  final bool isFetchedAfterMount;

  /// Whether [data] comes from `placeholderData`.
  final bool isPlaceholderData;

  final bool isStale;
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
