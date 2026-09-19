import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Observer<TData, TVariables, TContext>
    = MutationObserver<TData, TVariables, TContext>;
typedef _State<TData, TVariables, TContext>
    = MutationState<TData, TVariables, TContext>;

/// Builds UI from a mutation, like `BlocBuilder`.
///
/// ```dart
/// MutationBuilder(
///   mutation: deleteTodo,
///   builder: (context, state) =>
///       state.isPending ? const LoadingBarrier() : const SizedBox(),
/// )
/// ```
class MutationBuilder<TData, TVariables, TContext> extends StatelessWidget {
  const MutationBuilder({
    super.key,
    required this.mutation,
    required this.builder,
    this.buildWhen,
  });

  final MutationObserver<TData, TVariables, TContext> mutation;
  final ResultWidgetBuilder<MutationState<TData, TVariables, TContext>> builder;
  final ResultCondition<MutationState<TData, TVariables, TContext>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TData, TVariables, TContext>,
        _State<TData, TVariables, TContext>>(
      source: mutation,
      initialResult: _initialResult,
      subscribe: _subscribe,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when a mutation changes, like `BlocListener`.
///
/// ```dart
/// MutationListener(
///   mutation: addTodo,
///   listenWhen: (previous, current) => current.isSuccess,
///   listener: (context, state) => Navigator.pop(context),
///   child: ...,
/// )
/// ```
class MutationListener<TData, TVariables, TContext> extends StatelessWidget {
  const MutationListener({
    super.key,
    required this.mutation,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  final MutationObserver<TData, TVariables, TContext> mutation;
  final ResultWidgetListener<MutationState<TData, TVariables, TContext>>
      listener;
  final ResultCondition<MutationState<TData, TVariables, TContext>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TData, TVariables, TContext>,
        _State<TData, TVariables, TContext>>(
      source: mutation,
      initialResult: _initialResult,
      subscribe: _subscribe,
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// A [MutationBuilder] and [MutationListener] in one, like `BlocConsumer`.
class MutationConsumer<TData, TVariables, TContext> extends StatelessWidget {
  const MutationConsumer({
    super.key,
    required this.mutation,
    required this.builder,
    required this.listener,
    this.buildWhen,
    this.listenWhen,
  });

  final MutationObserver<TData, TVariables, TContext> mutation;
  final ResultWidgetBuilder<MutationState<TData, TVariables, TContext>> builder;
  final ResultWidgetListener<MutationState<TData, TVariables, TContext>>
      listener;
  final ResultCondition<MutationState<TData, TVariables, TContext>>? buildWhen;
  final ResultCondition<MutationState<TData, TVariables, TContext>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Observer<TData, TVariables, TContext>,
        _State<TData, TVariables, TContext>>(
      source: mutation,
      initialResult: _initialResult,
      subscribe: _subscribe,
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
    );
  }
}

_State<TData, TVariables, TContext> _initialResult<TData, TVariables, TContext>(
  _Observer<TData, TVariables, TContext> mutation,
) {
  return mutation.result;
}

void Function() _subscribe<TData, TVariables, TContext>(
  _Observer<TData, TVariables, TContext> mutation,
  void Function(_State<TData, TVariables, TContext>) listener,
) {
  return mutation.subscribe(listener);
}
