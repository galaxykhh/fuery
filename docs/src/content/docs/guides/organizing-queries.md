---
title: Organizing queries
description: Keep query keys, query functions, and mutations in one place as a Flutter app grows.
---

One definition per query keeps its key and data type the same on every screen, in every bloc, and in every service. Put the definitions in a file next to the API they call:

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
    );
```

A query holds no data, so a top-level `final` works. A query that takes a value, such as an id, is a function.

The same definition serves every use of the data:

```dart
QueryBuilder(query: todoQuery(id), builder: ...);     // in a widget
final todo = await client.query(todoQuery(id));        // fetching outside widgets
client.updateData(todoQuery(id), (todo) => todo?.copyWith(done: true));
final todos = todosQuery.observe();                   // in a cubit or a service
```

Every widget and observer of `todosQuery` shares one cache entry, and mutations invalidate `todosKey` without repeating it. `InfiniteQuery` definitions work the same way.

- **Types stay checked.** Widgets, `client.query`, `getData`, `setData`, and `updateData` take the data type from the query, so there is nothing to cast and no way to write another type to the key.
- **Keys stay consistent.** A typo in a key silently creates a second cache entry. One definition per query rules that out.
- **The hierarchy is explicit.** `['todos', ...]` groups everything about todos, so `invalidateQueries(queryKey: ['todos'])` refreshes the list and every detail at once.

## Passing dependencies to a query function

A query function must never capture a `BuildContext`. The `api` in the snippets above is a long-lived object, which makes them safe.

Fuery keeps the query function with the cache entry and runs it again later:

- when the app returns to the foreground,
- when the network reconnects,
- on every `refetchInterval` tick,
- when anything invalidates or refetches the key.

Some of these runs come after the widget that built the query is gone, when its `BuildContext` is unmounted. A captured `State`, `TickerProvider`, or anything read through `context` has the same problem.

Plain values are safe. An id or a search term belongs in the key and in the request, and outlives the widget.

Give the query the dependency as a parameter:

```dart
Query<List<Todo>> todosQuery(TodoApi api) => Query(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );
```

The screen resolves it where it uses the query:

```dart
QueryBuilder(query: todosQuery(locator<TodoApi>()), builder: ...)
```

Or look the dependency up inside the query function, which keeps the query parameterless:

```dart
final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => locator<TodoApi>().getTodos(),
);
```

`locator` stands for whatever your app resolves dependencies with. Either shape keeps the closure free of anything tied to a widget. Two widgets with the same key share one cache entry, so give every use of a key the same dependency.

The argument every query function receives, `QueryFunctionContext`, carries nothing from the widget tree: see [Query function context](../../reference/query-options/#query-function-context).

## Reporting failures from a repository

A query function has to throw to fail. Fuery sets the error state only from a thrown error. A function that returns a `Result`, an `Either`, or any other wrapper always succeeds, whatever the wrapper holds. The query then:

- keeps `status` at `QueryStatus.success` and `error` at `null`,
- never sets `isError`, `isLoadingError`, or `isRefetchError`,
- never retries, because the retry policy sees only thrown errors.

Unwrap the result in the query function and throw the failure:

```dart
Query<List<Todo>> todosQuery(TodoRepository repo) => Query(
      queryKey: todosKey,
      queryFn: (_) async => switch (await repo.getTodos()) {
        Ok(:final value) => value,
        Err(:final error) => throw error,
      },
    );
```

A function with no result to give throws as well, because query data can't be null. See [Query data can't be null](../queries/#query-data-cant-be-null).

## Organizing mutations

Put mutations next to their queries, defined the same way. Give each one a `mutationKey` built from the key of the data it changes:

```dart
// lib/data/todo_mutations.dart
final addTodo = Mutation(
  mutationKey: [...todosKey, 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: todosKey),
);
```

The `mutationKey` lets any screen find the runs of the mutation, whichever widget, hook, or cubit started them. `MutationStateBuilder(mutation: addTodo)` shows them anywhere in the app: see [Showing every run of a mutation](../mutations/#showing-every-run-of-a-mutation).

A definition holds no state, so it can be a top-level value, like a query. Each run belongs to the client's cache. The callbacks receive the client that runs the mutation, so the cache work reaches the right client in tests and under a `FueryProvider`. [Mutation runs](../../how-the-cache-works/#mutation-runs) explains how runs differ from cache entries.

Keep the cache work, such as invalidating and rolling back, in the definition. Put anything that belongs to one screen at the call site, such as closing the screen after its call succeeds:

```dart
onPressed: () async {
  await addTodo.mutateAsync(title); // throws if it fails
  if (context.mounted) Navigator.pop(context);
},
```

[Acting after one call succeeds](../mutations/#acting-after-one-call-succeeds) shows the whole button, with the failure caught.

A `MutationStateListener` shows a snackbar or a dialog after any run of the mutation, from any screen, with that screen's `BuildContext`. See [Telling the user a mutation failed](../mutations/#telling-the-user-a-mutation-failed).

## In the example app

The example defines its queries in [the feed queries](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart) and its mutations in [the feed mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
