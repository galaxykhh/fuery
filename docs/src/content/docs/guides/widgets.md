---
title: Widgets
description: Builder, listener, consumer, and selector widgets for cached queries and mutations in Flutter.
---

Queries, infinite queries, and mutations each have four widgets, and a list of queries has two:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| Several queries | `QueriesBuilder` | | | `QueriesSelector` |

Each takes a definition: a `Query`, an `InfiniteQuery`, or a `Mutation`. The widget keeps one observer for it while it is mounted, so the definition can be built in `build`:

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

- Mounting subscribes, and a query fetches if it needs to. Unmounting unsubscribes.
- When the widget rebuilds with a definition for another key, the observer follows it, and the new key's cached data shows in that same frame.
- The observer uses the client of the nearest `FueryProvider`, or `Fuery.client` without one.
- The result carries the actions: `state.refetch()`, `state.fetchNextPage()` and `state.fetchPreviousPage()` for infinite queries, and `state.mutate(...)`, `state.mutateAsync(...)`, and `state.reset()` for mutations.

A widget can also take an observer you created with `observe()`, to share one handle between widgets. The widget then uses it as it is.

## When builders and listeners run

- `buildWhen(previous, current)` compares with the last built result.
- `listenWhen(previous, current)` compares with the previous result.
- Listeners aren't called for the result the query already had when they mounted.

## Rebuilding only what changed

`buildWhen` keeps a builder from rebuilding for changes it doesn't show. This one only shows a progress bar while refetching:

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## Selecting part of the state

A selector builds from one value of the result and rebuilds only when that value changes:

```dart
QuerySelector(
  query: todosQuery,
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
  builder: (context, saving) => Text(saving ? 'Saving…' : 'Saved'),
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

```dart
MutationListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, state) => Navigator.pop(context),
  child: const AddTodoForm(),
)
```

## Pull to refresh

`state.refetch()` returns a `Future<QueryResult>` that completes when the fetch settles, which is what `RefreshIndicator` waits for:

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

- Disable the button while `state.isFetching`, so taps can't stack on a fetch that is already running.
- Match the data branch first. A refetch that fails keeps the data it had, so the list stays on screen and `isRefetchError` is true. Report that failure with a `QueryListener` and a snackbar instead of replacing the screen.
- The query retries on its own before the error branch ever builds: three attempts by default, about seven seconds. [Which errors to retry](../queries/#which-errors-to-retry) narrows that.

## Showing several queries together

`QueriesBuilder` takes a list of queries of one data type, such as one per id, and builds from all their results at once:

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
- Build the list in `build`. Every query keeps its observer while its key stays in the list, even when the list is reordered, and a key that leaves the list lets its observer go.
- Results that change together rebuild once.

`QueriesSelector` builds from one value combined from the results, and rebuilds only when that value changes:

```dart
QueriesSelector(
  queries: [for (final id in ids) todoQuery(id)],
  selector: (results) =>
      results.where((result) => result.data?.done ?? false).length,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

For a list where each item stands on its own, give each item its own `QueryBuilder` instead, as in `ListView.builder`: an item then rebuilds only for its own query. Queries of different types nest one `QueryBuilder` inside another.

## Showing that anything is fetching

A bar that follows every query in the app, not one query, reads the client instead of a widget. See [Watching the cache](../query-client/#watching-the-cache).

## Where to create queries

Define queries anywhere, and pass them to widgets; see [Using a query](../queries/#using-a-query). Call `observe()` only outside `build`, in a `State` field, a bloc, or another long-lived object: each call is a new observer.

## Do queries need disposing?

No. A widget that gets a definition creates its observer when it mounts and drops it when it unmounts. An observer you created with `observe()` subscribes to its query when it gets its first listener and unsubscribes when the last one leaves. Unmounting the last widget that uses it cancels its stale and refetch timers and detaches it from the query. Mounting a widget with the same observer later subscribes it again, so a `State` field holding a query observer needs nothing in `dispose`.

A mutation observer you hold runs the `MutateOptions` callbacks of its latest call even after the widget is gone. Call `reset()` on it in `dispose`, or check `mounted` in callbacks that use the `State` or its `BuildContext`. A widget that got the mutation as a definition does this for you when it unmounts.

A cubit that listens to `stream` cancels that subscription in `close()`, which does the same thing. See [In a cubit](../bloc/#in-a-cubit).

The cached data isn't the observer's to release. It stays for `gcTime` (default: 5 minutes) after the last observer leaves, which is why returning to a screen shows it instantly.

`QueryObserver.destroy()` does by hand what the last unsubscribe does: it drops every listener, cancels the timers, and detaches the observer from its query. Nothing in the widget tree needs it. Reach for it when a long-lived object holds an observer whose listeners it can't reach and has to stop it now.

## Building your own widgets or hooks

The widgets above are built on the public API of `fuery_core`, so a widget of your own, a hook, or an integration with another state library can do the same. Keep one slot per rendered query: `QuerySlot`, `InfiniteQuerySlot`, or `MutationSlot`, all `ObserverSlot`s. With [`flutter_hooks`](https://pub.dev/packages/flutter_hooks), a query hook is:

```dart
QueryResult<TData> useQuery<TData extends Object>(QuerySource<TData> query) {
  final client = FueryProvider.of(useContext(), listen: true);
  final slot = useMemoized(() => QuerySlot(query, client));
  final changes = useState(0);
  useEffect(() {
    final unsubscribe = slot.subscribe((_) => changes.value++);
    return () {
      unsubscribe();
      slot.dispose();
    };
  }, [slot]);
  slot.update(query, client);
  return slot.result;
}
```

- `update(source, client)` takes a `QuerySource`: a definition, whose observer the slot owns and updates, or an observer, which it uses as it is. A new client gets a new observer.
- `result` is current as soon as `update` returns, so the frame that changed the key shows it.
- `subscribe` delivers every later change and stays subscribed when the slot's `observer` changes. `dispose` drops it, and the observer if the slot created it.

`InfiniteQuerySource` and `MutationSource` are the sources of the other two slots. `QueriesSlot` takes a list of `QuerySource`s and gives a list of results, for a hook like `useQueries`. `FueryProvider.of(context, listen: true)` rebuilds the caller when the provided client is replaced.

## In the example app

The example has `buildWhen` for a refetch indicator, pull to refresh with a retry button, and a `MutationListener` for a snackbar in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
