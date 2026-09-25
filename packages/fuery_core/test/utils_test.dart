import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart' show CanonicalizedMap;
import 'package:fuery_core/fuery_core.dart';
import 'package:fuery_core/src/utils.dart'
    show keyCopy, partialMatchKey, sameKey;
import 'package:test/test.dart';

enum Filter { done, todo }

class Page {
  const Page(this.number);
  final int number;
  Map<String, Object?> toJson() => {'number': number};
}

void main() {
  group('hashKey', () {
    test('ignores map key order', () {
      expect(
        hashKey([
          'todos',
          {'page': 1, 'filter': 'done'},
        ]),
        hashKey([
          'todos',
          {'filter': 'done', 'page': 1},
        ]),
      );
    });

    test('distinguishes numbers from strings', () {
      expect(hashKey(['posts', 1]), isNot(hashKey(['posts', '1'])));
    });

    test('supports enums and objects with toJson', () {
      expect(hashKey([Filter.done]), isNot(hashKey([Filter.todo])));
      expect(hashKey([const Page(1)]), hashKey([const Page(1)]));
      expect(hashKey([const Page(1)]), isNot(hashKey([const Page(2)])));
    });

    test('rejects objects that cannot be serialized', () {
      expect(() => hashKey([Object()]), throwsArgumentError);
    });
  });

  group('sameKey', () {
    // Numbers are JavaScript numbers on the web, where 1.0 is an int.
    final onWeb = identical(1, 1.0);

    /// Keys of only the values sameKey compares, built again on every call,
    /// none with the hash of another.
    final comparable = <List<Object?> Function()>[
      () => [],
      () => [null],
      () => [true],
      () => [false],
      () => [0],
      () => [1],
      () => [-1],
      () => [9007199254740991],
      () => [''],
      () => ['1'],
      () => ['todos'],
      () => [Filter.done],
      () => [Filter.todo],
      () => [[]],
      () => [
            [1, 'a'],
          ],
      () => [
            ['a', 1],
          ],
      () => [<String, Object?>{}],
      () => [
            {'page': 1},
          ],
      () => [
            {'page': '1'},
          ],
      () => [
            {'page': 1, 'sort': 'new'},
          ],
      () => [
            {
              'page': [
                1,
                {'deep': Filter.done},
              ],
            },
          ],
      () => [
            'todos',
            1,
            {
              'tags': ['a', 'b'],
              'done': null,
            },
          ],
    ];

    /// Keys with values sameKey leaves to hashing, and keys that hash like
    /// one above in another form.
    final others = <List<Object?> Function()>[
      () => [1.0],
      () => [1.5],
      () => [-0.0],
      () => [double.nan],
      () => [double.infinity],
      () => [DateTime.utc(2026)],
      () => ['2026-01-01T00:00:00.000Z'],
      () => [
            {1, 'a'},
          ],
      () => [
            [1, 'a'].map((item) => item),
          ],
      () => [const Page(1)],
      () => [
            {'number': 1},
          ],
      () => [
            {1: 'a'},
          ],
      () => [
            {'1': 'a'},
          ],
      () => [
            {'sort': 'new', 'page': 1},
          ],
      () => ['Filter.done'],
      () => [
            caseInsensitive({'Page': 1})
          ],
    ];

    test(
        'compares null, bool, int, String, enums, lists, and String-keyed '
        'maps by content', () {
      List<Object?> key() => [
            'todos',
            1,
            null,
            true,
            Filter.done,
            [1, 'a'],
            {
              'page': 1,
              'tags': ['a'],
            },
          ];
      expect(sameKey(key(), key()), isTrue);
      expect(sameKey(<int>[1, 2], <Object?>[1, 2]), isTrue);
      expect(sameKey(UnmodifiableListView([1]), [1]), isTrue);
      expect(sameKey(<String, int>{'a': 1}, <String, Object?>{'a': 1}), isTrue);
    });

    test('tells apart keys that hash differently', () {
      void expectDifferent(List<Object?> a, List<Object?> b) {
        expect(hashKey(a) == hashKey(b), isFalse, reason: '$a and $b');
        expect(sameKey(a, b), isFalse, reason: '$a and $b');
        expect(sameKey(b, a), isFalse, reason: '$b and $a');
      }

      expectDifferent([1], ['1']);
      expectDifferent([1], [2]);
      expectDifferent([true], [1]);
      expectDifferent([true], [false]);
      expectDifferent([null], [false]);
      expectDifferent([null], []);
      expectDifferent([Filter.done], [Filter.todo]);
      expectDifferent([1, 2], [2, 1]);
      expectDifferent([1], [1, 2]);
      expectDifferent([
        [1],
      ], [
        1,
      ]);
      expectDifferent([
        {'a': 1},
      ], [
        {'a': 2},
      ]);
      expectDifferent([
        {'a': 1},
      ], [
        {'b': 1},
      ]);
      expectDifferent([
        {'a': 1},
      ], [
        {'a': 1, 'b': 2},
      ]);
      expectDifferent([
        {'a': 1},
      ], [
        ['a', 1],
      ]);
    });

    test('is false for what it leaves to hashing, even for the same hash', () {
      void expectHashed(List<Object?> a, List<Object?> b) {
        expect(hashKey(a), hashKey(b), reason: '$a and $b');
        expect(sameKey(a, b), isFalse, reason: '$a and $b');
      }

      expectHashed([1.5], [1.5]);
      expectHashed([DateTime.utc(2026)], [DateTime.utc(2026)]);
      expectHashed([
        {1, 2},
      ], [
        {1, 2},
      ]);
      expectHashed([
        {1, 2},
      ], [
        [1, 2],
      ]);
      expectHashed([
        [1, 2].map((item) => item),
      ], [
        [1, 2],
      ]);
      expectHashed([const Page(1)], [const Page(1)]);
      expectHashed([
        const Page(1),
      ], [
        {'number': 1},
      ]);
      expectHashed([
        {1: 'a'},
      ], [
        {1: 'a'},
      ]);
      expectHashed([
        {'a': 1, 'b': 2},
      ], [
        {'b': 2, 'a': 1},
      ]);
      expectHashed([Filter.done], ['Filter.done']);
      expectHashed(['Filter.done'], [Filter.done]);
      // Neither can be hashed.
      expect(sameKey([double.nan], [double.nan]), isFalse);
      expect(sameKey([double.infinity], [double.infinity]), isFalse);
    });

    test('compares a map by the keys it holds, not by its lookup', () {
      // The map finds 'page' under 'Page', but hashes with 'Page'.
      final map = caseInsensitive({'Page': 1});
      expect(map['page'], 1);
      expect(
          hashKey([map]) ==
              hashKey([
                {'page': 1},
              ]),
          isFalse);
      expect(
          sameKey([
            map
          ], [
            {'page': 1},
          ]),
          isFalse);
      expect(
          sameKey([
            {'page': 1},
          ], [
            map,
          ]),
          isFalse);
      expect(
          sameKey([
            map
          ], [
            caseInsensitive({'page': 1})
          ]),
          isFalse);
      expect(
          sameKey([
            map
          ], [
            caseInsensitive({'Page': 1})
          ]),
          isTrue);
    });

    test('1 and 1.0 are the same only where they hash the same, on the web',
        () {
      expect(hashKey([1]) == hashKey([1.0]), onWeb);
      expect(sameKey([1], [1.0]), onWeb);
      expect(sameKey([1.0], [1]), onWeb);
      expect(sameKey([1.0], [1.0]), onWeb);
    });

    test('-0.0 is never the same as 0, which hashes differently', () {
      expect(hashKey([0]) == hashKey([-0.0]), isFalse);
      expect(sameKey([0], [-0.0]), isFalse);
      expect(sameKey([-0.0], [0]), isFalse);
      expect(sameKey([-0.0], [-0.0]), onWeb);
    });

    test('is true only for the same hash, and always for comparable keys', () {
      for (final a in [...comparable, ...others]) {
        for (final b in [...comparable, ...others]) {
          if (sameKey(a(), b())) {
            expect(hashKey(a()), hashKey(b()), reason: '${a()} and ${b()}');
          }
        }
      }
      for (final a in comparable) {
        for (final b in comparable) {
          expect(
            sameKey(a(), b()),
            hashKey(a()) == hashKey(b()),
            reason: '${a()} and ${b()}',
          );
        }
      }
    });

    test('keyCopy copies the keys it compares, and no other', () {
      for (final key in comparable) {
        final copy = keyCopy(key())!;
        expect(identical(copy, key()), isFalse);
        expect(hashKey(copy), hashKey(key()));
        for (final other in [...comparable, ...others]) {
          expect(
            sameKey(other(), copy),
            sameKey(other(), key()),
            reason: '${other()} and ${key()}',
          );
        }
      }
      expect(keyCopy([1.0]) == null, !onWeb);
      expect(keyCopy([1.5]), isNull);
      expect(keyCopy([DateTime.utc(2026)]), isNull);
      expect(keyCopy([const Page(1)]), isNull);
      expect(
        keyCopy([
          'todos',
          [
            1,
            {1, 2},
          ],
        ]),
        isNull,
      );
      expect(
        keyCopy([
          {
            'page': {1: 'a'},
          },
        ]),
        isNull,
      );
      expect(
        keyCopy([
          {'at': DateTime.utc(2026)},
        ]),
        isNull,
      );
    });

    test('keyCopy keeps the key as it was when copied', () {
      final filter = <String, Object?>{'page': 1};
      final ids = [1, 2];
      final key = <Object?>['todos', filter, ids];
      final copy = keyCopy(key)!;
      expect(sameKey(key, copy), isTrue);

      filter['page'] = 2;
      expect(sameKey(key, copy), isFalse);
      filter['page'] = 1;
      ids[1] = 3;
      expect(sameKey(key, copy), isFalse);
      ids[1] = 2;
      key.add('done');
      expect(sameKey(key, copy), isFalse);
    });
  });

  group('partialMatchKey', () {
    test('matches list prefixes', () {
      expect(partialMatchKey(['todos', 1, 'comments'], ['todos']), isTrue);
      expect(partialMatchKey(['todos', 1], ['todos', 1]), isTrue);
      expect(partialMatchKey(['todos'], ['todos', 1]), isFalse);
      expect(partialMatchKey(['posts', 1], ['todos']), isFalse);
    });

    test('matches map subsets', () {
      expect(
        partialMatchKey([
          'todos',
          {'page': 1, 'filter': 'done'},
        ], [
          'todos',
          {'filter': 'done'},
        ]),
        isTrue,
      );
      expect(
        partialMatchKey([
          'todos',
          {'page': 1},
        ], [
          'todos',
          {'filter': 'done'},
        ]),
        isFalse,
      );
    });
  });

  group('replaceEqualDeep', () {
    test('returns the previous map when it is deeply equal', () {
      const json = '{"items": [{"id": 1, "author": {"name": "a"}}], '
          '"next": null}';
      final previous = jsonDecode(json);
      expect(
        identical(replaceEqualDeep(previous, jsonDecode(json)), previous),
        isTrue,
      );

      final ordered = {'a': 1, 'b': 2};
      expect(
        identical(replaceEqualDeep(ordered, {'b': 2, 'a': 1}), ordered),
        isTrue,
      );
    });

    test('returns the next map when anything differs', () {
      void expectNext(Map<Object?, Object?> a, Map<Object?, Object?> b) {
        expect(identical(replaceEqualDeep(a, b), b), isTrue);
      }

      expectNext({'a': 1}, {'a': 1, 'b': 2});
      expectNext(<String, int>{'a': 1}, <String, Object>{'a': 1});
      expectNext({'x': null}, {'y': null});
      expectNext({
        'a': {'b': 1},
      }, {
        'a': {'b': 2},
      });
      expectNext({
        'a': [1],
      }, {
        'a': [2],
      });
    });
  });
}

/// A map that finds `'page'` under `'Page'`.
Map<String, int> caseInsensitive(Map<String, int> entries) {
  return CanonicalizedMap.from(entries, (key) => key.toLowerCase());
}
