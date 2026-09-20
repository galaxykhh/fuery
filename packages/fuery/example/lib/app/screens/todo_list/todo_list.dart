import 'package:example/app/data/todo_mutations.dart';
import 'package:example/app/data/todo_queries.dart';
import 'package:example/app/screens/todo_detail/todo_detail.dart';
import 'package:example/app/screens/todo_list/widgets/add_todo_dialog.dart';
import 'package:example/app/screens/todo_list/widgets/todo_list_item.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  static const String routeName = 'todo_list';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const TodoListScreen(),
    );
  }

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final todos = todosQuery();

  final addTodo = addTodoMutation();
  final toggleTodo = toggleTodoMutation();
  final deleteTodo = deleteTodoMutation();

  @override
  Widget build(BuildContext context) {
    return MutationListener(
      mutation: deleteTodo,
      listenWhen: (previous, current) => current.isError,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: ${state.error}')),
        );
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Todos'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: QueryBuilder(
                  query: todos,
                  buildWhen: (previous, current) =>
                      previous.isRefetching != current.isRefetching,
                  builder: (context, state) => state.isRefetching
                      ? const LinearProgressIndicator(minHeight: 2)
                      : const SizedBox(height: 2),
                ),
              ),
              actions: [
                IconButton.outlined(
                  onPressed: () => AddTodoDialog.show(
                    context,
                    onSubmit: addTodo.mutate,
                  ),
                  icon: const Icon(Icons.add),
                ),
                IconButton.outlined(
                  onPressed: todos.refetch,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: QueryBuilder(
              query: todos,
              builder: (context, state) {
                return switch (state) {
                  // `refetch` completes when the fetch settles, which is what
                  // RefreshIndicator waits for.
                  QueryResult(:final data?) => RefreshIndicator(
                      onRefresh: () => todos.refetch(),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          return TodoListItem(
                            todo: data[index],
                            onToggle: (todo) => toggleTodo.mutate(todo.id),
                            onDelete: (todo) => deleteTodo.mutate(todo.id),
                            onOpen: (todo) => Navigator.push(
                              context,
                              TodoDetailScreen.route(todo.id),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 6);
                        },
                      ),
                    ),
                  QueryResult(:final error?) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error: $error'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: todos.refetch,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                };
              },
            ),
          ),
          MutationBuilder(
            mutation: deleteTodo,
            builder: (context, state) {
              if (!state.isPending) return const SizedBox();
              return const Stack(
                children: [
                  ModalBarrier(color: Colors.black54),
                  Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
