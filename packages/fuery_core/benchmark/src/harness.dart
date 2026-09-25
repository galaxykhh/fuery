/// Timing and reporting shared by the benchmarks. Plain [Stopwatch]es:
/// every case warms up, then takes several samples and reports the median,
/// the interquartile range, and the fastest and slowest sample.
library;

import 'dart:async';
import 'dart:io';

/// Whether this runs as a compiled executable (`dart compile exe`, AOT) or
/// on the VM (`dart run`, JIT).
const bool isAot = bool.fromEnvironment('dart.vm.product');

/// Holds what the timed code computed, so the compiler can't drop it.
Object? sink;

/// Lets every pending microtask run, then returns.
Future<void> pump() => Future<void>.delayed(Duration.zero);

/// Sample times of one case, in microseconds per operation.
class Stats {
  Stats(List<double> samples) : samples = [...samples]..sort();

  final List<double> samples;

  double get median => _quantile(0.5);
  double get p25 => _quantile(0.25);
  double get p75 => _quantile(0.75);
  double get min => samples.first;
  double get max => samples.last;

  double _quantile(double q) {
    final position = (samples.length - 1) * q;
    final lower = position.floor();
    final upper = position.ceil();
    final fraction = position - lower;
    return samples[lower] * (1 - fraction) + samples[upper] * fraction;
  }
}

/// Runs and reports the cases of one area.
///
/// Arguments: `--quick` takes fewer and shorter samples, for a smoke test,
/// and `--tsv` prints tab-separated rows instead of a table.
class Bench {
  Bench(this.area, List<String> args)
      : tsv = args.contains('--tsv'),
        quick = args.contains('--quick') {
    final mode = isAot ? 'AOT (dart compile exe)' : 'JIT (dart run)';
    if (tsv) {
      print('# $area\t$mode\t${Platform.version}');
      print('area\tsection\tcase\tn\tmedian_us\tp25_us\tp75_us\tmin_us\t'
          'max_us\tper_unit_us\tunit');
      return;
    }
    print('== $area ==');
    print('mode: $mode');
    print('dart: ${Platform.version}');
    print('os: ${Platform.operatingSystemVersion}, '
        '${Platform.numberOfProcessors} cores');
    print('samples: $samples per case (median, IQR p25-p75, min-max)');
  }

  final String area;
  final bool tsv;
  final bool quick;

  int get samples => quick ? 5 : 21;
  int get _warmupRuns => quick ? 2 : 10;
  Duration get _sampleTime => Duration(milliseconds: quick ? 2 : 10);
  Duration get _warmupTime => Duration(milliseconds: quick ? 30 : 300);

  /// The heading of the cases that follow.
  String _section = '';

  /// Prints a heading for the cases that follow.
  void section(String title) {
    _section = title;
    if (tsv) return;
    print('');
    print('-- $title');
  }

  /// Times [body], which does [count] operations, in batches long enough to
  /// time, and reports the time of one operation.
  ///
  /// [per] operations' worth of units, such as listeners, make up one
  /// operation, reported as the time per [unit].
  Stats sync(
    String name,
    void Function(int count) body, {
    int? n,
    int per = 1,
    String unit = '',
  }) {
    final watch = Stopwatch();
    var count = 1;
    // Doubles the batch until one takes long enough to time.
    while (true) {
      watch
        ..reset()
        ..start();
      body(count);
      watch.stop();
      if (watch.elapsed >= _sampleTime || count >= 1 << 30) break;
      count *= 2;
    }
    final warmup = Stopwatch()..start();
    while (warmup.elapsed < _warmupTime) {
      body(count);
    }
    final times = <double>[];
    for (var i = 0; i < samples; i++) {
      watch
        ..reset()
        ..start();
      body(count);
      watch.stop();
      times.add(_micros(watch) / count);
    }
    return report(name, Stats(times), n: n, per: per, unit: unit);
  }

  /// Times [op] once per sample, after an untimed [setup] and before an
  /// untimed [teardown], for operations that change what they run on.
  Stats each<T>(
    String name,
    T Function() setup,
    void Function(T input) op, {
    void Function(T input)? teardown,
    int? n,
    int per = 1,
    String unit = '',
  }) {
    final watch = Stopwatch();
    final times = <double>[];
    for (var i = 0; i < _warmupRuns + samples; i++) {
      final input = setup();
      watch
        ..reset()
        ..start();
      op(input);
      watch.stop();
      teardown?.call(input);
      if (i >= _warmupRuns) times.add(_micros(watch));
    }
    return report(name, Stats(times), n: n, per: per, unit: unit);
  }

  /// Like [each], for an [op] that completes asynchronously. The time runs
  /// until the future of [op] completes.
  Future<Stats> eachAsync<T>(
    String name,
    FutureOr<T> Function() setup,
    Future<void> Function(T input) op, {
    FutureOr<void> Function(T input)? teardown,
    int? n,
    int per = 1,
    String unit = '',
  }) async {
    final watch = Stopwatch();
    final times = <double>[];
    for (var i = 0; i < _warmupRuns + samples; i++) {
      final input = await setup();
      watch
        ..reset()
        ..start();
      await op(input);
      watch.stop();
      await teardown?.call(input);
      if (i >= _warmupRuns) times.add(_micros(watch));
    }
    return report(name, Stats(times), n: n, per: per, unit: unit);
  }

  /// Prints one row. [per] units make up one operation.
  Stats report(
    String name,
    Stats stats, {
    int? n,
    int per = 1,
    String unit = '',
  }) {
    final perUnit = unit.isEmpty ? null : stats.median / per;
    if (tsv) {
      print([
        area,
        _section,
        name,
        n ?? '',
        stats.median,
        stats.p25,
        stats.p75,
        stats.min,
        stats.max,
        perUnit ?? '',
        unit,
      ].join('\t'));
      return stats;
    }
    final size = n == null ? '' : 'N=$n';
    final perText = perUnit == null ? '' : '  ${formatMicros(perUnit)}/$unit';
    print('  ${name.padRight(48)} ${size.padRight(8)} '
        '${formatMicros(stats.median).padLeft(10)}  '
        'IQR ${formatMicros(stats.p25)}-${formatMicros(stats.p75)}  '
        'range ${formatMicros(stats.min)}-${formatMicros(stats.max)}'
        '$perText');
    return stats;
  }
}

double _micros(Stopwatch watch) => watch.elapsedTicks * 1e6 / watch.frequency;

/// [micros] in ns, µs, or ms, whichever reads best.
String formatMicros(double micros) {
  if (micros < 1) return '${(micros * 1000).toStringAsFixed(0)} ns';
  if (micros < 1000) return '${micros.toStringAsFixed(2)} µs';
  return '${(micros / 1000).toStringAsFixed(2)} ms';
}
