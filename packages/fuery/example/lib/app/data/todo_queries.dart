import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_repository.dart';
import 'package:fuery/fuery.dart';

const todosKey = ['todos', 'list'];

/// The todo list query. Every widget and cubit that calls this shares one
/// cache entry, so a change made on one screen shows up on the others.
QueryObserver<List<Todo>> todosQuery() {
  return Query.use(
    queryKey: todosKey,
    queryFn: (_) => TodoApi().getList(),
  );
}
