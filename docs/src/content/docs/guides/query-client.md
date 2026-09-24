---
title: QueryClient
description: Read, write, invalidate, and prefetch the Flutter cache, set defaults, and report every failure in one place.
---

The `QueryClient` owns the cache. Use it to read and write cached data, to invalidate or refetch it, and to fetch outside widgets.

`Fuery.client` is the client every widget uses without a `FueryProvider`, and every observer from `observe()` uses unless you pass `client:`. It is created the first time something needs it, so an app that never configures one still works. In a widget, `context.queryClient` returns the client of the nearest provider, or `Fuery.client`.

## Reading and writing the cache

```dart
final client = Fuery.client;

client.getData(todosQuery);                             // the data, or null
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.getQueryState(['todos'])?.dataUpdatedAt;         // the whole QueryState
```

`getData`, `setData`, and `updateData` take the key and the data type from the [query](../organizing-queries/), so there is nothing to cast. A query that `setData` creates gets all of its options, so it stores its data with `persist` and can refetch. Every widget using the key rebuilds with the new data, and returning `null` from the `updateData` updater leaves the cache unchanged.

With only a key, use `getQueryData`, `setQueryData`, and `updateQueryData`, and name the data type: `client.getQueryData<List<Todo>>(['todos'])`.

The reads take one exact key. `getQueryState` returns the `QueryState` behind the data, with `status`, `fetchStatus`, `error`, `dataUpdatedAt`, `errorUpdatedAt`, and `isInvalidated`. It also counts what happened: `dataUpdateCount` and `errorUpdateCount` since the query appeared, and `fetchFailureCount` with `fetchFailureReason` for the attempts since the last success, which a `QueryResult` reports as `failureCount` and `failureReason`.

Writing many keys at once, for example from one websocket frame, goes through `notifyManager.batch`. It collects the rebuilds and delivers them once:

```dart
notifyManager.batch(() {
  for (final todo in frame.todos) {
    client.setQueryData(['todo', todo.id], todo);
  }
});
```

## Updating many queries at once

`updateQueriesData` updates every query under a key that holds the updater's type, such as a post in every cached search result:

```dart
client.updateQueriesData(
  queryKey: ['posts', 'search'],
  (List<Post> posts) => [
    for (final post in posts) post.id == id ? post.copyWith(liked: true) : post,
  ],
);
```

- Queries of another type under the same key are left alone, so a prefix can mix lists and details.
- Queries without data are skipped, and returning `null` leaves a query unchanged.
- The type comes from the parameter of the updater, so give it one: the queries' data type exactly, not a supertype such as `Iterable<Post>`. Without a type, `updateQueriesData` throws an `ArgumentError` rather than update nothing.
- `updatedAt` sets when the new data counts as fetched, as for `setData`.

## Listing what is cached

`getQueriesData` reads many keys at once and returns the key and data of every match. It takes `queryKey`, `exact`, and `predicate`:

```dart
for (final (key, todo) in client.getQueriesData<Todo>(queryKey: ['todo'])) {
  print('$key holds $todo');
}
```

Every match has to hold the same type, because Fuery casts the data to the type argument. Keep detail keys like `['todo', 1]` under a different prefix than the list at `['todos']`.

For anything else, read the caches. `client.queryCache` and `client.mutationCache` expose `getAll`, `find`, and `findAll`:

```dart
final loading = client.queryCache.findAll(
  const QueryFilters(type: QueryTypeFilter.active, stale: true),
);
final saving = client.mutationCache.findAll(
  const MutationFilters(status: MutationStatus.pending),
);
```

A `CachedQuery` from the cache exposes `queryKey`, `state`, `options`, and `meta`, and a `CachedMutation` the same for a mutation. The caches only read. Change queries through the client.

## Invalidating

After a change on the server, mark the affected queries stale:

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

Queries that widgets are using refetch right away. The others refetch the next time they're used. Pass `refetchType: RefetchType.none` to only mark them stale.

## Choosing which queries an operation touches

Six calls pick their queries with the same filters. Each adds arguments of its own:

| Call | What it does | Its own arguments |
|---|---|---|
| `invalidateQueries` | Marks the matches stale and refetches the active ones. | `refetchType`, `cancelRefetch`, `throwOnError` |
| `refetchQueries` | Refetches the matches. Skips disabled queries, and static ones that have data. | `cancelRefetch`, `throwOnError` |
| `resetQueries` | Returns the matches to their initial state, then refetches the active ones. | `cancelRefetch`, `throwOnError` |
| `cancelQueries` | Cancels the fetches in flight. | `revert`, `silent` |
| `removeQueries` | Deletes the matches from the cache. | none |
| `isFetching` | Counts the matches that are fetching. | none |

`isMutating` counts pending mutations instead, and takes the mutation filters: `mutationKey`, `exact`, and a `predicate` that receives an `AnyCachedMutation`.

### The filters

Every filter you set has to match.

