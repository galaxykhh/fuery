// QueriesSlot with N queries, as a widget showing one query per item uses
// it: updates on rebuild, reorder, and key change, reading the result, and
// the push when one query changes.
import 'dart:async';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

typedef Item = Map<String, Object?>;

Item item(int id, [int version = 0]) =>
    {'id': id, 'title': 'Item $id', 'version': version};

Query<Item> itemQuery(int id) => Query(
      queryKey: ['items', id],
      queryFn: (_) async => item(id),
      staleTime: infiniteDuration,
    );

/// A list of definitions as a widget builds it: new objects every time.
List<Query<Item>> build(List<int> ids) => [for (final id in ids) itemQuery(id)];

Future<void> main(List<String> args) async {
  final bench = Bench('queries_slot', args);

  for (final n in [100, 500, 1000, 10000]) {
    bench.section('N=$n queries, all cached');
    final client = QueryClient();
    final ids = [for (var id = 0; id < n; id++) id];
    // The same ids with the middle one replaced by a new key.
    final changedIds = [...ids]..[n ~/ 2] = n;
    final reversedIds = ids.reversed.toList();
    for (var id = 0; id <= n; id++) {
      client.setData(itemQuery(id), item(id));
    }

    QueriesSlot<Item>? created;
    bench.each(
      'create and subscribe',
      () => build(ids),
      (queries) => created = QueriesSlot(queries, client)..subscribe((_) {}),
      teardown: (_) => created!.dispose(),
      n: n,
      per: n,
      unit: 'query',
    );
    await pump();

    var heard = 0;
    var done = Completer<void>();
    final slot = QueriesSlot(build(ids), client);
    slot.subscribe((_) {
      heard++;
      if (!done.isCompleted) done.complete();
    });
    await pump();

    // Rebuilt definitions are made beforehand, so the time is the slot's.
    final rebuilt = [build(ids), build(ids)];
    bench.sync('update, same keys, rebuilt definitions', (count) {
      for (var i = 0; i < count; i++) {
        slot.update(rebuilt[i & 1], client);
      }
    }, n: n, per: n, unit: 'query');

    bench.sync('result, read as a build does', (count) {
      Object? result;
      for (var i = 0; i < count; i++) {
        result = slot.result;
      }
      sink = result;
    }, n: n, per: n, unit: 'query');

    final reorders = [build(reversedIds), build(ids)];
    bench.sync('update, list reversed', (count) {
      for (var i = 0; i < count; i++) {
        slot.update(reorders[i & 1], client);
      }
    }, n: n, per: n, unit: 'query');
    slot.update(build(ids), client);

    final keyChanges = [build(changedIds), build(ids)];
    bench.sync('update, one key changed', (count) {
      for (var i = 0; i < count; i++) {
        slot.update(keyChanges[i & 1], client);
      }
    }, n: n, per: n, unit: 'query');
    slot.update(build(ids), client);
    await pump();

    // One query changes; the time runs until the slot's listener gets the
    // combined result.
    final middle = itemQuery(n ~/ 2);
    var version = 0;
    await bench.eachAsync(
      'push after setData on one query',
      () {
        heard = 0;
        done = Completer<void>();
      },
      (_) {
        client.setData(middle, item(n ~/ 2, ++version));
        return done.future;
      },
      n: n,
    );
    if (heard != 1) throw StateError('Expected one push, got $heard');

    // A push reads the result of every query that hasn't pushed since the
    // last update. Once every query has pushed, it reads none.
    for (var id = 0; id < n; id++) {
      client.setData(itemQuery(id), item(id, 1));
    }
    await pump();
    await bench.eachAsync(
      'push, after every query pushed once',
      () {
        heard = 0;
        done = Completer<void>();
      },
      (_) {
        client.setData(middle, item(n ~/ 2, ++version));
        return done.future;
      },
      n: n,
    );

    // The same change heard by one QuerySlot, for comparison.
    final single = QuerySlot<Item>(itemQuery(n ~/ 2), client);
    single.subscribe(notifyManager.batchCalls((_) {
      if (!done.isCompleted) done.complete();
    }));
    slot.dispose();
    await pump();
    await bench.eachAsync(
      'reference: the same change, one QuerySlot',
      () => done = Completer<void>(),
      (_) {
        client.setData(middle, item(n ~/ 2, ++version));
        return done.future;
      },
      n: n,
    );
    single.dispose();
    await pump();
    client.clear();
  }
}
