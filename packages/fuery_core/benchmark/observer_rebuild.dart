// What a widget's build costs without Flutter: the definition is built
// again every time (same key, new closures) and passed to the observer,
// then the result is read. Each case runs N rebuilds.
import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

typedef Todo = Map<String, Object?>;

/// A definition as a widget builds it in every build: a new object with a
/// new query function closure each time.
Query<Todo> todoQuery(QueryKey key) => Query(
      queryKey: key,
      queryFn: (_) async => {'key': key, 'title': 'Todo'},
      staleTime: const Duration(minutes: 5),
    );

Future<void> main(List<String> args) async {
  final bench = Bench('observer_rebuild', args);

  final keys = <String, QueryKey Function()>{
    "['todos', 42]": () => ['todos', 42],
    "['posts', {page, sort, tags}]": () => [
          'posts',
          {
            'page': 3,
            'sort': 'new',
            'tags': ['a', 'b'],
          },
        ],
  };

  for (final MapEntry(key: keyName, value: keyOf) in keys.entries) {
    final client = QueryClient();
    client.setData(todoQuery(keyOf()), {'title': 'Todo'});

    // Not subscribed, as before a widget's first frame, and subscribed, as
    // a mounted widget.
    final idle = todoQuery(keyOf()).observe(client: client);
    final mounted = todoQuery(keyOf()).observe(client: client);
    final unsubscribe = mounted.subscribe((_) {});
    final slot = QuerySlot<Todo>(todoQuery(keyOf()), client);
    final stopSlot = slot.subscribe(notifyManager.batchCalls((_) {}));

    for (final n in [100, 1000, 10000]) {
      bench.section('key $keyName, N=$n rebuilds');

      bench.sync('setOptions(rebuilt definition), no listener', (count) {
        for (var i = 0; i < count; i++) {
          for (var j = 0; j < n; j++) {
            idle.setOptions(todoQuery(keyOf()));
          }
        }
      }, n: n, per: n, unit: 'rebuild');

      bench.sync('setOptions(rebuilt definition), subscribed', (count) {
        for (var i = 0; i < count; i++) {
          for (var j = 0; j < n; j++) {
            mounted.setOptions(todoQuery(keyOf()));
          }
        }
      }, n: n, per: n, unit: 'rebuild');

      bench.sync('getOptimisticResult(), no listener', (count) {
        Object? result;
        for (var i = 0; i < count; i++) {
          for (var j = 0; j < n; j++) {
            result = idle.getOptimisticResult();
          }
        }
        sink = result;
      }, n: n, per: n, unit: 'rebuild');

      bench.sync('getOptimisticResult(), subscribed', (count) {
        Object? result;
        for (var i = 0; i < count; i++) {
          for (var j = 0; j < n; j++) {
            result = mounted.getOptimisticResult();
          }
        }
        sink = result;
      }, n: n, per: n, unit: 'rebuild');

      bench.sync('QuerySlot.update + result, subscribed', (count) {
        Object? result;
        for (var i = 0; i < count; i++) {
          for (var j = 0; j < n; j++) {
            slot.update(todoQuery(keyOf()), client);
            result = slot.result;
          }
        }
        sink = result;
      }, n: n, per: n, unit: 'rebuild');
    }

    unsubscribe();
    stopSlot();
    slot.dispose();
    idle.destroy();
    await pump();
    client.clear();
  }
}
