import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late QueryClient client;

  setUp(() {
    resetManagers();
    client = QueryClient()..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  QueryObserver<T> observe<T extends Object>(
    QueryKey key,
    QueryFn<T> queryFn, {
    Duration? staleTime,
    Duration? gcTime,
    bool? enabled,
    RetryPolicy? retry = const RetryPolicy.never(),
    RetryDelay? retryDelay,
    Duration? refetchInterval,
    T? initialData,
    PlaceholderDataFn<T>? placeholderData,
  }) {
    return QueryObserver<T>(
      client,
      Query<T>(
        queryKey: key,
        queryFn: queryFn,
        staleTime: staleTime,
        gcTime: gcTime,
        enabled: enabled,
        retry: retry,
        retryDelay: retryDelay,
        refetchInterval: refetchInterval,
        initialData: initialData,
        placeholderData: placeholderData,
      ),
    );
  }

  fakeTest('fetches on first subscribe and reports each state', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(['a'], fetcher.call);

    expect(observer.result.isPending, isTrue);
    expect(observer.result.fetchStatus, FetchStatus.idle);
    expect(fetcher.calls, 0);

    observer.subscribe((_) {});
    expect(observer.result.isLoading, isTrue);

    async.elapse(ms10);
    expect(fetcher.calls, 1);
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.data, 'data');
    expect(observer.result.fetchStatus, FetchStatus.idle);
    expect(observer.result.isFetchedAfterMount, isTrue);
  });

  fakeTest('does not refetch fresh data for a new observer', (async) {
    final fetcher = FakeFetcher(() => 'data');
    const staleTime = Duration(minutes: 1);

    observe(['a'], fetcher.call, staleTime: staleTime).subscribe((_) {});
    async.elapse(ms10);

    final second = observe(['a'], fetcher.call, staleTime: staleTime);
    second.subscribe((_) {});
    async.elapse(ms10);
    expect(fetcher.calls, 1);
    expect(second.result.data, 'data');

    async.elapse(staleTime);
    observe(['a'], fetcher.call, staleTime: staleTime).subscribe((_) {});
    async.elapse(ms10);
    expect(fetcher.calls, 2);
  });

  fakeTest('each observer keeps its own staleTime', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final fresh = observe(['a'], fetcher.call, staleTime: infiniteDuration);
    final stale = observe(['a'], fetcher.call, staleTime: Duration.zero);

    fresh.subscribe((_) {});
    stale.subscribe((_) {});
    async.elapse(ms10);

    expect(fresh.result.isStale, isFalse);
    expect(stale.result.isStale, isTrue);
  });

  fakeTest('can subscribe again after the last listener leaves', (async) {
    final fetcher = FakeFetcher(() => 'first');
    final observer = observe(['a'], fetcher.call, staleTime: infiniteDuration);

    final unsubscribe = observer.subscribe((_) {});
    async.elapse(ms10);
    unsubscribe();

    client.setQueryData(['a'], 'second');

    final results = <QueryResult<String>>[];
    final subscription = observer.stream.listen(results.add);
    async.flushMicrotasks();

    expect(results.last.data, 'second');

    client.setQueryData(['a'], 'third');
    async.flushMicrotasks();
    expect(results.last.data, 'third');
    subscription.cancel();
  });

  fakeTest('reattaches to the cache after its query was garbage collected',
      (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(
      ['a'],
      fetcher.call,
      staleTime: infiniteDuration,
      gcTime: const Duration(minutes: 1),
    );

    // Created long before anything listens, like a State field.
    async.elapse(const Duration(minutes: 2));
    expect(client.queryCache.getAll(), isEmpty);

    observer.subscribe((_) {});
    async.elapse(ms10);
    expect(observer.result.data, 'data');

    client.setQueryData(['a'], 'updated');
    expect(observer.result.data, 'updated');
    expect(client.queryCache.getAll().single.observersCount, 1);
  });

  fakeTest('reattaches after being unsubscribed longer than gcTime', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(
      ['a'],
      fetcher.call,
      staleTime: infiniteDuration,
      gcTime: const Duration(minutes: 1),
    );
    final unsubscribe = observer.subscribe((_) {});
    async.elapse(ms10);
    unsubscribe();
    async.elapse(const Duration(minutes: 2));

    expect(observer.getOptimisticResult().isLoading, isTrue);
    observer.subscribe((_) {});
    async.elapse(ms10);
    expect(fetcher.calls, 2);

    client.setQueryData(['a'], 'updated');
    expect(observer.result.data, 'updated');
  });

  fakeTest('removes unused queries after gcTime', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(
      ['a'],
      fetcher.call,
      gcTime: const Duration(minutes: 1),
    );

    final unsubscribe = observer.subscribe((_) {});
    async.elapse(ms10);
    unsubscribe();

    async.elapse(const Duration(seconds: 59));
    expect(client.getQueryData<String>(['a']), 'data');

    async.elapse(const Duration(seconds: 2));
    expect(client.getQueryData<String>(['a']), isNull);
    expect(client.queryCache.getAll(), isEmpty);
  });

  fakeTest('keeps a query while it has observers', (async) {
    final observer = observe(
      ['a'],
      FakeFetcher(() => 'data').call,
      gcTime: const Duration(minutes: 1),
    );
    observer.subscribe((_) {});

    async.elapse(const Duration(minutes: 10));
    expect(client.getQueryData<String>(['a']), 'data');
  });

  fakeTest('retries with the retry delay, then reports the error', (async) {
    final fetcher = FakeFetcher(() => 'data')..error = StateError('boom');
    final observer = observe(
      ['a'],
      fetcher.call,
      retry: const RetryPolicy.count(2),
      retryDelay: (_, __) => const Duration(milliseconds: 100),
    );
    observer.subscribe((_) {});

    async.elapse(ms10);
    expect(observer.result.failureCount, 1);
    expect(observer.result.isPending, isTrue);
    expect(observer.result.isFetching, isTrue);

    async.elapse(const Duration(milliseconds: 110));
    expect(observer.result.failureCount, 2);

    async.elapse(const Duration(milliseconds: 110));
    expect(fetcher.calls, 3);
    expect(observer.result.isError, isTrue);
    expect(observer.result.isLoadingError, isTrue);
    expect(observer.result.error, isA<StateError>());
    expect(observer.result.failureCount, 3);
  });

  fakeTest('keeps data when a refetch fails', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(['a'], fetcher.call);
    observer.subscribe((_) {});
    async.elapse(ms10);

    fetcher.error = StateError('boom');
    observer.refetch();
    expect(observer.result.isRefetching, isTrue);
    async.elapse(ms10);

    expect(observer.result.isError, isTrue);
    expect(observer.result.isRefetchError, isTrue);
    expect(observer.result.data, 'data');
  });

  fakeTest('recovers from an error on refetch', (async) {
    final fetcher = FakeFetcher(() => 'data')..error = StateError('boom');
    final observer = observe(['a'], fetcher.call);
    observer.subscribe((_) {});
    async.elapse(ms10);
    expect(observer.result.isError, isTrue);

    fetcher.error = null;
    observer.refetch();
    async.elapse(ms10);
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.error, isNull);
  });

  fakeTest('does not fetch while disabled', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(['a'], fetcher.call, enabled: false);
    observer.subscribe((_) {});
    async.elapse(ms10);

    expect(fetcher.calls, 0);
    expect(observer.result.isPending, isTrue);
    expect(observer.result.fetchStatus, FetchStatus.idle);

    observer.setOptions(Query(
      queryKey: ['a'],
      queryFn: fetcher.call,
      enabled: true,
    ));
    async.elapse(ms10);
    expect(fetcher.calls, 1);
    expect(observer.result.data, 'data');
  });

  fakeTest('shows previous data as placeholder while the key changes', (async) {
    var page = 1;
    final fetcher = FakeFetcher(() => 'page $page');
    final observer = observe(
      ['todos', 1],
      fetcher.call,
      placeholderData: (previous, client) => previous,
    );
    observer.subscribe((_) {});
    async.elapse(ms10);

    page = 2;
    observer.setOptions(Query(
      queryKey: ['todos', 2],
      queryFn: fetcher.call,
      placeholderData: keepPreviousData,
      retry: const RetryPolicy.never(),
    ));

    expect(observer.result.data, 'page 1');
    expect(observer.result.isPlaceholderData, isTrue);
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.isFetching, isTrue);

    async.elapse(ms10);
    expect(observer.result.data, 'page 2');
    expect(observer.result.isPlaceholderData, isFalse);
  });

  fakeTest('polls with refetchInterval while subscribed', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(
      ['a'],
      fetcher.call,
      refetchInterval: const Duration(seconds: 1),
    );

    final unsubscribe = observer.subscribe((_) {});
    async.elapse(const Duration(milliseconds: 3500));
    expect(fetcher.calls, 4);

    unsubscribe();
    async.elapse(const Duration(seconds: 5));
    expect(fetcher.calls, 4);
  });

  fakeTest('polls only while refetchWhile returns true', (async) {
    var status = 'running';
    final fetcher = FakeFetcher(() => status);
    final observer = Query(
      queryKey: ['job'],
      queryFn: fetcher.call,
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => state.data != 'done',
      retry: const RetryPolicy.never(),
    ).observe(client: client);

    observer.subscribe((_) {});
    async.elapse(const Duration(milliseconds: 2500));
    expect(fetcher.calls, 3);

    status = 'done';
    async.elapse(const Duration(seconds: 1));
    expect(fetcher.calls, 4);
    async.elapse(const Duration(seconds: 5));
    expect(fetcher.calls, 4);

    // Polling resumes once the condition is true again.
    status = 'running';
    observer.refetch();
    async.elapse(ms10);
    expect(fetcher.calls, 5);
    async.elapse(const Duration(seconds: 2));
    expect(fetcher.calls, 6);
  });

  fakeTest('refetches stale queries when the app regains focus', (async) {
    final stale = FakeFetcher(() => 'stale');
    final fresh = FakeFetcher(() => 'fresh');
    observe(['stale'], stale.call).subscribe((_) {});
    observe(['fresh'], fresh.call, staleTime: infiniteDuration)
        .subscribe((_) {});
    async.elapse(ms10);

    focusManager.setFocused(false);
    focusManager.setFocused(true);
    async.elapse(ms10);

    expect(stale.calls, 2);
    expect(fresh.calls, 1);
  });

  fakeTest('pauses while offline and fetches on reconnect', (async) {
    onlineManager.setOnline(false);
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(['a'], fetcher.call);
    observer.subscribe((_) {});
    async.elapse(ms10);

    expect(fetcher.calls, 0);
    expect(observer.result.isPaused, isTrue);
    expect(observer.result.isPending, isTrue);

    onlineManager.setOnline(true);
    async.elapse(ms10);
    expect(fetcher.calls, 1);
    expect(observer.result.data, 'data');
  });

  fakeTest('treats initialData as cached data', (async) {
    final fetcher = FakeFetcher(() => 'fetched');
    final observer = observe(
      ['a'],
      fetcher.call,
      initialData: 'initial',
      staleTime: const Duration(minutes: 1),
    );
    observer.subscribe((_) {});
    async.elapse(ms10);

    expect(fetcher.calls, 0);
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.data, 'initial');
  });

  fakeTest('stream sends the current result first, then changes', (async) {
    final observer = observe(['a'], FakeFetcher(() => 'data').call);
    final results = <QueryResult<String>>[];
    observer.stream.listen(results.add);
    async.elapse(ms10);

    expect(results.map((r) => (r.status, r.fetchStatus)), [
      (QueryStatus.pending, FetchStatus.fetching),
      (QueryStatus.success, FetchStatus.idle),
    ]);
  });

  fakeTest('stream is shared by several listeners', (async) {
    final fetcher = FakeFetcher(() => 'data');
    final observer = observe(['a'], fetcher.call);
    final first = <QueryResult<String>>[];
    final second = <QueryResult<String>>[];
    observer.stream.listen(first.add);
    observer.stream.listen(second.add);
    async.elapse(ms10);

    expect(fetcher.calls, 1);
    expect(first.last.data, 'data');
    expect(second.last.data, 'data');
  });

  fakeTest('reuses the previous data instance when data is equal', (async) {
    final observer = observe(['a'], (_) async => [1, 2, 3]);
    observer.subscribe((_) {});
    async.elapse(ms10);
    final before = observer.result.data;

    observer.refetch();
    async.elapse(ms10);
    expect(identical(observer.result.data, before), isTrue);
  });

  fakeTest('aborts a cancellable fetch when the last observer leaves', (async) {
    late AbortSignal signal;
    final observer = observe<String>(['a'], (context) async {
      signal = context.signal;
      await Future<void>.delayed(const Duration(seconds: 1));
      return 'data';
    });

    final unsubscribe = observer.subscribe((_) {});
    async.elapse(ms10);
    unsubscribe();
    async.elapse(const Duration(seconds: 1));

    expect(signal.aborted, isTrue);
    final state = client.getQueryState(['a'])!;
    expect(state.status, QueryStatus.pending);
    expect(state.fetchStatus, FetchStatus.idle);
    expect(state.data, isNull);
  });

  fakeTest('lets a non-cancellable fetch finish after unsubscribe', (async) {
    final observer = observe(['a'], FakeFetcher(() => 'data').call);
    final unsubscribe = observer.subscribe((_) {});
    unsubscribe();
    async.elapse(ms10);

    expect(client.getQueryData<String>(['a']), 'data');
  });

  fakeTest('refetch while fetching restarts the fetch', (async) {
    var value = 'first';
    final fetcher = FakeFetcher(() => value);
    final observer = observe(['a'], fetcher.call);
    observer.subscribe((_) {});
    async.elapse(ms10);

    value = 'second';
    observer.refetch();
    value = 'third';
    observer.refetch();
    async.elapse(ms10);

    expect(fetcher.calls, 3);
    expect(observer.result.data, 'third');
  });

  fakeTest('getOptimisticResult reports the fetch that mount will start',
      (async) {
    final observer = observe(['a'], FakeFetcher(() => 'data').call);
    final optimistic = observer.getOptimisticResult();

    expect(optimistic.isLoading, isTrue);
  });

  group('edge cases', () {
    fakeTest('stops retrying when the last observer unsubscribes', (async) {
      final fetcher = FakeFetcher(() => 'data')..error = StateError('boom');
      final observer = observe(
        ['a'],
        fetcher.call,
        retry: const RetryPolicy.count(3),
        retryDelay: (_, __) => const Duration(milliseconds: 100),
      );
      final unsubscribe = observer.subscribe((_) {});
      async.elapse(ms10);
      expect(observer.result.failureCount, 1);

      unsubscribe();
      async.elapse(const Duration(seconds: 1));

      expect(fetcher.calls, 1);
      expect(client.getQueryState(['a'])!.status, QueryStatus.error);
    });

    fakeTest('cancels a paused first fetch when the last observer leaves',
        (async) {
      onlineManager.setOnline(false);
      final fetcher = FakeFetcher(() => 'data');
      final unsubscribe = observe(['a'], fetcher.call).subscribe((_) {});
      async.flushMicrotasks();
      expect(client.getQueryState(['a'])!.fetchStatus, FetchStatus.paused);

      unsubscribe();
      expect(client.getQueryState(['a'])!.fetchStatus, FetchStatus.idle);

      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(fetcher.calls, 0);
    });

    fakeTest('retryOnMount: false keeps a failed query as it is', (async) {
      final fetcher = FakeFetcher(() => 'data')..error = StateError('boom');
      final unsubscribe = observe(['a'], fetcher.call).subscribe((_) {});
      async.elapse(ms10);
      unsubscribe();

      final observer = QueryObserver<String>(
        client,
        Query(
          queryKey: ['a'],
          queryFn: fetcher.call,
          retryOnMount: false,
          retry: const RetryPolicy.never(),
        ),
      );
      observer.subscribe((_) {});
      async.elapse(ms10);

      expect(fetcher.calls, 1);
      expect(observer.result.isError, isTrue);
    });

    fakeTest('goes stale when staleTime is shortened', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer = observe(
        ['a'],
        fetcher.call,
        staleTime: const Duration(minutes: 1),
      );
      observer.subscribe((_) {});
      async.elapse(ms10);
      expect(observer.result.isStale, isFalse);

      observer.setOptions(Query(
        queryKey: ['a'],
        queryFn: fetcher.call,
        staleTime: const Duration(seconds: 1),
      ));
      // Data arrived at 10ms, so it goes stale at 1010ms.
      async.elapse(const Duration(milliseconds: 990));
      expect(observer.result.isStale, isFalse);
      async.elapse(const Duration(milliseconds: 20));
      expect(observer.result.isStale, isTrue);
    });

    fakeTest('stops polling when refetchInterval is removed', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer = observe(
        ['a'],
        fetcher.call,
        refetchInterval: const Duration(seconds: 1),
      );
      observer.subscribe((_) {});
      async.elapse(const Duration(milliseconds: 1500));
      expect(fetcher.calls, 2);

      observer.setOptions(Query(queryKey: ['a'], queryFn: fetcher.call));
      async.elapse(const Duration(seconds: 5));
      expect(fetcher.calls, 2);
    });

    fakeTest('getOptimisticResult while mounted matches the result', (async) {
      final observer = observe(['a'], FakeFetcher(() => 'data').call);
      observer.subscribe((_) {});
      async.elapse(ms10);

      expect(observer.getOptimisticResult(), observer.result);
    });

    fakeTest('initialData from a later observer fills an empty query', (async) {
      final fetcher = FakeFetcher(() => 'fetched');
      observe(['a'], fetcher.call, enabled: false).subscribe((_) {});
      final observer = observe(
        ['a'],
        fetcher.call,
        initialData: 'initial',
        staleTime: const Duration(minutes: 1),
      );
      observer.subscribe((_) {});
      async.elapse(ms10);

      expect(observer.result.data, 'initial');
      expect(fetcher.calls, 0);
    });

    fakeTest('a plain cancel reports a CancelledError', (async) {
      final observer = observe(['a'], FakeFetcher(() => 'data').call);
      observer.subscribe((_) {});
      client.cancelQueries(queryKey: ['a'], revert: false);
      async.elapse(ms10);

      expect(observer.result.isError, isTrue);
      expect(observer.result.error, isA<CancelledError>());
    });

    fakeTest('exposes the query, its fetch, and its observers', (async) {
      final observer = observe(['a'], FakeFetcher(() => 'data').call);
      final query = observer.currentQuery;
      expect(query.isDisabled, isTrue);
      expect(query.isStale, isTrue);

      observer.subscribe((_) {});
      expect(query.future, isNotNull);
      expect(query.observers, [observer]);
      expect(query.toString(), 'CachedQuery(["a"], pending)');

      async.elapse(ms10);
      expect(query.future, isNull);
      expect(query.isStale, isTrue);
    });

    fakeTest('keeps its observers in the order they subscribed', (async) {
      final fetches = <String>[];
      final heard = <String>[];
      QueryObserver<String> observer(String name) {
        final observer = Query(
          queryKey: ['a'],
          queryFn: (_) async {
            fetches.add(name);
            return name;
          },
        ).observe(client: client);
        return observer;
      }

      final first = observer('first');
      final second = observer('second');
      final stopFirst = first.subscribe((_) => heard.add('first'));
      second.subscribe((_) => heard.add('second'));
      async.flushMicrotasks();
      final query = first.currentQuery;
      expect(query.observers, [first, second]);

      // A refetch uses the options of the first observer, and every change
      // reaches the observers in order.
      fetches.clear();
      heard.clear();
      client.invalidateQueries(queryKey: ['a']);
      async.flushMicrotasks();
      expect(fetches, ['first']);
      expect(heard, ['first', 'second', 'first', 'second']);

      // One that subscribes again comes last.
      stopFirst();
      first.subscribe((_) => heard.add('first'));
      expect(query.observers, [second, first]);
      async.flushMicrotasks();
      fetches.clear();
      heard.clear();
      client.invalidateQueries(queryKey: ['a']);
      async.flushMicrotasks();
      expect(fetches, ['second']);
      expect(heard, ['second', 'first', 'second', 'first']);
      expect(query.observersCount, 2);
    });
  });

  group('staticStaleTime', () {
    fakeTest('is never stale and never refetched automatically', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer = QueryObserver<String>(
        client,
        Query(
          queryKey: ['a'],
          queryFn: fetcher.call,
          staleTime: staticStaleTime,
          refetchOnFocus: RefetchMode.always,
          refetchOnMount: RefetchMode.always,
        ),
      );
      observer.subscribe((_) {});
      async.elapse(ms10);

      client.invalidateQueries(queryKey: ['a']);
      client.refetchQueries();
      focusManager.setFocused(false);
      focusManager.setFocused(true);
      observe(['a'], fetcher.call, staleTime: staticStaleTime)
          .subscribe((_) {});
      async.elapse(const Duration(minutes: 10));

      expect(fetcher.calls, 1);
      expect(observer.result.isStale, isFalse);
      expect(observer.currentQuery.isStatic, isTrue);
    });

    fakeTest('can still be refetched by hand', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer = observe(
        ['a'],
        fetcher.call,
        staleTime: staticStaleTime,
      );
      observer.subscribe((_) {});
      async.elapse(ms10);

      observer.refetch();
      async.elapse(ms10);
      expect(fetcher.calls, 2);
    });
  });
}
