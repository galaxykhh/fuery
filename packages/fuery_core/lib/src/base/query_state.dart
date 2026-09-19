import 'package:fuery_core/src/util/timestamp.dart';

enum QueryStatus {
  idle,
  pending,
  failure,
  success;

  bool get isIdle => this == idle;
  bool get isPending => this == pending;
  bool get isFailure => this == failure;
  bool get isSuccess => this == success;
}

enum FetchStatus {
  idle,
  fetching,
  refetching;

  bool get isIdle => this == idle;
  bool get isFetching => this == fetching;
  bool get isRefetching => this == refetching;
}

abstract class QueryStateBase<Data, Err> {
  QueryStateBase({
    this.data,
    this.error,
    required this.status,
    required this.fetchStatus,
    required this.updatedAt,
    required this.invalidated,
  });

  final Data? data;
  final Err? error;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final bool invalidated;
  final Timestamp updatedAt;

  bool get isSuccess => status.isSuccess;

  bool get isPending => status.isPending;

  bool get isFetching => fetchStatus.isFetching;

  bool get isLoading => isPending || isFetching;

  bool get isRefetching => fetchStatus.isRefetching;

  bool get isError => error != null;

  @override
  String toString() {
    return 'data: $data, error: $error, status: $status, fetchStatus: $fetchStatus, invalidated: $invalidated, updatedAt: $updatedAt';
  }
}
