---
title: How the cache works
description: Why two screens share one request, when cached data refetches, and when it leaves memory.
---

Two screens share one request, stale data refetches on its own, and unused data leaves memory after 5 minutes by default. These parts work together to produce that behavior:

| Term | What it is | API type |
|---|---|---|
| Query | A definition of server data: its key, query function, and options. It holds no data. | `Query`, `InfiniteQuery` |
| Mutation | A definition of a change: its mutation function and options. | `Mutation`, `NoVariablesMutation` |
| Client | The owner of a query cache and a mutation cache. | `QueryClient` |
| Cache entry | The data and state of one key in one client. | `CachedQuery` |
| Observer | The link between a definition and one client. A query observer watches one cache entry. A mutation observer starts runs and reports the latest one. | `QueryObserver`, `InfiniteQueryObserver`, `MutationObserver` |
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

`Fuery.client` is the default client, created on first use. A `FueryProvider` gives a subtree its own client, and the widgets below it use that client. Each client has its own caches, so the same key in two clients is two cache entries with separate data. [Which client a query uses](../guides/query-client/#which-client-a-query-uses) lists the rules for widgets, `observe()`, and query functions.

## Observers

An observer connects a definition to a cache entry in one client. Two things create observers:

- A widget or hook given a definition keeps one observer while it is mounted.
- `observe()` creates one in code outside widgets, such as a cubit or a service. Call it once, not in `build`: each call creates a new observer.

What an observer does:

- **Subscribing.** An observer subscribes to its cache entry when it gets its first listener: a mounted widget or hook, or a `stream.listen` call on an observer from `observe()`. It fetches if the entry has no data, or if the data is stale (`refetchOnMount` controls the second case).
- **Sharing a fetch.** An observer that subscribes while its entry is fetching joins that fetch. Two screens that open together send one request.
- **Unsubscribing.** An observer unsubscribes when its last listener leaves, such as when its widget unmounts or the stream subscription is cancelled.
- **Applying its own options.** Each observer applies its own `staleTime` and `refetchOnMount`. Two screens can watch one entry, and each decides for itself whether the data is stale.
- **Setting how long the entry stays.** Each observer asks for a `gcTime`, the garbage collection time: how long the entry stays in memory once no observer watches it. The entry keeps the longest one that any observer or fetch asked for.
- **Following a key.** When a widget rebuilds with a definition for another key, its observer moves to that key's cache entry.
- **Reporting results.** An observer reports a result on every change. The result shows the entry's state through the observer's options, such as `isStale` for its own `staleTime`. [QueryResult fields](../guides/queries/#queryresult-fields) lists the fields.

[Using a query](../guides/queries/#using-a-query) shows both ways to observe a query. [Widgets](../guides/widgets/) lists the widgets that keep observers.

## Query lifecycle

A cache entry moves through these stages. Stages 3 and 4 differ per observer, since each observer judges freshness by its own `staleTime`.

| Stage | What happens | What ends it |
|---|---|---|
| 1. Created | The first observer or `client.query` call for a key creates its cache entry, with no data. | An observer subscribes, or `client.query` fetches. |
| 2. Pending | The query function runs. `status` is `pending`. `fetchStatus` is `fetching`. It is `paused` while a retry waits for the app to return to the foreground, and, with a [connectivity source](../guides/lifecycle/#when-the-network-reconnects), while the device is offline. | The data arrives (`success`), or the fetch fails after its retries (`error`). |
| 3. Fresh | The data is younger than `staleTime` (default: zero, so data skips this stage unless you set it). By default, mounts, focus, and reconnects don't refetch it. | `staleTime` passes, or `invalidateQueries` marks the data stale. |
| 4. Stale | The data stays on screen. Fuery refetches it in the background when an observer subscribes, when the app returns to the foreground, and, with a connectivity source, when the network reconnects. | A refetch brings new data, back to stage 3. |
| 5. Inactive | No observer watches the entry: the last one left, or none ever did, as with an entry that only `client.query` or `setData` filled. The data stays in memory, so a screen that comes back shows it at once. | An observer subscribes (back to stage 3 or 4), or `gcTime` passes. |
| 6. Removed | Once `gcTime` (default: 5 minutes) passes with no observer, Fuery removes the cache entry. Persisted data stays in storage. | The next use of the key starts again at stage 1, and restores persisted data if there is some. |

Along the way:

- An entry created with `initialData`, by `setData`, or from persisted data starts with data, at stage 3 or 4.
- A fetch that an observer starts retries 3 times by default, waiting 1, 2, and 4 seconds. `client.query` retries only when the query or the client's defaults (`DefaultOptions`, `setQueryDefaults`) set `retry`.
- A first fetch that fails leaves the entry in `error`, with no data. It fetches again when an observer subscribes (unless `retryOnMount` is `false`), and on focus and reconnect like stale data.
- A refetch that fails keeps the data. `status` becomes `error`, and the data stays stale, so the next trigger refetches it.
- `invalidateQueries` marks matching entries stale, and refetches the ones an observer watches.
- `refetchInterval` refetches on a timer while an enabled observer with that option is subscribed. It pauses while the app is in the background, unless `refetchIntervalInBackground` is `true`.
- An observer with `staleTime: staticStaleTime` keeps the data at stage 3 for good, even after `invalidateQueries`.
- `removeQueries` and `clear()` remove entries at once, and delete their persisted data too.
- When a refetch returns data equal to the cached data, Fuery keeps the previous object, so a widget that compares it doesn't rebuild. When a list changed, each item that equals the previous item at the same index stays the previous object. Your own classes count as equal only when they implement `==`. [Rebuilding only what changed](../guides/queries/#rebuilding-only-what-changed) shows the effect on lists.

Each refetch trigger has an option, such as `refetchOnFocus`. [Query options](../reference/query-options/) lists them with their defaults.

## Mutation runs

A mutation doesn't share a cache entry the way a query does. Each `mutate` call adds a run to the mutation cache, with its own variables and state.

- **Showing the latest run.** A `MutationResult` shows the latest run that its observer started. The next `mutate` call replaces it, and `reset()` returns the result to idle.
- **Keeping runs apart.** Two widgets that run the same mutation each keep an observer, and each shows only its own runs. [Sharing one observer](../guides/mutations/#sharing-one-observer) covers the cases that need one.
- **Finding every run.** `MutationStateBuilder`, `MutationStateListener`, `MutationStateSelector`, and `useMutationState` find every run of a definition by its `mutationKey`, or every run that matches `MutationFilters`, wherever it started. See [Showing every run of a mutation](../guides/mutations/#showing-every-run-of-a-mutation).
- **Retrying.** A run retries only when the mutation or the client's mutation defaults (`DefaultOptions`, `setMutationDefaults`) set `retry`.
- **Leaving the cache.** A run stays while an observer shows it. Once it has settled and no observer shows it, Fuery removes it after `gcTime` (default: 5 minutes). `client.clear()` removes every run at once.

[MutationState fields](../guides/mutations/#mutationstate-fields) lists the fields of `MutationResult` and `MutationState`.

## Next steps

- [Queries](../guides/queries/): keys, freshness, and queries that depend on each other.
- [Widgets](../guides/widgets/): the widgets that keep observers.
- [Mutations](../guides/mutations/): running mutations and showing their runs.
- [QueryClient](../guides/query-client/): read, write, and invalidate cache entries through the client.
- [Query options](../reference/query-options/): every option, with its default.
