---
title: Organizing queries
description: Keep query keys, query functions, and mutations in one place as a Flutter app grows.
---

Define each query once, as `QueryOptions` returned by a plain function in a file next to its API. As an app grows, the same key and query function otherwise show up on several screens and in several blocs:

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

QueryOptions<List<Todo>> todosOptions() => QueryOptions(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );

QueryOptions<Todo> todoOptions(int id) => QueryOptions(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
    );
```

The same options serve every use of the query:

```dart
late final todos = todosOptions().observe();      // in a State or a cubit
final todo = await client.query(todoOptions(id)); // fetching outside widgets
client.updateData(todoOptions(id), (todo) => todo?.copyWith(done: true));
```

Observers of `todosOptions()` share one cache entry, and mutations invalidate `todosKey` without repeating it. Infinite queries work the same way with `infiniteQueryOptions`, whose `observe()` returns an `InfiniteQueryObserver`.

- **Types stay checked.** `observe`, `client.query`, `getData`, `setData`, and `updateData` take the data type from the options, so there is nothing to cast and no way to write another type to the key.
- **Keys stay consistent.** A typo in a key would silently create a second cache entry; one function per query rules that out.
- **Hierarchy is explicit.** `['todos', ...]` groups everything about todos, so `invalidateQueries(queryKey: ['todos'])` refreshes the list and every detail at once.

## Passing dependencies to a query function

A query function must never capture a `BuildContext`. The `api` above is a long-lived object, which is what makes those snippets safe.

The query keeps its query function with the cache entry and runs it again later: when the app returns to the foreground, when the network reconnects, on every `refetchInterval` tick, and whenever anything invalidates the key. Those runs happen after the widget that created the query is gone, so a captured `BuildContext` is unmounted by then. Capturing a `State`, a `TickerProvider`, or anything reached through `context` has the same problem.

Plain values are fine. An id or a search term belongs in the key and in the request, and outlives the widget without trouble.

Give the factory the dependency as a parameter:

```dart
QueryOptions<List<Todo>> todosOptions(TodoApi api) => QueryOptions(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );
```

The screen resolves it once, where it observes the query:

```dart
class _TodoScreenState extends State<TodoScreen> {
  late final todos = todosOptions(locator<TodoApi>()).observe();
}
```

Or look the dependency up inside the query function, which keeps the factory parameterless:

```dart
QueryOptions<List<Todo>> todosOptions() => QueryOptions(
      queryKey: todosKey,
      queryFn: (_) => locator<TodoApi>().getTodos(),
    );
```

`locator` stands for whatever your app resolves dependencies with. Either shape keeps the closure free of anything tied to a widget. Two observers with the same key share one cache entry, so give every call site for a key the same dependency.

`QueryFunctionContext`, the argument every query function receives, carries nothing from the widget tree:

| Field | What it gives |
|---|---|
| `client` | The `QueryClient` running the fetch, for reading other cached data |
| `queryKey` | The key being fetched, so the function can build the request from it |
| `meta` | Static values attached with the `meta` option |
| `signal` | Aborted when the fetch is cancelled. See [Cancelling a request](../queries/#cancelling-a-request). |

## Reporting failures from a repository

A query function has to throw. Fuery takes the error state from a thrown error and from nothing else, so a function that returns a `Result`, an `Either`, or any other wrapper always succeeds, whatever the wrapper holds. The query then:

- keeps `status` at `QueryStatus.success` and `error` at null,
- never sets `isError`, `isLoadingError`, or `isRefetchError`,
- never retries, because the retry policy only ever sees thrown errors.

Unwrap in the query function and throw the failure:

```dart
QueryOptions<List<Todo>> todosOptions(TodoRepository repo) => QueryOptions(
      queryKey: todosKey,
      queryFn: (_) async => switch (await repo.getTodos()) {
        Ok(:final value) => value,
        Err(:final error) => throw error,
      },
    );
```

Having nothing to return isn't a failure either. Query data can't be null, so a function with no result to give throws as well. See [Query data can't be null](../queries/#query-data-cant-be-null).

## Organizing mutations

Put mutations next to their queries, for the same reason. What they share differs, though. Two widgets that use the same query key share one cache entry, but each `Mutation.observe` call keeps its own pending and error state. A mutation factory therefore shares the mutation function and the cache updates, while every screen that calls it keeps its own state:

```dart
// lib/data/todo_mutations.dart
MutationObserver<Todo, String, void> addTodoMutation() {
  return Mutation.observe(
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

A mutation that [`restore`](../persistence/#persisting-mutations) runs again after a restart is defined as `MutationOptions` instead, so the screen and `restore` share it: the screen calls `addCommentOptions().observe()`.

## In the example app

The example has query and mutation factories in [the feed queries](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart) and [the feed mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
