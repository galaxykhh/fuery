import 'dart:async';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'storages.dart';

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

  QueryObserver<String> observe(QueryKey key, FakeFetcher<String> fetcher) {
    return QueryObserver<String>(
      client,
      Query(queryKey: key, queryFn: fetcher.call),
    );
  }

  group('invalidateQueries', () {
    fakeTest('refetches active queries and marks inactive ones stale', (async) {
      final active = FakeFetcher(() => 'active');
      final inactive = FakeFetcher(() => 'inactive');
      final other = FakeFetcher(() => 'other');

      observe(['todos', 1], active).subscribe((_) {});
      final unsubscribe = observe(['todos', 2], inactive).subscribe((_) {});
      observe(['posts'], other).subscribe((_) {});
      async.elapse(ms10);
      unsubscribe();

      client.invalidateQueries(queryKey: ['todos']);
      async.elapse(ms10);

      expect(active.calls, 2);
      expect(inactive.calls, 1);
      expect(other.calls, 1);
      expect(client.getQueryState(['todos', 2])!.isInvalidated, isTrue);
      expect(client.getQueryState(['posts'])!.isInvalidated, isFalse);
    });

    fakeTest('matches the key exactly with exact', (async) {
      final list = FakeFetcher(() => 'list');
      final detail = FakeFetcher(() => 'detail');
      observe(['todos'], list).subscribe((_) {});
      observe(['todos', 1], detail).subscribe((_) {});
      async.elapse(ms10);

      client.invalidateQueries(queryKey: ['todos'], exact: true);
      async.elapse(ms10);

      expect(list.calls, 2);
      expect(detail.calls, 1);
    });

    fakeTest('only marks queries stale with RefetchType.none', (async) {
      final fetcher = FakeFetcher(() => 'data');
      observe(['todos'], fetcher).subscribe((_) {});
      async.elapse(ms10);

      client.invalidateQueries(
        queryKey: ['todos'],
        refetchType: RefetchType.none,
      );
      async.elapse(ms10);

      expect(fetcher.calls, 1);
      expect(client.getQueryState(['todos'])!.isInvalidated, isTrue);
    });

    fakeTest('refetches an invalidated query on the next mount', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final observer = QueryObserver<String>(
        client,
        Query(
          queryKey: ['todos'],
          queryFn: fetcher.call,
          staleTime: infiniteDuration,
        ),
      );
      final unsubscribe = observer.subscribe((_) {});
      async.elapse(ms10);
      unsubscribe();

      client.invalidateQueries(queryKey: ['todos']);
      async.elapse(ms10);
      expect(fetcher.calls, 1);

      observer.subscribe((_) {});
      async.elapse(ms10);
      expect(fetcher.calls, 2);
    });
  });

  group('query data', () {
    fakeTest('setQueryData updates observers', (async) {
      final observer = observe(['todos'], FakeFetcher(() => 'fetched'));
      observer.subscribe((_) {});
      async.elapse(ms10);

      client.setQueryData(['todos'], 'manual');
      expect(observer.result.data, 'manual');
      expect(client.getQueryData<String>(['todos']), 'manual');
    });

    fakeTest('setQueryData creates a query that a later observer uses',
        (async) {
      client.setQueryData<String>(['todos'], 'seeded');
      final fetcher = FakeFetcher(() => 'fetched');
      final observer = QueryObserver<String>(
        client,
        Query(
          queryKey: ['todos'],
          queryFn: fetcher.call,
          staleTime: const Duration(minutes: 1),
        ),
      );
      observer.subscribe((_) {});
      async.elapse(ms10);

      expect(fetcher.calls, 0);
      expect(observer.result.data, 'seeded');
    });

    fakeTest('updateQueryData derives from the previous value', (async) {
      client.setQueryData<List<int>>(['numbers'], [1, 2]);
      client.updateQueryData<List<int>>(['numbers'], (old) => [...?old, 3]);

      expect(client.getQueryData<List<int>>(['numbers']), [1, 2, 3]);
    });

    fakeTest('reading a key with another data type throws', (async) {
      client.setQueryData<String>(['todos'], 'text');

      expect(() => client.setQueryData<int>(['todos'], 1), throwsStateError);
    });

    fakeTest('setData creates a query that can refetch', (async) {
      final fetcher = FakeFetcher(() => 'fetched');
      final todos = Query(queryKey: ['todos'], queryFn: fetcher.call);

      client.setData(todos, 'seeded');
      expect(client.getData(todos), 'seeded');

      client.refetchQueries(queryKey: ['todos']);
      async.elapse(ms10);
      expect(fetcher.calls, 1);
      expect(client.getData(todos), 'fetched');
    });

    fakeTest('updateData derives from the previous value', (async) {
      final numbers = Query(
        queryKey: ['numbers'],
        queryFn: (_) async => <int>[],
      );
      client.setData(numbers, [1, 2], updatedAt: 5);
      expect(client.getQueryState(['numbers'])!.dataUpdatedAt, 5);

      expect(client.updateData(numbers, (old) => [...?old, 3]), [1, 2, 3]);
      expect(client.updateData(numbers, (old) => null), isNull);
      expect(client.getData(numbers), [1, 2, 3]);
    });
  });

  group('query', () {
    fakeTest('returns fresh cached data without fetching', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final options = Query<String>(
        queryKey: ['todos'],
        queryFn: fetcher.call,
        staleTime: const Duration(minutes: 1),
      );

      String? first;
      String? second;
      client.query(options).then((data) => first = data);
      async.elapse(ms10);
      client.query(options).then((data) => second = data);
      async.flushMicrotasks();

      expect(first, 'data');
      expect(second, 'data');
      expect(fetcher.calls, 1);
    });

    fakeTest('throws when the fetch fails and does not retry', (async) {
      final fetcher = FakeFetcher(() => 'data')..error = StateError('boom');
      Object? error;
      QueryClient()
          .query(Query<String>(
        queryKey: ['todos'],
        queryFn: fetcher.call,
      ))
          .catchError((Object e) {
        error = e;
        return '';
      });
      async.elapse(const Duration(seconds: 10));

      expect(error, isA<StateError>());
      expect(fetcher.calls, 1);
    });

    fakeTest('dedupes concurrent fetches of the same key', (async) {
      final fetcher = FakeFetcher(() => 'data');
      final options = Query<String>(
        queryKey: ['todos'],
        queryFn: fetcher.call,
      );
      client.query(options);
      client.query(options);
      async.elapse(ms10);

      expect(fetcher.calls, 1);
    });
  });

  fakeTest('cancelQueries reverts to the previous state', (async) {
    final fetcher = FakeFetcher(() => 'first');
    final observer = observe(['todos'], fetcher);
    observer.subscribe((_) {});
    async.elapse(ms10);

    fetcher.value = () => 'second';
    observer.refetch();
    client.cancelQueries(queryKey: ['todos']);
    async.elapse(ms10);

    expect(observer.result.data, 'first');
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.fetchStatus, FetchStatus.idle);
  });

  fakeTest('removeQueries removes matching queries', (async) {
    client.setQueryData(['todos', 1], 'a');
    client.setQueryData(['todos', 2], 'b');
    client.setQueryData(['posts'], 'c');

    client.removeQueries(queryKey: ['todos']);

    expect(client.getQueryData<String>(['todos', 1]), isNull);
    expect(client.getQueryData<String>(['posts']), 'c');
  });

  fakeTest('resetQueries restores initial data and refetches', (async) {
    final fetcher = FakeFetcher(() => 'fetched');
    final observer = QueryObserver<String>(
      client,
      Query(
        queryKey: ['todos'],
        queryFn: fetcher.call,
        initialData: 'initial',
      ),
    );
    observer.subscribe((_) {});
    async.elapse(ms10);
    expect(observer.result.data, 'fetched');

    client.resetQueries(queryKey: ['todos']);
    expect(observer.result.data, 'initial');
    async.elapse(ms10);
    expect(observer.result.data, 'fetched');
    expect(fetcher.calls, 2);
  });

  fakeTest('setQueryDefaults applies to keys with that prefix', (async) {
    client.setQueryDefaults(
      ['todos'],
      const QueryDefaults(staleTime: Duration(minutes: 1)),
    );

    final todos = observe(['todos', 1], FakeFetcher(() => 'a'));
    final posts = observe(['posts'], FakeFetcher(() => 'b'));

    expect(todos.options.staleTime, const Duration(minutes: 1));
    expect(posts.options.staleTime, isNull);
  });

  fakeTest('isFetching counts fetching queries', (async) {
    observe(['todos'], FakeFetcher(() => 'a')).subscribe((_) {});
    observe(['posts'], FakeFetcher(() => 'b')).subscribe((_) {});

    expect(client.isFetching(), 2);
    expect(client.isFetching(queryKey: ['todos']), 1);
    async.elapse(ms10);
    expect(client.isFetching(), 0);
  });

  fakeTest('cache config callbacks see every query', (async) {
    final errors = <Object>[];
    final client = QueryClient(
      queryCache: QueryCache(
        config: QueryCacheConfig(onError: (error, _) => errors.add(error)),
      ),
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
    QueryObserver<String>(
      client,
      Query(
        queryKey: ['a'],
        queryFn: (FakeFetcher(() => 'a')..error = StateError('boom')).call,
      ),
    ).subscribe((_) {});
    async.elapse(ms10);

    expect(errors.single, isA<StateError>());
    client.clear();
  });

  group('reading and prefetching', () {
    fakeTest('getQueriesData returns every matching key and data', (async) {
      client.setQueryData(['todos', 1], 'a');
      client.setQueryData(['todos', 2], 'b');
      client.setQueryData(['posts'], 'c');

      final entries = client.getQueriesData<String>(queryKey: ['todos']);
      expect(entries.map((e) => '${e.$1} ${e.$2}'), [
        '[todos, 1] a',
        '[todos, 2] b',
      ]);
    });

    fakeTest('updateQueriesData updates every match of its data type', (async) {
      // Lists and details of different types under one prefix.
      client.setQueryData(['posts', 'search', 'a'], ['a1', 'a2']);
      client.setQueryData(['posts', 'search', 'b'], ['b1']);
      client.setQueryData(['posts', 'detail', 1], 'a1');
      client.setQueryData(['posts', 'search', 'c'], ['c1']);
      final observer = Query(
        queryKey: ['posts', 'search', 'd'],
        queryFn: FakeFetcher(() => ['d1']).call,
      ).observe(client: client);
      observer.subscribe((_) {}); // pending: nothing to update yet
      final seen = <List<String>>[];

      client.updateQueriesData(
        queryKey: ['posts'],
        (List<String> posts) {
          seen.add(posts);
          if (posts.contains('c1')) return null; // left as it is
          return [for (final post in posts) '$post!'];
        },
      );

      expect(seen, hasLength(3));
      expect(client.getQueryData<List<String>>(['posts', 'search', 'a']),
          ['a1!', 'a2!']);
      expect(
          client.getQueryData<List<String>>(['posts', 'search', 'b']), ['b1!']);
      expect(
          client.getQueryData<List<String>>(['posts', 'search', 'c']), ['c1']);
      expect(client.getQueryData<String>(['posts', 'detail', 1]), 'a1');

      client.updateQueriesData(
        queryKey: ['posts', 'search', 'a'],
        exact: true,
        predicate: (query) => query.state.data != null,
        updatedAt: 5,
        (List<String> posts) => ['only a'],
      );
      expect(client.getQueryState(['posts', 'search', 'a'])!.dataUpdatedAt, 5);
      expect(client.getQueryData<List<String>>(['posts', 'search', 'a']),
          ['only a']);
      expect(
          client.getQueryData<List<String>>(['posts', 'search', 'b']), ['b1!']);

      // A parameter without a type would match nothing.
      expect(
        () => client.updateQueriesData(queryKey: ['posts'], (posts) => posts),
        throwsArgumentError,
      );
      async.elapse(ms10);
    });

    fakeTest('with staticStaleTime, uses any cached data', (async) {
      final fetcher = FakeFetcher(() => 'fetched');
      final options = Query<String>(
        queryKey: ['todos'],
        queryFn: fetcher.call,
        staleTime: staticStaleTime,
      );

      String? first;
      client.query(options).then((data) => first = data);
      async.elapse(ms10);
      expect(first, 'fetched');

      client.invalidateQueries(queryKey: ['todos']);
      fetcher.value = () => 'refetched';
      String? second;
      client.query(options).then((data) => second = data);
      async.elapse(ms10);

      expect(second, 'fetched');
      expect(fetcher.calls, 1);
    });

    fakeTest('prefetching with ignore fills the cache and hides errors',
        (async) {
      client
          .query(Query<String>(
            queryKey: ['ok'],
            queryFn: FakeFetcher(() => 'data').call,
          ))
          .ignore();
      client
          .query(Query<String>(
            queryKey: ['bad'],
            queryFn:
                (FakeFetcher(() => 'data')..error = StateError('boom')).call,
          ))
          .ignore();
      async.elapse(ms10);

      expect(client.getQueryData<String>(['ok']), 'data');
      expect(client.getQueryState(['bad'])!.status, QueryStatus.error);
    });

    fakeTest('infiniteQuery loads the first page', (async) {
      InfiniteData<String, int>? data;
      client
          .infiniteQuery(InfiniteQuery(
            queryKey: ['pages'],
            queryFn: (context) async => 'page ${context.pageParam}',
            initialPageParam: 1,
            getNextPageParam: (data) => data.lastPageParam + 1,
          ))
          .then((value) => data = value);
      async.flushMicrotasks();

      expect(data!.pages, ['page 1']);
      expect(
        client.getQueryData<InfiniteData<String, int>>(['pages'])!.pages,
        ['page 1'],
      );
    });

    fakeTest('refetching data set by key alone fails clearly', (async) {
      // setQueryData knows the key, but no query function to refetch with.
      client.setQueryData(['todos'], 'seeded');
      Object? error;
      client.refetchQueries(queryKey: ['todos'], throwOnError: true).then(
          (_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();

      expect(error, isA<StateError>());
    });
  });

  group('refetching', () {
    fakeTest('refetchQueries refetches matching enabled queries', (async) {
      final todos = FakeFetcher(() => 'todos');
      final disabled = FakeFetcher(() => 'disabled');
      observe(['todos'], todos).subscribe((_) {});
      QueryObserver<String>(
        client,
        Query(
          queryKey: ['todos', 'disabled'],
          queryFn: disabled.call,
          enabled: false,
        ),
      ).subscribe((_) {});
      async.elapse(ms10);

      client.refetchQueries(queryKey: ['todos']);
      async.elapse(ms10);

      expect(todos.calls, 2);
      expect(disabled.calls, 0);
    });

    fakeTest('refetchQueries does not wait for paused queries', (async) {
      observe(['todos'], FakeFetcher(() => 'data')).subscribe((_) {});
      async.elapse(ms10);
      onlineManager.setOnline(false);

      var done = false;
      client.refetchQueries().then((_) => done = true);
      async.flushMicrotasks();

      expect(done, isTrue);
      expect(client.getQueryState(['todos'])!.fetchStatus, FetchStatus.paused);
    });

    fakeTest('refetchQueries rethrows with throwOnError', (async) {
      final fetcher = FakeFetcher(() => 'data');
      observe(['todos'], fetcher).subscribe((_) {});
      async.elapse(ms10);
      fetcher.error = StateError('boom');

      Object? error;
      client.refetchQueries(throwOnError: true).then((_) {},
          onError: (Object e) {
        error = e;
      });
      async.elapse(ms10);

      expect(error, isA<StateError>());
    });

    fakeTest('filters by stale, type, and predicate', (async) {
      client.setQueryData(['fresh'], 'a');
      final stale = observe(['stale'], FakeFetcher(() => 'b'));
      stale.subscribe((_) {});
      async.elapse(ms10);

      final staleKeys = client.queryCache
          .findAll(const QueryFilters(stale: true))
          .map((q) => q.queryKey);
      expect(staleKeys, [
        ['stale'],
      ]);
      expect(
        client.queryCache
            .findAll(const QueryFilters(type: QueryTypeFilter.inactive))
            .single
            .queryKey,
        ['fresh'],
      );
      expect(
        client.queryCache
            .findAll(
                QueryFilters(predicate: (q) => q.queryKey.first == 'fresh'))
            .single
            .queryKey,
        ['fresh'],
      );
      expect(client.queryCache.find(const QueryFilters(queryKey: ['fresh'])),
          isNotNull);
      expect(client.queryCache.find(const QueryFilters(queryKey: ['fre'])),
          isNull);
    });
  });

  group('filters', () {
    fakeTest('find and exact findAll apply the other filters', (async) {
      client.setQueryData(['post', 1], 'a');
      final cache = client.queryCache;
      final post = cache.getAll().single;

      expect(cache.find(const QueryFilters(queryKey: ['post', 1])), same(post));
      expect(
        cache.find(const QueryFilters(
          queryKey: ['post', 1],
          type: QueryTypeFilter.active,
        )),
        isNull,
      );
      expect(cache.find(const QueryFilters(queryKey: ['post'])), isNull);
      expect(
        cache.find(QueryFilters(predicate: (q) => q.queryKey.last == 1)),
        same(post),
      );

      List<CachedQuery<Object>> exact(
        QueryKey queryKey, {
        bool Function(CachedQuery<Object> query)? predicate,
      }) {
        return cache.findAll(QueryFilters(
          queryKey: queryKey,
          exact: true,
          predicate: predicate,
        ));
      }

      expect(exact(['post', 1]), [post]);
      expect(exact(['post', 1], predicate: (_) => false), isEmpty);
      expect(exact(['post']), isEmpty);
    });

    fakeTest('matches compares keys by prefix, or whole with exact', (async) {
      client.setQueryData(['post', 1, 'comments'], 'a');
      final query = client.queryCache.getAll().single;

      expect(const QueryFilters(queryKey: ['post']).matches(query), isTrue);
      expect(const QueryFilters(queryKey: ['user']).matches(query), isFalse);
      expect(
        const QueryFilters(queryKey: ['post'], exact: true).matches(query),
        isFalse,
      );
      expect(
        const QueryFilters(queryKey: ['post', 1, 'comments'], exact: true)
            .matches(query),
        isTrue,
      );
      expect(
        const QueryFilters(type: QueryTypeFilter.active).matches(query),
        isFalse,
      );
    });

    fakeTest('an exact invalidate leaves longer keys alone', (async) {
      client.setQueryData(['post', 1], 'a');
      client.setQueryData(['post', 1, 'comments'], 'b');

      client.invalidateQueries(queryKey: ['post', 1], exact: true);

      expect(client.getQueryState(['post', 1])!.isInvalidated, isTrue);
      expect(
        client.getQueryState(['post', 1, 'comments'])!.isInvalidated,
        isFalse,
      );
    });

    fakeTest('a key that cannot be hashed throws once an entry is tested',
        (async) {
      final key = [Object()];
      expect(client.isFetching(queryKey: key), 0);
      expect(client.isFetching(queryKey: key, exact: true), 0);
      expect(client.queryCache.find(QueryFilters(queryKey: key)), isNull);
      expect(client.isMutating(mutationKey: key), 0);
      expect(client.isMutating(mutationKey: key, exact: true), 0);

      client.setQueryData(['post'], 'a');
      expect(() => client.isFetching(queryKey: key), throwsArgumentError);
      expect(
        () => client.isFetching(queryKey: key, exact: true),
        throwsArgumentError,
      );

      // A mutation without a key matches no key, so its key isn't tested.
      Mutation(mutationFn: (int x) async => x)
          .observe(client: client)
          .mutate(1);
      async.flushMicrotasks();
      expect(client.isMutating(mutationKey: key), 0);

      Mutation(mutationFn: (int x) async => x, mutationKey: ['todos'])
          .observe(client: client)
          .mutate(1);
      async.flushMicrotasks();
      expect(() => client.isMutating(mutationKey: key), throwsArgumentError);
      expect(
        () => client.isMutating(mutationKey: key, exact: true),
        throwsArgumentError,
      );
    });
  });

  fakeTest('watch sees queries added, observed, updated, and removed', (async) {
    final snapshots = <List<(QueryStatus, int)>>[];
    final subscription = client
        .watch((client) => [
              for (final query in client.queryCache.getAll())
                (query.state.status, query.observersCount),
            ])
        .listen(snapshots.add);

    final observer = observe(['todos'], FakeFetcher(() => 'data'));
    async.flushMicrotasks();
    final unsubscribe = observer.subscribe((_) {});
    async.flushMicrotasks();
    async.elapse(ms10);
    unsubscribe();
    async.flushMicrotasks();
    client.removeQueries();
    async.flushMicrotasks();
    subscription.cancel();

    expect(snapshots, [
      <(QueryStatus, int)>[],
      [(QueryStatus.pending, 0)],
      [(QueryStatus.pending, 1)],
      [(QueryStatus.success, 1)],
      [(QueryStatus.success, 0)],
      <(QueryStatus, int)>[],
    ]);
  });

  fakeTest('setMutationDefaults applies to keys with that prefix', (async) {
    client.setMutationDefaults(
      ['todos'],
      const MutationDefaults(retry: RetryPolicy.count(2)),
    );

    final todo = Mutation(
      mutationFn: (int id) async => id,
      mutationKey: ['todos', 'add'],
    ).observe(client: client);
    final other = Mutation(
      mutationFn: (int id) async => id,
      mutationKey: ['posts'],
    ).observe(client: client);

    expect(todo.options.retry, isNotNull);
    expect(other.options.retry, isNull);
  });

  fakeTest('resumePausedMutations does nothing while offline', (async) {
    onlineManager.setOnline(false);
    final mutation = Mutation(
      mutationFn: (int id) async => id,
    ).observe(client: client);
    mutation.mutate(1);
    async.flushMicrotasks();

    client.resumePausedMutations();
    async.flushMicrotasks();
    expect(mutation.result.isPaused, isTrue);
  });

  group('onUncaughtError', () {
    late List<String> reported;
    late List<Object> zone;
    late QueryClient client;

    setUp(() {
      reported = [];
      zone = [];
      client = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(
            onSuccess: (data, _) {
              if (data == 'throw') throw StateError('cache onSuccess');
            },
          ),
        ),
        storage: MemoryStorage(),
        onUncaughtError: (error, _) => reported.add('$error'),
      );
    });

    tearDown(() => client.clear());

    fakeTest('receives what callbacks throw, instead of the zone', (async) {
      runZonedGuarded(() {
        client.query(
          Query(queryKey: ['a'], queryFn: FakeFetcher(() => 'throw').call),
        );
        Mutation(
          mutationFn: (String variables) async => throw StateError('down'),
          onError: (_, __, ___, ____) => throw StateError('onError'),
        ).observe(client: client).mutate(
              'a',
              MutateOptions(
                onError: (_, __, ___, ____) async =>
                    throw StateError('async mutate onError'),
                onSettled: (_, __, ___, ____, _____) =>
                    throw StateError('mutate onSettled'),
              ),
            );
        async.elapse(ms10);
      }, (error, _) => zone.add(error));

      expect(reported, [
        'Bad state: onError',
        'Bad state: mutate onSettled',
        'Bad state: async mutate onError',
        'Bad state: cache onSuccess',
      ]);
      expect(zone, isEmpty);
    });

    fakeTest('receives what an async cache callback throws', (async) {
      final asyncCallbacks = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(
            onSettled: (_, __, ___) async => throw StateError('async'),
          ),
        ),
        onUncaughtError: (error, _) => reported.add('$error'),
      );
      runZonedGuarded(() {
        asyncCallbacks.query(
          Query(queryKey: ['a'], queryFn: FakeFetcher(() => 'a').call),
        );
        async.elapse(ms10);
      }, (error, _) => zone.add(error));

      expect(reported, ['Bad state: async']);
      expect(zone, isEmpty);
      asyncCallbacks.clear();
    });

    fakeTest('receives mistakes Fuery finds, once per client', (async) {
      InfiniteQuery<int, int> pagesQuery() => InfiniteQuery(
            queryKey: ['pages'],
            queryFn: (context) async => context.pageParam,
            initialPageParam: 1,
            getNextPageParam: (data) => 'two',
          );
      final errors = <Object>[];
      final other =
          QueryClient(onUncaughtError: (error, _) => errors.add(error));
      runZonedGuarded(() {
        for (final client in [client, client, other]) {
          pagesQuery().observe(client: client).subscribe((_) {});
          async.flushMicrotasks();
        }
        final unstorable = Mutation(
          mutationKey: [Object()],
          mutationFn: (String variables) async => variables,
          persist: const MutationPersist<String>(
            toJson: _same,
            fromJson: _string,
          ),
        ).observe(client: client);
        unstorable
          ..mutate('a')
          ..mutate('b');
        async.flushMicrotasks();
      }, (error, _) => zone.add(error));

      expect(reported, [
        contains('getNextPageParam returned String'),
        contains('Keys must contain only'),
      ]);
      expect(errors, hasLength(1));
      expect(zone, isEmpty);
      other.clear();

      // clear() forgets what was reported, like everything else.
      client.clear();
      pagesQuery().observe(client: client).subscribe((_) {});
      async.flushMicrotasks();
      expect(reported, hasLength(3));
    });

    fakeTest('an error it throws goes to the zone, after the one it got',
        (async) {
      final failing = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(
            onSuccess: (_, __) => throw StateError('onSuccess'),
          ),
        ),
        onUncaughtError: (error, _) => throw StateError('reporting'),
      );
      runZonedGuarded(() {
        failing.query(
          Query(queryKey: ['a'], queryFn: FakeFetcher(() => 'a').call),
        );
        async.elapse(ms10);
      }, (error, _) => zone.add(error));

      expect(zone.map((e) => '$e'), [
        'Bad state: onSuccess',
        'Bad state: reporting',
      ]);
      failing.clear();
    });
  });
}

Object? _same(String variables) => variables;

String _string(Object? json) => json! as String;
