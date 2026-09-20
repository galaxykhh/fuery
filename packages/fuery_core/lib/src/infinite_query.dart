part of 'core.dart';

typedef InfiniteQueryFn<TPage, TParam> = Future<TPage> Function(
  InfiniteQueryFunctionContext<TParam> context,
);

/// Returns the param for the page after `data.lastPage`, or `null` if there is
/// no next page.
typedef GetNextPageParam<TPage, TParam> = TParam? Function(
  InfiniteData<TPage, TParam> data,
);

/// Returns the param for the page before `data.firstPage`, or `null` if there
/// is no previous page.
typedef GetPreviousPageParam<TPage, TParam> = TParam? Function(
  InfiniteData<TPage, TParam> data,
);

/// The pages loaded by an infinite query, with the param used for each.
@immutable
class InfiniteData<TPage, TParam> {
  const InfiniteData({required this.pages, required this.pageParams});

  final List<TPage> pages;
  final List<TParam> pageParams;

  TPage get firstPage => pages.first;
  TPage get lastPage => pages.last;
  TParam get firstPageParam => pageParams.first;
  TParam get lastPageParam => pageParams.last;

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    return other is InfiniteData<TPage, TParam> &&
        _equality.equals(other.pages, pages) &&
        _equality.equals(other.pageParams, pageParams);
  }

  @override
  int get hashCode =>
      Object.hash(_equality.hash(pages), _equality.hash(pageParams));

  @override
  String toString() => 'InfiniteData(pages: $pages, pageParams: $pageParams)';
}

class InfiniteQueryFunctionContext<TParam> extends QueryFunctionContext {
  InfiniteQueryFunctionContext._({
    required super.client,
    required super.queryKey,
    required super.meta,
    required super.signal,
    required this.pageParam,
  }) : super._();

  final TParam pageParam;
}

/// Fetches pages for an infinite query. Refetching re-fetches every loaded
/// page in order, recomputing each page param from the fresh pages.
class _InfiniteQueryBehavior<TPage, TParam>
    implements _QueryBehavior<InfiniteData<TPage, TParam>> {
  _InfiniteQueryBehavior({
    required this.queryFn,
    required this.initialPageParam,
    required this.getNextPageParam,
    this.getPreviousPageParam,
    this.maxPages,
    this.pages,
  });

  final InfiniteQueryFn<TPage, TParam> queryFn;
  final TParam initialPageParam;
  final GetNextPageParam<TPage, TParam> getNextPageParam;
  final GetPreviousPageParam<TPage, TParam>? getPreviousPageParam;

  /// Keep at most this many pages. Older pages are dropped from the other end.
  final int? maxPages;

  /// How many pages to load when nothing is cached. Defaults to one. With
  /// cached pages, a full fetch reloads all of them.
  final int? pages;

  @override
  void onFetch(
    _FetchContext<InfiniteData<TPage, TParam>> context,
    Query<InfiniteData<TPage, TParam>> query,
  ) {
    final direction = context.fetchOptions?.direction;
    final oldPages = context.state.data?.pages ?? <TPage>[];
    final oldPageParams = context.state.data?.pageParams ?? <TParam>[];

    context.fetchFn = () async {
      var cancelled = false;
      var signalConsumed = false;

      AbortSignal signal() {
        final signal = context.signal;
        if (!signalConsumed) {
          signalConsumed = true;
          signal.onAbort(() => cancelled = true);
        }
        return signal;
      }

      Future<InfiniteData<TPage, TParam>> fetchPage(
        InfiniteData<TPage, TParam> data,
        TParam? param, {
        bool previous = false,
      }) async {
        if (cancelled) throw context.signal.reason ?? const CancelledError();

        if (param == null && data.pages.isNotEmpty) return data;

        final pageParam = param as TParam;
        final page = await queryFn(InfiniteQueryFunctionContext<TParam>._(
          client: context.client,
          queryKey: context.queryKey,
          meta: context.options.meta,
          signal: signal,
          pageParam: pageParam,
        ));

        return previous
            ? InfiniteData(
                pages: addToStart(data.pages, page, maxPages),
                pageParams: addToStart(data.pageParams, pageParam, maxPages),
              )
            : InfiniteData(
                pages: addToEnd(data.pages, page, maxPages),
                pageParams: addToEnd(data.pageParams, pageParam, maxPages),
              );
      }

      if (direction != null && oldPages.isNotEmpty) {
        final previous = direction == _FetchDirection.backward;
        final oldData = InfiniteData<TPage, TParam>(
          pages: oldPages,
          pageParams: oldPageParams,
        );
        final param = previous ? _previousParam(oldData) : _nextParam(oldData);
        return fetchPage(oldData, param, previous: previous);
      }

      final remainingPages = oldPages.isEmpty ? pages ?? 1 : oldPages.length;
      var result = InfiniteData<TPage, TParam>(pages: [], pageParams: []);
      var currentPage = 0;

      do {
        final TParam? param;
        if (currentPage == 0) {
          param =
              oldPageParams.isNotEmpty ? oldPageParams.first : initialPageParam;
        } else {
          param = _nextParam(result);
          if (param == null) break;
        }
        result = await fetchPage(result, param);
        currentPage++;
      } while (currentPage < remainingPages);

      return result;
    };
  }

  TParam? _nextParam(InfiniteData<TPage, TParam> data) {
    if (data.pages.isEmpty) return null;
    return getNextPageParam(data);
  }

  TParam? _previousParam(InfiniteData<TPage, TParam> data) {
    if (data.pages.isEmpty) return null;
    return getPreviousPageParam?.call(data);
  }

  bool hasNextPage(InfiniteData<TPage, TParam>? data) {
    return data != null && _nextParam(data) != null;
  }

  bool hasPreviousPage(InfiniteData<TPage, TParam>? data) {
    return data != null && _previousParam(data) != null;
  }
}

