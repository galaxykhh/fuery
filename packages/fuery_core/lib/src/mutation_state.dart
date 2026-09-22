part of 'core.dart';

enum MutationStatus {
  idle,
  pending,
  success,
  error;

  bool get isIdle => this == idle;
  bool get isPending => this == pending;
  bool get isSuccess => this == success;
  bool get isError => this == error;
}

typedef MutationFn<TData, TVariables> = Future<TData> Function(
  TVariables variables,
);

/// Runs before the mutation function. The returned value is passed as
/// `context` to the other callbacks, for example to roll back an optimistic
/// update.
typedef MutationOnMutate<TVariables, TContext> = FutureOr<TContext?> Function(
  TVariables variables,
);

typedef MutationOnSuccess<TData, TVariables, TContext> = FutureOr<void>
    Function(TData data, TVariables variables, TContext? context);

typedef MutationOnError<TVariables, TContext> = FutureOr<void> Function(
  Object error,
  TVariables variables,
  TContext? context,
);

typedef MutationOnSettled<TData, TVariables, TContext> = FutureOr<void>
    Function(
  TData? data,
  Object? error,
  TVariables variables,
  TContext? context,
);

/// Mutations with the same scope id run one after another.
@immutable
class MutationScope {
  const MutationScope(this.id);
  final String id;
}

@immutable
class MutationState<TData, TVariables, TContext> {
  const MutationState({
    this.context,
    this.data,
    this.error,
    this.failureCount = 0,
    this.failureReason,
    this.isPaused = false,
    this.status = MutationStatus.idle,
    this.variables,
    this.submittedAt = 0,
  });

  /// What `onMutate` returned.
  final TContext? context;
  final TData? data;
  final Object? error;
  final int failureCount;
  final Object? failureReason;

  /// Waiting for the network before running.
  final bool isPaused;
  final MutationStatus status;
  final TVariables? variables;

  /// When the mutation was submitted, in milliseconds since epoch.
  final int submittedAt;

  bool get isIdle => status == MutationStatus.idle;
  bool get isPending => status == MutationStatus.pending;
  bool get isSuccess => status == MutationStatus.success;
  bool get isError => status == MutationStatus.error;

  MutationState<TData, TVariables, TContext> copyWith({
    Object? context = _undefined,
    Object? data = _undefined,
    Object? error = _undefined,
    int? failureCount,
    Object? failureReason = _undefined,
    bool? isPaused,
    MutationStatus? status,
    Object? variables = _undefined,
    int? submittedAt,
  }) {
    return MutationState<TData, TVariables, TContext>(
      context:
          identical(context, _undefined) ? this.context : context as TContext?,
      data: identical(data, _undefined) ? this.data : data as TData?,
      error: identical(error, _undefined) ? this.error : error,
      failureCount: failureCount ?? this.failureCount,
      failureReason: identical(failureReason, _undefined)
          ? this.failureReason
          : failureReason,
      isPaused: isPaused ?? this.isPaused,
      status: status ?? this.status,
      variables: identical(variables, _undefined)
          ? this.variables
          : variables as TVariables?,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MutationState<TData, TVariables, TContext> &&
        other.context == context &&
        other.data == data &&
        other.error == error &&
        other.failureCount == failureCount &&
        other.failureReason == failureReason &&
        other.isPaused == isPaused &&
        other.status == status &&
        other.variables == variables &&
        other.submittedAt == submittedAt;
  }

  @override
  int get hashCode => Object.hash(
        context,
        data,
        error,
        failureCount,
        failureReason,
        isPaused,
        status,
        variables,
        submittedAt,
      );

  @override
  String toString() {
    return 'MutationState(status: ${status.name}, data: $data, '
        'error: $error, variables: $variables)';
  }
}

/// Default values for mutation options.
@immutable
class MutationDefaults {
  const MutationDefaults({
    this.gcTime,
    this.retry,
    this.retryDelay,
    this.networkMode,
    this.meta,
  });

  final Duration? gcTime;
  final RetryPolicy? retry;
  final RetryDelay? retryDelay;
  final NetworkMode? networkMode;
  final Map<String, Object?>? meta;

  MutationDefaults merge(MutationDefaults? other) {
    if (other == null) return this;
    return MutationDefaults(
      gcTime: other.gcTime ?? gcTime,
      retry: other.retry ?? retry,
      retryDelay: other.retryDelay ?? retryDelay,
      networkMode: other.networkMode ?? networkMode,
      meta: other.meta ?? meta,
    );
  }
}

class MutationOptions<TData, TVariables, TContext> {
  const MutationOptions({
    this.mutationFn,
    this.mutationKey,
    this.gcTime,
    this.retry,
    this.retryDelay,
    this.networkMode,
    this.meta,
    this.scope,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.persist,
  })  : assert(
          persist == null || mutationKey != null,
          'A persisted mutation needs a mutationKey, so restore can find it',
        ),
        _defaulted = false;

