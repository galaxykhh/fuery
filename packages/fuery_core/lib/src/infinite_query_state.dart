import 'package:fuery_core/src/base/query_state.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:fuery_core/src/util/timestamp.dart';

class InfiniteQueryState<Data, Err> extends QueryState<Data, Err> {
  InfiniteQueryState({
    super.data,
    super.error,
    required super.status,
    required super.fetchStatus,
    required super.invalidated,
    required super.updatedAt,
    this.nextPageStatus = QueryStatus.idle,
    this.previousPageStatus = QueryStatus.idle,
  });

  final QueryStatus nextPageStatus;
  final QueryStatus previousPageStatus;

  InfiniteQueryState<Data, Err> copyWith({
    ValueGetter<Data>? data,
    ValueGetter<Err>? error,
    QueryStatus? status,
    FetchStatus? fetchStatus,
    bool? invalidated,
    QueryStatus? nextPageStatus,
    QueryStatus? previousPageStatus,
  }) {
    return InfiniteQueryState<Data, Err>(
      data: data != null ? data() : this.data,
      error: error != null ? error() : this.error,
      status: status ?? this.status,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      invalidated: invalidated ?? this.invalidated,
      updatedAt: data != null ? Timestamp.now() : updatedAt,
      nextPageStatus: nextPageStatus ?? this.nextPageStatus,
      previousPageStatus: previousPageStatus ?? this.previousPageStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InfiniteQueryState<Data, Err> &&
        other.data == data &&
        other.error == error &&
        other.status == status &&
        other.fetchStatus == fetchStatus &&
        other.invalidated == invalidated &&
        other.updatedAt == updatedAt &&
        other.nextPageStatus == nextPageStatus &&
        other.previousPageStatus == previousPageStatus;
  }

  @override
  int get hashCode =>
      data.hashCode ^
      error.hashCode ^
      status.hashCode ^
      fetchStatus.hashCode ^
      invalidated.hashCode ^
      updatedAt.hashCode ^
      nextPageStatus.hashCode ^
      previousPageStatus.hashCode;
}
