import 'package:example/app/data/todo_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// One page at a time, with the next page loaded on demand.
class InfiniteTodosScreen extends StatefulWidget {
  const InfiniteTodosScreen({super.key});

  static const String routeName = 'infinite_todos';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const InfiniteTodosScreen(),
    );
  }

  @override
  State<InfiniteTodosScreen> createState() => _InfiniteTodosScreenState();
}

class _InfiniteTodosScreenState extends State<InfiniteTodosScreen> {
  final archive = pagedTodosQuery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paged archive')),
      body: InfiniteQueryBuilder(
        query: archive,
        builder: (context, state) {
          if (state.error case final error? when state.pages.isEmpty) {
            return Center(child: Text('Error: $error'));
          }
          if (state.pages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = [for (final page in state.pages) ...page.todos];
          return ListView.builder(
            // One more row for the button or the end of the list.
            itemCount: todos.length + 1,
            itemBuilder: (context, index) {
              if (index < todos.length) {
                final todo = todos[index];
                return ListTile(
                  leading: Icon(
                    todo.isCompleted
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text(todo.title),
                  subtitle: Text(todo.description),
                );
              }
              if (!state.hasNextPage) {
                return const ListTile(title: Center(child: Text('The end')));
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: state.isFetching
                      ? const CircularProgressIndicator()
                      : FilledButton(
                          onPressed: archive.fetchNextPage,
                          child: const Text('Load more'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
