import 'package:fuery_core/src/base/cacheable.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:test/test.dart';

void main() {
  group('Cacheable', () {
    // Arrange
    final FueryKey key = ['A', 1];
    final Cacheable cacheable = Cacheable(key: key);

    test('Cacheable.key returns the key as it is', () {
      // Assert
      expect(cacheable.key == key, isTrue);
    });

    test('Cacheable.encodedKey returns the stringified key', () {
      // Assert
      expect(cacheable.encodedKey, TypeMatcher<String>());
      expect(cacheable.encodedKey == key.toString(), isTrue);
    });
  });
}
