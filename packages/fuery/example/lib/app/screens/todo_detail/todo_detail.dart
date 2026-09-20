import 'package:example/app/data/todo_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// A detail screen that opens with the list's copy of the todo as placeholder
/// data, then shows the fresh one when it arrives.
class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({super.key, required this.id});

  final int id;

  static const String routeName = 'todo_detail';

  static Route route(int id) {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => TodoDetailScreen(id: id),
    );
  }

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late final todo = todoQuery(widget.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo')),
      body: QueryBuilder(
        query: todo,
        builder: (context, state) {
          return switch (state) {
            QueryResult(:final data?) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(data.description),
                    const SizedBox(height: 24),
                    Text(
                      state.isPlaceholderData
                          ? 'Showing the list\'s copy while loading'
                          : 'Loaded from the server',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            QueryResult(:final error?) => Center(child: Text('Error: $error')),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}
