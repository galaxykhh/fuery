---
title: QueryClient
description: Read, write, invalidate, and prefetch the Flutter cache, inside widgets or outside them.
---

The `QueryClient` owns the cache. `Fuery.client` is the default client, used whenever you don't pass `client:`.

## Reading and writing the cache

```dart
final client = Fuery.client;

client.getQueryData<List<Todo>>(['todos']);
client.setQueryData(['todos', 1], todo);
client.updateQueryData<List<Todo>>(['todos'], (todos) => [...?todos, todo]);
```

Every widget using the key rebuilds with the new data. Returning `null` from the `updateQueryData` updater leaves the cache unchanged.

## Invalidating

After a change on the server, mark the affected queries stale:

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

Queries that widgets are using refetch right away. The others refetch the next time they're used. Pass `refetchType: RefetchType.none` to only mark them stale.

The other operations take the same filters: `refetchQueries`, `cancelQueries`, `resetQueries`, and `removeQueries`.

## Watching the cache

`client.watch` turns any value computed from the client into a `Stream`. Each listener gets the current value first, then a new value whenever queries or mutations change it. Watching doesn't fetch anything, and values are compared like in [selectors](../widgets/#select-part-of-the-state).

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos'])); // saves in progress
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
final todosQuery = QueryOptions(queryKey: ['todos'], queryFn: (_) => api.getTodos());

final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

To use whatever is cached, however old, set `staleTime: staticStaleTime`. This is handy in route guards and startup code.

`client.infiniteQuery(infiniteQueryOptions(...))` does the same for infinite queries. With nothing cached it loads `pages` pages (default: one); otherwise it reloads the pages already cached.

## Defaults

Configure every query, or every query under a key prefix:

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);
```

Assigning `Fuery.client` mounts the new client, so it refetches on focus and reconnect, and unmounts the previous one.

## Providing a client

To give part of the app its own client, for example in widget tests, wrap it in `FueryProvider`:

```dart
FueryProvider(client: QueryClient(), child: const App());
```

Read it with `context.queryClient`, which falls back to `Fuery.client` when there is no provider, and pass it as `client:` to `Query.use`, `InfiniteQuery.use`, and `Mutation.use`.

## In the example app

The example has prefetching and watching in [the prefetch screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/prefetch/prefetch.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
