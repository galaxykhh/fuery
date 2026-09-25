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
        _mutationCache = mutationCache,
        _scopeId = options.scope?.id,
        _options = options {
    _setOptions(options);
    _scheduleGc();
  }

  final int mutationId;
  bool _removed = false;

  /// Set when `clear()` cancels this run while it waits to start or to
  /// retry; nothing else removes a pending mutation. Its callbacks don't
  /// run: the optimistic update they would roll back was cleared too, and a
  /// rollback would write the cleared session's data back.
  bool _dropped = false;

  final QueryClient _client;
  final MutationCache _mutationCache;

  /// The scope the run was queued in. New options reach a pending run, but
  /// a new scope applies from the next run, so the runs queued behind this
  /// one still continue.
  final String? _scopeId;

  /// Where the variables are stored while the mutation runs, if they are.
  String? _storageKey;

  /// The write in flight, so the delete after settling can wait for it.
  Future<void>? _storeWrite;

  /// In the order they subscribed, like [CachedQuery._observers].
  final Set<MutationObserver<TData, TVariables, TContext>> _observers = {};
  Mutation<TData, TVariables, TContext> _options;
  var _state = MutationState<TData, TVariables, TContext>();
  Retryer<TData>? _retryer;

  /// The key converted for filters on first use, like [CachedQuery._keyForm],
  /// so the filters that test every run on every change don't convert it
  /// again. [_setOptions] drops them when new options bring another key.
  String? _hash;
  Object? _form;

  Mutation<TData, TVariables, TContext> get options => _options;

  MutationState<TData, TVariables, TContext> get state => _state;

  Map<String, Object?>? get meta => _options.meta;

  /// [hashKey] of the key, or null without one.
  String? get _keyHash {
    final key = _options.mutationKey;
    return key == null ? null : _hash ??= hashKey(key);
  }

  /// [keyForm] of the key, or null without one.
  Object? get _keyForm {
    final key = _options.mutationKey;
    return key == null ? null : _form ??= keyForm(key);
  }

  void _setOptions(Mutation<TData, TVariables, TContext> options) {
    // A pending run gets the new options of its observer, which can bring
    // another key, such as one where there was none.
    if (!identical(options.mutationKey, _options.mutationKey)) {
      _hash = null;
      _form = null;
    }
    _options = options;
    _updateGcTime(_options.gcTime);
  }

  void _addObserver(MutationObserver<TData, TVariables, TContext> observer) {
    if (!_observers.add(observer)) return;
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
    if (_state.isPaused) {
      // Nothing resumes a removed mutation, and a paused one has no attempt
      // in flight, so it fails now.
      _dropped = true;
      _retryer?.cancel();
    } else {
      // A removed mutation doesn't wait to retry; the current attempt
      // finishes.
      _retryer?.stopRetrying();
    }
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
      onPause: () {
        // A mutation removed during onMutate would never be resumed.
        if (_removed) {
          _dropped = true;
          return _retryer?.cancel();
        }
        _dispatch(const _MutationPauseAction());
      },
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
            submittedAt: _state.submittedAt,
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
      // A run that clear() dropped still fails, so its observers and
      // mutateAsync see the error, but none of its callbacks run.
      if (!_dropped) {
        // Errors thrown by the error callbacks must not hide the mutation
        // error.
        await _client._guardAsyncCallback(
          () =>
              cacheConfig.onError?.call(error, variables, _state.context, this),
        );
        await _client._guardAsyncCallback(
          () => _options.onError?.call(
            error,
            variables,
            _state.context,
            _client,
          ),
        );
        await _client._guardAsyncCallback(
          () => cacheConfig.onSettled?.call(
            null,
            error,
            _state.variables,
            _state.context,
            this,
          ),
        );
        await _client._guardAsyncCallback(
          () => _options.onSettled?.call(
            null,
            error,
            variables,
            _state.context,
            _client,
          ),
        );
      }

      _dispatch(
        _MutationErrorAction(error),
        onCallSettled == null || _dropped
            ? null
            : () => onCallSettled(null, error),
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
    final Object? storedKey;
    try {
      // The key's stored form, so enums and dates in it can be stored, and
      // encoded once here, so a key JSON can't hold is reported too.
      storedKey = storageKeyForm(mutationKey);
      jsonEncode(storedKey);
    } catch (error, stackTrace) {
      // A key that can't be hashed can't be restored either. Report it
      // rather than lose the run without a word; the run itself goes on.
      _client._reportOnce('mutationKey $mutationKey', error, stackTrace);
      return;
    }
    final key = '$_mutationKeyPrefix${_state.submittedAt}:$mutationId';
    final String value;
    try {
      value = jsonEncode({
        'v': persist.version,
        'k': storedKey,
        't': _state.submittedAt,
        'd': persist._encode(_state.variables as TVariables),
      });
    } catch (_) {
      return; // Variables that can't be encoded aren't stored.
    }
    _storageKey = key;
    // A restore while it runs must not run it again.
    _client._loadedMutationKeys.add(key);
    _storeWrite = Future<void>.sync(() => storage.write(key, value))
        .then((_) {}, onError: (Object _) {});
  }

  /// Deletes the stored variables once the mutation has settled, after a
  /// write that is still in flight. A restore skips the entry until the
  /// delete starts, and a restore reading then sees the delete and reads
  /// again.
  void _deleteStored() {
    final key = _storageKey;
    if (key == null) return;
    _storageKey = null;
    final write = _storeWrite;
    _storeWrite = null;
    void forget() {
      _client._loadedMutationKeys.remove(key);
      _client._deleteStored(key);
    }

    if (write == null) {
      forget();
    } else {
      write.whenComplete(forget);
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
