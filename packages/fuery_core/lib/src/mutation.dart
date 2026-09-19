part of 'core.dart';

/// A single execution of a mutation, stored in the [MutationCache].
///
/// Application code usually works with a [MutationObserver] from
/// [Mutation.use].
class Mutation<TData, TVariables, TContext> extends Removable {
  Mutation._({
    required MutationCache mutationCache,
    required this.mutationId,
    required MutationOptions<TData, TVariables, TContext> options,
    MutationState<TData, TVariables, TContext>? state,
  })  : _mutationCache = mutationCache,
        _state = state ?? MutationState<TData, TVariables, TContext>() {
    setOptions(options);
    scheduleGc();
  }

  /// Creates an observer for a mutation that takes [TVariables].
  ///
  /// ```dart
  /// late final addTodo = Mutation.use(
  ///   mutationFn: (String title) => api.addTodo(title),
  ///   onSuccess: (todo, title, context) {
  ///     Fuery.client.invalidateQueries(queryKey: ['todos']);
  ///   },
  /// );
  ///
  /// addTodo.mutate('Buy milk');
  /// ```
  static MutationObserver<TData, TVariables, TContext>
      use<TData, TVariables, TContext>({
    required MutationFn<TData, TVariables> mutationFn,
    MutationKey? mutationKey,
    MutationOnMutate<TVariables, TContext>? onMutate,
    MutationOnSuccess<TData, TVariables, TContext>? onSuccess,
    MutationOnError<TVariables, TContext>? onError,
    MutationOnSettled<TData, TVariables, TContext>? onSettled,
    Duration? gcTime,
    RetryPolicy? retry,
    RetryDelay? retryDelay,
    NetworkMode? networkMode,
    MutationScope? scope,
    Map<String, Object?>? meta,
    QueryClient? client,
  }) {
    return MutationObserver<TData, TVariables, TContext>(
      client ?? Fuery.client,
      MutationOptions<TData, TVariables, TContext>(
        mutationFn: mutationFn,
        mutationKey: mutationKey,
        onMutate: onMutate,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        gcTime: gcTime,
        retry: retry,
        retryDelay: retryDelay,
        networkMode: networkMode,
        scope: scope,
        meta: meta,
      ),
    );
  }

  /// Creates an observer for a mutation without variables, so it can be
  /// called as `mutate()`.
  static NoParamMutationObserver<TData, TContext> noParam<TData, TContext>({
    required Future<TData> Function() mutationFn,
    MutationKey? mutationKey,
    FutureOr<TContext?> Function()? onMutate,
    FutureOr<void> Function(TData data, TContext? context)? onSuccess,
    FutureOr<void> Function(Object error, TContext? context)? onError,
    FutureOr<void> Function(TData? data, Object? error, TContext? context)?
        onSettled,
    Duration? gcTime,
    RetryPolicy? retry,
    RetryDelay? retryDelay,
    NetworkMode? networkMode,
    MutationScope? scope,
    Map<String, Object?>? meta,
    QueryClient? client,
  }) {
    return NoParamMutationObserver<TData, TContext>(
      client ?? Fuery.client,
      MutationOptions<TData, void, TContext>(
        mutationFn: (_) => mutationFn(),
        mutationKey: mutationKey,
        onMutate: onMutate == null ? null : (_) => onMutate(),
        onSuccess: onSuccess == null
            ? null
            : (data, _, context) => onSuccess(data, context),
        onError: onError == null
            ? null
            : (error, _, context) => onError(error, context),
        onSettled: onSettled == null
            ? null
            : (data, error, _, context) => onSettled(data, error, context),
        gcTime: gcTime,
        retry: retry,
        retryDelay: retryDelay,
        networkMode: networkMode,
        scope: scope,
        meta: meta,
      ),
    );
  }

  final int mutationId;
  final MutationCache _mutationCache;
  final List<MutationObserver<TData, TVariables, TContext>> _observers = [];
  late MutationOptions<TData, TVariables, TContext> _options;
  MutationState<TData, TVariables, TContext> _state;
  Retryer<TData>? _retryer;

  MutationOptions<TData, TVariables, TContext> get options => _options;

  MutationState<TData, TVariables, TContext> get state => _state;

  Map<String, Object?>? get meta => _options.meta;

  void setOptions(MutationOptions<TData, TVariables, TContext> options) {
    _options = options;
    updateGcTime(_options.gcTime);
  }

  void _addObserver(MutationObserver<TData, TVariables, TContext> observer) {
    if (_observers.contains(observer)) return;
    _observers.add(observer);
    clearGcTimeout();
    _mutationCache.notify(MutationObserverAddedEvent(this, observer));
  }

