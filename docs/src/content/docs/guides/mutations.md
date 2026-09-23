---
title: Mutations
description: Create, update, and delete server data in Flutter, with optimistic updates and rollback.
---

A mutation changes server data and reports what happened while it runs. This page covers running one, reacting to the result, and updating the cache before the server answers.

```dart
final addTodo = Mutation.observe(
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context) {
    return Fuery.client.invalidateQueries(queryKey: ['todos']);
  },
);
```

Give the parameter of `mutationFn` a type, like `String title` above. The rest of the types are inferred from it.

## Running a mutation

```dart
addTodo.mutate('Buy milk'); // errors go to the state and callbacks
final todo = await addTodo.mutateAsync('Buy milk'); // throws on error
```

Use `mutate` from buttons and `mutateAsync` when you need the result. `addTodo.result` holds the latest `MutationState`. `addTodo.reset()` returns it to idle.

## MutationState fields

Builders, listeners, and `result` all report a `MutationState`:

| Field | Meaning |
|---|---|
| `status` | A `MutationStatus`: `idle`, `pending`, `success`, or `error` |
| `data` | What `mutationFn` returned, or `null` until it succeeds |
| `error` | Why the mutation failed. `null` in every other status. |
| `variables` | What the latest `mutate` call passed |
| `context` | What `onMutate` returned |
| `submittedAt` | When the latest `mutate` call started, in milliseconds since epoch. `0` before the first one. |
| `failureCount`, `failureReason` | How many attempts have failed and why. Both reset when a `mutate` call starts and when it succeeds. |

| Question | True when |
|---|---|
| `isIdle`, `isPending`, `isSuccess`, `isError` | `status` is that one |
| `isPaused` | Waiting for the network, or for another mutation in the same `scope` |

## Callbacks

| Callback | Runs |
|---|---|
| `onMutate(variables)` | Before `mutationFn`. What it returns becomes `context`. |
| `onSuccess(data, variables, context)` | After success |
| `onError(error, variables, context)` | After failure |
| `onSettled(data, error, variables, context)` | After either |

Returning a future from a callback keeps the mutation pending until it completes. Returning the `invalidateQueries` future from `onSuccess`, as above, keeps a loading indicator up until the list has refetched.

To react to a single call, pass `MutateOptions`. These callbacks only run while something is still listening to the mutation:

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, context) => showAddedSnackBar(todo)),
);
```

## Optimistic updates

Cancel refetches of the data first, then update the cache in `onMutate` and return what you need to roll back. If the request fails, `onError` receives it as `context`. `todosOptions` and `todosKey` are the query's [options and key](../organizing-queries/):

```dart
final deleteTodo = Mutation.observe(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await Fuery.client.cancelQueries(queryKey: todosKey);
    final previous = Fuery.client.getData(todosOptions());
    Fuery.client.updateData(
      todosOptions(),
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, id, previous) {
    if (previous != null) Fuery.client.setData(todosOptions(), previous);
  },
  onSettled: (_, __, ___, ____) {
    return Fuery.client.invalidateQueries(queryKey: todosKey);
  },
);
```

## Mutations without variables

`Mutation.noVariables` returns a `NoVariablesMutationObserver<TData, TContext>`, whose `mutate()` takes no argument:

```dart
final logout = Mutation.noVariables(mutationFn: () => api.logout());
logout.mutate();
```

Its callbacks drop the variables argument as well: `onMutate()`, `onSuccess(data, context)`, `onError(error, context)`, and `onSettled(data, error, context)`.

```dart
final logout = Mutation.noVariables(
  mutationFn: () => api.logout(),
  onSuccess: (data, context) => Fuery.client.clear(),
);
```

Empty the cache once the app has left the screens that were using it. [Clearing everything at logout](../query-client/#clearing-everything-at-logout) explains why the order matters.

The state is still a `MutationState`, so a `MutationBuilder` reads `isPending` and `error` the same way.

## Retries and ordering

A mutation never retries unless you set `retry`, because repeating a write is not always safe. `RetryPolicy.count(2)` gives it two more attempts, waiting 1s and then 2s. Mutations that share a `scope` run one after another, in the order they were started:

```dart
final saveDraft = Mutation.observe(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

A mutation that waits for its turn in the scope reports `isPaused`, and so does one waiting for the network. To keep a waiting mutation across a restart, give it a `persist`: see [persisting mutations](../persistence/#persisting-mutations).

## Showing mutation state

```dart
MutationBuilder(
  mutation: deleteTodo,
  builder: (context, state) =>
      state.isPending ? const LinearProgressIndicator() : const SizedBox(),
)
```

Switch on `status` when a widget draws every branch:

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => switch (state.status) {
    MutationStatus.idle => const Text('Nothing added yet'),
    MutationStatus.pending => const CircularProgressIndicator(),
    MutationStatus.success => const Text('Added'),
    MutationStatus.error => Text('Could not add: ${state.error}'),
  },
)
```

## Telling the user a mutation failed

A failed `mutate` puts the error in the state instead of throwing, so a screen shows it with a `MutationListener`:

```dart
MutationListener(
  mutation: deleteTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not delete: ${state.error}'))),
  child: const TodoListView(),
)
```

Use `MutateOptions(onError: ...)` instead when only one call site shows the failure, and `mutateAsync` inside a `try`/`catch` when the caller handles it.

## In the example app

The example has an optimistic like with a rollback and a comment that pauses while offline in [the feed mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart), and the snackbar above in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
