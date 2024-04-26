import 'package:example/app/data/payloads/add_todo_payload.dart';
import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_repository.dart';
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
  late final todos = Query.use(
    queryKey: ['todos', 'list'],
    queryFn: () => TodoApi().getList(),
  );

  late final addTodo = Mutation.use(
    mutationFn: (AddTodoPayload payload) => TodoApi().add(
      payload.title,
      payload.description,
    ),
    onSuccess: (_, newTodo) {
      Fuery.instance.invalidateQueries(queryKey: ['todos', 'list']);
    },
  );

  late final deleteTodo = Mutation.use(
    mutationFn: (int id) => TodoApi().delete(id),
    onMutate: (id) {
      final todos = Fuery.instance.getQueryData<List<Todo>>(['todos', 'list']);

      // has cached todos
      if (todos != null) {
        Fuery.instance.setQueryData(
          ['todos', 'list'],
          todos.where((t) => t.id != id).toList(),
        );
      }
    },
    onSuccess: (_, __) {
      Fuery.instance.invalidateQueries(queryKey: ['todos', 'list']);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Todos'),
            actions: [
              IconButton.outlined(
                onPressed: () => AddTodoDialog.show(
                  context,
                  onSubmit: (payload) => addTodo.mutate(payload),
                ),
                icon: const Icon(Icons.add),
              ),
              IconButton.outlined(
                onPressed: todos.refetch,
                icon: const Icon(Icons.refresh),
              )
            ],
          ),
          body: QueryListener(
            query: todos,
            listenWhen: (prev, curr) => prev.fetchStatus != curr.fetchStatus,
            listener: (context, data) {
              print('FETCH STATUS');
            },
            child: QueryBuilder(
              query: todos,
              builder: (context, state) {
                switch (state.status) {
                  case QueryStatus.idle:
                  case QueryStatus.pending:
                    return const Center(
                      child: CircularProgressIndicator(),
                    );

                  case QueryStatus.failure:
                    return const Center(
                      child: Text('ERROR'),
                    );

                  case QueryStatus.success:
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.data?.length ?? 0,
                      itemBuilder: (context, index) {
                        return TodoListItem(
                          todo: state.data![index],
                          onToggle: (todo) {},
                          onDelete: (todo) => deleteTodo.mutate(todo.id),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 6);
                      },
                    );
                }
              },
            ),
          ),
        ),
        MutationBuilder(
          mutation: deleteTodo,
          builder: (context, state) {
            if (state.status.isPending) {
              return const Stack(
                children: [
                  ModalBarrier(color: Colors.black54),
                  Center(child: CircularProgressIndicator(color: Colors.white)),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ],
    );
  }
}
