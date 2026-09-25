---
title: Query options
description: Every option of Query and InfiniteQuery in Flutter, with its type, its default, and what it changes.
---

Every option of `Query` and `InfiniteQuery`, with its type and default. `InfiniteQuery` takes all of them, plus the ones in [InfiniteQuery options](#infinitequery-options). To change a default for every query, or for every key under a prefix, set `QueryDefaults` on the client: see [Defaults](../query-client/#defaults).

[Queries](../../guides/queries/) shows the options at work.

## Fetching

| Option | Type | Default | What it does |
|---|---|---|---|
| `queryKey` | `List<Object?>` | required | Names the cache entry. See [Query keys](../../guides/queries/#query-keys). |
| `queryFn` | `Future<TData> Function(QueryFunctionContext)` | required | Fetches the data. Receives a [query function context](#query-function-context). |
| `enabled` | `bool` | `true` | `false` stops the query from fetching on its own. `refetch()` still fetches. |
| `meta` | `Map<String, Object?>` | none | Values the query function reads as `context.meta`. |

## Freshness and caching

| Option | Type | Default | What it does |
|---|---|---|---|
| `staleTime` | `Duration` | zero | How long data stays fresh. `infiniteDuration` keeps it fresh until you invalidate it. `staticStaleTime` also ignores invalidation. |
| `gcTime` | `Duration` | 5 minutes | Garbage collection time: how long a cache entry that nothing uses stays in memory. The entry keeps the longest `gcTime` any observer asks for. |
| `structuralSharing` | `bool` | `true` | Keeps the cached objects that a refetch returned unchanged. See [Rebuilding only what changed](../../guides/queries/#rebuilding-only-what-changed). |
| `persist` | `QueryPersist<TData>` | none | Stores the data on the device with the client's `storage`. See [Persistence](../../guides/persistence/). |

## Refetching

| Option | Type | Default | What it does |
|---|---|---|---|
| `refetchOnMount` | `RefetchMode` | `RefetchMode.ifStale` | Refetch when a widget or stream starts using the query. `.always` refetches fresh data too. `.never` shows cached data without refetching it. |
| `refetchOnFocus` | `RefetchMode` | `RefetchMode.ifStale` | Refetch when the app returns to the foreground. |
| `refetchOnReconnect` | `RefetchMode` | `RefetchMode.ifStale`, or `.never` with `NetworkMode.always` | Refetch when the network reconnects. |
| `refetchInterval` | `Duration` | none | Poll this often, counting from the query's latest change, while a widget or stream uses the query. |
| `refetchIntervalInBackground` | `bool` | `false` | Keep polling while the app is in the background. |
| `refetchWhile` | `bool Function(QueryResult<TData>)` | none | Poll only while this returns `true` for the latest result. Fuery checks it on every change, and before the first data arrives. |

## Failures

| Option | Type | Default | What it does |
|---|---|---|---|
| `retry` | `RetryPolicy` | `RetryPolicy.count(3)`, or `.never()` for `client.query` | How often to retry a failed fetch: `.count(n)`, `.never()`, `.always()`, or `.when((failureCount, error) => ...)`, where `failureCount` is 0 for the first failure. |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1s, 2s, 4s, … up to 30s | How long to wait before each retry. |
| `retryOnMount` | `bool` | `true` | `false` keeps a query that failed without data from fetching again when a widget starts using it. |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `.online` pauses fetches while the device is offline. `.always` ignores connectivity. `.offlineFirst` runs the first attempt, then pauses retries while offline. See [When the network reconnects](../../guides/lifecycle/#when-the-network-reconnects). |

## Data to show before the fetch

| Option | Type | Default | What it does |
|---|---|---|---|
| `initialData` | `TData` | none | Seeds the cache entry as if this data had been fetched. |
| `initialDataUpdatedAt` | `int` | now | When `initialData` was fetched, in milliseconds since epoch. Decides whether the seeded data is already stale. |
| `placeholderData` | `TData? Function(TData? previousData, QueryClient client)` | none | Data to show while the query is pending. Fuery never writes it to the cache. Receives the data of the key the observer showed before, and the client. `keepPreviousData` returns that data. See [Keeping the previous page on screen](../../guides/queries/#keeping-the-previous-page-on-screen). |

## InfiniteQuery options

`InfiniteQuery<TPage, TParam>` takes every `Query` option, with `InfiniteData<TPage, TParam>` as the data type. `TPage` is the type of one page, and `TParam` the type of the param that names a page. [Infinite queries](../../guides/infinite-queries/) shows them at work.

| Option | Type | Default | What it does |
|---|---|---|---|
| `queryFn` | `Future<TPage> Function(InfiniteQueryFunctionContext<TParam>)` | required | Fetches one page: the one `context.pageParam` names. |
| `initialPageParam` | `TParam` | required | The param of the first page. Fuery infers `TParam` from it. A first param of `null` needs a declared type: see [Cursor-based pages](../../guides/infinite-queries/#cursor-based-pages). |
| `getNextPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | required | Returns the param of the page after `data.lastPage`, or `null` when there is none. It must return a `TParam`: see [Page param errors](#page-param-errors). |
| `getPreviousPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | none | Returns the param of the page before `data.firstPage`, or `null`. Without it, `hasPreviousPage` is false and `fetchPreviousPage()` loads nothing. |
| `maxPages` | `int` | none | The most pages to keep. At the cap, loading a next page drops the first page, and loading a previous page drops the last one. |
| `pages` | `int` | 1 | How many pages to load when nothing is cached, up to `maxPages`. With pages cached, a fetch of every page reloads those instead. |
| `persist` | `InfiniteQueryPersist<TPage, TParam>` | none | Stores the pages on the device. See [Persisting infinite queries](../../guides/persistence/#persisting-infinite-queries). |
| `refetchWhile` | `bool Function(InfiniteQueryResult<TPage, TParam>)` | none | Like `refetchWhile` of `Query`, with the infinite query's result. |

Cached pages above `maxPages`, for example from `setData`, stay until the next or previous page loads, which trims them to `maxPages`. A refetch reloads only the first `maxPages` of them.

### Page param errors

Dart can't check what `getNextPageParam` and `getPreviousPageParam` return without losing type inference, so Fuery checks the param at runtime:

- While Fuery builds a result, to set `hasNextPage` or `hasPreviousPage`, a param of another type counts as no page. So does an error the function throws, such as `data.lastPage.last` on an empty page.
- While pages load, as in a refetch, a param of another type ends the loading at that page. An error the function throws fails the fetch.

Fuery reports a param of another type, and an error thrown while it builds a result, to [`onUncaughtError`](../../guides/client-setup/#catching-errors-that-callbacks-throw), once per client, function, and key.

Both functions receive at least one page, so `data.lastPage` and `data.firstPage` are always there.

## Query function context

Every query function receives a `QueryFunctionContext`. It carries nothing from the widget tree, so the function can run after the widget that built the query is gone.

| Field | Type | What it gives |
|---|---|---|
| `client` | `QueryClient` | The client running the fetch, for reading other cached data. |
| `queryKey` | `List<Object?>` | The key being fetched, to build the request from. |
| `meta` | `Map<String, Object?>?` | The values of the `meta` option. |
| `signal` | `AbortSignal` | Aborted when the fetch is cancelled. Reading it makes the fetch cancellable: see [Cancelling a request](../../guides/queries/#cancelling-a-request). |

An infinite query's function receives an `InfiniteQueryFunctionContext<TParam>`, which adds `pageParam`: the param of the page to load.
