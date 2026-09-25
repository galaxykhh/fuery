---
title: Persistence
description: Keep cached server data across app restarts in Flutter, with any key-value storage.
---

Store query data and pending mutations on the device, and they survive an app restart:

- A persisted query shows its last data right away, then refetches it in the background if it's stale.
- A persisted mutation that was waiting for the network when the app closed runs again once the app calls `restore(mutations:)` at the next start.

## Connecting storage

Fuery reads and writes strings through a `QueryStorage`. Implement it against any key-value store. This one uses [`shared_preferences`](https://pub.dev/packages/shared_preferences):

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

Every key Fuery writes starts with the `persistKeyPrefix` constant. Filter `readAll` by it, as above, so it returns Fuery's entries and nothing else from the store.

Give the storage to the client:

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

`SharedPreferencesWithCache` reads synchronously, so Fuery restores a persisted query before its first frame. Storage methods may also return futures, for example for a database. See [Restoring ahead of time](#restoring-ahead-of-time).

## Persisting a query

Add `persist` with functions that convert the data to JSON and back. Fuery stores only the queries that have `persist`:

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

- **Converting:** from `toJson`, return a value that `jsonEncode` accepts. If it can't be encoded, Fuery doesn't store the data and reports no error. `fromJson` receives what `jsonDecode` produced, so cast it there, once. `Todo.fromJson` above takes an `Object?`. With a generated `Todo.fromJson(Map<String, dynamic> json)`, write `Todo.fromJson(item as Map<String, dynamic>)`.
- **Restoring:** the first time the query is used, Fuery restores its stored data with the time it was fetched. `staleTime` then decides whether the query refetches, so fresh data isn't fetched again. Restoring doesn't need the network.
- **Storing:** Fuery stores the data whenever it changes and no fetch is running, including changes made with `setData`. `client.setData(todosQuery, todos)` stores even before anything uses the query, because the query it creates gets the definition's `persist`. Fuery stores a [streamed query](../streaming/) once its stream is done.
- **Keys with enums:** Fuery stores an enum in a key by its name, without its type. Obfuscated and minified builds can rename types in an app update, and the name alone still matches. Two persisted queries whose keys differ only in the type of a same-named enum therefore share one stored entry: `['todos', Filter.done]` and `['todos', Status.done]` overwrite each other's data. Add a string that tells them apart: `['todos', 'filter', Filter.done]`.

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

Fuery stores every loaded page in one entry, and writes it again after each page loads. Set `maxPages` to keep a long feed from growing into a large entry.

Fuery stores page params as they are, so they must be JSON values, such as numbers, strings, or `null`. For other params, add `paramToJson` and `paramFromJson`. `paramToJson` receives each param as `Object?`, so cast it: `paramToJson: (date) => (date! as DateTime).toIso8601String()`.

## When stored data is discarded

Fuery discards stored data, and the query fetches as if nothing was stored, when the data:

- is older than the query's `maxAge`, or than the client's `persistMaxAge` (default: 1 day) when the query sets no `maxAge`.
- has a `version` other than the query's. Increase `version` when the JSON format changes.
- can't be decoded.

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

`restore()` also deletes the stored queries that have expired, by the `maxAge` in effect when Fuery stored them. The data of a key the app no longer uses doesn't stay in the storage.

## Restoring ahead of time

With a storage that reads asynchronously, a query shows its loading state until Fuery has read its data. To show the data on the first frame, read every stored entry before the app starts:

```dart
await Fuery.client.restore();
runApp(const App());
```

## Deleting stored data

| Call | Stored data |
|---|---|
| `removeQueries`, `resetQueries` | Deleted for the matching queries. A call that filters only by key also deletes the stored queries that aren't loaded. |
| `clear()` | All deleted, queries and mutations. Call it when the user logs out. |
| Garbage collection | Kept. A query that leaves memory is restored the next time it's used. |

## Persisting mutations

A mutation with `persist` stores the variables of each run from the moment it starts until it settles. A run that was paused offline, or still running, when the app closed is still stored at the next start. `restore(mutations:)` runs it again with the definition you pass, so the screen and `main` use the same definition:

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
addCommentMutation().mutate((postId: post.id, body: 'Nice post'));

// In main, before runApp:
await Fuery.client.restore(mutations: [addCommentMutation()]);
```

[MutationPersist](../../reference/mutation-options/#mutationpersist) lists its parameters. A `NoVariablesMutation` persists with `MutationPersist.noVariables`: `NoVariablesMutation(mutationKey: ['sync'], mutationFn: () => api.sync(), persist: MutationPersist.noVariables)`.

A request that reached the server before the app closed runs again after the restart. Persist only the mutations whose request is safe to repeat, or make the server treat a repeat as the same write.

### Matching stored runs

- `restore` matches a stored run to its definition by `mutationKey`, so a persisted mutation needs one.
- `mutations` is a list of `AnyMutation`. Every `Mutation` is one, so definitions with different types go in one list.
- Fuery stores the `mutationKey` the way it stores query keys, so the key can hold enums and `DateTime`s.
- A key that can't be stored, such as one holding an object without `toJson()`, is reported once to `onUncaughtError`. The run goes on without being stored.
- `restore` reports two definitions whose keys differ only in enum types, and restores neither.

### Restoring stored runs

- `restore` is the only way stored runs come back. It starts each one with its stored variables: right away while online, or when the network is back.
- Runs that share a scope run one at a time, oldest first.
- `restore` starts each stored run once. It skips a run the client is already running or has paused, so calling it twice doesn't repeat a request.
- A restored run skips `onMutate`, and its callbacks receive `null` as `context`. The optimistic update belongs to the run that made it. The restored run repeats only the request and the callbacks after it.
- The [MutationState widgets](../mutations/#showing-every-run-of-a-mutation) and `useMutationState` show restored runs, found by the same `mutationKey`. `MutationStateBuilder(mutation: addCommentMutation(), ...)` lists the comments still on their way after a restart.

### Deleting stored runs

- Fuery deletes a stored run once it succeeds or fails. `clear()` deletes them all.
- A stored run whose definition wasn't passed to `restore` stays, so a later `restore` can run it.
- Fuery deletes a stored run that another `version` of its `MutationPersist` stored, or that it can't read.

## What Fuery guarantees

- Fuery waits for a deletion in progress before it reads or writes, so a removed query never restores deleted data or writes over its own deletion.
- A restore still running when the query is reset or removed doesn't bring the old data back.
- When a deletion overlaps a `restore()` read, `restore()` reads again once the deletion is done, for at most 3 reads in all, so it never restores deleted data. If a deletion overlaps all 3 reads, that call restores nothing: queries restore when they're first used, and stored mutations wait for the next `restore()`.
- A query decides whether to fetch on mount after an asynchronous restore finishes, so `refetchOnMount` and `staleTime` treat restored data like cached data.
- Storage methods may be synchronous or asynchronous. Fuery ignores their errors: a query with a failing storage loads as if nothing was stored.

## In the example app

- [The preferences storage](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart) is a storage adapter.
- [The feed queries](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart) persist the feed's pages.

The example's [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
