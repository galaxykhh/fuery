import 'dart:async';

import 'package:example/app/data/todo_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Each search term is its own cache entry. The previous results stay on
/// screen while the next ones load, and repeating a term is instant.
class SearchTodosScreen extends StatefulWidget {
  const SearchTodosScreen({super.key});

  static const String routeName = 'search_todos';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const SearchTodosScreen(),
    );
  }

  @override
  State<SearchTodosScreen> createState() => _SearchTodosScreenState();
}

class _SearchTodosScreenState extends State<SearchTodosScreen> {
  // One observer follows every term, so the previous results can stay on
  // screen while the next ones load.
  final results = searchTodosQuery('');

  String _term = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    // Debouncing belongs to the screen: the query only sees settled terms.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final term = value.trim();
      setState(() => _term = term);
      results.setOptions(searchTodosOptions(term));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search as you type')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Try "todo 1"',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: QueryBuilder(
              query: results,
              builder: (context, state) {
                if (_term.isEmpty) {
                  return const Center(child: Text('Type to search'));
                }
                return switch (state) {
                  QueryResult(:final data?) => Stack(
                      children: [
                        if (data.isEmpty)
                          const Center(child: Text('Nothing found'))
                        else
                          ListView(
                            children: [
                              for (final todo in data)
                                ListTile(
                                  title: Text(todo.title),
                                  subtitle: Text(todo.description),
                                ),
                            ],
                          ),
                        // Results of the previous term while this one loads.
                        if (state.isPlaceholderData || state.isRefetching)
                          const LinearProgressIndicator(minHeight: 2),
                      ],
                    ),
                  QueryResult(:final error?) => Center(
                      child: Text('Error: $error'),
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}
