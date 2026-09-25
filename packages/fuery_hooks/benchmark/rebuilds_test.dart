// Benchmarks of the hooks: scenarios 1, 2, and 4 of the fuery widget
// benchmarks (packages/fuery/benchmark), with useQuery and useQueries in
// HookWidgets, and the fuery widgets next to them for comparison.
//
// Run from packages/fuery_hooks with `flutter test benchmark/`. The counts
// are exact and checked; the times come from `flutter test`, which runs in
// JIT mode with asserts on, so compare them only with each other. See
// README.md.
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery_hooks/fuery_hooks.dart';

import 'harness.dart';

const ms1 = Duration(milliseconds: 1);

class Post {
  const Post(this.id, this.title);

  final int id;
  final String title;
}

var fetches = 0;

/// A definition built on every call, as a screen builds it in `build`.
Query<Post> postQuery(int id) => Query(
      queryKey: ['post', id],
      queryFn: (_) async {
        fetches++;
        return Post(id, 'Post $id');
      },
    );

/// A query whose data the benchmark sets, and which never refetches.
Query<String> rowQuery(int id) => Query(
      queryKey: ['row', id],
      queryFn: (_) async {
        fetches++;
        return 'row $id';
      },
      staleTime: infiniteDuration,
    );

/// Scenario 1 with hooks: the definition is built in `build`.
class HookPostView extends HookWidget {
  const HookPostView({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final result = useQuery(postQuery(id));
    onBuild();
    return Text(result.data?.title ?? 'loading');
  }
}

/// HookPostView with a shared observer, created once outside the widget.
class SharedHookPostView extends HookWidget {
  const SharedHookPostView({
    super.key,
    required this.observer,
    required this.onBuild,
  });

  final QueryObserver<Post> observer;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final result = useQuery(observer);
    onBuild();
    return Text(result.data?.title ?? 'loading');
  }
}

/// A HookWidget that uses no hook, for the cost of HookWidget itself.
class PlainHookView extends HookWidget {
  const PlainHookView({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text('Post $id');
  }
}

/// The fuery widget for the same screen, for comparison.
class WidgetPostView extends StatelessWidget {
  const WidgetPostView({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: postQuery(id),
      builder: (context, result) {
        onBuild();
        return Text(result.data?.title ?? 'loading');
      },
    );
  }
}

/// One item of scenario 2.
class RowView extends HookWidget {
  const RowView({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final result = useQuery(rowQuery(id));
    onBuild();
    return Text(result.data ?? '');
  }
}

/// Scenario 4 with hooks.
class RowsView extends HookWidget {
  const RowsView({
    super.key,
    required this.ids,
    required this.memoized,
    required this.onBuild,
  });

  final List<int> ids;

  /// Whether the list of definitions is kept while [ids] holds the same ids,
  /// as the hooks guide shows, instead of built on every build.
  final bool memoized;
  final void Function(List<QueryResult<String>> results) onBuild;

