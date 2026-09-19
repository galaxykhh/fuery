import 'package:fuery_core/fuery_core.dart';
import 'package:fuery_core/src/base/query_result.dart';

class InfiniteQueryResult<Param, Data, Err> extends QueryResultBase<
    List<InfiniteData<Param, Data>>,
    Err,
    QueryState<List<InfiniteData<Param, Data>>, Err>> {
  InfiniteQueryResult({
    required super.stream,
    required super.refetch,
    required super.updateOptions,
    required void Function() fetchNextPage,
    required void Function()? fetchPreviousPage,
    required void Function() reset,
    required bool Function() hasNextPage,
    required bool Function() hasPreviousPage,
  })  : _fetchNextPage = fetchNextPage,
        _fetchPreviousPage = fetchPreviousPage,
        _hasNextPage = hasNextPage,
        _hasPreviousPage = hasPreviousPage,
        _reset = reset;

  void Function() _fetchNextPage;
  void fetchNextPage() => _fetchNextPage();

  void Function()? _fetchPreviousPage;
  void fetchPreviousPage() => _fetchPreviousPage?.call();

  bool Function() _hasNextPage;
  bool get hasNextPage => _hasNextPage();

  bool Function() _hasPreviousPage;
  bool get hasPreviousPage => _hasPreviousPage();

  void Function() _reset;
  void reset() => _reset();

  Stream<T> select<T>(
      T Function(List<InfiniteData<Param, Data>> pages) selector) {
    return data.map((pages) => selector(pages ?? []));
  }
}
