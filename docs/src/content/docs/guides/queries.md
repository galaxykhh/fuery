---
title: Queries
description: "Fetch and cache server data in Flutter: query keys, freshness, retries, dependent queries, polling, and cancellation."
---

A query describes one piece of server data: the key it is cached under and the function that fetches it. Every widget that shows the same key shares one cache entry and one request, so you never pass the data down the tree.

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

[Query options](../../reference/query-options/) lists every option. [How the cache works](../../how-the-cache-works/) explains when a query fetches and when its data leaves memory.

## Query keys

A key is a list that names a cache entry. Fuery compares keys by value, so `['todos', 1]` built in two widgets is one cache entry and one request.

Order the parts from general to specific: `['todos']`, `['todos', 1]`, `['todos', 1, 'comments']`. Invalidating `['todos']` then refreshes every key that starts with it.

A key can hold `null`, `bool`, `num`, `String`, enums, `DateTime`, lists, maps, and objects with a `toJson()` method. Fuery compares keys by their JSON form:

- A `DateTime` becomes its ISO 8601 string.
- An enum becomes its type and name, such as `'Filter.done'`.
- An object becomes what its `toJson()` returns.
- Map keys become strings, so `{1: 'a'}` and `{'1': 'a'}` are the same key.
- The order of map entries doesn't matter.
- `1` and `1.0` are different keys on mobile and desktop, and the same key on the web. Use `int` for numbers in keys.

Each key holds one data type. Using a key with another type throws a `StateError`: see [Troubleshooting](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y) for the fix.

## Using a query

Pass the query to a widget. A `Query` holds no data and starts nothing, so build it wherever you need it, `build` included:

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