  @override
  Widget build(BuildContext context) {
    List<Query<String>> queries() => [for (final id in ids) rowQuery(id)];
    final results = useQueries(
      memoized ? useMemoized(queries, ids) : queries(),
    );
    onBuild(results);
    return Text('${results.length} rows');
  }
}

void main() {
  late QueryClient client;

  setUpAll(() => report('Environment: ${environment()}'));

  setUp(() {
    focusManager.setFocused(null);
    onlineManager.setOnline(true);
    client = newClient();
    fetches = 0;
  });

  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  benchmark('warm-up, not measured', (tester) async {
    // Compiles the frame pipeline and Fuery's paths first, so that the
    // scenario that runs first isn't slower for it.
    final parent = GlobalKey<RebuilderState>();
    for (var i = 0; i < 50; i++) {
      client.setData(rowQuery(i), 'row $i');
    }
    await tester.pumpWidget(
      host(
        client,
        Rebuilder(
          key: parent,
          builder: (_) => ListView.builder(
            itemCount: 50,
            itemExtent: 20,
            itemBuilder: (context, i) => RowView(id: i, onBuild: () {}),
          ),
        ),
      ),
    );
    for (var k = 0; k < 3000; k++) {
      if (k.isEven) {
        parent.currentState!.rebuild();
      } else {
        client.setData(rowQuery(k % 20), 'row v$k');
      }
      await tester.pump(deliver);
    }
    await tearDownApp(tester);
  });

  group('6.1 a parent rebuilds 1,000 times with the same id', () {
    Future<Timing> run(
      WidgetTester tester,
      String name,
      Widget Function(VoidCallback onBuild) view, {
      required int expectedFetches,
      required bool count,
    }) async {
      fetches = 0;
      var builds = 0;
      final parent = GlobalKey<RebuilderState>();
      await tester.pumpWidget(
        host(
          client,
          Rebuilder(key: parent, builder: (_) => view(() => builds++)),
        ),
      );
      await tester.pump(ms1);
      await tester.pump(ms1);

      Future<void> rebuild() {
        parent.currentState!.rebuild();
        return tester.pump(deliver);
      }

      if (count) {
        builds = 0;
        final elements = ElementRebuilds()..start();
        for (var i = 0; i < 1000; i++) {
          await rebuild();
        }
        elements.stop();
        report('S6.1 $name: builds $builds per 1000 parent rebuilds, '
            'fetches $fetches (since mount), widget rebuilds '
            '${elements.count / 1000} per frame (${elements.describe()} in '
            '1000 frames)');
        expect(builds, 1000);
        expect(fetches, expectedFetches);
      }

      final timing = await measure(
        warmup: 200,
        rounds: 2,
        perRound: 1000,
        op: (_) => rebuild(),
      );
      expect(fetches, expectedFetches);
      await tearDownApp(tester);
      return timing;
    }

    benchmark('each variant, alternating in 3 passes', (tester) async {
      final variants =
          <(String, int, Widget Function(VoidCallback)) Function()>[
        () => (
              'baseline, HookWidget without hooks',
              0,
              (onBuild) => PlainHookView(id: 1, onBuild: onBuild),
            ),
        () => (
              'useQuery(postQuery(id)) built in build',
              1,
              (onBuild) => HookPostView(id: 1, onBuild: onBuild),
            ),
        () {
          final observer = postQuery(1).observe(client: client);
          return (
            'useQuery(observer), observer created once',
            1,
            (onBuild) =>
                SharedHookPostView(observer: observer, onBuild: onBuild),
          );
        },
        () => (
              'QueryBuilder(query: postQuery(id)) widget, for comparison',
              1,
              (onBuild) => WidgetPostView(id: 1, onBuild: onBuild),
            ),
      ];
      final timings = <String, List<Timing>>{};
      for (var pass = 0; pass < 3; pass++) {
        for (final variant in variants) {
          final (name, expectedFetches, view) = variant();
          (timings[name] ??= []).add(
            await run(
              tester,
              name,
              view,
              expectedFetches: expectedFetches,
              count: pass == 0,
            ),
          );
        }
      }
      for (final MapEntry(key: name, value: passes) in timings.entries) {
        report('S6.1 $name: parent rebuild + frame: '
            '${Timing.merge(passes)}');
      }
    });
  });

  group('6.2 a ListView of useQuery items, one updated with setData', () {
    Future<Map<String, Timing>> run(
      WidgetTester tester, {
      required int n,
      required bool allMounted,
      required bool hooks,
      bool count = false,
    }) async {
      if (allMounted) {
        // Tall enough for every item, so none is built lazily.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(400, n * 20.0);
      }
      final builds = List.filled(n, 0);
      for (var i = 0; i < n; i++) {
        client.setData(rowQuery(i), 'item $i v0');
      }
      await tester.pumpWidget(
        host(
          client,
          ListView.builder(
            itemCount: n,
            itemExtent: 20,
            itemBuilder: (context, i) => hooks
                ? RowView(id: i, onBuild: () => builds[i]++)
                : QueryBuilder(
                    query: rowQuery(i),
                    builder: (context, result) {
                      builds[i]++;
                      return Text(result.data ?? '');
                    },
                  ),
          ),
        ),
      );
      await tester.pump(ms1);
      final mounted = builds.where((b) => b > 0).length;
      final target = allMounted ? n ~/ 2 : 10;
      final name = '${hooks ? 'useQuery HookWidget' : 'QueryBuilder'} x$n, '
          '${allMounted ? 'all mounted' : 'lazy, $mounted mounted'}';

      var version = 0;
      void update(int item) {
        version++;
        client.setData(rowQuery(item), 'item $item v$version');
      }

      if (count) {
        var total = 0;
        var others = 0;
        var unmounted = 0;
        final elements = ElementRebuilds()..start();
        for (var k = 0; k < 100; k++) {
          final before = [...builds];
          update(target);
          await tester.pump(deliver);
          for (var i = 0; i < n; i++) {
            final delta = builds[i] - before[i];
            total += delta;
            if (i != target) others += delta;
          }
        }
        elements.stop();
        if (!allMounted) {
          final before = builds.fold(0, (a, b) => a + b);
          for (var k = 0; k < 100; k++) {
            update(n - 1);
            await tester.pump(deliver);
          }
          unmounted = builds.fold(0, (a, b) => a + b) - before;
        }
        report('S6.2 $name: 100 updates of one item ran $total item builds '
            '($others of other items), widget rebuilds '
            '${elements.count / 100} per frame (${elements.describe()} in '
            '100 frames)'
            '${allMounted ? '' : '; 100 updates of an unmounted item ran '
                '$unmounted builds'}'
            ', fetches $fetches');
        expect(total, 100);
        expect(others, 0);
        expect(unmounted, 0);
        expect(fetches, 0);
      }

      // Runs the update and the microtask that delivers it. Not
      // `tester.idle()`, which moves the fake clock: FakeAsync then looks at
      // every pending timer, and each cached query that nothing observes
      // holds one until it is collected, so idle() would time the number of
      // queries rather than the update.
      Future<void> updateToSetState() async {
        update(target);
        await Future<void>.value();
        if (!tester.binding.hasScheduledFrame) {
          throw StateError('The update scheduled no frame');
        }
      }

      final perRound = allMounted && n >= 10000 ? 20 : 100;
      final timings = {
        // From the update until the item's rebuild is scheduled: Fuery's
        // part.
        'update to setState': await measure(
          warmup: 20,
          perRound: perRound,
          op: (_) => updateToSetState(),
          settle: (_) => tester.pump(),
        ),
        // The frame that rebuilds the item: Flutter's part.
        'frame': await measure(
          warmup: 20,
          perRound: perRound,
          prepare: (_) => updateToSetState(),
          op: (_) => tester.pump(),
        ),
      };
      for (final MapEntry(key: op, value: timing) in timings.entries) {
        report('S6.2 $name, $op: $timing');
      }
      await tearDownApp(tester);
      tester.view.reset();
      return timings;
    }

    benchmark('1,000 items, lazy and all mounted, with counts', (tester) async {
      await run(tester, n: 1000, allMounted: false, hooks: true, count: true);
      await run(tester, n: 1000, allMounted: false, hooks: false, count: true);
      await run(tester, n: 1000, allMounted: true, hooks: true, count: true);
      await run(tester, n: 1000, allMounted: true, hooks: false, count: true);
    });

    Future<void> scale(
      WidgetTester tester,
      List<int> sizes, {
      required bool allMounted,
    }) async {
      final byOp = <String, Map<int, double>>{};
      for (final n in sizes) {
        for (final hooks in [true, false]) {
          final timings = await run(
            tester,
            n: n,
            allMounted: allMounted,
            hooks: hooks,
          );
          for (final MapEntry(key: op, value: timing) in timings.entries) {
            final variant = hooks ? 'useQuery' : 'QueryBuilder';
            (byOp['$variant, $op'] ??= {})[n] = timing.median;
          }
        }
      }
      for (final MapEntry(key: op, value: bySize) in byOp.entries) {
        report('S6.2 scaling, ${allMounted ? 'all mounted' : 'lazy'}, $op: '
            '${scaling(bySize, 'item')}');
      }
    }

    benchmark('scaling with the number of items, lazy', (tester) async {
      await scale(tester, [1000, 10000, 100000], allMounted: false);
    });

    benchmark('scaling with the number of mounted items', (tester) async {
      await scale(tester, [100, 1000, 10000], allMounted: true);
    });
  });

