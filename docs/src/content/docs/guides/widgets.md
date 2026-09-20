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

## Where to create queries

Create queries in `State` fields, blocs, or other long-lived objects, never in `build`. See [Create the query once](../queries/#create-the-query-once).

## In the example app

The example has a selector in [the case list](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/cases/cases_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