  void _removeObserver(MutationObserver<TData, TVariables, TContext> observer) {
    _observers.remove(observer);
    scheduleGc();
    _mutationCache.notify(MutationObserverRemovedEvent(this, observer));
  }

  @override
  @protected
  void optionalRemove() {
    if (_observers.isNotEmpty) return;
    if (_state.status == MutationStatus.pending) {
      scheduleGc();
    } else {
      _mutationCache.remove(this);
    }
  }

  /// Resumes a paused mutation.
  Future<Object?> resume() {
    final retryer = _retryer;
    if (retryer != null) return retryer.resume();
    if (_state.status == MutationStatus.pending) {
      return execute(_state.variables as TVariables);
    }
    return Future.value();
  }

  Future<TData> execute(TVariables variables) async {
    void onContinue() => _dispatch(const MutationContinueAction());

    final retryer = _retryer = Retryer<TData>(
      fn: () {
        final mutationFn = _options.mutationFn;
        if (mutationFn == null) {
          return Future.error(StateError('No mutationFn found'));
        }
        return mutationFn(variables);
      },
      onFail: (failureCount, error) {
        _dispatch(MutationFailedAction(failureCount, error));
      },
      onPause: () => _dispatch(const MutationPauseAction()),
      onContinue: onContinue,
      retry: _options.retry ?? const RetryPolicy.never(),
      retryDelay: _options.retryDelay,
      networkMode: _options.networkMode,
      canRun: () => _mutationCache.canRun(this),
    );

    final restored = _state.status == MutationStatus.pending;
    final isPaused = !retryer.canStart();
    final cacheConfig = _mutationCache.config;

    try {
      if (restored) {
        onContinue();
      } else {
        _dispatch(MutationPendingAction(
          isPaused: isPaused,
          variables: variables,
        ));
        await cacheConfig.onMutate?.call(variables, this);
        final context = await _options.onMutate?.call(variables);
        if (context != _state.context) {
          _dispatch(MutationPendingAction(
            isPaused: isPaused,
            variables: variables,
            context: context,
          ));
        }
      }

      final data = await retryer.start();

      await cacheConfig.onSuccess?.call(data, variables, _state.context, this);
      await _options.onSuccess?.call(data, variables, _state.context);
      await cacheConfig.onSettled
          ?.call(data, null, _state.variables, _state.context, this);
      await _options.onSettled?.call(data, null, variables, _state.context);

      _dispatch(MutationSuccessAction(data));
      return data;
    } catch (error, stackTrace) {
      // Errors thrown by the error callbacks must not hide the mutation error.
      await _guard(
        () => cacheConfig.onError?.call(error, variables, _state.context, this),
      );
      await _guard(
        () => _options.onError?.call(error, variables, _state.context),
      );
      await _guard(
        () => cacheConfig.onSettled?.call(
          null,
          error,
          _state.variables,
          _state.context,
          this,
        ),
      );
      await _guard(
        () => _options.onSettled?.call(null, error, variables, _state.context),
      );

      _dispatch(MutationErrorAction(error));
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (identical(_retryer, retryer)) _retryer = null;
      _mutationCache.runNext(this);
    }
  }

  void _dispatch(MutationAction action) {
    _state = switch (action) {
      MutationFailedAction(:final failureCount, :final error) =>
        _state.copyWith(failureCount: failureCount, failureReason: error),
      MutationPauseAction() => _state.copyWith(isPaused: true),
      MutationContinueAction() => _state.copyWith(isPaused: false),
      MutationPendingAction(
        :final isPaused,
        :final variables,
        :final context
      ) =>
        _state.copyWith(
          context: context,
          data: null,
          failureCount: 0,
          failureReason: null,
          error: null,
          isPaused: isPaused,
          status: MutationStatus.pending,
          variables: variables,
          submittedAt: now(),
        ),
      MutationSuccessAction(:final data) => _state.copyWith(
          data: data,
          failureCount: 0,
          failureReason: null,
          error: null,
          status: MutationStatus.success,
          isPaused: false,
        ),
      MutationErrorAction(:final error) => _state.copyWith(
          data: null,
          error: error,
          failureCount: _state.failureCount + 1,
          failureReason: error,
          isPaused: false,
          status: MutationStatus.error,
        ),
    };

    notifyManager.batch(() {
      for (final observer in _observers.toList()) {
        observer._onMutationUpdate(action);
      }
      _mutationCache.notify(MutationUpdatedEvent(this, action));
    });
  }

  @override
  String toString() => 'Mutation($mutationId, ${_state.status.name})';
}

Future<void> _guard(FutureOr<void> Function() callback) async {
  try {
    await callback();
  } catch (error, stackTrace) {
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}
