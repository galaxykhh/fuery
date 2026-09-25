---
title: Mutations
description: Create, update, and delete server data in Flutter, with optimistic updates and rollback.
---

A mutation changes server data and reports what happened while it runs. This page covers running one, showing its runs anywhere in the app, reacting to the result, and updating the cache before the server answers.

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

Give the parameter of `mutationFn` a type, like `String title` above. The rest of the types are inferred from it. The `mutationKey` lets any widget find the mutation's runs; see [Showing every run of a mutation](#showing-every-run-of-a-mutation).

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

The builder shows the runs it starts. To show the mutation's state anywhere else, such as a progress bar on another screen, use the [MutationState widgets](#showing-every-run-of-a-mutation), which find its runs by `mutationKey`. To run it from a cubit, or from several widgets that must see only each other's runs, see [Sharing one observer](#sharing-one-observer).

## MutationState fields

Builders, listeners, and an observer's `result` all report a `MutationResult`, a `MutationState` with `mutate`, `mutateAsync`, and `reset`. The [MutationState widgets](#showing-every-run-of-a-mutation) and `useMutationState` report plain `MutationState`s, one for each run, without them:

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

To react to a single call, pass `MutateOptions`. Its callbacks run after the mutation's own, once the call settles:

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

- A later `mutate` call on the same observer replaces them, so only the latest call's callbacks run.
- `reset()` drops them, and so does unmounting the widget that got the mutation.
- A [shared observer](#sharing-one-observer) runs them whether or not a widget listens to it. Check `context.mounted` before using a `BuildContext` in them.

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

`NoVariablesMutation` describes a mutation that takes nothing. Its callbacks drop the variables argument: `onMutate(client)`, `onSuccess(data, context, client)`, `onError(error, context, client)`, and `onSettled(data, error, context, client)`.

```dart
final logoutMutation = NoVariablesMutation(
  mutationFn: () => api.logout(),
);
```

A result is typed like any mutation's, with `void` variables, so a `MutationBuilder` runs it with `state.mutate(null)`. The callbacks of one call keep the variables argument, which is `null`: `MutateOptions(onSuccess: (data, _, context, client) {...})`.

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

`useMutation(logoutMutation)` returns the same result, so a `HookWidget` calls `mutate(null)` too. Outside widgets, its observer, a `NoVariablesMutationObserver`, runs it with `mutate()`; see [Sharing one observer](#sharing-one-observer).

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

The builder that runs a mutation shows the state of its runs. Switch on `status` when it draws every branch:

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

A widget that only shows the state, away from the button, uses the MutationState widgets below.

## Showing every run of a mutation

The MutationState widgets show the runs of a mutation wherever they started: a `MutationBuilder` on another screen, a `useMutation`, a cubit's observer, or [`restore(mutations:)`](../persistence/#persisting-mutations). They find the runs by the definition's `mutationKey`, so nothing has to share an observer, and they work in a `StatelessWidget`.

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

Which runs they show:

- A `Mutation` finds the runs with its `mutationKey`, exactly, typed like the definition. The runs of another definition with the same key and types count too. A definition without a key fails an assert in debug builds.
- A run of other types under the key is left out, and reported once to [`onUncaughtError`](../client-setup/#catching-errors-that-callbacks-throw). Give each definition a key of its own.
- `MutationFilters` find the runs of any mutation that match them, as `client.mutationCache.findAll` does: by key prefix, `exact` key, `status`, or `predicate`. Without a `status`, settled runs match too. Their states are typed `Object?`.
- The runs are listed oldest first, so `runs.lastOrNull` is the latest.
- A settled run stays until the cache removes it, `gcTime` (default: 5 minutes) after it settles. A mounted `MutationBuilder` keeps its latest run for as long as it shows it. Build indicators from `isPending`, not from the length. `client.clear()` removes every run.
- Only the runs of the widget's client count: the nearest `FueryProvider`'s, or `Fuery.client`.
- The widgets only read. They never run a mutation and apply none of the definition's options, so a definition built in `build` costs nothing.

## Telling the user a mutation failed

A failed `mutate` puts the error in the state instead of throwing. A `MutationStateListener` hears every run of the mutation, from any screen, and gets each run's new state:

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

- It is called once for each run that changed, so two runs that fail give two calls. `listenWhen` compares that run's previous state with its new one.
- It isn't called for the states runs already had when it mounted, or for a run that the cache removes.
- It hears restored runs and runs from other screens too, so mount it once, where the message belongs.

Use `MutateOptions(onError: ...)` instead when only one call site shows the failure, and `mutateAsync` inside a `try`/`catch` when the caller handles it.

A `MutationListener` hears only the runs of the observer it gets. Given a definition, it hears nothing, because nothing runs its observer, and in debug builds it prints a warning. See [A MutationListener never runs](../../troubleshooting/#a-mutationlistener-never-runs).

## Sharing one observer

Every widget and hook that gets the definition keeps an observer of its own, and the MutationState widgets show all their runs. Share one observer only when code outside widgets runs the mutation, or when several widgets must follow the runs of one screen and nothing else. `addTodo.observe()` returns a `MutationObserver`, and every widget given it uses it as it is. Here the app bar shows a progress bar while this screen's form saves. A `MutationStateSelector` would also show the runs that other screens start:

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

Closing the screen after its own call succeeds needs no shared observer: pass `MutateOptions(onSuccess: ...)` to that call. See [Callbacks](#callbacks).

- Create it once, in a `State` field or a cubit. `observe()` in `build` returns a new, idle observer on every rebuild.
- `observe()` uses `Fuery.client` unless you pass `client:`. Under a `FueryProvider` with a client of its own, pass `context.queryClient`, as above, so the observer uses the client the widgets use.
- Call `reset()` in `dispose`. It drops the callbacks of the latest `mutate` call, which belong to this screen. A widget given the definition does this when it unmounts.
- A `MutationListener`, a `MutationSelector`, and a `MutationBuilder` given the observer hear every run it starts, wherever it is called.
- The observer of a `NoVariablesMutation` runs it with `mutate()`, so a button can take its tear-off: `onPressed: logout.mutate`.
- A cubit or a bloc keeps its observer the same way, and calls `mutateAsync` from its methods. See [Mutations from a bloc](../bloc/#mutations-from-a-bloc).

## In the example app

The example has an optimistic like with a rollback and a comment that pauses while offline in [the feed mutations](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart). [The feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart) reports every failed like with a `MutationStateListener`, and [the post screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart) lists the comments on their way with a `MutationStateBuilder`. Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
