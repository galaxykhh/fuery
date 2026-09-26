---
title: Bloc and cubits
description: Read cached queries and run mutations from cubits and blocs, sharing one cache with Fuery's widgets.
---

Cubits and blocs use the same queries, mutations, and cache as Fuery's widgets, so you keep the state management you have. An observer's `stream` emits the current result, then every change. Listening subscribes the observer, which fetches as a mounted widget would. Cancelling the subscription unsubscribes it.

## Which builder to use

Pick a builder per screen:

| The screen | Build it with |
|---|---|
| Shows server data much as it arrives | `QueryBuilder`. A cubit in between would rebuild the loading and error flags that `QueryResult` already carries. |
| Mixes server data with app state: a selection, a filter, a form, several queries combined | A cubit that listens to the query, and `BlocBuilder` |
| Already runs on events, in an app built with blocs | A bloc that listens to the query, and `BlocBuilder` |

One screen can do both: `BlocBuilder` for the app state, `QueryBuilder` for the server data. Two screens that use the same key share one cache entry and one request either way, so choose by the screen, not by the data.

Listen to the query from the cubit, not through a repository. The query is already the caching layer.

## In a cubit

Outside widgets, `observe()` turns a query into an observer with a `stream`. `todosQuery` is the query, as in [Organizing queries](../organizing-queries/):

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState()) {
    _subscription = _todos.stream.listen((result) {
      emit(state.copyWith(todos: result.data, loading: result.isLoading));
    });
  }

  final _todos = todosQuery.observe();
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

Call `cancel()` in `close()` without awaiting it. Under `testWidgets` and `fakeAsync`, its future never completes. See [Testing cubits and blocs](../testing/#testing-cubits-and-blocs).

## In a bloc

`emit.forEach` subscribes for as long as the handler runs:

```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(const TodoState()) {
    on<TodosSubscribed>((event, emit) {
      return emit.forEach(
        todosQuery.observe().stream,
        onData: (result) =>
            state.copyWith(todos: result.data, loading: result.isLoading),
      );
    });
  }
}
```

## Mutations from a cubit or bloc

A cubit runs a mutation from its definition, with no observer of its own. `mutateAsync` returns the data or throws, which fits a cubit's methods:

```dart
Future<void> add(String title) async {
  try {
    await addTodo.mutateAsync(title);
  } catch (error) {
    emit(state.copyWith(error: error));
  }
}
```

A bloc's event handler does the same: `await addTodo.mutateAsync(event.title)`.

- The run uses `Fuery.client`. A cubit given another client, such as a test's, passes it: `addTodo.mutateAsync(title, client)`.
- The run belongs to the client's cache, not to the cubit, so every screen can show it. See [Sharing with widgets](#sharing-with-widgets).
- Keep an observer, `final _addTodo = addTodo.observe();`, only when the cubit follows the state of its own runs through the observer's `result` or `stream`.

## Sharing with widgets

A cubit and a `QueryBuilder` that use the same key share one cache entry. A change made on one screen, such as marking notifications read, shows in the cubit and in every widget.

Give `addTodo` a `mutationKey`, and the runs a cubit or bloc starts show in `MutationStateBuilder(mutation: addTodo)` on any screen. See [Showing every run of a mutation](../mutations/#showing-every-run-of-a-mutation).

A cubit that reacts to every run of a mutation, wherever it started, keeps a `MutationStateSlot`. `subscribeToRuns` calls its listener for each later change of each run, and `result` lists the current runs. See [Every run of a mutation](../adapters/#every-run-of-a-mutation).

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit(QueryClient client)
      : _adding = MutationStateSlot(addTodo, client),
        super(const TodoState()) {
    _adding.subscribeToRuns((previous, current) {
      if (current.isError) emit(state.copyWith(error: current.error));
    });
  }

  final MutationStateSlot<Todo, String, Object?> _adding;

  @override
  Future<void> close() {
    _adding.dispose();
    return super.close();
  }
}
```

## App lifecycle

Fuery's widgets, hooks, and `FueryProvider` connect the app lifecycle, so stale queries refetch when the app resumes. An app that uses queries only from blocs, without a `FueryProvider`, calls `FueryBinding.ensureInitialized()` once in `main` instead. See [When the app resumes](../lifecycle/#when-the-app-resumes).

## In the example app

The [notifications cubit](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/notifications/notifications_cubit.dart) counts unread notifications for a badge, while the notifications screen shows the same query with Fuery's widgets. The example's [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
