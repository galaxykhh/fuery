---
title: Queries
description: Query keys, stale time, and results for fetching server data in Flutter.
---

A query is one piece of server data in the cache, named by a key. You describe it with `Query`, and pass that description wherever the data is needed. This page covers the key, using a query, freshness, and the result. Every option has its own row in [Query options](../../reference/query-options/).

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

## Query keys

A key identifies cached data. Keys are lists compared by value, so `['todos', 1]` from two widgets is one query and one request. Maps inside a key are compared regardless of key order.

A key can contain `null`, `bool`, `num`, `String`, enums, `DateTime`, lists, maps, and objects with a `toJson()` method.

Order the parts from general to specific: `['todos']`, `['todos', 1]`, `['todos', 1, 'comments']`. Invalidating `['todos']` then refreshes everything under it.

Each key holds one data type. Using a key with another type throws a `StateError`, which [Troubleshooting](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y) shows how to fix.

## Using a query

Pass the query to a widget. A `Query` is only a description, so it can be built anywhere, `build` included:

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

The widget keeps one **observer** for it: a handle on the cached data that fetches when the widget mounts and reports every change. When the widget rebuilds with a query for another key, such as a new `id`, the observer follows it. The same query in another widget or screen shares the cache entry and the request, so you never pass data down the tree.

Outside widgets, in a cubit, a service, or a `State` field that needs the handle itself, call `observe()` once and keep the observer:

```dart
final todos = todosQuery.observe();
todos.stream.listen((result) => print(result.data));
```

Don't call `observe()` in `build`: each call is a new observer that subscribes and fetches again. [Organizing queries](../organizing-queries/) shows where to keep queries as an app grows.

Observers of one key can ask for different options. Each keeps its own `staleTime` and `refetchOnMount`, so a screen that wants fresher data still refetches on mount while the other screen shows what is cached. The shared entry keeps the longest `gcTime` any of them asked for.

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

## Rebuilding only what changed

A refetch usually returns the same data it returned before. Fuery compares the new data with the old one, deeply, and keeps every list, map, and set that didn't change as the same object. A list that came back with one new item is a new list whose other items are the previous objects.

For widgets that means a background refetch of a 50-item list rebuilds the row for the item that changed, and nothing else, as long as the rows take their item as a parameter and the item type has `==`. A `QuerySelector` or a `buildWhen` that compares data sees the same object and doesn't rebuild at all. Structural sharing is on by default; `structuralSharing: false` turns it off for a query whose data is expensive to compare.

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
| `isFetched`, `isFetchedAfterMount` | It has fetched at all, and since this observer got its first listener |

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
final prices = Query(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

Add `refetchWhile` to stop polling once a job is done. Fuery checks it on every change, so polling stops when it returns false and starts again when it returns true, for example after you invalidate the query:

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` also runs before the first result arrives, so handle `state.data` being `null`.

## Changing what a query asks for

A search field or a filter changes the key as the user types. Keep the term in state, and build the query from it:

```dart
Query<List<Todo>> searchQuery(String term) => Query(
      queryKey: ['todos', 'search', term],
      queryFn: (_) => api.searchTodos(term),
      enabled: term.isNotEmpty,
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: searchQuery(_term),
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

`enabled: false` keeps the query from fetching on its own, so an empty term costs nothing. `state.refetch()` still fetches when you ask it to.

Debounce in the widget, with a `Timer`, before calling `setState`. Each term gets its own cache entry, so going back to an earlier term shows its results at once. Outside widgets, pass the next query to the observer's `setOptions` instead.

## Queries that depend on another query

`enabled` also covers a query that needs a value from another one:

```dart
Query<List<Project>> projectsQuery(String? userId) => Query(
      queryKey: ['projects', userId],
      queryFn: (_) => api.getProjects(userId!),
      enabled: userId != null,
    );
```

Or build the second query once the value exists, inside the first one's builder:

```dart
QueryBuilder(
  query: userQuery,
  builder: (context, state) => switch (state.data?.id) {
    final userId? => QueryBuilder(
        query: projectsQuery(userId),
        builder: (context, projects) => ProjectList(projects.data),
      ),
    null => const CircularProgressIndicator(),
  },
)
```

## Keeping the previous page on screen

Switching to a new key shows the pending state until the new data arrives. `placeholderData` shows the previous data instead:

```dart
Query<List<Post>> postsQuery(int page) => Query(
      queryKey: ['posts', page],
      queryFn: (_) => api.getPosts(page),
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: postsQuery(_page),
  builder: (context, state) => PostList(state.data ?? const []),
)
```

The widget keeps its observer when `_page` changes, so the observer has the previous page to show. An observer you create per page has none.

`keepPreviousData` shows the previous data unchanged. Use it where the data type is already known, as in a function with a return type. In a `Query(...)` whose type Dart infers, write `(previous, client) => previous`: the generic `keepPreviousData` there makes Dart infer the data type as `Object` instead of taking it from `queryFn`.

While the next page loads, `state.isPlaceholderData` is `true`, so you can dim the list or disable the next button. For endless scrolling, use an [infinite query](../infinite-queries/) instead.

## Opening a detail screen without a spinner

The list already holds the item the detail screen is about to fetch. Read it out of the cache as placeholder data:

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
      placeholderData: (previous, client) {
        if (previous != null) return previous;
        final todos = client.getData(todosQuery);
        return todos?.firstWhereOrNull((todo) => todo.id == id);
      },
    );
```

`placeholderData` receives the client that runs the query, so it reads the list from the right cache in tests and under a `FueryProvider`.

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

`context.signal` is an `AbortSignal`. A query function that works in steps can check `signal.aborted` between them, call `signal.throwIfAborted()` to stop with an `AbortedException`, or race `signal.whenAborted` against its own work.

A cancellation is not a failure. [`cancelQueries`](../query-client/#the-extra-arguments) puts the query back in the state it had before the fetch, the `CancelledError` never reaches `QueryCacheConfig.onError`, and a cancelled fetch that finishes late never overwrites data that was fetched or written after it. Only a query function that swallows the abort and returns a value can put stale data in the cache.

## In the example app

The example keeps the previous results while searching in [the search screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search/search_screen.dart), and polls a new post until it is published in [the compose screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
