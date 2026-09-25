---
title: How the cache works
description: Why two screens share one request, when cached data refetches, and when it leaves memory.
---

Two screens share one request, stale data refetches on its own, and unused data leaves memory after 5 minutes by default. Each of these follows from how the parts below work together. Every page of these docs uses their names in one sense:

| Term | What it is | API type |
|---|---|---|
| Query | A definition of server data: its key, query function, and options. It holds no data. | `Query`, `InfiniteQuery` |
| Mutation | A definition of a change: its mutation function and options. | `Mutation`, `NoVariablesMutation` |
| Client | The owner of a query cache and a mutation cache. | `QueryClient` |
| Cache entry | The data and state of one key in one client. | `CachedQuery` |
| Observer | Watches one cache entry, or runs one mutation, and reports every change. | `QueryObserver`, `InfiniteQueryObserver`, `MutationObserver` |
| Result | What an observer reports: the state it sees, with actions such as `refetch` or `mutate`. | `QueryResult`, `InfiniteQueryResult`, `MutationResult` |
| Run | One `mutate` call, with its variables and state. | `CachedMutation` |

## Definitions

A definition says what to fetch or change, and nothing else. A `Query` holds a key, a query function, and options. A `Mutation` holds a mutation function and options. Neither holds data or a client. Creating one starts nothing.

So a definition can be a top-level value, or be built by a function or in `build`:

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (_) => api.getTodo(id),
    );
```

Two calls of `todoQuery(1)` build two objects with the key `['todos', 1]`. Fuery compares keys by value, so both objects use one cache entry. [Query keys](../guides/queries/#query-keys) lists what a key can hold.

## Clients and caches

A `QueryClient` holds everything that is cached, in two caches:

- its `QueryCache` holds one cache entry per key,
- its `MutationCache` holds one run per `mutate` call.

The client also holds the defaults and the storage that its caches use.

`Fuery.client` is the default client, created on first use. A `FueryProvider` gives a subtree its own client, and the widgets below it use that client. Each client has its own caches, so the same key in two clients is two cache entries with separate data. [Which client a query uses](../guides/client-setup/#which-client-a-query-uses) lists the rules for widgets, `observe()`, and query functions.

## Observers

An observer connects a definition to a cache entry in one client. Two things create observers:

- A widget or hook given a definition keeps one observer while it is mounted.
- `observe()` creates one in code outside widgets, such as a cubit or a service. Call it once, not in `build`: each call creates a new observer.

What an observer does:

- **Subscribing.** An observer subscribes to its cache entry when it gets its first listener. It fetches if the entry has no data, or if the data is stale (`refetchOnMount` controls the second case).
- **Sharing a fetch.** An observer that subscribes while its entry is fetching joins that fetch. Two screens that open together send one request.
- **Unsubscribing.** An observer unsubscribes when its last listener leaves, such as when its widget unmounts.
- **Its own options.** Each observer applies its own `staleTime` and `refetchOnMount`. Two screens can watch one entry, and each decides for itself whether the data is stale.
- **Garbage collection time.** `gcTime`, the garbage collection time, is how long an entry stays in memory once no observer watches it. The entry keeps the longest `gcTime` that any observer or fetch asked for.
- **Following a key.** When a widget rebuilds with a definition for another key, its observer moves to that key's cache entry.
- **Results.** An observer reports a result on every change. The result shows the entry's state through the observer's options, such as `isStale` for its own `staleTime`. [Query results](../reference/query-results/) lists the fields.

[Using a query](../guides/queries/#using-a-query) shows both ways to observe a query. [Widgets](../guides/widgets/) lists the widgets that keep observers.

## Query lifecycle

A cache entry moves through these stages, in order:

| Stage | What happens | What ends it |
|---|---|---|
| 1. Created | The first observer or `client.query` call for a key creates its cache entry, with no data. | An observer subscribes, or `client.query` fetches. |
| 2. Pending | The query function runs. `status` is `pending`. `fetchStatus` is `fetching`, or `paused` while the device is offline. | The data arrives (`success`), or the fetch fails after its retries (`error`). |
| 3. Fresh | The data is younger than `staleTime` (default: zero, so data skips this stage unless you set it). By default, mounts, focus, and reconnects don't refetch it. | `staleTime` passes, or `invalidateQueries` marks the data stale. |
| 4. Stale | The data stays on screen. Fuery refetches it in the background when an observer subscribes, when the app returns to the foreground, and when the network reconnects. | A refetch brings new data, back to stage 3. |
| 5. Inactive | The last observer left, at stage 3 or 4. The data stays in memory, so a screen that comes back shows it at once. | An observer subscribes (back to stage 3 or 4), or `gcTime` passes. |
| 6. Removed | Once `gcTime` (default: 5 minutes) passes with no observer, Fuery removes the cache entry. Persisted data stays in storage. | The next use of the key starts again at stage 1, and restores persisted data if there is some. |

Along the way:

- An entry created with `initialData`, by `setData`, or from persisted data starts with data, at stage 3 or 4.
- A fetch that an observer starts retries 3 times, waiting 1, 2, and 4 seconds. `client.query` retries only when the query sets `retry`.
- A first fetch that fails leaves the entry in `error`, with no data. It fetches again on the same triggers as stale data.
- A refetch that fails keeps the data. `status` becomes `error`, and the data stays stale, so the next trigger refetches it.
- `invalidateQueries` marks matching entries stale, and refetches the ones an observer watches.
- `refetchInterval` refetches on a timer in stages 3 and 4, while an observer is subscribed and the app is in the foreground.
- An observer with `staleTime: staticStaleTime` keeps the data at stage 3 for good, even after `invalidateQueries`.
- `removeQueries` and `clear()` remove entries at once, and delete their persisted data too.
- Fuery keeps each part of refetched data that didn't change as the same object, so a widget that compares it doesn't rebuild. [Rebuilding only what changed](../guides/queries/#rebuilding-only-what-changed) shows the effect on lists.

Each refetch trigger has an option, such as `refetchOnFocus`. [Query options](../reference/query-options/) lists them with their defaults.

## Mutation runs

A mutation doesn't share a cache entry the way a query does. Each `mutate` call adds a run to the mutation cache, with its own variables and state.

- **An observer shows its latest run.** A `MutationResult` shows the latest run that its observer started. The next `mutate` call replaces it, and `reset()` returns the result to idle.
- **Widgets don't share runs.** Two widgets that run the same mutation each keep an observer, and each shows only its own runs. [Sharing one observer](../guides/mutations/#sharing-one-observer) covers the cases that need one.
- **Finding every run.** The MutationState widgets and `useMutationState` find every run by the definition's `mutationKey`, wherever it started. See [Showing every run of a mutation](../guides/mutations/#showing-every-run-of-a-mutation).
- **Retries.** A run retries only when the mutation sets `retry`.
- **Leaving the cache.** A run stays while an observer shows it. Once it has settled and no observer shows it, Fuery removes it after `gcTime` (default: 5 minutes). `client.clear()` removes every run at once.

[Mutation results](../reference/mutation-results/) lists the fields of `MutationResult` and `MutationState`.

## Next steps

- [Queries](../guides/queries/): keys, freshness, and queries that depend on each other.
- [Widgets](../guides/widgets/): the widgets that keep observers.
- [Mutations](../guides/mutations/): running mutations and showing their runs.
- [Reading and updating the cache](../guides/query-client/): read, write, and invalidate cache entries through the client.
- [Query options](../reference/query-options/): every option, with its default.
