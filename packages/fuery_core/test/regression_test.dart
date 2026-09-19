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

  fakeTest('a failing scoped mutation only reports to its caller', (async) {
    Future<String> run(String value) async {
      await Future<void>.delayed(ms10);
      if (value == 'b') throw StateError('boom');
      return value;
    }

    final first = Mutation.use(
      mutationFn: run,
      scope: const MutationScope('s'),
      client: client,
    );
    final second = Mutation.use(
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

    expect(() => client.setQueryData(['todos'], []), throwsStateError);
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
    final query = Query.use(
      queryKey: ['paused'],
      queryFn: FakeFetcher(() => 'a').call,
      client: client,
    );
    final mutation = Mutation.use(
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

    expect(async.pendingTimers, isEmpty);
  });
}
