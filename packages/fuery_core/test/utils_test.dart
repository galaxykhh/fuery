import 'package:fuery_core/fuery_core.dart';
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
}
