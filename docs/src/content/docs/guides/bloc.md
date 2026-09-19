---
title: Using with bloc
description: Use the same queries inside cubits and blocs.
---

Queries and mutations don't depend on widgets. Every observer has a `stream` that emits the current result first, then every change. Listening to it is what makes the query fetch, and cancelling the subscription stops watching it.

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

Call `cancel()` in `close()` without awaiting it. Its future doesn't complete inside `testWidgets`, so awaiting it hangs widget tests.

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

A cubit and a `QueryBuilder` that use the same key share one cache entry. A change made on one screen, like completing a todo, shows up in the cubit and in every widget. The [example app](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) has a list screen built with Fuery widgets and a stats screen built with a cubit, reading the same query.

## App lifecycle

Fuery widgets connect the app lifecycle for you. If your app only uses queries from blocs, call this once at startup so stale queries refetch when the app resumes:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```
