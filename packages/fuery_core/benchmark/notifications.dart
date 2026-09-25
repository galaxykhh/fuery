// N observers subscribed across M queries. One notifyManager.batch writes
// every query, and the time runs until the last listener has run.
import 'dart:async';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

/// How a listener hears of a result.
enum Kind {
  /// `observer.subscribe(listener)`: called synchronously, during the write.
  sync,

  /// `observer.subscribe(notifyManager.batchCalls(listener))`, as adapters
  /// that can't update during a render do: one microtask per call, after
  /// the batch.
  batched,

  /// `observer.stream.listen(listener)`.
  stream,
}

Query<int> counterQuery(int id) => Query(
      queryKey: ['counter', id],
      queryFn: (_) async => 0,
      staleTime: infiniteDuration,
    );

Future<void> main(List<String> args) async {
  final bench = Bench('notifications', args);

  for (final n in [100, 1000, 10000]) {
    for (final m in {1, 10, n}) {
      bench.section('N=$n observers across M=$m queries '
          '(${n ~/ m} per query)');
      final client = QueryClient();
      final queries = [for (var id = 0; id < m; id++) counterQuery(id)];
      var value = 0;
      for (final query in queries) {
        client.setData(query, value);
      }

      void writeAll() {
        value++;
        notifyManager.batch(() {
          for (final query in queries) {
            client.setData(query, value);
          }
        });
      }

      bench.sync('setData on the M queries, no observers', (count) {
        for (var i = 0; i < count; i++) {
          writeAll();
        }
      }, n: n);

      // Mounting: creating and subscribing N observers, then unsubscribing
      // them, with the M queries already cached.
      final observers = <QueryObserver<int>>[];
      bench.each(
        'observe() N observers',
        () => observers.clear(),
        (_) {
          for (var i = 0; i < n; i++) {
            observers.add(queries[i % m].observe(client: client));
          }
        },
        n: n,
        per: n,
        unit: 'observer',
      );
      final unsubscribes = <void Function()>[];
      bench.each(
        'subscribe N observers',
        () => unsubscribes.clear(),
        (_) {
          for (final observer in observers) {
            unsubscribes.add(observer.subscribe((_) {}));
          }
        },
        teardown: (_) {
          for (final unsubscribe in unsubscribes) {
            unsubscribe();
          }
        },
        n: n,
        per: n,
        unit: 'observer',
      );
      bench.each(
        'unsubscribe N observers',
        () {
          unsubscribes.clear();
          for (final observer in observers) {
            unsubscribes.add(observer.subscribe((_) {}));
          }
        },
        (_) {
          for (final unsubscribe in unsubscribes) {
            unsubscribe();
          }
        },
        n: n,
        per: n,
        unit: 'observer',
      );

      for (final kind in Kind.values) {
        var heard = 0;
        var done = Completer<void>();
        void listener(QueryResult<int> result) {
          if (++heard == n) done.complete();
        }

        final stops = <void Function()>[];
        for (final observer in observers) {
          switch (kind) {
            case Kind.sync:
              stops.add(observer.subscribe(listener));
            case Kind.batched:
              stops.add(observer.subscribe(notifyManager.batchCalls(listener)));
            case Kind.stream:
              stops.add(observer.stream.listen(listener).cancel);
          }
        }
        // A stream delivers the current result first.
        await pump();

        await bench.eachAsync(
          'write all M, ${kind.name} listeners',
          () {
            heard = 0;
            done = Completer<void>();
          },
          (_) {
            writeAll();
            return done.future;
          },
          n: n,
          per: n,
          unit: 'listener',
        );
        for (final stop in stops) {
          stop();
        }
        await pump();
      }
      client.clear();
    }
  }
}
