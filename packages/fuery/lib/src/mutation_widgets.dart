import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Source<TData, TVariables, TContext>
    = MutationSource<TData, TVariables, TContext>;
typedef _Result<TData, TVariables, TContext>
    = MutationResult<TData, TVariables, TContext>;

/// Builds UI from a mutation, and runs it from the builder with
/// `state.mutate`.
///
/// [mutation] is a [Mutation] definition, or an observer that is already
/// shared. A definition can be built in `build`: the widget keeps one
/// observer for it.
///
/// ```dart
/// MutationBuilder(
///   mutation: deleteTodo,
///   builder: (context, state) => IconButton(
///     onPressed: state.isPending ? null : () => state.mutate(todo.id),
///     icon: const Icon(Icons.delete),
///   ),
/// )
/// ```
class MutationBuilder<TData, TVariables, TContext> extends StatelessWidget {
  const MutationBuilder({
    super.key,
    required this.mutation,
    required this.builder,
    this.buildWhen,
  });

  final MutationSource<TData, TVariables, TContext> mutation;
  final ResultWidgetBuilder<MutationResult<TData, TVariables, TContext>>
      builder;
  final ResultCondition<MutationResult<TData, TVariables, TContext>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TData, TVariables, TContext>,
        _Result<TData, TVariables, TContext>>(
      source: mutation,
      createSlot: MutationSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationBuilder',
      debugKey: debugSameKey(_observerKey),
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when an observer's mutation changes. Not called for the
/// state the mutation already had when the listener mounted.
///
/// A listener can't run a mutation, so it hears only the runs of the
/// observer it gets. To hear every run of a mutation, wherever it started,
/// give the definition a `mutationKey` and use [MutationStateListener]. For
/// the callbacks of one call, pass `MutateOptions` to `mutate`. To hear only
/// one observer's runs, such as the ones a cubit starts, create it once with
/// `observe()` and pass it here. In debug builds, a [Mutation] definition
/// prints a warning.
///
/// ```dart
/// MutationListener(
///   mutation: cubit.adding, // addTodo.observe(), kept by the cubit
///   listenWhen: (previous, current) => current.isError,
///   listener: (context, state) => ScaffoldMessenger.of(context)
///       .showSnackBar(SnackBar(content: Text('${state.error}'))),
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

  final MutationSource<TData, TVariables, TContext> mutation;
  final ResultWidgetListener<MutationResult<TData, TVariables, TContext>>
      listener;
  final ResultCondition<MutationResult<TData, TVariables, TContext>>?
      listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A listener can't run the mutation, so a definition is never run.
    if (mutation is Mutation) debugWarnMutationDefinition('MutationListener');
    return ResultSubscriber<_Source<TData, TVariables, TContext>,
        _Result<TData, TVariables, TContext>>(
      source: mutation,
      createSlot: MutationSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationListener',
      debugKey: debugSameKey(_observerKey),
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// A [MutationBuilder] and [MutationListener] in one.
class MutationConsumer<TData, TVariables, TContext> extends StatelessWidget {
  const MutationConsumer({
    super.key,
    required this.mutation,
    required this.builder,
    required this.listener,
    this.buildWhen,
    this.listenWhen,
  });

  final MutationSource<TData, TVariables, TContext> mutation;
  final ResultWidgetBuilder<MutationResult<TData, TVariables, TContext>>
      builder;
  final ResultWidgetListener<MutationResult<TData, TVariables, TContext>>
      listener;
  final ResultCondition<MutationResult<TData, TVariables, TContext>>? buildWhen;
  final ResultCondition<MutationResult<TData, TVariables, TContext>>?
      listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TData, TVariables, TContext>,
        _Result<TData, TVariables, TContext>>(
      source: mutation,
      createSlot: MutationSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationConsumer',
      debugKey: debugSameKey(_observerKey),
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
    );
  }
}

/// Builds UI from a value selected from a mutation's state, and rebuilds only
/// when that value changes.
///
/// It shows the runs of its own observer. Unless the builder runs the
/// mutation itself, use [MutationStateSelector] with a definition that has a
/// `mutationKey`, which selects from every run of the mutation, or pass the
/// observer that runs it, created once with `observe()`.
///
/// ```dart
/// MutationSelector(
///   mutation: adding, // addTodo.observe(), kept in a State field
///   selector: (state) => state.isPending,
///   builder: (context, saving) => FilledButton(
///     onPressed: saving ? null : () => adding.mutate(title),
///     child: const Text('Save'),
///   ),
/// )
/// ```
class MutationSelector<TData, TVariables, TContext, T> extends StatelessWidget {
  const MutationSelector({
    super.key,
    required this.mutation,
    required this.selector,
    required this.builder,
  });

  final MutationSource<TData, TVariables, TContext> mutation;
  final T Function(MutationResult<TData, TVariables, TContext> state) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<_Source<TData, TVariables, TContext>,
        _Result<TData, TVariables, TContext>, T>(
      source: mutation,
      createSlot: MutationSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationSelector',
      debugKey: debugSameKey(_observerKey),
      selector: selector,
      builder: builder,
    );
  }
}

String? _observerKey<TData, TVariables, TContext>(
  _Source<TData, TVariables, TContext> mutation,
) {
  if (mutation is! MutationObserver<TData, TVariables, TContext>) return null;
  final key = mutation.options.mutationKey;
  return key == null ? null : hashKey(key);
}
