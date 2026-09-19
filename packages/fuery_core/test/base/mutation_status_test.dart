import 'package:fuery_core/src/base/mutation_state.dart';
import 'package:test/test.dart';

void main() {
  group('MutationStatus', () {
    test('MutationStatus.isIdle works properly.', () {
      // Arrange
      const status = MutationStatus.idle;

      // Assert
      expect(status.isIdle, isTrue);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isFalse);
    });

    test('MutationStatus.isPending works properly.', () {
      // Arrange
      const status = MutationStatus.pending;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isTrue);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isFalse);
    });

    test('MutationStatus.isFailure works properly.', () {
      // Arrange
      const status = MutationStatus.failure;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isTrue);
      expect(status.isSuccess, isFalse);
    });

    test('MutationStatus.isSuccess works properly', () {
      // Arrange
      const status = MutationStatus.success;

      // Assert
      expect(status.isIdle, isFalse);
      expect(status.isPending, isFalse);
      expect(status.isFailure, isFalse);
      expect(status.isSuccess, isTrue);
    });
  });
}
