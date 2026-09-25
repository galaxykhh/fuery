// A todo list written with hooks: one query, one mutation that shows a
// snackbar when it fails, and a text field.
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuery_hooks/fuery_hooks.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

final addTodoMutation = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: api.addTodo,
  onSuccess: (_, __, ___, client) =>
      client.invalidateQueries(queryKey: ['todos']),
);

void main() => runApp(const MaterialApp(home: TodoScreen()));

class TodoScreen extends HookWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = useQuery(todosQuery);
    final addTodo = useMutation(addTodoMutation);
    // Runs after the change, never during a build.
    useOnMutationChange(
      addTodo,
      listenWhen: (previous, current) => current.isError,
      listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add the todo: ${result.error}')),
      ),
    );
    final title = useTextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: switch (todos) {
        QueryResult(:final data?) => ListView(
            children: [for (final todo in data) ListTile(title: Text(todo))],
          ),
        QueryResult(:final error?) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: SafeArea(
        child: Row(
          children: [
            Expanded(child: TextField(controller: title)),
            IconButton(
              onPressed: addTodo.isPending
                  ? null
                  : () {
                      addTodo.mutate(title.text);
                      title.clear();
                    },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

/// A server that answers after a short delay.
final api = _Api();

class _Api {
  final _todos = ['Buy milk'];

  Future<List<String>> getTodos() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.of(_todos);
  }

  Future<void> addTodo(String title) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _todos.add(title);
  }
}
