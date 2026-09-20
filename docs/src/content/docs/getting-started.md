---
title: Getting started
description: Install Fuery in a Flutter app and cache your first API request.
---

By the end of this page a screen shows a list from an API, with loading and
error states, and the data cached for every other screen that needs it.

## 1. Install Fuery

```bash
flutter pub add fuery
```

`fuery` includes `fuery_core`, so this is the only package you need in a Flutter app. For Dart code without Flutter, such as a server or CLI, use `dart pub add fuery_core` instead.

## 2. Write your first query

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

## What Fuery does for you

- **No type arguments.** `todos` is a `QueryObserver<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `state` in the builder is a `QueryResult<List<Todo>>`. Mutations, infinite queries, and every widget infer their types the same way.
- **No null checks.** `QueryResult(:final data?)` matches only when there is data, so `data` is a `List<Todo>`. That branch comes first, so a list that fails to refresh stays on screen and the error shows only when there is nothing to show.
- **Creating the query starts nothing.** The fetch begins when `QueryBuilder` mounts, and the first frame already shows loading.
- **Widgets share data by key.** Another screen that uses `['todos']` gets the cached list immediately and shares the same request.
- **Stale data refreshes itself.** It refetches in the background when another screen starts using it and when the app returns to the foreground. The old data stays on screen while that happens.

## Next steps

- [Server state in Flutter](../server-state/): why server data needs a cache rather than another state class.
- [Queries](../guides/queries/): keys, freshness, and results.
- [Widgets](../guides/widgets/): builders, listeners, and consumers.
- [Mutations](../guides/mutations/): changing server data and optimistic updates.
- [Using with bloc](../guides/bloc/): the same queries inside cubits and blocs.
- [Devtools](../guides/devtools/): see every query and mutation while you develop.
