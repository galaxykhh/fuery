// Structural sharing of JSON-like data: a list of N maps with nested maps
// and lists, compared with a freshly decoded equal copy, with a copy where
// one item changed, and with a copy where every item changed. Then the same
// through a refetch of an observed query.
import 'dart:convert';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

Map<String, Object?> post(int id, {int likes = 0}) => {
      'id': id,
      'title': 'Post $id',
      'author': {
        'id': id % 50,
        'name': 'User ${id % 50}',
        'avatar': 'https://example.com/avatars/${id % 50}.png',
      },
      'tags': ['dart', 'flutter', if (id.isEven) 'cache'],
      'likes': likes + id * 3,
      'comments': [
        {
          'id': id * 10,
          'body': 'First',
          'likedBy': [1, 2, 3],
        },
        {'id': id * 10 + 1, 'body': 'Second', 'likedBy': <int>[]},
      ],
    };

/// [n] posts as a response body. Decoding it gives the types a real
/// response has: `List<dynamic>` and `Map<String, dynamic>`.
String feedJson(int n, {int? changed, bool allChanged = false}) => jsonEncode([
      for (var id = 0; id < n; id++)
        post(id, likes: allChanged || id == changed ? 1 : 0),
    ]);

Future<void> main(List<String> args) async {
  final bench = Bench('structural_sharing', args);

  for (final n in [100, 1000, 10000]) {
    bench.section('A list of N=$n posts, 8 maps and lists in each');
    final equalJson = feedJson(n);
    final oneChangedJson = feedJson(n, changed: n ~/ 2);
    final allChangedJson = feedJson(n, allChanged: true);
    final previous = jsonDecode(equalJson) as List<Object?>;

    bench.each(
      'reference: jsonDecode of the response',
      () => equalJson,
      (json) => sink = jsonDecode(json),
      n: n,
      per: n,
      unit: 'item',
    );

    Object? decode(String json) => jsonDecode(json);
    final sharedEqual = replaceEqualDeep(previous, decode(equalJson));
    final sharedOne = replaceEqualDeep(previous, decode(oneChangedJson));
    if (!identical(sharedEqual, previous) ||
        identical(sharedOne, previous) ||
        !identical((sharedOne! as List<Object?>)[0], previous[0])) {
      throw StateError('replaceEqualDeep did not share as expected');
    }

    bench.each(
      'replaceEqualDeep, equal copy',
      () => decode(equalJson),
      (next) => sink = replaceEqualDeep(previous, next),
      n: n,
      per: n,
      unit: 'item',
    );
    bench.each(
      'replaceEqualDeep, one item changed',
      () => decode(oneChangedJson),
      (next) => sink = replaceEqualDeep(previous, next),
      n: n,
      per: n,
      unit: 'item',
    );
    bench.each(
      'replaceEqualDeep, every item changed',
      () => decode(allChangedJson),
      (next) => sink = replaceEqualDeep(previous, next),
      n: n,
      per: n,
      unit: 'item',
    );

    // A subscribed observer refetches; the query function returns a copy
    // decoded beforehand, so the time is the fetch, the sharing, and the
    // notification.
    for (final sharing in [true, false]) {
      final client = QueryClient();
      Object? response;
      final feed = Query<Object>(
        queryKey: const ['feed'],
        queryFn: (_) async => response!,
        staleTime: infiniteDuration,
        structuralSharing: sharing,
      );
      client.setData(feed, decode(equalJson)!);
      final observer = feed.observe(client: client);
      final unsubscribe = observer.subscribe((_) {});
      final label = sharing ? 'structural sharing' : 'structuralSharing: false';

      await bench.eachAsync(
        'refetch, equal data, $label',
        () => response = decode(equalJson),
        (_) => observer.refetch(),
        n: n,
        per: n,
        unit: 'item',
      );
      if (sharing) {
        await bench.eachAsync(
          'refetch, one item changed, $label',
          () {
            // Back to the unchanged list, untimed.
            client.setData(feed, decode(equalJson)!);
            response = decode(oneChangedJson);
          },
          (_) => observer.refetch(),
          n: n,
          per: n,
          unit: 'item',
        );
      }
      unsubscribe();
      client.clear();
    }
  }
}
