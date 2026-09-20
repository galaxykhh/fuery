---
title: Query options
description: Every option of Query.use and QueryOptions in Flutter, with its default and what it changes.
---

This page lists every option that `Query.use`, `QueryOptions`, and `client.query` accept. [Queries](../../guides/queries/) explains the ideas behind them; `InfiniteQuery.use` takes these options too, plus the ones in [Infinite queries](../../guides/infinite-queries/).

## Fetching

| Option | Default | What it does |
|---|---|---|
| `queryKey` | required | Identifies the cached data. See [Query keys](../../guides/queries/#query-keys). |
| `queryFn` | required | Fetches the data. Receives a context with `signal`, `client`, `queryKey`, and `meta`. |
| `enabled` | `true` | Set `false` to stop the query from fetching on its own. `refetch()` still works. |
| `client` | `Fuery.client` | The client that holds the data. See [Which client a query uses](../../guides/query-client/#which-client-a-query-uses). |
| `meta` | none | Any values you want in the query function, read as `context.meta`. |

## Freshness and caching

| Option | Default | What it does |
|---|---|---|
| `staleTime` | zero | How long data stays fresh. `infiniteDuration` keeps it fresh until you invalidate it; `staticStaleTime` also ignores invalidation. |
| `gcTime` | 5 minutes | How long data nothing uses stays in the cache. |
| `structuralSharing` | `true` | Reuses the previous data object when a refetch returns equal data, so widgets rebuild less. |
| `persist` | none | Stores the data on the device. See [Persistence](../../guides/persistence/). |

## Refetching

| Option | Default | What it does |
|---|---|---|
| `refetchOnMount` | `RefetchMode.ifStale` | Refetch when a widget or stream starts using the query. Also `.always` and `.never`. |
| `refetchOnFocus` | `RefetchMode.ifStale` | Refetch when the app returns to the foreground. |
| `refetchOnReconnect` | `RefetchMode.ifStale` | Refetch when the network reconnects. Defaults to `.never` with `NetworkMode.always`. |
| `refetchInterval` | none | Poll this often, counting from the query's latest change. |
| `refetchIntervalInBackground` | `false` | Keep polling while the app is in the background. |
| `refetchWhile` | none | Poll only while this returns true for the latest result. |

## Failures

| Option | Default | What it does |
|---|---|---|
| `retry` | `RetryPolicy.count(3)` | How often to retry a failed fetch. Also `.never()`, `.always()`, and `.when((count, error) => ...)`. |
| `retryDelay` | 1s, 2s, 4s, … up to 30s | How long to wait between attempts, as a function of the failure count and the error. |
| `retryOnMount` | `true` | Set `false` to leave a failed query alone when another widget starts using it. |
| `networkMode` | `NetworkMode.online` | Whether fetching waits for connectivity. See [Refetching automatically](../../guides/lifecycle/). |

## Data to show before the fetch

| Option | Default | What it does |
|---|---|---|
| `initialData` | none | Seeds the cache as if this data had been fetched. |
| `initialDataUpdatedAt` | now | When `initialData` was fetched, in milliseconds since epoch. It decides whether the seeded data is already stale. |
| `placeholderData` | none | Shows data while the query is pending, without writing it to the cache. See [Keeping the previous page](../../guides/queries/#keeping-the-previous-page-on-screen). |
