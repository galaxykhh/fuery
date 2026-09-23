part of 'core.dart';

/// A single execution of a mutation, stored in the [MutationCache].
///
/// Application code usually works with a [MutationObserver] from
/// [Mutation.observe].
class CachedMutation<TData, TVariables, TContext> extends _Removable {
  CachedMutation._({
    required QueryClient client,
    required MutationCache mutationCache,
    required this.mutationId,
    required Mutation<TData, TVariables, TContext> options,
  })  : _client = client,
        _mutationCache = mutationCache {
    _setOptions(options);
    _scheduleGc();
  }

  final int mutationId;
  bool _removed = false;
  final QueryClient _client;
  final MutationCache _mutationCache;

  /// Where the variables are stored while the mutation runs, if they are.
  String? _storageKey;

  /// The write in flight, so the delete after settling can wait for it.
  Future<void>? _storeWrite;
  final List<MutationObserver<TData, TVariables, TContext>> _observers = [];
  late Mutation<TData, TVariables, TContext> _options;
  var _state = MutationState<TData, TVariables, TContext>();
  Retryer<TData>? _retryer;

  Mutation<TData, TVariables, TContext> get options => _options;

  MutationState<TData, TVariables, TContext> get state => _state;

  Map<String, Object?>? get meta => _options.meta;

  void _setOptions(Mutation<TData, TVariables, TContext> options) {
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

  /// Runs the mutation. A [restored] mutation was stored by a previous run:
  /// it is already stored under `storageKey`, keeps its `submittedAt`, and
  /// skips `onMutate`, whose work belongs to the run that submitted it.
  ///
  /// [onCallSettled] gets the result of this run first, before observers
  /// hear of it, for the callbacks of the `mutate` call that started it.
  Future<TData> _execute(
    TVariables variables, {
    ({String storageKey, int submittedAt})? restored,
    void Function(TData? data, Object? error)? onCallSettled,
  }) async {
    final retryer = _retryer = Retryer<TData>(
      fn: () => _options.mutationFn(variables),
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
        submittedAt: restored?.submittedAt,
      ));
      if (restored != null) {
        _storageKey = restored.storageKey;
      } else {
        _writeStored();
        await cacheConfig.onMutate?.call(variables, this);
        final context = await _options.onMutate?.call(variables, _client);
        if (context != _state.context) {
          _dispatch(_MutationPendingAction(
            isPaused: isPaused,
            variables: variables,
            context: context,
          ));
        }
      }

      // The scope or network may have freed up during onMutate.
      if (_state.isPaused && retryer.canStart()) {
        _dispatch(const _MutationContinueAction());
      }
      final data = await retryer.start();

      await cacheConfig.onSuccess?.call(data, variables, _state.context, this);
      await _options.onSuccess?.call(
        data,
        variables,
        _state.context,
        _client,
      );
      await cacheConfig.onSettled
          ?.call(data, null, _state.variables, _state.context, this);
      await _options.onSettled?.call(
        data,
        null,
        variables,
        _state.context,
        _client,
      );

      _dispatch(
        _MutationSuccessAction(data),
        onCallSettled == null ? null : () => onCallSettled(data, null),
      );
      return data;
    } catch (error, stackTrace) {
      // Errors thrown by the error callbacks must not hide the mutation error.
      await _guard(
        () => cacheConfig.onError?.call(error, variables, _state.context, this),
      );
      await _guard(
        () => _options.onError?.call(
          error,
          variables,
          _state.context,
          _client,
        ),
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
        () => _options.onSettled?.call(
          null,
          error,
          variables,
          _state.context,
          _client,
        ),
      );

      _dispatch(
        _MutationErrorAction(error),
        onCallSettled == null ? null : () => onCallSettled(null, error),
      );
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (identical(_retryer, retryer)) _retryer = null;
      _deleteStored();
      if (_observers.isEmpty) _scheduleGc();
      _mutationCache._runNext(this);
    }
  }

  /// Stores the variables under a key of its own, so every run of the
  /// mutation is restored separately and in submission order.
  void _writeStored() {
    final storage = _client.storage;
    final persist = _options.persist;
    final mutationKey = _options.mutationKey;
    if (storage == null || persist == null || mutationKey == null) return;
    final key = '$_mutationKeyPrefix${_state.submittedAt}:$mutationId';
    final String value;
    try {
      value = jsonEncode({
        'v': persist.version,
        'k': mutationKey,
        't': _state.submittedAt,
        'd': persist._encode(_state.variables as TVariables),
      });
    } catch (_) {
      return; // Variables that can't be encoded aren't stored.
    }
    _storageKey = key;
    _storeWrite = Future<void>.sync(() => storage.write(key, value))
        .then((_) {}, onError: (Object _) {});
  }

  /// Deletes the stored variables once the mutation has settled, after a
  /// write that is still in flight.
  void _deleteStored() {
    final key = _storageKey;
    if (key == null) return;
    _storageKey = null;
    _client._loadedMutationKeys.remove(key);
    final write = _storeWrite;
    _storeWrite = null;
    if (write == null) {
      _client._deleteStored(key);
    } else {
      write.whenComplete(() => _client._deleteStored(key));
    }
  }

  /// Applies [action] and notifies, running [first] before the observers.
  void _dispatch(_MutationAction action, [void Function()? first]) {
    _state = switch (action) {
      _MutationFailedAction(:final failureCount, :final error) =>
        _state.copyWith(failureCount: failureCount, failureReason: error),
      _MutationPauseAction() => _state.copyWith(isPaused: true),
      _MutationContinueAction() => _state.copyWith(isPaused: false),
      _MutationPendingAction(
        :final isPaused,
        :final variables,
        :final context,
        :final submittedAt,
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
          submittedAt: submittedAt ?? now(),
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
      first?.call();
      for (final observer in _observers.toList()) {
        observer._onMutationUpdate();
      }
      _mutationCache._notify();
    });
  }

  @override
  String toString() => 'CachedMutation($mutationId, ${_state.status.name})';
}

Future<void> _guard(FutureOr<void> Function() callback) async {
  try {
    await callback();
  } catch (error, stackTrace) {
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}