| Filter | Type | Default | Selects |
|---|---|---|---|
| `queryKey` | `List<Object?>` | every query | Queries whose key starts with this one. `['todos']` matches `['todos', 1]`. |
| `exact` | `bool` | `false` | `true` matches the single query with exactly this key. |
| `type` | `QueryTypeFilter` | `.all` | `.active`: an enabled widget or subscriber is using the query. `.inactive`: nothing is using it. |
| `stale` | `bool?` | unset | `true` for stale queries only, `false` for fresh ones. |
| `predicate` | `bool Function(CachedQuery<Object>)` | unset | Queries this returns `true` for. |

### The extra arguments

| Argument | Default | What it does |
|---|---|---|
| `refetchType` | active queries | Which matches refetch: `RefetchType.active`, `.inactive`, `.all`, or `.none` to only mark them stale. |
| `cancelRefetch` | `true` | Cancels the fetch in flight and starts a new one. `false` waits for the one already running. |
| `throwOnError` | `false` | `true` makes the returned future fail when a refetch fails. |
| `revert` | `true` | Puts the cancelled query back in the state it had before the fetch. `false` records the cancellation as its error. |
| `silent` | `false` | `true` records nothing and returns the query to idle. |

Without `refetchType`, `invalidateQueries` refetches the matches that `type` selected, or the active ones when `type` is unset.

### Refreshing only what is on screen

```dart
client.invalidateQueries(
  queryKey: ['todos'],
  type: QueryTypeFilter.active,
);
```

Without `type`, Fuery marks every matching query stale and refetches the active ones. With `type: QueryTypeFilter.active`, it leaves the queries nothing is showing alone: they keep their data, and refetch on mount only once their `staleTime` has passed.

### Clearing one user's keys

A `predicate` reaches into the key when a prefix isn't enough:

```dart
client.removeQueries(
  predicate: (query) => query.queryKey.contains(userId),
);
```

The predicate receives the `CachedQuery`, so it can read `query.state` and `query.options` as well, for example to drop every query that failed.

## Watching the cache

