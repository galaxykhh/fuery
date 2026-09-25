// hashKey for typical keys. Every cache lookup by key hashes it: getData,
// setData, an observer's setOptions, and a QueriesSlot update per query.
import 'dart:convert';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

enum Status { active, archived }

void main(List<String> args) {
  final bench = Bench('hash_key', args);

  final keys = <String, QueryKey>{
    "['todos']": ['todos'],
    "['todos', 42]": ['todos', 42],
    "['posts', {page, sort, tags}]": [
      'posts',
      {
        'page': 3,
        'sort': 'new',
        'tags': ['a', 'b'],
      },
    ],
    "['events', enum, DateTime]": [
      'events',
      Status.active,
      DateTime.utc(2026, 9, 25, 12, 30),
    ],
  };

  bench.section('hashKey(key), per call');
  for (final MapEntry(key: name, value: key) in keys.entries) {
    bench.sync(name, (count) {
      var length = 0;
      for (var i = 0; i < count; i++) {
        length += hashKey(key).length;
      }
      sink = length;
    });
  }

  bench.section('Reference: jsonEncode of the key alone, keys JSON can hold');
  for (final name in keys.keys.take(3)) {
    final key = keys[name]!;
    bench.sync(name, (count) {
      var length = 0;
      for (var i = 0; i < count; i++) {
        length += jsonEncode(key).length;
      }
      sink = length;
    });
  }
}
