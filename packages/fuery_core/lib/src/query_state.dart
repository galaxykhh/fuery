part of 'core.dart';

enum QueryStatus {
  /// No data yet and no finished attempt.
  pending,

  /// The last attempt failed.
  error,

  /// The query has data.
  success;

  bool get isPending => this == pending;
  bool get isError => this == error;
  bool get isSuccess => this == success;
}

enum FetchStatus {
  /// The query function is running.
  fetching,

  /// A fetch wanted to run but is waiting for the network or focus.
  paused,

  /// Not fetching.
  idle;

  bool get isFetching => this == fetching;
  bool get isPaused => this == paused;
  bool get isIdle => this == idle;
}

/// Which page an infinite query fetches.
enum _FetchDirection { forward, backward }

/// The raw state stored in a [CachedQuery]. Observers derive [QueryResult]s from it.
@immutable
class QueryState<TData extends Object> {
  const QueryState({
    this.data,
    this.dataUpdateCount = 0,
    this.dataUpdatedAt = 0,
    this.error,
    this.errorUpdateCount = 0,
    this.errorUpdatedAt = 0,
    this.fetchFailureCount = 0,
    this.fetchFailureReason,
    this.isInvalidated = false,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
  }) : _fetchDirection = null;

  const QueryState._({
    required this.data,
    required this.dataUpdateCount,
    required this.dataUpdatedAt,
    required this.error,
    required this.errorUpdateCount,
    required this.errorUpdatedAt,
    required this.fetchFailureCount,
    required this.fetchFailureReason,
    required this.isInvalidated,
    required this.status,
    required this.fetchStatus,
    required _FetchDirection? fetchDirection,
  }) : _fetchDirection = fetchDirection;

  /// The last successfully resolved data. `null` means there is no data.
  final TData? data;

  /// How many times the query resolved successfully.
  final int dataUpdateCount;

  /// When [data] was last updated, in milliseconds since epoch. `0` if never.
  final int dataUpdatedAt;

  /// The error from the last attempt, if it failed.
  final Object? error;

  /// How many times the query resolved with an error.
  final int errorUpdateCount;

  /// When [error] was last set, in milliseconds since epoch. `0` if never.
  final int errorUpdatedAt;

  /// Failures during the current fetch, including retries. Reset on success.
  final int fetchFailureCount;

  /// The latest failure during the current fetch. Reset on success.
  final Object? fetchFailureReason;

  /// The page direction of the in-flight or most recent fetch.
  final _FetchDirection? _fetchDirection;

  /// Whether the query was invalidated. Reset on success.
  final bool isInvalidated;

  final QueryStatus status;

  final FetchStatus fetchStatus;

  QueryState<TData> copyWith({
    Object? data = _undefined,
    int? dataUpdateCount,
    int? dataUpdatedAt,
    Object? error = _undefined,
    int? errorUpdateCount,
    int? errorUpdatedAt,
    int? fetchFailureCount,
    Object? fetchFailureReason = _undefined,
    bool? isInvalidated,
    QueryStatus? status,
    FetchStatus? fetchStatus,
  }) {
    return QueryState<TData>._(
      data: identical(data, _undefined) ? this.data : data as TData?,
      dataUpdateCount: dataUpdateCount ?? this.dataUpdateCount,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      error: identical(error, _undefined) ? this.error : error,
      errorUpdateCount: errorUpdateCount ?? this.errorUpdateCount,
      errorUpdatedAt: errorUpdatedAt ?? this.errorUpdatedAt,
      fetchFailureCount: fetchFailureCount ?? this.fetchFailureCount,
      fetchFailureReason: identical(fetchFailureReason, _undefined)
          ? this.fetchFailureReason
          : fetchFailureReason,
      isInvalidated: isInvalidated ?? this.isInvalidated,
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      fetchDirection: _fetchDirection,
    );
  }

  QueryState<TData> _withFetchDirection(_FetchDirection? direction) {
    return QueryState<TData>._(
      data: data,
      dataUpdateCount: dataUpdateCount,
      dataUpdatedAt: dataUpdatedAt,
      error: error,
      errorUpdateCount: errorUpdateCount,
      errorUpdatedAt: errorUpdatedAt,
      fetchFailureCount: fetchFailureCount,
      fetchFailureReason: fetchFailureReason,
      isInvalidated: isInvalidated,
      status: status,
      fetchStatus: fetchStatus,
      fetchDirection: direction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QueryState<TData> &&
        other.data == data &&
        other.dataUpdateCount == dataUpdateCount &&
        other.dataUpdatedAt == dataUpdatedAt &&
        other.error == error &&
        other.errorUpdateCount == errorUpdateCount &&
        other.errorUpdatedAt == errorUpdatedAt &&
        other.fetchFailureCount == fetchFailureCount &&
        other.fetchFailureReason == fetchFailureReason &&
        other._fetchDirection == _fetchDirection &&
        other.isInvalidated == isInvalidated &&
        other.status == status &&
        other.fetchStatus == fetchStatus;
  }

  @override
  int get hashCode => Object.hash(
        data,
        dataUpdateCount,
        dataUpdatedAt,
        error,
        errorUpdateCount,
        errorUpdatedAt,
        fetchFailureCount,
        fetchFailureReason,
        _fetchDirection,
        isInvalidated,
        status,
        fetchStatus,
      );

  @override
  String toString() {
    return 'QueryState(status: ${status.name}, fetchStatus: '
        '${fetchStatus.name}, data: $data, error: $error)';
  }
}

/// A state transition applied to a [CachedQuery].
sealed class _QueryAction {
  const _QueryAction();
}

final class _QueryFetchAction extends _QueryAction {
  const _QueryFetchAction(this.direction);
  final _FetchDirection? direction;
}

final class _QuerySuccessAction<TData extends Object> extends _QueryAction {
  const _QuerySuccessAction({
    required this.data,
    this.dataUpdatedAt,
    this.manual = false,
  });
  final TData data;
  final int? dataUpdatedAt;
  final bool manual;
}

final class _QueryErrorAction extends _QueryAction {
  const _QueryErrorAction(this.error);
  final Object error;
}

final class _QueryFailedAction extends _QueryAction {
  const _QueryFailedAction(this.failureCount, this.error);
  final int failureCount;
  final Object error;
}

final class _QueryPauseAction extends _QueryAction {
  const _QueryPauseAction();
}

final class _QueryContinueAction extends _QueryAction {
  const _QueryContinueAction();
}

final class _QueryInvalidateAction extends _QueryAction {
  const _QueryInvalidateAction();
}

final class _QuerySetStateAction<TData extends Object> extends _QueryAction {
  const _QuerySetStateAction(this.state);
  final QueryState<TData> state;
}
