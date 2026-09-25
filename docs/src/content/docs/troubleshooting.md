---
title: Troubleshooting
description: Errors and surprises with Fuery in Flutter, what causes them, and how to fix them.
---

Fixes for the errors and surprising behavior you can hit with Fuery in Flutter, grouped by area. Each heading names what you see.

## Types and compile errors

### StateError: Query holds X, but was requested as Y

Reading or writing a key throws this error. A key holds one data type, and the code used another:

```dart
client.setQueryData(['todos'], []); // StateError: the list has no type
```

Dart infers `List<dynamic>` for the empty list, not the `List<Todo>` the query holds. Name the type:

```dart
client.setQueryData<List<Todo>>(['todos'], []);
```

`setData` takes the type from the query, so it can't cause this error: `client.setData(todosQuery, [])`. See [Organizing queries](../guides/organizing-queries/).

### The data type is Object

A query has the type `Query<Object>` instead of your model. Dart inferred the data type from a generic function, such as `keepPreviousData`, instead of from `queryFn`:

```dart
final posts = Query(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is Query<Object>
);
```

Write the closure instead:

```dart
placeholderData: (previous, client) => previous,
```

Where the type is already known, as in a function that returns `Query<List<Post>>`, `keepPreviousData` is fine.

### The name FocusManager is defined in two libraries

A file that imports Flutter and `package:fuery/fuery.dart` fails to compile with `ambiguous_import` where it names `FocusManager`, as in `FocusManager.instance.primaryFocus?.unfocus()`. Flutter has a `FocusManager` class. `package:fuery/fuery.dart` exports `FocusManager`, a deprecated alias of `FueryFocusManager`.

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

## Tests

### A Timer is still pending even after the widget tree was disposed

A cached query keeps a garbage collection timer, and `testWidgets` fails with this message when a timer outlives the test. End each widget test by unmounting the tree and emptying the cache:

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

Unsubscribe any observer you subscribed by hand before `clear()`. `clear()` moves an observer that is still subscribed to a new query, which starts loading again.

`addTearDown(Fuery.client.clear)` runs too late. After the test body, `testWidgets` unmounts the tree, which starts the timer. It then checks for pending timers before the tear-downs run. Put the two lines at the end of the test body.

### A test passes only when it runs first

A test passes on its own but fails after another test: its client stays empty. An observer keeps the client it was created with. An observer created at the top level of a file, as in `final todos = todosQuery.observe();`, keeps the client of the first test that used it. Later tests create fresh clients that never see it.

