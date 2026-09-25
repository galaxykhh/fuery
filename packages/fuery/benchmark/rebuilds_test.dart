// Benchmarks of the fuery widgets: how many builds and fetches a change
// causes, and how the time of a frame grows with the number of queries.
//
// Run from packages/fuery with `flutter test benchmark/`. The counts are
// exact and checked; the times come from `flutter test`, which runs in JIT
// mode with asserts on, so compare them only with each other. See README.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'harness.dart';

const ms1 = Duration(milliseconds: 1);

class Post {
  const Post(this.id, this.title);

  final int id;
  final String title;
}

class Item {
  const Item(this.id, this.title, this.likes);

  final int id;
  final String title;
  final int likes;
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

Query<List<Item>> itemsQuery() => Query(
      queryKey: ['items'],
      queryFn: (_) async {
        fetches++;
        return const <Item>[];
      },
      staleTime: infiniteDuration,
    );

List<Item> itemList(int n, {int likes = 0, int renamed = -1, int version = 0}) {
  return [
    for (var i = 0; i < n; i++)
      Item(i, i == renamed ? 'Item $i v$version' : 'Item $i', likes),
  ];
}

/// The StatelessWidget of scenario 1: it builds the definition in `build`.
class PostView extends StatelessWidget {
  const PostView({super.key, required this.id, required this.onBuild});

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

/// PostView with a QuerySelector.
class PostTitle extends StatelessWidget {
  const PostTitle({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return QuerySelector(
      query: postQuery(id),
      selector: (result) => result.data?.title,
      builder: (context, title) {
        onBuild();
        return Text(title ?? 'loading');
      },
    );
  }
}

/// PostView with a shared observer, created once outside the widget.
class SharedPostView extends StatelessWidget {
  const SharedPostView({
    super.key,
    required this.observer,
    required this.onBuild,
  });

  final QueryObserver<Post> observer;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: observer,
      builder: (context, result) {
        onBuild();
        return Text(result.data?.title ?? 'loading');
      },
    );
  }
}

/// The same widget without Fuery, for the cost of the rebuild itself.
class PlainPostView extends StatelessWidget {
  const PlainPostView({super.key, required this.id, required this.onBuild});

  final int id;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text('Post $id');
  }
}

/// Counts its builds in [leafBuilds].
class Leaf extends StatelessWidget {
  const Leaf({super.key});

  @override
  Widget build(BuildContext context) {
    leafBuilds++;
    return const SizedBox.expand();
  }
}

var leafBuilds = 0;