/// Options for an infinite query.
class InfiniteQueryOptions<TPage, TParam>
    extends QueryOptions<InfiniteData<TPage, TParam>> {
  InfiniteQueryOptions({
    required super.queryKey,
    required InfiniteQueryFn<TPage, TParam> queryFn,
    required TParam initialPageParam,
    required GetNextPageParam<TPage, TParam> getNextPageParam,
    GetPreviousPageParam<TPage, TParam>? getPreviousPageParam,
    int? maxPages,
    int? pages,
    bool Function(InfiniteQueryResult<TPage, TParam> result)? refetchWhile,
    super.enabled,
    super.staleTime,
    super.gcTime,
    super.refetchInterval,
    super.refetchIntervalInBackground,
    super.refetchOnMount,
    super.refetchOnFocus,
    super.refetchOnReconnect,
    super.retryOnMount,
    super.retry,
    super.retryDelay,
    super.networkMode,
    super.initialData,
    super.initialDataUpdatedAt,
    super.placeholderData,
    super.structuralSharing,
    InfiniteQueryPersist<TPage, Object?>? persist,
    super.meta,
  }) : super._withBehavior(
          persist: persist?._toQueryPersist<TParam>(),
          // Infinite observers always report InfiniteQueryResults.
          refetchWhile: refetchWhile == null
              ? null
              : (result) => refetchWhile(
                    result as InfiniteQueryResult<TPage, TParam>,
                  ),
          behavior: _InfiniteQueryBehavior<TPage, TParam>(
            queryFn: queryFn,
            initialPageParam: initialPageParam,
            getNextPageParam: getNextPageParam,
            getPreviousPageParam: getPreviousPageParam,
            maxPages: maxPages,
            pages: pages,
          ),
        );
}

/// What an [InfiniteQueryObserver] reports to its listeners.
class InfiniteQueryResult<TPage, TParam>
    extends QueryResult<InfiniteData<TPage, TParam>> {
  InfiniteQueryResult._fromBase(
    QueryResult<InfiniteData<TPage, TParam>> base, {
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  }) : super(
          status: base.status,
          fetchStatus: base.fetchStatus,
          data: base.data,
          dataUpdatedAt: base.dataUpdatedAt,
          error: base.error,
          errorUpdatedAt: base.errorUpdatedAt,
          errorUpdateCount: base.errorUpdateCount,
          failureCount: base.failureCount,
          failureReason: base.failureReason,
          isFetched: base.isFetched,
          isFetchedAfterMount: base.isFetchedAfterMount,
          isPlaceholderData: base.isPlaceholderData,
          isStale: base.isStale,
          isEnabled: base.isEnabled,
        );

  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final bool isFetchNextPageError;
  final bool isFetchPreviousPageError;

  /// All pages, or an empty list if there is no data yet.
  List<TPage> get pages => data?.pages ?? const [];

  @override
  bool get isRefetching =>
      super.isRefetching && !isFetchingNextPage && !isFetchingPreviousPage;

  @override
  bool get isRefetchError =>
      super.isRefetchError &&
      !isFetchNextPageError &&
      !isFetchPreviousPageError;

  @override
  bool operator ==(Object other) {
    return super == other &&
        other is InfiniteQueryResult<TPage, TParam> &&
        other.hasNextPage == hasNextPage &&
        other.hasPreviousPage == hasPreviousPage &&
        other.isFetchingNextPage == isFetchingNextPage &&
        other.isFetchingPreviousPage == isFetchingPreviousPage &&
        other.isFetchNextPageError == isFetchNextPageError &&
        other.isFetchPreviousPageError == isFetchPreviousPageError;
  }

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        hasNextPage,
        hasPreviousPage,
        isFetchingNextPage,
        isFetchingPreviousPage,
        isFetchNextPageError,
        isFetchPreviousPageError,
      );
}

