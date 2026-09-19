---
title: Organizing queries
description: Keep keys and query functions in one place.
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

The [example app](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) uses this pattern to share its todo list between a widget screen and a cubit.
