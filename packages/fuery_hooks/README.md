<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery_hooks.svg)](https://pub.dev/packages/fuery_hooks)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

Hooks for [Fuery](https://pub.dev/packages/fuery): render cached server data from inside `build`, in a [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) `HookWidget`.

Fuery is built the Flutter way. Queries keep their data outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`. And `fuery` depends on nothing beyond Dart and Flutter.

`fuery_hooks` is for developers who prefer hooks. It is a package of its own because it depends on `flutter_hooks`, so only apps that choose hooks get that dependency. It renders the same queries with one call per query and no builders:

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

`fuery_hooks` re-exports `fuery`. `package:fuery_hooks/fuery_hooks.dart` and `package:flutter_hooks/flutter_hooks.dart` are the only imports you need.

## Hooks

| Hook | Returns |
|---|---|
| `useQuery(query)` | The latest `QueryResult`. `refetch()` is on the result. |
| `useInfiniteQuery(query)` | The latest `InfiniteQueryResult`. `fetchNextPage()` is on the result. |
| `useMutation(mutation)` | The latest `MutationResult` of the runs this widget starts. `mutate(...)` is on the result. |
| `useQueries(queries)` | The results of a list of queries of one data type, in order. |
| `useMutationState(mutation)` | The state of every run of a mutation, oldest first, wherever it started, found by its `mutationKey`. |
| `useQueryClient()` | The client the hooks use, for `invalidateQueries` and `setData`. |

Each hook rebuilds the widget when its result changes. None needs type arguments: `todos` above is a `QueryResult<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. These hooks only read; [change hooks](#reacting-to-changes) run side effects.

## Changing data

Run a mutation from its definition, as in any widget. `useMutationState` reads its runs:

```dart
final adding = useMutationState(addTodoMutation).any((run) => run.isPending);

ElevatedButton(
  onPressed: adding ? null : () => addTodoMutation.mutate('Buy milk'),
  child: const Text('Add'),
)
```

The run belongs to the client's cache, not to the widget. It uses `Fuery.client` unless you pass the client from `useQueryClient()`. A `NoVariablesMutation` runs with `logoutMutation.mutate()`.

`useMutation` is for a widget that shows only the runs it starts, as a `MutationBuilder` does. Its result runs the mutation with `mutate`, and a `NoVariablesMutation` with `mutate(null)`:

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

For a side effect of one call through the result, pass `MutateOptions` to `mutate`. When the widget goes away, the request still finishes. For a definition, the hook then drops the `MutateOptions` callbacks. A shared observer still runs them, so check `context.mounted` in them.

## Reacting to changes

For navigation, snackbars, and other one-off effects, pass what a hook returns to a change hook. Its listener runs after a change, never during a build. It doesn't run for the result the widget mounts with. `listenWhen` compares the previous result with the new one, as on `QueryListener`:

```dart
final addTodo = useMutation(addTodoMutation);
useOnMutationChange(
  addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);
```

| Hook | Calls its listener after |
|---|---|
| `useOnQueryChange(result, listener: ...)` | Each change of the result of `useQuery` or `useInfiniteQuery`. |
| `useOnMutationChange(result, listener: ...)` | Each change of the result of `useMutation`: the runs started with it, or every run of a shared observer. |
| `useOnMutationStateChange(mutation, listener: ...)` | Each change of each run of a mutation, found by its `mutationKey`, from any widget. |

See [Reacting to changes](https://galaxykhh.github.io/fuery/guides/hooks/#reacting-to-changes) for which effect goes where.

## Rules

- **Pass a definition.** A `Query` or `Mutation` can be top-level or built in `build`. The hook keeps one observer for it and updates its options, so a new key shows in the same frame.
- **Don't call `.observe()` in `build`.** A new query observer on every build subscribes and fetches again. A new mutation observer starts idle. In debug builds, the hook prints a warning once per key.
- **Run side effects in a change hook.** Show a snackbar or navigate from `useOnQueryChange`, `useOnMutationChange`, or `useOnMutationStateChange`. `useEffect` and `useValueChanged` run during the build, where those calls fail.
- **Memoize the stream of `client.watch`.** Write `useStream(useMemoized(() => client.watch(selector), [client]))`. A new stream on every build rebuilds the widget on every frame.
- **Get the client with `useQueryClient()`.** It returns the client of the nearest `FueryProvider` above, or `Fuery.client` without one. The hooks use that client. A shared observer keeps the client it was created with.

Everything else, from keys and freshness to persistence and devtools, is the same as with Fuery's widgets. See the [documentation](https://galaxykhh.github.io/fuery/).
