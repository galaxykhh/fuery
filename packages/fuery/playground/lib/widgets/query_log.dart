import 'package:flutter/widgets.dart';
import 'package:fuery/fuery.dart';

import '../timeline.dart';

/// Whether the status, fetchStatus, isStale, or failureCount of a query
/// changed, which is what the timeline shows.
bool queryChanged(QueryResult<Object> previous, QueryResult<Object> current) =>
    previous.status != current.status ||
    previous.fetchStatus != current.fetchStatus ||
    previous.isStale != current.isStale ||
    previous.failureCount != current.failureCount;

/// A query's state for the timeline, such as "success · idle · fresh".
String describeQuery(QueryResult<Object> state) => [
      state.status.name,
      state.fetchStatus.name,
      state.isStale ? 'stale' : 'fresh',
      if (state.failureCount > 0) 'failureCount ${state.failureCount}',
    ].join(' · ');

/// Writes each change of a query to the timeline, with a [QueryListener].
class QueryLog<TData extends Object> extends StatelessWidget {
  const QueryLog({super.key, required this.query, required this.child});

  final QuerySource<TData> query;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return QueryListener(
      query: query,
      listenWhen: queryChanged,
      listener: (context, state) =>
          Timeline.of(context).query(describeQuery(state)),
      child: child,
    );
  }
}

/// Writes each change of each run of a mutation to the timeline, with a
/// [MutationStateListener].
class MutationLog<TData, TVariables, TContext> extends StatelessWidget {
  const MutationLog({super.key, required this.mutation, required this.child});

  final MutationStateSource<TData, TVariables, TContext> mutation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MutationStateListener(
      mutation: mutation,
      listener: (context, run) => Timeline.of(context).mutation(
        [
          'run "${run.variables}"',
          run.status.name,
          if (run.isPaused) 'isPaused',
        ].join(' · '),
      ),
      child: child,
    );
  }
}