/// Watches an infinite query and loads more pages on demand.
class InfiniteQueryObserver<TPage, TParam>
    extends QueryObserver<InfiniteData<TPage, TParam>> {
  InfiniteQueryObserver(
    super.client,
    InfiniteQueryOptions<TPage, TParam> super.options,
  );

  late final Stream<InfiniteQueryResult<TPage, TParam>> _infiniteStream =
      super.stream.cast();

  @override
  InfiniteQueryResult<TPage, TParam> get result =>
      super.result as InfiniteQueryResult<TPage, TParam>;

  @override
  Stream<InfiniteQueryResult<TPage, TParam>> get stream => _infiniteStream;

  @override
  InfiniteQueryResult<TPage, TParam> getOptimisticResult() =>
      super.getOptimisticResult() as InfiniteQueryResult<TPage, TParam>;

  /// Fetches the page after the last loaded page.
  ///
  /// With [cancelRefetch], a fetch that is already running is cancelled and
  /// restarted. Check `!result.isFetching` first to avoid that.
  Future<InfiniteQueryResult<TPage, TParam>> fetchNextPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    final result = await _fetch(
      _FetchOptions(
        cancelRefetch: cancelRefetch,
        direction: _FetchDirection.forward,
      ),
      throwOnError,
    );
    return result as InfiniteQueryResult<TPage, TParam>;
  }

  /// Fetches the page before the first loaded page.
  Future<InfiniteQueryResult<TPage, TParam>> fetchPreviousPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    final result = await _fetch(
      _FetchOptions(
        cancelRefetch: cancelRefetch,
        direction: _FetchDirection.backward,
      ),
      throwOnError,
    );
    return result as InfiniteQueryResult<TPage, TParam>;
  }

  @override
  Future<InfiniteQueryResult<TPage, TParam>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) async {
    final result = await super.refetch(
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
    return result as InfiniteQueryResult<TPage, TParam>;
  }

  @override
  QueryResult<InfiniteData<TPage, TParam>> _buildResult(
    QueryState<InfiniteData<TPage, TParam>> state,
    QueryOptions<InfiniteData<TPage, TParam>> options,
    QueryResult<InfiniteData<TPage, TParam>> base,
  ) {
    final behavior =
        options._behavior! as _InfiniteQueryBehavior<TPage, TParam>;
    final data = state.data;
    final direction = state._fetchDirection;
    final forward = direction == _FetchDirection.forward;
    final backward = direction == _FetchDirection.backward;

    return InfiniteQueryResult<TPage, TParam>._fromBase(
      base,
      hasNextPage: behavior.hasNextPage(data),
      hasPreviousPage: behavior.hasPreviousPage(data),
      isFetchingNextPage: base.isFetching && forward,
      isFetchingPreviousPage: base.isFetching && backward,
      isFetchNextPageError: base.isError && forward,
      isFetchPreviousPageError: base.isError && backward,
    );
  }
}

/// Builds [InfiniteQueryOptions] with the page and param types inferred from
/// the arguments, for example for [QueryClient.infiniteQuery].
///
/// Prefer this over the [InfiniteQueryOptions] constructor, which needs
/// explicit type arguments. See [InfiniteQuery.use] for the parameters.
/// [pages] sets how many pages to load when nothing is cached, for example
/// to prefetch several pages with [QueryClient.infiniteQuery].
InfiniteQueryOptions<TPage, TParam> infiniteQueryOptions<
    TPage,
    TParam,
    TNext extends TParam?,
    TPrev extends TParam?,
    TPersistParam extends Object?>({
  required QueryKey queryKey,
  required InfiniteQueryFn<TPage, TParam> queryFn,
  required TParam initialPageParam,
  required TNext Function(InfiniteData<TPage, TParam> data) getNextPageParam,
  TPrev Function(InfiniteData<TPage, TParam> data)? getPreviousPageParam,
  int? maxPages,
  int? pages,
  bool? enabled,
  Duration? staleTime,
  Duration? gcTime,
  Duration? refetchInterval,
  bool? refetchIntervalInBackground,
  bool Function(InfiniteQueryResult<TPage, TParam> result)? refetchWhile,
  RefetchMode? refetchOnMount,
  RefetchMode? refetchOnFocus,
  RefetchMode? refetchOnReconnect,
  bool? retryOnMount,
  RetryPolicy? retry,
  RetryDelay? retryDelay,
  NetworkMode? networkMode,
  InfiniteData<TPage, TParam>? initialData,
  int? initialDataUpdatedAt,
  PlaceholderDataFn<InfiniteData<TPage, TParam>>? placeholderData,
  bool? structuralSharing,
  InfiniteQueryPersist<TPage, TPersistParam>? persist,
  Map<String, Object?>? meta,
}) {
  return InfiniteQueryOptions<TPage, TParam>(
    queryKey: queryKey,
    queryFn: queryFn,
    initialPageParam: initialPageParam,
    getNextPageParam: getNextPageParam,
    getPreviousPageParam: getPreviousPageParam,
    maxPages: maxPages,
    pages: pages,
    enabled: enabled,
    staleTime: staleTime,
    gcTime: gcTime,
    refetchInterval: refetchInterval,
    refetchIntervalInBackground: refetchIntervalInBackground,
    refetchWhile: refetchWhile,
    refetchOnMount: refetchOnMount,
    refetchOnFocus: refetchOnFocus,
    refetchOnReconnect: refetchOnReconnect,
    retryOnMount: retryOnMount,
    retry: retry,
    retryDelay: retryDelay,
    networkMode: networkMode,
    initialData: initialData,
    initialDataUpdatedAt: initialDataUpdatedAt,
    placeholderData: placeholderData,
    structuralSharing: structuralSharing,
    persist: persist,
    meta: meta,
  );
}

