import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

typedef _Source<TData, TVariables, TContext>
    = MutationStateSource<TData, TVariables, TContext>;
typedef _Runs<TData, TVariables, TContext>
    = List<MutationState<TData, TVariables, TContext>>;

/// Builds UI from the state of every run of a mutation, wherever it was
/// started: a [MutationBuilder] on another screen, a hook, a cubit's
/// observer, or `restore(mutations:)`.
///
/// [mutation] is a [Mutation] definition with a `mutationKey`, which finds
/// the runs with that key, typed like the definition, or [MutationFilters],
/// which find the runs of any mutation that match them. The widget only
/// reads: it never runs the mutation. The runs are listed oldest first, and
/// a run stays until the cache removes it, `gcTime` after it settles, so
/// build an indicator from `isPending` rather than from the length.
///
/// ```dart
/// MutationStateBuilder(
///   mutation: addTodo,
///   builder: (context, runs) => Column(
///     children: [
///       for (final run in runs)
///         if (run case MutationState(isPending: true, :final variables?))
///           ListTile(title: Text(variables)),
///     ],
///   ),
/// )
/// ```
class MutationStateBuilder<TData, TVariables, TContext>
    extends StatelessWidget {
  const MutationStateBuilder({
    super.key,
    required this.mutation,
    required this.builder,
    this.buildWhen,
  });

  final MutationStateSource<TData, TVariables, TContext> mutation;
  final ResultWidgetBuilder<List<MutationState<TData, TVariables, TContext>>>
      builder;

  /// Rebuilds only when this returns true for the last built runs and the
  /// new ones.
  final ResultCondition<List<MutationState<TData, TVariables, TContext>>>?
      buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<_Source<TData, TVariables, TContext>,
        _Runs<TData, TVariables, TContext>>(
      source: mutation,
      createSlot: MutationStateSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationStateBuilder',
      debugKey: debugNoRecreatedKey,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when a run of a mutation changes, wherever it was
/// started, such as a snackbar for every run that fails.
///
/// [mutation] finds the runs as in [MutationStateBuilder]. [listener] gets
/// the new state of each run that changed, once per run, and [listenWhen]
/// compares the state that run had before with its new one. It isn't called
/// for the states runs already had when the widget mounted, or for a run
/// that the cache removes. For an effect of one call, such as closing the
/// form that saved, await [Mutation.mutateAsync] instead.
///
/// ```dart
/// MutationStateListener(
///   mutation: addTodo,
///   listenWhen: (previous, current) => current.isError,
///   listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Could not add "${run.variables}"')),
///   ),
///   child: const TodoList(),
/// )
/// ```
class MutationStateListener<TData, TVariables, TContext>
    extends StatelessWidget {
  const MutationStateListener({
    super.key,
    required this.mutation,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  final MutationStateSource<TData, TVariables, TContext> mutation;

  /// Called with a run's new state, once for each run that changed.
  final ResultWidgetListener<MutationState<TData, TVariables, TContext>>
      listener;

  /// Compares that run's previous state with its new one.
  final ResultCondition<MutationState<TData, TVariables, TContext>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MutationRunListener<TData, TVariables, TContext>(
      source: mutation,
      listener: listener,
      listenWhen: listenWhen,
      debugName: 'MutationStateListener',
      child: child,
    );
  }
}

/// Builds UI from a value selected from the runs of a mutation, and
/// rebuilds only when that value changes.
///
/// [mutation] finds the runs as in [MutationStateBuilder].
///
/// ```dart
/// MutationStateSelector(
///   mutation: addTodo,
///   selector: (runs) => runs.any((run) => run.isPending),
///   builder: (context, adding) => adding
///       ? const LinearProgressIndicator()
///       : const SizedBox(height: 4),
/// )
/// ```
class MutationStateSelector<TData, TVariables, TContext, T>
    extends StatelessWidget {
  const MutationStateSelector({
    super.key,
    required this.mutation,
    required this.selector,
    required this.builder,
  });

  final MutationStateSource<TData, TVariables, TContext> mutation;
  final T Function(List<MutationState<TData, TVariables, TContext>> runs)
      selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<_Source<TData, TVariables, TContext>,
        _Runs<TData, TVariables, TContext>, T>(
      source: mutation,
      createSlot: MutationStateSlot<TData, TVariables, TContext>.new,
      debugName: 'MutationStateSelector',
      debugKey: debugNoRecreatedKey,
      selector: selector,
      builder: builder,
    );
  }
}