  group('6.4 useQueries over a list of queries', () {
    Future<Map<String, Timing>> run(
      WidgetTester tester, {
      required int n,
      required bool memoized,
      bool count = false,
    }) async {
      var builds = 0;
      late List<QueryResult<String>> last;
      final parent = GlobalKey<RebuilderState>();
      var ids = [for (var i = 0; i < n; i++) i];
      for (final id in ids) {
        client.setData(rowQuery(id), 'row $id v0');
      }
      final name = memoized
          ? 'useQueries x$n, list memoized on ids'
          : 'useQueries x$n, list built in build';
      await tester.pumpWidget(
        host(
          client,
          Rebuilder(
            key: parent,
            builder: (_) => RowsView(
              ids: ids,
              memoized: memoized,
              onBuild: (results) {
                builds++;
                last = results;
              },
            ),
          ),
        ),
      );
      await tester.pump(ms1);

      var version = 0;
      Future<void> changeOne() {
        version++;
        client.setData(rowQuery(n ~/ 2), 'row ${n ~/ 2} v$version');
        return tester.pump(deliver);
      }

      Future<void> rebuild() {
        parent.currentState!.rebuild();
        return tester.pump(deliver);
      }

      Future<void> reorder() {
        // Moves the first query to the end.
        ids = [...ids.skip(1), ids.first];
        return rebuild();
      }

      if (count) {
        Future<(int, int)> countOf(Future<void> Function() op) async {
          builds = 0;
          final elements = ElementRebuilds()..start();
          for (var k = 0; k < 100; k++) {
            await op();
          }
          elements.stop();
          return (builds, elements.count);
        }

        final (changed, changedElements) = await countOf(changeOne);
        final (rebuilt, rebuiltElements) = await countOf(rebuild);
        final observers = Set<Object>.identity()
          ..addAll(last.map((result) => result.observer!));
        final (reordered, reorderedElements) = await countOf(reorder);
        ids = ids.reversed.toList();
        await rebuild();
        final kept = last.every(
          (result) => observers.contains(result.observer),
        );
        report('S6.4 $name: 100 changes of one query built '
            '$changed times ($changedElements widget rebuilds); 100 parent '
            'rebuilds built $rebuilt times ($rebuiltElements); 100 reorders '
            'built $reordered times ($reorderedElements); after reordering '
            'and reversing, every observer kept: $kept; fetches $fetches');
        expect(changed, 100);
        expect(rebuilt, 100);
        expect(reordered, 100);
        expect(kept, isTrue);
        expect(fetches, 0);
      }

      final perRound = n > 1000 ? 50 : 100;
      final timings = {
        'change one query': await measure(
          warmup: 20,
          perRound: perRound,
          op: (_) => changeOne(),
        ),
        'parent rebuild': await measure(
          warmup: 20,
          perRound: perRound,
          op: (_) => rebuild(),
        ),
        'reorder': await measure(
          warmup: 20,
          perRound: perRound,
          op: (_) => reorder(),
        ),
      };
      for (final MapEntry(key: op, value: timing) in timings.entries) {
        report('S6.4 $name, $op + frame: $timing');
      }
      await tearDownApp(tester);
      return timings;
    }

    benchmark('500 queries, with counts', (tester) async {
      await run(tester, n: 500, memoized: false, count: true);
      await run(tester, n: 500, memoized: true, count: true);
    });

    benchmark('scaling with the number of queries', (tester) async {
      final byOp = <String, Map<int, double>>{};
      for (final n in [100, 250, 500, 1000, 2000]) {
        for (final memoized in [false, true]) {
          final timings = await run(tester, n: n, memoized: memoized);
          final variant = memoized ? 'list memoized' : 'list built in build';
          for (final MapEntry(key: op, value: timing) in timings.entries) {
            (byOp['$variant, $op'] ??= {})[n] = timing.median;
          }
        }
      }
      for (final MapEntry(key: op, value: bySize) in byOp.entries) {
        report('S6.4 scaling, $op: ${scaling(bySize, 'query')}');
      }
    });
  });
}
