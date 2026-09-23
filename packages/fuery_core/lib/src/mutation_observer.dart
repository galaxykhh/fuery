part of 'core.dart';

/// Runs mutations and reports the state of the latest one.
class MutationObserver<TData, TVariables, TContext>
    extends Subscribable<MutationResult<TData, TVariables, TContext>>
    implements MutationSource<TData, TVariables, TContext> {
  MutationObserver(
    this._client,
    Mutation<TData, TVariables, TContext> options,
  ) {
    setOptions(options);
    _updateResult();
  }

  final QueryClient _client;
  Mutation<TData, TVariables, TContext>? _options;
  late MutationResult<TData, TVariables, TContext> _currentResult;
  CachedMutation<TData, TVariables, TContext>? _currentMutation;

  Mutation<TData, TVariables, TContext> get options => _options!;

  /// The state of the latest mutation, or idle if none ran yet, with the
  /// methods to run it again. Up to date even while nothing listens.
  MutationResult<TData, TVariables, TContext> get result {
    _updateResult();
    return _currentResult;
  }

  /// States as a stream. Each listener first receives the current state, then
  /// every change.
  late final Stream<MutationResult<TData, TVariables, TContext>> stream =
      Stream.multi(
    (controller) {
      MutationResult<TData, TVariables, TContext>? last;
      void emit(MutationResult<TData, TVariables, TContext> state) {
        if (state == last) return;
        last = state;
        controller.add(state);
      }

      final unsubscribe = subscribe(notifyManager.batchCalls(emit));
      emit(result);
      controller.onCancel = unsubscribe;
    },
    isBroadcast: true,
  );

  void setOptions(Mutation<TData, TVariables, TContext> options) {
    final prevOptions = _options;
    _options = _client._defaultMutationOptions(options);

    if (!this.options._sameConfig(prevOptions)) {
      _client.mutationCache._notify();
    }

    final prevKey = prevOptions?.mutationKey;
    final nextKey = this.options.mutationKey;
    if (prevKey != null &&
        nextKey != null &&
        hashKey(prevKey) != hashKey(nextKey)) {
      reset();
    } else if (_currentMutation?.state.status == MutationStatus.pending) {
      _currentMutation?._setOptions(this.options);
    }
  }

  @override
  void onSubscribe() {
    final mutation = _currentMutation;
    if (listeners.length == 1 && mutation != null) {
      mutation._addObserver(this);
      _updateResult();
    }
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) _currentMutation?._removeObserver(this);
  }

  void _onMutationUpdate() {
    _updateResult();
    _notify();
  }

  /// Forgets the latest mutation and goes back to idle.
  void reset() {
    _currentMutation?._removeObserver(this);
    _currentMutation = null;
    _updateResult();
    _notify();
  }

  /// Runs the mutation and returns its data. Throws if it fails.
  Future<TData> mutateAsync(
    TVariables variables, [
    MutateOptions<TData, TVariables, TContext>? options,
  ]) {
    _currentMutation?._removeObserver(this);

    final mutation = _currentMutation =
        _client.mutationCache._build<TData, TVariables, TContext>(
      _client,
      this.options,
    );
    // Without listeners there is nobody to notify, and attaching would keep
    // the mutation from being garbage collected. onSubscribe attaches later.
    if (hasListeners) mutation._addObserver(this);

    return mutation._execute(
      variables,
      onCallSettled:
          options == null ? null : _callbacksOf(mutation, variables, options),
    );
  }

  /// Runs the callbacks of one `mutate` call when its mutation settles,
  /// before listeners hear of it, whether or not anything listens. A later
  /// call or [reset], also from one of these callbacks, drops the rest; so
  /// does the slot that owns this observer being disposed.
  void Function(TData? data, Object? error) _callbacksOf(
    CachedMutation<TData, TVariables, TContext> mutation,
    TVariables variables,
    MutateOptions<TData, TVariables, TContext> options,
  ) {
    return (data, error) {
      bool current() => identical(_currentMutation, mutation);
      final context = mutation.state.context;
      if (error == null) {
        if (current()) {
          _guardSync(
            () => options.onSuccess
                ?.call(data as TData, variables, context, _client),
          );
        }
        if (current()) {
          _guardSync(
            () => options.onSettled
                ?.call(data, null, variables, context, _client),
          );
        }
      } else {
        if (current()) {
          _guardSync(
            () => options.onError?.call(error, variables, context, _client),
          );
        }
        if (current()) {
          _guardSync(
            () => options.onSettled
                ?.call(null, error, variables, context, _client),
          );
        }
      }
    };
  }

  /// Runs the mutation without waiting for it. Errors are reported in
  /// [result] and to the callbacks instead of being thrown.
  void mutate(
    TVariables variables, [
    MutateOptions<TData, TVariables, TContext>? options,
  ]) {
    mutateAsync(variables, options).ignore();
  }

  void _updateResult() {
    final state = _currentMutation?.state ?? _idle;
    // Reading result must not create a new object while the state is the same.
    if (_resultState != null && identical(state, _resultState)) return;
    _resultState = state;
    _currentResult = MutationResult<TData, TVariables, TContext>._(state, this);
  }

  MutationState<TData, TVariables, TContext>? _resultState;
  final _idle = MutationState<TData, TVariables, TContext>();

  void _notify() {
    notifyManager.batch(() {
      for (final listener in listeners) {
        listener(_currentResult);
      }
    });
  }
}

/// A [MutationObserver] for mutations without variables, called as
/// `mutate()`. Created by [NoVariablesMutation.observe].
class NoVariablesMutationObserver<TData, TContext>
    extends MutationObserver<TData, void, TContext> {
  NoVariablesMutationObserver(super.client, super.options);

  @override
  Future<TData> mutateAsync([
    void variables,
    MutateOptions<TData, void, TContext>? options,
  ]) {
    return super.mutateAsync(null, options);
  }

  @override
  void mutate([
    void variables,
    MutateOptions<TData, void, TContext>? options,
  ]) {
    super.mutate(null, options);
  }
}

void _guardSync(void Function() callback) {
  try {
    callback();
  } catch (error, stackTrace) {
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}
