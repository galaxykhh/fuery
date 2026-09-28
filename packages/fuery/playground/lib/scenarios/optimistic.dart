import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const optimisticScenario = Scenario(
  path: 'optimistic',
  title: 'Optimistic updates',
  summary: 'A mutation writes the new todo into the cache before the server '
      'answers, so the list changes at once. If the server fails, the '
      'mutation takes the todo out again.',
  tryThis: [
    'Add a todo. It shows at once, in italics, until the refetch brings the '
        "server's copy.",
    'Add two quickly. The counter above the list shows both runs pending.',
    'Set "fail next" to 1 request and add one. It shows, then disappears, '
        'and a snackbar says why.',
  ],
  source: 'lib/scenarios/optimistic.dart',
  icon: Icons.bolt,
  child: OptimisticScenario(),
);

// #region snippet
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => server.getTodos(),
);

final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => server.addTodo(title),
  onMutate: (String title, client) async {
    // Keep a refetch in flight from overwriting the new todo.
    await client.cancelQueries(queryKey: ['todos']);
    final draft = Todo.draft(title);
    client.setData(todosQuery, [...?client.getData(todosQuery), draft]);
    // The other callbacks get this as their context.
    return draft;
  },
  onError: (error, String title, draft, client) {
    // Roll back: take the draft out again.
    client.updateData(
      todosQuery,
      (todos) => todos?.where((todo) => todo != draft).toList(),
    );
  },
  // Refetch what the server has. The run stays pending until it arrives.
  onSettled: (todo, error, title, draft, client) =>
      client.invalidateQueries(queryKey: ['todos']),
);
// #endregion

class OptimisticScenario extends StatefulWidget {
  const OptimisticScenario({super.key});

  @override
  State<OptimisticScenario> createState() => _OptimisticScenarioState();
}

class _OptimisticScenarioState extends State<OptimisticScenario> {
  static const _titles = [
    'Buy milk',
    'Water the plants',
    'Call Grace',
    'Book the train',
    'Fix the bike',
  ];

  int _added = 0;

  String get _nextTitle => _titles[_added % _titles.length];

  void _add(BuildContext context) {
    // #region snippet
    // Any widget runs the mutation from its definition, with the client
    // the widgets use.
    addTodo.mutate(_nextTitle, context.queryClient);
    // #endregion
    setState(() => _added++);
  }

  @override
  Widget build(BuildContext context) {
    return QueryLog(
      query: todosQuery,
      child: MutationLog(mutation: addTodo, child: _build(context)),
    );
  }

  Widget _build(BuildContext context) {
    // #region snippet
    return MutationStateListener(
      mutation: addTodo,
      // Every failed run of addTodo, whichever widget started it.
      listenWhen: (previous, current) => current.isError,
      listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not add "${run.variables}": ${run.error}')),
      ),
      child: QueryBuilder(
        query: todosQuery,
        builder: (context, state) => ScenarioLayout(
          live: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Counts the runs in flight, from any screen.
              MutationStateSelector(
                mutation: addTodo,
                selector: (runs) => runs.where((run) => run.isPending).length,
                builder: (context, saving) => SavingHeader(saving: saving),
              ),
              switch (state) {
                QueryResult(:final data?) => TodoList(data),
                QueryResult(:final error?) => ErrorMessage(error),
                _ => const Loading(),
              },
            ],
          ),
          controls: ControlBar(
            children: [
              ActionButton(
                'Add "$_nextTitle"',
                primary: true,
                icon: Icons.add,
                onPressed: () => _add(context),
              ),
            ],
          ),
          state: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QueryStatePanel(state),
              const Divider(height: 24),
              MutationStateBuilder(
                mutation: addTodo,
                builder: (context, runs) => MutationRunsPanel(runs),
              ),
            ],
          ),
        ),
      ),
    );
    // #endregion
  }
}

class SavingHeader extends StatelessWidget {
  const SavingHeader({super.key, required this.saving});

  final int saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text('Todos', style: theme.textTheme.titleMedium)),
          Pill(
            saving > 0 ? 'Saving $saving…' : 'All saved',
            key: const Key('saving'),
            tone: saving > 0 ? Tone.active(context) : Tone.good(context),
          ),
        ],
      ),
    );
  }
}

class TodoList extends StatelessWidget {
  const TodoList(this.todos, {super.key});

  final List<Todo> todos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final todo in todos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  todo.isDraft
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_outline,
                  size: 20,
                  color: todo.isDraft
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    todo.title,
                    style: todo.isDraft
                        ? TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
                if (todo.isDraft)
                  Text(
                    'saving',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
