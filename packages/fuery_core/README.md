<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery_core.svg)](https://pub.dev/packages/fuery_core)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

# Fuery Core

Server state caching for Dart: queries, infinite queries, and mutations. Observers of one key share one request and keep the cached data while Fuery refetches it. Retries and pagination are built in.

This is the pure Dart core. **For Flutter apps, use [`fuery`](https://pub.dev/packages/fuery)**, which re-exports this package and adds widgets. Use `fuery_core` directly in Dart servers, CLIs, and packages that shouldn't depend on Flutter. It depends only on the Dart team's `clock`, `collection`, and `meta`, and needs no code generation.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)**

## Install

```bash
dart pub add fuery_core
```

## Queries

A `Query` describes the data: its key, how to fetch it, and how long it stays fresh. `observe()` returns a `QueryObserver`. The observer fetches when it gets its first listener, and it shares one cache entry and one request with every other observer of the same key.

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
await subscription.cancel(); // stops observing; the cache entry is removed after gcTime
```

The stream sends the current `QueryResult` first, then every change. `todos.result` reads the latest one at any time, and `subscribe(listener)` returns an unsubscribe function.

`todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. Mutations, infinite queries, results, and callbacks infer their types the same way. You name a type in two cases:

- A read or write by key alone, as a key carries no type: `Fuery.client.getQueryData<List<Todo>>(['todos'])`.
- An [infinite query whose first page param is `null`](https://galaxykhh.github.io/fuery/guides/infinite-queries/#cursor-based-pages).

## Mutations

A `Mutation` changes server data. Run it from the definition with `mutateAsync` or `mutate`:

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: ['todos']),
);

final todo = await addTodo.mutateAsync('Buy milk'); // throws on error
addTodo.mutate('Buy milk'); // puts an error in the run's state instead
```

The definition holds no state. Each run belongs to the client's cache: `Fuery.client`, or the client you pass, as in `addTodo.mutate('Buy milk', client)`. `Fuery.client.isMutating(mutationKey: ['todos', 'add'])` counts the pending runs, and a `MutationStateSlot` lists them. To follow the state of your own runs, `addTodo.observe()` returns a `MutationObserver` with a `result` and a `stream`.

## QueryClient

`Fuery.client` is the default `QueryClient`, used whenever no `client:` is passed. Assign your own to change the defaults:

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

Pure Dart has no focus or connectivity events. Report them to `focusManager` and `onlineManager` with `setEventListener`, or call `setFocused` and `setOnline`. A mounted client refetches when they report that the app is focused or back online. Assigning `Fuery.client` mounts the new client. A client you pass to `observe(client:)` yourself, such as in a test, needs `client.mount()`.

A Dart process stays alive while cached queries keep their garbage collection timers running. When a CLI is done, cancel its subscriptions, then call `Fuery.client.clear()`.

## Building an adapter for another framework

An adapter, for example for another state library, keeps one slot per rendered source: a `QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`, `QueriesSlot` for a list of queries, or `MutationStateSlot` for every run of a mutation. On every render, call the slot's `update(source, client)` and render its `result`. Call `subscribe` to render again after each change, and `dispose` when the component goes away. The widgets in `fuery` and the hooks in `fuery_hooks` are built this way, with this package's public API alone. See [Building an adapter](https://galaxykhh.github.io/fuery/guides/adapters/) for batching and side effects.

## Learn more

- [How the cache works](https://galaxykhh.github.io/fuery/how-the-cache-works/): when data is shared, refetched, and removed.
- [Queries](https://galaxykhh.github.io/fuery/guides/queries/): keys, stale time, polling, and cancelling a request.
- [Mutations](https://galaxykhh.github.io/fuery/guides/mutations/): changing server data, optimistic updates, and rollback.
- [Infinite queries](https://galaxykhh.github.io/fuery/guides/infinite-queries/): paginated lists, cursors, and previous pages.
- [Streamed queries](https://galaxykhh.github.io/fuery/guides/streaming/): a `Stream` folded into the cache as it arrives.
- [Persistence](https://galaxykhh.github.io/fuery/guides/persistence/): queries and mutations kept across restarts.
- [Setting up the client](https://galaxykhh.github.io/fuery/guides/client-setup/): defaults, error reporting, and which client a query uses.
- [Reading and updating the cache](https://galaxykhh.github.io/fuery/guides/query-client/): reading, writing, invalidating, and watching cached data.
- [Testing](https://galaxykhh.github.io/fuery/guides/testing/#testing-without-a-widget-tree): queries tested without a widget tree, with fake time.

Reference: [Query options](https://galaxykhh.github.io/fuery/reference/query-options/), [Query results](https://galaxykhh.github.io/fuery/reference/query-results/), [Mutation options](https://galaxykhh.github.io/fuery/reference/mutation-options/), [Mutation results](https://galaxykhh.github.io/fuery/reference/mutation-results/), and [QueryClient](https://galaxykhh.github.io/fuery/reference/query-client/).

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
