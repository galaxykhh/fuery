import 'package:example/app/data/demo_api.dart';
import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/data/models.dart';
import 'package:fuery/fuery.dart';

/// Mutations live next to their queries, like the query factories do. Each
/// call returns its own observer, so a screen's pending and error state stays
/// its own, while the cache work below is written once.
///
/// Anything that belongs to a screen, such as a snackbar, goes to the call
/// site instead: `mutation.mutate(variables, MutateOptions(...))`, or a
/// `MutationListener`.

/// What the cache held before an optimistic like, to put back on failure.
class LikeSnapshot {
  const LikeSnapshot({required this.feed, required this.post});

  final InfiniteData<PostPage, int>? feed;
  final Post? post;
}

/// Toggles a like in the feed and on the post right away, and puts both back
/// if the request fails.
MutationObserver<Post, int, LikeSnapshot> likePostMutation() {
  return Mutation.observe(
    mutationFn: (int id) => DemoApi().toggleLike(id),
    onMutate: (id) async {
      final client = Fuery.client;
      // A refetch in flight would overwrite the optimistic value.
      await client.cancelQueries(queryKey: feedKey);
      await client.cancelQueries(queryKey: postKey(id));
      final snapshot = LikeSnapshot(
        feed: client.getData(feedOptions()),
        post: client.getData(postOptions(id)),
      );
      client.updateData(
        feedOptions(),
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
        postOptions(id),
        (post) => post == null ? null : _toggled(post),
      );
      return snapshot;
    },
    onError: (error, id, snapshot) {
      final client = Fuery.client;
      if (snapshot?.feed case final feed?) {
        client.setData(feedOptions(), feed);
      }
      if (snapshot?.post case final post?) {
        client.setData(postOptions(id), post);
      }
    },
    onSettled: (post, error, id, snapshot) =>
        Fuery.client.invalidateQueries(queryKey: postKey(id)),
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
/// [addCommentOptions] to `restore` for that.
MutationObserver<Comment, NewComment, void> addCommentMutation() =>
    addCommentOptions().observe();

MutationOptions<Comment, NewComment, void> addCommentOptions() {
  return MutationOptions(
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
    onSuccess: (_, comment, __) {
      final client = Fuery.client;
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
MutationObserver<Post, String, void> createPostMutation() {
  return Mutation.observe(
    mutationFn: (String body) => DemoApi().createPost(body),
    onSuccess: (post, _, __) {
      Fuery.client.invalidateQueries(queryKey: feedKey);
    },
  );
}

/// Marks every notification read on screen first, then on the server.
NoVariablesMutationObserver<void, List<FeedNotification>>
    markAllReadMutation() {
  return Mutation.noVariables(
    mutationFn: () => DemoApi().markAllRead(),
    onMutate: () {
      final client = Fuery.client;
      final previous = client.getData(notificationsOptions());
      client.updateData(
        notificationsOptions(),
        (notifications) => [
          for (final notification in notifications ?? const [])
            notification.copyWith(read: true),
        ],
      );
      return previous;
    },
    onError: (error, previous) {
      if (previous != null) {
        Fuery.client.setData(notificationsOptions(), previous);
      }
    },
    onSettled: (_, __, ___) =>
        Fuery.client.invalidateQueries(queryKey: notificationsKey),
  );
}
