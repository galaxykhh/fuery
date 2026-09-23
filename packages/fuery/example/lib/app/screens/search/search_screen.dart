import 'dart:async';

import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:example/app/data/recent_posts.dart';
import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Search as you type. The widgets get the current term's query and keep
/// their observers, so the previous results stay on screen until the next
/// ones arrive.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _term = '';
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
      setState(() => _term = term.trim());
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
        // Nothing typed: the recently viewed posts, and no search at all, so
        // the last term's results don't linger as placeholder data.
        if (_term.isEmpty) ...[
          const SizedBox(height: 2),
          const Expanded(child: _RecentPosts()),
        ] else ...[
          // Shows only while a new term loads behind the previous results.
          QueryBuilder(
            query: searchQuery(_term),
            buildWhen: (previous, current) =>
                previous.isPlaceholderData != current.isPlaceholderData,
            builder: (context, state) => state.isPlaceholderData
                ? const LinearProgressIndicator(minHeight: 2)
                : const SizedBox(height: 2),
          ),
          Expanded(
            child: QueryBuilder(
              query: searchQuery(_term),
              builder: (context, state) => switch (state) {
                QueryResult(:final data?) when data.isEmpty => const Center(
                    child: Text('No posts match'),
                  ),
                QueryResult(:final data?) => ListView(
                    children: [
                      for (final post in data)
                        ListTile(
                          title: Text(post.body),
                          subtitle:
                              Text('${post.author} · ${post.likes} likes'),
                          onTap: () => Navigator.push(
                            context,
                            PostScreen.route(post.id),
                          ),
                        ),
                    ],
                  ),
                QueryResult(:final error?) =>
                  Center(child: Text('Error: $error')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// The posts opened lately, shown while nothing is typed. Each is its own
/// query, so a post opened before shows at once from the cache, and one the
/// cache let go of loads again.
class _RecentPosts extends StatelessWidget {
  const _RecentPosts();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: recentPosts,
      builder: (context, ids, _) => ids.isEmpty
          ? const Center(child: Text('Type to search'))
          : QueriesBuilder(
              queries: [for (final id in ids) postQuery(id)],
              builder: (context, results) => ListView(
                children: [
                  ListTile(
                    title: Text(
                      'Recently viewed',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final result in results) _tile(context, result),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, QueryResult<Post> result) {
    return switch (result) {
      QueryResult(data: final post?) => ListTile(
          title: Text(post.body),
          subtitle: Text(post.author),
          onTap: () => Navigator.push(context, PostScreen.route(post.id)),
        ),
      QueryResult(:final error?) => ListTile(
          title: Text('Could not load this post: $error'),
          trailing: IconButton(
            tooltip: 'Try again',
            onPressed: result.refetch,
            icon: const Icon(Icons.refresh),
          ),
        ),
      _ => const ListTile(title: LinearProgressIndicator()),
    };
  }
}
