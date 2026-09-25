import 'package:example/app/data/feed_mutations.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:example/app/data/recent_posts.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// A post with its comments. It opens with the feed's copy of the post, so
/// there is no spinner, and comments written offline wait for the connection,
/// listed below the comments until they are sent.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.id});

  final int id;

  static const String routeName = 'post';

  static Route route(int id) {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => PostScreen(id: id),
    );
  }

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _draft = TextEditingController();
  // Asked for with a button, so the stream doesn't start until then.
  bool _summarize = false;

  @override
  void initState() {
    super.initState();
    // After the frame: the search screen listens, and can't rebuild during
    // this build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => rememberPost(widget.id));
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  // The list below the comments shows the comment on its way, so the
  // definition runs it and no widget has to keep it.
  void _send() {
    final body = _draft.text.trim();
    if (body.isEmpty) return;
    addCommentMutation().mutate(
      (postId: widget.id, body: body),
      context.queryClient,
    );
    _draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                QueryBuilder(
                  query: postQuery(widget.id),
                  builder: (context, state) => switch (state) {
                    QueryResult(:final data?) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.author, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(data.body, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text(
                            '${data.likes} likes · ${data.commentCount} comments'
                            '${state.isPlaceholderData ? ' · from the feed' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    QueryResult(:final error?) => Text('Error: $error'),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
                const SizedBox(height: 16),
                if (_summarize)
                  _Summary(query: summaryQuery(widget.id))
                else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _summarize = true),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Summarize thread'),
                  ),
                const Divider(height: 32),
                QueryBuilder(
                  query: commentsQuery(widget.id),
                  builder: (context, state) => switch (state) {
                    QueryResult(:final data?) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final comment in data)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(comment.author),
                              subtitle: Text(comment.body),
                            ),
                          if (data.isEmpty)
                            Text(
                              'No comments yet',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    QueryResult(:final error?) => Text('Error: $error'),
                    _ => const LinearProgressIndicator(),
                  },
                ),
              ],
            ),
          ),
          // Every comment on this post that is on its way, found by the
          // mutation's key: sent from this screen before, even before the
          // app restarted. Paused while offline, it sends itself once the
          // connection is back.
          MutationStateBuilder(
            mutation: addCommentMutation(),
            builder: (context, runs) => Column(
              children: [
                for (final run in runs)
                  if (run.isPending && run.variables?.postId == widget.id)
                    _QueuedComment(run),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A comment on its way to the server: paused while offline, or sending.
class _QueuedComment extends StatelessWidget {
  const _QueuedComment(this.run);

  final MutationState<Comment, NewComment, void> run;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: run.isPaused
          ? const Icon(Icons.cloud_off)
          : const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
      title: Text(
        run.isPaused
            ? 'Comment will send when you\'re back online'
            : 'Sending…',
      ),
      subtitle: Text(run.variables?.body ?? ''),
    );
  }
}

/// A summary that grows word by word, and is complete at once when the
/// screen is opened again.
class _Summary extends StatelessWidget {
  const _Summary({required this.query});

  final Query<String> query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QueryBuilder(
      query: query,
      builder: (context, state) => Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.isFetching ? 'Summarizing…' : 'Summary',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(state.data ?? ''),
            ],
          ),
        ),
      ),
    );
  }
}