While it is mounted, the widget keeps one [observer](../../how-the-cache-works/#observers) for the query, which fetches and reports each change. When the widget rebuilds with another key, such as a new `id`, the observer follows it. [Query results](../../reference/query-results/#queryresult-fields) lists what `state` holds.

Outside widgets, in a cubit, a service, or a `State` field, call `observe()` once and keep the observer:

```dart
final todo = todoQuery(1).observe();
todo.stream.listen((result) => print(result.data));
```

Don't call `observe()` in `build`. Each call creates an observer that subscribes and fetches again. [Organizing queries](../organizing-queries/) shows where to keep queries as an app grows.

## Query data can't be null

Fuery uses `null` for "no data yet", so a query function returns a non-nullable type, such as `Future<User>`. When there is nothing to show, return an empty value, such as an empty list, or throw.

## Stale time and freshness

Data is fresh for `staleTime` (default: zero) and stale after it. Stale data stays on screen. Fuery refetches it in the background when a widget or stream starts using the query, the app returns to the foreground, the network reconnects, or you invalidate the query. [Query lifecycle](../../how-the-cache-works/#query-lifecycle) lists every stage.

Set `staleTime` to how long the data can be shown without asking the server again:

- `Duration(minutes: 1)` keeps the data fresh for a minute after each fetch. Within that minute, Fuery doesn't refetch it when a widget or stream starts using the query, the app returns to the foreground, or the network reconnects. Invalidating the query still refetches it.
- `infiniteDuration` keeps the data fresh until you invalidate it.
- `staticStaleTime` is for data that never changes. The data never goes stale and never refetches on its own, not even after you invalidate it.

Two screens can show one key with different `staleTime` values, and each screen judges freshness by its own. With data fetched 30 seconds ago, a screen whose query sets `staleTime` to 10 seconds refetches when it opens. A screen whose query sets it to 1 minute shows the cached data without refetching.

Data that no widget or stream uses stays in memory for `gcTime` (garbage collection time, default: 5 minutes). A screen opened again within that time shows the data at once.

## Which errors to retry

A failed fetch retries three times by default, waiting 1s, 2s, then 4s. A request that can never succeed therefore takes about seven seconds to reach the error branch. Retry only the errors worth retrying:

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

In `RetryPolicy.when`, `failureCount` is 0 for the first failure, so `failureCount < 3` allows three retries. `QueryResult.failureCount` is the number of failed attempts instead, so it is 1 after the first failure.

`RetryPolicy.count(3)` is the default, and `RetryPolicy.never()` and `RetryPolicy.always()` are the other shorthands. A single query can set its own `retry`. `client.query` and mutations retry only when a `retry` is set, on the definition or in the defaults.

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

- `enabled: false` keeps the query from fetching on its own, so an empty term sends no request. `state.refetch()` still fetches.
- `placeholderData` keeps the previous results on screen while the next term loads: see [Keeping the previous page on screen](#keeping-the-previous-page-on-screen).
- Each term gets its own cache entry, so going back to an earlier term shows its results at once.

Debounce in the widget, with a `Timer`, before calling `setState`. Outside widgets, pass the next query to the observer's `setOptions`.

## Queries that depend on another query

Set `enabled` from the value the query needs:

```dart
Query<List<Project>> projectsQuery(String? userId) => Query(
      queryKey: ['projects', userId],
      queryFn: (_) => api.getProjects(userId!),
      enabled: userId != null,
    );
```

Or build the second query inside the first one's builder, once the value exists:

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

A new key shows the pending state until its data arrives. `placeholderData` shows the previous key's data instead:

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

The widget keeps its observer when `_page` changes, so the observer still has the previous page to show. An observer you create for each page has none.

While the next page loads, `state.isPlaceholderData` is `true`. Use it to dim the list or disable the next button. For endless scrolling, use an [infinite query](../infinite-queries/) instead.

`keepPreviousData` needs the data type from its surroundings, such as the return type of `postsQuery`. In a `Query(...)` whose type Dart infers, write `(previous, client) => previous` instead. There, `keepPreviousData` makes Dart infer the data type as `Object` rather than take it from `queryFn`.

## Opening a detail screen without a spinner

The list screen already holds the item that the detail screen fetches. Return it as placeholder data:

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

`placeholderData` receives the client that runs the query, so it reads the right cache in tests and under a `FueryProvider`. Fuery never caches placeholder data: the fetch still runs, and the full item replaces it. Use `initialData` instead for a value that should go into the cache as fetched data.

## Polling until something finishes

`refetchInterval` polls while a widget or stream uses the query, and pauses while the app is in the background:

```dart
final prices = Query(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

Add `refetchWhile` to stop polling once a job is done. Fuery checks it on every change: polling stops when it returns `false`, and starts again when it returns `true`, for example after you invalidate the query.

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` also runs before the first data arrives, so handle `state.data` being `null`.

## Rebuilding only what changed

Fuery compares refetched data with the cached data, deeply, and keeps the cached objects that didn't change:

- Equal data stays the same object.
- In a list that changed, each item equal to the item at the same index stays the previous object. Items compare with `==`.

Code that compares data with `==`, such as a `buildWhen`, then sees no change where nothing changed. This builder skips the rebuild when a refetch returns the same todos, although `List` compares by identity:

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.data != current.data,
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

Structural sharing is on by default. Set `structuralSharing: false` for a query whose data is expensive to compare.

## Cancelling a request

Read `context.signal` in the query function to make the request cancellable. Fuery then aborts the fetch when no widget or stream uses the query anymore, instead of letting it finish in the background:

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

`context.signal` is an `AbortSignal`. A query function that works in steps can check `signal.aborted` between them, call `signal.throwIfAborted()` to stop with the cancellation's `CancelledError`, or race `signal.whenAborted` against its own work. Fuery always aborts the signal with that `CancelledError`, never with an `AbortedException`.

Fuery doesn't treat a cancellation as a failure:

- By default, [`cancelQueries`](../../reference/query-client/#refetch-and-cancel-arguments) puts the query back in the state it had before the fetch.
- The `CancelledError` never reaches `QueryCacheConfig.onError`.
- A cancelled fetch that finishes late never overwrites data fetched or written after it.

Only a query function that ignores the abort and returns a value can put outdated data in the cache.

A `CancelledError` that the query function throws itself is a failure like any other. For example, a query function that awaits `context.client.query(userQuery)` throws one when `userQuery` is removed while it loads, or cancelled before it has data. Fuery retries the query whose function threw it, as its `retry` allows. When every attempt fails, that query goes to error, and `QueryCacheConfig.onError` receives the `CancelledError`.

## In the example app

The example keeps the previous results while searching in [the search screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search/search_screen.dart), and polls a new post until it is published in [the compose screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
