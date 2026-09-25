// Resident memory (ProcessInfo.currentRss) per 10,000 cached queries with
// small data. RSS counts pages the process holds, not live objects, so read
// the growth over several steps; run each variant in a process of its own.
//
//   --variant=cached       setData on each key, default gcTime (a timer each)
//   --variant=no-gc-timer  the same with gcTime: infiniteDuration
//   --variant=observed     cached, plus one subscribed observer per query
//   --variant=data-only    no Fuery: the same data in a Map by hashKey
import 'dart:io';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

const step = 10000;
const steps = 5;
const prefixes = ['todos', 'posts', 'users', 'comments'];

Map<String, Object?> item(int id) =>
    {'id': id, 'title': 'Item $id', 'done': id.isEven};

QueryKey keyOf(int id) => [prefixes[id % prefixes.length], id];

Future<void> main(List<String> args) async {
  final variant = args
      .firstWhere(
        (arg) => arg.startsWith('--variant='),
        orElse: () => '--variant=cached',
      )
      .substring('--variant='.length);
  const variants = ['cached', 'no-gc-timer', 'observed', 'data-only'];
  if (!variants.contains(variant)) {
    stderr.writeln('Unknown variant $variant; one of $variants');
    exitCode = 64;
    return;
  }
  final tsv = args.contains('--tsv');

  final client = QueryClient();
  final plain = <String, Object>{};
  final unsubscribes = <void Function()>[];

  void add(int from, int to) {
    for (var id = from; id < to; id++) {
      final data = item(id);
      if (variant == 'data-only') {
        plain[hashKey(keyOf(id))] = data;
        continue;
      }
      final query = Query(
        queryKey: keyOf(id),
        queryFn: (_) async => item(id),
        staleTime: infiniteDuration,
        gcTime: variant == 'no-gc-timer' ? infiniteDuration : null,
      );
      client.setData(query, data);
      if (variant == 'observed') {
        unsubscribes.add(query.observe(client: client).subscribe((_) {}));
      }
    }
  }

  // Runs the code once, so compiling it doesn't count, then empties the
  // cache again.
  add(-step, 0);
  for (final unsubscribe in unsubscribes) {
    unsubscribe();
  }
  unsubscribes.clear();
  client.clear();
  plain.clear();
  await settle();

  final base = ProcessInfo.currentRss;
  final mode = isAot ? 'AOT' : 'JIT';
  if (tsv) {
    print('# memory\t$mode\t$variant\t${Platform.version}');
    print('variant\tqueries\trss_mb\tgrowth_mb\tstep_kb');
  } else {
    print('== memory, variant $variant ==');
    print('mode: $mode, dart: ${Platform.version}');
    print('RSS after warm-up: ${mb(base)} MB');
  }
  var previous = base;
  final perStep = <int>[];
  for (var i = 1; i <= steps; i++) {
    add((i - 1) * step, i * step);
    await settle();
    final rss = ProcessInfo.currentRss;
    perStep.add(rss - previous);
    if (tsv) {
      print('$variant\t${i * step}\t${mb(rss)}\t${mb(rss - base)}\t'
          '${(rss - previous) ~/ 1024}');
    } else {
      print('  ${(i * step).toString().padLeft(6)} queries: RSS ${mb(rss)} MB, '
          '+${mb(rss - base)} MB in all, '
          '+${((rss - previous) / 1024).toStringAsFixed(0)} KB this step');
    }
    previous = rss;
  }
  perStep.sort();
  final median = perStep[steps ~/ 2];
  final total = previous - base;
  final summary = 'per 10,000 queries: median step '
      '${(median / 1024).toStringAsFixed(0)} KB, mean '
      '${(total / steps / 1024).toStringAsFixed(0)} KB; '
      '${(total / (steps * step)).toStringAsFixed(0)} bytes per query; '
      'max RSS ${mb(ProcessInfo.maxRss)} MB';
  print(tsv ? '# $summary' : summary);

  for (final unsubscribe in unsubscribes) {
    unsubscribe();
  }
  client.clear();
}

String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// Churns short-lived garbage, so the young generation is collected and
/// what survives is promoted, then waits a moment.
Future<void> settle() async {
  for (var i = 0; i < 200; i++) {
    sink = List<int>.filled(10000, i);
  }
  await Future<void>.delayed(const Duration(milliseconds: 200));
}
