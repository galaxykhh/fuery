import 'package:rxdart/rxdart.dart';
import 'package:fuery_core/src/base/query.dart';
import 'package:fuery_core/src/base/query_state.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/query_options.dart';
import 'package:fuery_core/src/query_result.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:fuery_core/src/fuery_client.dart';
import 'package:fuery_core/src/util/timestamp.dart';

class Query<Data, Err> extends QueryBase<Data, Err, QueryState<Data, Err>> {
  Query._({
    required QueryKey queryKey,
    required QueryFn<Data> queryFn,
    QueryOptions<Data>? options,
  })  : _queryFn = queryFn,
        super(
          queryKey: queryKey,
          state: QueryState<Data, Err>(
            data: options?.initialData,
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

  /// Returns [QueryResult] new or existing [Query].
  ///
  /// If there is no existing cached [Query] with the same [queryKey], creates a new [Query] instance.
  ///
  /// example:
  /// ```dart
  /// late final post = Query.use(
  /// 	queryKey: ['posts', 2], // The post with the Id of 2.
  /// 	queryFn: () => getPostById(2),
  /// );
  /// ```
  static QueryResult<Data, Err> use<Data, Err>({
    required QueryKey queryKey,
    required QueryFn<Data> queryFn,
    int? gcTime,
    int? staleTime,
    int? refetchInterval,
    Data? initialData,
  }) {
    assert(queryKey.isNotEmpty, 'queryKey should not be empty');

    QueryBase? query = Fuery.instance.getQuery(queryKey);
    final QueryOptions<Data> options = QueryOptions(
      gcTime: gcTime,
      initialData: initialData,
      staleTime: staleTime,
      refetchInterval: refetchInterval,
    );
    final bool exists = query is QueryBase && query is Query;

    if (exists) {
      query.updateOptions(options);

      final bool shouldRefetch = !query.stream.value.isLoading && query.isStale;
      if (shouldRefetch) query.refetch();
    } else {
      query = Query<Data, Err>._(
        queryKey: queryKey,
        queryFn: queryFn,
        options: options,
      )..fetch();

      Fuery.instance.addQuery(
        queryKey,
        query,
      );
    }

    return QueryResult<Data, Err>(
      stream: query.stream as ValueStream<QueryState<Data, Err>>,
      refetch: query.refetch,
      updateOptions: query.updateOptions,
    );
  }

  final QueryFn<Data> _queryFn;

  /// Called when an new [Query] created.
  ///
  /// In general, there won't typically be a situation where you directly call during development.
  @override
  void fetch() {
    if (stream.value.isLoading) return;

    super.emit(stream.value.copyWith(
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
    ));

    _invokeQueryFn();
  }

  /// Refresh query.
  ///
  /// When there's already an existing [Query], it will be automatically called when necessary.
  /// When new data needs to be requested, you can call it to refresh and update the data.
  @override
  void refetch() {
    if (shouldSkipFetch) return;

    super.emit(stream.value.copyWith(
      status: stream.value.status.isFailure
          ? QueryStatus.pending
          : stream.value.status,
      fetchStatus: FetchStatus.refetching,
      error: () => stream.value.status.isFailure ? null : stream.value.error,
    ));

    _invokeQueryFn();
  }

  /// invalidate [Query].
  ///
  /// It indicates to [refetch] when [hasListener] is true or the [Query] with the same [key] is called.
  @override
  void invalidate() {
    super.invalidate();

    if (hasListener) refetch();
  }

  Future<void> _invokeQueryFn() async {
    try {
      final Data data = await _queryFn();
      super.emit(stream.value.copyWith(
        data: () => data,
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
}
