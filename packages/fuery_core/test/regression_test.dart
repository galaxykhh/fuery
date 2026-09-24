// Regression tests for cache, refetch, and mutation edge cases.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:fuery_core/src/utils.dart' show storageHash;
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

enum Sort { newest }

enum Tab { newest }

enum Label {
  a;

  @override
  String toString() => 'label $name';
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

    final observer = Query(
      queryKey: ['a'],
      queryFn: fetch,
      retryDelay: (_, __) => ms10,
    ).observe(client: client);
    final unsubscribe = observer.subscribe((_) {});
    async.elapse(const Duration(seconds: 1));
    client.query(Query(queryKey: ['a'], queryFn: fetch)).ignore();
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
      final me = Query(
        queryKey: ['me'],
        queryFn: (_) async => user,
      ).observe(client: client);
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
      Query(queryKey: ['me'], queryFn: fetcher.call)
          .observe(client: client)
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
          Query(queryKey: ['a'], queryFn: fetcher.call).observe(client: client);
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
      final todos = Query(
        queryKey: ['todos'],
        queryFn: FakeFetcher(() => ['a']).call,
      ).observe(client: reporting);
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
      final observer = Query(
        queryKey: ['a'],
        queryFn: FakeFetcher(() => 'data').call,
      ).observe(client: client);
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
      final observer = Query(
        queryKey: ['a'],
        queryFn: (_) async => throw StateError('boom'),
        retryDelay: (_, __) => const Duration(seconds: 30),
      ).observe(client: client);
      final unsubscribe = observer.subscribe((_) {});
      async.flushMicrotasks();
      expect(observer.result.failureCount, 1);

