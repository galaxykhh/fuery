---
title: Mutations
description: Create, update, and delete server data in Flutter, with optimistic updates and rollback.
---

A mutation changes server data and reports what happened while it runs. This page covers running one, reacting to the result, and updating the cache before the server answers.

```dart
final addTodo = Mutation(
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

Give the parameter of `mutationFn` a type, like `String title` above. The rest of the types are inferred from it.

## Running a mutation

Pass the mutation to a `MutationBuilder`, and run it from the builder:

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => FilledButton(
    onPressed: state.isPending ? null : () => state.mutate('Buy milk'),
    child: Text(state.isPending ? 'Adding…' : 'Add'),
  ),
)
```

`state.mutate` puts errors in the state and passes them to the callbacks. `await state.mutateAsync('Buy milk')` returns the data, and throws on error. `state.reset()` returns the state to idle.

When the button and the state are in different places, or outside widgets, create one observer with `addTodo.observe()`, a `MutationObserver`, and call `mutate` on it. Keep it in a `State` field or a cubit, not in `build`, and pass it to the widgets that show its state.

## MutationState fields

Builders, listeners, and an observer's `result` all report a `MutationResult`, a `MutationState` with `mutate`, `mutateAsync`, and `reset`:

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
| `onMutate(variables, client)` | Before `mutationFn`. What it returns becomes `context`. |
| `onSuccess(data, variables, context, client)` | After success |
| `onError(error, variables, context, client)` | After failure |
| `onSettled(data, error, variables, context, client)` | After either |

`client` is the client running the mutation: the one a widget got from `FueryProvider`, or the one passed to `observe(client:)`. Use it instead of `Fuery.client`, so the callbacks reach the right cache in tests too.

Returning a future from a callback keeps the mutation pending until it completes. Returning the `invalidateQueries` future from `onSuccess`, as above, keeps a loading indicator up until the list has refetched.

To react to a single call, pass `MutateOptions`. These callbacks only run while something is still listening to the mutation, which a mounted `MutationBuilder` always is:

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

## Optimistic updates

Cancel refetches of the data first, then update the cache in `onMutate` and return what you need to roll back. If the request fails, `onError` receives it as `context`. `todosQuery` and `todosKey` are the query and its [key](../organizing-queries/):

```dart
final deleteTodo = Mutation(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id, client) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await client.cancelQueries(queryKey: todosKey);
    final previous = client.getData(todosQuery);
    client.updateData(
      todosQuery,
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, id, previous, client) {
    if (previous != null) client.setData(todosQuery, previous);
  },
  onSettled: (_, __, ___, ____, client) {
    return client.invalidateQueries(queryKey: todosKey);
  },
);
```

## Mutations without variables

`NoVariablesMutation` describes a mutation that takes nothing. Its observer is a `NoVariablesMutationObserver<TData, TContext>`, whose `mutate()` takes no argument, so a button can take its tear-off:

```dart
final logout = NoVariablesMutation(
  mutationFn: () => api.logout(),
  onSuccess: (data, context, client) => client.clear(),
).observe();

TextButton(onPressed: logout.mutate, child: const Text('Log out'))
```

Its callbacks drop the variables argument as well: `onMutate(client)`, `onSuccess(data, context, client)`, `onError(error, context, client)`, and `onSettled(data, error, context, client)`. From a `MutationBuilder`, where the state is typed like any mutation's, call `state.mutate(null)`.

Empty the cache once the app has left the screens that were using it. [Clearing everything at logout](../query-client/#clearing-everything-at-logout) explains why the order matters.

## Retries and ordering

A mutation never retries unless you set `retry`, because repeating a write is not always safe. `RetryPolicy.count(2)` gives it two more attempts, waiting 1s and then 2s. Mutations that share a `scope` run one after another, in the order they were started:

```dart
final saveDraft = Mutation(
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
