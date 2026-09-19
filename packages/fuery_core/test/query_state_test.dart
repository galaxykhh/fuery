import 'package:fuery_core/src/base/query_state.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:fuery_core/src/util/timestamp.dart';
import 'package:test/test.dart';

void main() {
  group('QueryState', () {
    test('boolean getters works properly', () {
      // Arrange (case: Initial loading)
      QueryState state = QueryState<int, Exception>(
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.fetching,
        invalidated: false,
        updatedAt: Timestamp.now(),
      );

      // Assert
      expect(state.isPending, isTrue);
      expect(state.isFetching, isTrue);
      expect(state.isLoading, isTrue);
      expect(state.isRefetching, isFalse);
      expect(state.isError, isFalse);

      // Arrange (case: When success)
      state = state.copyWith(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: () => 1,
      );

      // Assert
      expect(state.isPending, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isRefetching, isFalse);
      expect(state.isError, isFalse);

      // Arrange (case: When refetch or invalidated)
      state = state.copyWith(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.refetching,
      );

      expect(state.isPending, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isRefetching, isTrue);
      expect(state.isError, isFalse);

      // Arrange (case: When error occurred)
      state = state.copyWith(
        status: QueryStatus.failure,
        fetchStatus: FetchStatus.idle,
        error: () => Exception(),
      );

      expect(state.isPending, isFalse);
      expect(state.isFetching, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isRefetching, isFalse);
      expect(state.isError, isTrue);
    });
  });
}
