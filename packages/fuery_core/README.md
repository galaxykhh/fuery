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

`Query.use` returns a `QueryObserver`. It fetches when it gets its first listener, and shares one cache entry and one request with every other observer of the same key.

```dart
import 'package:fuery_core/fuery_core.dart';

final todos = Query.use(
  queryKey: ['todos'],
  queryFn: (context) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);

final subscription = todos.stream.listen((result) {
  if (result.isSuccess) print(result.data);
});

await todos.refetch();
await subscription.cancel(); // stops observing; the cache is freed after gcTime
```

The stream sends the current `QueryResult` first, then every change. You can also read `todos.result` at any time, or use `subscribe(listener)`, which returns an unsubscribe function.

To poll until something finishes, combine `refetchInterval` with `refetchWhile`:

```dart
final job = Query.use(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`streamedQuery` folds a `Stream` that ends into the query data, and the query succeeds with the first chunk:

```dart
final answer = Query.use(
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
final addTodo = Mutation.use(
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context) =>
      Fuery.client.invalidateQueries(queryKey: ['todos']),
);

final todo = await addTodo.mutateAsync('Buy milk'); // throws on error
addTodo.mutate('Buy milk'); // reports errors in addTodo.result instead
```

## Infinite queries

```dart
final posts = InfiniteQuery.use(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);

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

Fuery.client.invalidateQueries(queryKey: ['todos']);
Fuery.client.setQueryData(['todos', 1], todo);
final data = await Fuery.client.query(
  QueryOptions(queryKey: ['todos'], queryFn: (_) => api.getTodos()),
);
```

To keep data across restarts, give the client a `QueryStorage` and add `persist` to a query:

```dart
Fuery.client = QueryClient(storage: FileStorage(directory));

final todos = Query.use(
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

A mounted client refetches when `focusManager` or `onlineManager` report that the app is focused or back online. Assigning `Fuery.client` mounts the new client; a client you pass as `client:` yourself, for example in a test, needs `client.mount()`. Pure Dart has no focus or connectivity events, so set them yourself with `setEventListener`, or call `setFocused` and `setOnline`.

Cached queries keep garbage collection timers running, which keeps a Dart process alive. Call `Fuery.client.clear()` when a CLI is done.

## Documentation

The [`fuery` README](https://pub.dev/packages/fuery) covers every option, optimistic updates, cancellation, and defaults.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
