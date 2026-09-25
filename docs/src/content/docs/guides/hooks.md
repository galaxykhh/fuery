---
title: Hooks
description: Render queries and mutations from inside build with fuery_hooks and flutter_hooks.
---

`fuery_hooks` renders Fuery's queries and mutations from inside `build`, in a [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) `HookWidget`, with one call per query and no builders.

Fuery's own style is [the widgets](../widgets/), which follow Flutter's conventions: queries are defined outside `build`, builders turn them into UI, and listeners run side effects. Hooks are for developers who prefer the style many know from web development. The queries, mutations, and client stay the same, so a screen written with hooks and one written with widgets share one cache and one request.

`fuery` depends on nothing beyond Dart and Flutter. Hooks need `flutter_hooks`, so they live in a package of their own, and only apps that choose hooks depend on it.

## Installing

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` re-exports `fuery`. It needs the same Dart and Flutter versions as `fuery`.

## Reading a query

Make the screen a `HookWidget`, and call `useQuery` with a query:

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

class TodoListScreen extends HookWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = useQuery(todosQuery);
    return switch (todos) {
      QueryResult(:final data?) => TodoList(data),
      QueryResult(:final error?) => Text('$error'),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

`useQuery` returns the result of this moment and rebuilds the widget when it changes. The result is the same `QueryResult` a `QueryBuilder` gets, with `refetch()` on it. The first build already shows the pending state, and the fetch starts when the widget mounts.

The query can be a top-level value, as above, or be built in `build`, such as `useQuery(todoQuery(id))`. The hook keeps one observer for it and updates its options, so a new key shows in the same frame. Don't pass `todosQuery.observe()`: a new observer on every build subscribes and fetches again, and in debug builds the hook prints a warning once per key.

## One query that needs another

Hooks don't wait for data. A query that needs a value from another one turns itself off with `enabled` until the value exists:

```dart
Query<List<Post>> postsQuery(int? userId) => Query(
      queryKey: ['posts', userId],
      queryFn: (_) => api.getPosts(userId!),
      enabled: userId != null,
    );

final user = useQuery(userQuery);
final posts = useQuery(postsQuery(user.data?.id));
if (posts.isPending) return const CircularProgressIndicator();
```

| Build | `user` | `posts` |
|---|---|---|
| First | Fetching, no data | Key `['posts', null]`, turned off, fetches nothing |
| After the user arrives | Data with id `7` | Key `['posts', 7]`, starts fetching in this build |
| After the posts arrive | Data | Data |

A query that is turned off and has no data is pending, so `posts.isPending` covers both waits. `posts.isLoading` is true only while its request runs.

## Changing data

`useMutation` returns the mutation's result, with `mutate` on it:

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

A `NoVariablesMutation` runs with `mutate(null)`, as from a `MutationBuilder`. See [Mutations without variables](../mutations/#mutations-without-variables) for the callbacks of one call:

```dart
final logout = useMutation(logoutMutation);

TextButton(
  onPressed: () => logout.mutate(null),
  child: const Text('Log out'),
)
```

For a side effect of one call, such as a snackbar, pass `MutateOptions` to `mutate`:

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(
    onError: (error, _, __, ___) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error'))),
  ),
);
```

