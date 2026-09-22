import 'package:example/app/data/models.dart';

/// An in-memory server with the delays and failures a real one has, so the
/// example runs anywhere, the web included.
class DemoApi {
  static const pageSize = 10;

  /// Liking this post always fails, so the feed shows a rollback.
  static const flakyPostId = 29;

  static final List<Post> _posts = _seedPosts();
  static final List<Comment> _comments = _seedComments();
  static final List<FeedNotification> _notifications = _seedNotifications();
  static final Map<int, int> _processingPolls = {};
  static int _nextPostId = 31;
  static int _nextCommentId = 100;
  static int _nextNotificationId = 10;
  static int _notificationPolls = 0;

  /// Puts the server back in its initial state, for tests.
  static void reset() {
    _posts
      ..clear()
      ..addAll(_seedPosts());
    _comments
      ..clear()
      ..addAll(_seedComments());
    _notifications
      ..clear()
      ..addAll(_seedNotifications());
    _processingPolls.clear();
    _nextPostId = 31;
    _nextCommentId = 100;
    _nextNotificationId = 10;
    _notificationPolls = 0;
  }

  /// The feed, newest first, [pageSize] posts from [cursor].
  Future<PostPage> getFeed(int cursor) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final published = [
      for (final post in _posts)
        if (post.status == PostStatus.published) post,
    ];
    final end = (cursor + pageSize).clamp(0, published.length);
    return PostPage(
      posts: published.sublist(cursor, end),
      nextCursor: end < published.length ? end : null,
    );
  }

  /// One post. A processing post is published after it is read three times,
  /// as if the server finished preparing it.
  Future<Post> getPost(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _indexOf(id);
    var post = _posts[index];
    if (post.status == PostStatus.processing) {
      final polls = (_processingPolls[id] ?? 0) + 1;
      _processingPolls[id] = polls;
      if (polls >= 3) {
        post = post.copyWith(status: PostStatus.published);
        _posts[index] = post;
      }
    }
    return post;
  }

  Future<Post> createPost(String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final post = Post(
      id: _nextPostId++,
      author: 'You',
      body: body,
      likes: 0,
      liked: false,
      commentCount: 0,
      status: PostStatus.processing,
    );
    _posts.insert(0, post);
    return post;
  }

  Future<Post> toggleLike(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (id == flakyPostId) throw Exception('Too many requests');
    final index = _indexOf(id);
    final post = _posts[index];
    final liked = !post.liked;
    _posts[index] = post.copyWith(
      liked: liked,
      likes: post.likes + (liked ? 1 : -1),
    );
    return _posts[index];
  }

  Future<List<Comment>> getComments(int postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      for (final comment in _comments)
        if (comment.postId == postId) comment,
    ];
  }

  Future<Comment> addComment(int postId, String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final comment = Comment(
      id: _nextCommentId++,
      postId: postId,
      author: 'You',
      body: body,
    );
    _comments.add(comment);
    final index = _indexOf(postId);
    _posts[index] = _posts[index].copyWith(
      commentCount: _posts[index].commentCount + 1,
    );
    return comment;
  }

  Future<List<Post>> search(String term) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final lowercase = term.toLowerCase();
    return [
      for (final post in _posts)
        if (post.status == PostStatus.published &&
            (post.body.toLowerCase().contains(lowercase) ||
                post.author.toLowerCase().contains(lowercase)))
          post,
    ];
  }

  /// Notifications, newest first. Every other read brings a new one, as if
  /// people were reacting to your posts while the app is open.
  Future<List<FeedNotification>> getNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _notificationPolls++;
    if (_notificationPolls.isEven) {
      final author = _authors[_nextNotificationId % _authors.length];
      _notifications.insert(
        0,
        FeedNotification(
          id: _nextNotificationId++,
          text: '$author liked your post',
          read: false,
        ),
      );
    }
    return [..._notifications];
  }

  Future<void> markAllRead() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
  }

  /// A summary of a thread that arrives a word at a time, like a model
  /// streaming tokens.
  Stream<String> summarize(int postId) async* {
    final count = _comments.where((c) => c.postId == postId).length;
    final words = ('$count comments so far. People agree with the post and '
            'ask for a follow-up with more detail.')
        .split(' ');
    for (final word in words) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      yield word;
    }
  }

  static int _indexOf(int id) {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index < 0) throw Exception('Post $id not found');
    return index;
  }

  static const _authors = [
    'Mina Park',
    'Jonas Weber',
    'Aisha Bello',
    'Tom Okafor',
    'Lea Fontaine',
    'Kenji Sato',
  ];

  static const _bodies = [
    'Shipped the new onboarding flow this morning. Drop-off is already down.',
    'Hot take: most loading spinners could be cached data.',
    'Reading about structural sharing and finally get why my lists rebuilt.',
    'Coffee, then code review. In that order.',
    'Our API now returns cursors instead of page numbers. So much simpler.',
    'Who else keeps their query keys next to the query function?',
    'Weekend project: a tiny CLI that reuses the app\'s data layer.',
    'Airplane mode is the best offline test environment.',
    'Turned pull-to-refresh into one line. The cache did the rest.',
    'Pagination bug of the day: fetching the same page twice on scroll.',
    'A retry with backoff saved our launch from a flaky endpoint.',
    'If a screen shows stale data while refetching, users never notice.',
    'Design review went well. Rounded corners won again.',
    'The devtools panel on a real device is a game changer for QA.',
    'Fixed the double-submit on the compose screen. Scoped mutations.',
    'Question: do you persist every query, or only the ones on the home screen?',
    'Migrated the stats widget to a cubit. Same cache, zero new requests.',
    'Streaming the AI summary word by word feels faster than it is.',
    'Prefetching on hover makes the web build feel native.',
    'Reminder to cancel the request when the screen closes.',
    'Optimistic likes with rollback, done before lunch.',
    'Long day. The tests pass on the oldest Flutter we support though.',
    'Search that keeps the old results while typing is underrated.',
    'The notification badge is a cubit over the same query as the list.',
    'Polling a job until it finishes, then stopping. refetchWhile is neat.',
    'Nothing beats a fake API with real delays for demos.',
    'Refactored three screens to share one cache entry. Deleted 200 lines.',
    'Offline comments queue up and send themselves later. Feels magical.',
    'This post fails to like on purpose, to show the rollback.',
    'First post on the new feed. Hello, everyone!',
  ];

  static List<Post> _seedPosts() => [
        // Newest first: post 30 is the top of the feed.
        for (var i = 30; i >= 1; i--)
          Post(
            id: i,
            author: _authors[i % _authors.length],
            body: _bodies[i - 1],
            likes: (i * 7) % 40,
            liked: i % 5 == 0,
            commentCount: i == 30 ? 3 : i % 4,
            status: PostStatus.published,
          ),
      ];

  static List<Comment> _seedComments() => [
        const Comment(id: 1, postId: 30, author: 'Mina Park', body: 'Welcome!'),
        const Comment(
          id: 2,
          postId: 30,
          author: 'Jonas Weber',
          body: 'Looking forward to more posts.',
        ),
        const Comment(
          id: 3,
          postId: 30,
          author: 'Aisha Bello',
          body: 'Can you share the onboarding numbers?',
        ),
        const Comment(
          id: 4,
          postId: 29,
          author: 'Tom Okafor',
          body: 'Nice demo of a failed request.',
        ),
      ];

  static List<FeedNotification> _seedNotifications() => [
        const FeedNotification(
          id: 3,
          text: 'Aisha Bello commented on your post',
          read: false,
        ),
        const FeedNotification(
          id: 2,
          text: 'Jonas Weber liked your post',
          read: false,
        ),
        const FeedNotification(
          id: 1,
          text: 'Mina Park started following you',
          read: true,
        ),
      ];
}
