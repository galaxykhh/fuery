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

enum FetchDirection { forward, backward }

/// Metadata attached to a fetch, such as the direction of an infinite query
/// page fetch.
@immutable
class FetchMeta {
  const FetchMeta({this.direction});

  final FetchDirection? direction;

  @override
  bool operator ==(Object other) =>
      other is FetchMeta && other.direction == direction;

  @override
  int get hashCode => direction.hashCode;
}

/// The raw state stored in a [Query]. Observers derive [QueryResult]s from it.
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
    this.fetchMeta,
    this.isInvalidated = false,
    this.status = QueryStatus.pending,
    this.fetchStatus = FetchStatus.idle,
  });

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

  /// Metadata of the in-flight or most recent fetch.
  final FetchMeta? fetchMeta;

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
    Object? fetchMeta = _undefined,
    bool? isInvalidated,
    QueryStatus? status,
    FetchStatus? fetchStatus,
  }) {
    return QueryState<TData>(
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
      fetchMeta: identical(fetchMeta, _undefined)
          ? this.fetchMeta
          : fetchMeta as FetchMeta?,
      isInvalidated: isInvalidated ?? this.isInvalidated,
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
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
        other.fetchMeta == fetchMeta &&
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
        fetchMeta,
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

/// A state transition applied to a [Query]. Delivered to cache listeners in
/// [QueryUpdatedEvent].
sealed class QueryAction {
  const QueryAction();
}

final class QueryFetchAction extends QueryAction {
  const QueryFetchAction(this.meta);
  final FetchMeta? meta;
}

final class QuerySuccessAction<TData extends Object> extends QueryAction {
  const QuerySuccessAction({
    required this.data,
    this.dataUpdatedAt,
    this.manual = false,
  });
  final TData data;
  final int? dataUpdatedAt;
  final bool manual;
}

final class QueryErrorAction extends QueryAction {
  const QueryErrorAction(this.error);
  final Object error;
}

final class QueryFailedAction extends QueryAction {
  const QueryFailedAction(this.failureCount, this.error);
  final int failureCount;
  final Object error;
}

final class QueryPauseAction extends QueryAction {
  const QueryPauseAction();
}

final class QueryContinueAction extends QueryAction {
  const QueryContinueAction();
}

final class QueryInvalidateAction extends QueryAction {
  const QueryInvalidateAction();
}

final class QuerySetStateAction<TData extends Object> extends QueryAction {
  const QuerySetStateAction(this.state);
  final QueryState<TData> state;
}
