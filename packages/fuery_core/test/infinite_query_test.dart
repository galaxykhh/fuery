import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late QueryClient client;

  setUp(() {
    resetManagers();
    client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    )..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  /// A paged source with pages 1 to [lastPage]. Page `n` contains `'<n>'`.
  InfiniteQueryObserver<String, int> observe({
    int lastPage = 3,
    int initialPage = 1,
    int? maxPages,
    String Function(int page)? render,
    List<int>? calls,
    Set<int>? failing,
  }) {
    return InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async {
        calls?.add(context.pageParam);
        await Future<void>.delayed(ms10);
        if (failing?.contains(context.pageParam) ?? false) {
          throw StateError('page ${context.pageParam} failed');
        }
        return (render ?? (p) => '$p')(context.pageParam);
      },
      initialPageParam: initialPage,
      getNextPageParam: (data) =>
          data.lastPageParam < lastPage ? data.lastPageParam + 1 : null,
      getPreviousPageParam: (data) =>
          data.firstPageParam > 1 ? data.firstPageParam - 1 : null,
      maxPages: maxPages,
    ).observe(client: client);
  }

  fakeTest('fetches the first page, then more on demand', (async) {
    final observer = observe();
    observer.subscribe((_) {});
    async.elapse(ms10);

    expect(observer.result.pages, ['1']);
    expect(observer.result.data!.pageParams, [1]);
    expect(observer.result.hasNextPage, isTrue);

    observer.fetchNextPage();
    expect(observer.result.isFetchingNextPage, isTrue);
    expect(observer.result.isRefetching, isFalse);
    async.elapse(ms10);

    expect(observer.result.pages, ['1', '2']);
    expect(observer.result.isFetchingNextPage, isFalse);

    observer.fetchNextPage();
    async.elapse(ms10);
    expect(observer.result.pages, ['1', '2', '3']);
    expect(observer.result.hasNextPage, isFalse);
  });

  fakeTest('polls only while refetchWhile returns true', (async) {
    var status = 'running';
    var calls = 0;
    final observer = InfiniteQuery(
      queryKey: ['job'],
      queryFn: (context) async {
        calls++;
        await Future<void>.delayed(ms10);
        return status;
      },
      initialPageParam: 1,
      getNextPageParam: (data) => null,
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => !state.pages.contains('done'),
    ).observe(client: client);

    observer.subscribe((_) {});
    async.elapse(const Duration(milliseconds: 1500));
    expect(calls, 2);

    status = 'done';
    async.elapse(const Duration(seconds: 1));
    expect(calls, 3);
    async.elapse(const Duration(seconds: 5));
    expect(calls, 3);
  });

  fakeTest('fetches the previous page before the first one', (async) {
    final observer = observe(initialPage: 3);
    observer.subscribe((_) {});
    async.elapse(ms10);
    expect(observer.result.hasPreviousPage, isTrue);

    observer.fetchPreviousPage();
    expect(observer.result.isFetchingPreviousPage, isTrue);
    async.elapse(ms10);
    expect(observer.result.pages, ['2', '3']);

    observer.fetchPreviousPage();
    async.elapse(ms10);
    expect(observer.result.pages, ['1', '2', '3']);
    expect(observer.result.hasPreviousPage, isFalse);
  });

  fakeTest('refetch reloads every loaded page in order', (async) {
    var version = 1;
    final calls = <int>[];
    final observer = observe(render: (p) => 'v$version-$p', calls: calls);
    observer.subscribe((_) {});
    async.elapse(ms10);
    observer.fetchNextPage();
    async.elapse(ms10);

    version = 2;
    calls.clear();
    observer.refetch();
    expect(observer.result.isRefetching, isTrue);
    async.elapse(const Duration(milliseconds: 20));

    expect(calls, [1, 2]);
    expect(observer.result.pages, ['v2-1', 'v2-2']);
  });

  fakeTest('a failed next page keeps loaded pages and can be retried', (async) {
    final failing = {2};
    final observer = observe(failing: failing);
    observer.subscribe((_) {});
    async.elapse(ms10);

    observer.fetchNextPage();
    async.elapse(ms10);
    expect(observer.result.isFetchNextPageError, isTrue);
    expect(observer.result.isRefetchError, isFalse);
    expect(observer.result.pages, ['1']);

    failing.clear();
    observer.fetchNextPage();
    async.elapse(ms10);
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.pages, ['1', '2']);
  });

  fakeTest('maxPages drops pages from the other end', (async) {
    final observer = observe(lastPage: 5, maxPages: 2);
    observer.subscribe((_) {});
    async.elapse(ms10);
    observer.fetchNextPage();
    async.elapse(ms10);
    observer.fetchNextPage();
    async.elapse(ms10);

    expect(observer.result.pages, ['2', '3']);
    expect(observer.result.data!.pageParams, [2, 3]);
  });

  fakeTest('stream reports infinite results', (async) {
    final observer = observe();
    final results = <InfiniteQueryResult<String, int>>[];
    observer.stream.listen(results.add);
    async.elapse(ms10);

    expect(results.last.pages, ['1']);
    expect(results.last.hasNextPage, isTrue);
  });

  fakeTest('infiniteQuery fetches the given number of pages', (async) {
    InfiniteData<String, int>? data;
    client
        .infiniteQuery(InfiniteQuery(
          queryKey: ['pages'],
          queryFn: (context) async => '${context.pageParam}',
          initialPageParam: 1,
          getNextPageParam: (data) => data.lastPageParam + 1,
          pages: 3,
        ))
        .then((value) => data = value);
    async.flushMicrotasks();

    expect(data!.pages, ['1', '2', '3']);
  });

  fakeTest('maxPages drops pages from the end when going backward', (async) {
    final observer = observe(initialPage: 3, maxPages: 2);
    observer.subscribe((_) {});
    async.elapse(ms10);
    observer.fetchPreviousPage();
    async.elapse(ms10);
    observer.fetchPreviousPage();
    async.elapse(ms10);

    expect(observer.result.pages, ['1', '2']);
  });

  fakeTest('a failed previous page is not a refetch error', (async) {
    final observer = observe(initialPage: 2, failing: {1});
    observer.subscribe((_) {});
    async.elapse(ms10);
    observer.fetchPreviousPage();
    async.elapse(ms10);

    expect(observer.result.isFetchPreviousPageError, isTrue);
    expect(observer.result.isRefetchError, isFalse);
  });

  fakeTest('stops fetching further pages once cancelled', (async) {
    final fetched = <int>[];
    final observer = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async {
        context.signal;
        fetched.add(context.pageParam);
        await Future<void>.delayed(ms10);
        return '${context.pageParam}';
      },
      initialPageParam: 1,
      getNextPageParam: (data) => data.lastPageParam + 1,
    ).observe(client: client);
    observer.subscribe((_) {});
    async.elapse(ms10);
    observer.fetchNextPage();
    async.elapse(ms10);

    fetched.clear();
    observer.refetch();
    async.elapse(const Duration(milliseconds: 5));
    client.cancelQueries(queryKey: ['pages']);
    async.elapse(const Duration(milliseconds: 50));

    expect(fetched, [1]);
    expect(observer.result.pages, ['1', '2']);
    expect(observer.result.fetchStatus, FetchStatus.idle);
  });

  fakeTest('getOptimisticResult and results are typed', (async) {
    final observer = observe();
    final optimistic = observer.getOptimisticResult();
    expect(optimistic.isLoading, isTrue);
    expect(optimistic.pages, isEmpty);

    observer.subscribe((_) {});
    async.elapse(ms10);
    expect({observer.result, observer.getOptimisticResult()}, hasLength(1));
  });
}
