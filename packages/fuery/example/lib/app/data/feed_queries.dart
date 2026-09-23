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

int? _nextCursor(InfiniteData<PostPage, int> data) => data.lastPage.nextCursor;

/// Each query is defined once, as options. Screens observe them with
/// `observe()`, `client.query` fetches them, and mutations read and write
/// their data with `client.getData` and `client.updateData`, all with the
/// data type taken from the options.

/// The feed, a page at a time. Every observer of it shares one cache entry,
/// so a like on one screen shows on the others.
///
/// `persist` stores the loaded pages with the client's storage, so a restart
/// shows the feed before the request finishes. See `main.dart`.
InfiniteQueryOptions<PostPage, int> feedOptions() {
  return infiniteQueryOptions(
    queryKey: feedKey,
    queryFn: (context) => _fetchFeed(context.pageParam),
    initialPageParam: 0,
    getNextPageParam: _nextCursor,
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
QueryOptions<Post> postOptions(int id) {
  return QueryOptions(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    placeholderData: (previous) {
      if (previous != null) return previous;
      final feed = Fuery.client.getData(feedOptions());
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
QueryOptions<Post> publishingPostOptions(int id) {
  return QueryOptions(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    refetchInterval: const Duration(milliseconds: 500),
    refetchWhile: (state) => state.data?.status != PostStatus.published,
  );
}

QueryOptions<List<Comment>> commentsOptions(int postId) {
  return QueryOptions(
    queryKey: commentsKey(postId),
    queryFn: (_) => DemoApi().getComments(postId),
  );
}

/// Search results for [term]. Each term is its own cache entry, and an empty
/// term doesn't fetch at all.
///
/// One observer follows the typing: pass the next term's options to its
/// `setOptions`, so `placeholderData` can keep the previous term's results on
/// screen. A new observer per term would have nothing to keep.
QueryOptions<List<Post>> searchOptions(String term) {
  return QueryOptions(
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
QueryOptions<List<FeedNotification>> notificationsOptions() {
  return QueryOptions(
    queryKey: notificationsKey,
    queryFn: (_) => DemoApi().getNotifications(),
    refetchInterval: const Duration(seconds: 5),
    refetchIntervalInBackground: false,
  );
}

/// Folds a stream of words into the query's data, so the summary grows while
/// it arrives and stays cached afterwards.
QueryOptions<String> summaryOptions(int postId) {
  return QueryOptions(
    queryKey: summaryKey(postId),
    queryFn: streamedQuery(
      stream: (context) => DemoApi().summarize(postId),
      initialValue: '',
      combine: (summary, word) => summary.isEmpty ? word : '$summary $word',
    ),
    staleTime: infiniteDuration,
  );
}
