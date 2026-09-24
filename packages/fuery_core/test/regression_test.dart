// Regression tests for cache, refetch, and mutation edge cases.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:fuery_core/src/utils.dart' show storageHash;
import 'package:test/test.dart';

import 'helpers.dart';
import 'storages.dart';

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
    fakeTest('a cancelled dependency fails the query that awaited it', (async) {
      final errors = <Object>[];
      final reporting = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(onError: (error, _) => errors.add(error)),
        ),
      );
      final user = Query(
        queryKey: ['user'],
        queryFn: FakeFetcher(() => 'alice').call,
      );
      final posts = Query(
        queryKey: ['posts'],
        queryFn: (context) async => ['by ${await context.client.query(user)}'],
        retry: const RetryPolicy.never(),
      ).observe(client: reporting);
      final unsubscribe = posts.subscribe((_) {});
      async.flushMicrotasks();

      reporting.cancelQueries(queryKey: ['user']);
      async.flushMicrotasks();
      expect(posts.result.isFetching, isFalse);
      expect(posts.result.error, isA<CancelledError>());
      expect(reporting.isFetching(), 0);
      expect(errors.single, isA<CancelledError>());

      unsubscribe();
      reporting.clear();
      async.elapse(ms10);
    });

    fakeTest('a dependency removed mid-fetch fails the query that awaited it',
        (async) {
      final user = Query(
        queryKey: ['user'],
        queryFn: FakeFetcher(() => 'alice').call,
      );
      final posts = Query(
        queryKey: ['posts'],
        queryFn: (context) async => ['by ${await context.client.query(user)}'],
        retry: const RetryPolicy.never(),
      ).observe(client: client);
      final unsubscribe = posts.subscribe((_) {});
      async.flushMicrotasks();

      client.removeQueries(queryKey: ['user']);
      async.flushMicrotasks();
      expect(posts.result.isFetching, isFalse);
      expect(posts.result.isError, isTrue);
      expect(client.isFetching(), 0);

      unsubscribe();
      async.elapse(ms10);
    });
  });

  group('retry timers', () {
    test('the default retry delay stays at 30 seconds after many failures', () {
      final error = StateError('down');
      for (final count in [5, 53, 54, 55, 64, 100, 1024]) {
        expect(defaultRetryDelay(count, error), const Duration(seconds: 30));
      }
    });

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
      expect(callbackError, isNull);
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
      final called = <String>[];
      final mutation = Mutation(
        mutationFn: (int x) async => x,
        onMutate: (_, __) async {
          await Future<void>.delayed(ms10);
          return 'context';
        },
        onError: (error, x, context, client) {
          called.add('onError');
        },
        onSettled: (data, error, x, context, client) {
          called.add('onSettled');
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
      expect(called, isEmpty);
      expect(async.pendingTimers, isEmpty);
      unsubscribe();
    });

    fakeTest('clear() runs no callback of a mutation it drops', (async) {
      // The optimistic update the rollback would undo was cleared too, so
      // the rollback wrote the cleared session's data back into the cache
      // and the storage.
      final called = <String>[];
      final storage = MemoryStorage();
      final persisted = QueryClient(
        storage: storage,
        mutationCache: MutationCache(
          config: MutationCacheConfig(
            onError: (error, variables, context, mutation) {
              called.add('cache onError');
            },
            onSettled: (data, error, variables, context, mutation) {
              called.add('cache onSettled');
            },
          ),
        ),
      )..mount();
      final todos = Query(
        queryKey: ['todos'],
        queryFn: (_) async => ['a', 'b'],
        staleTime: const Duration(minutes: 5),
        persist: QueryPersist(
          toJson: (todos) => todos,
          fromJson: (json) => [
            for (final todo in json! as List<Object?>) todo! as String,
          ],
        ),
      );
      persisted.query(todos).ignore();
      async.flushMicrotasks();
      expect(storage.entries, isNotEmpty);

      onlineManager.setOnline(false);
      final deleteTodo = Mutation(
        mutationFn: (String id) async => id,
        onMutate: (id, client) {
          final previous = client.getData(todos);
          client.updateData(
            todos,
            (list) => list?.where((todo) => todo != id).toList(),
          );
          return previous;
        },
        onError: (error, id, previous, client) {
          called.add('onError');
          if (previous != null) client.setData(todos, previous);
        },
        onSettled: (data, error, id, previous, client) {
          called.add('onSettled');
        },
      ).observe(client: persisted);
      final unsubscribe = deleteTodo.subscribe((_) {});
      Object? error;
      deleteTodo
          .mutateAsync(
        'a',
        MutateOptions(
          onError: (error, id, previous, client) {
            called.add('call onError');
          },
          onSettled: (data, error, id, previous, client) {
            called.add('call onSettled');
          },
        ),
      )
          .then<void>((_) {}, onError: (Object e) {
        error = e;
      });
      async.flushMicrotasks();
      expect(deleteTodo.result.isPaused, isTrue);

      persisted.clear();
      async.flushMicrotasks();
      expect(error, isA<CancelledError>());
      expect(deleteTodo.result.isError, isTrue);
      expect(persisted.getData(todos), isNull);
      expect(storage.entries, isEmpty);
      expect(async.pendingTimers, isEmpty);
      expect(called, isEmpty);
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

  fakeTest('isFetchedAfterMount counts from a reset', (async) {
    final fetcher = FakeFetcher(() => 'todos');
    client.query(Query(queryKey: ['todos'], queryFn: fetcher.call)).ignore();
    async.elapse(ms10);
    final todos = Query(
      queryKey: ['todos'],
      queryFn: fetcher.call,
      staleTime: infiniteDuration,
    ).observe(client: client);
    final unsubscribe = todos.subscribe((_) {});
    async.flushMicrotasks();
    expect(todos.result.isFetchedAfterMount, isFalse);

    // For example, after logging out.
    client.resetQueries(queryKey: ['todos']);
    expect(todos.result.isFetchedAfterMount, isFalse);
    expect(todos.result.isPending, isTrue);
    expect(todos.result.isFetching, isTrue);

    async.elapse(ms10);
    expect(todos.result.isFetchedAfterMount, isTrue);
    expect(fetcher.calls, 2);
    unsubscribe();
  });

  group('data written by key', () {
    fakeTest('refetches skip it until a Query for the key is used', (async) {
      final errors = <Object>[];
      final reporting = QueryClient(
        queryCache: QueryCache(
          config: QueryCacheConfig(onError: (error, _) => errors.add(error)),
        ),
      );
      reporting.setQueryData(['todo', 1], 'seeded');

      var refetched = false;
      reporting
          .refetchQueries(throwOnError: true)
          .then((_) => refetched = true);
      async.flushMicrotasks();
      expect(refetched, isTrue);

      var invalidated = false;
      reporting
          .invalidateQueries(refetchType: RefetchType.all, throwOnError: true)
          .then((_) => invalidated = true);
      async.flushMicrotasks();
      expect(invalidated, isTrue);

      final state = reporting.getQueryState(['todo', 1])!;
      expect(state.status, QueryStatus.success);
      expect(state.fetchStatus, FetchStatus.idle);
      expect(state.data, 'seeded');
      expect(state.errorUpdateCount, 0);
      expect(state.isInvalidated, isTrue);
      expect(errors, isEmpty);

      final todo = Query(
        queryKey: ['todo', 1],
        queryFn: FakeFetcher(() => 'fetched').call,
      ).observe(client: reporting);
      final unsubscribe = todo.subscribe((_) {});
      async.elapse(ms10);
      expect(todo.result.data, 'fetched');
      unsubscribe();
      reporting.clear();
    });

    fakeTest('an observer listening to it brings its query function', (async) {
      final fetcher = FakeFetcher(() => 'fetched');
      // Created at startup. Its query is collected before anything listens,
      // and the data comes back by key.
      final todo = Query(
        queryKey: ['todo', 1],
        queryFn: fetcher.call,
        staleTime: infiniteDuration,
      ).observe(client: client);
      async.elapse(const Duration(minutes: 5));
      client.setQueryData(['todo', 1], 'seeded');
      final unsubscribe = todo.subscribe((_) {});
      async.flushMicrotasks();
      expect(fetcher.calls, 0);

      client.invalidateQueries(queryKey: ['todo', 1]);
      async.elapse(ms10);
      expect(fetcher.calls, 1);
      expect(todo.result.data, 'fetched');
      unsubscribe();
    });
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

    group('page param functions and callbacks that throw', () {
      // A page param function that throws while a result is built, or an
      // observer callback that throws, has no caller to receive the error.
      // Before, it left observers loading and failed the fetch that caused
      // the update.
      late List<Object> uncaught;
      late List<Object> cacheErrors;
      late QueryClient client;

      setUp(() {
        uncaught = [];
        cacheErrors = [];
        client = QueryClient(
          queryCache: QueryCache(
            config: QueryCacheConfig(
              onError: (error, _) => cacheErrors.add(error),
            ),
          ),
          onUncaughtError: (error, _) => uncaught.add(error),
        )..mount();
      });

      tearDown(() {
        client.unmount();
        client.clear();
      });

      InfiniteQueryObserver<List<int>, int> feed({
        List<int> Function(int param)? page,
        Object? Function(InfiniteData<List<int>, int> data)? previous,
      }) {
        return InfiniteQuery(
          queryKey: ['feed'],
          queryFn: (context) async => (page ??
              (param) => param == 0 ? [1, 2] : <int>[])(context.pageParam),
          initialPageParam: 0,
          // Throws "No element" on an empty page.
          getNextPageParam: (data) => data.lastPage.last + 1,
          getPreviousPageParam: previous,
        ).observe(client: client);
      }

      fakeTest('a next page param that throws on an empty page is no page',
          (async) {
        final observer = feed();
        observer.subscribe((_) {});
        async.flushMicrotasks();
        expect(observer.result.hasNextPage, isTrue);

        InfiniteQueryResult<List<int>, int>? fetched;
        Object? rejected;
        observer.fetchNextPage().then<void>((result) {
          fetched = result;
        }, onError: (Object error) {
          rejected = error;
        });
        async.flushMicrotasks();

        expect(rejected, isNull);
        expect(fetched!.pages, [
          [1, 2],
          <int>[],
        ]);
        expect(observer.result.fetchStatus, FetchStatus.idle);
        expect(observer.result.isSuccess, isTrue);
        expect(observer.result.data!.pageParams, [0, 3]);
        expect(observer.result.hasNextPage, isFalse);

        // Results are built again with the same data.
        observer.fetchNextPage();
        observer.refetch();
        async.flushMicrotasks();
        expect(uncaught, [isA<StateError>()]);
        expect(cacheErrors, isEmpty);
      });

      fakeTest('an empty first page loads with no next page', (async) {
        final observer = feed(page: (_) => []);
        observer.subscribe((_) {});
        async.flushMicrotasks();

        expect(observer.result.isSuccess, isTrue);
        expect(observer.result.fetchStatus, FetchStatus.idle);
        expect(observer.result.pages, [<int>[]]);
        expect(observer.result.hasNextPage, isFalse);
        expect(uncaught, [isA<StateError>()]);
        expect(cacheErrors, isEmpty);
      });

      fakeTest('a previous page param that throws is no page', (async) {
        final observer = feed(previous: (_) => throw StateError('previous'));
        observer.subscribe((_) {});
        async.flushMicrotasks();

        expect(observer.result.isSuccess, isTrue);
        expect(observer.result.hasPreviousPage, isFalse);
        expect(observer.result.hasNextPage, isTrue);

        InfiniteQueryResult<List<int>, int>? fetched;
        observer.fetchPreviousPage().then((result) => fetched = result);
        async.flushMicrotasks();
        expect(fetched!.pages, [
          [1, 2]
        ]);
        expect(uncaught.map((error) => (error as StateError).message),
            ['previous']);
        expect(cacheErrors, isEmpty);
      });

      fakeTest('a refetchWhile that throws leaves the fetch successful',
          (async) {
        final posts = Query(
          queryKey: ['posts'],
          queryFn: FakeFetcher(() => 'posts').call,
          refetchInterval: const Duration(minutes: 1),
          refetchWhile: (result) {
            if (result.data != null) throw StateError('refetchWhile');
            return true;
          },
        ).observe(client: client);
        final other = Query(
          queryKey: ['posts'],
          queryFn: FakeFetcher(() => 'posts').call,
        ).observe(client: client);
        posts.subscribe((_) {});
        final results = <QueryResult<String>>[];
        other.subscribe(results.add);
        async.elapse(ms10);

        final query =
            client.queryCache.find(QueryFilters(queryKey: ['posts']))!;
        expect(query.state.status, QueryStatus.success);
        expect(query.state.fetchStatus, FetchStatus.idle);
        expect(posts.result.data, 'posts');
        expect(results.last.data, 'posts');
        expect(uncaught.map((error) => (error as StateError).message),
            ['refetchWhile']);
        expect(cacheErrors, isEmpty);
        posts.destroy();
        other.destroy();
      });

      fakeTest('a page param that throws while pages load fails the fetch',
          (async) {
        Object? rejected;
        client
            .infiniteQuery(InfiniteQuery(
          queryKey: ['feed'],
          queryFn: (context) async => [context.pageParam],
          initialPageParam: 0,
          getNextPageParam: (_) => throw StateError('next'),
          pages: 2,
        ))
            .then<void>((_) {}, onError: (Object error) {
          rejected = error;
        });
        async.flushMicrotasks();

        expect((rejected! as StateError).message, 'next');
        expect(cacheErrors, [rejected]);
        expect(uncaught, isEmpty);
      });
    });

    group('a write while a page loads', () {
      // A page used to be added to the pages cached when the fetch started,
      // so an update made while it loaded, such as a like, was lost.
      const second = Duration(seconds: 1);
      final feed = InfiniteQuery(
        queryKey: ['feed'],
        queryFn: (context) async {
          await Future<void>.delayed(second);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.lastPageParam + 1,
        getPreviousPageParam: (data) => data.firstPageParam - 1,
      );

      InfiniteQueryObserver<String, int> load(FakeAsync async) {
        final observer = feed.observe(client: client);
        observer.subscribe((_) {});
        async.elapse(second);
        return observer;
      }

      void like() {
        client.updateData(
          feed,
          (data) => data?.mapPages((page) => '$page, liked'),
        );
      }

      fakeTest('is kept by fetchNextPage', (async) {
        final observer = load(async);
        observer.fetchNextPage();
        async.elapse(second ~/ 2);
        like();
        async.elapse(second);

        expect(observer.result.pages, ['page 0, liked', 'page 1']);
        expect(observer.result.data!.pageParams, [0, 1]);
      });

      fakeTest('is kept by fetchPreviousPage', (async) {
        final observer = load(async);
        observer.fetchPreviousPage();
        async.elapse(second ~/ 2);
        like();
        async.elapse(second);

        expect(observer.result.pages, ['page -1', 'page 0, liked']);
        expect(observer.result.data!.pageParams, [-1, 0]);
      });

      fakeTest('that changes the loaded pages is replaced', (async) {
        final observer = load(async);
        observer.fetchNextPage();
        async.elapse(second ~/ 2);
        client.setData(
          feed,
          const InfiniteData(pages: ['other'], pageParams: [5]),
        );
        async.elapse(second);

        expect(observer.result.pages, ['page 0', 'page 1']);
        expect(observer.result.data!.pageParams, [0, 1]);
      });
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

  fakeTest('a key read with another data type is rejected clearly', (async) {
    // What `client.setQueryData(['todos'], [])` writes.
    client.setQueryData(['todos'], <dynamic>[]);
    final todos = Query(queryKey: ['todos'], queryFn: (_) async => <String>[]);

    expect(() => client.getData(todos), throwsStateError);
    expect(
      () => client.getQueryData<List<String>>(['todos']),
      throwsStateError,
    );
    var updated = false;
    List<String>? update(List<String>? previous) {
      updated = true;
      return previous;
    }

    expect(() => client.updateData(todos, update), throwsStateError);
    expect(
      () => client.updateQueryData<List<String>>(['todos'], update),
      throwsStateError,
    );
    expect(updated, isFalse);
    // A wider type still reads it.
    expect(client.getQueryData<Object>(['todos']), isEmpty);
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

  group('listeners that throw', () {
    late List<Object> uncaught;
    late QueryClient client;

    setUp(() {
      uncaught = [];
      client = QueryClient(
        onUncaughtError: (error, _) => uncaught.add(error),
      )..mount();
    });

    tearDown(() {
      client.unmount();
      client.clear();
    });

    fakeTest('a listener that throws leaves the rest of its observer', (async) {
      // A listener that throws used to skip the observer's later listeners
      // and its timers. An equal result later returned early, so they
      // never caught up.
      final posts = Query(
        queryKey: ['posts'],
        queryFn: FakeFetcher(() => 'posts').call,
        staleTime: const Duration(minutes: 1),
      ).observe(client: client);
      var thrown = false;
      posts.subscribe((result) {
        if (result.data == null || thrown) return;
        thrown = true;
        throw StateError('listener');
      });
      final results = <QueryResult<String>>[];
      posts.subscribe(results.add);
      final rendered = <QueryResult<String>>[];
      final slot = QuerySlot(posts, client);
      slot.subscribe(notifyManager.batchCalls(rendered.add));
      async.elapse(ms10);

      expect(results.last.data, 'posts');
      expect(rendered.last.data, 'posts');
      expect(
          uncaught.map((error) => (error as StateError).message), ['listener']);

      async.elapse(const Duration(minutes: 2));
      expect(results.last.isStale, isTrue);
      expect(rendered.last.isStale, isTrue);
      slot.dispose();
      posts.destroy();
    });

    fakeTest('a slot listener that throws leaves the other listeners', (async) {
      final slot = QuerySlot(
        Query(
          queryKey: ['posts'],
          queryFn: FakeFetcher(() => 'posts').call,
        ),
        client,
      );
      slot.subscribe((result) {
        if (result.data != null) throw StateError('listener');
      });
      final results = <QueryResult<String>>[];
      slot.subscribe(results.add);
      async.elapse(ms10);

      expect(results.last.data, 'posts');
      expect(
          uncaught.map((error) => (error as StateError).message), ['listener']);
      slot.dispose();
    });

    fakeTest('a QueriesSlot listener that throws leaves the other listeners',
        (async) {
      // It used to stop the push, so a listen added later never heard the
      // change, and the error reached the zone.
      final post = Query(
        queryKey: ['post'],
        queryFn: (_) async => 'post',
        staleTime: infiniteDuration,
      );
      client.setQueryData(['post'], 'post');
      final slot = QueriesSlot([post], client);
      slot.subscribe((_) => throw StateError('listener'));
      final pushed = <String?>[];
      slot.subscribe((results) => pushed.add(results.single.data));
      final heard = <(String?, String?)>[];
      slot.listen((previous, current) {
        heard.add((previous.single.data, current.single.data));
      });

      client.setQueryData(['post'], 'edited');
      async.flushMicrotasks();
      expect(pushed, ['edited']);
      expect(heard, [('post', 'edited')]);
      expect(
          uncaught.map((error) => (error as StateError).message), ['listener']);
      slot.dispose();
    });
  });

  fakeTest('a throwing listener leaves the rest of its batch notified',
      (async) {
    final count = Query(
      queryKey: ['count'],
      queryFn: (_) async => 0,
      staleTime: infiniteDuration,
    );
    client.setQueryData(['count'], 0);
    final watched = <int?>[];
    final pushed = <int?>[];
    final errors = <Object>[];
    runZonedGuarded(() {
      final unsubscribe = count.observe(client: client).subscribe(
        notifyManager.batchCalls((QueryResult<int> result) {
          if (result.data == 1) throw StateError('listener');
        }),
      );
      final watching = client
          .watch((client) => client.getQueryData<int>(['count']))
          .listen(watched.add);
      final slot = QueriesSlot([count], client);
      final unsubscribeSlot =
          slot.subscribe((results) => pushed.add(results.single.data));
      async.flushMicrotasks();

      for (final value in [1, 2, 3]) {
        client.setQueryData(['count'], value);
        async.flushMicrotasks();
      }
      unsubscribe();
      unsubscribeSlot();
      slot.dispose();
      watching.cancel();
    }, (error, _) => errors.add(error));

    // Watch streams and QueriesSlot schedule one update at a time, so a
    // dropped update used to stop them for good.
    expect(watched.last, 3);
    expect(pushed.last, 3);
    expect(errors.single, isA<StateError>());
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
