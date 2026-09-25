// Timing and counting helpers for the benchmarks in this directory. Not a
// test file itself: `flutter test benchmark/` runs only the `_test.dart`
// files.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery_hooks/fuery_hooks.dart';

/// A `testWidgets` for a benchmark: with a long timeout, and with semantics
/// off, as in an app that no accessibility service reads. With semantics on,
/// which is the default of `testWidgets`, a frame of a tree with thousands
/// of mounted widgets spends most of its time updating Flutter's semantics
/// tree.
void benchmark(String description, WidgetTesterCallback body) {
  testWidgets(
    description,
    body,
    timeout: const Timeout(Duration(minutes: 10)),
    semanticsEnabled: false,
  );
}

/// Prints one line of the report.
void report(String line) {
  // ignore: avoid_print
  print(line);
}

/// Where the numbers come from: `flutter test` runs Dart in JIT mode with
/// asserts on, so times are only comparable with each other.
String environment() {
  var asserts = false;
  assert(asserts = true);
  const product = bool.fromEnvironment('dart.vm.product');
  final mode = kReleaseMode
      ? 'release'
      : kProfileMode
          ? 'profile'
          : 'debug';
  return 'Dart ${Platform.version.split(' ').first}, '
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}, '
      '${Platform.numberOfProcessors} cores, $mode mode, '
      '${product ? 'AOT (product VM)' : 'JIT'}, '
      'asserts ${asserts ? 'on' : 'off'}';
}

/// Fuery delivers a change to widgets in a microtask, and `tester.pump()`
/// draws a frame only when one was scheduled before it was called. Pumping
/// with [Duration.zero] runs the microtasks first, so a change and the frame
/// that shows it take one pump.
const deliver = Duration.zero;

/// A fresh client, as the package's tests make one.
QueryClient newClient() => QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );

/// Times of one operation, in microseconds, over several rounds.
class Timing {
  Timing(List<int> samples, this.roundMedians) : samples = [...samples]..sort();

  /// The samples and rounds of several timings of the same operation, such
  /// as passes that alternate with other variants.
  factory Timing.merge(Iterable<Timing> timings) => Timing(
        [for (final timing in timings) ...timing.samples],
        [for (final timing in timings) ...timing.roundMedians],
      );

  /// Every sample, sorted.
  final List<int> samples;

  /// The median of each round, in the order they ran.
  final List<double> roundMedians;

  double get median => _percentile(samples, 0.5);
  double get p25 => _percentile(samples, 0.25);
  double get p75 => _percentile(samples, 0.75);
  int get min => samples.first;
  int get max => samples.last;

  @override
  String toString() {
    final rounds = [...roundMedians]..sort();
    return 'median ${_us(median)} (IQR ${_us(p25)}-${_us(p75)}, '
        'min ${_us(min)}, max ${_us(max)}, n=${samples.length}; '
        'round medians ${_us(rounds.first)}-${_us(rounds.last)})';
  }
}

String _us(num micros) {
  if (micros >= 10000) return '${(micros / 1000).toStringAsFixed(1)} ms';
  if (micros >= 100) return '${micros.round()} µs';
  return '${micros.toStringAsFixed(1)} µs';
}

double _percentile(List<int> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final index = (sorted.length - 1) * p;
  final lower = index.floor();
  final upper = index.ceil();
  if (lower == upper) return sorted[lower].toDouble();
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
}

double medianOf(List<int> values) => _percentile([...values]..sort(), 0.5);

/// Runs [op] [warmup] times, then [rounds] rounds of [perRound] times, and
/// times each run of [op] alone. [prepare] runs before each [op] and
/// [settle] after it, both untimed.
Future<Timing> measure({
  int warmup = 100,
  int rounds = 5,
  required int perRound,
  Future<void> Function(int i)? prepare,
  required Future<void> Function(int i) op,
  Future<void> Function(int i)? settle,
}) async {
  var i = 0;
  Future<void> once(Stopwatch? watch) async {
    await prepare?.call(i);
    watch?.start();
    await op(i);
    watch?.stop();
    await settle?.call(i);
    i++;
  }

  for (var w = 0; w < warmup; w++) {
    await once(null);
  }
  final samples = <int>[];
  final roundMedians = <double>[];
  final watch = Stopwatch();
  for (var r = 0; r < rounds; r++) {
    final round = <int>[];
    for (var k = 0; k < perRound; k++) {
      watch.reset();
      await once(watch);
      round.add(watch.elapsedMicroseconds);
    }
    samples.addAll(round);
    roundMedians.add(medianOf(round));
  }
  return Timing(samples, roundMedians);
}

/// Counts every widget rebuild (stateless, stateful, inherited, and proxy
/// elements) while [start]ed, through [debugOnRebuildDirtyWidget]. Only for
/// counting passes: it adds a call to every rebuild.
class ElementRebuilds {
  int count = 0;
  final Map<String, int> byWidget = {};

  void start() {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      count++;
      final name = element.widget.runtimeType.toString();
      byWidget[name] = (byWidget[name] ?? 0) + 1;
    };
  }

  void stop() => debugOnRebuildDirtyWidget = null;

  void reset() {
    count = 0;
    byWidget.clear();
  }

  /// The widgets that rebuilt, most first, such as `Text x2, QueryBuilder x1`.
  String describe() {
    final entries = byWidget.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${e.key} x${e.value}').join(', ');
  }
}

/// A parent that rebuilds its child on [RebuilderState.rebuild], so the
/// child's widgets are created again, as a parent's `setState` does.
class Rebuilder extends StatefulWidget {
  const Rebuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<Rebuilder> createState() => RebuilderState();
}

class RebuilderState extends State<Rebuilder> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The provider and the text direction that every scenario needs, without
/// the routes and theme of an app.
Widget host(QueryClient client, Widget child) => FueryProvider(
      client: client,
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

/// The median time at each size, and how the time grew from the smallest
/// size to the largest compared with the size: `time x10 for size x10` is
/// linear, `time x1` is constant, and a time ratio well above the size ratio
/// is faster than linear.
String scaling(Map<int, double> medianBySize, String unit) {
  final sizes = medianBySize.keys.toList()..sort();
  final first = sizes.first;
  final last = sizes.last;
  final parts = [
    for (final size in sizes)
      '$size $unit: ${_us(medianBySize[size]!)} '
          '(${(medianBySize[size]! / size).toStringAsFixed(2)} µs/$unit)',
  ];
  final time = medianBySize[last]! / medianBySize[first]!;
  return '${parts.join('; ')}. Time x${time.toStringAsFixed(1)} for '
      '$unit count x${(last / first).toStringAsFixed(0)}';
}
