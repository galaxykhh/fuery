import 'package:example/app/data/payloads/add_todo_payload.dart';
import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_queries.dart';
import 'package:example/app/data/todo_repository.dart';
import 'package:fuery/fuery.dart';

/// Mutations live next to their queries, like the query factories do. Each
/// call returns its own observer, so a screen's pending and error state stays
/// its own, while the cache work below is written once.
///
/// Anything that belongs to a screen, such as a snackbar, goes to the call
/// site instead: `addTodoMutation().mutate(payload, MutateOptions(...))`, or a
/// `MutationListener`.

MutationObserver<Todo, AddTodoPayload, void> addTodoMutation() {
  return Mutation.use(
    mutationFn: (AddTodoPayload payload) =>
        TodoApi().add(payload.title, payload.description),
    onSuccess: (todo, payload, _) =>
        Fuery.client.invalidateQueries(queryKey: todosKey),
  );
}

MutationObserver<Todo, int, void> toggleTodoMutation() {
  return Mutation.use(
    mutationFn: (int id) => TodoApi().toggle(id),
    onSuccess: (todo, id, _) =>
        Fuery.client.invalidateQueries(queryKey: ['todos']),
  );
}

/// Removes the todo from the list right away, and puts it back if the server
/// call fails. The removed list is the context that `onError` rolls back to.
MutationObserver<void, int, List<Todo>> deleteTodoMutation() {
  return Mutation.use(
    mutationFn: (int id) => TodoApi().delete(id),
    onMutate: (id) async {
      final client = Fuery.client;
      // A refetch in flight would bring the todo back.
      await client.cancelQueries(queryKey: todosKey);
      final previous = client.getQueryData<List<Todo>>(todosKey);
      client.updateQueryData<List<Todo>>(
        todosKey,
        (todos) => todos?.where((todo) => todo.id != id).toList(),
      );
      return previous;
    },
    onError: (error, id, previous) {
      if (previous != null) Fuery.client.setQueryData(todosKey, previous);
    },
    onSuccess: (_, id, __) =>
        Fuery.client.invalidateQueries(queryKey: todosKey),
  );
}