When the widget goes away, the request still finishes. For a definition, the callbacks passed to its `mutate` calls are dropped. A [shared observer](../mutations/#sharing-one-observer) is left alone and still runs them, so check `context.mounted` in them, or call the observer's `reset()` in the `dispose` of the screen that created it.

## Reacting to changes

The hooks above only read. For navigation, snackbars, and other one-off effects, pass what they return to a change hook:

| Hook | Calls its listener after |
|---|---|
| `useOnQueryChange(result, ...)` | Each change of the result of a `useQuery` or `useInfiniteQuery` |
| `useOnMutationChange(result, ...)` | Each change of the result of a `useMutation`: the runs started with it |
| `useOnMutationStateChange(mutation, ...)` | Each change of each run of a mutation, found by its `mutationKey`, from any widget |

```dart
final todos = useQuery(todosQuery);
useOnQueryChange(
  todos,
  listenWhen: (previous, current) =>
      !previous.isRefetchError && current.isRefetchError,
  listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not refresh: ${result.error}')),
  ),
);
```

The listener runs outside the build, never during one: right after the change, before the rebuild that shows it, with the widget's own `context`. It isn't called for the result the hook starts with. `listenWhen` compares the previous result received with the new one, as on a [`QueryListener`](../widgets/#reacting-to-changes), and the latest build's `listener` and `listenWhen` are used. Given the result of `useInfiniteQuery`, the closures get an `InfiniteQueryResult`, with its pages. Given a result built with the `QueryResult` constructor, such as made-up data in a widget test, the hook calls nothing.

The listener hears every change of the result, including a fetch starting and ending and data written with `setData`. To react to a transition, compare the two results in `listenWhen`, as above: `!previous.isRefetchError && current.isRefetchError` shows one snackbar per failed refresh, not one per rebuild of an error that is still there.

Each widget that calls a change hook gets its own calls, so two widgets reacting to the same query both run their listeners. An effect the whole app needs once, such as reporting every failed fetch, belongs in [`QueryCacheConfig.onError`](../query-client/#reporting-every-failure-in-one-place) instead.

A change hook adds no observer, and a change it hears never rebuilds the widget. The widget still rebuilds through the hook that reads. `useOnMutationStateChange` uses the provided client, so it rebuilds the widget when that client is replaced, to follow it. To react without rebuilding a widget, wrap its subtree in a `QueryListener` or `InfiniteQueryListener`, which `fuery_hooks` re-exports.

`useOnMutationChange` hears the runs started with the result it gets:

```dart
final addTodo = useMutation(addTodoMutation);
useOnMutationChange(
  addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);

FilledButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate(title.text),
  child: const Text('Add'),
)
```

Run the mutation from that result, or pass the result to the child that runs it. Another `useMutation(addTodoMutation)` has an observer of its own, and this listener doesn't hear its runs. A result shows its latest run, so when runs overlap, the listener hears the latest one; to react to each run, use `useOnMutationStateChange` or await `mutateAsync`. Given a [shared observer](../mutations/#sharing-one-observer), `useMutation` returns its result, and the listener hears every run of that observer.

`useOnMutationStateChange` hears every run of a mutation, wherever it started, as a `MutationStateListener` does. It needs no `useMutation`. The listener gets the new state of each run that changed, once per run, and `listenWhen` compares that run's previous state with its new one:

```dart
useOnMutationStateChange(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

| Effect | Where it goes |
|---|---|
| Cache work, such as invalidating `['todos']` after any run | The callbacks of the `Mutation` |
| The screen's reaction to the runs of its own `useMutation`, such as closing the screen | `useOnMutationChange` |
| A reaction to every run, from any widget, such as a snackbar for each failure | `useOnMutationStateChange` |
| An effect of one call that needs that call's variables | `MutateOptions` passed to `mutate` |
| An effect after one call, in the code that runs it | `await result.mutateAsync(...)`, then check `context.mounted` |

Awaiting the call keeps the effect next to the code that runs it:

```dart
onPressed: () async {
  await addTodo.mutateAsync(title.text); // throws if it fails
  if (!context.mounted) return;
  Navigator.pop(context);
},
```

When the result the widget mounts with already decides what to show, such as a signed-out user, decide it in `build` from the result the hook returns. No change hook is called for it.

### Showing a snackbar or navigating from `useEffect`

`flutter_hooks` runs a `useEffect` callback during the build: on the first build, then on every build whose keys changed, or on every build when it has no keys. A snackbar or a navigation fails there, because it changes the widget tree while the tree is building. In a debug build, `showSnackBar` reports `The showSnackBar() method cannot be called during build.`, and `Navigator.pop` reports `setState() or markNeedsBuild() called during build.` On the first build, or after its keys changed, an effect that calls `ScaffoldMessenger.of(context)` fails first, with `Cannot listen to inherited widgets inside HookState.initState.` The effect also runs for the value the widget mounts with. `useValueChanged` runs during the build too. The change hooks run outside the build, and only for later changes.

## Showing every run of a mutation

`useMutationState` returns the state of every run of a mutation, oldest first, wherever it started: a `useMutation` in another widget, a `MutationBuilder`, or a cubit's observer. It finds the runs by the definition's `mutationKey`, as [`MutationStateBuilder`](../mutations/#showing-every-run-of-a-mutation) does, and never runs the mutation:

```dart
final runs = useMutationState(addTodoMutation);

if (runs.any((run) => run.isPending)) return const LinearProgressIndicator();
```

To react to each run instead, use [`useOnMutationStateChange`](#reacting-to-changes).

## Loading more pages

`useInfiniteQuery` returns an `InfiniteQueryResult`, with the loaded pages and `fetchNextPage()`:

```dart
final feed = useInfiniteQuery(feedQuery);

ListView(
  children: [
    for (final post in feed.pages.expand((page) => page.posts)) PostTile(post),
    if (feed.hasNextPage)
      TextButton(onPressed: feed.fetchNextPage, child: const Text('More')),
  ],
)
```

## A list of queries

`useQueries` takes a list of queries of one data type and returns their results in order, such as one query per id:

```dart
final posts = useQueries([for (final id in ids) postQuery(id)]);
final loaded = posts.where((post) => post.hasData).length;
```

Each query keeps its observer while its key stays in the list, even when the list is reordered. Changes that arrive together rebuild once. Pass the definitions, not `.observe()`: new observers on every build fetch again, and in debug builds the hook prints a warning.

With hundreds of queries, build the list with `useMemoized`, keyed on the ids and on anything else from `build` that the definitions read, such as a value passed to `enabled:`. A rebuild with the same keys then passes the same list, and `useQueries` skips updating the queries, so a value missing from the keys keeps the one the list was built with:

```dart
final posts = useQueries(
  useMemoized(() => [for (final id in ids) postQuery(id)], ids),
);
```

## The hook for each widget

| Widget | Hook |
|---|---|
| `QueryBuilder` | `useQuery(query)` |
| `QueryListener` | `useOnQueryChange(result, listener: ...)` |
| `QueryConsumer` | `useQuery(query)` and `useOnQueryChange` |
| `InfiniteQueryBuilder` | `useInfiniteQuery(query)` |
| `InfiniteQueryListener` | `useOnQueryChange(result, listener: ...)` |
| `InfiniteQueryConsumer` | `useInfiniteQuery(query)` and `useOnQueryChange` |
| `MutationBuilder` | `useMutation(mutation)` |
| `MutationListener` | `useOnMutationChange(result, listener: ...)` |
| `MutationConsumer` | `useMutation(mutation)` and `useOnMutationChange` |
| `QueriesBuilder` | `useQueries(queries)` |
| `MutationStateBuilder`, `MutationStateSelector` | `useMutationState(mutation)` |
| `MutationStateListener` | `useOnMutationStateChange(mutation, listener: ...)` |

`result` is what the reading hook returns, such as `useQuery(query)`.

## The client

`useQueryClient()` returns the client the hooks use: the one a `FueryProvider` above provides, or `Fuery.client`. The widget rebuilds when the provided client is replaced.

```dart
final client = useQueryClient();

RefreshIndicator(
  onRefresh: () => client.invalidateQueries(queryKey: ['todos']),
  child: TodoList(todos.data ?? []),
)
```

A shared observer keeps the client it was created with, and `observe()` without `client:` uses `Fuery.client`. Under a `FueryProvider` with a client of its own, pass the definition, or create the observer with the client `useQueryClient()` returns. In debug builds, a hook that gets an observer of another client prints a warning. See [A screen reads another client's cache](../../troubleshooting/#a-screen-reads-another-clients-cache).

## Watching the client

`useStream` renders a value from `client.watch`, such as whether anything is fetching. Create the stream once, with `useMemoized`:

```dart
final client = useQueryClient();
final fetching = useStream(
  useMemoized(
    () => client.watch((client) => client.isFetching() > 0),
    [client],
  ),
);

if (fetching.data ?? false) return const LinearProgressIndicator();
```

Each `watch` call returns a new stream, and each listener gets the current value first. `useStream` subscribes to every new stream it gets, so a stream created on every build rebuilds the widget on every frame. List the client in the keys of `useMemoized`, and anything from `build` that the selector reads, so the stream follows them. See [Watching the cache](../query-client/#watching-the-cache).

A mutation needs no stream: [`useMutationState`](#showing-every-run-of-a-mutation) returns its runs, and `useMutationState(const MutationFilters())` returns the runs of every mutation.

## Testing

Test a hook screen like any widget. [Testing](../testing/) applies as it is: end each test by unmounting the tree and clearing the client.
