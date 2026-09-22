---
title: Troubleshooting
description: Errors and surprises you can hit with Fuery in Flutter, what causes them, and how to fix them.
---

Each entry names the symptom, the cause, and the fix.

## StateError: Query holds X, but was requested as Y

A key holds one data type. Reading or writing it with another type throws:

```dart
client.setQueryData(['todos'], []); // StateError: the list has no type
```

Dart infers `List<dynamic>` for the empty list, which isn't the `List<Todo>` the query holds. Name the type:

```dart
client.setQueryData<List<Todo>>(['todos'], []);
```

## The data type is Object instead of my model

Passing a generic function such as `keepPreviousData` to `Query.use` makes Dart infer the data type from that function rather than from `queryFn`:

```dart
final posts = Query.use(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is QueryObserver<Object>
);
```

Write the closure instead. Inside `QueryOptions`, where the type is already known, `keepPreviousData` is fine:

```dart
placeholderData: (previous) => previous,
```

## A Timer is still pending even after the widget tree was disposed

A cached query keeps a garbage collection timer, and `testWidgets` fails if any timer outlives the test. End each widget test by unmounting the tree and emptying the cache:

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

Unsubscribe any observer you subscribed by hand before `clear()`. Clearing moves observers that are still subscribed to new queries, which start loading again.

`addTearDown(Fuery.client.clear)` is not enough: `testWidgets` checks for pending timers before the tear-downs run, and the tree it unmounts on its own at that point is what starts the timer. The two lines belong at the end of the test body.

## The test client stays empty, or a test only passes when it runs first

A query captures its client when you create it. A query declared at the top level of a file therefore keeps the client from the first test that used it, while later tests create fresh clients that never see it.

Declare shared queries as functions instead, so each caller gets a query on the current client:

```dart
QueryObserver<List<Todo>> todosQuery() =>
    Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());
```

See [Which client a query uses](../guides/query-client/#which-client-a-query-uses).

## A test hangs on await subscription.cancel()

Inside `testWidgets` and `fakeAsync`, the future returned by `cancel()` never completes. Call it without awaiting:

```dart
@override
Future<void> close() {
  _subscription.cancel(); // no await
  return super.close();
}
```

## Persisted data doesn't come back

Three things to check:

- The client has a storage: `Fuery.client = QueryClient(storage: myStorage)`, set before anything uses a query.
- The query sets `persist`. Queries without it are never stored.
- The stored entry is still valid. Data is discarded when its `version` differs from the query's, or when it is older than the query's `maxAge` or the client's `persistMaxAge` (one day by default).

With a storage that reads asynchronously, data arrives a frame or two later. To have it on the first frame, `await Fuery.client.restore()` before `runApp`.

## An optimistic update is undone a moment later

A refetch that was already running finishes after your change and overwrites it. Cancel it first:

```dart
onMutate: (id) async {
  await Fuery.client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

## fetchNextPage cancels a refetch

`fetchNextPage()` cancels a fetch that is already running, including a background refetch of every page. Check `isFetching` before calling it, or pass `cancelRefetch: false`.

## The error screen takes several seconds to appear

A failed fetch retries three times by default, waiting 1s, 2s, then 4s. An error that can never succeed, such as a 404, spends that time retrying. Retry only what is worth retrying, with [`RetryPolicy.when`](../guides/queries/#which-errors-to-retry).

## The query succeeds even though the request failed

A query fails when its query function throws. A repository that returns a result object instead, such as a `Result` or an `Either`, returns normally either way, so the query is a success holding a failure. Unwrap it and throw: [Reporting failures from a repository](../guides/organizing-queries/#reporting-failures-from-a-repository).

## What the user typed is replaced while they type

A form seeded from a query is overwritten when a background refetch returns. Seed the controllers once, and stop the query refetching while the form is open:

```dart
final todo = Query.use(
  queryKey: ['todos', 'detail', id],
  queryFn: (_) => api.getTodo(id),
  refetchOnMount: RefetchMode.never,
  refetchOnFocus: RefetchMode.never,
);
```

Invalidate the key after saving, so every other screen picks the change up.

## A query refetches more often than expected

Every widget that starts using a query refetches it when the data is stale, and the default `staleTime` is zero, so almost everything is stale. Give the query a `staleTime` that matches how fast the data changes.

## A query fetches on every rebuild

`Query.use` in a `build` method creates a new query object each time. Create it once in a `State` field, a cubit, or a function that widgets call:

```dart
class _TodosScreenState extends State<TodosScreen> {
  final todos = Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());
}
```

The same happens when the object is created inline, as in `QueryBuilder(query: Query.use(...))`, or by a factory such as `todosQuery()` called from `build`. Call the factory once, store the result, and pass that down.

In debug builds, a Fuery widget that gets a new observer for the same key on a rebuild prints a warning to the console, once per key, with a link here.

## A mutation stays pending after the request finished

A callback that returns a future keeps the mutation pending until the future completes. `onSuccess: (_, __, ___) => client.invalidateQueries(...)` returns the invalidation, so the mutation is pending until the refetch is done. That is right for a save button whose spinner should wait for the list. When the screen shouldn't wait, use a block body, which returns nothing:

```dart
onSuccess: (post, _, __) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

See [what the callbacks return](../guides/mutations/#callbacks).

## The devtools button covers part of the app

`FueryDevtools` puts its button in the bottom right corner, over a navigation bar or a floating action button that lives there. Move it with `buttonAlignment`:

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerRight,
  child: child!,
)
```

## Nothing refetches when the app resumes

Fuery widgets connect the app lifecycle for you. An app that only uses queries from blocs has no Fuery widget, so call this once at startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## Nothing pauses while the device is offline

Fuery assumes the device is online until you report connectivity. See [Refetching automatically](../guides/lifecycle/#when-the-network-reconnects).
