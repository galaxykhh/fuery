enum MutationStatus {
  idle,
  pending,
  failure,
  success;

  bool get isIdle => this == idle;
  bool get isPending => this == pending;
  bool get isFailure => this == failure;
  bool get isSuccess => this == success;
}

abstract class MutationStateBase<Data, Err> {
  MutationStateBase({
    this.data,
    this.error,
    required this.status,
  });

  final Data? data;
  final Err? error;
  final MutationStatus status;
}
