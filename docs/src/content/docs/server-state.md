---
title: Server state in Flutter
description: Why server data needs a cache rather than another state class, and what Fuery's cache does for a Flutter app.
---

Server data needs a cache, not another state class: a cache gives every screen the same copy, tracks loading and errors, and refreshes data that went out of date.

Most of what a Flutter app shows comes from a server: a list of todos, a profile, a page of search results. That data behaves differently from the state the app owns:

- **The app doesn't own it.** It changes on the server, without telling the app.
- **It's shared.** Several screens show the same list, and they should agree.
- **It arrives late, or not at all.** Every read has a loading state and an error state.
- **It goes out of date.** A list fetched a minute ago can be wrong now.

App state, such as which tab is selected, has none of those problems:

| | App state | Server data |
|---|---|---|
| Who changes it | Your code | The server, at any time |
| Who holds the truth | The app | Somewhere else |
| Arrives | Immediately | Later, or not at all |
| Goes out of date | No | Yes |

If you keep server data with app state, you write the cache yourself: a cache in the repository, a loading flag per screen, a refresh method, invalidation after every write, and a rule for two screens that ask at once.

## What a cache gives you

Fuery keeps server data in one cache, under a key:

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

From that one definition:

- **One copy per key.** Every screen that uses `['todos']` reads the same cache entry.
- **One request at a time.** Screens that ask while a fetch runs share that request.
- **Fresh, then stale.** Data is fresh for `staleTime` (default: zero, so stale as soon as it arrives).
- **Old data stays on screen.** Screens keep showing it while Fuery refetches in the background.
- **Refetches on its own.** Fuery refetches stale data when a screen starts using it, the app returns to the foreground, or the network reconnects.
- **Refetches after writes.** Invalidating `['todos']` after a mutation refetches the list on screen.
- **Loading and errors come with the data.** The result carries `status`, `error`, and flags such as `isRefetching`, so a screen reads them instead of tracking them.
- **Unused data leaves memory.** Fuery removes data that no screen uses after `gcTime`, the garbage collection time (default: 5 minutes). Persisted data stays on the device.

[Query lifecycle](../how-the-cache-works/#query-lifecycle) lists each stage of cached data and what ends it.

## Where the cache runs

The cache is a plain Dart object, not part of the widget tree. The same query works in three places:

- a `QueryBuilder` renders it,
- a cubit listens to the `stream` of `todosQuery.observe()`,
- a script awaits `client.query(todosQuery)`.

Fuery doesn't replace the state management you already use. [Bloc and cubits](../guides/bloc/) shows queries inside cubits and blocs.

## Next steps

- [How the cache works](../how-the-cache-works/): definitions, clients, observers, and the lifecycle of cached data.
- [Getting started](../getting-started/): install Fuery and cache your first request.
- [Queries](../guides/queries/): keys, freshness, and the options.
- [Try the demo](/fuery/demo/): the example app in a browser, with the devtools.
