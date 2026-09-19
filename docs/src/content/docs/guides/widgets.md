---
title: Widgets
description: Builders, listeners, and consumers for queries, infinite queries, and mutations.
---

Each kind of query has a builder, a listener, a consumer, and a selector:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |

Mounting any of them subscribes to the query, which fetches if needed. Unmounting unsubscribes.

## How they update

- `buildWhen(previous, current)` compares with the last built result.
- `listenWhen(previous, current)` compares with the previous result.
- Listeners aren't called for the result the query already had when they mounted.

## Rebuild only what changed

`buildWhen` keeps a builder from rebuilding for changes it doesn't show. This one only shows a progress bar while refetching:

```dart
QueryBuilder(
  query: todos,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## Select part of the state

A selector builds from one value of the state and rebuilds only when that value changes:

```dart
QuerySelector(
  query: todos,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Lists, maps, and sets are compared by content, so a selector that builds a new list each time only rebuilds when the items change. Other values are compared with `==`.
- The selector runs again when the parent rebuilds, so it can use values from the parent.
- Use `buildWhen` when the builder needs the whole state, and a selector when it needs one value derived from it.

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

## React to changes

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

## Create queries once

Create queries in `State` fields, blocs, or other long-lived objects, not in `build`. A query created in `build` is a new observer on every rebuild, which resubscribes each time.

If a query reads `context`, for example to use a [provided client](../query-client/#providing-a-client), make it `late final` so it's created on first use:

```dart
late final todos = Query.use(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  client: context.queryClient,
);
```
