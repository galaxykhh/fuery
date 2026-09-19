import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A storage that reads and writes synchronously.
class MemoryStorage implements QueryStorage {
  MemoryStorage([Map<String, String>? entries]) : entries = entries ?? {};

  final Map<String, String> entries;
  int reads = 0;
  int writes = 0;

  @override
  String? read(String key) {
    reads++;
    return entries[key];
  }

  @override
  void write(String key, String value) {
    writes++;
    entries[key] = value;
  }

  @override
  void delete(String key) => entries.remove(key);

  @override
  Map<String, String> readAll() => Map.of(entries);
}

/// Wraps a [MemoryStorage] and answers after a delay.
class AsyncStorage implements QueryStorage {
  AsyncStorage(
    this.inner, {
    this.readDelay = ms10,
    this.readAllDelay = ms10,
  });

  final MemoryStorage inner;
  final Duration readDelay;
  final Duration readAllDelay;

  @override
  Future<String?> read(String key) =>
      Future.delayed(readDelay, () => inner.read(key));

  @override
  Future<void> write(String key, String value) =>
      Future.delayed(ms10, () => inner.write(key, value));

  @override
  Future<void> delete(String key) =>
      Future.delayed(ms10, () => inner.delete(key));

  @override
  Future<Map<String, String>> readAll() =>
      Future.delayed(readAllDelay, inner.readAll);
}

/// A storage where every call fails, synchronously or asynchronously.
class FailingStorage implements QueryStorage {
  FailingStorage({this.async = false});

  final bool async;

  T _fail<T>() => throw StateError('storage is broken');

  FutureOr<T> _call<T>() => async ? Future<T>(_fail) : _fail();

  @override
  FutureOr<String?> read(String key) => _call();

  @override
  FutureOr<void> write(String key, String value) => _call();

  @override
  FutureOr<void> delete(String key) => _call();

  @override
  FutureOr<Map<String, String>> readAll() => _call();
}

String storageKey(QueryKey queryKey) => '$persistKeyPrefix${hashKey(queryKey)}';

/// A stored entry as Fuery writes it.
String entry(Object? data, {int version = 1, Duration age = Duration.zero}) {
  return jsonEncode({
    'v': version,
    't': clock.now().subtract(age).millisecondsSinceEpoch,
    'd': data,
  });
}

Object? stored(MemoryStorage storage, QueryKey queryKey) {
  final raw = storage.entries[storageKey(queryKey)];
  return raw == null ? null : (jsonDecode(raw) as Map)['d'];
}

final todosPersist = QueryPersist<List<String>>(
  toJson: (todos) => todos,
  fromJson: (json) => List<String>.from(json! as List),
);

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
    return Query.use(
      queryKey: queryKey,
      queryFn: fetcher.call,
      staleTime: staleTime,
      persist: persist ?? todosPersist,
      client: on ?? client,
    );
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
      Query.use(
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
        client: client,
      ).subscribe((_) {});
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
      Query.use(
        queryKey: ['plain'],
        queryFn: FakeFetcher(() => 'a').call,
        client: client,
      ).subscribe((_) {});

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
      final observer = Query.use(
        queryKey: ['todos'],
        queryFn: FakeFetcher(() => ['fetched']).call,
        client: client,
      );
      expect(observer.result.data, isNull);

      observer.setOptions(QueryOptions(
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

  group('infinite queries', () {
    InfiniteQueryObserver<String, int> pages(QueryClient on) {
      return InfiniteQuery.use(
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
        client: on,
      );
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
        return InfiniteQuery.use(
          queryKey: ['days'],
          queryFn: (context) async => 'day ${context.pageParam.day}',
          initialPageParam: DateTime.utc(2026, 9, 1),
          getNextPageParam: (data) => null,
          staleTime: const Duration(minutes: 1),
          persist: InfiniteQueryPersist(
            pageToJson: (page) => page,
            pageFromJson: (json) => json! as String,
            paramToJson: (date) => date.toIso8601String(),
            paramFromJson: (json) => DateTime.parse(json! as String),
          ),
          client: on,
        );
      }

      byDate(client).subscribe((_) {});
      async.flushMicrotasks();

      final restored = byDate(createClient());
      expect(restored.result.pages, ['day 1']);
      expect(restored.result.data!.pageParams, [DateTime.utc(2026, 9, 1)]);
    });
  });
}
