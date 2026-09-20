---
title: Queries
description: Query keys, stale time, and results for fetching server data in Flutter.
---

A query is one piece of server data in the cache, named by a key. This page covers the four things you work with: the key, the query object, freshness, and the result. Every option has its own row in [Query options](../../reference/query-options/).

```dart
final todo = Query.use(
  queryKey: ['todos', id],
  queryFn: (context) => api.getTodo(id),
  staleTime: const Duration(minutes: 1),
);
```

`Query.use` returns an **observer**: a handle on the cached data that reports results to whoever listens. Widgets and blocs listen to it, and the query fetches when it gets its first listener.

## Query keys

A key identifies cached data. Keys are lists compared by value, so `['todos', 1]` from two widgets is one query and one request. Maps inside a key are compared regardless of key order.

A key can contain `null`, `bool`, `num`, `String`, enums, `DateTime`, lists, maps, and objects with a `toJson()` method.

Order the parts from general to specific: `['todos']`, `['todos', 1]`, `['todos', 1, 'comments']`. Invalidating `['todos']` then refreshes everything under it.

Each key holds one data type. Using a key with another type throws a `StateError`, which [Troubleshooting](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y) shows how to fix.

## Create the query once

Create a query in a `State` field, in a cubit, or in a function that widgets call. A query created in `build` is a new object on every frame, and the widget subscribes to it again each time.

```dart
class _TodoScreenState extends State<TodoScreen> {
  final todos = Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());
}
```

Creating a query starts nothing, so the field doesn't need to be `late`. Use `late final` when the query reads `widget` or another field, as in `queryKey: ['todo', widget.id]`.

Several screens can each create their own observer for the same key. They share one cache entry and one request, so you never pass a query down the tree. [Organizing queries](../organizing-queries/) shows where to keep them as an app grows.

Those observers can ask for different options. Each keeps its own `staleTime` and `refetchOnMount`, so a screen that wants fresher data still refetches on mount while the other screen shows what is cached. The shared entry keeps the longest `gcTime` any of them asked for.

## Query data can't be null

`null` means "no data yet", so query data types are non-nullable. Use a type like `Future<User>`, and throw or return an empty value when there is nothing to show.

## Stale time and freshness

Data is **fresh** for `staleTime` (default: zero) and **stale** afterwards. Stale data stays on screen and refetches in the background when:

- another widget or stream starts using the query,
- the app returns to the foreground,
- the network reconnects,
- you invalidate it.

Set `staleTime: infiniteDuration` to keep data fresh until you invalidate it. Set `staleTime: staticStaleTime` for data that never changes: it never goes stale and never refetches on its own, not even after invalidation.

Data that nothing uses stays cached for `gcTime` (default: 5 minutes), so returning to a screen shows it instantly.

## QueryResult fields

Builders and streams receive a `QueryResult`. Two enums carry the state, and the rest are named questions about them:

| Field | Meaning |
|---|---|
| `status` | A `QueryStatus`: `pending` (no data yet), `error`, or `success` |
| `fetchStatus` | A `FetchStatus`: `fetching`, `paused` (waiting for the network or the foreground), or `idle` |
| `data`, `error` | The latest data and error. `data` is kept when a refetch fails. |

| Question | True when |
|---|---|
| `isPending`, `isSuccess`, `isError` | `status` is that one |
| `hasData` | `data` isn't null |
| `isFetching`, `isPaused` | `fetchStatus` is that one |
| `isLoading` | First load: pending and fetching |
| `isRefetching` | Fetching while data is shown |
| `isLoadingError` | Failed before any data arrived |
| `isRefetchError` | Failed while data is still shown |
| `isPlaceholderData` | `data` comes from `placeholderData` |
| `isStale` | Older than `staleTime`, so the next trigger refetches |
| `isEnabled` | The query may fetch on its own |
| `isFetched`, `isFetchedAfterMount` | It has fetched at all, and since this observer started |

`failureCount` and `failureReason` describe the attempts since the last success, and `dataUpdatedAt`, `errorUpdatedAt`, and `errorUpdateCount` say when each last changed, in milliseconds since epoch.

