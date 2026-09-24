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

Pass `listener` to the hook for navigation, snackbars, and other one-off effects. It runs after a change, never during a build, and not for the result the widget mounts with:

```dart
final todos = useQuery(
  todosQuery,
  listenWhen: (previous, current) =>
      !previous.isRefetchError && current.isRefetchError,
  listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not refresh: ${result.error}')),
  ),
);
```

`listener` and `listenWhen` work as on a [`QueryListener`](../widgets/#reacting-to-changes). `listenWhen` compares the previous result received with the new one, and `context` is the widget's own. `useInfiniteQuery` and `useMutation` take them too.

A mutation's listener hears the runs started with the result its hook returns:

```dart
final addTodo = useMutation(
  addTodoMutation,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);

FilledButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate(title.text),
  child: const Text('Add'),
)
```

Run the mutation from that result, or pass the result to the child that runs it. Another `useMutation(addTodoMutation)` has an observer of its own, and this listener doesn't hear its runs. To hear every run, from any widget, pass the listener to [`useMutationState`](#showing-every-run-of-a-mutation) instead.

| Effect | Where it goes |
|---|---|
| Cache work, such as invalidating `['todos']` after any run | The callbacks of the `Mutation` |
| The screen's reaction to the runs of its own `useMutation`, such as closing the screen | `listener` of `useMutation` |
| A reaction to every run, from any widget, such as a snackbar for each failure | `listener` of `useMutationState` |
| An effect of one call that needs that call's variables | `MutateOptions` passed to `mutate` |

The widget still rebuilds when the result changes, with a listener or without. To react without rebuilding a widget, wrap its subtree in a `QueryListener` or `InfiniteQueryListener`, which `fuery_hooks` re-exports.

The listener isn't called for the result the widget mounts with. When that result already decides what to show, such as a signed-out user, decide it in `build` from the result the hook returns.

Don't show a snackbar or navigate from `useEffect` or `useValueChanged` keyed on the result: `flutter_hooks` runs them during the build, where those calls fail.

## Showing every run of a mutation

`useMutationState` returns the state of every run of a mutation, oldest first, wherever it started: a `useMutation` in another widget, a `MutationBuilder`, or a cubit's observer. It finds the runs by the definition's `mutationKey`, as [`MutationStateBuilder`](../mutations/#showing-every-run-of-a-mutation) does, and never runs the mutation:

```dart
final runs = useMutationState(addTodoMutation);

if (runs.any((run) => run.isPending)) return const LinearProgressIndicator();
```

Its `listener` gets the new state of each run that changed, as a `MutationStateListener` does, and `listenWhen` compares that run's previous state with its new one:

```dart
useMutationState(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

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

## The hook for each widget

| Widget | Hook |
|---|---|
| `QueryBuilder` | `useQuery(query)` |
| `QueryListener`, `QueryConsumer` | `useQuery(query, listener: ...)` |
| `InfiniteQueryBuilder` | `useInfiniteQuery(query)` |
| `InfiniteQueryListener`, `InfiniteQueryConsumer` | `useInfiniteQuery(query, listener: ...)` |
| `MutationBuilder` | `useMutation(mutation)` |
| `MutationListener`, `MutationConsumer` | `useMutation(mutation, listener: ...)` |
| `QueriesBuilder` | `useQueries(queries)` |
| `MutationStateBuilder`, `MutationStateSelector` | `useMutationState(mutation)` |
| `MutationStateListener` | `useMutationState(mutation, listener: ...)` |

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