`client.watch` turns any value computed from the client into a `Stream`. Each listener gets the current value first, then a new value whenever queries or mutations change it. Watching doesn't fetch anything, and values are compared like in [selectors](../widgets/#selecting-part-of-the-state).

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos']) > 0); // saving
client.watch((client) => client.getQueryData<List<Todo>>(['todos'])); // cached data
```

A global loading bar, for example, is a `StreamBuilder` over a stream created once:

```dart
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key});

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar> {
  late final fetching = context.queryClient.watch(
    (client) => client.isFetching() > 0,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: fetching,
      builder: (context, snapshot) => snapshot.data == true
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
```

In a bloc, listen to the stream like any other.

## Fetching outside widgets

`client.query` returns cached data if it's fresh, and fetches otherwise. It throws on failure and doesn't retry unless you set `retry`:

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

To use whatever is cached, however old, set `staleTime: staticStaleTime`. Route guards and startup code use it to read the cache without waiting for a fetch.

## Fetching an infinite query outside widgets

`client.infiniteQuery` does the same for [infinite queries](../infinite-queries/). `pages` sets how many pages it loads:

```dart
InfiniteQuery<TodoPage, int> pagedTodosQuery() => InfiniteQuery(
      queryKey: ['todos', 'paged'],
      queryFn: (context) => api.getPage(context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
      pages: 3,
    );

await client.infiniteQuery(pagedTodosQuery());
```

`pages` is how many pages to load when nothing is cached, one by default. When pages are already cached, `client.infiniteQuery` reloads those instead and ignores `pages`. Widgets and observers ignore it: they load the first page, then whatever `fetchNextPage()` asks for.

## Setting defaults for every query and mutation

Configure the whole client, or a key prefix:

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    mutations: MutationDefaults(retry: RetryPolicy.count(2)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);

Fuery.client.setMutationDefaults(
  ['todos'],
  const MutationDefaults(networkMode: NetworkMode.offlineFirst),
);
```

`QueryDefaults` takes the [query options](../../reference/query-options/) that aren't specific to one query: `enabled`, `staleTime`, `gcTime`, `refetchInterval`, `refetchIntervalInBackground`, `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect`, `retryOnMount`, `retry`, `retryDelay`, `networkMode`, `structuralSharing`, and `meta`. `MutationDefaults` takes `gcTime`, `retry`, `retryDelay`, `networkMode`, and `meta`.

Per-key defaults win over client defaults, and options set on the query or mutation itself win over both. A mutation only picks up per-key defaults when it has a `mutationKey`. `getQueryDefaults(['settings'])` and `getMutationDefaults(['todos'])` return what a key resolves to, merged from every prefix you registered.

Assigning `Fuery.client` mounts the new client and unmounts the previous one. The new client then refetches on focus and on reconnect.

Set it in `main()`, before anything creates a query:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Fuery.client = QueryClient(storage: myStorage);
  runApp(const App());
}
```

## Reporting every failure in one place

Give the caches a config to run a callback for every query and every mutation. This is where an app reports to a crash or logging service:

```dart
Fuery.client = QueryClient(
  queryCache: QueryCache(
    config: QueryCacheConfig(
      onError: (error, query) => reportError(error, query.queryKey),
    ),
  ),
  mutationCache: MutationCache(
    config: MutationCacheConfig(
      onError: (error, variables, context, mutation) =>
          reportError(error, mutation.options.mutationKey),
    ),
  ),
);
```

A cache keeps its config for its whole life, so pass it when you construct the client.

`QueryCacheConfig` takes three callbacks, each with the `CachedQuery` as its last argument:

| Callback | Runs |
|---|---|
| `onSuccess(data, query)` | After a fetch resolves |
| `onError(error, query)` | After a fetch fails and its retries are used up |
| `onSettled(data, error, query)` | After either |

A cancelled fetch is not a failure and reaches none of them.

`MutationCacheConfig` takes four, each with the mutation as its last argument:

| Callback | Runs |
|---|---|
| `onMutate(variables, mutation)` | Before `mutationFn` |
| `onSuccess(data, variables, context, mutation)` | After success |
| `onError(error, variables, context, mutation)` | After failure |
| `onSettled(data, error, variables, context, mutation)` | After either |

Each of these runs before the matching [callback on the mutation itself](../mutations/#callbacks), and Fuery awaits a future it returns. The mutation arrives as `AnyCachedMutation`, a mutation of unknown types, so `data`, `variables`, and `context` come in as `Object?`. Identify it by `mutation.options.mutationKey` or `mutation.options.meta`.

## Catching errors that callbacks throw

Some errors have no caller to go to, and `onUncaughtError` receives them:

- An error thrown by a `QueryCacheConfig` or `MutateOptions` callback.
- An error thrown by `onError` or `onSettled` of a mutation that failed.
- A mistake Fuery finds while running, such as a `getNextPageParam` that returns a param of the wrong type, or a persisted `mutationKey` that can't be stored.

```dart
Fuery.client = QueryClient(
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

The query or mutation goes on as if the callback hadn't thrown. Fuery reports a mistake once per client, not every time the code runs. When `onUncaughtError` throws, its error and the one it received go to the current zone.

Without `onUncaughtError`, these errors go to the current zone, and Flutter passes them to `PlatformDispatcher.onError`. A crash reporter that records everything there as fatal counts them as crashes, although the app keeps running. With `onUncaughtError`, you decide how to record them.

The callbacks of a `Mutation` and a `MutationCacheConfig` are part of the mutation: an error thrown by `onMutate`, or by `onSuccess` or `onSettled` after a success, fails the mutation and reaches its `onError`.

## Resuming mutations that paused offline

A mutation started while the device is offline waits, and Fuery resumes it when the app is focused again or the network reconnects. Call `resumePausedMutations` to resume at another moment:

```dart
await client.resumePausedMutations();
```

It resumes every paused mutation on the client, and does nothing while the device is still offline. A paused mutation is gone after a restart unless it has a `persist`: see [persisting mutations](../persistence/#persisting-mutations).

## Clearing everything at logout

```dart
Future<void> logout() async {
  await api.logout();
  Fuery.client.clear();
}
```

`clear()` removes every query and every mutation, and deletes all [persisted data](../persistence/#deleting-stored-data). The client itself stays, along with the defaults registered through `setQueryDefaults` and `setMutationDefaults`.

A mutation already sending finishes. A mutation still waiting, for the network or for its turn in a scope, is dropped: it fails with a `CancelledError`, which reaches its `onError` and `onSettled` callbacks.

Clear once the screens that use queries are gone. An observer still subscribed when `clear()` or `removeQueries` runs doesn't stop: Fuery moves it to a new query for the same key, and that query loads like a new one. A list still on screen therefore refetches right away, with the logged-out session. Navigate to the login screen first, and unsubscribe any observer you subscribed by hand.

## Which client a query uses

A `Query` holds no client. The client is chosen where the query is used:

- A widget that gets a query or a mutation uses the client of the nearest `FueryProvider`, or `Fuery.client` without one. It follows a provider whose client is replaced.
- `observe()` uses the client you pass as `client:`, or `Fuery.client` at that moment, and keeps it for the observer's whole life.
- Query functions, `placeholderData`, and mutation callbacks receive the client that runs them.

So queries can be top-level values, and a test that gives each widget test a fresh client through `Fuery.client` or a `FueryProvider` needs nothing else. Configure the client before creating observers: a storage or defaults set afterwards don't reach an observer that already exists.

## Giving a subtree its own client

To run part of the app on another client, for example in a widget test, wrap it in `FueryProvider`:

```dart
FueryProvider(client: QueryClient(), child: const App());
```

Widgets below it use that client. `context.queryClient` returns it, and falls back to `Fuery.client` when there is no provider. Pass it to `observe` for an observer of your own:

```dart
late final todos = todosQuery.observe(client: context.queryClient);
```

An adapter for another way of building widgets, such as hooks, reads the client with `FueryProvider.of(context, listen: true)`, which rebuilds when the provider's client is replaced.

## In the example app

The example prefetches a post when the pointer hovers its card in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart), and watches the client for an activity indicator in [the home shell](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
