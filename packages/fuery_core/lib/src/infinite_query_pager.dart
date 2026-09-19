import 'package:fuery_core/src/base/typedefs.dart';

class InfiniteQueryPager<Param, Data> {
  InfiniteQueryPager({
    required Param initialPageParam,
    required InfiniteQueryNextParamGetter<Param, Data> getNextPageParam,
    InfiniteQueryPreviousParamGetter<Param, Data>? getPreviousPageParam,
  })  : _initialPageParam = initialPageParam,
        _getNextPageParam = getNextPageParam,
        _getPreviousPageParam = getPreviousPageParam;

  final Param _initialPageParam;
  Param get initialPageParam => _initialPageParam;

  final InfiniteQueryNextParamGetter<Param, Data> _getNextPageParam;
  InfiniteQueryNextParamGetter<Param, Data> get getNextPageParam =>
      _getNextPageParam;

  final InfiniteQueryPreviousParamGetter<Param, Data>? _getPreviousPageParam;
  InfiniteQueryPreviousParamGetter<Param, Data>? get getPreviousPageParam =>
      _getPreviousPageParam;
}
