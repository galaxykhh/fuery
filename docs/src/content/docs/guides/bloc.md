---
title: Using with bloc
description: Use cached server data inside cubits and blocs, without replacing your state management.
---

Queries and mutations don't depend on widgets. Every observer exposes a `stream` that emits the current result first, then every change. The query fetches as soon as you listen to that stream, and stops updating when you cancel the subscription.

## Which builder to use

Adding Fuery doesn't move your screens to a new builder. Pick per screen:

| The screen | Build it with |
|---|---|
| Shows server data much as it arrives | `QueryBuilder`. A cubit in between would rebuild the loading and error flags that `QueryResult` already carries. |
| Mixes server data with app state: a selection, a filter, a form, several queries combined | A cubit that listens to the query, and `BlocBuilder` |
| Already runs on events, in an app built with blocs | A bloc that listens to the query, and `BlocBuilder` |

One screen can do both: `BlocBuilder` for the app state, `QueryBuilder` for the server data. Two screens that use the same key share one cache entry and one request either way, so the choice is about the screen, not about the data.

Keep the query out of a repository. It is already the caching layer, so a cubit that listens to it directly has one layer less to keep in sync.

The example app shows both: a list screen built with Fuery widgets, and a stats screen whose cubit listens to the same query.

## In a cubit

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState()) {
    _subscription = _todos.stream.listen((result) {
      emit(state.copyWith(todos: result.data, loading: result.isLoading));
    });
  }

  final _todos = todosQuery();
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

Call `cancel()` in `close()` without awaiting it. See [Testing cubits and blocs](../testing/#testing-cubits-and-blocs) for why.

## In a bloc

`emit.forEach` subscribes for as long as the handler runs:

```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(const TodoState()) {
    on<TodosSubscribed>((event, emit) {
      return emit.forEach(
        todosQuery().stream,
        onData: (result) =>
            state.copyWith(todos: result.data, loading: result.isLoading),
      );
    });
  }
}
```

## Mutations from a bloc

`mutateAsync` returns the data or throws, which fits event handlers:

```dart
on<TodoAdded>((event, emit) async {
  try {
    await _addTodo.mutateAsync(event.title);
  } catch (error) {
    emit(state.copyWith(error: error));
  }
});
```

## Sharing with widgets

A cubit and a `QueryBuilder` that use the same key share one cache entry. A change made on one screen, like marking notifications read, shows up in the cubit and in every widget. The [example app](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) has a notifications screen built with Fuery widgets and a badge counted by a cubit, reading the same query.

## App lifecycle

An app that uses queries only from blocs has to connect the app lifecycle itself, with one call at startup. See [Refetching automatically](../lifecycle/#when-the-app-resumes).

## In the example app

The example has a query in a cubit in [the notifications cubit](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/notifications/notifications_cubit.dart), which counts unread notifications for a badge while the notifications screen shows the same query. Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