Keep the queries at the top level instead, and pass them to widgets, which use the current client. Call `observe()` where the observer is used, such as in a cubit, so each test gets an observer on its own client. See [Which client a query uses](../guides/client-setup/#which-client-a-query-uses).

### A test hangs on await subscription.cancel()

Inside `testWidgets` and `fakeAsync`, the future that `cancel()` returns never completes. Call it without `await`:

```dart
@override
Future<void> close() {
  _subscription.cancel(); // no await
  return super.close();
}
```

## Queries and refetching

### An error takes 7 seconds to appear

A failed fetch retries three times by default, waiting 1s, 2s, then 4s. An error that can never succeed, such as a 404, spends those 7 seconds retrying. Retry only the errors worth retrying:

```dart
retry: RetryPolicy.when(
  (failureCount, error) => failureCount < 3 && error is! NotFoundException,
),
```

See [Which errors to retry](../guides/queries/#which-errors-to-retry).

### A query succeeds though the request failed

A query fails when its query function throws. A repository that returns a result object, such as a `Result` or an `Either`, returns normally either way. Unwrap the result in the query function and throw the failure. See [Reporting failures from a repository](../guides/organizing-queries/#reporting-failures-from-a-repository).

### A form loses what the user typed

A background refetch returns and replaces what the user typed in a form seeded from a query. Seed the controllers once, and stop the query refetching while the form is open:

```dart
final todo = Query(
  queryKey: ['todos', 'detail', id],
  queryFn: (_) => api.getTodo(id),
  refetchOnMount: RefetchMode.never,
  refetchOnFocus: RefetchMode.never,
  refetchOnReconnect: RefetchMode.never,
);
```

After saving, invalidate the key, so every other screen shows the change.

### A query refetches too often

A stale query refetches when a widget starts using it, when the app returns to the foreground, and when the network reconnects. The default `staleTime` is zero, so data is stale as soon as it arrives. Give the query a `staleTime` that matches how fast the data changes:

```dart
final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);
```

See [Query lifecycle](../how-the-cache-works/#query-lifecycle).

### A query fetches on every rebuild

`observe()` in a `build` method creates a new observer on every rebuild, as in `QueryBuilder(query: todosQuery.observe())`, and each new observer subscribes and fetches. Pass the query itself instead. The widget keeps one observer for it:

```dart
QueryBuilder(query: todosQuery, builder: ...)
```

A list of queries has the same fix. Pass the definitions, not new observers:

```dart
QueriesBuilder(queries: [for (final id in ids) todoQuery(id)], builder: ...)
```

With [hooks](../guides/hooks/), write `useQuery(todosQuery)`, not `useQuery(todosQuery.observe())`, and `useQueries([for (final id in ids) todoQuery(id)])`.

A mutation observer created in `build`, as in `MutationBuilder(mutation: saveTodo.observe())`, starts idle on every rebuild. The button then loses the pending or error state of the mutation it started. When you need the observer, call `observe()` once, in a `State` field or a cubit, and pass that down. See [Sharing one observer](../guides/mutations/#sharing-one-observer).

In debug builds, a Fuery widget or hook, including the list forms, prints a warning with a link here when it gets a new observer for the same key and client on a rebuild. It warns once per key. A new observer for a replaced provider client is expected, so it prints nothing.

### fetchNextPage cancels a refetch

`state.fetchNextPage()` cancels a fetch that is already running, such as a background refetch of every page. It doesn't cancel when it is loading the next page already or when there is no next page. Check `isFetching` before calling it, or pass `cancelRefetch: false`:

```dart
state.fetchNextPage(cancelRefetch: false);
```

### Nothing refetches when the app resumes

Fuery widgets and hooks connect the app lifecycle. An app that uses queries only from blocs has neither. Call this once at startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

See [When the app resumes](../guides/lifecycle/#when-the-app-resumes).

### Nothing pauses while the device is offline

Fuery assumes the device is online until you report connectivity with `onlineManager.setEventListener`. See [When the network reconnects](../guides/lifecycle/#when-the-network-reconnects).

## Mutations

### An optimistic update is undone

A refetch that was already running finished after your change and overwrote it. Cancel running fetches in `onMutate`, before you change the cache:

```dart
onMutate: (id, client) async {
  await client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

### A mutation stays pending after its request

A callback that returns a future keeps the mutation pending until the future completes. `onSuccess: (_, __, ___, client) => client.invalidateQueries(...)` returns the invalidation, so the mutation stays pending until the refetch is done. That suits a save button whose spinner should wait for the list. When the screen shouldn't wait, use a block body, which returns nothing:

```dart
onSuccess: (post, _, __, client) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

See [Callbacks](../guides/mutations/#callbacks).

### A MutationListener never runs

A `MutationListener` never calls its listener, or a `MutationBuilder` or `MutationSelector` that only shows the state stays idle while a button's mutation runs. A mutation's state belongs to the observer that runs it. A widget given a definition, as in `MutationListener(mutation: addTodo)`, creates an observer of its own, and nothing runs that one.

To hear every run of the mutation, wherever it started, give the definition a `mutationKey` and use a `MutationStateListener`:

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

For the widgets that only show the state, use `MutationStateBuilder` or `MutationStateSelector`. See [Showing every run of a mutation](../guides/mutations/#showing-every-run-of-a-mutation).

For the callbacks of one call, such as closing the form that saved, pass `MutateOptions` to `mutate`.

To hear only the runs of one observer, create it once, in a `State` field. Pass it both to the widget that runs it and to the `MutationListener`:

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

[Sharing one observer](../guides/mutations/#sharing-one-observer) shows the whole screen, with the `reset()` it needs in `dispose`.

In a `HookWidget`, pass the result of the `useMutation` that runs the mutation to `useOnMutationChange`. To hear every run, call `useOnMutationStateChange(addTodo, ...)`. See [Reacting to changes](../guides/hooks/#reacting-to-changes).

A builder, consumer, or selector that runs the mutation itself, with `state.mutate`, can take the definition.

In debug builds, a `MutationListener` given a definition prints a warning with a link here, once.

### A MutationStateBuilder shows no runs

The MutationState widgets and `useMutationState` find runs by the definition's `mutationKey`, in the cache of the client they use. Check these causes:

- **The definition has no `mutationKey`.** Give it one, such as `mutationKey: const ['todos', 'add']`. In debug builds, the widget fails an assert that says so.
- **Another definition with other types uses the key.** Fuery leaves its runs out and reports them once to [`onUncaughtError`](../guides/client-setup/#catching-errors-that-callbacks-throw). Give each definition a key of its own.
- **The runs are on another client.** An observer created with `observe()` without `client:` runs on `Fuery.client`, not on the client of a `FueryProvider`. See [A screen reads another client's cache](#a-screen-reads-another-clients-cache).
- **The runs are gone.** A settled run that no observer holds leaves the cache after its `gcTime` (default: 5 minutes). `client.clear()` removes every run.

## Clients and error reporting

### A screen reads another client's cache

A mutation's callbacks invalidate queries, and the screen doesn't update. An observer keeps the client it was created with. `observe()` without `client:` uses `Fuery.client`. Under a `FueryProvider` with a client of its own, an observer in a `State` field, such as `final adding = addTodo.observe();`, reads and writes `Fuery.client`. The widgets around it that got definitions use the provider's client, so the callbacks invalidate the wrong cache.

Pass the definition instead, and the widget observes it with its own client. Where code needs a shared observer, create it with the client the widgets use:

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

In a `HookWidget`, `useQueryClient()` returns the client the hooks use. `observer.client` returns the client an observer uses.

In debug builds, a Fuery widget or hook that gets an observer of another client prints a warning with a link here. It warns once per widget or hook and key.

### A listener's error doesn't reach the zone

An error thrown in a listener doesn't reach `runZonedGuarded` or `PlatformDispatcher.onError`. When the client has `onUncaughtError`, Fuery reports the error there instead of to the zone.

This covers the `listener` of a listener widget, a consumer, or a hook, and a function passed to a slot's `listen` or `subscribeToRuns`. The rebuild still happens, and the other listeners still run.

Report the error from your `onUncaughtError`, like the other errors that callbacks throw:

```dart
Fuery.client = QueryClient(
  // reportError stands for your crash reporter.
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

See [Catching errors that callbacks throw](../guides/client-setup/#catching-errors-that-callbacks-throw).

## Persistence and devtools

### Persisted data doesn't come back

A persisted query loads from the network after a restart. Check these causes:

- **The client has no storage.** Set it before anything uses a query: `Fuery.client = QueryClient(storage: myStorage)`.
- **The query doesn't set `persist`.** Fuery stores only the queries that set it.
- **The stored entry is no longer valid.** Fuery discards an entry whose `version` differs from the query's, an entry it can't decode, and an entry older than the query's `maxAge`. A query without `maxAge` uses the client's `persistMaxAge` (default: 1 day). See [When stored data is discarded](../guides/persistence/#when-stored-data-is-discarded).

With a storage that reads asynchronously, the data arrives a frame or two later. To have it on the first frame, `await Fuery.client.restore()` before `runApp`. See [Restoring ahead of time](../guides/persistence/#restoring-ahead-of-time).

### The devtools button covers the app

`FueryDevtools` puts its button halfway down the right edge, over any content there. Move it with `buttonAlignment`:

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerLeft,
  child: child!,
)
```
