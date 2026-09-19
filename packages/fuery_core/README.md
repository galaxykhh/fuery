# Fuery Core

Server state caching for Dart: queries, infinite queries, and mutations.

This is the pure Dart core. **For Flutter apps, use [`fuery`](https://pub.dev/packages/fuery)**, which re-exports this package and adds widgets. Use `fuery_core` directly for Dart servers, CLIs, or packages that shouldn't depend on Flutter.

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

## Mutations

```dart
final addTodo = Mutation.use(
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context) =>
      Fuery.instance.invalidateQueries(queryKey: ['todos']),
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

`Fuery.instance` is the default `QueryClient`, used whenever no `client:` is passed. Create your own to change defaults or to isolate tests:

```dart
final client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
  ),
)..mount();

client.invalidateQueries(queryKey: ['todos']);
client.setQueryData(['todos', 1], todo);
final data = await client.query(
  QueryOptions(queryKey: ['todos'], queryFn: (_) => api.getTodos()),
);
```

`mount()` makes the client refetch when `focusManager` or `onlineManager` report that the app is focused or back online. Pure Dart has no focus or connectivity events, so set them yourself with `setEventListener`, or call `setFocused` and `setOnline`.

Cached queries keep garbage collection timers running, which keeps a Dart process alive. Call `client.clear()` when a CLI is done.

## Documentation

The [`fuery` README](https://pub.dev/packages/fuery) covers every option, optimistic updates, cancellation, and defaults.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
