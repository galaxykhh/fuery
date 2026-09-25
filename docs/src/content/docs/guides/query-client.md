---
title: Reading and updating the cache
description: Read, write, invalidate, and watch cached data in Flutter, fetch outside widgets, and clear the cache at logout.
---

With the `QueryClient`, you update what every screen shows without a new request, refetch data after a change on the server, and fetch before a screen opens. In a widget, `context.queryClient` returns the client the widgets use. Elsewhere, use the client you configured: `Fuery.client`, or the one you passed to `FueryProvider`. See [Which client a query uses](../client-setup/#which-client-a-query-uses).

## Reading and writing the cache

The client keeps one cache entry (`CachedQuery`) for each query key: the data and state of that key. Read and write the data with the query definition:

```dart
final client = Fuery.client;

client.getData(todosQuery);                             // the data, or null
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.getQueryState(['todos'])?.dataUpdatedAt;         // the whole QueryState
```

- `getData`, `setData`, and `updateData` take the key and the data type from the [query definition](../organizing-queries/), so there is nothing to cast.
- Every widget that uses the key rebuilds with the new data.
- When the key has no cache entry, `setData` creates one with every option of the query, so Fuery stores its data with `persist` and can refetch it.
- Returning `null` from the `updateData` updater leaves the cache unchanged.

With only a key, use `getQueryData`, `setQueryData`, and `updateQueryData`, and name the data type: `client.getQueryData<List<Todo>>(['todos'])`. A cache entry that `setQueryData` creates has no query function, so refetches skip it until an observer or `client.query` brings a query for its key. Reading a key as another data type throws a [`StateError`](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y).

`getQueryState` returns the `QueryState` of one key, such as when its data was last updated. [QueryState fields](../../reference/query-client/#querystate-fields) lists its fields.

To write many keys at once, for example from one websocket frame, wrap the writes in `notifyManager.batch`. Fuery then notifies the widgets once, after the last write:

```dart
notifyManager.batch(() {
  for (final todo in frame.todos) {
    client.setQueryData(['todo', todo.id], todo);
  }
});
```

## Updating many queries at once

`updateQueriesData` updates every cache entry under a key whose data has the updater's type, such as a post in every cached search result:

```dart
client.updateQueriesData(
  queryKey: ['posts', 'search'],
  (List<Post> posts) => [
    for (final post in posts) post.id == id ? post.copyWith(liked: true) : post,
  ],
);
```

- Fuery skips cache entries of another data type under the key, so one prefix can hold lists and details.
- Fuery skips cache entries without data. Returning `null` leaves a cache entry unchanged.
- Give the updater's parameter the exact data type of the cache entries, not a supertype such as `Iterable<Post>`. Without a type, `updateQueriesData` throws an `ArgumentError`.
- `updatedAt` sets when the new data counts as fetched, as for `setData`.

## Listing what is cached

`getQueriesData` returns the key and data of every cache entry that matches `queryKey`, `exact`, and `predicate`:

```dart
for (final (key, todo) in client.getQueriesData<Todo>(queryKey: ['todo'])) {
  print('$key holds $todo');
}
```

Every match must hold data of the type you pass, because Fuery casts the data to it. Keep detail keys like `['todo', 1]` under another prefix than the list at `['todos']`.

For anything else, read the caches. `client.queryCache` and `client.mutationCache` have `getAll`, `find`, and `findAll`:

```dart
final staleOnScreen = client.queryCache.findAll(
  const QueryFilters(type: QueryTypeFilter.active, stale: true),
);
final saving = client.mutationCache.findAll(
  const MutationFilters(status: MutationStatus.pending),
);
```

A match in the query cache is a cache entry (`CachedQuery`). A match in the mutation cache is the run of one `mutate` call (`CachedMutation`). [Caches](../../reference/query-client/#caches) lists their fields. The caches are read-only: change the cache through the client.

## Invalidating

After a change on the server, mark the cache entries it affects stale:

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

Fuery refetches the matching cache entries in use right away: those with an enabled [observer](../../how-the-cache-works/#observers), such as a mounted widget. The others refetch the next time something uses them. Pass `refetchType: RefetchType.none` to only mark them stale.

## Choosing which queries an operation touches

`invalidateQueries`, `refetchQueries`, `resetQueries`, `cancelQueries`, `removeQueries`, and `isFetching` select cache entries with the same filters: `queryKey`, `exact`, `type`, `stale`, and `predicate`. See [Operations on matching queries](../../reference/query-client/#operations-on-matching-queries), [Query filters](../../reference/query-client/#query-filters), and [Refetch and cancel arguments](../../reference/query-client/#refetch-and-cancel-arguments).

### Refreshing only what is on screen

```dart
client.invalidateQueries(
  queryKey: ['todos'],
  type: QueryTypeFilter.active,
);
```

Without `type`, Fuery marks every match stale and refetches the ones in use. With `type: QueryTypeFilter.active`, it touches only the ones in use. The others keep their data and stay fresh until their `staleTime` passes.

### Clearing one user's keys

When a prefix isn't enough, a `predicate` reads the whole key:

```dart
client.removeQueries(
  predicate: (query) => query.queryKey.contains(userId),
);
```

The predicate receives the cache entry (`CachedQuery`), so it can also test `query.state` and `query.options`, for example to remove every cache entry whose fetch failed.

## Watching the cache

`client.watch` turns any value computed from the client into a `Stream`, for example to show a loading bar while anything fetches:

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos']) > 0); // saving
client.watch((client) => client.getQueryData<List<Todo>>(['todos'])); // cached data
```

- Each listener gets the current value first, then every new value after the query cache or the mutation cache changes.
- Fuery compares values as [selectors](../widgets/#selecting-part-of-the-state) do, so an equal value emits nothing.
- Watching fetches nothing.

Create the stream once, for example in a `State` field, and show it with a `StreamBuilder`:

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

To show whether a mutation is running, widgets need no stream: [`MutationStateSelector`](../mutations/#showing-every-run-of-a-mutation) shows it, and so does `useMutationState` in a `HookWidget`.

## Fetching outside widgets

`client.query` returns the cached data while it is fresh and fetches otherwise. Route guards, startup code, and prefetching use it:

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

- Data is fresh for the query's `staleTime`. With the default of zero, `client.query` fetches every time.
- A call that needs to fetch waits for a fetch already running for the key, instead of starting another.
- It throws when the fetch fails.
- It retries only when the query, `defaultOptions`, or a `setQueryDefaults` call for its key sets `retry`.

To use whatever is cached, however old, set `staleTime: staticStaleTime`. `client.query` then fetches only when nothing is cached.

## Fetching an infinite query outside widgets

`client.infiniteQuery` does the same for [infinite queries](../infinite-queries/):

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

- `pages` sets how many pages a fetch loads when nothing is cached: one by default, and never more than `maxPages`.
- `pages` belongs to the definition, so a widget that shows this query also loads three pages first.
- When pages are cached, a fetch reloads them from the first, up to `maxPages`, and ignores `pages`.

## Clearing everything at logout

```dart
Future<void> logout() async {
  await api.logout();
  Fuery.client.clear();
}
```

`clear()` removes every cache entry and every mutation run, and deletes all [persisted data](../persistence/#deleting-stored-data). The client stays, with the defaults registered through `setQueryDefaults` and `setMutationDefaults`.

What happens to a running mutation depends on its stage:

- A mutation already sending its request finishes.
- A mutation still waiting, for the network or for its turn in a scope, fails with a `CancelledError`. `mutateAsync` throws it, and the mutation's state shows it. None of its callbacks run, including those of `MutationCacheConfig` and of its `mutate` call, so no rollback writes the old session's data back.

Clear once the screens that use queries are gone. An observer still subscribed when `clear()` or `removeQueries` runs moves to a new cache entry for the same key, which loads like a new one. A list still on screen therefore refetches right away, with the logged-out session. Navigate to the login screen first, and unsubscribe any observer you subscribed by hand.

## In the example app

The example prefetches a post when the pointer hovers its card in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart), and watches the client for an activity indicator in [the home shell](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
