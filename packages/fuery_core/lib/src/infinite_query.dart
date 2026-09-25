part of 'core.dart';

typedef InfiniteQueryFn<TPage, TParam> = Future<TPage> Function(
  InfiniteQueryFunctionContext<TParam> context,
);

/// Returns the param for the page after `data.lastPage`, or `null` if there is
/// no next page.
@Deprecated(
  'Nothing takes this type. Write the function inline: InfiniteQuery takes '
  'Object? Function(InfiniteData<TPage, TParam> data).',
)
typedef GetNextPageParam<TPage, TParam> = TParam? Function(
  InfiniteData<TPage, TParam> data,
);

/// Returns the param for the page before `data.firstPage`, or `null` if there
/// is no previous page.
@Deprecated(
  'Nothing takes this type. Write the function inline: InfiniteQuery takes '
  'Object? Function(InfiniteData<TPage, TParam> data).',
)
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

  /// The same pages, each replaced by what [transform] returns for it, with
  /// the same params. Use it to update an item in an infinite query's data:
  ///
  /// ```dart
  /// client.updateData(feedQuery, (feed) => feed?.mapPages(
  ///       (page) => page.withPost(post),
  ///     ));
  /// ```
  InfiniteData<TPage, TParam> mapPages(TPage Function(TPage page) transform) {
    return InfiniteData(
      pages: [for (final page in pages) transform(page)],
      pageParams: pageParams,
    );
  }

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
  final _PageParamCheck<TPage, TParam> getNextPageParam;
  final _PageParamCheck<TPage, TParam>? getPreviousPageParam;

  /// Keep at most this many pages. Older pages are dropped from the other end,
  /// down to this many when more were cached.
  final int? maxPages;

  /// How many pages to load when nothing is cached. Defaults to one. With
  /// cached pages, a full fetch reloads them, starting from the first. Either
  /// way it loads no more than [maxPages].
  final int? pages;

  @override
  void onFetch(
    _FetchContext<InfiniteData<TPage, TParam>> context,
    CachedQuery<InfiniteData<TPage, TParam>> query,
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
        InfiniteData<TPage, TParam> loaded,
        TParam? param, {
        bool previous = false,
        bool directional = false,
      }) async {
        if (cancelled) throw context.signal.reason ?? const CancelledError();

        if (param == null && loaded.pages.isNotEmpty) return loaded;

        final pageParam = param as TParam;
        final page = await queryFn(InfiniteQueryFunctionContext<TParam>._(
          client: context.client,
          queryKey: context.queryKey,
          meta: context.options.meta,
          signal: signal,
          pageParam: pageParam,
        ));

        var data = loaded;
        if (directional) {
          // Keep writes made while the page loaded, such as an item updated
          // with mapPages, as long as they left the same pages loaded.
          final current = query.state.data;
          if (current != null &&
              InfiniteData._equality
                  .equals(current.pageParams, loaded.pageParams)) {
            data = current;
          }
        }

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
        final param = previous
            ? _previousParam(oldData, query._client)
            : _nextParam(oldData, query._client);
        return fetchPage(
          oldData,
          param,
          previous: previous,
          directional: true,
        );
      }

      // Load no more pages than maxPages keeps, or the first ones would be
      // fetched only to be dropped.
      final max = maxPages;
      var remainingPages = oldPages.isEmpty ? pages ?? 1 : oldPages.length;
      if (max != null && max > 0 && remainingPages > max) {
        remainingPages = max;
      }
      var result = InfiniteData<TPage, TParam>(pages: [], pageParams: []);
      var currentPage = 0;

      do {
        final TParam? param;
        if (currentPage == 0) {
          param =
              oldPageParams.isNotEmpty ? oldPageParams.first : initialPageParam;
        } else {
          param = _nextParam(result, query._client);
          if (param == null) break;
        }
        result = await fetchPage(result, param);
        currentPage++;
      } while (currentPage < remainingPages);

      return result;
    };
  }

  TParam? _nextParam(InfiniteData<TPage, TParam> data, QueryClient client) {
    if (data.pages.isEmpty) return null;
    return getNextPageParam(data, client);
  }

  TParam? _previousParam(
    InfiniteData<TPage, TParam> data,
    QueryClient client,
  ) {
    if (data.pages.isEmpty) return null;
    return getPreviousPageParam?.call(data, client);
  }

  bool hasNextPage(InfiniteData<TPage, TParam>? data, QueryClient client) {
    return data != null &&
        data.pages.isNotEmpty &&
        getNextPageParam.has(data, client);
  }

  bool hasPreviousPage(InfiniteData<TPage, TParam>? data, QueryClient client) {
    return data != null &&
        data.pages.isNotEmpty &&
        (getPreviousPageParam?.has(data, client) ?? false);
  }
}

