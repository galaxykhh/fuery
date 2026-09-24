import 'dart:async';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'storages.dart';

enum Sort { newest }

void main() {
  late MemoryStorage memory;
  late QueryClient client;
  final clients = <QueryClient>[];

  QueryClient createClient([QueryStorage? storage]) {
    final client = QueryClient(
      storage: storage ?? memory,
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    )..mount();
    clients.add(client);
    return client;
  }

  setUp(() {
    resetManagers();
    memory = MemoryStorage();
    client = createClient();
  });

  tearDown(() {
    for (final client in clients) {
      client.unmount();
      client.clear();
    }
    clients.clear();
  });

  QueryObserver<List<String>> todos(
    FakeFetcher<List<String>> fetcher, {
    QueryKey queryKey = const ['todos'],
    Duration? staleTime,
    QueryPersist<List<String>>? persist,
    QueryClient? on,
  }) {
    return Query(
      queryKey: queryKey,
      queryFn: fetcher.call,
      staleTime: staleTime,
      persist: persist ?? todosPersist,
    ).observe(client: on ?? client);
  }

  group('storing', () {
    fakeTest('stores fetched data', (async) {
      todos(FakeFetcher(() => ['a'])).subscribe((_) {});
      async.elapse(ms10);

      expect(stored(memory, ['todos']), ['a']);
    });

    fakeTest('stores data set by hand once per batch', (async) {
      todos(FakeFetcher(() => ['a'])).subscribe((_) {});
      async.elapse(ms10);
      memory.writes = 0;

      notifyManager.batch(() {
        client.setQueryData(['todos'], ['b']);
        client.setQueryData(['todos'], ['c']);
      });
      async.flushMicrotasks();

      expect(memory.writes, 1);
      expect(stored(memory, ['todos']), ['c']);
    });

    fakeTest('stores a streamed query once the stream is done', (async) {
      final controller = StreamController<String>();
      Query(
        queryKey: ['answer'],
        queryFn: streamedQuery(
          stream: (context) => controller.stream,
          initialValue: '',
          combine: (text, token) => text + token,
        ),
        persist: QueryPersist(
          toJson: (text) => text,
          fromJson: (json) => json! as String,
        ),
      ).observe(client: client).subscribe((_) {});
      async.flushMicrotasks();

      controller.add('a');
      async.flushMicrotasks();
      expect(stored(memory, ['answer']), isNull);

      controller
        ..add('b')
        ..close();
      async.flushMicrotasks();
      expect(stored(memory, ['answer']), 'ab');
    });

    fakeTest('stores nothing without persist or without a storage', (async) {
      Query(
        queryKey: ['plain'],
        queryFn: FakeFetcher(() => 'a').call,
      ).observe(client: client).subscribe((_) {});

      final noStorage = QueryClient();
      todos(FakeFetcher(() => ['a']), on: noStorage).subscribe((_) {});
      async.elapse(ms10);
      noStorage.restore();
      noStorage.clear();

      expect(memory.entries, isEmpty);
    });

    fakeTest('skips data that cannot be encoded', (async) {
      todos(
        FakeFetcher(() => ['a']),
        persist: QueryPersist(
          toJson: (todos) => DateTime(2026),
          fromJson: (json) => [],
        ),
      ).subscribe((_) {});
      async.elapse(ms10);

      expect(memory.entries, isEmpty);
    });
  });

  fakeTest('setData stores data before anything observes the query', (async) {
    final todos = Query(
      queryKey: ['todos'],
      queryFn: FakeFetcher(() => ['fetched']).call,
      persist: todosPersist,
    );
    client.setData(todos, ['offline']);
    async.flushMicrotasks();

    expect(stored(memory, ['todos']), ['offline']);
  });

  group('keys with enums', () {
    fakeTest('are stored without the enum type, and restored', (async) {
      todos(FakeFetcher(() => ['a']), queryKey: ['todos', Sort.newest])
          .subscribe((_) {});
      async.elapse(ms10);
      expect(memory.entries.keys, ['fuery:["todos","enum:newest"]']);

      final restarted = createClient();
      final observer = todos(
        FakeFetcher(() => ['fetched']),
        queryKey: ['todos', Sort.newest],
        staleTime: const Duration(minutes: 1),
        on: restarted,
      );
      expect(observer.result.data, ['a']);
    });

    fakeTest('are deleted with entries stored in the earlier form', (async) {
      memory.entries.addAll({
        'fuery:["todos","Sort.newest"]': entry(['old']),
        'fuery:["todos","enum:newest"]': entry(['new']),
      });

      client.removeQueries(queryKey: ['todos', Sort.newest], exact: true);
      async.flushMicrotasks();
      expect(memory.entries, isEmpty);

      memory.entries.addAll({
        'fuery:["todos","Sort.newest",1]': entry(['old']),
        'fuery:["todos","enum:newest",1]': entry(['new']),
      });
      client.removeQueries(queryKey: ['todos', Sort.newest]);
      async.flushMicrotasks();
      expect(memory.entries, isEmpty);
    });
  });

  group('restoring', () {
    fakeTest('restores synchronously before the first result', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final fetcher = FakeFetcher(() => ['fetched']);
      final observer = todos(fetcher, staleTime: const Duration(minutes: 1));

      expect(observer.result.data, ['stored']);
      expect(observer.result.isSuccess, isTrue);

      observer.subscribe((_) {});
      async.elapse(ms10);
      expect(fetcher.calls, 0);
    });

    fakeTest('shows stale restored data while it refetches', (async) {
      memory.entries[storageKey(['todos'])] =
          entry(['stored'], age: const Duration(hours: 1));
      final observer = todos(FakeFetcher(() => ['fetched']))..subscribe((_) {});

      expect(observer.result.data, ['stored']);
      expect(observer.result.isFetching, isTrue);

      async.elapse(ms10);
      expect(observer.result.data, ['fetched']);
      expect(stored(memory, ['todos']), ['fetched']);
    });

    fakeTest('waits for an async storage before fetching', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final fetcher = FakeFetcher(() => ['fetched']);
      final observer = todos(
        fetcher,
        staleTime: const Duration(minutes: 1),
        on: createClient(AsyncStorage(memory)),
      )..subscribe((_) {});
      async.flushMicrotasks();
      expect(observer.result.data, isNull);

      async.elapse(ms10);
      expect(observer.result.data, ['stored']);
      expect(fetcher.calls, 0);
    });

    fakeTest('fetches after an async restore finds stale or no data', (async) {
      memory.entries[storageKey(['todos'])] =
          entry(['stored'], age: const Duration(hours: 1));
      final asyncClient = createClient(AsyncStorage(memory));
      final stale = FakeFetcher(() => ['fetched']);
      final empty = FakeFetcher(() => ['fetched']);
      final observer = todos(stale, on: asyncClient)..subscribe((_) {});
      todos(empty, queryKey: ['other'], on: asyncClient).subscribe((_) {});

      async.elapse(ms10);
      expect(observer.result.data, ['stored']);
      async.elapse(ms10);
      expect(observer.result.data, ['fetched']);
      expect(stale.calls, 1);
      expect(empty.calls, 1);
    });

    fakeTest('an explicit refetch during a restore still fetches', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final fetcher = FakeFetcher(() => ['fetched']);
      final observer = todos(
        fetcher,
        staleTime: const Duration(minutes: 1),
        on: createClient(AsyncStorage(memory)),
      );

      observer.refetch();
      async.elapse(ms10 * 2);
      expect(fetcher.calls, 1);
      expect(observer.result.data, ['fetched']);
    });

    fakeTest('restores when a persist option is added later', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final observer = Query(
        queryKey: ['todos'],
        queryFn: FakeFetcher(() => ['fetched']).call,
      ).observe(client: client);
      expect(observer.result.data, isNull);

      observer.setOptions(Query(
        queryKey: ['todos'],
        queryFn: FakeFetcher(() => ['fetched']).call,
        persist: todosPersist,
      ));
      expect(observer.result.data, ['stored']);
    });

    fakeTest('restores while offline', (async) {
      onlineManager.setOnline(false);
      memory.entries[storageKey(['todos'])] =
          entry(['stored'], age: const Duration(hours: 1));
      final observer = todos(
        FakeFetcher(() => ['fetched']),
        on: createClient(AsyncStorage(memory)),
      )..subscribe((_) {});

      async.elapse(ms10);
      expect(observer.result.data, ['stored']);
      expect(observer.result.fetchStatus, FetchStatus.paused);
    });

    fakeTest('discards stored data that is outdated or unreadable', (async) {
      memory.entries.addAll({
        storageKey(['version']): entry(['old format']),
        storageKey(['expired']): entry(['a'], age: const Duration(days: 2)),
        storageKey(['short']): entry(['a'], age: const Duration(hours: 2)),
        storageKey(['corrupt']): 'not json',
        storageKey(['decode']): entry(42),
      });
      final observers = [
        todos(
          FakeFetcher(() => []),
          queryKey: ['version'],
          persist: QueryPersist(
            version: 2,
            toJson: (todos) => todos,
            fromJson: (json) => List<String>.from(json! as List),
          ),
        ),
        todos(FakeFetcher(() => []), queryKey: ['expired']),
        todos(
          FakeFetcher(() => []),
          queryKey: ['short'],
          persist: QueryPersist(
            maxAge: const Duration(hours: 1),
            toJson: (todos) => todos,
            fromJson: (json) => List<String>.from(json! as List),
          ),
        ),
        todos(FakeFetcher(() => []), queryKey: ['corrupt']),
        todos(FakeFetcher(() => []), queryKey: ['decode']),
      ];

      for (final observer in observers) {
        expect(observer.result.data, isNull);
      }
      expect(memory.entries, isEmpty);
    });

    fakeTest('keeps working when the storage fails', (async) {
      for (final storage in [FailingStorage(), FailingStorage(async: true)]) {
        final failing = createClient(storage);
        final observer = todos(FakeFetcher(() => ['a']), on: failing)
          ..subscribe((_) {});
        failing.restore();
        async.elapse(ms10 * 2);
        expect(observer.result.data, ['a']);

        failing.setQueryData(['todos'], ['b']);
        failing.removeQueries(queryKey: ['todos']);
        failing.clear();
        async.elapse(ms10);
      }
    });
  });

  group('restore', () {
    fakeTest('reads everything ahead of time', (async) {
      memory.entries.addAll({
        storageKey(['todos']): entry(['stored']),
        'other app': 'ignored',
      });
      final asyncClient = createClient(AsyncStorage(memory));

      asyncClient.restore();
      async.elapse(ms10);
      final observer = todos(FakeFetcher(() => []), on: asyncClient);

      expect(observer.result.data, ['stored']);
      expect(memory.reads, 0);
    });

    fakeTest('fills queries that are still reading', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final asyncClient = createClient(AsyncStorage(
        memory,
        readDelay: const Duration(seconds: 1),
      ));
      todos(FakeFetcher(() => []), on: asyncClient);

      asyncClient.restore();
      async.elapse(ms10);
      expect(asyncClient.getQueryData<List<String>>(['todos']), ['stored']);

      async.elapse(const Duration(seconds: 1));
      expect(asyncClient.getQueryData<List<String>>(['todos']), ['stored']);
    });

    fakeTest('deletes stored queries that have expired', (async) {
      final hour = QueryPersist<List<String>>(
        maxAge: const Duration(hours: 1),
        toJson: (todos) => todos,
        fromJson: (json) => List<String>.from(json! as List),
      );
      final unsubscribes = [
        todos(FakeFetcher(() => ['a']), queryKey: ['hour'], persist: hour),
        todos(FakeFetcher(() => ['b']), queryKey: ['day']),
      ].map((observer) => observer.subscribe((_) {})).toList();
      async.elapse(ms10);
      for (final unsubscribe in unsubscribes) {
        unsubscribe();
      }
      // Stored before entries recorded when they expire.
      memory.entries[storageKey(['legacy'])] =
          entry(['c'], age: const Duration(days: 30));
      async.elapse(const Duration(hours: 2));

      // The app starts again and never uses ['hour'].
      createClient().restore();
      async.flushMicrotasks();

      expect(
          memory.entries.keys,
          unorderedEquals([
            storageKey(['day']),
            storageKey(['legacy']),
          ]));
    });
  });

  group('deleting', () {
    setUp(() {
      memory.entries.addAll({
        storageKey(['todos']): entry(['all']),
        storageKey(['todos', 1]): entry(['one']),
        storageKey(['todos', 2]): entry(['two']),
        storageKey(['posts']): entry(['post']),
        'other app': 'kept',
      });
    });

    fakeTest('removeQueries deletes loaded and stored queries by key', (async) {
      client.restore();
      async.flushMicrotasks();
      todos(FakeFetcher(() => []), queryKey: ['todos', 1]);

      client.removeQueries(queryKey: ['todos']);
      expect(memory.entries.keys, [
        storageKey(['posts']),
        'other app'
      ]);

      final restored = todos(FakeFetcher(() => []), queryKey: ['todos', 2]);
      expect(restored.result.data, isNull);
    });

    fakeTest('an exact key deletes only that query', (async) {
      client.removeQueries(queryKey: ['todos'], exact: true);

      expect(memory.entries, isNot(contains(storageKey(['todos']))));
      expect(memory.entries, contains(storageKey(['todos', 1])));
    });

    fakeTest('other filters only delete loaded queries', (async) {
      todos(FakeFetcher(() => []), queryKey: ['todos', 1]);

      client.removeQueries(predicate: (query) => true);

      expect(memory.entries, isNot(contains(storageKey(['todos', 1]))));
      expect(memory.entries, contains(storageKey(['todos', 2])));
    });

    fakeTest('resetQueries deletes, then stores the refetched data', (async) {
      todos(FakeFetcher(() => ['fetched']), queryKey: ['todos', 1])
          .subscribe((_) {});
      async.elapse(ms10);

      client.resetQueries(queryKey: ['todos']);
      expect(memory.entries, isNot(contains(storageKey(['todos', 2]))));
      expect(stored(memory, ['todos', 1]), isNull);

      async.elapse(ms10);
      expect(stored(memory, ['todos', 1]), ['fetched']);
    });

    fakeTest('clear deletes every stored query and what restore read', (async) {
      final asyncClient = createClient(AsyncStorage(memory));
      asyncClient.restore();
      async.elapse(ms10);

      asyncClient.clear();
      todos(FakeFetcher(() => []), queryKey: ['todos', 1], on: asyncClient);
      asyncClient.setQueryData(['todos', 2], ['new']);
      async.elapse(ms10 * 5);

      expect(asyncClient.getQueryData<List<String>>(['todos', 1]), isNull);
      expect(memory.entries.keys, ['other app']);
    });

    fakeTest('data stored right after clear is kept', (async) {
      final asyncClient = createClient(AsyncStorage(memory));
      asyncClient.clear();
      todos(FakeFetcher(() => []), queryKey: ['todos', 1], on: asyncClient);
      asyncClient.setQueryData(['todos', 1], ['new']);
      async.elapse(ms10 * 5);

      expect(stored(memory, ['todos', 1]), ['new']);
    });

    fakeTest('a restore that is reading when clear runs is dropped', (async) {
      final asyncClient = createClient(AsyncStorage(memory));
      asyncClient.restore();
      asyncClient.clear();
      async.elapse(ms10 * 5);

      asyncClient.restore();
      async.elapse(ms10);
      todos(FakeFetcher(() => []), queryKey: ['todos', 1], on: asyncClient);
      async.elapse(ms10 * 5);

      expect(asyncClient.getQueryData<List<String>>(['todos', 1]), isNull);
    });

    fakeTest('a removed query does not write its data back', (async) {
      final observer = todos(FakeFetcher(() => []), queryKey: ['todos', 1]);

      client.setQueryData(['todos', 1], ['new']);
      client.removeQueries(queryKey: ['todos', 1]);
      async.flushMicrotasks();

      expect(observer.result.data, ['one']); // restored when it was created
      expect(memory.entries, isNot(contains(storageKey(['todos', 1]))));
    });

    fakeTest('garbage collection keeps stored data', (async) {
      final unsubscribe = todos(
        FakeFetcher(() => ['fetched']),
        queryKey: ['todos', 1],
      ).subscribe((_) {});
      async.elapse(ms10);

      unsubscribe();
      async.elapse(const Duration(minutes: 6));
      expect(client.queryCache.getAll(), isEmpty);

      final restored = todos(FakeFetcher(() => []), queryKey: ['todos', 1]);
      expect(restored.result.data, ['fetched']);
    });
  });

  group('races', () {
    fakeTest('resetQueries during an async read keeps the data deleted',
        (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final asyncClient = createClient(AsyncStorage(memory));
      todos(
        FakeFetcher(() => ['fetched'], delay: const Duration(seconds: 1)),
        staleTime: const Duration(minutes: 5),
        on: asyncClient,
      );

      asyncClient.resetQueries(queryKey: ['todos']);
      async.elapse(const Duration(milliseconds: 50));
      expect(memory.entries, isEmpty);
      expect(asyncClient.getQueryData<List<String>>(['todos']), isNull);
    });

    fakeTest('refetchOnMount applies to data restored asynchronously', (async) {
      memory.entries[storageKey(['fresh'])] = entry(['stored']);
      memory.entries[storageKey(['stale'])] =
          entry(['stored'], age: const Duration(minutes: 10));
      final asyncClient = createClient(AsyncStorage(memory));
      QueryObserver<List<String>> use(
        QueryKey queryKey,
        FakeFetcher<List<String>> fetcher,
        RefetchMode refetchOnMount,
      ) {
        return Query(
          queryKey: queryKey,
          queryFn: fetcher.call,
          staleTime: const Duration(minutes: 5),
          refetchOnMount: refetchOnMount,
          persist: todosPersist,
        ).observe(client: asyncClient);
      }

      final always = FakeFetcher(() => ['fetched']);
      final never = FakeFetcher(() => ['fetched']);
      use(['fresh'], always, RefetchMode.always).subscribe((_) {});
      use(['stale'], never, RefetchMode.never).subscribe((_) {});
      async.elapse(const Duration(milliseconds: 50));

      expect(always.calls, 1);
      expect(never.calls, 0);
      expect(asyncClient.getQueryData<List<String>>(['stale']), ['stored']);
    });

    fakeTest('client.query waits for an async read and uses fresh data',
        (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final asyncClient = createClient(AsyncStorage(memory));
      final fetcher = FakeFetcher(() => ['fetched']);
      List<String>? data;
      asyncClient
          .query(Query(
            queryKey: ['todos'],
            queryFn: fetcher.call,
            staleTime: const Duration(minutes: 5),
            persist: todosPersist,
          ))
          .then((value) => data = value);
      async.elapse(const Duration(milliseconds: 50));

      expect(data, ['stored']);
      expect(fetcher.calls, 0);
    });

    fakeTest('an invalidation during an async read is kept', (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final asyncClient = createClient(AsyncStorage(memory));
      todos(
        FakeFetcher(() => ['fetched']),
        staleTime: const Duration(minutes: 5),
        on: asyncClient,
      );

      asyncClient.invalidateQueries(queryKey: ['todos']);
      async.elapse(const Duration(milliseconds: 50));
      final state = asyncClient.getQueryState(['todos'])!;
      expect(state.data, ['stored']);
      expect(state.isInvalidated, isTrue);
    });

    fakeTest('a restore() snapshot does not come back over newer data',
        (async) {
      memory.entries[storageKey(['todos'])] = entry(['v1']);
      final asyncClient = createClient(AsyncStorage(memory));
      QueryObserver<List<String>> use({Duration? gcTime}) {
        return Query(
          queryKey: ['todos'],
          queryFn: FakeFetcher(() => ['fetched']).call,
          staleTime: const Duration(minutes: 5),
          gcTime: gcTime,
          persist: todosPersist,
        ).observe(client: asyncClient);
      }

      use(gcTime: const Duration(seconds: 1));
      async.elapse(ms10);
      expect(asyncClient.getQueryData<List<String>>(['todos']), ['v1']);

      asyncClient.restore();
      async.elapse(ms10);
      asyncClient.setQueryData(['todos'], ['v2']);
      async.elapse(ms10);
      async.elapse(const Duration(seconds: 2));
      expect(asyncClient.getQueryState(['todos']), isNull);

      use();
      async.elapse(const Duration(milliseconds: 50));
      expect(asyncClient.getQueryData<List<String>>(['todos']), ['v2']);
    });

    fakeTest('an observer moved by removeQueries loads instead of restoring',
        (async) {
      memory.entries[storageKey(['todos'])] = entry(['stored']);
      final fetcher = FakeFetcher(() => ['fetched']);
      final observer = todos(fetcher, staleTime: const Duration(minutes: 5));
      observer.subscribe((_) {});
      expect(observer.result.data, ['stored']);

      client.removeQueries(queryKey: ['todos']);
      async.elapse(ms10);
      expect(fetcher.calls, 1);
      expect(observer.result.data, ['fetched']);
    });
  });

  group('infinite queries', () {
    InfiniteQueryObserver<String, int> pages(QueryClient on) {
      return InfiniteQuery(
        queryKey: ['pages'],
        queryFn: (context) async => 'page ${context.pageParam}',
        initialPageParam: 1,
        getNextPageParam: (data) =>
            data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
        staleTime: const Duration(minutes: 1),
        persist: InfiniteQueryPersist(
          pageToJson: (page) => page,
          pageFromJson: (json) => json! as String,
        ),
      ).observe(client: on);
    }

    fakeTest('stores and restores pages and params', (async) {
      final observer = pages(client)..subscribe((_) {});
      async.flushMicrotasks();
      observer.fetchNextPage();
      async.flushMicrotasks();

      final restored = pages(createClient());
      expect(restored.result.pages, ['page 1', 'page 2']);
      expect(restored.result.data!.pageParams, [1, 2]);
      expect(restored.result.hasNextPage, isFalse);
    });

    fakeTest('uses codecs for params', (async) {
      InfiniteQueryObserver<String, DateTime> byDate(QueryClient on) {
        return InfiniteQuery(
          queryKey: ['days'],
          queryFn: (context) async => 'day ${context.pageParam.day}',
          initialPageParam: DateTime.utc(2026, 9, 1),
          getNextPageParam: (data) => null,
          staleTime: const Duration(minutes: 1),
          persist: InfiniteQueryPersist(
            pageToJson: (page) => page,
            pageFromJson: (json) => json! as String,
            paramToJson: (date) => (date! as DateTime).toIso8601String(),
            paramFromJson: (json) => DateTime.parse(json! as String),
          ),
        ).observe(client: on);
      }

      byDate(client).subscribe((_) {});
      async.flushMicrotasks();

      final restored = byDate(createClient());
      expect(restored.result.pages, ['day 1']);
      expect(restored.result.data!.pageParams, [DateTime.utc(2026, 9, 1)]);
    });
  });
}
