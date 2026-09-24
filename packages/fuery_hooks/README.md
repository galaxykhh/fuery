<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery_hooks.svg)](https://pub.dev/packages/fuery_hooks)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

Hooks for [Fuery](https://pub.dev/packages/fuery): render cached server data from inside `build`, in a [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) `HookWidget`.

Fuery is built the Flutter way. Queries are defined outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`. And `fuery` depends on nothing beyond Dart and Flutter.

`fuery_hooks` is for developers who prefer hooks, a style many know from web development. It is a package of its own because it depends on `flutter_hooks`, so only apps that choose hooks get that dependency. It renders the same queries with one call per query, and no builders:

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

The queries, mutations, and client are Fuery's own, so a screen written with hooks and a screen written with widgets share one cache and one request.

**[Read the hooks guide →](https://galaxykhh.github.io/fuery/guides/hooks/)** · **[Fuery documentation →](https://galaxykhh.github.io/fuery/)**

## Install

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` re-exports `fuery`, so `package:fuery_hooks/fuery_hooks.dart` and `package:flutter_hooks/flutter_hooks.dart` are the only imports you need.

## Hooks

| Hook | Returns |
|---|---|
| `useQuery(query)` | The latest `QueryResult`. `refetch()` is on the result. |
| `useInfiniteQuery(query)` | The latest `InfiniteQueryResult`. `fetchNextPage()` is on the result. |
| `useMutation(mutation)` | The latest `MutationResult`. `mutate(...)` is on the result. |
| `useQueries(queries)` | The results of a list of queries of one data type, in order. |
| `useMutationState(mutation)` | The state of every run of a mutation, oldest first, wherever it started, found by its `mutationKey`. |
| `useQueryClient()` | The client the hooks use, for `invalidateQueries` and `setData`. |

Each rebuilds the widget when its result changes, and needs no type arguments: `todos` above is a `QueryResult<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. `useQuery`, `useInfiniteQuery`, `useMutation`, and `useMutationState` also take `listener` and `listenWhen`, for side effects.

## Changing data

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

A `NoVariablesMutation` runs with `mutate(null)`, as from a `MutationBuilder`:

```dart
final logout = useMutation(logoutMutation);

TextButton(
  onPressed: () => logout.mutate(null),
  child: const Text('Log out'),
)
```

For a side effect of one call, pass `MutateOptions` to `mutate`. The request itself still finishes when the widget goes away. For a definition, the callbacks of its calls are dropped then. A shared observer is left alone and still runs them, so check `context.mounted` in them.

## Reacting to changes

Pass `listener` to the hook for navigation, snackbars, and other one-off effects. It runs after a change, never during a build, and not for the result the widget mounts with. `listenWhen` compares the previous result with the new one, as on `QueryListener`. The listener of `useMutationState` hears every run of the mutation, found by the definition's `mutationKey`, from any widget, one run at a time:

```dart
useMutationState(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

For a definition, the listener of `useMutation` hears only the runs started with the result its hook returns. For a shared observer, it hears every run. See [Reacting to changes](https://galaxykhh.github.io/fuery/guides/hooks/#reacting-to-changes) for which effect goes where.

## Rules

- **Pass a definition.** A `Query` or a `Mutation` can be a top-level value or be built in `build`: the hook keeps one observer for it and updates its options, so a new key shows in the same frame.
- **Don't call `.observe()` in `build`.** A new query observer every build subscribes and fetches again, and a new mutation observer starts idle. In debug builds the hook prints a warning once per key.
- **Run side effects in a listener.** For a snackbar or navigation, pass `listener:` to the hook. `useEffect` and `useValueChanged` run during the build, where those calls fail.
- **Watch the client with a memoized stream**: `useStream(useMemoized(() => client.watch(selector), [client]))`. A new stream every build rebuilds the widget on every frame.
- **The client** is the one a `FueryProvider` above provides, or `Fuery.client`, and `useQueryClient()` returns it. A shared observer keeps the client it was created with instead.

Everything else, from keys and freshness to persistence and devtools, is Fuery's. See the [documentation](https://galaxykhh.github.io/fuery/).
