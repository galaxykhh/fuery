import 'package:example/app/data/feed_mutations.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:example/app/screens/feed/widgets/post_card.dart';
import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// The feed: a page at a time, pull to refresh, and likes that apply before
/// the server answers.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Every like that fails, found by the mutation's key: likes that overlap,
    // and likes whose card scrolled away before the server answered.
    return MutationStateListener(
      mutation: likePostMutation(),
      listenWhen: (previous, current) => current.isError,
      listener: (context, like) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not like the post')),
        );
      },
      child: Column(
        children: [
          // Rebuilds only when a background refetch starts or ends.
          InfiniteQueryBuilder(
            query: feedQuery(),
            buildWhen: (previous, current) =>
                previous.isRefetching != current.isRefetching,
            builder: (context, state) => state.isRefetching
                ? const LinearProgressIndicator(minHeight: 2)
                : const SizedBox(height: 2),
          ),
          Expanded(
            child: InfiniteQueryBuilder(
              query: feedQuery(),
              builder: (context, state) {
                return switch (state) {
                  InfiniteQueryResult(:final data?) => RefreshIndicator(
                      // `refetch` completes when the fetch settles, which is
                      // what RefreshIndicator waits for.
                      onRefresh: () => state.refetch(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _count(data.pages) + 1,
                        itemBuilder: (context, index) {
                          final post = _postAt(data.pages, index);
                          if (post == null) {
                            return _FeedFooter(
                              hasNextPage: state.hasNextPage,
                              isFetchingNextPage: state.isFetchingNextPage,
                              isFetchNextPageError: state.isFetchNextPageError,
                              onLoadMore: state.fetchNextPage,
                            );
                          }
                          // Each card runs its own likes.
                          return MutationBuilder(
                            mutation: likePostMutation(),
                            builder: (context, like) => PostCard(
                              post: post,
                              onLike: () => like.mutate(post.id),
                              onOpen: () => Navigator.push(
                                context,
                                PostScreen.route(post.id),
                              ),
                              // On the web and desktop the pointer reaches a
                              // card before the click does, so the post is
                              // often cached by the time it opens.
                              onHover: () => context.queryClient.query(
                                postQuery(post.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  InfiniteQueryResult(:final error?) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Could not load the feed: $error'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: state.refetch,
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
        ],
      ),
    );
  }

  static int _count(List<PostPage> pages) =>
      pages.fold<int>(0, (count, page) => count + page.posts.length);

  static Post? _postAt(List<PostPage> pages, int index) {
    var remaining = index;
    for (final page in pages) {
      if (remaining < page.posts.length) return page.posts[remaining];
      remaining -= page.posts.length;
    }
    return null;
  }
}

/// The last item of the list. It is built when the list scrolls near the end,
/// and that is when it asks for the next page.
class _FeedFooter extends StatefulWidget {
  const _FeedFooter({
    required this.hasNextPage,
    required this.isFetchingNextPage,
    required this.isFetchNextPageError,
    required this.onLoadMore,
  });

  final bool hasNextPage;
  final bool isFetchingNextPage;
  final bool isFetchNextPageError;
  final Future<void> Function() onLoadMore;

  @override
  State<_FeedFooter> createState() => _FeedFooterState();
}

class _FeedFooterState extends State<_FeedFooter> {
  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(_FeedFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadMore();
  }

  // After the frame, not during build. A page that failed waits for the
  // button, so a broken connection doesn't retry forever.
  void _loadMore() {
    if (!widget.hasNextPage ||
        widget.isFetchingNextPage ||
        widget.isFetchNextPageError) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: switch (widget) {
          _FeedFooter(hasNextPage: false) => Text(
              'You\'re all caught up',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _FeedFooter(isFetchNextPageError: true) => TextButton(
              onPressed: widget.onLoadMore,
              child: const Text('Load more'),
            ),
          _ => const CircularProgressIndicator(),
        },
      ),
    );
  }
}