/// Entry point for infinite queries.
abstract final class InfiniteQuery {
  /// Watches the infinite query for [queryKey].
  ///
  /// [getNextPageParam] returns the param for the page after `data.lastPage`,
  /// or `null` when there are no more pages. The page and param types are
  /// inferred from [queryFn] and [initialPageParam].
  ///
  /// ```dart
  /// final posts = InfiniteQuery.use(
  ///   queryKey: ['posts'],
  ///   queryFn: (context) => api.getPosts(page: context.pageParam),
  ///   initialPageParam: 1,
  ///   getNextPageParam: (data) =>
  ///       data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  /// );
  /// ```
  ///
  /// When the first page has no param, give `null` its type so the param type
  /// can be inferred: `initialPageParam: null as String?`.
  static InfiniteQueryObserver<TPage, TParam> use<
      TPage,
      TParam,
      TNext extends TParam?,
      TPrev extends TParam?,
      TPersistParam extends Object?>({
    required QueryKey queryKey,
    required InfiniteQueryFn<TPage, TParam> queryFn,
    required TParam initialPageParam,
    required TNext Function(InfiniteData<TPage, TParam> data) getNextPageParam,
    TPrev Function(InfiniteData<TPage, TParam> data)? getPreviousPageParam,
    int? maxPages,
    bool? enabled,
    Duration? staleTime,
    Duration? gcTime,
    Duration? refetchInterval,
    bool? refetchIntervalInBackground,
    bool Function(InfiniteQueryResult<TPage, TParam> result)? refetchWhile,
    RefetchMode? refetchOnMount,
    RefetchMode? refetchOnFocus,
    RefetchMode? refetchOnReconnect,
    bool? retryOnMount,
    RetryPolicy? retry,
    RetryDelay? retryDelay,
    NetworkMode? networkMode,
    InfiniteData<TPage, TParam>? initialData,
    int? initialDataUpdatedAt,
    PlaceholderDataFn<InfiniteData<TPage, TParam>>? placeholderData,
    bool? structuralSharing,
    InfiniteQueryPersist<TPage, TPersistParam>? persist,
    Map<String, Object?>? meta,
    QueryClient? client,
  }) {
    return InfiniteQueryObserver<TPage, TParam>(
      client ?? Fuery.client,
      infiniteQueryOptions(
        queryKey: queryKey,
        queryFn: queryFn,
        initialPageParam: initialPageParam,
        getNextPageParam: getNextPageParam,
        getPreviousPageParam: getPreviousPageParam,
        maxPages: maxPages,
        enabled: enabled,
        staleTime: staleTime,
        gcTime: gcTime,
        refetchInterval: refetchInterval,
        refetchIntervalInBackground: refetchIntervalInBackground,
        refetchWhile: refetchWhile,
        refetchOnMount: refetchOnMount,
        refetchOnFocus: refetchOnFocus,
        refetchOnReconnect: refetchOnReconnect,
        retryOnMount: retryOnMount,
        retry: retry,
        retryDelay: retryDelay,
        networkMode: networkMode,
        initialData: initialData,
        initialDataUpdatedAt: initialDataUpdatedAt,
        placeholderData: placeholderData,
        structuralSharing: structuralSharing,
        persist: persist,
        meta: meta,
      ),
    );
  }
}
