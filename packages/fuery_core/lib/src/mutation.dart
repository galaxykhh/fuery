part of 'core.dart';

/// A single execution of a mutation, stored in the [MutationCache].
///
/// Application code usually works with a [MutationObserver] from
/// [Mutation.use].
class Mutation<TData, TVariables, TContext> extends _Removable {
  Mutation._({
    required MutationCache mutationCache,
    required this.mutationId,
    required MutationOptions<TData, TVariables, TContext> options,
  }) : _mutationCache = mutationCache {
    _setOptions(options);
    _scheduleGc();
  }

  /// Creates an observer for a mutation that takes [TVariables].
  ///
  /// ```dart
  /// final addTodo = Mutation.use(
  ///   mutationFn: (String title) => api.addTodo(title),
  ///   onSuccess: (todo, title, context) {
  ///     Fuery.client.invalidateQueries(queryKey: ['todos']);
  ///   },
  /// );
  ///
  /// addTodo.mutate('Buy milk');
  /// ```
  static MutationObserver<TData, TVariables, TContext>
      use<TData, TVariables, TContext extends Object?>({
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
  static NoParamMutationObserver<TData, TContext>
      noParam<TData, TContext extends Object?>({
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
  bool _removed = false;
  final MutationCache _mutationCache;
  final List<MutationObserver<TData, TVariables, TContext>> _observers = [];
  late MutationOptions<TData, TVariables, TContext> _options;
  var _state = MutationState<TData, TVariables, TContext>();
  Retryer<TData>? _retryer;

  MutationOptions<TData, TVariables, TContext> get options => _options;

  MutationState<TData, TVariables, TContext> get state => _state;

  Map<String, Object?>? get meta => _options.meta;

  void _setOptions(MutationOptions<TData, TVariables, TContext> options) {
    _options = options;
    _updateGcTime(_options.gcTime);
  }

  void _addObserver(MutationObserver<TData, TVariables, TContext> observer) {
    if (_observers.contains(observer)) return;
    _observers.add(observer);
    _clearGcTimeout();
    _mutationCache._notify();
  }

  void _removeObserver(MutationObserver<TData, TVariables, TContext> observer) {
    _observers.remove(observer);
    _scheduleGc();
    _mutationCache._notify();
  }

  @override
  void _destroy() {
    super._destroy();
    // A removed mutation doesn't wait to retry; the current attempt finishes.
    _retryer?.stopRetrying();
  }

  @override
  void _scheduleGc() {
    // Once removed from the cache, there is nothing left to collect.
    if (!_removed) super._scheduleGc();
  }

  @override
  void _optionalRemove() {
    // A pending mutation is collected once it settles, see _execute.
    if (_observers.isNotEmpty || _state.status == MutationStatus.pending) {
      return;
    }
    _mutationCache._remove(this);
  }

  /// Resumes a paused mutation.
  Future<Object?> _resume() => _retryer?.resume() ?? Future.value();

  Future<TData> _execute(TVariables variables) async {
    final retryer = _retryer = Retryer<TData>(
      fn: () {
        final mutationFn = _options.mutationFn;
        if (mutationFn == null) {
          return Future.error(StateError('No mutationFn found'));
        }
        return mutationFn(variables);
      },
      onFail: (failureCount, error) {
        _dispatch(_MutationFailedAction(failureCount, error));
      },
      onPause: () => _dispatch(const _MutationPauseAction()),
      onContinue: () => _dispatch(const _MutationContinueAction()),
      retry: _options.retry ?? const RetryPolicy.never(),
      retryDelay: _options.retryDelay,
      networkMode: _options.networkMode,
      canRun: () => _mutationCache._canRun(this),
    );

    final isPaused = !retryer.canStart();
    final cacheConfig = _mutationCache.config;

    try {
      _dispatch(_MutationPendingAction(
        isPaused: isPaused,
        variables: variables,
      ));
      await cacheConfig.onMutate?.call(variables, this);
      final context = await _options.onMutate?.call(variables);
      if (context != _state.context) {
        _dispatch(_MutationPendingAction(
          isPaused: isPaused,
          variables: variables,
          context: context,
        ));
      }

      // The scope or network may have freed up during onMutate.
      if (_state.isPaused && retryer.canStart()) {
        _dispatch(const _MutationContinueAction());
      }
      final data = await retryer.start();

      await cacheConfig.onSuccess?.call(data, variables, _state.context, this);
      await _options.onSuccess?.call(data, variables, _state.context);
      await cacheConfig.onSettled
          ?.call(data, null, _state.variables, _state.context, this);
      await _options.onSettled?.call(data, null, variables, _state.context);

      _dispatch(_MutationSuccessAction(data));
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

      _dispatch(_MutationErrorAction(error));
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (identical(_retryer, retryer)) _retryer = null;
      if (_observers.isEmpty) _scheduleGc();
      _mutationCache._runNext(this);
    }
  }

  void _dispatch(_MutationAction action) {
    _state = switch (action) {
      _MutationFailedAction(:final failureCount, :final error) =>
        _state.copyWith(failureCount: failureCount, failureReason: error),
      _MutationPauseAction() => _state.copyWith(isPaused: true),
      _MutationContinueAction() => _state.copyWith(isPaused: false),
      _MutationPendingAction(
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
      _MutationSuccessAction(:final data) => _state.copyWith(
          data: data,
          failureCount: 0,
          failureReason: null,
          error: null,
          status: MutationStatus.success,
          isPaused: false,
        ),
      _MutationErrorAction(:final error) => _state.copyWith(
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
      _mutationCache._notify();
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