      unsubscribe();
      client.clear();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });

    fakeTest('clear() stops a mutation waiting to retry', (async) {
      final mutation = Mutation(
        mutationFn: (int x) async => throw StateError('boom'),
        retry: const RetryPolicy.count(1),
        retryDelay: (_, __) => const Duration(seconds: 30),
      ).observe(client: client);
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

    fakeTest('clear() drops a mutation paused offline', (async) {
      onlineManager.setOnline(false);
      final mutation =
          Mutation(mutationFn: (int x) async => x).observe(client: client);
      final unsubscribe = mutation.subscribe((_) {});
      Object? error;
      Object? callbackError;
      final options =
          MutateOptions<int, int, Object?>(onError: (e, _, __, ___) {
        callbackError = e;
      });
      mutation.mutateAsync(1, options).then((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();
      expect(mutation.result.isPaused, isTrue);

      client.clear();
      async.flushMicrotasks();
      expect(error, isA<CancelledError>());
      expect(callbackError, isA<CancelledError>());
      expect(mutation.result.isPaused, isFalse);
      expect(mutation.result.isError, isTrue);
      expect(async.pendingTimers, isEmpty);
      unsubscribe();
    });

    fakeTest('clear() drops a mutation waiting for its scope', (async) {
      final post = Mutation(
        mutationFn: (int x) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return x;
        },
        scope: const MutationScope('s'),
      );
      final first = post.observe(client: client);
      final second = post.observe(client: client);
      int? data;
      Object? error;
      first.mutateAsync(1).then((value) {
        data = value;
      });
      second.mutateAsync(2).then((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();
      expect(second.result.isPaused, isTrue);

      client.clear();
      async.flushMicrotasks();
      expect(error, isA<CancelledError>());
      expect(data, isNull);

      // The run that is sending finishes.
      async.elapse(const Duration(seconds: 1));
      expect(data, 1);
      expect(async.pendingTimers, isEmpty);
    });

    fakeTest('clear() drops a mutation whose retry paused offline', (async) {
      final mutation = Mutation(
        mutationFn: (int x) async => throw StateError('boom'),
        retry: const RetryPolicy.count(3),
        retryDelay: (_, __) => ms10,
      ).observe(client: client);
      Object? error;
      mutation.mutateAsync(1).then((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();
      onlineManager.setOnline(false);
      async.elapse(ms10);
      expect(mutation.result.isPaused, isTrue);

      client.clear();
      async.flushMicrotasks();
      expect(error, isA<CancelledError>());
      expect(async.pendingTimers, isEmpty);
    });

    fakeTest('clear() during onMutate drops a run that would pause', (async) {
      final mutation = Mutation(
        mutationFn: (int x) async => x,
        onMutate: (_, __) async {
          await Future<void>.delayed(ms10);
          return 'context';
        },
      ).observe(client: client);
      final paused = <bool>[];
      final unsubscribe =
          mutation.subscribe((result) => paused.add(result.isPaused));
      Object? error;
      mutation.mutateAsync(1).then((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();
      onlineManager.setOnline(false);

      client.clear();
      async.elapse(ms10);
      expect(error, isA<CancelledError>());
      expect(mutation.result.isError, isTrue);
      expect(paused, everyElement(isFalse));
      expect(async.pendingTimers, isEmpty);
      unsubscribe();
    });
  });

  fakeTest('resetQueries refetches an active static query', (async) {
    var calls = 0;
    final config = Query(
      queryKey: ['config'],
      queryFn: (_) async => 'config ${++calls}',
      staleTime: staticStaleTime,
    ).observe(client: client);
    config.subscribe((_) {});
    async.flushMicrotasks();

    client.resetQueries();
    async.flushMicrotasks();
    expect(config.result.data, 'config 2');
  });

  fakeTest('a new listener first gets the current result during a fetch',
      (async) {
    final fetcher = FakeFetcher(() => 'todos');
    final first = Query(queryKey: ['todos'], queryFn: fetcher.call)
        .observe(client: client);
    // Created before there is any data, for example by a bloc at startup.
    final second = Query(queryKey: ['todos'], queryFn: fetcher.call)
        .observe(client: client);

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
    final todos = Query(
      queryKey: ['todos'],
      queryFn: FakeFetcher(() => 'todos').call,
      staleTime: const Duration(milliseconds: 100),
    ).observe(client: client);
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
    final todos = Query(
      queryKey: ['todos'],
      queryFn: fetcher.call,
      staleTime: infiniteDuration,
    ).observe(client: client);
    client.query(Query(queryKey: ['todos'], queryFn: fetcher.call)).ignore();
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

  group('cache callbacks', () {
    // A query cache callback that throws is the app's bug, not the fetch's:
    // the query keeps the fetch's outcome, and the other callbacks run.
    fakeTest('a throwing onSuccess leaves the fetch successful', (async) {
      final settled = <Object?>[];
      final client = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(
            onSuccess: (_, __) => throw StateError('onSuccess'),
            onSettled: (data, _, __) => settled.add(data),
          ),
        ),
      );
      final errors = <Object>[];
      Object? fetched;
      runZonedGuarded(() {
        client
            .query(Query(queryKey: ['a'], queryFn: FakeFetcher(() => 'a').call))
            .then<void>((data) {
          fetched = data;
        }, onError: (Object error) {
          fetched = error;
        });
        async.elapse(ms10);
      }, (error, _) => errors.add(error));

      expect(fetched, 'a');
      expect(
          client.queryCache.find(QueryFilters(queryKey: ['a']))!.state.status,
          QueryStatus.success);
      expect(settled, ['a']);
      expect((errors.single as StateError).message, 'onSuccess');
      client.clear();
    });

    fakeTest('a throwing onError leaves the fetch error and runs onSettled',
        (async) {
      final settled = <Object?>[];
      final client = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(
            onError: (_, __) => throw StateError('onError'),
            onSettled: (_, error, __) => settled.add(error),
          ),
        ),
      );
      final fetcher = FakeFetcher(() => 'a')..error = StateError('down');
      final errors = <Object>[];
      runZonedGuarded(() {
        client
            .query(Query(
              queryKey: ['a'],
              queryFn: fetcher.call,
              retry: const RetryPolicy.never(),
            ))
            .ignore();
        async.elapse(ms10);
      }, (error, _) => errors.add(error));

      final state =
          client.queryCache.find(QueryFilters(queryKey: ['a']))!.state;
      expect((state.error! as StateError).message, 'down');
      expect(settled, [state.error]);
      expect((errors.single as StateError).message, 'onError');
      client.clear();
    });
  });

  group('stored keys are the same in obfuscated builds', () {
    // Obfuscated and minified builds rename types, so a storage key with a
    // type name would change with every build, and persisted queries under
    // keys with enums would not be restored after an app update.
    test('the storage hash leaves out enum types', () {
      expect(storageHash(['posts', Sort.newest]), '["posts","enum:newest"]');
      expect(
          storageHash([
            {Sort.newest: true}
          ]),
          '[{"enum:newest":true}]');
      final plain = [
        'posts',
        1,
        {'a': DateTime.utc(2026)}
      ];
      expect(storageHash(plain), hashKey(plain));
    });

    test('in memory, keys keep enum types apart as before', () {
      expect(hashKey(['posts', Sort.newest]), '["posts","Sort.newest"]');
      expect(
        hashKey(['posts', Sort.newest]),
        isNot(hashKey(['posts', Tab.newest])),
      );
      // A map key is its toString, as it was.
      expect(
          hashKey([
            {Label.a: 1}
          ]),
          '[{"label a":1}]');
    });
  });

  group('infinite queries', () {
    Future<String> fetchPage(InfiniteQueryFunctionContext<int> context) async =>
        'page ${context.pageParam}';
    int? next(InfiniteData<String, int> data) => data.lastPageParam + 1;

    fakeTest('pages only applies when nothing is cached', (async) {
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: fetchPage,
        initialPageParam: 1,
        getNextPageParam: next,
      ).observe(client: client);
      posts.subscribe((_) {});
      async.flushMicrotasks();
      posts.fetchNextPage();
      async.flushMicrotasks();
      posts.fetchNextPage();
      async.flushMicrotasks();

      final prefetch = InfiniteQuery(
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
      InfiniteQueryObserver<String, int> use() => InfiniteQuery(
            queryKey: ['posts'],
            queryFn: fetchPage,
            initialPageParam: 1,
            getNextPageParam: next,
          ).observe(client: client);
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
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: (context) async {
          final value = 'v$version';
          await Future<void>.delayed(ms10);
          return value;
        },
        initialPageParam: 1,
        getNextPageParam: noPage,
        staleTime: const Duration(minutes: 5),
      ).observe(client: client);
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
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: fetchPage,
        initialPageParam: 1,
        getNextPageParam: noPage,
        getPreviousPageParam: noPage,
      ).observe(client: client);
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
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: (context) async {
          params.add(context.pageParam);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: next,
      ).observe(client: client);
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
      final addTodo = Mutation(
        mutationFn: (String title) async => title,
        gcTime: const Duration(seconds: 1),
      ).observe(client: client);
      addTodo.mutateAsync('Buy milk').ignore();
      async.elapse(ms10);
      expect(addTodo.result.data, 'Buy milk');

      async.elapse(const Duration(seconds: 2));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('result is current while nothing listens', (async) {
      final save = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
      ).observe(client: client);
      final unsubscribe = save.subscribe((_) {});
      save.mutate('a');
      async.flushMicrotasks();
      unsubscribe();

      async.elapse(ms10);
      expect(save.result.isSuccess, isTrue);
    });

    fakeTest('a pending mutation without observers waits to be collected',
        (async) {
      final save = Mutation(
        mutationFn: (int x) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return x;
        },
        gcTime: Duration.zero,
      ).observe(client: client);
      final unsubscribe = save.subscribe((_) {});
      save.mutate(1);
      unsubscribe();
      async.elapse(const Duration(milliseconds: 100));
      // No garbage collection timer runs over and over while it is pending.
      expect(async.pendingTimers, hasLength(1));

      async.elapse(const Duration(milliseconds: 200));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('a running mutation keeps the scope it was queued in', (async) {
      Mutation<int, int, Object?> post(String scope) => Mutation(
            mutationKey: const ['post'],
            mutationFn: (int x) async {
              await Future<void>.delayed(ms10);
              return x;
            },
            scope: MutationScope(scope),
          );
      final first = post('a').observe(client: client);
      final second = post('a').observe(client: client);
      first.mutate(1);
      second.mutate(2);
      async.flushMicrotasks();
      expect(second.result.isPaused, isTrue);

      // A widget rebuilds with another scope while the first run is sending.
      first.setOptions(post('b'));
      async.elapse(const Duration(milliseconds: 30));
      expect(first.result.isSuccess, isTrue);
      expect(second.result.isSuccess, isTrue);

      // The next run in the scope isn't held up by either of them.
      final third = post('a').observe(client: client);
      third.mutate(3);
      async.flushMicrotasks();
      expect(third.result.isPaused, isFalse);
      async.elapse(ms10);
      expect(third.result.isSuccess, isTrue);
    });

    fakeTest('submittedAt stays the same when onMutate returns a context',
        (async) {
      final save = Mutation(
        mutationFn: (int x) async => x,
        onMutate: (_, __) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'context';
        },
      ).observe(client: client);
      final submitted = <int>[];
      final unsubscribe = save.subscribe((result) {
        if (result.isPending) submitted.add(result.submittedAt);
      });
      save.mutate(1);
      async.elapse(const Duration(milliseconds: 30));

      expect(save.result.context, 'context');
      expect(submitted, hasLength(greaterThan(1)));
      expect(submitted.toSet(), hasLength(1));
      expect(save.result.submittedAt, submitted.first);
      unsubscribe();
    });

    fakeTest('a scoped mutation is not paused while it runs', (async) {
      Future<String> run(String value) async {
        await Future<void>.delayed(ms10);
        return value;
      }

      final first = Mutation(
        mutationFn: run,
        scope: const MutationScope('s'),
      ).observe(client: client);
      final second = Mutation(
        mutationFn: run,
        onMutate: (_, client) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return null;
        },
        scope: const MutationScope('s'),
      ).observe(client: client);
      first.mutate('a');
      second.mutate('b');
      async.elapse(const Duration(milliseconds: 25));
      expect(second.result.isPending, isTrue);
      expect(second.result.isPaused, isFalse);
    });
  });

  group('reconnecting with paused mutations', () {
    Mutation<int, int, Object?> slowPost() => Mutation(
          mutationFn: (int x) async {
            await Future<void>.delayed(const Duration(seconds: 3));
            return x;
          },
          scope: const MutationScope('posts'),
        );

    fakeTest('a paused first load does not wait for the mutations', (async) {
      onlineManager.setOnline(false);
      for (var i = 0; i < 3; i++) {
        slowPost().observe(client: client).mutate(i);
      }
      final fetcher = FakeFetcher(() => 'me');
      final profile = Query(queryKey: ['profile'], queryFn: fetcher.call)
          .observe(client: client);
      final unsubscribe = profile.subscribe((_) {});
      async.flushMicrotasks();
      expect(profile.result.fetchStatus, FetchStatus.paused);

      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(profile.result.data, 'me');
      expect(client.isMutating(), 3);

      // Once the mutations are done, the reconnect refetches as usual.
      async.elapse(const Duration(seconds: 9));
      expect(client.isMutating(), 0);
      expect(fetcher.calls, 2);
      unsubscribe();
    });

    fakeTest('a refetch of a query with data waits for the mutations', (async) {
      client.setQueryData(['a'], 'old');
      onlineManager.setOnline(false);
      final fetcher = FakeFetcher(() => 'new');
      final a =
          Query(queryKey: ['a'], queryFn: fetcher.call).observe(client: client);
      final unsubscribe = a.subscribe((_) {});
      slowPost().observe(client: client).mutate(1);
      async.flushMicrotasks();
      expect(a.result.fetchStatus, FetchStatus.paused);

      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(fetcher.calls, 0);
      expect(a.result.data, 'old');

      async.elapse(const Duration(seconds: 3));
      expect(fetcher.calls, 1);
      async.elapse(ms10);
      expect(a.result.data, 'new');
      unsubscribe();
    });

    fakeTest('a paused first load resumes on focus', (async) {
      var attempts = 0;
      final profile = Query(
        queryKey: ['profile'],
        queryFn: (_) async {
          if (++attempts == 1) throw StateError('down');
          return 'me';
        },
        retryDelay: (_, __) => ms10,
      ).observe(client: client);
      final unsubscribe = profile.subscribe((_) {});
      async.flushMicrotasks();
      // Its retry pauses while the app is in the background, and the second
      // post waits for the first.
      focusManager.setFocused(false);
      for (var i = 0; i < 2; i++) {
        slowPost().observe(client: client).mutate(i);
      }
      async.elapse(ms10);
      expect(profile.result.fetchStatus, FetchStatus.paused);

      focusManager.setFocused(true);
      async.flushMicrotasks();
      expect(profile.result.data, 'me');
      expect(client.isMutating(), 2);
      async.elapse(const Duration(seconds: 6));
      unsubscribe();
    });
  });

  fakeTest('a failing scoped mutation only reports to its caller', (async) {
    Future<String> run(String value) async {
      await Future<void>.delayed(ms10);
      if (value == 'b') throw StateError('boom');
      return value;
    }

    final first = Mutation(
      mutationFn: run,
      scope: const MutationScope('s'),
    ).observe(client: client);
    final second = Mutation(
      mutationFn: run,
      scope: const MutationScope('s'),
    ).observe(client: client);

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
      Query(
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
        Query(queryKey: ['todos'], queryFn: (_) async => 1),
      ),
      throwsStateError,
    );
  });

  fakeTest('setOptions with a mismatched key leaves the observer as it was',
      (async) {
    client.setQueryData(['numbers'], 1);
    final observer = QueryObserver<String>(
      client,
      Query(queryKey: ['text'], queryFn: (_) async => 'a'),
    );

    expect(
      () => observer.setOptions(
        Query(queryKey: ['numbers'], queryFn: (_) async => 'b'),
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
      Query(queryKey: ['items'], queryFn: (_) async => items),
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
      Query(queryKey: ['nested'], queryFn: (_) async => data),
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
    final options = Query(queryKey: ['a'], queryFn: fetch);
    final observer = QueryObserver<String>(client, options);
    final changes = countChanges(async);

    observer.setOptions(Query(queryKey: ['a'], queryFn: fetch));
    expect(changes(), 0);

    observer.setOptions(Query(
      queryKey: ['a'],
      queryFn: fetch,
      staleTime: const Duration(seconds: 1),
    ));
    expect(changes(), 1);
  });

  fakeTest('options built again with new closures are not a change', (async) {
    // What a widget that builds its options in build() passes each time.
    Query<String> todoOptions(int id) => Query(
          queryKey: ['todo', id],
          queryFn: (_) async => 'todo $id',
          placeholderData: (previous, client) => previous,
          refetchWhile: (result) => true,
          retry: RetryPolicy.when((count, _) => count < 2),
          retryDelay: (_, __) => ms10,
          persist: QueryPersist(
            toJson: (todo) => todo,
            fromJson: (json) => json! as String,
          ),
          meta: {'screen': 'todo'},
        );
    final observer = todoOptions(1).observe(client: client);
    observer.subscribe((_) {});
    async.elapse(ms10);
    final changes = countChanges(async);

    observer.setOptions(todoOptions(1));
    observer.setOptions(todoOptions(1));
    expect(changes(), 0);

    // The latest query function is still the one that runs.
    observer.setOptions(Query(
      queryKey: ['todo', 1],
      queryFn: (_) async => 'replaced',
      placeholderData: (previous, client) => previous,
      refetchWhile: (result) => true,
      retry: RetryPolicy.when((count, _) => count < 2),
      retryDelay: (_, __) => ms10,
      persist: QueryPersist(
        toJson: (todo) => todo,
        fromJson: (json) => json! as String,
      ),
      meta: {'screen': 'todo'},
    ));
    expect(changes(), 0);
    observer.refetch();
    async.flushMicrotasks();
    expect(observer.result.data, 'replaced');

    observer.setOptions(Query(
      queryKey: ['todo', 1],
      queryFn: (_) async => 'todo 1',
      meta: {'screen': 'other'},
    ));
    expect(changes(), greaterThan(0));
  });

  fakeTest('initialData built again with equal content is not a change',
      (async) {
    Query<List<String>> tags() => Query(
          queryKey: ['tags'],
          queryFn: (_) async => ['a'],
          initialData: ['a'],
          staleTime: infiniteDuration,
        );
    final observer = tags().observe(client: client);
    observer.subscribe((_) {});
    async.flushMicrotasks();
    final changes = countChanges(async);

    observer.setOptions(tags());
    expect(changes(), 0);
  });

  fakeTest('mutation options built again with new closures are not a change',
      (async) {
    Mutation<int, int, void> addOptions() => Mutation(
          mutationKey: ['add'],
          mutationFn: (x) async => x + 1,
          onSuccess: (_, __, ___, client) {},
          retry: RetryPolicy.when((count, _) => false),
          persist: MutationPersist(
            toJson: (x) => x,
            fromJson: (json) => json! as int,
          ),
          meta: {'form': 'add'},
        );
    final observer = addOptions().observe(client: client);
    final changes = countChanges(async);

    observer.setOptions(addOptions());
    expect(changes(), 0);
  });

  fakeTest('mutation observers report only real option changes', (async) {
    Future<int> run(int x) async => x;
    final observer = MutationObserver<int, int, void>(
      client,
      Mutation(mutationFn: run, mutationKey: ['add']),
    );
    final changes = countChanges(async);

    observer.setOptions(Mutation(mutationFn: run, mutationKey: ['add']));
    expect(changes(), 0);

    observer.setOptions(Mutation(
      mutationFn: run,
      mutationKey: ['add'],
      gcTime: ms10,
    ));
    expect(changes(), 1);
  });

  fakeTest('removed queries and mutations keep no garbage collection timer',
      (async) {
    onlineManager.setOnline(false);
    final query = Query(
      queryKey: ['paused'],
      queryFn: FakeFetcher(() => 'a').call,
    ).observe(client: client);
    final mutation = Mutation(
      mutationFn: (int id) async => id,
    ).observe(client: client);
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
