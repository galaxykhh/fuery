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

  fakeTest('emits the current value, then each change', (async) {
    final values = <int>[];
    final subscription =
        client.watch((client) => client.isFetching()).listen(values.add);
    async.flushMicrotasks();
    expect(values, [0]);

    final unsubscribe = Query.observe(
      queryKey: ['todos'],
      queryFn: FakeFetcher(() => 'todos').call,
      client: client,
    ).subscribe((_) {});
    async.flushMicrotasks();
    expect(values, [0, 1]);

    async.elapse(ms10);
    expect(values, [0, 1, 0]);

    unsubscribe();
    subscription.cancel();
  });

  fakeTest('compares collections by content', (async) {
    final values = <List<String>?>[];
    client
        .watch((client) => client
            .getQueryData<List<String>>(['todos'])
            ?.where((todo) => todo.startsWith('a'))
            .toList())
        .listen(values.add);
    async.flushMicrotasks();
    expect(values, [null]);

    client.setQueryData(['todos'], ['a1', 'b1']);
    async.flushMicrotasks();
    expect(values, [
      null,
      ['a1'],
    ]);

    client.setQueryData(['todos'], ['a1', 'b2']);
    async.flushMicrotasks();
    expect(values, hasLength(2));

    client.setQueryData(['todos'], ['a1', 'a2']);
    async.flushMicrotasks();
    expect(values.last, ['a1', 'a2']);
  });

  fakeTest('computes once for changes made in one batch', (async) {
    final values = <int>[];
    client
        .watch((client) => client.queryCache.getAll().length)
        .listen(values.add);
    async.flushMicrotasks();

    notifyManager.batch(() {
      client.setQueryData(['a'], 'a');
      client.setQueryData(['b'], 'b');
    });
    async.flushMicrotasks();
    expect(values, [0, 2]);
  });

  fakeTest('follows mutations', (async) {
    final values = <int>[];
    client.watch((client) => client.isMutating()).listen(values.add);
    final addTodo = Mutation.observe(
      mutationFn: (String title) async {
        await Future<void>.delayed(ms10);
        return title;
      },
      client: client,
    );

    addTodo.mutate('Buy milk');
    async.elapse(ms10);
    expect(values, [0, 1, 0]);
  });

  fakeTest('reports selector errors and keeps watching', (async) {
    final values = <int>[];
    final errors = <Object>[];
    var fail = true;
    client.watch((client) {
      if (fail) throw StateError('not ready');
      return client.queryCache.getAll().length;
    }).listen(values.add, onError: errors.add);
    async.flushMicrotasks();
    expect(errors, [isA<StateError>()]);
    expect(values, isEmpty);

    fail = false;
    client.setQueryData(['a'], 'a');
    async.flushMicrotasks();
    expect(values, [1]);
  });

  fakeTest('emits a value equal to the last one after an error', (async) {
    final values = <int>[];
    final errors = <Object>[];
    var fail = false;
    client.watch((client) {
      if (fail) throw StateError('not ready');
      return 1;
    }).listen(values.add, onError: errors.add);
    async.flushMicrotasks();

    fail = true;
    client.setQueryData(['a'], 'a');
    async.flushMicrotasks();
    fail = false;
    client.setQueryData(['a'], 'b');
    async.flushMicrotasks();

    expect(errors, hasLength(1));
    expect(values, [1, 1]);
  });

  fakeTest('stops listening to the client when cancelled', (async) {
    var reads = 0;
    final subscription = client.watch((client) {
      reads++;
      return client.isFetching();
    }).listen((_) {});
    async.flushMicrotasks();

    subscription.cancel();
    client.setQueryData(['a'], 'a');
    Mutation.observe(mutationFn: (int x) async => x, client: client).mutate(1);
    async.flushMicrotasks();
    expect(reads, 1);
  });
}
