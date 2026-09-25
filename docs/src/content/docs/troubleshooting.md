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

`setData` takes the type from the query, so this can't happen: `client.setData(todosQuery, [])`. See [Organizing queries](../guides/organizing-queries/).

## The data type is Object instead of my model

Passing a generic function such as `keepPreviousData` to a `Query` whose type Dart infers makes it infer the data type from that function rather than from `queryFn`:

```dart
final posts = Query(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is Query<Object>
);
```

Write the closure instead. Where the type is already known, as in a function that returns `Query<List<Post>>`, `keepPreviousData` is fine:

```dart
placeholderData: (previous, client) => previous,
```

## The name FocusManager is defined in two libraries

`package:fuery/fuery.dart` exports `FocusManager`, the deprecated former name of Fuery's `FueryFocusManager`. Flutter has a `FocusManager` class too. A file that imports both and names `FocusManager`, as in `FocusManager.instance.primaryFocus?.unfocus()` to dismiss the keyboard, fails to compile with `ambiguous_import`.

Reach Flutter's focus manager without naming the class. Flutter's top-level `primaryFocus` is the focused node, so this dismisses the keyboard:

```dart
primaryFocus?.unfocus();
```

For anything else, `WidgetsBinding.instance.focusManager` is the same object as `FocusManager.instance`.

Or hide Fuery's name:

```dart
import 'package:fuery/fuery.dart' hide FocusManager;
```

`FocusManager` then means Flutter's class. `FueryFocusManager` and the `focusManager` singleton stay available. `package:fuery_hooks/fuery_hooks.dart` hides `FocusManager` already.

## A Timer is still pending even after the widget tree was disposed

A cached query keeps a garbage collection timer, and `testWidgets` fails if any timer outlives the test. End each widget test by unmounting the tree and emptying the cache:

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

Unsubscribe any observer you subscribed by hand before `clear()`. Clearing moves observers that are still subscribed to new queries, which start loading again.

`addTearDown(Fuery.client.clear)` is not enough: `testWidgets` checks for pending timers before the tear-downs run, and the tree it unmounts on its own at that point is what starts the timer. The two lines belong at the end of the test body.

## The test client stays empty, or a test only passes when it runs first

An observer keeps the client it was created with. An observer created at the top level of a file, as in `final todos = todosQuery.observe();`, therefore keeps the client from the first test that used it, while later tests create fresh clients that never see it.

