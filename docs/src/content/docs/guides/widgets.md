---
title: Widgets
description: Show cached queries and mutations in Flutter with builder, listener, consumer, and selector widgets.
---

Fuery's widgets render queries and mutations in the widget tree, so a screen that shows server data stays a `StatelessWidget`. Pick a widget by its source and by what it does:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| Several queries | `QueriesBuilder` | | | `QueriesSelector` |
| Every run of a mutation | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

The query, infinite query, and mutation widgets take a definition: a `Query`, an `InfiniteQuery`, or a `Mutation`. Build it anywhere, `build` included. The widget keeps one [observer](../../how-the-cache-works/#observers) for it while it is mounted:

```dart
QueryBuilder(
  query: todoQuery(id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

- Mounting subscribes. The query fetches if it has no data, and by default also if its data is stale. A query with `enabled: false` doesn't fetch on mount. Unmounting unsubscribes.
- When the widget rebuilds with a definition for another key, the observer follows it. The new key's cached data shows in the same frame.
- The observer uses the client of the nearest `FueryProvider`, or `Fuery.client` without one.
- The result carries the actions: `state.refetch()`, `state.fetchNextPage()` and `state.fetchPreviousPage()` for infinite queries, and `state.mutate(...)`, `state.mutateAsync(...)`, and `state.reset()` for mutations.

A `MutationBuilder` shows only the runs it starts. The MutationState widgets show the runs of a mutation from anywhere, found by its `mutationKey`. See [Showing every run of a mutation](../mutations/#showing-every-run-of-a-mutation). A button that runs the mutation from its definition, with `addTodo.mutate('Buy milk', context.queryClient)`, needs no `MutationBuilder`. See [Running a mutation](../mutations/#running-a-mutation).

## When builders and listeners run

- `buildWhen(previous, current)` compares the last built result with the new one.
- `listenWhen(previous, current)` compares the previous result with the new one.
- A listener runs in a microtask after the change, never during a build.
- A listener isn't called for the result the query already has when the listener mounts.
- A consumer's listener runs before the rebuild that shows the change.
- A listener that throws doesn't stop the rebuild. Fuery reports its error to [`onUncaughtError`](../client-setup/#catching-errors-that-callbacks-throw).

## Rebuilding only what changed

`buildWhen` skips the rebuilds for changes a builder doesn't show. This builder shows only a progress bar while the query refetches:

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## Selecting part of the state

A selector builds from one value of the result, and rebuilds only when that value changes:

```dart
QuerySelector(
  query: todosQuery,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Fuery compares lists, maps, and sets by content, and everything else with `==`. A selector that returns a new list on every call rebuilds the builder only when the items change.
- The selector runs again when the parent rebuilds, so it can read values from the parent.
- Use `buildWhen` when the builder needs the whole result. Use a selector when it needs one value derived from it.

`MutationStateSelector` does the same for the runs of a mutation. This one counts the saves in flight, from any screen:

```dart
MutationStateSelector(
  mutation: saveTodo,
  selector: (runs) => runs.where((run) => run.isPending).length,
  builder: (context, saving) =>
      Text(saving > 0 ? 'Saving $saving…' : 'All changes saved'),
)
```

## Reacting to changes

Use a listener for navigation, snackbars, and other one-off effects:

```dart
QueryListener(
  query: todosQuery,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoScreen(),
)
```

For mutations:

- A `MutationStateListener` hears every run of a mutation, from any screen. See [Telling the user a mutation failed](../mutations/#telling-the-user-a-mutation-failed).
- To close a screen after its own call succeeds, await `mutateAsync`, then check `context.mounted`. See [Acting after one call succeeds](../mutations/#acting-after-one-call-succeeds).
- A `MutationListener` hears only the runs of the observer it gets. Given a definition, it hears nothing, and prints a warning in debug builds. See [A MutationListener never runs](../../troubleshooting/#a-mutationlistener-never-runs).
- A `MutationConsumer` given a definition hears the runs that its own builder starts.

## Pull to refresh

`state.refetch()` returns a `Future<QueryResult>` that completes when the fetch settles. `RefreshIndicator` waits for that future:

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => RefreshIndicator(
        onRefresh: () => state.refetch(),
        child: ListView(
          children: [for (final todo in data) TodoTile(todo)],
        ),
      ),
    QueryResult(:final error?) => Center(child: Text('$error')),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `refetch()` reports a failed fetch in the result instead of throwing, so the indicator always closes. Pass `throwOnError: true` to make it throw.
- If the query has data, `refetch()` cancels the fetch in flight and starts a new one. Pass `cancelRefetch: false` to wait for the fetch in flight instead. A query without data always waits for it.
- Wrap only the data branch. The gesture needs a scrollable, and the pending and error branches have none.

To refresh every query of a screen, call the client:

```dart
RefreshIndicator(
  onRefresh: () => context.queryClient.invalidateQueries(queryKey: ['todos']),
  child: const TodoList(),
)
```

- [`invalidateQueries`](../query-client/#invalidating) marks every query under `['todos']` stale, and refetches the ones with an observer, such as a mounted widget.
- `refetchQueries` refetches without marking anything stale. Its `type` defaults to `QueryTypeFilter.all`, which also refetches cache entries without an observer. Pass `type: QueryTypeFilter.active` to refetch only the ones with an observer.
- Both complete when every matching fetch settles, and throw only with `throwOnError: true`. Neither waits for a fetch paused while the device is offline, so the indicator doesn't hang.

[Query filters](../../reference/query-client/#query-filters) lists the filters both take.

## Retrying after an error

Give the error branch a button that calls `state.refetch()`:

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => TodoList(data),
    QueryResult(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            FilledButton(
              onPressed: state.isFetching ? null : () => state.refetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- Disable the button while `state.isFetching`, so taps don't stack on a fetch that is running.
- Match the data branch first. A failed refetch keeps the data, so the list stays on screen and `isRefetchError` is true. Report that failure with a `QueryListener` and a snackbar instead of replacing the screen.
- By default, the query retries three times before the error branch builds, waiting 1, 2, and 4 seconds. [Which errors to retry](../queries/#which-errors-to-retry) narrows that.

## Showing several queries together

`QueriesBuilder` builds from the results of a list of queries of one data type, such as one query per id:

```dart
QueriesBuilder(
  queries: [for (final id in cartIds) productQuery(id)],
  builder: (context, results) {
    if (results.any((result) => !result.hasData)) {
      return const CircularProgressIndicator();
    }
    final total = results.fold(0.0, (sum, result) => sum + result.data!.price);
    return Text('Total: $total');
  },
)
```

- The results come in the order of the queries.
- Build the list in `build`. Each query keeps its observer while its key stays in the list, even when the list is reordered.
- A key that leaves the list drops its observer.
- Results that change together cause one rebuild.
- Every rebuild of the widget that builds `QueriesBuilder` updates every query in the list, even when the ids stay the same. With hundreds of queries, keep state that changes often, such as a text field's, in another widget. The widget that builds `QueriesBuilder` then rebuilds only when the ids change.

`QueriesSelector` builds from one value combined from the results, and rebuilds only when that value changes:

```dart
QueriesSelector(
  queries: [for (final id in ids) todoQuery(id)],
  selector: (results) =>
      results.where((result) => result.data?.done ?? false).length,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

When each item of a list stands on its own, give each item its own `QueryBuilder`, as in `ListView.builder`. An item then rebuilds only for its own query. For queries of different data types, nest one `QueryBuilder` inside another.

## Showing that anything is fetching

A bar that follows every query in the app reads the client, not a widget. See [Watching the cache](../query-client/#watching-the-cache).

For mutations, a `MutationStateSelector` with `MutationFilters` shows whether any mutation is running:

```dart
MutationStateSelector(
  mutation: const MutationFilters(),
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, saving) => saving ? const Text('Saving…') : const SizedBox(),
)
```

## Passing an observer

Most screens pass the definition. Widgets given definitions with the same key already share the cache entry and the request. See [Using a query](../queries/#using-a-query).

The query, infinite query, and mutation widgets, `QueriesBuilder`, and `QueriesSelector` also take an observer from `observe()`. They use it as it is, with its options and the client it was created with. Pass one only when a cubit and a widget share one handle, or when several widgets show the runs of one mutation observer and nothing else.

Create the observer once, outside `build`, such as in a cubit or a `State` field. Each `observe()` call creates a new observer, which subscribes and fetches again. [Sharing one observer](../mutations/#sharing-one-observer) shows the `State` field, the client, and the `reset()` in `dispose`.

## Disposing observers

Query observers need no disposing. Only a mutation observer that you hold needs a step in `dispose`.

- A widget given a query definition creates its observer when it mounts, and destroys it when it unmounts.
- An observer from `observe()` subscribes to its query on its first listener. When the last listener leaves, such as the last widget that uses it, the observer cancels its stale and refetch timers and detaches from the query.
- A widget that mounts later with the same observer subscribes it again, so a `State` field that holds a query observer needs nothing in `dispose`.
- A cubit that listens to `stream` cancels its subscription in `close()`, which unsubscribes the same way. See [In a cubit](../bloc/#in-a-cubit).

A mutation observer you hold still runs the `MutateOptions` callbacks of its latest call after the widget is gone. Call `reset()` on it in `dispose`, or check `mounted` in callbacks that use the `State` or its `BuildContext`. A widget given the mutation as a definition resets its own observer when it unmounts.

The cache entry stays for `gcTime` (default: 5 minutes) after the last observer leaves, so a screen you return to shows its data at once.

`QueryObserver.destroy()` removes every listener at once. Like the last unsubscribe, it cancels the observer's timers and detaches it from its query. Nothing in the widget tree needs it. Call it when a long-lived object must stop an observer whose listeners it can't reach.

## Building your own widgets or adapters

For hooks, use [`fuery_hooks`](../hooks/). For a widget of your own or another state library, see [Building an adapter](../adapters/). It shows how to render queries with the public API of `fuery_core`, the same API these widgets use.

## In the example app

The example has `buildWhen` for a refetch indicator, pull to refresh with a retry button, and a `MutationStateListener` for a snackbar in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
