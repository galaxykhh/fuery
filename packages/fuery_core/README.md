<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

# Fuery Core

Server state caching for Dart: queries, infinite queries, and mutations. Types are inferred from your query and mutation functions, so you don't write type arguments.

This is the pure Dart core. **For Flutter apps, use [`fuery`](https://pub.dev/packages/fuery)**, which re-exports this package and adds widgets. Use `fuery_core` directly for Dart servers, CLIs, or packages that shouldn't depend on Flutter.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)**

## Install

```bash
dart pub add fuery_core
```

## Queries

A `Query` describes the data: its key, how to fetch it, and how long it stays fresh. `observe()` returns a `QueryObserver`, which fetches when it gets its first listener, and shares one cache entry and one request with every other observer of the same key.

```dart
import 'package:fuery_core/fuery_core.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (context) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);

final todos = todosQuery.observe();

final subscription = todos.stream.listen((result) {
  if (result.isSuccess) print(result.data);
});

await todos.refetch();
await subscription.cancel(); // stops observing; the cache is freed after gcTime
```

The stream sends the current `QueryResult` first, then every change. You can also read `todos.result` at any time, or use `subscribe(listener)`, which returns an unsubscribe function.

To poll until something finishes, combine `refetchInterval` with `refetchWhile`:

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`streamedQuery` folds a `Stream` that ends into the query data, and the query succeeds with the first chunk:

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

## Mutations

```dart
final addTodo = Mutation(
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: ['todos']),
).observe();

final todo = await addTodo.mutateAsync('Buy milk'); // throws on error
addTodo.mutate('Buy milk'); // reports errors in addTodo.result instead
```

## Infinite queries

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
).observe();

posts.stream.listen((result) => print(result.pages));
await posts.fetchNextPage();
```

## QueryClient

`Fuery.client` is the default `QueryClient`, used whenever no `client:` is passed. Assign your own to change defaults:

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
  ),
);

final data = await Fuery.client.query(todosQuery); // fetch, or use fresh cache
Fuery.client.updateData(todosQuery, (todos) => [...?todos, todo]);
Fuery.client.invalidateQueries(queryKey: ['todos']);
```

To keep data across restarts, give the client a `QueryStorage` and add `persist` to a query. A mutation takes `persist: MutationPersist(...)` and a `mutationKey` the same way, and `client.restore(mutations: [...])` runs the ones that were still waiting when the process ended:

```dart
Fuery.client = QueryClient(storage: myStorage); // your QueryStorage, see the persistence guide

final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  persist: QueryPersist(
    toJson: (todos) => [for (final todo in todos) todo.toJson()],
    fromJson: (json) => [
      for (final item in json! as List)
        Todo.fromJson(item as Map<String, Object?>),
    ],
  ),
);
```

`Fuery.client.watch` turns any value computed from the client into a `Stream`, without fetching anything:

```dart
Fuery.client.watch((client) => client.isFetching()).listen(print);
```

To build an adapter for another framework, such as hooks, keep a `QuerySlot` (or `InfiniteQuerySlot`, `MutationSlot`) per rendered query: call `update(query, client)` on every render and read `result`. The Flutter widgets in `fuery` are built this way.

A mounted client refetches when `focusManager` or `onlineManager` report that the app is focused or back online. Assigning `Fuery.client` mounts the new client; a client you pass to `observe(client:)` yourself, for example in a test, needs `client.mount()`. Pure Dart has no focus or connectivity events, so set them yourself with `setEventListener`, or call `setFocused` and `setOnline`.

Cached queries keep garbage collection timers running, which keeps a Dart process alive. When a CLI is done, cancel its subscriptions, then call `Fuery.client.clear()`.

## Documentation

The [`fuery` README](https://pub.dev/packages/fuery) covers the options, optimistic updates, cancellation, and defaults, and the [documentation](https://galaxykhh.github.io/fuery/) has a guide for each topic.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
