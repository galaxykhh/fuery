import 'package:example/app/data/demo_api.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:fuery/fuery.dart';

/// Mutations live next to their queries, defined the same way. The cache
/// work below is written once, and every widget or observer that runs a
/// mutation keeps its own pending and error state. The callbacks receive the
/// client that runs the mutation, so they work with any client.
///
/// Anything that belongs to a screen, such as a snackbar, goes to the call
/// site instead: `state.mutate(variables, MutateOptions(...))`, or a
/// `MutationListener`.

/// What the cache held before an optimistic like, to put back on failure.
class LikeSnapshot {
  const LikeSnapshot({required this.feed, required this.post});

  final InfiniteData<PostPage, int>? feed;
  final Post? post;
}

/// Toggles a like in the feed and on the post right away, and puts both back
/// if the request fails.
Mutation<Post, int, LikeSnapshot> likePostMutation() {
  return Mutation(
    mutationFn: (int id) => DemoApi().toggleLike(id),
    onMutate: (id, client) async {
      // A refetch in flight would overwrite the optimistic value.
      await client.cancelQueries(queryKey: feedKey);
      await client.cancelQueries(queryKey: postKey(id));
      final snapshot = LikeSnapshot(
        feed: client.getData(feedQuery()),
        post: client.getData(postQuery(id)),
      );
      client.updateData(
        feedQuery(),
        (feed) => feed == null
            ? null
            : InfiniteData(
                pages: [
                  for (final page in feed.pages)
                    PostPage(
                      posts: [
                        for (final post in page.posts)
                          post.id == id ? _toggled(post) : post,
                      ],
                      nextCursor: page.nextCursor,
                    ),
                ],
                pageParams: feed.pageParams,
              ),
      );
      client.updateData(
        postQuery(id),
        (post) => post == null ? null : _toggled(post),
      );
      return snapshot;
    },
    onError: (error, id, snapshot, client) {
      if (snapshot?.feed case final feed?) client.setData(feedQuery(), feed);
      if (snapshot?.post case final post?) client.setData(postQuery(id), post);
    },
    onSettled: (post, error, id, snapshot, client) =>
        client.invalidateQueries(queryKey: postKey(id)),
  );
}

Post _toggled(Post post) => post.copyWith(
      liked: !post.liked,
      likes: post.likes + (post.liked ? -1 : 1),
    );

typedef NewComment = ({int postId, String body});

/// Adds a comment. While offline the mutation pauses and runs once the
/// connection is back. The scope keeps comments in the order they were
/// written, one at a time.
///
/// `persist` stores the comment while it waits, so one written offline is
/// still sent after the app is closed and opened again. `main.dart` passes
/// this mutation to `restore` for that.
Mutation<Comment, NewComment, void> addCommentMutation() {
  return Mutation(
    mutationKey: const ['comments', 'add'],
    mutationFn: (NewComment comment) =>
        DemoApi().addComment(comment.postId, comment.body),
    scope: const MutationScope('comments'),
    persist: MutationPersist(
      toJson: (comment) => {'postId': comment.postId, 'body': comment.body},
      fromJson: (json) {
        final map = json! as Map<String, Object?>;
        return (postId: map['postId']! as int, body: map['body']! as String);
      },
    ),
    onSuccess: (_, comment, __, client) {
      client.invalidateQueries(queryKey: commentsKey(comment.postId));
      client.invalidateQueries(queryKey: postKey(comment.postId));
    },
  );
}

/// Creates a post and refreshes the feed once the server has it.
///
/// The invalidation is not returned: a returned future keeps the mutation
/// pending until the refetch is done, and the compose screen shouldn't wait
/// for the feed.
Mutation<Post, String, void> createPostMutation() {
  return Mutation(
    mutationFn: (String body) => DemoApi().createPost(body),
    onSuccess: (post, _, __, client) {
      client.invalidateQueries(queryKey: feedKey);
    },
  );
}

/// Marks every notification read on screen first, then on the server. It
/// takes no variables, so its observer runs it with `mutate()`.
NoVariablesMutation<void, List<FeedNotification>> markAllReadMutation() {
  return NoVariablesMutation(
    mutationFn: () => DemoApi().markAllRead(),
    onMutate: (client) {
      final previous = client.getData(notificationsQuery());
      client.updateData(
        notificationsQuery(),
        (notifications) => [
          for (final notification in notifications ?? const [])
            notification.copyWith(read: true),
        ],
      );
      return previous;
    },
    onError: (error, previous, client) {
      if (previous != null) client.setData(notificationsQuery(), previous);
    },
    onSettled: (_, __, ___, client) =>
        client.invalidateQueries(queryKey: notificationsKey),
  );
}
