---
title: QueryClient
description: Read, write, invalidate, and prefetch the Flutter cache, inside widgets or outside them.
---

The `QueryClient` owns the cache. Use it to read and write cached data, to invalidate or refetch it, and to fetch outside widgets.

`Fuery.client` is the client every query uses unless you pass `client:`. It is created the first time something needs it, so an app that never configures one still works.

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
final todosOptions = QueryOptions(queryKey: ['todos'], queryFn: (_) => api.getTodos());

final todos = await client.query(todosOptions); // fetch, or use fresh cache
client.query(todosOptions).ignore(); // prefetch: ignore the result and errors
```

To use whatever is cached, however old, set `staleTime: staticStaleTime`. Route guards and startup code use it to read the cache without waiting for a fetch.

`client.infiniteQuery` does the same for [infinite queries](../infinite-queries/), taking the options from `infiniteQueryOptions`. When nothing is cached, it loads as many pages as the `pages` option asks for, one by default. When pages are already cached, it reloads those.

## Default options

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

Assigning `Fuery.client` mounts the new client and unmounts the previous one. The new client then refetches on focus and on reconnect.

Set it in `main()`, before anything creates a query:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Fuery.client = QueryClient(storage: myStorage);
  runApp(const App());
}
```

## Which client a query uses

A query takes its client when you create it: the one you pass as `client:`, or `Fuery.client` at that moment. It keeps that client for its whole life, so assigning `Fuery.client` later leaves existing queries where they are.

Two rules follow:

- **Configure the client first.** A storage or defaults set after a query exists don't reach it.
- **Share queries as functions, not as objects.** A top-level `final todos = Query.use(...)` keeps the client it first saw, which breaks tests that use a fresh client per test. A function creates the query on the current client each time it is called:

  ```dart
  QueryObserver<List<Todo>> todosQuery() =>
      Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());
  ```

  Callers still share one cache entry and one request, because that comes from the key. [Organizing queries](../organizing-queries/) covers the pattern.

## Giving a subtree its own client

To run part of the app on another client, for example in a widget test, wrap it in `FueryProvider`:

```dart
FueryProvider(client: QueryClient(), child: const App());
```

`context.queryClient` reads it, and falls back to `Fuery.client` when there is no provider. A query uses it only when it is passed as `client:`:

```dart
late final todos = Query.use(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  client: context.queryClient,
);
```

## In the example app

The example has prefetching and watching in [the prefetch screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/prefetch/prefetch.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
