import 'package:fuery_core/src/base/query_state.dart';
import 'package:test/test.dart';

void main() {
  group('QueryStatus', () {
    test('QueryStatus.isIdle works properly.', () {
      // Arrange
      const status = QueryStatus.idle;

      // Assert
      expect(status.isIdle, isTrue);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isFalse);
    });

    test('QueryStatus.isPending works properly.', () {
      // Arrange
      const status = QueryStatus.pending;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isTrue);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isFalse);
    });

    test('QueryStatus.isFailure works properly.', () {
      // Arrange
      const status = QueryStatus.failure;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isTrue);
      expect(status.isSuccess, isFalse);
    });

    test('QueryStatus.isSuccess works properly', () {
      // Arrange
      const status = QueryStatus.success;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isTrue);
    });
  });
}
