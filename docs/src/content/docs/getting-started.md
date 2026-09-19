---
title: Getting started
description: Install Fuery and show your first query.
---

## Install

```bash
flutter pub add fuery
```

`fuery` includes `fuery_core`, so this is the only package you need in a Flutter app. For Dart code without Flutter, such as a server or CLI, use `dart pub add fuery_core` instead.

## Your first query

A query needs a **key** that identifies the data and a **query function** that fetches it. Create the query once, for example in a `State` field, and build UI from it with `QueryBuilder`:

```dart
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final todos = Query.use(
    queryKey: ['todos'],
    queryFn: (_) => api.getTodos(),
  );

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: todos,
      builder: (context, state) => switch (state) {
        QueryResult(:final data?) => TodoList(data),
        QueryResult(:final error?) => Text('$error'),
        _ => const CircularProgressIndicator(),
      },
    );
  }
}
```

## What happens

- **No type arguments.** `todos` is a `QueryObserver<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `state` in the builder is a `QueryResult<List<Todo>>`. Mutations, infinite queries, and every widget infer their types the same way.
- **`data` is never null in the builder above.** `QueryResult(:final data?)` only matches when there is data, so `data` is a `List<Todo>` and needs no `!`. Data comes first, so a list that fails to refresh stays on screen, and the error shows only when there is no data yet.
- **Creating the query doesn't fetch.** It fetches when `QueryBuilder` mounts, so the field doesn't need to be `late`. Use `late final` only when the query reads `widget` or another field, for example `queryKey: ['todo', widget.id]`.
- **The first frame already shows loading.** There is no empty frame before the request starts.
- **Widgets share data by key.** Another screen that uses `['todos']` gets the cached list immediately and shares the same request.
- **Data stays fresh.** When the screen comes back, when the app returns to the foreground, or when the network reconnects, stale data refetches in the background while the old data stays on screen.
- **Unused data is cleaned up.** Five minutes after the last widget stops using `['todos']`, the cache entry is removed.

## Next steps

- [Queries](../guides/queries/): keys, freshness, and every option.
- [Widgets](../guides/widgets/): builders, listeners, and consumers.
- [Mutations](../guides/mutations/): changing server data and optimistic updates.
- [Using with bloc](../guides/bloc/): the same queries inside cubits and blocs.
- [Devtools](../guides/devtools/): see every query and mutation while you develop.