## Which errors to retry

A failed fetch retries three times by default, waiting 1s, 2s, then 4s, so a request that can never succeed takes about seven seconds to reach the error branch. Narrow that to the errors worth retrying:

```dart
Fuery.client = QueryClient(
  defaultOptions: DefaultOptions(
    queries: QueryDefaults(
      retry: RetryPolicy.when(
        (failureCount, error) => failureCount < 3 && error is! NotFoundException,
      ),
    ),
  ),
);
```

`RetryPolicy.count(3)` is the default; `RetryPolicy.never()` and `RetryPolicy.always()` are the other shorthands, and a single query can set its own `retry`. Mutations never retry unless you ask them to.

## Polling until something finishes

`refetchInterval` polls while a widget or stream uses the query, and pauses while the app is in the background:

```dart
final prices = Query.use(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

Add `refetchWhile` to stop polling once a job is done. Fuery checks it on every change, so polling stops when it returns false and starts again when it returns true, for example after you invalidate the query:

```dart
final job = Query.use(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` also runs before the first result arrives, so handle `state.data` being `null`.

## Changing what a query asks for

`setOptions` points an existing observer at another key, which is how a search field or a filter works. One observer has to follow every term: a new observer per term starts from nothing.

```dart
void search(String term) {
  results.setOptions(QueryOptions(
    queryKey: ['todos', 'search', term],
    queryFn: (_) => api.searchTodos(term),
    enabled: term.isNotEmpty,
    placeholderData: keepPreviousData,
  ));
}
```

`enabled: false` keeps the query from fetching on its own, so an empty term costs nothing. `refetch()` still fetches when you ask it to.

Debounce in the widget, with a `Timer`, before calling `setOptions`. Each term gets its own cache entry, so going back to an earlier term shows its results at once.

## Queries that depend on another query

`enabled` also covers a query that needs a value from another one:

```dart
final projects = Query.use(
  queryKey: ['projects', userId],
  queryFn: (_) => api.getProjects(userId!),
  enabled: userId != null,
);
```

Or create the second query once the value exists, by passing it to a child widget:

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

`ProjectList` then creates `Query.use(queryKey: ['projects', userId], ...)` in its state.

## Keeping the previous page on screen

Switching to a new key shows the pending state until the new data arrives. `placeholderData` shows the previous data instead:

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

One observer has to follow every page, as `setOptions` does above. A new observer per page has no previous data to show.

`keepPreviousData` is a named shorthand for `(previous) => previous`. Use it inside `QueryOptions`, where the data type is already known. In `Query.use`, write the closure: the generic `keepPreviousData` there makes Dart infer the data type as `Object` instead of taking it from `queryFn`.

While the next page loads, `state.isPlaceholderData` is `true`, so you can dim the list or disable the next button. For endless scrolling, use an [infinite query](../infinite-queries/) instead.

## Opening a detail screen without a spinner

The list already holds the item the detail screen is about to fetch. Read it out of the cache as placeholder data:

```dart
QueryObserver<Todo> todoQuery(int id) => Query.use(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
      placeholderData: (previous) {
        if (previous != null) return previous;
        final todos = Fuery.client.getQueryData<List<Todo>>(['todos', 'list']);
        return todos?.firstWhereOrNull((todo) => todo.id == id);
      },
    );
```

Placeholder data is shown, never cached, and the fetch still runs, so the screen fills in as soon as the full item arrives. Use `initialData` instead when the value should count as fetched data and land in the cache.

## Cancelling a request

Read `context.signal` in the query function to make the request cancellable. Fuery then aborts the fetch when the last widget stops using the query, instead of letting it finish in the background:

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

Without the signal, the request finishes and Fuery caches its result for next time.

`context.signal` is an `AbortSignal`. A query function that works in steps can check `signal.aborted` between them, call `signal.throwIfAborted()` to stop with an `AbortedException`, or race `signal.whenAborted` against its own work. A fetch that `cancelQueries` stops fails with a `CancelledError`, which is worth filtering out before reporting errors to a crash reporter.

## In the example app

The example keeps the previous results while searching in [the search screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search_todos/search_todos.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
