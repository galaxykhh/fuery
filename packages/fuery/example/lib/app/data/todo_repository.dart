import 'package:example/app/data/todo.dart';

// mock data
final List<Todo> _todos = [
  const Todo(
      id: 1,
      title: "Grocery Shopping",
      description: "Buy fruits, vegetables, and bread",
      isCompleted: false),
  const Todo(
      id: 2,
      title: "Finish Assignment",
      description: "Complete the programming assignment for class",
      isCompleted: false),
  const Todo(
      id: 3,
      title: "Call Mom",
      description: "Check up on her and see how she's doing",
      isCompleted: false),
  const Todo(
      id: 4,
      title: "Read Chapter 5",
      description: "Read chapter 5 of the novel for book club meeting",
      isCompleted: false),
  const Todo(
    id: 5,
    title: "Pay Bills",
    description: "Pay electricity, water, and internet bills",
    isCompleted: false,
  ),
];

class TodoApi {
  Future<List<Todo>> getList() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [..._todos];
  }

  Future<Todo> add(String title, String description) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final todo = Todo(
      id: _todos.last.id + 1,
      title: title,
      description: description,
      isCompleted: false,
    );
    _todos.add(todo);

    return todo;
  }

  Future<void> delete(int id) async {
    await Future.delayed(const Duration(milliseconds: 3000));
    _todos.removeWhere((t) => t.id == id);
  }
}
