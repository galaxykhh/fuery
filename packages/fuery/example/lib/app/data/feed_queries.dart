import 'package:example/app/data/demo_api.dart';
import 'package:example/app/data/models.dart';
import 'package:fuery/fuery.dart';

/// Keys live next to their query, so a typo can't create a second cache
/// entry. Everything below `['posts']` is invalidated together.
const feedKey = ['posts', 'feed'];
const notificationsKey = ['notifications'];

QueryKey postKey(int id) => ['posts', 'detail', id];

QueryKey commentsKey(int postId) => ['posts', 'comments', postId];

QueryKey searchKey(String term) => ['posts', 'search', term];

QueryKey summaryKey(int postId) => ['posts', 'summary', postId];

Future<PostPage> _fetchFeed(int cursor) => DemoApi().getFeed(cursor);

/// Each query is defined once. Screens pass the definition to a widget, such
/// as `QueryBuilder(query: postQuery(id))`, which keeps one observer for it;
/// `client.query` fetches it; and mutations read and write its data with
/// `client.getData` and `client.updateData`, typed by the definition.

/// The feed, a page at a time. Every widget and cubit that uses it shares
/// one cache entry, so a like on one screen shows on the others.
///
/// `persist` stores the loaded pages with the client's storage, so a restart
/// shows the feed before the request finishes. See `main.dart`.
InfiniteQuery<PostPage, int> feedQuery() {
  return InfiniteQuery(
    queryKey: feedKey,
    queryFn: (context) => _fetchFeed(context.pageParam),
    initialPageParam: 0,
    getNextPageParam: (data) => data.lastPage.nextCursor,
    staleTime: const Duration(seconds: 30),
    persist: InfiniteQueryPersist(
      pageToJson: (page) => page.toJson(),
      pageFromJson: PostPage.fromJson,
    ),
  );
}

Future<Post> _fetchPost(int id) => DemoApi().getPost(id);

/// One post. While it loads, the feed's copy is shown as placeholder data, so
/// opening a post never shows a spinner. The feed also prefetches it with
/// `client.query` when the pointer hovers its card.
Query<Post> postQuery(int id) {
  return Query(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    placeholderData: (previous, client) {
      if (previous != null) return previous;
      final feed = client.getData(feedQuery());
      for (final page in feed?.pages ?? const <PostPage>[]) {
        for (final post in page.posts) {
          if (post.id == id) return post;
        }
      }
      return null;
    },
  );
}

/// A post that was just created. It polls until the server has published it,
/// then stops.
Query<Post> publishingPostQuery(int id) {
  return Query(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    refetchInterval: const Duration(milliseconds: 500),
    refetchWhile: (state) => state.data?.status != PostStatus.published,
  );
}

Query<List<Comment>> commentsQuery(int postId) {
  return Query(
    queryKey: commentsKey(postId),
    queryFn: (_) => DemoApi().getComments(postId),
  );
}

/// Search results for [term]. Each term is its own cache entry, and an empty
/// term doesn't fetch at all. A widget that gets the next term's definition
/// keeps its observer, so `keepPreviousData` shows the previous term's
/// results until the next ones arrive.
Query<List<Post>> searchQuery(String term) {
  return Query(
    queryKey: searchKey(term),
    queryFn: (_) => DemoApi().search(term),
    enabled: term.isNotEmpty,
    placeholderData: keepPreviousData,
    staleTime: const Duration(minutes: 1),
  );
}

/// Notifications, checked every five seconds while the app is in the
/// foreground. The badge in the navigation bar and the notifications screen
/// share this query.
Query<List<FeedNotification>> notificationsQuery() {
  return Query(
    queryKey: notificationsKey,
    queryFn: (_) => DemoApi().getNotifications(),
    refetchInterval: const Duration(seconds: 5),
    refetchIntervalInBackground: false,
  );
}

/// Folds a stream of words into the query's data, so the summary grows while
/// it arrives and stays cached afterwards.
Query<String> summaryQuery(int postId) {
  return Query(
    queryKey: summaryKey(postId),
    queryFn: streamedQuery(
      stream: (context) => DemoApi().summarize(postId),
      initialValue: '',
      combine: (summary, word) => summary.isEmpty ? word : '$summary $word',
    ),
    staleTime: infiniteDuration,
  );
}
