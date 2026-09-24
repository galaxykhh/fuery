<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery_core.svg)](https://pub.dev/packages/fuery_core)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

# Fuery Core

Server state caching for Dart: queries, infinite queries, and mutations, with request deduplication, stale-while-revalidate caching, retries, and pagination.

This is the pure Dart core. **For Flutter apps, use [`fuery`](https://pub.dev/packages/fuery)**, which re-exports this package and adds widgets. Use `fuery_core` directly for Dart servers, CLIs, or packages that shouldn't depend on Flutter. It depends only on the Dart team's `clock`, `collection`, and `meta`, and needs no code generation.

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

The stream sends the current `QueryResult` first, then every change. `todos.result` reads the latest one at any time, and `subscribe(listener)` returns an unsubscribe function.

`todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. Mutations, infinite queries, results, and callbacks infer their types the same way. Only reads and writes by key alone name the type, because a key doesn't carry one: `Fuery.client.getQueryData<List<Todo>>(['todos'])`.

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

## Running without Flutter

A mounted client refetches when `focusManager` or `onlineManager` report that the app is focused or back online. Assigning `Fuery.client` mounts the new client; a client you pass to `observe(client:)` yourself, for example in a test, needs `client.mount()`. Pure Dart has no focus or connectivity events, so set them yourself with `setEventListener`, or call `setFocused` and `setOnline`.

Cached queries keep garbage collection timers running, which keeps a Dart process alive. When a CLI is done, cancel its subscriptions, then call `Fuery.client.clear()`.

## Building an adapter for another framework

An adapter, for example for another state library, keeps one `QuerySlot` (or `InfiniteQuerySlot`, `MutationSlot`, or `QueriesSlot` for a list of queries) per rendered query: call `update(query, client)` on every render and read `result`. The listeners of `subscribe` run synchronously, sometimes during another component's render, so wrap them in `notifyManager.batchCalls` when your framework can't update during a render. For side effects, such as navigation, `listen((previous, current) {...})` runs in a microtask after each later change. `MutationStateSlot` gives the state of every run of a mutation, found by its `mutationKey` or by `MutationFilters`. The Flutter widgets in `fuery` and the hooks in `fuery_hooks` are built this way. See [Building your own widgets or adapters](https://galaxykhh.github.io/fuery/guides/widgets/#building-your-own-widgets-or-adapters).

## Learn more

- [Queries](https://galaxykhh.github.io/fuery/guides/queries/): keys, stale time, results, polling, and cancelling a request.
- [Mutations](https://galaxykhh.github.io/fuery/guides/mutations/): changing server data, optimistic updates, and rollback.
- [Infinite queries](https://galaxykhh.github.io/fuery/guides/infinite-queries/): paginated lists, cursors, and previous pages.
- [Streamed queries](https://galaxykhh.github.io/fuery/guides/streaming/): a `Stream` folded into the cache as it arrives.
- [Persistence](https://galaxykhh.github.io/fuery/guides/persistence/): queries and mutations kept across restarts.
- [QueryClient](https://galaxykhh.github.io/fuery/guides/query-client/): reading, writing, invalidating, and watching the cache, and defaults.
- [Testing](https://galaxykhh.github.io/fuery/guides/testing/#testing-without-a-widget-tree): queries tested without a widget tree, with fake time.
- [Query options](https://galaxykhh.github.io/fuery/reference/query-options/): every option, with its default.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
