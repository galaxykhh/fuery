---
title: Widgets
description: Builder, listener, consumer, and selector widgets for cached queries and mutations in Flutter.
---

Every query, infinite query, and mutation has four widgets:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |

Mounting one subscribes it to its query or mutation. A query fetches if it needs to. Unmounting unsubscribes.

## When builders and listeners run

- `buildWhen(previous, current)` compares with the last built result.
- `listenWhen(previous, current)` compares with the previous result.
- Listeners aren't called for the result the query already had when they mounted.

## Rebuilding only what changed

`buildWhen` keeps a builder from rebuilding for changes it doesn't show. This one only shows a progress bar while refetching:

```dart
QueryBuilder(
  query: todos,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## Selecting part of the state

A selector builds from one value of the result and rebuilds only when that value changes:

```dart
QuerySelector(
  query: todos,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Fuery compares lists, maps, and sets by content, and everything else with `==`. A selector that builds a new list on every call therefore rebuilds the builder only when the items change.
- The selector runs again when the parent rebuilds, so it can use values from the parent.
- Use `buildWhen` when the builder needs the whole result, and a selector when it needs one value derived from it.

The same works for a mutation:

```dart
MutationSelector(
  mutation: saveTodo,
  selector: (state) => state.isPending,
  builder: (context, saving) => FilledButton(
    onPressed: saving ? null : save,
    child: const Text('Save'),
  ),
)
```

## Reacting to changes

Use a listener for navigation, snackbars, and other one-off effects:

```dart
QueryListener(
  query: todos,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoScreen(),
)
```

```dart
MutationListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, state) => Navigator.pop(context),
  child: const AddTodoForm(),
)
```

## Pull to refresh

`refetch()` returns a `Future<QueryResult>` that completes when the fetch settles, which is what `RefreshIndicator` waits for:

```dart
QueryBuilder(
  query: todos,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => RefreshIndicator(
        onRefresh: () => todos.refetch(),
        child: ListView(
          children: [for (final todo in data) TodoTile(todo)],
        ),
      ),
    QueryResult(:final error?) => Center(child: Text('$error')),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `refetch()` reports a failed fetch in the result instead of throwing, so the indicator always closes. Pass `throwOnError: true` to have it throw instead.
- When the query already has data, it cancels the fetch in flight and starts a new one. Pass `cancelRefetch: false` to wait for that fetch instead. A query with no data always waits for the fetch in flight.
- Wrap the data branch, not the whole builder. The gesture needs a scrollable, and the pending and error branches have none.

To refresh a whole screen, go through the client:

```dart
RefreshIndicator(
  onRefresh: () => context.queryClient.invalidateQueries(queryKey: ['todos']),
  child: const TodoList(),
)
```

`invalidateQueries` marks every query under `['todos']` stale and refetches the ones a widget is using. `refetchQueries` refetches without marking anything stale; its `type` defaults to `QueryTypeFilter.all`, so pass `QueryTypeFilter.active` to leave screens nobody is looking at alone. [Invalidating](../query-client/#invalidating) covers the filters both take.

Both return a `Future<void>` that completes when every matching fetch settles, and neither throws unless you pass `throwOnError: true`. A fetch that is paused because the device is offline isn't waited for, so the indicator doesn't hang.

## Retrying after an error

Give the error branch a button that calls `refetch()`:

```dart
QueryBuilder(
  query: todos,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => TodoList(data),
    QueryResult(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            FilledButton(
              onPressed: state.isFetching ? null : () => todos.refetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- Disable the button while `state.isFetching`, so taps can't stack on a fetch that is already running.
- Match the data branch first. A refetch that fails keeps the data it had, so the list stays on screen and `isRefetchError` is true. Report that failure with a `QueryListener` and a snackbar instead of replacing the screen.
- The query retries on its own before the error branch ever builds: three attempts by default, about seven seconds. [Which errors to retry](../queries/#which-errors-to-retry) narrows that.

## Showing that anything is fetching

A bar that follows every query in the app, not one query, reads the client instead of a widget. See [Watching the cache](../query-client/#watching-the-cache).

## Where to create queries

Create queries in `State` fields, blocs, or other long-lived objects, never in `build`. See [Create the query once](../queries/#create-the-query-once).

## Do queries need disposing?

No. An observer subscribes to its query when it gets its first listener and unsubscribes when the last one leaves. Unmounting the last widget that uses it cancels its stale and refetch timers and detaches it from the query. Mounting a widget with the same observer later subscribes it again, so a `State` field holding a query needs nothing in `dispose`. Mutation observers work the same way.

A cubit that listens to `stream` cancels that subscription in `close()`, which does the same thing. See [In a cubit](../bloc/#in-a-cubit).

The cached data isn't the observer's to release. It stays for `gcTime` (default: 5 minutes) after the last observer leaves, which is why returning to a screen shows it instantly.

`QueryObserver.destroy()` does by hand what the last unsubscribe does: it drops every listener, cancels the timers, and detaches the observer from its query. Nothing in the widget tree needs it. Reach for it when a long-lived object holds an observer whose listeners it can't reach and has to stop it now.

## In the example app

The example has a selector in [the case list](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/cases/cases_screen.dart), and pull to refresh with a retry button in [the todo list](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/todo_list/todo_list.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
