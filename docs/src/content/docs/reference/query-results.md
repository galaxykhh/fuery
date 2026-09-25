---
title: Query results
description: "What builders, hooks, and streams receive for a query: status, data, errors, fetch flags, and the pages of an infinite query."
---

Every query widget, `useQuery`, and observer stream receives a `QueryResult`. An infinite query reports an `InfiniteQueryResult`, which adds the pages and the page actions. Which field to read depends on the question:

- **What to show:** `data` when it isn't `null`, then `error`, then a loading indicator. A failed refetch keeps the earlier `data`.
- **Whether a request is running:** `isFetching`, or `isRefetching` for a background refetch while data is on screen.
- **Why it failed:** `error` once the fetch gave up, and `failureReason` and `failureCount` while it still retries.

## QueryResult fields

Two enums carry the state, and the other fields describe the data and the latest fetch:

| Field | Type | Meaning |
|---|---|---|
| `status` | `QueryStatus` | `pending`, `error`, or `success`. See [QueryStatus and FetchStatus](#querystatus-and-fetchstatus). |
| `fetchStatus` | `FetchStatus` | `fetching`, `paused`, or `idle`. |
| `data` | `TData?` | The latest data, or `null` before the first. A failed refetch keeps it. |
| `error` | `Object?` | The error of the latest failed fetch. `null` again once a fetch succeeds, or while a query without data fetches again. |
| `dataUpdatedAt` | `int` | When `data` last changed, in milliseconds since epoch. `0` if never. |
| `errorUpdatedAt` | `int` | When `error` was last set, in milliseconds since epoch. `0` if never. |
| `errorUpdateCount` | `int` | How many times a fetch has failed. |
| `failureCount` | `int` | Failed attempts in the latest fetch, retries included. Back to `0` when a fetch starts or succeeds. |
| `failureReason` | `Object?` | The error of the latest failed attempt. Cleared with `failureCount`. |
| `isFetched` | `bool` | The query has finished a fetch, or received data from `setData`, at least once. |
| `isFetchedAfterMount` | `bool` | The same, since this observer got its first listener. |
| `isPlaceholderData` | `bool` | `data` comes from `placeholderData`. `status` is `success` meanwhile. |
| `isStale` | `bool` | The data is older than `staleTime`, invalidated, or missing, so the next trigger refetches it. Always `false` for a disabled query. |
| `isEnabled` | `bool` | `enabled` isn't `false`, so the query fetches on its own. |
| `observer` | `QueryObserver<TData>?` | The observer that reported the result. `null` for a result built with the `QueryResult` constructor, as in a test. |

The rest are questions about those fields:

| Question | Type | True when |
|---|---|---|
| `isPending`, `isSuccess`, `isError` | `bool` | `status` is that value. |
| `hasData` | `bool` | `data` isn't `null`. |
| `isFetching`, `isPaused` | `bool` | `fetchStatus` is that value. |
| `isLoading` | `bool` | The first load: pending and fetching. |
| `isRefetching` | `bool` | A fetch runs while data is on screen. |
| `isLoadingError` | `bool` | The fetch failed before any data arrived. |
| `isRefetchError` | `bool` | The fetch failed while data is on screen. |

### QueryStatus and FetchStatus

| Value | Meaning |
|---|---|
| `QueryStatus.pending` | No data and no error yet. |
| `QueryStatus.error` | The latest fetch failed. `data` keeps any earlier data. |
| `QueryStatus.success` | The query has data, and the latest fetch didn't fail. |
| `FetchStatus.fetching` | The query function is running. |
| `FetchStatus.paused` | A fetch waits for the network, or a retry waits for the app to return to the foreground. |
| `FetchStatus.idle` | Nothing is fetching. |

## QueryResult actions

`refetch()` runs the query again, for example from a pull-to-refresh or a retry button:

```dart
Future<QueryResult<TData>> refetch({
  bool cancelRefetch = true,
  bool throwOnError = false,
})
```

| Argument | Type | Default | What it does |
|---|---|---|---|
| `cancelRefetch` | `bool` | `true` | When the query has data, cancels a fetch in flight and starts a new one. With `false`, or without data, the call joins the fetch in flight. |
| `throwOnError` | `bool` | `false` | `true` makes the returned future fail with the fetch's error. Otherwise the error is only in the result. |

- The returned future completes with the result after the fetch settles.
- It refetches the observer's current query. After a widget moved to another key, that is the new key.
- It fetches even when `enabled` is `false`.
- A result built with the constructor has no observer, so its `refetch()` throws a `StateError`.

## InfiniteQueryResult fields

An `InfiniteQueryResult` has every [`QueryResult` field](#queryresult-fields), with `InfiniteData<TPage, TParam>` as `data`. It adds:

| Field | Type | Meaning |
|---|---|---|
| `pages` | `List<TPage>` | The loaded pages, or an empty list before the first. `data` holds the same pages with their params. |
| `hasNextPage` | `bool` | `getNextPageParam` returned a param. `false` until the first page loads. |
| `hasPreviousPage` | `bool` | `getPreviousPageParam` returned a param. `false` without that option. |
| `isFetchingNextPage` | `bool` | A `fetchNextPage()` is running. |
| `isFetchingPreviousPage` | `bool` | A `fetchPreviousPage()` is running. |
| `isFetchNextPageError` | `bool` | The latest fetch was a `fetchNextPage()`, and it failed. |
| `isFetchPreviousPageError` | `bool` | The latest fetch was a `fetchPreviousPage()`, and it failed. |
| `observer` | `InfiniteQueryObserver<TPage, TParam>?` | The observer that reported the result, as for `QueryResult`. |

`isRefetching` and `isRefetchError` cover a refetch of every page, so both stay `false` while a single page loads or fails.

`fetchNextPage()` and `fetchPreviousPage()` take the same arguments as `refetch()`, and return the result after the page loads:

- A call does nothing when `hasNextPage`, or `hasPreviousPage`, is `false`.
- A call while the same page loads joins that fetch.
- With `cancelRefetch: true`, the default, a call first cancels any other fetch, such as a refetch of every page. With `false`, it joins that fetch and loads no page.

`refetch()` reloads every loaded page, in order: see [Refetching every loaded page](../../guides/infinite-queries/#refetching-every-loaded-page).

## InfiniteData fields

`InfiniteData<TPage, TParam>` is the `data` of an infinite query, and what `getNextPageParam` and `getPreviousPageParam` receive.

| Member | Type | What it is |
|---|---|---|
| `pages` | `List<TPage>` | Every loaded page, in order. |
| `pageParams` | `List<TParam>` | The param each page was loaded with, at the same index. |
| `firstPage`, `lastPage` | `TPage` | The first and the last loaded page. |
| `firstPageParam`, `lastPageParam` | `TParam` | Their params. |
| `mapPages(transform)` | `InfiniteData<TPage, TParam>` | The same data, with each page replaced by what `transform` returns and the same params. See [Updating items in cached pages](../../guides/infinite-queries/#updating-items-in-cached-pages). |

`firstPage`, `lastPage`, and their params throw a `StateError` when there are no pages. To write pages with `setData` or `initialData`, build the data with `InfiniteData(pages: ..., pageParams: ...)`, one param per page.
