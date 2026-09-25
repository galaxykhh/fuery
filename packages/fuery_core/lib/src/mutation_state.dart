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
/// update. [client] is the client running the mutation.
typedef MutationOnMutate<TVariables, TContext> = FutureOr<TContext?> Function(
  TVariables variables,
  QueryClient client,
);

typedef MutationOnSuccess<TData, TVariables, TContext> = FutureOr<void>
    Function(
  TData data,
  TVariables variables,
  TContext? context,
  QueryClient client,
);

typedef MutationOnError<TVariables, TContext> = FutureOr<void> Function(
  Object error,
  TVariables variables,
  TContext? context,
  QueryClient client,
);

typedef MutationOnSettled<TData, TVariables, TContext> = FutureOr<void>
    Function(
  TData? data,
  Object? error,
  TVariables variables,
  TContext? context,
  QueryClient client,
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

/// What a [MutationObserver] reports: the state of its latest run, with the
/// methods to start another, for example from a builder.
class MutationResult<TData, TVariables, TContext>
    extends MutationState<TData, TVariables, TContext> {
  MutationResult._(
    MutationState<TData, TVariables, TContext> state,
    this._observer,
  ) : super(
          context: state.context,
          data: state.data,
          error: state.error,
          failureCount: state.failureCount,
          failureReason: state.failureReason,
          isPaused: state.isPaused,
          status: state.status,
          variables: state.variables,
          submittedAt: state.submittedAt,
        );

  final MutationObserver<TData, TVariables, TContext> _observer;

  /// The observer that reported this result. An adapter given only a
  /// result, such as a hook given the result of another hook, can listen to
  /// it. Left out of `==`.
  MutationObserver<TData, TVariables, TContext> get observer => _observer;

  /// Runs the mutation without waiting for it, like
  /// [MutationObserver.mutate].
  void mutate(
    TVariables variables, [
    MutateOptions<TData, TVariables, TContext>? options,
  ]) {
    _observer.mutate(variables, options);
  }

  /// Runs the mutation and returns its data, like
  /// [MutationObserver.mutateAsync]. Throws if it fails.
  Future<TData> mutateAsync(
    TVariables variables, [
    MutateOptions<TData, TVariables, TContext>? options,
  ]) {
    return _observer.mutateAsync(variables, options);
  }

  /// Goes back to idle, like [MutationObserver.reset].
  void reset() => _observer.reset();
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

/// Describes a mutation: what it runs and what happens around it.
///
/// ```dart
/// final addTodo = Mutation(
///   mutationFn: (String title) => api.addTodo(title),
///   onSuccess: (todo, title, context, client) =>
///       client.invalidateQueries(queryKey: ['todos']),
/// );
/// ```
class Mutation<TData, TVariables, TContext extends Object?>
    implements
        MutationSource<TData, TVariables, TContext>,
        MutationStateSource<TData, TVariables, TContext> {
  const Mutation({
    required this.mutationFn,
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

  const Mutation._defaulted({
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

  final MutationFn<TData, TVariables> mutationFn;
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

  /// Returns an observer that runs this mutation, with [Fuery.client] unless
  /// [client] is given. Each observer keeps the state of its own latest run.
  ///
  /// The same options can also be passed to [QueryClient.restore], so a
  /// persisted mutation is defined once:
  ///
  /// ```dart
  /// final addComment = addCommentMutation().observe();
  /// ```
  MutationObserver<TData, TVariables, TContext> observe({QueryClient? client}) {
    return MutationObserver<TData, TVariables, TContext>(
      client ?? Fuery.client,
      this,
    );
  }

  /// Whether [other] configures the mutation the same way, as far as
  /// anything watching the cache can tell. [sameKeyHash] tells whether the
  /// keys have the same hash, which the observer knows. Functions and codecs
  /// are compared only by whether they are set, like [Query]; the observer
  /// uses the latest ones either way.
  bool _sameConfig(
    Mutation<TData, TVariables, TContext>? other, {
    required bool sameKeyHash,
  }) {
    bool sameSet(Object? a, Object? b) => (a == null) == (b == null);
    return other != null &&
        sameKeyHash &&
        gcTime == other.gcTime &&
        networkMode == other.networkMode &&
        const DeepCollectionEquality().equals(meta, other.meta) &&
        scope?.id == other.scope?.id &&
        sameSet(mutationFn, other.mutationFn) &&
        sameSet(retry, other.retry) &&
        sameSet(retryDelay, other.retryDelay) &&
        sameSet(onMutate, other.onMutate) &&
        sameSet(onSuccess, other.onSuccess) &&
        sameSet(onError, other.onError) &&
        sameSet(onSettled, other.onSettled) &&
        sameSet(persist, other.persist);
  }

  Mutation<TData, TVariables, TContext> _withDefaults(
    MutationDefaults defaults,
  ) {
    return Mutation<TData, TVariables, TContext>._defaulted(
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
  AnyCachedMutation _restore(
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

/// Describes a mutation that takes no variables. Its observer runs it with
/// `mutate()`, and its callbacks leave the variables out.
///
/// ```dart
/// final logout = NoVariablesMutation(mutationFn: () => api.logout());
/// ```
class NoVariablesMutation<TData, TContext extends Object?>
    extends Mutation<TData, void, TContext> {
  NoVariablesMutation({
    required Future<TData> Function() mutationFn,
    super.mutationKey,
    FutureOr<TContext?> Function(QueryClient client)? onMutate,
    FutureOr<void> Function(TData data, TContext? context, QueryClient client)?
        onSuccess,
    FutureOr<void> Function(
      Object error,
      TContext? context,
      QueryClient client,
    )? onError,
    FutureOr<void> Function(
      TData? data,
      Object? error,
      TContext? context,
      QueryClient client,
    )? onSettled,
    super.gcTime,
    super.retry,
    super.retryDelay,
    super.networkMode,
    super.scope,
    super.meta,
    super.persist,
  }) : super(
          mutationFn: (_) => mutationFn(),
          onMutate: onMutate == null ? null : (_, client) => onMutate(client),
          onSuccess: onSuccess == null
              ? null
              : (data, _, context, client) => onSuccess(data, context, client),
          onError: onError == null
              ? null
              : (error, _, context, client) => onError(error, context, client),
          onSettled: onSettled == null
              ? null
              : (data, error, _, context, client) =>
                  onSettled(data, error, context, client),
        );

  /// Returns an observer that runs this mutation with `mutate()`.
  @override
  NoVariablesMutationObserver<TData, TContext> observe({QueryClient? client}) {
    return NoVariablesMutationObserver<TData, TContext>(
      client ?? Fuery.client,
      this,
    );
  }
}

/// Callbacks for a single `mutate` call, run after the mutation's own
/// callbacks. A later `mutate` call on the same observer replaces them, and
/// `reset()` drops them, as does unmounting the widget that owns the
/// observer. Check `context.mounted` before using a `BuildContext` in them.
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

@Deprecated('Use Mutation.')
typedef MutationOptions<TData, TVariables, TContext extends Object?>
    = Mutation<TData, TVariables, TContext>;
