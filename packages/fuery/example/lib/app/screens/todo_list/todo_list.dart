import 'package:example/app/data/payloads/add_todo_payload.dart';
import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_queries.dart';
import 'package:example/app/data/todo_repository.dart';
import 'package:example/app/screens/todo_list/widgets/add_todo_dialog.dart';
import 'package:example/app/screens/todo_list/widgets/todo_list_item.dart';
import 'package:example/app/screens/todo_stats/todo_stats.dart';
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

  final addTodo = Mutation.use(
    mutationFn: (AddTodoPayload payload) {
      return TodoApi().add(payload.title, payload.description);
    },
    onSuccess: (todo, payload, _) {
      return Fuery.instance.invalidateQueries(queryKey: todosKey);
    },
  );

  final toggleTodo = Mutation.use(
    mutationFn: (int id) => TodoApi().toggle(id),
    onSuccess: (_, id, __) {
      return Fuery.instance.invalidateQueries(queryKey: todosKey);
    },
  );

  // Removes the todo from the list right away, and puts it back if the
  // server call fails.
  final deleteTodo = Mutation.use(
    mutationFn: (int id) => TodoApi().delete(id),
    onMutate: (id) {
      final client = Fuery.instance;
      final previous = client.getQueryData<List<Todo>>(todosKey);
      client.updateQueryData<List<Todo>>(
        todosKey,
        (todos) => todos?.where((todo) => todo.id != id).toList(),
      );
      return previous;
    },
    onError: (error, id, previous) {
      if (previous != null) Fuery.instance.setQueryData(todosKey, previous);
    },
    onSuccess: (_, id, __) {
      return Fuery.instance.invalidateQueries(queryKey: todosKey);
    },
  );

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
                  onPressed: () => Navigator.push(
                    context,
                    TodoStatsScreen.route(),
                  ),
                  icon: const Icon(Icons.insights),
                ),
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
                  QueryResult(:final data?) => ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return TodoListItem(
                          todo: data[index],
                          onToggle: (todo) => toggleTodo.mutate(todo.id),
                          onDelete: (todo) => deleteTodo.mutate(todo.id),
                        );
                      },
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 6);
                      },
                    ),
                  QueryResult(:final error?) => Center(
                      child: Text('Error: $error'),
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
