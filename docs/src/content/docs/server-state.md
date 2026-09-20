---
title: Server state in Flutter
description: What server state is, why it needs caching rather than another state class, and how Fuery handles it.
---

Most of what a Flutter app shows comes from a server: a list of todos, a profile, a page of search results. That data behaves differently from the state you own.

- **You don't own it.** It changes on the server, without telling the app.
- **It's shared.** Several screens show the same list, and they should agree.
- **It arrives late, and can fail.** Every read has loading and error states.
- **It goes out of date.** What you fetched a minute ago may be wrong now.

App state, such as which tab is selected, has none of those problems:

| | App state | Server data |
|---|---|---|
| Who changes it | Your code | The server, at any time |
| Who holds the truth | The app | Somewhere else |
| Arrives | Immediately | Later, or not at all |
| Goes out of date | No | Yes |

Hold server data in the same place as app state and you end up writing the cache yourself: a cache in the repository, a loading flag per screen, a refresh method, invalidation after every write, and a rule for what happens when two screens ask at once.

## What a cache gives you

Fuery gives that data a key and keeps it in one cache:

```dart
final todos = Query.use(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

From that one declaration:

- **One request.** Every screen using `['todos']` shares the same cache entry and the same in-flight request.
- **Fresh, then stale.** Data is fresh for `staleTime`; after that it refetches in the background while the old data stays on screen.
- **Automatic refetching.** When the app comes back to the foreground, when the network reconnects, or when a mutation invalidates the key.
- **Loading and errors come with it.** The result carries `status`, `error`, and flags like `isRefetching`, so a screen reads them instead of tracking them.
- **Cleaned up.** Unused data is dropped after `gcTime`, or kept on the device if you persist it.

## Where the cache runs

The cache is a plain Dart object, so it isn't tied to widgets. The same query is read by a `QueryBuilder`, by a cubit through its `stream`, or by a script with `await client.query(...)`. Adding it doesn't replace the state management you already use: see [using it with bloc](../guides/bloc/).

## Next steps

- [Getting started](../getting-started/): install it and cache your first request.
- [Queries](../guides/queries/): keys, freshness, and the options.
- [Try the demo](/fuery/demo/): the example app in a browser, with the devtools.
