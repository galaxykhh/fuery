import 'package:fuery_core/src/base/query.dart';
import 'package:fuery_core/src/base/query_state.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/fuery_client.dart';
import 'package:fuery_core/src/infinite_query_pager.dart';
import 'package:fuery_core/src/infinite_query_result.dart';
import 'package:fuery_core/src/infinite_data.dart';
import 'package:fuery_core/src/infinite_query_state.dart';
import 'package:fuery_core/src/query_options.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:fuery_core/src/util/timestamp.dart';
import 'package:rxdart/rxdart.dart';

enum Direction {
  forward,
  backward;

  bool get isForward => this == forward;
  bool get isBackward => this == backward;
}

class InfiniteQuery<Param, Data, Err> extends QueryBase<
    List<InfiniteData<Param, Data>>,
    Err,
    InfiniteQueryState<List<InfiniteData<Param, Data>>, Err>> {
  InfiniteQuery._({
    required QueryKey queryKey,
    required InfiniteQueryFn<Param, Data> queryFn,
    QueryOptions<Data>? options,
    required Param initialPageParam,
    required InfiniteQueryNextParamGetter<Param, Data> getNextPageParam,
    InfiniteQueryPreviousParamGetter<Param, Data>? getPreviousPageParam,
  })  : _queryFn = queryFn,
        _pager = InfiniteQueryPager(
          initialPageParam: initialPageParam,
          getNextPageParam: getNextPageParam,
          getPreviousPageParam: getPreviousPageParam,
        ),
        super(
          queryKey: queryKey,
          state: InfiniteQueryState(
            status: QueryStatus.idle,
            fetchStatus: FetchStatus.idle,
            invalidated: false,
            updatedAt: options?.initialData == null
                ? const Timestamp(0)
                : Timestamp.now(),
          ),
          options: QueryOptions<Data>(
            initialData: options?.initialData,
            gcTime: options?.gcTime ?? Fuery.instance.defaultOptions.gcTime,
            staleTime:
                options?.staleTime ?? Fuery.instance.defaultOptions.staleTime,
            refetchInterval: options?.refetchInterval ??
                Fuery.instance.defaultOptions.refetchInterval,
          ),
        );

  /// Returns [InfiniteQueryResult] new or existing [InfiniteQuery].
  ///
  /// If there is no existing cached [InfiniteQuery] with the same [queryKey], it creates a new [InfiniteQuery] instance.
  ///
  /// example:
  /// ```dart
  /// late final posts = InfiniteQuery.use(
  /// 	queryKey: ['posts', 'list'],
  /// 	queryFn: (int page) => getPostsByPage(page),
  /// 	initialPageParam: 1,
  /// 	getNextPageParam: (lastPage, allPages) {
  /// 		return lastPage.data.nextCursor;
  /// 	},
  /// );
  /// ```
  static InfiniteQueryResult<Param, Data, Err> use<Param, Data, Err>({
    required QueryKey queryKey,
    required InfiniteQueryFn<Param, Data> queryFn,
    int? gcTime,
    int? staleTime,
    int? refetchInterval,
    Data? initialData,
    required Param initialPageParam,
    required InfiniteQueryNextParamGetter<Param, Data> getNextPageParam,
    InfiniteQueryPreviousParamGetter<Param, Data>? getPreviousPageParam,
    bool? resetOnRefetch,
  }) {
    QueryBase? query = Fuery.instance.getQuery(queryKey);
    final QueryOptions<Data> options = QueryOptions(
      gcTime: gcTime,
      initialData: initialData,
      staleTime: staleTime,
      refetchInterval: refetchInterval,
    );
    final bool exists = query is QueryBase && query is InfiniteQuery;

    if (exists) {
      query.updateOptions(options);

      final bool shouldRefetch = !query.stream.value.isLoading && query.isStale;
      if (shouldRefetch) query.refetch();
    } else {
      query = InfiniteQuery<Param, Data, Err>._(
        queryKey: queryKey,
        queryFn: queryFn,
        options: options,
        initialPageParam: initialPageParam,
        getNextPageParam: getNextPageParam,
        getPreviousPageParam: getPreviousPageParam,
      );

      Fuery.instance.addQuery(
        queryKey,
        query,
      );

      query.fetch();
    }

    return InfiniteQueryResult(
      stream: query.stream
          as ValueStream<QueryState<List<InfiniteData<Param, Data>>, Err>>,
      refetch: query.refetch,
      updateOptions: query.updateOptions,
      fetchNextPage: query.fetchNextPage,
      fetchPreviousPage: query.fetchPreviousPage,
      reset: query.reset,
      hasNextPage: () {
        return (query as InfiniteQuery<Param, Data, Err>).hasNextPage;
      },
      hasPreviousPage: () {
        return (query as InfiniteQuery<Param, Data, Err>).hasPreviousPage;
      },
    );
  }

  final InfiniteQueryFn<Param, Data> _queryFn;

  final InfiniteQueryPager<Param, Data> _pager;

  /// Called when an new [InfiniteQuery] created.
  ///
  /// In general, there won't typically be a situation where you directly call during development.
  @override
  void fetch() {
    if (stream.value.isLoading) return;

    super.emit(stream.value.copyWith(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
    ));

    _invokeQueryFn(
      param: _pager.initialPageParam,
      direction: Direction.forward,
      resetOnEmit: true,
    );
  }

  /// Refresh all pages.
  ///
  /// When there's already an existing [InfiniteQuery], it will be automatically called when necessary.
  @override
  void refetch() async {
    if (shouldSkipFetch) return;

    final List<Param> params =
        (stream.value.data ?? []).map((e) => e.param).toList();
    final bool shouldRefetch = params.isNotEmpty || stream.value.isError;

    if (!shouldRefetch) return;

    if (stream.value.isError) {
      fetch();
      return;
    }

    try {
      super.emit(stream.value.copyWith(fetchStatus: FetchStatus.refetching));

      final List<InfiniteData<Param, Data>> pages = [];

      for (final Param param in params) {
        final Data data = await _queryFn(param);
        final InfiniteData<Param, Data> page = InfiniteData<Param, Data>(
          data: data,
          param: param,
        );

        pages.add(page);
      }

      super.emit(stream.value.copyWith(
        data: () => pages,
        error: () => null,
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        invalidated: false,
      ));
    } catch (e) {
      super.emit(stream.value.copyWith(
        error: () => e as Err,
        status: QueryStatus.failure,
        fetchStatus: FetchStatus.idle,
      ));
    }
  }

  /// invalidate [InfiniteQuery].
  ///
  /// It indicates to [refetch] when [hasListener] is true or the [InfiniteQuery] with the same [key] is called.
  @override
  void invalidate() {
    super.invalidate();
    if (hasListener) refetch();
  }

  /// Request next page.
  void fetchNextPage() {
    if (_shouldSkipFetchNextPage) return;
    if (!hasNextPage) return;

    super.emit(stream.value.copyWith(nextPageStatus: QueryStatus.pending));

    final Param? nextPageParam = _pager.getNextPageParam(
      stream.value.data!.last,
      stream.value.data!,
    );

    if (nextPageParam != null) {
      _invokeQueryFn(
        param: nextPageParam,
        direction: Direction.forward,
        resetOnEmit: false,
      );
    }
  }

  /// Request previous page.
  void fetchPreviousPage() {
    if (_shouldSkipFetchPreviousPage) return;
    if (!hasPreviousPage) return;

    super.emit(stream.value.copyWith(previousPageStatus: QueryStatus.pending));

    final Param? previousPageParam = _pager.getPreviousPageParam?.call(
      stream.value.data!.last,
      stream.value.data!,
    );

    if (previousPageParam != null) {
      _invokeQueryFn(
        param: previousPageParam,
        direction: Direction.backward,
        resetOnEmit: false,
      );
    }
  }

  /// Reset all pages and fetch first page based on [initialPageParam].
  void reset() {
    if (shouldSkipFetch) return;

    super.emit(stream.value.copyWith(
      data: () => const [],
      status: QueryStatus.idle,
      fetchStatus: FetchStatus.idle,
      nextPageStatus: QueryStatus.idle,
      previousPageStatus: QueryStatus.idle,
      error: () => null,
      invalidated: true,
    ));

    fetch();
  }

  Future<void> _invokeQueryFn({
    required Param param,
    Direction? direction,
    required bool resetOnEmit,
  }) async {
    try {
      final Data data = await _queryFn(param);
      final InfiniteData<Param, Data> page = InfiniteData(
        data: data,
        param: param,
      );

      super.emit(stream.value.copyWith(
        data: () {
          if (stream.value.data == null || direction == null || resetOnEmit) {
            return [
              InfiniteData(data: data, param: param),
            ];
          }

          return direction.isForward
              ? [
                  ...stream.value.data ?? [],
                  page,
                ]
              : [
                  page,
                  ...stream.value.data ?? [],
                ];
        },
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        nextPageStatus:
            direction?.isForward ?? false ? QueryStatus.success : null,
        previousPageStatus:
            direction?.isBackward ?? false ? QueryStatus.success : null,
        invalidated: false,
      ));
    } catch (e) {
      super.emit(stream.value.copyWith(
        error: () => e as Err,
        status: QueryStatus.failure,
        fetchStatus: FetchStatus.idle,
      ));
    }
  }

  /// Returns true when has data.
  bool get hasData =>
      stream.value.data != null &&
      stream.value.data is List<InfiniteData<Param, Data>>;

  /// Returns true when has next page.
  bool get hasNextPage {
    if (!hasData || stream.value.data?.isEmpty == true) {
      return false;
    }

    return _pager.getNextPageParam(stream.value.data!.last, stream.value.data!)
        is Param;
  }

  /// Return true when has previous page.
  bool get hasPreviousPage {
    if (stream.value.data == null || stream.value.data?.isEmpty == true) {
      return false;
    }

    return _pager.getPreviousPageParam
        ?.call(stream.value.data!.first, stream.value.data!) is Param;
  }

  /// Returns true when should skip fetch next page.
  bool get _shouldSkipFetchNextPage {
    return super.shouldSkipFetch || stream.value.nextPageStatus.isPending;
  }

  /// Returns true when should skip fetch previous page.
  bool get _shouldSkipFetchPreviousPage {
    return super.shouldSkipFetch || stream.value.previousPageStatus.isPending;
  }
}
