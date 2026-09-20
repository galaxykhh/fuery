---
title: Persistence
description: Keep cached server data across app restarts in Flutter, with any key-value storage.
---

Queries can store their data on the device. When the app starts again, it shows the last data right away and refetches it in the background if it's stale.

## Connecting storage

Fuery writes strings through a `QueryStorage`. Implement it against any key-value store. This one uses [`shared_preferences`](https://pub.dev/packages/shared_preferences):

```dart
class PreferencesStorage implements QueryStorage {
  PreferencesStorage(this.preferences);

  final SharedPreferencesWithCache preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<void> delete(String key) => preferences.remove(key);

  @override
  Map<String, String> readAll() => {
        for (final key in preferences.keys)
          if (key.startsWith(persistKeyPrefix)) key: preferences.getString(key)!,
      };
}
```

Fuery stores each query under its hash, behind the `persistKeyPrefix` constant, so `readAll` can hand back the stored queries and leave the rest of the store alone.

Give it to the client:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  Fuery.client = QueryClient(storage: PreferencesStorage(preferences));
  runApp(const App());
}
```

`SharedPreferencesWithCache` reads synchronously, so Fuery restores persisted queries before their first frame. Storage methods can also return futures, for example for a database. See [restoring ahead of time](#restoring-ahead-of-time).

## Persisting a query

Add `persist` with a way to convert the data to JSON and back. Only queries with `persist` are stored:

```dart
QueryObserver<List<Todo>> todosQuery() {
  return Query.use(
    queryKey: ['todos'],
    queryFn: (_) => api.getTodos(),
    persist: QueryPersist(
      toJson: (todos) => [for (final todo in todos) todo.toJson()],
      fromJson: (json) => [
        for (final item in json! as List) Todo.fromJson(item),
      ],
    ),
  );
}
```

- **The codec:** `toJson` must return a value `jsonEncode` accepts. `fromJson` receives whatever `jsonDecode` produced, so cast that value inside `fromJson` instead of at every call site. `Todo.fromJson` above takes that value; with a generated `Todo.fromJson(Map<String, dynamic> json)`, write `Todo.fromJson(item as Map<String, dynamic>)`.
- **Restoring:** the first time the query is used, its stored data is restored with the time it was fetched, so `staleTime` decides whether it refetches. Fresh data isn't fetched again.
- **Storing:** data is stored whenever it changes and no fetch is running, including changes made with `setQueryData`. A [streamed query](../streaming/) is stored once its stream is done.
- **Offline:** restoring doesn't need the network.

## Persisting infinite queries

Convert one page, and Fuery stores the list of pages:

```dart
final posts = InfiniteQuery.use(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  persist: InfiniteQueryPersist(
    pageToJson: (page) => page.toJson(),
    pageFromJson: (json) => PostPage.fromJson(json! as Map<String, Object?>),
  ),
);
```

Page params are stored as they are, so they must be JSON values like numbers, strings, or `null`. Otherwise, add `paramToJson` and `paramFromJson`.

## When stored data is discarded

Fuery discards stored data, and the query fetches as if nothing was stored, when:

- it is older than the query's `maxAge`, or, when the query doesn't set one, the client's `persistMaxAge` (default: one day),
- its `version` differs from the query's `version`. Increase `version` when the JSON format changes,
- it can't be decoded.

```dart
persist: QueryPersist(
  version: 2,
  maxAge: const Duration(hours: 6),
  toJson: (todos) => [for (final todo in todos) todo.toJson()],
  fromJson: (json) => [
    for (final item in json! as List) Todo.fromJson(item),
  ],
),
```

## Restoring ahead of time

With a storage that reads asynchronously, a query shows loading until its data has been read. To have the data on the first frame instead, read everything before the app starts:

```dart
await Fuery.client.restore();
runApp(const App());
```

## Deleting stored data

| | Stored data |
|---|---|
| `removeQueries`, `resetQueries` | Deleted for the matching queries. Filtering only by key also deletes stored queries that aren't loaded. |
| `clear()` | All deleted. Call it when the user logs out. |
| Garbage collection | Kept. Unused queries leave memory and are restored the next time they're used. |

A failing storage behaves like an empty one; Fuery ignores its errors. Fuery doesn't persist mutations.

## In the example app

The example has a storage adapter in [the preferences storage](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
