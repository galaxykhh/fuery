import 'dart:async';

import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Search as you type. One observer follows the term, and the previous
/// results stay on screen until the next ones arrive.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final results = searchQuery('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String term) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Every term is its own cache entry. A term typed before is shown at
      // once, and a new one keeps the old results as placeholder data.
      results.setOptions(searchOptions(term.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: _onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search posts and people',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        // Shows only while a new term loads behind the previous results.
        QueryBuilder(
          query: results,
          buildWhen: (previous, current) =>
              previous.isPlaceholderData != current.isPlaceholderData,
          builder: (context, state) => state.isPlaceholderData
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
        Expanded(
          child: QueryBuilder(
            query: results,
            builder: (context, state) => switch (state) {
              QueryResult(:final data?) when data.isEmpty => const Center(
                  child: Text('No posts match'),
                ),
              QueryResult(:final data?) => ListView(
                  children: [
                    for (final post in data)
                      ListTile(
                        title: Text(post.body),
                        subtitle: Text(post.author),
                        onTap: () => Navigator.push(
                          context,
                          PostScreen.route(post.id),
                        ),
                      ),
                  ],
                ),
              QueryResult(:final error?) =>
                Center(child: Text('Error: $error')),
              QueryResult(isEnabled: false) => const Center(
                  child: Text('Type to search'),
                ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ],
    );
  }
}