void main() {
  late QueryClient client;

  setUpAll(() => report('Environment: ${environment()}'));

  setUp(() {
    focusManager.setFocused(null);
    onlineManager.setOnline(true);
    client = newClient();
    fetches = 0;
    leafBuilds = 0;
  });

  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  /// Counts the cache's notifications, as `client.watch` and the devtools
  /// hear them: one per batch of changes.
  ({int Function() count, void Function() stop}) watchCache() {
    var calls = 0;
    final subscription = client.watch((_) {
      calls++;
      return 0;
    }).listen((_) {});
    return (count: () => calls, stop: () => subscription.cancel());
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
            itemBuilder: (context, i) => QueryBuilder(
              query: rowQuery(i),
              builder: (context, result) => Text(result.data ?? ''),
            ),
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

  group('1. a parent rebuilds 1,000 times with the same id', () {
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
      final cache = watchCache();
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
        final notifications = cache.count();
        final elements = ElementRebuilds()..start();
        for (var i = 0; i < 1000; i++) {
          await rebuild();
        }
        elements.stop();
        final heard = cache.count() - notifications;
        report('S1 $name: builder calls $builds per 1000 parent rebuilds, '
            'fetches $fetches (since mount), cache notifications $heard, '
            'widget rebuilds ${elements.count / 1000} per frame '
            '(${elements.describe()} in 1000 frames)');
        expect(builds, 1000);
        expect(fetches, expectedFetches);
        expect(heard, 0);
      }

      final timing = await measure(
        warmup: 200,
        rounds: 2,
        perRound: 1000,
        op: (_) => rebuild(),
      );
      cache.stop();
      expect(fetches, expectedFetches);
      await tearDownApp(tester);
      return timing;
    }

    benchmark('each variant, alternating in 3 passes', (tester) async {
      final variants =
          <(String, int, Widget Function(VoidCallback)) Function()>[
        () => (
              'baseline, plain StatelessWidget without Fuery',
              0,
              (onBuild) => PlainPostView(id: 1, onBuild: onBuild),
            ),
        () => (
              'QueryBuilder(query: postQuery(id)) built in build',
              1,
              (onBuild) => PostView(id: 1, onBuild: onBuild),
            ),
        () => (
              'QuerySelector(query: postQuery(id)) built in build',
              1,
              (onBuild) => PostTitle(id: 1, onBuild: onBuild),
            ),
        () {
          final observer = postQuery(1).observe(client: client);
          return (
            'QueryBuilder(query: observer), observer created once',
            1,
            (onBuild) => SharedPostView(observer: observer, onBuild: onBuild),
          );
        },
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
        report('S1 $name: parent rebuild + frame: ${Timing.merge(passes)}');
      }
    });
  });

  group('2. a ListView of QueryBuilders, one item updated with setData', () {
    Future<Map<String, Timing>> run(
      WidgetTester tester, {
      required int n,
      required bool allMounted,
      required bool fuery,
      bool count = false,
    }) async {
      if (allMounted) {
        // Tall enough for every item, so none is built lazily.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(400, n * 20.0);
      }
      final builds = List.filled(n, 0);
      final notifiers = [
        for (var i = 0; i < n; i++) ValueNotifier('item $i v0'),
      ];
      for (var i = 0; i < n; i++) {
        client.setData(rowQuery(i), 'item $i v0');
      }
      await tester.pumpWidget(
        host(
          client,
          ListView.builder(
            itemCount: n,
            itemExtent: 20,
            itemBuilder: (context, i) => fuery
                ? QueryBuilder(
                    query: rowQuery(i),
                    builder: (context, result) {
                      builds[i]++;
                      return Text(result.data ?? '');
                    },
                  )
                : ValueListenableBuilder(
                    valueListenable: notifiers[i],
                    builder: (context, value, _) {
                      builds[i]++;
                      return Text(value);
                    },
                  ),
          ),
        ),
      );
      await tester.pump(ms1);
      final mounted = builds.where((b) => b > 0).length;
      final target = allMounted ? n ~/ 2 : 10;
      final name = '${fuery ? 'QueryBuilder' : 'baseline '
              'ValueListenableBuilder'} x$n, '
          '${allMounted ? 'all mounted' : 'lazy, $mounted mounted'}';

      var version = 0;
      void update(int item) {
        version++;
        if (fuery) {
          client.setData(rowQuery(item), 'item $item v$version');
        } else {
          notifiers[item].value = 'item $item v$version';
        }
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
        report('S2 $name: 100 updates of one item ran $total item builders '
            '($others of other items), widget rebuilds '
            '${elements.count / 100} per frame (${elements.describe()} in '
            '100 frames)'
            '${allMounted ? '' : '; 100 updates of an unmounted item ran '
                '$unmounted builders'}'
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
        report('S2 $name, $op: $timing');
      }
      await tearDownApp(tester);
      tester.view.reset();
      for (final notifier in notifiers) {
        notifier.dispose();
      }
      return timings;
    }

    benchmark('1,000 items, lazy and all mounted, with counts', (tester) async {
      await run(tester, n: 1000, allMounted: false, fuery: true, count: true);
      await run(tester, n: 1000, allMounted: false, fuery: false, count: true);
      await run(tester, n: 1000, allMounted: true, fuery: true, count: true);
      await run(tester, n: 1000, allMounted: true, fuery: false, count: true);
    });

    Future<void> scale(
      WidgetTester tester,
      List<int> sizes, {
      required bool allMounted,
    }) async {
      final byOp = <String, Map<int, double>>{};
      for (final n in sizes) {
        for (final fuery in [true, false]) {
          final timings = await run(
            tester,
            n: n,
            allMounted: allMounted,
            fuery: fuery,
          );
          for (final MapEntry(key: op, value: timing) in timings.entries) {
            final variant = fuery ? 'QueryBuilder' : 'baseline';
            (byOp['$variant, $op'] ??= {})[n] = timing.median;
          }
        }
      }
      for (final MapEntry(key: op, value: bySize) in byOp.entries) {
        report('S2 scaling, ${allMounted ? 'all mounted' : 'lazy'}, $op: '
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

  group('3. QuerySelector over a list query, an unrelated field changes', () {
    Future<Timing> run(
      WidgetTester tester, {
      required int n,
      required bool selector,
      bool count = false,
    }) async {
      var builds = 0;
      var selections = 0;
      client.setData(itemsQuery(), itemList(n));
      await tester.pumpWidget(
        host(
          client,
          selector
              ? QuerySelector(
                  query: itemsQuery(),
                  selector: (result) {
                    selections++;
                    return [
                      for (final item in result.data ?? const <Item>[])
                        item.title,
                    ];
                  },
                  builder: (context, titles) {
                    builds++;
                    return Text('${titles.length} titles');
                  },
                )
              : QueryBuilder(
                  query: itemsQuery(),
                  builder: (context, result) {
                    builds++;
                    return Text('${result.data?.length} items');
                  },
                ),
        ),
      );
      await tester.pump(ms1);
      final name = selector
          ? 'QuerySelector(titles) over $n items'
          : 'QueryBuilder (control) over $n items';

      var likes = 0;
      late List<Item> next;
      void prepareLikes() => next = itemList(n, likes: ++likes);

      if (count) {
        builds = 0;
        selections = 0;
        for (var k = 0; k < 1000; k++) {
          prepareLikes();
          client.setData(itemsQuery(), next);
          await tester.pump(deliver);
        }
        final unrelated = builds;
        final selected = selections;
        builds = 0;
        for (var k = 0; k < 10; k++) {
          client.setData(
            itemsQuery(),
            itemList(n, likes: likes, renamed: k, version: k),
          );
          await tester.pump(deliver);
        }
        report('S3 $name: 1000 changes of likes (not selected) rebuilt '
            '$unrelated times and ran the selector $selected times; 10 '
            'renames rebuilt $builds times');
        expect(unrelated, selector ? 0 : 1000);
        expect(builds, 10);
      }

      final timing = await measure(
        warmup: 20,
        perRound: n > 1000 ? 40 : 200,
        prepare: (_) async => prepareLikes(),
        op: (_) {
          client.setData(itemsQuery(), next);
          return tester.pump(deliver);
        },
      );
      report('S3 $name: setData of an unrelated change + frame: $timing');
      await tearDownApp(tester);
      return timing;
    }

    benchmark('1,000 items, with counts', (tester) async {
      await run(tester, n: 1000, selector: true, count: true);
      await run(tester, n: 1000, selector: false, count: true);
    });

    benchmark('scaling with the length of the list', (tester) async {
      final selector = <int, double>{};
      final control = <int, double>{};
      for (final n in [100, 1000, 10000]) {
        selector[n] = (await run(tester, n: n, selector: true)).median;
        control[n] = (await run(tester, n: n, selector: false)).median;
      }
      report('S3 scaling, QuerySelector: ${scaling(selector, 'item')}');
      report('S3 scaling, QueryBuilder: ${scaling(control, 'item')}');
    });
  });

  group('4. QueriesBuilder over a list of queries', () {
    Future<Map<String, Timing>> run(
      WidgetTester tester, {
      required int n,
      bool count = false,
    }) async {
      var builds = 0;
      late List<QueryResult<String>> last;
      final parent = GlobalKey<RebuilderState>();
      var ids = [for (var i = 0; i < n; i++) i];
      for (final id in ids) {
        client.setData(rowQuery(id), 'row $id v0');
      }
      await tester.pumpWidget(
        host(
          client,
          Rebuilder(
            key: parent,
            builder: (_) => QueriesBuilder(
              queries: [for (final id in ids) rowQuery(id)],
              builder: (context, results) {
                builds++;
                last = results;
                return Text('${results.length} rows');
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
        report('S4 QueriesBuilder x$n: 100 changes of one query built '
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
        report('S4 QueriesBuilder x$n, $op + frame: $timing');
      }
      await tearDownApp(tester);
      return timings;
    }

    benchmark('500 queries, with counts', (tester) async {
      await run(tester, n: 500, count: true);
    });

    benchmark('scaling with the number of queries', (tester) async {
      final byOp = <String, Map<int, double>>{};
      for (final n in [100, 250, 500, 1000, 2000]) {
        final timings = await run(tester, n: n);
        for (final MapEntry(key: op, value: timing) in timings.entries) {
          (byOp[op] ??= {})[n] = timing.median;
        }
      }
      for (final MapEntry(key: op, value: bySize) in byOp.entries) {
        report('S4 scaling, $op: ${scaling(bySize, 'query')}');
      }
    });
  });

  group('5. MutationStateSelector with many other runs in the cache', () {
    Mutation<int, int, Object?> other(int i) => Mutation(
          mutationKey: ['other', i],
          mutationFn: (int v) async => v,
        );
    final like = Mutation(
      mutationKey: const ['like'],
      mutationFn: (int v) async => v,
    );
    const gcTime = Duration(milliseconds: 10);

    Future<Map<String, Timing>> run(
      WidgetTester tester, {
      required int others,
      bool count = false,
    }) async {
      for (var i = 0; i < others; i++) {
        unawaited(other(i).observe(client: client).mutateAsync(i));
      }
      for (var i = 0; i < 10; i++) {
        unawaited(like.observe(client: client).mutateAsync(i));
      }
      await tester.pump(ms1);

      var selectorBuilds = 0;
      var builderBuilds = 0;
      await tester.pumpWidget(
        host(
          client,
          Column(
            children: [
              MutationStateSelector(
                mutation: like,
                selector: (runs) => runs.where((run) => run.isPending).length,
                builder: (context, pending) {
                  selectorBuilds++;
                  return Text('$pending pending');
                },
              ),
              // Only while counting: it rebuilds whenever a matching run
              // is added, changes, or is removed.
              if (count)
                MutationStateBuilder(
                  mutation: like,
                  builder: (context, runs) {
                    builderBuilds++;
                    return Text('${runs.length} runs');
                  },
                ),
            ],
          ),
        ),
      );
      await tester.pump(ms1);

      // A run that the test settles, and that the cache removes gcTime
      // later.
      late Completer<int> gate;
      MutationObserver<int, int, Object?> transient(MutationKey key) {
        return Mutation(
          mutationKey: key,
          gcTime: gcTime,
          mutationFn: (int v) => gate.future,
        ).observe(client: client);
      }

      final runners = {
        'matching': transient(const ['like']),
        'unrelated': transient(const ['other', 'transient']),
      };

      Future<void> start(MutationObserver<int, int, Object?> runner, int i) {
        gate = Completer<int>();
        unawaited(runner.mutateAsync(i));
        return tester.pump(deliver);
      }

      Future<void> settle(int i) {
        gate.complete(i);
        return tester.pump(deliver);
      }

      Future<void> collect() => tester.pump(gcTime * 2);

      if (count) {
        for (final MapEntry(key: kind, value: runner) in runners.entries) {
          final selector = [0, 0, 0];
          final builder = [0, 0, 0];
          Future<void> step(int index, Future<void> Function() op) async {
            final (s, b) = (selectorBuilds, builderBuilds);
            await op();
            selector[index] += selectorBuilds - s;
            builder[index] += builderBuilds - b;
          }

          for (var i = 0; i < 100; i++) {
            await step(0, () => start(runner, i));
            await step(1, () => settle(i));
            await step(2, collect);
          }
          report('S5 $others other runs + 10 matching, 100 $kind runs '
              '(start, settle, removal): MutationStateSelector(pending '
              'count) rebuilt ${selector.join('/')}; MutationStateBuilder '
              'rebuilt ${builder.join('/')}');
          if (kind == 'matching') {
            expect(selector, [100, 100, 0]);
            expect(builder, [100, 100, 100]);
          } else {
            expect(selector, [0, 0, 0]);
            expect(builder, [0, 0, 0]);
          }
        }
      }

      final timings = <String, Timing>{};
      for (final MapEntry(key: kind, value: runner) in runners.entries) {
        timings['$kind run settles'] = await measure(
          warmup: 20,
          perRound: others > 1000 ? 20 : 100,
          prepare: (i) => start(runner, i),
          op: settle,
          settle: (_) => collect(),
        );
      }
      for (final MapEntry(key: op, value: timing) in timings.entries) {
        report('S5 $others other runs, MutationStateSelector, $op + frame: '
            '$timing');
      }
      await tearDownApp(tester);
      return timings;
    }

    benchmark('1,000 other runs and 10 matching, with counts', (tester) async {
      await run(tester, others: 1000, count: true);
    });

    benchmark('scaling with the number of runs in the cache', (tester) async {
      final byOp = <String, Map<int, double>>{};
      for (final others in [100, 1000, 10000]) {
        final timings = await run(tester, others: others);
        for (final MapEntry(key: op, value: timing) in timings.entries) {
          (byOp[op] ??= {})[others] = timing.median;
        }
      }
      for (final MapEntry(key: op, value: bySize) in byOp.entries) {
        report('S5 scaling, $op: ${scaling(bySize, 'run')}');
      }
    });
  });

  group('7. FueryDevtools when disabled', () {
    /// The app of the devtools guide: FueryDevtools in MaterialApp's
    /// builder, above every route.
    Future<(int, Timing)> run(
      WidgetTester tester,
      String name,
      Widget Function(Widget child) wrap, {
      required bool count,
    }) async {
      final parent = GlobalKey<RebuilderState>();
      await tester.pumpWidget(
        host(
          client,
          Rebuilder(
            key: parent,
            builder: (_) => MaterialApp(
              builder: (context, child) => wrap(child!),
              home: const Leaf(),
            ),
          ),
        ),
      );
      final panels = find.byType(FueryDevtoolsPanel).evaluate().length;

      Future<void> rebuild() {
        parent.currentState!.rebuild();
        return tester.pump(deliver);
      }

      var keyboard = false;
      Future<void> toggleKeyboard() {
        keyboard = !keyboard;
        if (keyboard) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        } else {
          tester.view.resetViewInsets();
        }
        return tester.pump(deliver);
      }

      var version = 0;
      Future<void> changeQuery() {
        client.setData(rowQuery(0), 'row 0 v${version++}');
        return tester.pump(deliver);
      }

      if (count) {
        final counts = <String>[];
        for (final (op, action) in [
          ('app rebuild', rebuild),
          ('keyboard toggle', toggleKeyboard),
          ('setData', changeQuery),
        ]) {
          leafBuilds = 0;
          final elements = ElementRebuilds()..start();
          for (var k = 0; k < 100; k++) {
            await action();
          }
          elements.stop();
          counts.add('100 x $op: home builds $leafBuilds, Navigator builds '
              '${elements.byWidget['Navigator'] ?? 0}, FueryDevtools builds '
              '${elements.byWidget['FueryDevtools'] ?? 0}, widget rebuilds '
              '${elements.count}');
        }
        report('S7 $name: FueryDevtoolsPanel mounted: $panels; '
            '${counts.join('; ')}');
      }

      final timing = await measure(
        warmup: 100,
        rounds: 2,
        perRound: 500,
        op: (_) => rebuild(),
      );
      tester.view.resetViewInsets();
      await tearDownApp(tester);
      return (panels, timing);
    }

    benchmark('each variant, alternating in 3 passes', (tester) async {
      final variants = <String, Widget Function(Widget child)>{
        'no devtools (baseline)': (child) => child,
        'FueryDevtools(enabled: false)': (child) =>
            FueryDevtools(enabled: false, child: child),
        'FueryDevtools(enabled: true), closed': (child) =>
            FueryDevtools(enabled: true, child: child),
        'FueryDevtools(enabled: true), open': (child) =>
            FueryDevtools(enabled: true, initiallyOpen: true, child: child),
      };
      final timings = <String, List<Timing>>{};
      final panels = <String, int>{};
      for (var pass = 0; pass < 3; pass++) {
        for (final MapEntry(key: name, value: wrap) in variants.entries) {
          final (mounted, timing) = await run(
            tester,
            name,
            wrap,
            count: pass == 0,
          );
          panels[name] = mounted;
          (timings[name] ??= []).add(timing);
        }
      }
      for (final MapEntry(key: name, value: passes) in timings.entries) {
        report('S7 $name, app rebuild + frame: ${Timing.merge(passes)}');
      }
      expect(panels['FueryDevtools(enabled: false)'], 0);
    });
  });
}
