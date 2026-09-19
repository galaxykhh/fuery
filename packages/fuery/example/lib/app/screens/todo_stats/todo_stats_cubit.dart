import 'dart:async';

import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_queries.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuery/fuery.dart';

class TodoStatsState {
  const TodoStatsState({
    this.total = 0,
    this.completed = 0,
    this.isLoading = true,
    this.isRefreshing = false,
    this.error,
  });

  final int total;
  final int completed;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  double get progress => total == 0 ? 0 : completed / total;

  @override
  bool operator ==(Object other) {
    return other is TodoStatsState &&
        other.total == total &&
        other.completed == completed &&
        other.isLoading == isLoading &&
        other.isRefreshing == isRefreshing &&
        other.error == error;
  }

  @override
  int get hashCode =>
      Object.hash(total, completed, isLoading, isRefreshing, error);
}

/// Derives stats from the same todo query the list screen uses. Listening to
/// the query's stream is what makes it fetch, and the cubit sees every change
/// the list screen makes.
class TodoStatsCubit extends Cubit<TodoStatsState> {
  TodoStatsCubit({QueryObserver<List<Todo>>? todos})
      : _todos = todos ?? todosQuery(),
        super(const TodoStatsState()) {
    _subscription = _todos.stream.listen(_onResult);
  }

  final QueryObserver<List<Todo>> _todos;
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  void _onResult(QueryResult<List<Todo>> result) {
    final todos = result.data ?? const <Todo>[];
    emit(TodoStatsState(
      total: todos.length,
      completed: todos.where((todo) => todo.isCompleted).length,
      isLoading: result.isLoading,
      isRefreshing: result.isRefetching,
      error: result.isLoadingError ? result.error : null,
    ));
  }

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
