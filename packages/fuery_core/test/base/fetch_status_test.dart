import 'package:fuery_core/src/base/query_state.dart';
import 'package:test/test.dart';

void main() {
  group('FetchStatus', () {
    test('FetchStatus.isIdle works properly.', () {
      // Arrange
      const status = FetchStatus.idle;

      // Assert
      expect(status.isIdle, isTrue);
      expect(status.isFetching, isFalse);
      expect(status.isRefetching, isFalse);
    });

    test('FetchStatus.isFetching works properly.', () {
      // Arrange
      const status = FetchStatus.fetching;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isFetching, isTrue);
      expect(status.isRefetching, isFalse);
    });

    test('FetchStatus.isRefetching works properly.', () {
      // Arrange
      const status = FetchStatus.refetching;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isFetching, isFalse);
      expect(status.isRefetching, isTrue);
    });
  });
}
