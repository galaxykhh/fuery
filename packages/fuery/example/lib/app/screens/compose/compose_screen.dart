import 'package:example/app/data/feed_mutations.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Writes a post. After it is sent the screen polls the server until the post
/// is published, then stops.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  static const String routeName = 'compose';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const ComposeScreen(),
    );
  }

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final createPost = createPostMutation();
  final _body = TextEditingController();
  // Set once the server has the post; polls it until it is published.
  QueryObserver<Post>? _published;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _post() {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    createPost.mutate(
      body,
      MutateOptions(
        // Screen-level work stays at the call site. The feed invalidation
        // lives in the mutation, where every caller gets it.
        onSuccess: (post, _, __) => setState(
            () => _published = publishingPostOptions(post.id).observe()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_published) {
          final query? => _Publishing(query: query),
          null => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _body,
                  autofocus: true,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'What\'s happening?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                MutationBuilder(
                  mutation: createPost,
                  builder: (context, state) => FilledButton(
                    onPressed: state.isPending ? null : _post,
                    child: Text(state.isPending ? 'Posting…' : 'Post'),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}

class _Publishing extends StatelessWidget {
  const _Publishing({required this.query});

  final QueryObserver<Post> query;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: query,
      builder: (context, state) {
        final published = state.data?.status == PostStatus.published;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: published
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              title: Text(published ? 'Published' : 'Publishing…'),
              subtitle: Text(
                published
                    ? 'Polling stopped'
                    : 'Checking with the server every half second',
              ),
            ),
            if (state.data case final post?) ...[
              const SizedBox(height: 8),
              Text(post.body),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: published
                    ? () => Navigator.pushReplacement(
                          context,
                          PostScreen.route(post.id),
                        )
                    : null,
                child: const Text('View post'),
              ),
            ],
          ],
        );
      },
    );
  }
}