Keep queries at the top level instead, and pass them to widgets, which use the current client. Call `observe()` where the observer is used, such as in a cubit, so each test gets one on its own client. See [Which client a query uses](../guides/query-client/#which-client-a-query-uses).

## A screen reads another client's cache

An observer keeps the client it was created with, and `observe()` without `client:` uses `Fuery.client`. Under a `FueryProvider` with a client of its own, an observer in a `State` field, such as `final adding = addTodo.observe();`, therefore reads and writes `Fuery.client`. The widgets around it that got definitions use the provider's client. A mutation's callbacks then invalidate the wrong cache, and the screen doesn't update.

Pass the definition instead, and the widget observes it with its own client. Where code needs a shared observer, create it with the client the widgets use:

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

A definition's `mutate` and `mutateAsync` also run on `Fuery.client` unless you pass a client, so under a provider, call `addTodo.mutate('Buy milk', context.queryClient)`.

In a `HookWidget`, `useQueryClient()` returns the client the hooks use. `observer.client` returns the client an observer uses. In debug builds, a Fuery widget or hook that gets an observer of another client than its own prints a warning to the console, once per widget or hook and key, with a link here.

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
onMutate: (id, client) async {
  await client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

## fetchNextPage cancels a refetch

`state.fetchNextPage()` cancels a fetch that is already running, such as a background refetch of every page, unless it is loading the next page already or there is no next page. Check `isFetching` before calling it, or pass `cancelRefetch: false`.

## The error screen takes several seconds to appear

A failed fetch retries three times by default, waiting 1s, 2s, then 4s. An error that can never succeed, such as a 404, spends that time retrying. Retry only what is worth retrying, with [`RetryPolicy.when`](../guides/queries/#which-errors-to-retry).

## The query succeeds even though the request failed

A query fails when its query function throws. A repository that returns a result object instead, such as a `Result` or an `Either`, returns normally either way, so the query is a success holding a failure. Unwrap it and throw: [Reporting failures from a repository](../guides/organizing-queries/#reporting-failures-from-a-repository).

## What the user typed is replaced while they type

A form seeded from a query is overwritten when a background refetch returns. Seed the controllers once, and stop the query refetching while the form is open:

```dart
final todo = Query(
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

`observe()` in a `build` method creates a new observer each time, as in `QueryBuilder(query: todosQuery.observe())`, and each one subscribes and fetches again. Pass the query itself instead. The widget keeps one observer for it:

```dart
QueryBuilder(query: todosQuery, builder: ...)
```

A list of queries and a hook have the same fix. Pass the definitions, not new observers:

```dart
QueriesBuilder(queries: [for (final id in ids) todoQuery(id)], builder: ...)
```

With [hooks](../guides/hooks/), write `useQuery(todosQuery)`, not `useQuery(todosQuery.observe())`, and `useQueries([for (final id in ids) todoQuery(id)])`.

A mutation observer created in `build`, as in `MutationBuilder(mutation: saveTodo.observe())`, swaps in an idle observer on every rebuild. The button then loses the pending or error state of the mutation it started.

When you need the observer, call `observe()` once in a `State` field or a cubit, and pass that down. See [Sharing one observer](../guides/mutations/#sharing-one-observer).

In debug builds, a Fuery widget or hook, including the list forms, that gets a new observer for the same key and client on a rebuild prints a warning to the console, once per key, with a link here. A new observer for a replaced provider client is expected, so it doesn't print one.

## A mutation stays pending after the request finished

A callback that returns a future keeps the mutation pending until the future completes. `onSuccess: (_, __, ___, client) => client.invalidateQueries(...)` returns the invalidation, so the mutation is pending until the refetch is done. That is right for a save button whose spinner should wait for the list. When the screen shouldn't wait, use a block body, which returns nothing:

```dart
onSuccess: (post, _, __, client) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

See [what the callbacks return](../guides/mutations/#callbacks).

## A MutationListener never runs

A mutation's state belongs to the observer that runs it. A `MutationListener` given a definition, as in `MutationListener(mutation: addTodo)`, creates an observer of its own, and nothing runs that one. A `MutationBuilder` or `MutationSelector` that only shows the state has the same problem: it stays idle while the button's mutation runs.

To hear every run of the mutation, wherever it started, give the definition a `mutationKey` and use a `MutationStateListener`. For the widgets that only show the state, use `MutationStateBuilder` or `MutationStateSelector`. See [Showing every run of a mutation](../guides/mutations/#showing-every-run-of-a-mutation).

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
);

MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not add: ${run.error}'))),
  child: const AddTodoForm(),
)
```

For the callbacks of one call, such as closing the form that saved, pass `MutateOptions` to `mutate`.

To hear only the runs of one observer, create it once, in a `State` field, and pass it both to the widget that runs it and to the `MutationListener`:

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

[Sharing one observer](../guides/mutations/#sharing-one-observer) shows the whole screen, with the `reset()` it needs in `dispose`.

A builder, consumer, or selector that runs the mutation itself, with `state.mutate`, can take the definition. In debug builds, a `MutationListener` given a definition prints a warning to the console, once, with a link here.

In a `HookWidget`, pass the result of the `useMutation` that runs the mutation to `useOnMutationChange`, or call `useOnMutationStateChange(addTodo, ...)` to hear every run. See [Reacting to changes](../guides/hooks/#reacting-to-changes).

## A MutationStateBuilder shows no runs

The MutationState widgets and `useMutationState` find runs by the definition's `mutationKey`, in the cache of the client they use.

- **The definition has no `mutationKey`.** In debug builds, the widget fails an assert that says so. Give it one, such as `mutationKey: const ['todos', 'add']`.
- **Another definition with other types uses the key.** Its runs are left out, and reported once to [`onUncaughtError`](../guides/query-client/#catching-errors-that-callbacks-throw). Give each definition a key of its own.
- **The runs are on another client.** An observer created with `observe()` without `client:`, or a run started with the definition's `mutate` or `mutateAsync` without a client, runs on `Fuery.client`, not on the client of a `FueryProvider`. See [A screen reads another client's cache](#a-screen-reads-another-clients-cache).
- **The runs are gone.** A settled run leaves the cache `gcTime` (default: 5 minutes) after it settles, and `client.clear()` removes every run.

## An error thrown in a listener doesn't reach the zone

An error thrown by a listener goes to the client's `onUncaughtError` when the client has one, and only without it to the current zone, where Flutter passes it to `PlatformDispatcher.onError`. That covers the `listener` of a listener widget, a consumer, or a hook, and a function passed to a slot's `listen` or `subscribeToRuns`. The rebuild still happens, and the other listeners still run.

Report it from `onUncaughtError`, as the other errors that callbacks throw. See [Catching errors that callbacks throw](../guides/query-client/#catching-errors-that-callbacks-throw).

## The devtools button covers part of the app

`FueryDevtools` puts its button halfway down the right edge, over any content there. Move it with `buttonAlignment`:

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerLeft,
  child: child!,
)
```

## Nothing refetches when the app resumes

Fuery widgets and hooks connect the app lifecycle for you. An app that uses queries only from blocs has neither, so call this once at startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## Nothing pauses while the device is offline

Fuery assumes the device is online until you report connectivity. See [Refetching automatically](../guides/lifecycle/#when-the-network-reconnects).
