---
title: Organizing queries
description: Keep query keys, query functions, and mutations in one place as a Flutter app grows.
---

As an app grows, the same key and query function show up on several screens and in several blocs. Put each query in one plain function instead:

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

QueryObserver<List<Todo>> todosQuery() {
  return Query.use(
    queryKey: todosKey,
    queryFn: (_) => api.getTodos(),
  );
}

QueryObserver<Todo> todoQuery(int id) {
  return Query.use(
    queryKey: ['todos', 'detail', id],
    queryFn: (_) => api.getTodo(id),
  );
}
```

Screens and blocs call `todosQuery()` and share one cache entry, and mutations invalidate `todosKey` without repeating it.

- **Types stay checked.** Each function returns a typed observer, so there is nothing to cast.
- **Keys stay consistent.** A typo in a key would silently create a second cache entry; one function per query rules that out.
- **Hierarchy is explicit.** `['todos', ...]` groups everything about todos, so `invalidateQueries(queryKey: ['todos'])` refreshes the list and every detail at once.

## Mutations

Mutations go next to their queries, for the same reason. The difference is what gets shared: a query key shares one cache entry, while each `Mutation.use` call has its own pending and error state. So a factory shares the server work, and every screen that calls it keeps its own state:

```dart
// lib/data/todo_mutations.dart
MutationObserver<Todo, String, void> addTodoMutation() {
  return Mutation.use(
    mutationFn: (String title) => api.addTodo(title),
    onSuccess: (todo, title, _) =>
        Fuery.client.invalidateQueries(queryKey: todosKey),
  );
}
```

Keep the cache work, such as invalidating and rolling back, in the factory. Anything that belongs to one screen goes to the call site instead:

```dart
addTodo.mutate(
  title,
  MutateOptions(onSuccess: (todo, title, _) => Navigator.pop(context)),
);
```

A `MutationListener` does the same for a snackbar or a dialog, with the screen's `BuildContext`.

## In the example app

The example has query and mutation factories in [the todo queries](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/todo_queries.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
