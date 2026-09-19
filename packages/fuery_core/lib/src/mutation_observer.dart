part of 'core.dart';

/// Runs mutations and reports the state of the latest one.
class MutationObserver<TData, TVariables, TContext>
    extends Subscribable<MutationState<TData, TVariables, TContext>> {
  MutationObserver(
    this._client,
    MutationOptions<TData, TVariables, TContext> options,
  ) {
    setOptions(options);
    _updateResult();
  }

  final QueryClient _client;
  MutationOptions<TData, TVariables, TContext>? _options;
  late MutationState<TData, TVariables, TContext> _currentResult;
  Mutation<TData, TVariables, TContext>? _currentMutation;
  MutateOptions<TData, TVariables, TContext>? _mutateOptions;

  MutationOptions<TData, TVariables, TContext> get options => _options!;

  /// The state of the latest mutation, or idle if none ran yet. Up to date
  /// even while nothing listens.
  MutationState<TData, TVariables, TContext> get result {
    _updateResult();
    return _currentResult;
  }

  /// States as a stream. Each listener first receives the current state, then
  /// every change.
  late final Stream<MutationState<TData, TVariables, TContext>> stream =
      Stream.multi(
    (controller) {
      MutationState<TData, TVariables, TContext>? last;
      void emit(MutationState<TData, TVariables, TContext> state) {
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

  void setOptions(MutationOptions<TData, TVariables, TContext> options) {
    final prevOptions = _options;
    _options = _client.defaultMutationOptions(options);

    if (!this.options._sameAs(prevOptions)) {
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
    if (!hasListeners()) _currentMutation?._removeObserver(this);
  }

  void _onMutationUpdate(_MutationAction action) {
    _updateResult();
    _notify(action);
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
    _mutateOptions = options;
    _currentMutation?._removeObserver(this);

    final mutation = _currentMutation =
        _client.mutationCache._build<TData, TVariables, TContext>(
      _client,
      this.options,
    );
    // Without listeners there is nobody to notify, and attaching would keep
    // the mutation from being garbage collected. onSubscribe attaches later.
    if (hasListeners()) mutation._addObserver(this);

    return mutation._execute(variables);
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
    _currentResult =
        _currentMutation?.state ?? MutationState<TData, TVariables, TContext>();
  }

  void _notify([_MutationAction? action]) {
    notifyManager.batch(() {
      final mutateOptions = _mutateOptions;
      if (mutateOptions != null && hasListeners()) {
        final context = _currentResult.context;
        TVariables variables() => _currentResult.variables as TVariables;

        switch (action) {
          case _MutationSuccessAction(:final data):
            _guardSync(
              () => mutateOptions.onSuccess?.call(
                data as TData,
                variables(),
                context,
              ),
            );
            _guardSync(
              () => mutateOptions.onSettled?.call(
                data as TData,
                null,
                variables(),
                context,
              ),
            );
          case _MutationErrorAction(:final error):
            _guardSync(
              () => mutateOptions.onError?.call(error, variables(), context),
            );
            _guardSync(
              () => mutateOptions.onSettled?.call(
                null,
                error,
                variables(),
                context,
              ),
            );
          default:
            break;
        }
      }

      for (final listener in listeners.toList()) {
        listener(_currentResult);
      }
    });
  }
}

/// A [MutationObserver] for mutations without variables, called as
/// `mutate()`.
class NoParamMutationObserver<TData, TContext>
    extends MutationObserver<TData, void, TContext> {
  NoParamMutationObserver(super.client, super.options);

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
