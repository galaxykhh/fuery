---
title: Persistence
description: Keep cached server data across app restarts in Flutter, with any key-value storage.
---

Queries can store their data on the device. When the app starts again, it shows the last data right away and refetches it in the background if it's stale. Mutations can store their variables while they run, so one that was waiting for the network when the app closed runs after the next start.

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
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  persist: QueryPersist(
    toJson: (todos) => [for (final todo in todos) todo.toJson()],
    fromJson: (json) => [
      for (final item in json! as List) Todo.fromJson(item),
    ],
  ),
);
```

- **The codec:** `toJson` must return a value `jsonEncode` accepts. `fromJson` receives whatever `jsonDecode` produced, so cast that value inside `fromJson` instead of at every call site. `Todo.fromJson` above takes that value; with a generated `Todo.fromJson(Map<String, dynamic> json)`, write `Todo.fromJson(item as Map<String, dynamic>)`.
- **Restoring:** the first time the query is used, its stored data is restored with the time it was fetched, so `staleTime` decides whether it refetches. Fresh data isn't fetched again.
- **Storing:** data is stored whenever it changes and no fetch is running, including changes made with `setData`. `client.setData(todosQuery, todos)` stores even before anything uses the query, because the query it creates gets the `persist` from the definition. A [streamed query](../streaming/) is stored once its stream is done.
- **Offline:** restoring doesn't need the network.

## Persisting infinite queries

Convert one page, and Fuery stores the list of pages:

```dart
final posts = InfiniteQuery(
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

Page params are stored as they are, so they must be JSON values like numbers, strings, or `null`. Otherwise, add `paramToJson` and `paramFromJson`. Params reach those as `Object?`, so cast them: `paramToJson: (date) => (date! as DateTime).toIso8601String()`.

## When stored data is discarded

Fuery discards stored data, and the query fetches as if nothing was stored, when:

- it is older than the query's `maxAge`, or, when the query doesn't set one, the client's `persistMaxAge` (default: one day),
- its `version` differs from the query's `version`. Increase `version` when the JSON format changes,
- it can't be decoded.

`restore()` also deletes stored queries that have expired, using the `maxAge` in effect when they were stored, so the data of a key the app no longer uses doesn't stay in the storage.

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

A failing storage behaves like an empty one; Fuery ignores its errors.

## Persisting mutations

A mutation with `persist` stores its variables from the moment it starts until it settles. A mutation that was paused offline, or still running, when the app was closed is therefore still there at the next start. `restore` runs it again with the mutation you pass, so the screen and `main` use the same definition:

```dart
Mutation<Comment, NewComment, void> addCommentMutation() {
  return Mutation(
    mutationKey: ['comments', 'add'],
    mutationFn: (NewComment comment) => api.addComment(comment),
    scope: const MutationScope('comments'),
    persist: MutationPersist(
      toJson: (comment) => {'postId': comment.postId, 'body': comment.body},
      fromJson: (json) {
        final map = json! as Map<String, Object?>;
        return (postId: map['postId']! as int, body: map['body']! as String);
      },
    ),
    onSuccess: (_, comment, __, client) {
      client.invalidateQueries(queryKey: ['comments', comment.postId]);
    },
  );
}

// In a screen:
MutationBuilder(mutation: addCommentMutation(), builder: ...)

// In main, before runApp:
await Fuery.client.restore(mutations: [addCommentMutation()]);
```

- A persisted mutation needs a `mutationKey`. That is how `restore` matches a stored run to its definition. `mutations` is a list of `AnyMutation`, which every `Mutation` is, so options with different types go in one list.
- `restore` is the only way stored mutations come back. Each stored run is started again with its stored variables: right away while online, or when the network is back. Runs that share a scope go one at a time, oldest first.
- A restored run skips `onMutate`, and its callbacks receive `null` as `context`. An optimistic update belongs to the run that made it; the restored run only repeats the request and its `onSuccess`.
- A stored run is deleted once the mutation succeeds or fails. `clear()` deletes them all.
- An entry whose mutation wasn't passed to `restore` is kept, so a later `restore` can run it. One stored by another `version` of its `MutationPersist`, or one that can't be read, is deleted.
- A mutation without variables persists with `MutationPersist.noVariables`: `NoVariablesMutation(mutationKey: ['sync'], mutationFn: () => api.sync(), persist: MutationPersist.noVariables)`.

A request that had reached the server before the app closed runs again after the restart. Persist mutations whose request is safe to repeat, or make the server treat a repeat as the same write.

## What Fuery guarantees

- Reads and writes wait for a deletion that is still running, so a query that was removed is never restored from data that was about to be deleted, and never writes over its own deletion.
- A restore that is still running when the query is reset or removed doesn't bring the old data back.
- A query decides whether to fetch on mount after an asynchronous restore finishes, so `refetchOnMount` and `staleTime` apply to restored data the same way they apply to cached data.
- Storage methods may be synchronous or asynchronous, and their errors never reach the query. A query with a broken storage loads as if nothing was stored.

## In the example app

The example has a storage adapter in [the preferences storage](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart), and persists the feed's pages in [the feed queries](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
