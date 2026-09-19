import 'package:example/app/data/todo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adds a todo after every todo was deleted', (tester) async {
    final api = TodoApi();
    Future<T> settle<T>(Future<T> future) async {
      await tester.pump(const Duration(seconds: 3));
      return future;
    }

    for (final todo in await settle(api.getList())) {
      await settle(api.delete(todo.id));
    }
    final todo = await settle(api.add('Buy milk', ''));
    expect(todo.id, 6);
  });
}