  const MutationOptions._defaulted({
    required this.mutationFn,
    required this.mutationKey,
    required this.gcTime,
    required this.retry,
    required this.retryDelay,
    required this.networkMode,
    required this.meta,
    required this.scope,
    required this.onMutate,
    required this.onSuccess,
    required this.onError,
    required this.onSettled,
    required this.persist,
  }) : _defaulted = true;

  final MutationFn<TData, TVariables>? mutationFn;
  final MutationKey? mutationKey;

  /// How long a finished, unobserved mutation stays in the cache.
  final Duration? gcTime;

  /// Mutations do not retry unless set.
  final RetryPolicy? retry;
  final RetryDelay? retryDelay;
  final NetworkMode? networkMode;
  final Map<String, Object?>? meta;
  final MutationScope? scope;
  final MutationOnMutate<TVariables, TContext>? onMutate;
  final MutationOnSuccess<TData, TVariables, TContext>? onSuccess;
  final MutationOnError<TVariables, TContext>? onError;
  final MutationOnSettled<TData, TVariables, TContext>? onSettled;

  /// Stores the variables while the mutation runs, so it can be restored
  /// after a restart. Needs [mutationKey].
  final MutationPersist<TVariables>? persist;

  final bool _defaulted;

  /// Whether every option is equal, comparing functions with `==`.
  bool _sameAs(MutationOptions<TData, TVariables, TContext>? other) {
    return other != null &&
        mutationFn == other.mutationFn &&
        _keyHash(mutationKey) == _keyHash(other.mutationKey) &&
        gcTime == other.gcTime &&
        retry == other.retry &&
        retryDelay == other.retryDelay &&
        networkMode == other.networkMode &&
        meta == other.meta &&
        scope?.id == other.scope?.id &&
        onMutate == other.onMutate &&
        onSuccess == other.onSuccess &&
        onError == other.onError &&
        onSettled == other.onSettled &&
        persist == other.persist;
  }

  static String? _keyHash(MutationKey? key) =>
      key == null ? null : hashKey(key);

  MutationOptions<TData, TVariables, TContext> _withDefaults(
    MutationDefaults defaults,
  ) {
    return MutationOptions<TData, TVariables, TContext>._defaulted(
      mutationFn: mutationFn,
      mutationKey: mutationKey,
      gcTime: gcTime ?? defaults.gcTime,
      retry: retry ?? defaults.retry,
      retryDelay: retryDelay ?? defaults.retryDelay,
      networkMode: networkMode ?? defaults.networkMode,
      meta: meta ?? defaults.meta,
      scope: scope,
      onMutate: onMutate,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
      persist: persist,
    );
  }

  /// Runs a mutation stored by a previous run with these options. It is
  /// typed here, where [TVariables] is known, so the decoded variables reach
  /// [mutationFn] and the callbacks with their real types.
  AnyMutation _restore(
    QueryClient client,
    String storageKey,
    Object? variablesJson,
    int submittedAt,
  ) {
    final variables = persist!._decode(variablesJson);
    final mutation = client.mutationCache._build<TData, TVariables, TContext>(
      client,
      this,
    );
    mutation._execute(
      variables,
      restored: (storageKey: storageKey, submittedAt: submittedAt),
    ).ignore();
    return mutation;
  }
}

/// Callbacks for a single `mutate` call. They only run while the observer
/// that started the mutation still has listeners.
@immutable
class MutateOptions<TData, TVariables, TContext> {
  const MutateOptions({this.onSuccess, this.onError, this.onSettled});

  final MutationOnSuccess<TData, TVariables, TContext>? onSuccess;
  final MutationOnError<TVariables, TContext>? onError;
  final MutationOnSettled<TData, TVariables, TContext>? onSettled;
}

sealed class _MutationAction {
  const _MutationAction();
}

final class _MutationFailedAction extends _MutationAction {
  const _MutationFailedAction(this.failureCount, this.error);
  final int failureCount;
  final Object error;
}

final class _MutationPendingAction extends _MutationAction {
  const _MutationPendingAction({
    required this.isPaused,
    required this.variables,
    this.context,
    this.submittedAt,
  });
  final bool isPaused;
  final Object? variables;
  final Object? context;

  /// Kept from the run that stored the mutation; null means now.
  final int? submittedAt;
}

final class _MutationSuccessAction extends _MutationAction {
  const _MutationSuccessAction(this.data);
  final Object? data;
}

final class _MutationErrorAction extends _MutationAction {
  const _MutationErrorAction(this.error);
  final Object error;
}

final class _MutationPauseAction extends _MutationAction {
  const _MutationPauseAction();
}

final class _MutationContinueAction extends _MutationAction {
  const _MutationContinueAction();
}
