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

/// The feed, a page at a time. Every widget and cubit that calls this shares
/// one cache entry, so a like on one screen shows on the others.
///
/// `persist` stores the loaded pages with the client's storage, so a restart
/// shows the feed before the request finishes. See `main.dart`.
InfiniteQueryObserver<PostPage, int> feedQuery() {
  return InfiniteQuery.use(
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
/// opening a post never shows a spinner.
QueryObserver<Post> postQuery(int id) {
  return Query.use(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    placeholderData: (previous) {
      if (previous != null) return previous;
      final feed = Fuery.client.getQueryData<InfiniteData<PostPage, int>>(
        feedKey,
      );
      for (final page in feed?.pages ?? const <PostPage>[]) {
        for (final post in page.posts) {
          if (post.id == id) return post;
        }
      }
      return null;
    },
  );
}

/// The same key and function as [postQuery], for fetching outside widgets
/// with `client.query`. The feed prefetches a post when the pointer hovers
/// its card.
QueryOptions<Post> postOptions(int id) {
  return QueryOptions(queryKey: postKey(id), queryFn: (_) => _fetchPost(id));
}

/// A post that was just created. It polls until the server has published it,
/// then stops.
QueryObserver<Post> publishingPostQuery(int id) {
  return Query.use(
    queryKey: postKey(id),
    queryFn: (_) => _fetchPost(id),
    refetchInterval: const Duration(milliseconds: 500),
    refetchWhile: (state) => state.data?.status != PostStatus.published,
  );
}

QueryObserver<List<Comment>> commentsQuery(int postId) {
  return Query.use(
    queryKey: commentsKey(postId),
    queryFn: (_) => DemoApi().getComments(postId),
  );
}

/// Search results for [term]. Each term is its own cache entry, and an empty
/// term doesn't fetch at all.
///
/// One observer follows the typing: pass [searchOptions] to its `setOptions`
/// so `placeholderData` can keep the previous term's results on screen. A new
/// observer per term would have nothing to keep.
QueryObserver<List<Post>> searchQuery(String term) {
  return Query.use(
    queryKey: searchKey(term),
    queryFn: (_) => DemoApi().search(term),
    enabled: term.isNotEmpty,
    placeholderData: keepPreviousData,
    staleTime: const Duration(minutes: 1),
  );
}

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
QueryObserver<List<FeedNotification>> notificationsQuery() {
  return Query.use(
    queryKey: notificationsKey,
    queryFn: (_) => DemoApi().getNotifications(),
    refetchInterval: const Duration(seconds: 5),
    refetchIntervalInBackground: false,
  );
}

/// Folds a stream of words into the query's data, so the summary grows while
/// it arrives and stays cached afterwards.
QueryObserver<String> summaryQuery(int postId) {
  return Query.use(
    queryKey: summaryKey(postId),
    queryFn: streamedQuery(
      stream: (context) => DemoApi().summarize(postId),
      initialValue: '',
      combine: (summary, word) => summary.isEmpty ? word : '$summary $word',
    ),
    staleTime: infiniteDuration,
  );
}
