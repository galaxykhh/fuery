---
title: Mutations
description: Create, update, and delete server data in Flutter, with optimistic updates and rollback.
---

A mutation changes server data and reports what happened while it runs. This page covers running one, reacting to the result, and updating the cache before the server answers.

```dart
final addTodo = Mutation.use(
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

Use `mutate` from buttons and `mutateAsync` when you need the result. `addTodo.result` holds the latest `MutationState`: `status`, `data`, `error`, and `variables`. `addTodo.reset()` returns it to idle.

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

Cancel refetches of the data first, then update the cache in `onMutate` and return what you need to roll back. If the request fails, `onError` receives it as `context`:

```dart
final deleteTodo = Mutation.use(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await Fuery.client.cancelQueries(queryKey: ['todos']);
    final previous = Fuery.client.getQueryData<List<Todo>>(['todos']);
    Fuery.client.updateQueryData<List<Todo>>(
      ['todos'],
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, id, previous) {
    if (previous != null) Fuery.client.setQueryData(['todos'], previous);
  },
  onSettled: (_, __, ___, ____) {
    return Fuery.client.invalidateQueries(queryKey: ['todos']);
  },
);
```

## Mutations without variables

Use `Mutation.noParam` and call `mutate()`:

```dart
final logout = Mutation.noParam(mutationFn: () => api.logout());
logout.mutate();
```

## Retries and ordering

Mutations don't retry unless you set `retry`, because repeating a write is not always safe. Mutations that share a `scope` run one after another, in the order they were started:

```dart
final saveDraft = Mutation.use(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

## Showing mutation state

```dart
MutationBuilder(
  mutation: deleteTodo,
  builder: (context, state) =>
      state.isPending ? const LinearProgressIndicator() : const SizedBox(),
)
```

## In the example app

The example has an optimistic delete in [the todo mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/todo_mutations.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