/// Describes an infinite query.
class InfiniteQuery<TPage, TParam> extends Query<InfiniteData<TPage, TParam>>
    implements InfiniteQuerySource<TPage, TParam> {
  /// Describes an infinite query. The page and param types are inferred from
  /// [queryFn] and [initialPageParam].
  ///
  /// [getNextPageParam] returns the param for the page after `data.lastPage`,
  /// or `null` when there are no more pages. It must return a [TParam]:
  /// Dart can't check that here without breaking inference, so another type
  /// is reported as an error when the next page is looked up, and treated as
  /// no next page. An error it throws while a result is built, such as
  /// `data.lastPage.last` on an empty page, is reported once and treated the
  /// same way; while pages load, it fails the fetch.
  ///
  /// ```dart
  /// final posts = InfiniteQuery(
  ///   queryKey: ['posts'],
  ///   queryFn: (context) => api.getPosts(page: context.pageParam),
  ///   initialPageParam: 1,
  ///   getNextPageParam: (data) =>
  ///       data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  /// );
  /// ```
  ///
  /// When the first page has no param, declare the param type, as in a
  /// function that returns `InfiniteQuery<ItemPage, String?>`, and pass
  /// `initialPageParam: null`. [pages] sets how many pages to load when
  /// nothing is cached, for example to prefetch several pages with
  /// [QueryClient.infiniteQuery]. Above [maxPages], it loads only [maxPages]
  /// pages.
  //
  // The page param functions return Object?: a return type of TParam? makes
  // Dart infer the page type before queryFn fixes it, which would make
  // `data.lastPage` nullable. `persist` is typed by Object? params, so a
  // persist without param codecs can't widen the inferred param type.
  InfiniteQuery({
    required super.queryKey,
    required InfiniteQueryFn<TPage, TParam> queryFn,
    required TParam initialPageParam,
    required Object? Function(InfiniteData<TPage, TParam> data)
        getNextPageParam,
    Object? Function(InfiniteData<TPage, TParam> data)? getPreviousPageParam,
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
            getNextPageParam: _PageParamCheck<TPage, TParam>(
              'getNextPageParam',
              getNextPageParam,
              queryKey,
            ),
            getPreviousPageParam: getPreviousPageParam == null
                ? null
                : _PageParamCheck<TPage, TParam>(
                    'getPreviousPageParam',
                    getPreviousPageParam,
                    queryKey,
                  ),
            maxPages: maxPages,
            pages: pages,
          ),
        );

  /// Returns an observer that watches this infinite query. See
  /// [Query.observe].
  @override
  InfiniteQueryObserver<TPage, TParam> observe({QueryClient? client}) {
    return InfiniteQueryObserver<TPage, TParam>(client ?? Fuery.client, this);
  }
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
  }) : super._copy(base, base._observer);

  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final bool isFetchNextPageError;
  final bool isFetchPreviousPageError;

  /// All pages, or an empty list if there is no data yet.
  List<TPage> get pages => data?.pages ?? const [];

  /// The [InfiniteQueryObserver] that reported this result.
  @override
  InfiniteQueryObserver<TPage, TParam>? get observer =>
      _observer as InfiniteQueryObserver<TPage, TParam>?;

  InfiniteQueryObserver<TPage, TParam> get _infiniteReporter =>
      _reporter as InfiniteQueryObserver<TPage, TParam>;

  /// Fetches the page after the last one, like
  /// [InfiniteQueryObserver.fetchNextPage] on the observer that reported this
  /// result.
  Future<InfiniteQueryResult<TPage, TParam>> fetchNextPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _infiniteReporter.fetchNextPage(
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
  }

  /// Fetches the page before the first one, like
  /// [InfiniteQueryObserver.fetchPreviousPage].
  Future<InfiniteQueryResult<TPage, TParam>> fetchPreviousPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _infiniteReporter.fetchPreviousPage(
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
  }

  @override
  Future<InfiniteQueryResult<TPage, TParam>> refetch({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _infiniteReporter.refetch(
      cancelRefetch: cancelRefetch,
      throwOnError: throwOnError,
    );
  }

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
    extends QueryObserver<InfiniteData<TPage, TParam>>
    implements InfiniteQuerySource<TPage, TParam> {
  InfiniteQueryObserver(
    super.client,
    InfiniteQuery<TPage, TParam> super.options,
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
  /// Does nothing when [InfiniteQueryResult.hasNextPage] is false, and joins
  /// a next page that is already loading, so it is safe to call from a
  /// scroll listener. With [cancelRefetch], any other fetch that is running,
  /// such as a refetch of every page, is cancelled first; pass false to wait
  /// for it instead.
  Future<InfiniteQueryResult<TPage, TParam>> fetchNextPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _fetchPage(_FetchDirection.forward, cancelRefetch, throwOnError);
  }

  /// Fetches the page before the first loaded page. Like [fetchNextPage],
  /// with [InfiniteQueryResult.hasPreviousPage].
  Future<InfiniteQueryResult<TPage, TParam>> fetchPreviousPage({
    bool cancelRefetch = true,
    bool throwOnError = false,
  }) {
    return _fetchPage(_FetchDirection.backward, cancelRefetch, throwOnError);
  }

  Future<InfiniteQueryResult<TPage, TParam>> _fetchPage(
    _FetchDirection direction,
    bool cancelRefetch,
    bool throwOnError,
  ) async {
    _updateQuery();
    final state = currentQuery.state;
    final data = state.data;
    if (data != null) {
      final behavior =
          options._behavior! as _InfiniteQueryBehavior<TPage, TParam>;
      final hasPage = direction == _FetchDirection.forward
          ? behavior.hasNextPage(data, _client)
          : behavior.hasPreviousPage(data, _client);
      // Fetching would return the same pages, but still cancel a refetch in
      // flight and mark the old pages as fresh.
      if (!hasPage) {
        _updateResult();
        return result;
      }
      // Restarting would only fetch the same page again.
      if (state.fetchStatus != FetchStatus.idle &&
          state._fetchDirection == direction) {
        cancelRefetch = false;
      }
    }

    final fetched = await _fetch(
      _FetchOptions(cancelRefetch: cancelRefetch, direction: direction),
      throwOnError,
    );
    return fetched as InfiniteQueryResult<TPage, TParam>;
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
    Query<InfiniteData<TPage, TParam>> options,
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
      hasNextPage: behavior.hasNextPage(data, _client),
      hasPreviousPage: behavior.hasPreviousPage(data, _client),
      isFetchingNextPage: base.isFetching && forward,
      isFetchingPreviousPage: base.isFetching && backward,
      isFetchNextPageError: base.isError && forward,
      isFetchPreviousPageError: base.isError && backward,
    );
  }
}

