---
title: QueryClient
description: Read, write, invalidate, and prefetch cached data.
---

The `QueryClient` owns the cache. `Fuery.instance` is the default client, used whenever you don't pass `client:`.

## Reading and writing the cache

```dart
final client = Fuery.instance;

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

## Fetching outside widgets

`client.query` returns cached data if it's fresh, and fetches otherwise. It throws on failure and doesn't retry unless you set `retry`:

```dart
final todosQuery = QueryOptions(queryKey: ['todos'], queryFn: (_) => api.getTodos());

final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

To use whatever is cached, however old, set `staleTime: staticStaleTime`. This is handy in route guards and startup code.

`client.infiniteQuery(infiniteQueryOptions(...))` does the same for infinite queries, and fetches `pages` pages when nothing is cached.

## Defaults

Configure every query, or every query under a key prefix:

```dart
Fuery.instance = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
  ),
)..mount();

Fuery.instance.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);
```

`mount()` makes the client refetch on focus and reconnect. The default `Fuery.instance` is already mounted.

## Providing a client

To give part of the app its own client, for example in widget tests, wrap it in `FueryProvider`:

```dart
FueryProvider(client: QueryClient(), child: const App());
```

Read it with `context.queryClient`, which falls back to `Fuery.instance` when there is no provider, and pass it as `client:` to `Query.use`, `InfiniteQuery.use`, and `Mutation.use`.
