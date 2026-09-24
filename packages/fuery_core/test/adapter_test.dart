// What an adapter, such as a Flutter widget or a hook, needs from the core.
// Everything here uses only the public API, so any adapter can do what the
// Fuery widgets do.
import 'dart:async';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A minimal adapter: it renders a query source on every "frame", the way a
/// widget's build or a hook would, and records what it rendered.
class RenderLoop<TData extends Object> {
  RenderLoop(QuerySource<TData> source, this.client)
      : slot = QuerySlot(source, client) {
    unsubscribe = slot.subscribe((result) => pushed.add(result));
  }

  final QueryClient client;
  final QuerySlot<TData> slot;
  final rendered = <QueryResult<TData>>[];
  final pushed = <QueryResult<TData>>[];
  late final void Function() unsubscribe;

  QueryResult<TData> render(QuerySource<TData> source, [QueryClient? on]) {
    slot.update(source, on ?? client);
    final result = slot.result;
    rendered.add(result);
    return result;
  }

  void dispose() {
    unsubscribe();
    slot.dispose();
  }
}

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

  Query<String> post(int id) => Query(
        queryKey: ['post', id],
        queryFn: (_) async {
          await Future<void>.delayed(ms10);
          return 'post $id';
        },
        placeholderData: keepPreviousData,
      );

  group('QuerySlot', () {
    fakeTest('renders a definition built again on every frame', (async) {
      final loop = RenderLoop(post(1), client);
      expect(loop.render(post(1)).isLoading, isTrue);
      async.elapse(ms10);
      expect(loop.render(post(1)).data, 'post 1');

      // The observer stays, so keepPreviousData has the previous key's data.
      final observer = loop.slot.observer;
      final next = loop.render(post(2));
      expect(identical(loop.slot.observer, observer), isTrue);
      expect(next.data, 'post 1');
      expect(next.isPlaceholderData, isTrue);

      async.elapse(ms10);
      expect(loop.render(post(2)).data, 'post 2');
      expect(loop.pushed.last.data, 'post 2');
      loop.dispose();
    });

    fakeTest('reports the new key in the same frame', (async) {
      client.setQueryData(['post', 1], 'post 1');
      client.setQueryData(['post', 2], 'post 2');
      final loop = RenderLoop(post(1), client);
      loop.render(post(1));

      expect(loop.render(post(2)).data, 'post 2');
      loop.dispose();
    });

    fakeTest('uses a shared observer as it is, and leaves it alone', (async) {
      final shared = post(1).observe(client: client);
      final keep = shared.subscribe((_) {});
      final loop = RenderLoop<String>(shared, client);
      async.elapse(ms10);

      expect(identical(loop.slot.observer, shared), isTrue);
      expect(loop.render(shared).data, 'post 1');
      loop.dispose();
      expect(shared.result.data, 'post 1');
      keep();
    });

    fakeTest('switches between definitions and observers', (async) {
      final loop = RenderLoop(post(1), client);
      final owned = loop.slot.observer;
      async.elapse(ms10);

      // To a shared observer: the owned one is destroyed, and the
      // subscription moves along.
      final shared = post(2).observe(client: client);
      loop.render(shared);
      expect(identical(loop.slot.observer, shared), isTrue);
      async.elapse(ms10);
      expect(loop.pushed.last.data, 'post 2');

      // Back to a definition: a new owned observer.
      loop.render(post(3));
      expect(identical(loop.slot.observer, owned), isFalse);
      expect(identical(loop.slot.observer, shared), isFalse);
      async.elapse(ms10);
      expect(loop.pushed.last.data, 'post 3');
      loop.dispose();
    });

    fakeTest('creates a new observer for a new client', (async) {
      final other = QueryClient(
        defaultOptions: const DefaultOptions(
          queries: QueryDefaults(retry: RetryPolicy.never()),
        ),
      );
      other.setQueryData(['post', 1], 'from the other client');
      final loop = RenderLoop(post(1), client);
      final first = loop.slot.observer;

      expect(loop.render(post(1), other).data, 'from the other client');
      expect(identical(loop.slot.observer, first), isFalse);
      loop.dispose();
      other.clear();
    });

    fakeTest('switching without listeners does not subscribe', (async) {
      final slot = QuerySlot(post(1), client);
      slot.update(post(1).observe(client: client), client);
      async.elapse(ms10);

      expect(client.getQueryData<String>(['post', 1]), isNull);
      slot.dispose();
    });
  });

  group('QueriesSlot', () {
    fakeTest('renders a list of queries that changes on every frame', (async) {
      client.setQueryData(['post', 1], 'post 1');
      final slot = QueriesSlot([post(1), post(2)], client);
      final pushed = <List<QueryResult<String>>>[];
      final unsubscribe = slot.subscribe(pushed.add);

      expect(slot.result.map((result) => result.data), ['post 1', null]);
      expect(slot.result[1].isLoading, isTrue);
      async.elapse(ms10);
      // Both results arrive together, in the order of the queries.
      expect(pushed.last.map((result) => result.data), ['post 1', 'post 2']);
      final first = slot.result;
      expect(identical(slot.result, first), isTrue);

      // A new order keeps the observers of the keys that stay.
      final observers = slot.observer;
      slot.update([post(2), post(1)], client);
      expect(slot.result.map((result) => result.data), ['post 2', 'post 1']);
      expect(slot.observer, [observers[1], observers[0]]);

      // A removed key's observer goes, a new key's arrives.
      slot.update([post(2), post(3)], client);
      expect(identical(slot.observer.first, observers[1]), isTrue);
      async.elapse(ms10);
      expect(pushed.last.map((result) => result.data), ['post 2', 'post 3']);

      // The same query twice gets two observers, and a shared observer is
      // used as it is.
      final shared = post(4).observe(client: client);
      slot.update([post(2), post(2), shared], client);
      expect(slot.observer, hasLength(3));
      expect(identical(slot.observer.last, shared), isTrue);
      async.elapse(ms10);
      expect(slot.result.map((result) => result.data),
          ['post 2', 'post 2', 'post 4']);

      unsubscribe();
      slot.dispose();
    });

    fakeTest('results always act on the query now in their place', (async) {
      // Pending results are equal by value, whatever query they belong to.
      final slot = QueriesSlot([post(1), post(2)], client);
      final before = slot.result;
      slot.update([post(2), post(1)], client);
      final after = slot.result;

      expect(identical(after, before), isFalse);
      // Refetching the first result reaches post 2's observer, not post 1's.
      QueryResult<String>? refetched;
      after.first.refetch().then((result) => refetched = result);
      async.elapse(ms10);
      expect(refetched!.data, 'post 2');
      slot.dispose();
      expect(slot.observer, isEmpty);
    });

    fakeTest('disposing while listened to stops the pushes', (async) {
      final slot = QueriesSlot([post(1)], client);
      final pushed = <List<QueryResult<String>>>[];
      slot.subscribe(pushed.add);
      slot.dispose();
      async.elapse(ms10);

      expect(pushed, isEmpty);
      expect(slot.result, isEmpty);
    });

    fakeTest('an empty list renders nothing', (async) {
      final slot = QueriesSlot<String>([], client);
      expect(slot.result, isEmpty);
      slot.update([post(1)], client);
      expect(slot.result.single.isPending, isTrue);
      slot.dispose();
    });
  });

  group('InfiniteQuerySlot', () {
    InfiniteQuery<String, int> pages() => InfiniteQuery(
          queryKey: ['pages'],
          queryFn: (context) async => 'page ${context.pageParam}',
          initialPageParam: 1,
          getNextPageParam: (data) =>
              data.lastPageParam < 3 ? data.lastPageParam + 1 : null,
        );

    fakeTest('renders pages and loads more from the result', (async) {
      final slot = InfiniteQuerySlot(pages(), client);
      final pushed = <InfiniteQueryResult<String, int>>[];
      final unsubscribe = slot.subscribe(pushed.add);
      async.flushMicrotasks();

      slot.update(pages(), client);
      slot.result.fetchNextPage();
      async.flushMicrotasks();
      expect(slot.result.pages, ['page 1', 'page 2']);
      expect(pushed.last.hasNextPage, isTrue);

      final shared = pages().observe(client: client);
      slot.update(shared, client);
      expect(identical(slot.observer, shared), isTrue);
      unsubscribe();
      slot.dispose();
    });
  });

  group('MutationSlot', () {
    Mutation<int, int, void> add() => Mutation(mutationFn: (x) async => x + 1);

    fakeTest('runs the mutation from its result', (async) {
      final slot = MutationSlot(add(), client);
      final pushed = <MutationResult<int, int, void>>[];
      final unsubscribe = slot.subscribe(pushed.add);

      slot.update(add(), client);
      slot.result.mutate(1);
      async.flushMicrotasks();
      expect(slot.result.data, 2);
      expect(pushed.last.data, 2);

      final shared = add().observe(client: client);
      slot.update(shared, client);
      expect(identical(slot.observer, shared), isTrue);
      unsubscribe();
      slot.dispose();
    });
  });

  group('listen', () {
    // Fresh for good, so subscribing fetches nothing when data is cached.
    Query<String> fresh(int id) => Query(
          queryKey: ['post', id],
          queryFn: (_) async {
            await Future<void>.delayed(ms10);
            return 'post $id';
          },
          staleTime: infiniteDuration,
        );

    /// Listens to [slot] and records each change as the data before and
    /// after it.
    List<(String?, String?)> dataHeard(QuerySlot<String> slot) {
      final heard = <(String?, String?)>[];
      slot.listen((previous, current) {
        heard.add((previous.data, current.data));
      });
      return heard;
    }

    fakeTest('hears later changes, never the result it starts from', (async) {
      final fetcher = FakeFetcher(() => 'post 1');
      final slot = QuerySlot(
        Query(queryKey: ['post', 1], queryFn: fetcher.call),
        client,
      );
      final start = slot.result;
      final heard = <(QueryResult<String>, QueryResult<String>)>[];
      final stop = slot.listen((previous, current) {
        heard.add((previous, current));
      });

      // Listening subscribes, so the query fetches. The start of the fetch
      // is the result it started from, so it isn't a change.
      expect(fetcher.calls, 1);
      expect(start.isFetching, isTrue);
      async.flushMicrotasks();
      expect(heard, isEmpty);

      async.elapse(ms10);
      expect(heard, hasLength(1));
      expect(heard.single.$1, start);
      expect(heard.single.$2.data, 'post 1');

      // Never synchronous, and previous is the last result delivered.
      client.setQueryData(['post', 1], 'edited');
      expect(heard, hasLength(1));
      async.flushMicrotasks();
      expect(
        [
          for (final (previous, current) in heard) (previous.data, current.data)
        ],
        [(null, 'post 1'), ('post 1', 'edited')],
      );

      // The last stop unsubscribes the observer.
      stop();
      expect(slot.observer.hasListeners, isFalse);
      slot.dispose();
    });

    fakeTest('delivers at the end of the outer batch', (async) {
      client.setQueryData(['post', 1], 'post 1');
      final slot = QuerySlot(fresh(1), client);
      final heard = dataHeard(slot);

      notifyManager.batch(() {
        client.setQueryData(['post', 1], 'edited');
        async.flushMicrotasks();
        expect(heard, isEmpty);
      });
      async.flushMicrotasks();
      expect(heard, [('post 1', 'edited')]);
      slot.dispose();
    });

    fakeTest('hears a new key of a definition with the same observer', (async) {
      client.setQueryData(['post', 1], 'post 1');
      client.setQueryData(['post', 2], 'post 2');
      final slot = QuerySlot(fresh(1), client);
      final heard = dataHeard(slot);
      final observer = slot.observer;

      slot.update(fresh(2), client);
      expect(identical(slot.observer, observer), isTrue);
      expect(slot.result.data, 'post 2');
      expect(heard, isEmpty);
      async.flushMicrotasks();
      expect(heard, [('post 1', 'post 2')]);
      slot.dispose();
    });

    fakeTest('does not hear a move to another observer', (async) {
      final other = QueryClient();
      for (final id in [1, 2, 3]) {
        client.setQueryData(['post', id], 'post $id');
      }
      other.setQueryData(['post', 3], 'other post 3');
      final slot = QuerySlot(fresh(1).observe(client: client), client);
      final heard = dataHeard(slot);

      // To another shared observer.
      slot.update(fresh(2).observe(client: client), client);
      async.flushMicrotasks();
      expect(heard, isEmpty);
      client.setQueryData(['post', 2], 'post 2!');
      async.flushMicrotasks();
      expect(heard, [('post 2', 'post 2!')]);

      // From an observer to a definition.
      slot.update(fresh(3), client);
      async.flushMicrotasks();
      expect(heard, hasLength(1));
      client.setQueryData(['post', 3], 'post 3!');
      async.flushMicrotasks();
      expect(heard.last, ('post 3', 'post 3!'));

      // To another client.
      slot.update(fresh(3), other);
      async.flushMicrotasks();
      expect(heard, hasLength(2));
      other.setQueryData(['post', 3], 'other post 3!');
      async.flushMicrotasks();
      expect(heard.last, ('other post 3', 'other post 3!'));
      slot.dispose();
      other.clear();
    });

    fakeTest('drops what the observer it left had queued', (async) {
      client.setQueryData(['post', 1], 'post 1');
      client.setQueryData(['post', 2], 'post 2');
      final slot = QuerySlot(fresh(1), client);
      final heard = dataHeard(slot);

      client.setQueryData(['post', 1], 'post 1!');
      slot.update(fresh(2).observe(client: client), client);
      async.flushMicrotasks();
      expect(heard, isEmpty);
      slot.dispose();
    });

    fakeTest('stops, also for a change already queued', (async) {
      client.setQueryData(['post', 1], 'post 1');
      final slot = QuerySlot(fresh(1), client);
      final heard = <String?>[];
      final stop = slot.listen((previous, current) {
        heard.add('stopped ${current.data}');
      });
      slot.listen((previous, current) => heard.add(current.data));

      client.setQueryData(['post', 1], 'edited');
      stop();
      stop();
      async.flushMicrotasks();
      expect(heard, ['edited']);
      expect(slot.observer.hasListeners, isTrue);

      // Disposing drops the queued changes of every listener.
      client.setQueryData(['post', 1], 'edited again');
      slot.dispose();
      async.flushMicrotasks();
      expect(heard, ['edited']);
    });

    fakeTest('reports a listener that throws to the client', (async) {
      final errors = <Object>[];
      final reporting = QueryClient(
        onUncaughtError: (error, _) => errors.add(error),
      )..setQueryData(['post', 1], 'post 1');
      final slot = QuerySlot(fresh(1), reporting);
      slot.listen((previous, current) => throw StateError('sync'));
      slot.listen((previous, current) async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('async');
      });
      final heard = dataHeard(slot);

      reporting.setQueryData(['post', 1], 'edited');
      async.elapse(Duration.zero);
      expect(
        errors.map((error) => '$error'),
        ['Bad state: sync', 'Bad state: async'],
      );
      expect(heard, [('post 1', 'edited')]);
      slot.dispose();
      reporting.clear();
    });

    fakeTest('MutationSlot hears the runs of its result', (async) {
      Mutation<int, int, void> add(String key) => Mutation(
            mutationKey: [key],
            mutationFn: (x) async => x + 1,
          );
      final slot = MutationSlot(add('a'), client);
      final heard = <(MutationStatus, MutationStatus)>[];
      slot.listen((previous, current) {
        heard.add((previous.status, current.status));
      });

      slot.result.mutate(1);
      async.flushMicrotasks();
      expect(heard, [
        (MutationStatus.idle, MutationStatus.pending),
        (MutationStatus.pending, MutationStatus.success),
      ]);

      // A new mutationKey resets the observer to idle.
      slot.update(add('b'), client);
      async.flushMicrotasks();
      expect(heard.last, (MutationStatus.success, MutationStatus.idle));
      slot.dispose();
    });

    fakeTest('InfiniteQuerySlot hears new pages', (async) {
      final slot = InfiniteQuerySlot(
        InfiniteQuery(
          queryKey: ['pages'],
          queryFn: (context) async => 'page ${context.pageParam}',
          initialPageParam: 1,
          getNextPageParam: (data) => data.lastPageParam + 1,
        ),
        client,
      );
      final heard = <int>[];
      slot.listen((previous, current) {
        if (previous.pages.length != current.pages.length) {
          heard.add(current.pages.length);
        }
      });
      async.flushMicrotasks();

      slot.result.fetchNextPage();
      async.flushMicrotasks();
      expect(heard, [1, 2]);
      slot.dispose();
    });

    fakeTest('QueriesSlot hears new lists, but not a new observer in it',
        (async) {
      final errors = <Object>[];
      final reporting = QueryClient(
        onUncaughtError: (error, _) => errors.add(error),
      )..setQueryData(['post', 1], 'post 1');
      final slot = QueriesSlot([fresh(1)], reporting);
      String describe(List<QueryResult<String>> results) =>
          results.map((result) => result.data).join(', ');
      final heard = <String>[];
      slot.listen((previous, current) {
        heard.add('${describe(previous)} > ${describe(current)}');
      });
      slot.listen((previous, current) => throw StateError('listener'));

      reporting.setQueryData(['post', 1], 'post 1!');
      async.flushMicrotasks();
      expect(heard, ['post 1 > post 1!']);
      expect(errors, [isA<StateError>()]);

      // A change pushed before a query is added is dropped, and so is the
      // move to the new list of observers.
      reporting.setQueryData(['post', 1], 'post 1!!');
      scheduleMicrotask(() => slot.update([fresh(1), fresh(2)], reporting));
      async.flushMicrotasks();
      expect(heard, hasLength(1));

      async.elapse(ms10);
      expect(heard.last, 'post 1!!, null > post 1!!, post 2');
      slot.dispose();
      reporting.clear();
    });
  });

  test('observers expose the client they use, to check a shared one', () {
    final other = QueryClient();
    final query = post(1).observe(client: other);
    final infinite = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async => 'page ${context.pageParam}',
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    ).observe(client: client);
    final mutation = Mutation(mutationFn: (int x) async => x).observe(
      client: other,
    );

    // An adapter compares them with the client it uses itself.
    expect(identical(query.client, other), isTrue);
    expect(identical(infinite.client, client), isTrue);
    expect(identical(mutation.client, other), isTrue);
    expect(identical(post(2).observe().client, Fuery.client), isTrue);
    other.clear();
    Fuery.client.clear();
  });

  group('results act on their query', () {
    fakeTest('QueryResult.refetch', (async) {
      final fetcher = FakeFetcher(() => 'todos');
      final todos = Query(queryKey: ['todos'], queryFn: fetcher.call)
          .observe(client: client);
      todos.subscribe((_) {});
      async.elapse(ms10);

      QueryResult<String>? refetched;
      todos.result.refetch().then((result) => refetched = result);
      async.elapse(ms10);
      expect(fetcher.calls, 2);
      expect(refetched!.data, 'todos');
    });

    fakeTest('InfiniteQueryResult pages and refetch', (async) {
      final pages = InfiniteQuery(
        queryKey: ['pages'],
        queryFn: (context) async => context.pageParam,
        initialPageParam: 2,
        getNextPageParam: (data) => data.lastPageParam + 1,
        getPreviousPageParam: (data) =>
            data.firstPageParam > 1 ? data.firstPageParam - 1 : null,
      ).observe(client: client);
      pages.subscribe((_) {});
      async.flushMicrotasks();

      pages.result.fetchNextPage();
      async.flushMicrotasks();
      pages.result.fetchPreviousPage();
      async.flushMicrotasks();
      expect(pages.result.pages, [1, 2, 3]);

      InfiniteQueryResult<int, int>? refetched;
      pages.result.refetch().then((result) => refetched = result);
      async.flushMicrotasks();
      expect(refetched!.pages, [1, 2, 3]);
    });

    fakeTest('MutationResult runs and resets', (async) {
      final add =
          Mutation(mutationFn: (int x) async => x + 1).observe(client: client);

      int? data;
      add.result.mutateAsync(1).then((value) => data = value);
      async.flushMicrotasks();
      expect(data, 2);

      add.result.mutate(2);
      async.flushMicrotasks();
      expect(add.result.data, 3);

      add.result.reset();
      expect(add.result.isIdle, isTrue);
      expect(identical(add.result, add.result), isTrue);
    });

    test('a result made by hand has no query to act on', () {
      const result = QueryResult<String>(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        data: null,
        dataUpdatedAt: 0,
        error: null,
        errorUpdatedAt: 0,
        errorUpdateCount: 0,
        failureCount: 0,
        failureReason: null,
        isFetched: false,
        isFetchedAfterMount: false,
        isPlaceholderData: false,
        isStale: true,
        isEnabled: true,
      );
      expect(result.refetch, throwsStateError);
    });
  });

  group('callbacks get the client', () {
    fakeTest('mutation callbacks and mutate options', (async) {
      final other = QueryClient();
      final seen = <QueryClient>[];
      final add = Mutation(
        mutationFn: (int x) async => x,
        onMutate: (x, client) => seen.add(client),
        onSuccess: (data, x, context, client) => seen.add(client),
        onSettled: (data, error, x, context, client) => seen.add(client),
      ).observe(client: other);
      final unsubscribe = add.subscribe((_) {});
      add.mutate(
        1,
        MutateOptions(onSuccess: (data, x, context, client) {
          seen.add(client);
        }),
      );
      async.flushMicrotasks();

      expect(seen, [other, other, other, other]);
      unsubscribe();
      other.clear();
    });

    fakeTest('placeholderData', (async) {
      final other = QueryClient();
      other.setQueryData(['list'], ['a', 'b']);
      final item = Query(
        queryKey: ['item', 'b'],
        queryFn: (_) async {
          await Future<void>.delayed(ms10);
          return 'b from the server';
        },
        placeholderData: (previous, client) => client
            .getQueryData<List<String>>(['list'])?.firstWhere(
                (item) => item == 'b'),
      ).observe(client: other);

      expect(item.result.data, 'b');
      expect(item.result.isPlaceholderData, isTrue);
      expect(keepPreviousData('kept'), 'kept');
      other.clear();
    });
  });

  group('InfiniteQuery checks the page params it gets', () {
    fakeTest('from getNextPageParam and getPreviousPageParam', (async) {
      final errors = <Object>[];
      // Built again on every render, as in a widget's build.
      InfiniteQuery<int, int> pagesQuery() => InfiniteQuery(
            queryKey: ['pages'],
            queryFn: (context) async => context.pageParam,
            initialPageParam: 1,
            getNextPageParam: (data) => 'two',
            getPreviousPageParam: (data) => 'zero',
          );
      runZonedGuarded(() {
        final pages = pagesQuery().observe(client: client);
        final unsubscribe = pages.subscribe((_) {});
        async.flushMicrotasks();
        pages.fetchNextPage();
        async.flushMicrotasks();
        pages.setOptions(pagesQuery());
        pages.setOptions(pagesQuery());
        async.flushMicrotasks();

        expect(pages.result.pages, [1]);
        expect(pages.result.hasNextPage, isFalse);
        expect(pages.result.hasPreviousPage, isFalse);
        unsubscribe();
      }, (error, _) => errors.add(error));

      // Reported once per function and key, however often the result or
      // the definition is built.
      expect(errors.map((e) => '$e'), [
        contains('getNextPageParam returned String, but the page params'),
        contains('getPreviousPageParam returned String'),
      ]);
    });
  });
}