/// Checks the page params that `getNextPageParam` or `getPreviousPageParam`
/// return, which the [InfiniteQuery] constructor can't check statically.
///
/// A param of another type means there is no such page, and is reported
/// once per client, function, and query key, however often the definition
/// is built again. Throwing instead would stop the result that asked for it
/// from being built, and the error would be lost with it. For the same
/// reason, a function that throws while a result is built, such as
/// `data.lastPage.last` on an empty page, is reported once and means no
/// page. While pages load, what it throws fails the fetch instead.
class _PageParamCheck<TPage, TParam> {
  _PageParamCheck(this._name, this._getParam, this._queryKey);

  final String _name;
  final Object? Function(InfiniteData<TPage, TParam> data) _getParam;
  final QueryKey _queryKey;

  /// Hashed once, since results are built again with the same mistake.
  late final String _queryHash = hashKey(_queryKey);

  TParam? call(InfiniteData<TPage, TParam> data, QueryClient client) {
    final param = _getParam(data);
    if (param is TParam?) return param;
    client._reportOnce(
      '$_name $_queryHash',
      StateError(
        '$_name returned ${param.runtimeType}, but the page params of the '
        'query $_queryHash are $TParam.',
      ),
      StackTrace.current,
    );
    return null;
  }

  /// Whether [data] has a page, for building results. A throw means no page
  /// and is reported once: no caller could receive it.
  bool has(InfiniteData<TPage, TParam> data, QueryClient client) {
    try {
      return call(data, client) != null;
    } catch (error, stackTrace) {
      client._reportOnce('$_name threw $_queryHash', error, stackTrace);
      return false;
    }
  }
}

/// Builds an [InfiniteQuery], like its constructor.
@Deprecated(
  'Use the InfiniteQuery constructor, which takes the same arguments. Of '
  'explicit type arguments, keep the first two: InfiniteQuery<TPage, TParam>.',
)
InfiniteQuery<TPage, TParam> infiniteQueryOptions<
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
  return InfiniteQuery<TPage, TParam>(
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

@Deprecated('Use InfiniteQuery.')
typedef InfiniteQueryOptions<TPage, TParam> = InfiniteQuery<TPage, TParam>;
