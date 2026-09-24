import 'dart:convert';

import 'package:fuery_core/fuery_core.dart';
import 'package:fuery_core/src/utils.dart' show partialMatchKey;
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
