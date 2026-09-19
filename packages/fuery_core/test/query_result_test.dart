// ignore_for_file: dead_code
import 'package:fuery_core/fuery_core.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

void main() {
  const delay = const Duration(milliseconds: 150);

  bool shouldThrowError = false;

  // Returns [value] wrapped in Future.
  Future<String> getFutureValue(String value) async {
    await Future.delayed(delay);

    if (shouldThrowError) {
      throw Exception();
    }

    return value;
  }

  // Return [QueryResult] from cache. create if not exists.
  QueryResult<String, dynamic> getQueryResult() {
    return Query.use(
      queryKey: ['query_result_test'],
      queryFn: () => getFutureValue('A'),
    );
  }

  // Arrange
  final result = getQueryResult();

  group('QueryResult', () {
    test('Getters in QueryResult works properly', () {
      // Assert
      expect(
        result.stream,
        TypeMatcher<ValueStream<QueryState<String, dynamic>>>(),
      );
      expect(result.data, TypeMatcher<Stream<String?>>());
      expect(result.status, TypeMatcher<Stream<QueryStatus>>());
      expect(result.error, TypeMatcher<Stream<dynamic>>());
      expect(result.refetch, TypeMatcher<void Function()>());
    });

    test('refetch (success) works properly', () async {
      // Act
      await Future.delayed(delay);
      result.refetch();

      // Assert A
      expect(result.isPending, isFalse);
      expect(result.isRefetching, isTrue);

      await Future.delayed(delay);

      // Assert B
      expect(result.isSuccess, isTrue);
      expect(result.isPending, isFalse);
      expect(result.isRefetching, isFalse);
    });

    test('refetch (error) works properly', () async {
      // Act
      await Future.delayed(delay);
      shouldThrowError = true;
      result.refetch();

      // Assert A
      expect(result.isPending, isFalse);
      expect(result.isRefetching, isTrue);

      await Future.delayed(delay);

      // Assert B
      expect(result.isError, isTrue);
      expect(result.errorValue, TypeMatcher<Exception>());
    });
  });
}
