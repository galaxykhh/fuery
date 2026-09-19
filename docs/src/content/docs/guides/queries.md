---
title: Queries
description: Keys, freshness, results, and query options.
---

```dart
final todo = Query.use(
  queryKey: ['todos', id],
  queryFn: (context) => api.getTodo(id),
  staleTime: const Duration(minutes: 1),
);
```

`Query.use` returns a `QueryObserver`. Widgets and blocs subscribe to it, and the query fetches when it gets its first subscriber.

## Keys

Keys identify cached data. They are lists compared by value, so `['todos', 1]` from two widgets is the same query. Maps inside keys are compared regardless of key order.

A key can contain `null`, `bool`, `num`, `String`, enums, `DateTime`, lists, maps, and objects with a `toJson()` method.

Order keys from general to specific, like `['todos']`, `['todos', 1]`, and `['todos', 1, 'comments']`. Invalidating `['todos']` then also refreshes everything under it.

Each key holds one data type. Using a key with a different type, for example `setQueryData(['todos'], [])` for a `List<Todo>` query, throws a `StateError`. Write `setQueryData<List<Todo>>(['todos'], [])` instead.

## Data can't be null

`null` means "no data yet", so query data types are non-nullable. Use a type like `Future<User>`, and throw or return an empty value when there is nothing to show.

## Freshness

Data is **fresh** for `staleTime` (default: zero) and **stale** afterwards. Stale data is still shown, and it refetches in the background when:

- a new widget starts using the query,
- the app returns to the foreground,
- the network reconnects,
- it is invalidated.

`infiniteDuration` keeps data fresh until it is invalidated. `staticStaleTime` is for data that never changes: it never goes stale and never refetches on its own, even after invalidation.

Queries that no widget uses stay cached for `gcTime` (default: 5 minutes), so going back to a screen shows its data instantly.

## Results

Builders and streams receive a `QueryResult`:

| Field | Meaning |
|---|---|
| `status` | `pending` (no data yet), `error`, or `success` |
| `fetchStatus` | `fetching`, `paused` (waiting for the network), or `idle` |
| `data`, `error` | The latest data and error. `data` is kept when a refetch fails. |
| `isLoading` | First load: pending and fetching |
| `isRefetching` | Fetching while data is shown |
| `isLoadingError` | Failed before any data arrived |
| `isRefetchError` | Failed while data is still shown |
| `isPlaceholderData` | `data` comes from `placeholderData` |
| `isStale`, `failureCount`, `dataUpdatedAt` | Freshness, retries so far, and when data last changed |

## Options

| Option | Default | |
|---|---|---|
| `enabled` | `true` | `false` stops automatic fetching. `refetch()` still works. |
| `staleTime` | zero | How long data stays fresh |
| `gcTime` | 5 minutes | How long unused data stays cached |
| `retry` | `RetryPolicy.count(3)` | Also `.never()`, `.always()`, and `.when((count, error) => ...)` |
| `retryDelay` | 1s, 2s, 4s, … up to 30s | A function of the failure count and error |
| `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect` | `RefetchMode.ifStale` | `.never` or `.always`. `refetchOnReconnect` defaults to `.never` with `NetworkMode.always`. |
| `refetchInterval` | none | Polls while a widget uses the query, counting from its latest change |
| `refetchIntervalInBackground` | `false` | Keep polling while the app is in the background |
| `refetchWhile` | none | Polls only while this returns true for the latest result |
| `retryOnMount` | `true` | `false` doesn't retry a failed query when a widget starts using it |
| `initialData` | none | Seeds the cache as if it had been fetched |
| `initialDataUpdatedAt` | now | When `initialData` was fetched, in milliseconds since epoch |
| `placeholderData` | none | Shown while pending, never cached |
| `networkMode` | `NetworkMode.online` | See [App lifecycle and network](../lifecycle/) |
| `structuralSharing` | `true` | Keeps unchanged data identical across refetches |
| `persist` | none | Stores the data on the device. See [Persistence](../persistence/) |
| `meta` | none | Any values, passed to the query function as `context.meta` |
| `client` | `Fuery.client` | See [Providing a client](../query-client/#providing-a-client) |

## Polling

```dart
final prices = Query.use(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

Polling runs only while a widget or stream listens to the query, and pauses while the app is in the background.

To poll until something finishes, add `refetchWhile`. It is checked on every change, so polling stops when it returns false and resumes when it returns true again, for example after the query is invalidated:

```dart
final job = Query.use(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` also runs before the first result arrives, so handle `state.data` being `null`.

## Dependent queries

When a query needs a value from another query, create it once the value exists. A child widget that receives the value works well:

```dart
QueryBuilder(
  query: user,
  builder: (context, state) {
    final userId = state.data?.id;
    if (userId == null) return const CircularProgressIndicator();
    return ProjectList(userId: userId);
  },
)
```

`ProjectList` creates `Query.use(queryKey: ['projects', userId], ...)` in its state.

## Pagination with placeholder data

Switching to a new key normally shows the pending state until the new page arrives. Keep showing the previous page instead with `placeholderData`:

```dart
final posts = Query.use(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: (previous) => previous,
);

void showPage(int page) {
  posts.setOptions(QueryOptions(
    queryKey: ['posts', page],
    queryFn: (_) => api.getPosts(page),
    placeholderData: keepPreviousData,
  ));
}
```

`keepPreviousData` is the same function by name. Pass it where the data type is already known, as in `setOptions` above. In `Query.use`, write `(previous) => previous`: a generic function there would make Dart infer the data type as `Object` instead of taking it from `queryFn`.

While the next page loads, `state.isPlaceholderData` is `true`, so you can dim the list or disable the next button. For endless scrolling, use an [infinite query](../infinite-queries/) instead.

## Cancellation

Read `context.signal` in the query function to make it cancellable. When the last widget stops using the query, the fetch is aborted instead of finishing in the background:

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

Without the signal, the request finishes and its result is cached for next time.
