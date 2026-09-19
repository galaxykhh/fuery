---
title: Mutations
description: Create, update, and delete server data, with optimistic updates.
---

Mutations change server data:

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

To react to a single call, pass `MutateOptions`. These callbacks only run while a widget or listener is still subscribed to the mutation:

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, context) => showAddedSnackBar(todo)),
);
```

## Optimistic updates

Update the cache in `onMutate` and return what you need to roll back. If the request fails, `onError` receives it as `context`:

```dart
final deleteTodo = Mutation.use(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id) {
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

## Without variables

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
