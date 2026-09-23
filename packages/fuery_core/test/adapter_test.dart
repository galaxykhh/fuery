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
        pages.subscribe((_) {});
        async.flushMicrotasks();
        pages.fetchNextPage();
        async.flushMicrotasks();
        pages.setOptions(pagesQuery());
        pages.setOptions(pagesQuery());
        async.flushMicrotasks();

        expect(pages.result.pages, [1]);
        expect(pages.result.hasNextPage, isFalse);
        expect(pages.result.hasPreviousPage, isFalse);
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
