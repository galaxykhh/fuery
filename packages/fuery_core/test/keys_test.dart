// Keys that observers, slots, and filters compare: whatever they skip
// hashing for, they reach the query or run that hashing the key finds.
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

enum Sort { newest, oldest }

class Page {
  const Page(this.number);
  final int number;
  Map<String, Object?> toJson() => {'number': number};
}

/// Keys built again on every call, as a widget builds them, including keys
/// of other types that hash the same, and keys that only look alike.
final samples = <QueryKey Function()>[
  () => [],
  () => ['todos'],
  () => [
        ['todos'],
      ],
  () => ['todos', 1],
  () => ['todos', '1'],
  () => ['todos', 1.0],
  () => ['todos', 1.5],
  () => ['todos', 0],
  () => ['todos', -0.0],
  () => ['todos', null],
  () => ['todos', true],
  () => ['todos', false],
  () => ['todos', Sort.newest],
  () => ['todos', Sort.oldest],
  () => ['todos', 'Sort.newest'],
  () => [
        'todos',
        [1, 2],
      ],
  () => [
        'todos',
        [2, 1],
      ],
  () => [
        'todos',
        {1, 2},
      ],
  () => [
        'todos',
        {'page': 1, 'sort': 'new'},
      ],
  () => [
        'todos',
        {'sort': 'new', 'page': 1},
      ],
  () => [
        'todos',
        {'page': 1},
      ],
  () => [
        'todos',
        {1: 'a'},
      ],
  () => [
        'todos',
        {'1': 'a'},
      ],
  () => ['todos', DateTime.utc(2026, 1, 2)],
  () => ['todos', '2026-01-02T00:00:00.000Z'],
  () => ['todos', const Page(1)],
  () => [
        'todos',
        {'number': 1},
      ],
];

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

  Query<String> todos(QueryKey key) {
    return Query(
      queryKey: key,
      queryFn: (_) async => '$key',
      staleTime: infiniteDuration,
    );
  }

  Mutation<String, String, Object?> save(QueryKey? key) {
    return Mutation(
      mutationKey: key,
      mutationFn: (title) async {
        await Future<void>.delayed(ms10);
        return title;
      },
    );
  }

  group('a query observer', () {
    test('reaches the query of the hash of every new key', () {
      for (final before in samples) {
        for (final after in samples) {
          final observer = todos(before()).observe(client: client);
          observer.setOptions(todos(after()));
          final hash = hashKey(after());
          expect(observer.options.queryHash, hash, reason: '${after()}');
          expect(observer.currentQuery.queryHash, hash);
          observer.setOptions(todos(after()));
          expect(observer.currentQuery.queryHash, hash);
        }
      }
    });

    fakeTest('follows a key changed in place', (async) {
      final filter = <String, Object?>{'page': 1};
      final key = <Object?>['todos', filter];
      final observer = todos(key).observe(client: client);
      observer.subscribe((_) {});
      async.flushMicrotasks();

      filter['page'] = 2;
      observer.setOptions(todos(key));
      expect(
        observer.currentQuery.queryHash,
        hashKey([
          'todos',
          {'page': 2},
        ]),
      );
      async.flushMicrotasks();
      expect(observer.result.data, '[todos, {page: 2}]');

      key[0] = 'posts';
      observer.setOptions(todos(key));
      expect(
        observer.currentQuery.queryHash,
        hashKey([
          'posts',
          {'page': 2},
        ]),
      );

      filter['page'] = 3;
      observer.setOptions(todos(['posts', filter]));
      expect(
        observer.currentQuery.queryHash,
        hashKey([
          'posts',
          {'page': 3},
        ]),
      );
      observer.destroy();
    });
  });

  group('a QueriesSlot', () {
    test('reaches the query of the hash of every new key', () {
      for (final before in samples) {
        for (final after in samples) {
          final slot = QueriesSlot([todos(before())], client);
          slot.update([todos(after())], client);
          final hash = hashKey(after());
          expect(slot.observer.single.options.queryHash, hash);
          slot.update([todos(after())], client);
          expect(slot.observer.single.options.queryHash, hash);
          slot.dispose();
        }
      }
    });

    fakeTest('follows a key changed in place', (async) {
      final first = <Object?>['todos', 1];
      final second = <Object?>['todos', 2];
      final slot = QueriesSlot([todos(first), todos(second)], client);
      slot.update([todos(first), todos(second)], client);
      final observers = slot.observer;

      first[1] = 3;
      slot.update([todos(first), todos(second)], client);
      expect(identical(slot.observer.first, observers.first), isFalse);
      expect(identical(slot.observer.last, observers.last), isTrue);
      expect(
        slot.observer.first.options.queryHash,
        hashKey(['todos', 3]),
      );

      // The key a slot had at an index can move to another one.
      second[1] = 3;
      final moved = todos(['todos', 2]);
      slot.update([moved, todos(second)], client);
      expect(slot.observer.first.options.queryHash, hashKey(['todos', 2]));
      expect(slot.observer.last.options.queryHash, hashKey(['todos', 3]));
      slot.dispose();
    });

    fakeTest('reuses the hash a shared observer had at the index', (async) {
      final shared = todos(['todos', 1]).observe(client: client);
      final slot = QueriesSlot([shared], client);
      final definition = todos(['todos', 1]);
      slot.update([definition], client);
      expect(identical(slot.observer.single, shared), isFalse);
      expect(slot.observer.single.options.queryHash, hashKey(['todos', 1]));
      slot.dispose();
    });
  });

  group('a mutation observer', () {
    fakeTest('resets only for a key of another hash', (async) {
      for (final before in samples) {
        for (final after in samples) {
          final observer = save(before()).observe(client: client);
          observer.mutate('a');
          async.flushMicrotasks();
          observer.setOptions(save(after()));
          expect(
            observer.result.isIdle,
            hashKey(before()) != hashKey(after()),
            reason: '${before()} to ${after()}',
          );
          async.elapse(ms10);
        }
      }
    });

    fakeTest('reports a new key as a change, but not a key built again',
        (async) {
      // A watcher whose value changes on every read counts the changes.
      var reads = 0;
      final subscription = client.watch((_) => reads++).listen((_) {});
      addTearDown(subscription.cancel);
      async.flushMicrotasks();
      var seen = reads;
      int changes() {
        async.flushMicrotasks();
        final count = reads - seen;
        seen = reads;
        return count;
      }

      final observer = save([
        'todos',
        {'page': 1, 'sort': 'new'},
      ]).observe(client: client);
      changes();

      observer.setOptions(save([
        'todos',
        {'sort': 'new', 'page': 1},
      ]));
      expect(changes(), 0);
      observer.setOptions(save(['todos', 1.5]));
      expect(changes(), 1);
      observer.setOptions(save(['todos', 1.5]));
      expect(changes(), 0);
      observer.setOptions(save(null));
      expect(changes(), 1);
      observer.setOptions(save(null));
      expect(changes(), 0);
      observer.setOptions(save(['todos']));
      expect(changes(), 1);
    });

    fakeTest('keeps its run when the key is changed in place', (async) {
      final key = <Object?>['todos', 1];
      final observer = save(['other']).observe(client: client);
      // A new key is hashed.
      observer.setOptions(save(key));
      observer.mutate('a');
      async.elapse(ms10);

      key[1] = 2;
      observer.setOptions(save(key));
      expect(observer.result.data, 'a');

      // The list holds another key now than when it was hashed.
      observer.setOptions(save(['todos', 1]));
      expect(observer.result.isIdle, isTrue);
    });

    fakeTest('throws for a key it cannot hash once options change', (async) {
      final unhashable = [Object()];
      final observer = save(unhashable).observe(client: client);
      expect(() => observer.setOptions(save(unhashable)), throwsArgumentError);

      final keyless = save(null).observe(client: client);
      expect(() => keyless.setOptions(save(unhashable)), throwsArgumentError);
      expect(() => keyless.setOptions(save(null)), throwsArgumentError);
    });
  });

  group('the filters', () {
    fakeTest('follow the key a pending run gets from its observer', (async) {
      int matching(QueryKey key, {bool exact = false}) {
        return client.mutationCache
            .findAll(MutationFilters(mutationKey: key, exact: exact))
            .length;
      }

      final slot = MutationStateSlot(save(['todos', 'b']), client);
      final observer = save(['todos', 'a']).observe(client: client);
      observer.mutate('a');
      async.flushMicrotasks();
      expect(matching(['todos']), 1);
      expect(matching(['todos', 'a'], exact: true), 1);

      // Without a key in between, the key can change to one of another
      // hash while the run is pending.
      observer.setOptions(save(null));
      expect(matching(['todos']), 0);
      expect(matching(['todos', 'a'], exact: true), 0);

      observer.setOptions(save(['todos', 'b']));
      expect(matching(['todos', 'a']), 0);
      expect(matching(['todos', 'a'], exact: true), 0);
      expect(matching(['todos', 'b']), 1);
      expect(matching(['todos', 'b'], exact: true), 1);
      expect(slot.result.single.isPending, isTrue);

      // A key built again matches the same.
      observer.setOptions(save(['todos', 'b']));
      expect(matching(['todos', 'b'], exact: true), 1);
      async.elapse(ms10);
      expect(slot.result.single.data, 'a');
      expect(client.isMutating(mutationKey: ['todos']), 0);
      slot.dispose();
    });
  });
}
