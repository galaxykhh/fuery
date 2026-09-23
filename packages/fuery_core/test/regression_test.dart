// Regression tests for cache, refetch, and mutation edge cases.
import 'package:fake_async/fake_async.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class Item {
  const Item(this.id, this.name);
  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Item && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

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

  fakeTest('client.query keeps its retry default out of later refetches',
      (async) {
    var attempts = 0;
    Future<String> fetch(QueryFunctionContext _) async {
      attempts++;
      throw StateError('down');
    }

    final observer = Query.observe(
      queryKey: ['a'],
      queryFn: fetch,
      retryDelay: (_, __) => ms10,
      client: client,
    );
    final unsubscribe = observer.subscribe((_) {});
    async.elapse(const Duration(seconds: 1));
    client.query(QueryOptions(queryKey: ['a'], queryFn: fetch)).ignore();
    async.elapse(const Duration(seconds: 1));

    attempts = 0;
    client.invalidateQueries(queryKey: ['a']);
    async.elapse(const Duration(seconds: 1));
    expect(attempts, 4);
    unsubscribe();
  });

  fakeTest('resetting an unused query still garbage collects it', (async) {
    client.setQueryData(['a'], 'a');
    client.resetQueries(queryKey: ['a']);
    async.elapse(const Duration(minutes: 6));
    expect(client.getQueryState(['a']), isNull);
  });

  group('removing queries', () {
    fakeTest('observers follow their key after clear()', (async) {
      var user = 'alice';
      final me = Query.observe(
        queryKey: ['me'],
        queryFn: (_) async => user,
        client: client,
      );
      me.subscribe((_) {});
      async.flushMicrotasks();
      expect(me.result.data, 'alice');

      // Log out and in as someone else.
      user = 'bob';
      client.clear();
      expect(me.result.isLoading, isTrue);
      async.flushMicrotasks();
      expect(me.result.data, 'bob');

      client.setQueryData(['me'], 'carol');
      async.flushMicrotasks();
      expect(me.result.data, 'carol');
    });

    fakeTest('invalidating and focus reach observers after removeQueries',
        (async) {
      final fetcher = FakeFetcher(() => 'me');
      Query.observe(queryKey: ['me'], queryFn: fetcher.call, client: client)
          .subscribe((_) {});
      async.elapse(ms10);

      client.removeQueries(queryKey: ['me']);
      async.elapse(ms10);
      expect(fetcher.calls, 2);

      client.invalidateQueries(queryKey: ['me']);
      async.elapse(ms10);
      expect(fetcher.calls, 3);
    });
  });

  group('cancelling', () {
    fakeTest('a cancelled fetch leaves the fetch that replaced it alone',
        (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer =
          Query.observe(queryKey: ['a'], queryFn: fetcher.call, client: client);
      observer.subscribe((_) {});
      async.elapse(ms10);

      observer.refetch();
      async.flushMicrotasks();
      client.cancelQueries(queryKey: ['a'], revert: false);
      observer.refetch();
      async.flushMicrotasks();
      expect(observer.result.isFetching, isTrue);

      observer.refetch(cancelRefetch: false);
      async.elapse(ms10);
      expect(fetcher.calls, 3);
      expect(observer.result.data, 'data');
    });

    fakeTest('a write right after cancelQueries(revert: false) stays', (async) {
      final errors = <Object>[];
      final reporting = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(onError: (error, _) => errors.add(error)),
        ),
      );
      final todos = Query.observe(
        queryKey: ['todos'],
        queryFn: FakeFetcher(() => ['a']).call,
        client: reporting,
      );
      todos.subscribe((_) {});
      async.elapse(ms10);
      todos.refetch();
      async.flushMicrotasks();

      reporting.cancelQueries(queryKey: ['todos'], revert: false);
      reporting.setQueryData(['todos'], ['a', 'b']);
      async.elapse(ms10);

      expect(todos.result.data, ['a', 'b']);
      expect(todos.result.isError, isFalse);
      expect(errors, isEmpty, reason: 'cancelling is not an error to report');
      reporting.clear();
    });

    fakeTest('cancelQueries(silent: true) ends the fetch', (async) {
      final observer = Query.observe(
        queryKey: ['a'],
        queryFn: FakeFetcher(() => 'data').call,
        client: client,
      );
      final unsubscribe = observer.subscribe((_) {});
      async.elapse(ms10);
      observer.refetch();
      async.flushMicrotasks();

      client.cancelQueries(queryKey: ['a'], revert: false, silent: true);
      async.flushMicrotasks();
      expect(observer.result.isFetching, isFalse);
      expect(client.isFetching(), 0);

      unsubscribe();
      async.elapse(const Duration(minutes: 10));
      expect(client.getQueryState(['a']), isNull);
    });
  });

  group('retry timers', () {
    fakeTest('clear() cancels a query waiting to retry', (async) {
      final observer = Query.observe(
        queryKey: ['a'],
        queryFn: (_) async => throw StateError('boom'),
        retryDelay: (_, __) => const Duration(seconds: 30),
        client: client,
      );
      final unsubscribe = observer.subscribe((_) {});
      async.flushMicrotasks();
      expect(observer.result.failureCount, 1);

      unsubscribe();
      client.clear();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });

    fakeTest('clear() stops a mutation waiting to retry', (async) {
      final mutation = Mutation.observe(
        mutationFn: (int x) async => throw StateError('boom'),
        retry: const RetryPolicy.count(1),
        retryDelay: (_, __) => const Duration(seconds: 30),
        client: client,
      );
      Object? error;
      mutation.mutateAsync(1).then((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();

      client.clear();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
      expect(error, isA<StateError>());
    });
  });

  fakeTest('resetQueries refetches an active static query', (async) {
    var calls = 0;
    final config = Query.observe(
      queryKey: ['config'],
      queryFn: (_) async => 'config ${++calls}',
      staleTime: staticStaleTime,
      client: client,
    );
    config.subscribe((_) {});
    async.flushMicrotasks();

    client.resetQueries();
    async.flushMicrotasks();
    expect(config.result.data, 'config 2');
  });

  fakeTest('a new listener first gets the current result during a fetch',
      (async) {
    final fetcher = FakeFetcher(() => 'todos');
    final first = Query.observe(
        queryKey: ['todos'], queryFn: fetcher.call, client: client);
    // Created before there is any data, for example by a bloc at startup.
    final second = Query.observe(
        queryKey: ['todos'], queryFn: fetcher.call, client: client);

    first.subscribe((_) {});
    async.elapse(ms10);
    first.refetch();
    async.flushMicrotasks();

    final results = <QueryResult<String>>[];
    second.stream.listen(results.add);
    async.flushMicrotasks();
    expect(fetcher.calls, 2);
    expect(results.first.data, 'todos');
    expect(results.first.isRefetching, isTrue);
  });

  fakeTest('a widget mounting at the stale boundary keeps others updated',
      (async) {
    final todos = Query.observe(
      queryKey: ['todos'],
      queryFn: FakeFetcher(() => 'todos').call,
      staleTime: const Duration(milliseconds: 100),
      client: client,
    );
    final stale = <bool>[];
    todos.subscribe((result) => stale.add(result.isStale));
    async.elapse(ms10);
    async.elapse(const Duration(milliseconds: 100));

    // A second widget reads the first frame just before the stale timer.
    expect(todos.getOptimisticResult().isStale, isTrue);
    async.elapse(const Duration(seconds: 1));
    expect(stale.last, isTrue);
  });

  fakeTest('isFetchedAfterMount counts from the first listener', (async) {
    final fetcher = FakeFetcher(() => 'todos');
    // Created at startup, listened to later.
    final todos = Query.observe(
      queryKey: ['todos'],
      queryFn: fetcher.call,
      staleTime: infiniteDuration,
      client: client,
    );
    client
        .query(QueryOptions(queryKey: ['todos'], queryFn: fetcher.call))
        .ignore();
    async.elapse(ms10);

    expect(todos.getOptimisticResult().isFetchedAfterMount, isFalse);
    var unsubscribe = todos.subscribe((_) {});
    async.flushMicrotasks();
    expect(todos.result.isFetchedAfterMount, isFalse);

    client.invalidateQueries(queryKey: ['todos']);
    async.elapse(ms10);
    expect(todos.result.isFetchedAfterMount, isTrue);

    // Listened to again, for example by a screen that opens again.
    unsubscribe();
    unsubscribe = todos.subscribe((_) {});
    async.flushMicrotasks();
    expect(todos.result.isFetchedAfterMount, isFalse);
    expect(fetcher.calls, 2);
    unsubscribe();
  });

  group('infinite queries', () {
    Future<String> fetchPage(InfiniteQueryFunctionContext<int> context) async =>
        'page ${context.pageParam}';
    int? next(InfiniteData<String, int> data) => data.lastPageParam + 1;

    fakeTest('pages only applies when nothing is cached', (async) {
      final posts = InfiniteQuery.observe(
        queryKey: ['posts'],
        queryFn: fetchPage,
        initialPageParam: 1,
        getNextPageParam: next,
        client: client,
      );
      posts.subscribe((_) {});
      async.flushMicrotasks();
      posts.fetchNextPage();
      async.flushMicrotasks();
      posts.fetchNextPage();
      async.flushMicrotasks();

      final prefetch = infiniteQueryOptions(
        queryKey: ['posts'],
        queryFn: fetchPage,
        initialPageParam: 1,
        getNextPageParam: next,
        pages: 1,
      );
      client.infiniteQuery(prefetch).ignore();
      async.flushMicrotasks();
      expect(posts.result.pages, ['page 1', 'page 2', 'page 3']);

      final observer = InfiniteQueryObserver(client, prefetch);
      observer.subscribe((_) {});
      observer.refetch();
      async.flushMicrotasks();
      expect(observer.result.pages, ['page 1', 'page 2', 'page 3']);
    });

    fakeTest('the first frame of a mount refetch is not a next-page fetch',
        (async) {
      InfiniteQueryObserver<String, int> use() => InfiniteQuery.observe(
            queryKey: ['posts'],
            queryFn: fetchPage,
            initialPageParam: 1,
            getNextPageParam: next,
            client: client,
          );
      final first = use();
      final unsubscribe = first.subscribe((_) {});
      async.flushMicrotasks();
      first.fetchNextPage();
      async.flushMicrotasks();
      unsubscribe();

      final optimistic = use().getOptimisticResult();
      expect(optimistic.isRefetching, isTrue);
      expect(optimistic.isFetchingNextPage, isFalse);
    });

    int? noPage(InfiniteData<String, int> data) => null;

    fakeTest('fetchNextPage without a next page leaves a refetch alone',
        (async) {
      var version = 1;
      final posts = InfiniteQuery.observe(
        queryKey: ['posts'],
        queryFn: (context) async {
          final value = 'v$version';
          await Future<void>.delayed(ms10);
          return value;
        },
        initialPageParam: 1,
        getNextPageParam: noPage,
        staleTime: const Duration(minutes: 5),
        client: client,
      );
      posts.subscribe((_) {});
      async.elapse(ms10);

      version = 2;
      client.invalidateQueries(queryKey: ['posts']);
      // A scroll listener reaching the end of the list.
      posts.fetchNextPage();
      async.elapse(ms10);

      expect(posts.result.pages, ['v2']);
    });

    fakeTest('fetching a page that does not exist changes nothing', (async) {
      final posts = InfiniteQuery.observe(
        queryKey: ['posts'],
        queryFn: fetchPage,
        initialPageParam: 1,
        getNextPageParam: noPage,
        getPreviousPageParam: noPage,
        client: client,
      );
      posts.subscribe((_) {});
      async.flushMicrotasks();
      final before = posts.result;
      final results = <QueryResult<InfiniteData<String, int>>>[];
      posts.subscribe(results.add);

      InfiniteQueryResult<String, int>? next;
      InfiniteQueryResult<String, int>? previous;
      posts.fetchNextPage().then((result) => next = result);
      posts.fetchPreviousPage().then((result) => previous = result);
      async.flushMicrotasks();

      expect(results, isEmpty);
      expect(next, before);
      expect(previous, before);
    });

    fakeTest('fetchNextPage joins a next page that is already loading',
        (async) {
      final params = <int>[];
      final posts = InfiniteQuery.observe(
        queryKey: ['posts'],
        queryFn: (context) async {
          params.add(context.pageParam);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: next,
        client: client,
      );
      posts.subscribe((_) {});
      async.elapse(const Duration(milliseconds: 100));

      final results = <InfiniteQueryResult<String, int>>[];
      for (var i = 0; i < 3; i++) {
        posts.fetchNextPage().then(results.add);
        async.elapse(const Duration(milliseconds: 20));
      }
      async.elapse(const Duration(milliseconds: 100));

      expect(params, [1, 2]);
      expect(posts.result.pages, ['page 1', 'page 2']);
      expect(results.map((result) => result.pages), [
        for (var i = 0; i < 3; i++) ['page 1', 'page 2'],
      ]);
    });
  });

  group('mutations', () {
    fakeTest('a mutation run with mutateAsync is garbage collected', (async) {
      final addTodo = Mutation.observe(
        mutationFn: (String title) async => title,
        gcTime: const Duration(seconds: 1),
        client: client,
      );
      addTodo.mutateAsync('Buy milk').ignore();
      async.elapse(ms10);
      expect(addTodo.result.data, 'Buy milk');

      async.elapse(const Duration(seconds: 2));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('result is current while nothing listens', (async) {
      final save = Mutation.observe(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
        client: client,
      );
      final unsubscribe = save.subscribe((_) {});
      save.mutate('a');
      async.flushMicrotasks();
      unsubscribe();

      async.elapse(ms10);
      expect(save.result.isSuccess, isTrue);
    });

    fakeTest('a pending mutation without observers waits to be collected',
        (async) {
      final save = Mutation.observe(
        mutationFn: (int x) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return x;
        },
        gcTime: Duration.zero,
        client: client,
      );
      final unsubscribe = save.subscribe((_) {});
      save.mutate(1);
      unsubscribe();
      async.elapse(const Duration(milliseconds: 100));
      // No garbage collection timer runs over and over while it is pending.
      expect(async.pendingTimers, hasLength(1));

      async.elapse(const Duration(milliseconds: 200));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('a scoped mutation is not paused while it runs', (async) {
      Future<String> run(String value) async {
        await Future<void>.delayed(ms10);
        return value;
      }

      final first = Mutation.observe(
        mutationFn: run,
        scope: const MutationScope('s'),
        client: client,
      );
      final second = Mutation.observe(
        mutationFn: run,
        onMutate: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return null;
        },
        scope: const MutationScope('s'),
        client: client,
      );
      first.mutate('a');
      second.mutate('b');
      async.elapse(const Duration(milliseconds: 25));
      expect(second.result.isPending, isTrue);
      expect(second.result.isPaused, isFalse);
    });
  });

  fakeTest('a failing scoped mutation only reports to its caller', (async) {
    Future<String> run(String value) async {
      await Future<void>.delayed(ms10);
      if (value == 'b') throw StateError('boom');
      return value;
    }

    final first = Mutation.observe(
      mutationFn: run,
      scope: const MutationScope('s'),
      client: client,
    );
    final second = Mutation.observe(
      mutationFn: run,
      scope: const MutationScope('s'),
      client: client,
    );

    Object? error;
    first.mutate('a');
    second.mutateAsync('b').then((_) {}, onError: (Object e) {
      error = e;
    });
    async.elapse(const Duration(milliseconds: 30));

    expect(error, isA<StateError>());
    expect(second.result.isError, isTrue);
  });

  fakeTest('restarting a paused fetch shows it as fetching again', (async) {
    var attempts = 0;
    final observer = QueryObserver<String>(
      client,
      QueryOptions(
        queryKey: ['a'],
        queryFn: (_) async {
          attempts++;
          await Future<void>.delayed(ms10);
          if (attempts == 2) throw StateError('boom');
          return 'data $attempts';
        },
        retryDelay: (_, __) => ms10,
      ),
    );
    observer.subscribe((_) {});
    async.elapse(ms10);

    // A background refetch fails, and its retry pauses while unfocused.
    focusManager.setFocused(false);
    observer.refetch();
    async.elapse(const Duration(milliseconds: 30));
    expect(observer.result.fetchStatus, FetchStatus.paused);
    expect(observer.result.failureCount, 1);

    var done = false;
    client.refetchQueries().then((_) => done = true);
    async.flushMicrotasks();
    expect(observer.result.fetchStatus, FetchStatus.fetching);
    expect(observer.result.failureCount, 0);
    expect(done, isFalse);

    async.elapse(ms10);
    expect(done, isTrue);
    expect(observer.result.data, 'data 3');
  });

  fakeTest('a key read with a wider data type is rejected clearly', (async) {
    client.setQueryData(['todos'], [const Item(1, 'a')]);

    expect(() => client.setQueryData(['todos'], <Object?>[]), throwsStateError);
    expect(
      () => QueryObserver<Object>(
        client,
        QueryOptions(queryKey: ['todos'], queryFn: (_) async => 1),
      ),
      throwsStateError,
    );
  });

  fakeTest('setOptions with a mismatched key leaves the observer as it was',
      (async) {
    client.setQueryData(['numbers'], 1);
    final observer = QueryObserver<String>(
      client,
      QueryOptions(queryKey: ['text'], queryFn: (_) async => 'a'),
    );

    expect(
      () => observer.setOptions(
        QueryOptions(queryKey: ['numbers'], queryFn: (_) async => 'b'),
      ),
      throwsStateError,
    );
    expect(observer.options.queryKey, ['text']);
    expect(observer.currentQuery.queryKey, ['text']);
  });

  fakeTest('structural sharing keeps unchanged list items', (async) {
    var items = [for (var i = 0; i < 100; i++) Item(i, 'item $i')];
    final observer = QueryObserver<List<Item>>(
      client,
      QueryOptions(queryKey: ['items'], queryFn: (_) async => items),
    );
    observer.subscribe((_) {});
    async.flushMicrotasks();
    final before = observer.result.data!;

    items = [
      for (var i = 0; i < 100; i++) Item(i, i == 50 ? 'changed' : 'item $i'),
    ];
    observer.refetch();
    async.flushMicrotasks();
    final after = observer.result.data!;

    expect(identical(before, after), isFalse);
    expect(after[50].name, 'changed');
    expect(identical(after[0], before[0]), isTrue);
    expect(identical(after[99], before[99]), isTrue);
    expect(after, isA<List<Item>>());
  });

  fakeTest('structural sharing reuses nested lists and equal maps', (async) {
    var data = <Object>[
      [1, 2],
      {'a': 1},
      [3],
    ];
    final observer = QueryObserver<List<Object>>(
      client,
      QueryOptions(queryKey: ['nested'], queryFn: (_) async => data),
    );
    observer.subscribe((_) {});
    async.flushMicrotasks();
    final before = observer.result.data!;

    data = <Object>[
      [1, 2],
      {'a': 1},
      [4],
    ];
    observer.refetch();
    async.flushMicrotasks();
    final after = observer.result.data!;

    expect(identical(after[0], before[0]), isTrue);
    expect(identical(after[1], before[1]), isTrue);
    expect(identical(after[2], before[2]), isFalse);
  });

  // Counts how often the client reports a change, through a watcher whose
  // value changes on every read.
  int Function() countChanges(FakeAsync async) {
    var reads = 0;
    final subscription = client.watch((_) => reads++).listen((_) {});
    addTearDown(subscription.cancel);
    async.flushMicrotasks();
    return () {
      async.flushMicrotasks();
      return reads - 1;
    };
  }

  fakeTest('query observers report only real option changes', (async) {
    Future<String> fetch(QueryFunctionContext _) async => 'a';
    final options = QueryOptions(queryKey: ['a'], queryFn: fetch);
    final observer = QueryObserver<String>(client, options);
    final changes = countChanges(async);

    observer.setOptions(QueryOptions(queryKey: ['a'], queryFn: fetch));
    expect(changes(), 0);

    observer.setOptions(QueryOptions(
      queryKey: ['a'],
      queryFn: fetch,
      staleTime: const Duration(seconds: 1),
    ));
    expect(changes(), 1);
  });

  fakeTest('mutation observers report only real option changes', (async) {
    Future<int> run(int x) async => x;
    final observer = MutationObserver<int, int, void>(
      client,
      MutationOptions(mutationFn: run, mutationKey: ['add']),
    );
    final changes = countChanges(async);

    observer.setOptions(MutationOptions(mutationFn: run, mutationKey: ['add']));
    expect(changes(), 0);

    observer.setOptions(MutationOptions(
      mutationFn: run,
      mutationKey: ['add'],
      gcTime: ms10,
    ));
    expect(changes(), 1);
  });

  fakeTest('removed queries and mutations keep no garbage collection timer',
      (async) {
    onlineManager.setOnline(false);
    final query = Query.observe(
      queryKey: ['paused'],
      queryFn: FakeFetcher(() => 'a').call,
      client: client,
    );
    final mutation = Mutation.observe(
      mutationFn: (int id) async => id,
      client: client,
    );
    final unsubscribeQuery = query.subscribe((_) {});
    final unsubscribeMutation = mutation.subscribe((_) {});
    mutation.mutate(1);
    async.flushMicrotasks();

    client.clear();
    unsubscribeQuery();
    unsubscribeMutation();
    async.flushMicrotasks();

    // The subscribed observer moved to a new query, which is collected later.
    // The removed query and mutation keep no timers.
    expect(client.queryCache.getAll(), hasLength(1));
    expect(async.pendingTimers, hasLength(1));
    client.clear();
    expect(async.pendingTimers, isEmpty);
  });
}
