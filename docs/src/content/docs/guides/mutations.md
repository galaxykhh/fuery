---
title: Mutations
description: Create, update, and delete server data in Flutter, with optimistic updates and rollback.
---

A mutation sends a change to the server, such as a new todo. Run it from a button, show its progress on any screen, tell the user when it fails, and update the cache before the server answers.

This one adds a todo:

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

Type the parameter of `mutationFn`, like `String title` above, and Dart infers the other types from it. The `mutationKey` lets any widget find the mutation's runs. A run is one `mutate` call ([Mutation runs](../../how-the-cache-works/#mutation-runs)). [Mutation options](../../reference/mutation-options/) lists every option.

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

- `state.mutate('Buy milk')` starts a run. An error goes to the state and the callbacks, not to the caller.
- `await state.mutateAsync('Buy milk')` returns the data, and throws on error.
- `state.reset()` returns the state to idle.

[Mutation results](../../reference/mutation-results/#mutationresult) lists every member and field of `state`.

The builder shows only the runs it starts. To show the mutation anywhere else, such as a progress bar on another screen, use the [MutationState widgets](#showing-every-run-of-a-mutation). To run it from a cubit, or from several widgets that must see only one screen's runs, see [Sharing one observer](#sharing-one-observer).

## Callbacks

`onMutate` runs before `mutationFn`. `onSuccess`, `onError`, and `onSettled` run after it. [Callbacks](../../reference/mutation-options/#callbacks) lists their arguments and order.

- The last argument, `client`, is the client running the mutation: the one a widget got from `FueryProvider`, or the one passed to `observe(client:)`. Use it instead of `Fuery.client`, so the callbacks reach the right cache in tests too.
- When `onMutate`, `onSuccess`, `onError`, or `onSettled` returns a future, the run stays pending until the future completes. Fuery doesn't await the `MutateOptions` callbacks below. `addTodo` above returns the `invalidateQueries` future from `onSuccess`, so the button shows *Adding…* until the list has refetched.

To react to one call only, pass `MutateOptions`. Its callbacks run after the mutation's own, once the call settles:

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

- A later `mutate` call on the same observer replaces them. Only the latest call's callbacks run.
- `reset()` drops them. Unmounting the widget that got the mutation drops them too.
- A [shared observer](#sharing-one-observer) runs them whether or not a widget listens to it. Check `context.mounted` before you use a `BuildContext` in them.

## Optimistic updates

An optimistic update changes the cache before the server answers, so the screen responds at once:

1. In `onMutate`, cancel refetches of the query, so none overwrites the update.
2. Still in `onMutate`, write the new data and return the old data. The other callbacks receive it as `context`.
3. In `onError`, write the old data back.
4. In `onSettled`, invalidate the query to refetch what the server has.

`todosQuery` and `todosKey` are the query and its [key](../organizing-queries/):

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

Use `NoVariablesMutation` for a mutation that takes nothing, such as logging out. Its `mutationFn` and callbacks leave out the variables ([NoVariablesMutation](../../reference/mutation-options/#novariablesmutation)):

```dart
final logoutMutation = NoVariablesMutation(
  mutationFn: () => api.logout(),
);
```

Its result has `void` variables, so a `MutationBuilder` runs it with `state.mutate(null)`. The callbacks of one call keep the variables argument, which is `null`:

```dart
MutationBuilder(
  mutation: logoutMutation,
  builder: (context, state) => TextButton(
    onPressed: state.isPending
        ? null
        : () => state.mutate(
              null,
              MutateOptions(
                onSuccess: (data, _, __, client) {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
            ),
    child: const Text('Log out'),
  ),
)
```

A `HookWidget` calls `mutate(null)` on the result of `useMutation(logoutMutation)` too. Outside widgets, its observer, a `NoVariablesMutationObserver`, runs it with `mutate()`; see [Sharing one observer](#sharing-one-observer).

After logging out, empty the cache once the app has left the screens that used it. [Clearing everything at logout](../query-client/#clearing-everything-at-logout) explains why the order matters.

## Retries and ordering

A mutation retries only when you set `retry`, because repeating a write is not always safe. `RetryPolicy.count(2)` allows two more attempts, 1 second and then 2 seconds apart. Mutations that share a `scope` run one at a time, in the order they started:

```dart
final saveDraft = Mutation(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

A run that waits for its turn in the scope reports `isPaused`, and so does a run that waits for the network. To keep a waiting run across a restart, give the mutation a `persist` ([Persisting mutations](../persistence/#persisting-mutations)).

## Showing mutation state

The builder that runs a mutation shows the state of its latest run. Switch on `status` to draw every branch:

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => switch (state.status) {
    MutationStatus.idle => FilledButton(
        onPressed: () => state.mutate('Buy milk'),
        child: const Text('Add'),
      ),
    MutationStatus.pending => const CircularProgressIndicator(),
    MutationStatus.success => const Text('Added'),
    MutationStatus.error => TextButton(
        onPressed: () => state.mutate('Buy milk'),
        child: Text('Could not add: ${state.error}. Try again'),
      ),
  },
)
```

To show the state away from the button, use the MutationState widgets below.

## Showing every run of a mutation

The MutationState widgets show every run of a mutation, wherever it started: a `MutationBuilder` on another screen, a `useMutation`, a cubit's observer, or [`restore(mutations:)`](../persistence/#persisting-mutations). They find the runs by the definition's `mutationKey`, so nothing has to share an observer, and they work in a `StatelessWidget`.

| Widget | Builds from, or hears |
|---|---|
| `MutationStateBuilder` | The `MutationState` of every run, oldest first |
| `MutationStateSelector` | A value selected from those states. It rebuilds only when the value changes. |
| `MutationStateListener` | Each change of each run, for side effects |

A progress bar while anything is being added:

```dart
MutationStateSelector(
  mutation: addTodo,
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, adding) =>
      adding ? const LinearProgressIndicator() : const SizedBox(height: 4),
)
```

The titles on their way to the server, typed as `String` like the definition's variables:

```dart
MutationStateBuilder(
  mutation: addTodo,
  builder: (context, runs) => Column(
    children: [
      for (final run in runs)
        if (run case MutationState(isPending: true, :final variables?))
          ListTile(title: Text(variables)),
    ],
  ),
)
```

### Matching runs

- Given a `Mutation`, the widgets show the runs whose `mutationKey` equals its own exactly, typed like the definition.
- Runs of another definition with the same key and types count too.
- A run of other types under the key is left out and reported once to [`onUncaughtError`](../client-setup/#catching-errors-that-callbacks-throw). Give each definition a key of its own.
- A definition without a `mutationKey` fails an assert in debug builds.
- Given `MutationFilters`, the widgets show the runs of any mutation that match them, as `client.mutationCache.findAll` finds them: by key prefix, `exact` key, `status`, or `predicate`. Their states are typed `Object?`.
- Without a `status` filter, settled runs match too.

### Run order and lifetime

- Runs are listed oldest first, so `runs.lastOrNull` is the latest.
- A run stays `gcTime` (default: 5 minutes) after it settles, so build an indicator from `isPending`, not from the number of runs.
- A mounted `MutationBuilder` keeps its latest run for as long as it shows it.
- `client.clear()` removes every run.

### Client and cost

- Only the runs of the widget's client count: the nearest `FueryProvider`'s, or `Fuery.client`.
- The widgets only read. They never run a mutation and apply none of the definition's options, so a definition built in `build` costs nothing.

## Telling the user a mutation failed

A failed `mutate` puts the error in the state instead of throwing it. A `MutationStateListener` hears every run of the mutation, from any screen, and gets each run's new state:

```dart
MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
  child: const TodoScreen(),
)
```

- Fuery calls it once for each run that changed, so two failed runs give two calls.
- `listenWhen` compares that run's previous state with its new one.
- It isn't called for the states runs already had when it mounted, or for a run that the cache removes.
- It hears restored runs and runs from other screens too, so mount it once, where the message belongs.

Pass `MutateOptions(onError: ...)` instead when only one call site shows the failure. Use `mutateAsync` in a `try`/`catch` when the caller handles it.

A `MutationListener` hears only the runs of the observer it gets. Given a definition, it creates an observer of its own that nothing runs, so it hears nothing. In debug builds, it also prints a warning. See [A MutationListener never runs](../../troubleshooting/#a-mutationlistener-never-runs).

## Sharing one observer

Every widget and hook given the definition keeps its own observer, and the MutationState widgets show the runs of all of them. Share one observer only when:

- code outside widgets, such as a cubit, runs the mutation, or
- several widgets must follow the runs of one screen and no others.

`addTodo.observe()` returns a `MutationObserver`, and every widget given it uses it as it is. Here the app bar shows a progress bar while this screen's form saves. A `MutationStateSelector` would also show the runs that other screens start:

```dart
class _AddTodoScreenState extends State<AddTodoScreen> {
  late final adding = addTodo.observe(client: context.queryClient);

  @override
  void dispose() {
    adding.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New todo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: MutationSelector(
            mutation: adding,
            selector: (state) => state.isPending,
            builder: (context, saving) => saving
                ? const LinearProgressIndicator()
                : const SizedBox(height: 4),
          ),
        ),
      ),
      body: AddTodoForm(onSubmit: adding.mutate),
    );
  }
}
```

To close the screen after its own call succeeds, you don't need a shared observer. Pass `MutateOptions(onSuccess: ...)` to that call ([Callbacks](#callbacks)).

- Create the observer once, in a `State` field or a cubit. `observe()` in `build` returns a new, idle observer on every rebuild.
- `observe()` uses `Fuery.client` unless you pass `client:`. Under a `FueryProvider` with its own client, pass `context.queryClient`, as above.
- Call `reset()` in `dispose`. It drops the callbacks of the latest `mutate` call, which belong to this screen. A widget given the definition resets its own observer when it unmounts.
- A `MutationListener`, `MutationSelector`, or `MutationBuilder` given the observer hears every run it starts, wherever it is called.
- The observer of a `NoVariablesMutation` runs it with `mutate()`, so a button can take its tear-off: `onPressed: logout.mutate`.
- A cubit or a bloc keeps its observer the same way and calls `mutateAsync` from its methods. See [Mutations from a bloc](../bloc/#mutations-from-a-bloc).

## In the example app

- [The feed mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart) have an optimistic like with a rollback, and a comment that pauses while offline.
- [The feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart) reports every failed like with a `MutationStateListener`.
- [The post screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart) lists the comments on their way with a `MutationStateBuilder`.

The example's [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
