# Fuery example

A todo list with one query and one mutation. It runs as it is: `api`, at the end, stands in for your server.

```dart
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

// The list, cached under the key ['todos'].
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

// Adds a todo, then refetches the list.
final addTodoMutation = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: ['todos']),
);

void main() => runApp(const MaterialApp(home: TodoScreen()));

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: QueryBuilder(
        query: todosQuery,
        builder: (context, state) => switch (state) {
          QueryResult(:final data?) => ListView(
              children: [for (final todo in data) ListTile(title: Text(todo))],
            ),
          QueryResult(:final error?) => Center(child: Text('$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            addTodoMutation.mutate('Buy bread', context.queryClient),
        child: const Icon(Icons.add),
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

  Future<String> addTodo(String title) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _todos.add(title);
    return title;
  }
}
```

- `QueryBuilder` fetches the list when it mounts. Every widget that shows `todosQuery` shares the cached list and its request.
- The button runs the mutation from its definition. `context.queryClient` is the client the widgets use: the one of the nearest `FueryProvider`, or `Fuery.client` without one.
- When the mutation succeeds, `onSuccess` invalidates `['todos']`, and the list refetches.

## The full app

[Try the demo](https://galaxykhh.github.io/fuery/demo/) in the browser: a social feed with infinite scrolling, likes that show before the server answers, comments written offline, and the devtools. [Its source](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) has a README that maps each screen to the Fuery features it shows.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)**
