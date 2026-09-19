import 'package:fuery_core/src/base/mutation.dart';
import 'package:fuery_core/src/base/query.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/error/fuery_exception.dart';
import 'package:fuery_core/src/mutation_cache.dart';
import 'package:fuery_core/src/query_cache.dart';
import 'package:fuery_core/src/query_options.dart';

class Fuery {
  Fuery._();

  static final Fuery _singleton = Fuery._();
  static Fuery get instance => _singleton;

  QueryOptions _defaultQueryOptions = QueryOptions();
  QueryOptions get defaultOptions => _defaultQueryOptions;

  final QueryCache _queryCache = QueryCache();
  QueryCache get cache => _queryCache;

  final MutationCache _mutationCache = MutationCache();
  MutationCache get mutationCache => _mutationCache;

  /// Set [QueryOptions] globally.
  ///
  /// The default settings follow [defaultOptions].
  ///
  /// example:
  /// ```dart
  /// Fuery.instance.configQueryOptions(QueryOptions(
  /// 	...
  /// ));
  /// ```
  void configQueryOptions(QueryOptions? queryOptions) {
    if (queryOptions != null) _defaultQueryOptions = queryOptions;
  }

  /// Add the [QueryBase] to the [QueryCache].
  void addQuery(
    QueryKey queryKey,
    QueryBase query,
  ) {
    _queryCache.add(
      queryKey,
      query,
    );
  }

  /// Return [QueryBase] if exists.
  QueryBase? getQuery(QueryKey queryKey) {
    return _queryCache.find(queryKey);
  }

  /// Return query data if exists.
  T? getQueryData<T>(QueryKey queryKey) {
    final QueryBase? query = getQuery(queryKey);

    return query?.stream.value.data as T?;
  }

  /// Return whether the [QueryBase] is cached or not.
  bool hasQuery(QueryKey queryKey) => _queryCache.has(queryKey);

  /// Remove [QueryBase] from the [QueryCache].
  void removeQuery(QueryKey queryKey) {
    _queryCache.remove(queryKey);
  }

  /// Set data If the [QueryBase] exists based on the [queryKey],
  void setQueryData<T>(
    QueryKey queryKey,
    T data,
  ) {
    final QueryBase? query = _queryCache.find(queryKey);

    if (query == null) return;
    if (query.stream.value.data == null) return;
    if (query.stream.value.data is! T) {
      throw QueryStateTypeException(
        data: data,
        message: 'data is not type of $T: $data',
      );
    }

    query.emit(query.stream.value.copyWith(data: () => data));
  }

  /// Mark queries as stale.
  ///
  /// example:
  /// ```dart
  /// // Invalidate every queries.
  /// Fuery.instance.invalidateQueries();
  ///
  /// // Invalidate queries with a key starts with `posts`
  /// Fuery.instance.invalidateQueries(queryKey: ['posts']);
  ///
  /// // Invalidate the query that perfectly matches the key.
  /// Fuery.instance.invalidateQueries(
  /// 	queryKey: ['posts'],
  /// 	exact: true,
  /// );
  /// ```
  void invalidateQueries({
    QueryKey? queryKey,
    bool? exact,
  }) {
    final List<QueryBase> filtered = queryKey != null && queryKey.isNotEmpty
        ? _queryCache
            .findAll(
              key: queryKey,
              exact: exact,
            )
            .toList()
        : _queryCache.getAll();

    for (final query in filtered) {
      query.invalidate();
    }
  }

  /// Add the [MutationBase] to the [MutationCache]
  void addMutation(
    MutationKey mutationKey,
    MutationBase mutation,
  ) {
    _mutationCache.add(
      mutationKey,
      mutation,
    );
  }

  /// Returns [MutationBase] if exists.
  MutationBase? getMutation(MutationKey mutationKey) {
    return _mutationCache.find(mutationKey);
  }

  /// Returns mutation data if exists.
  T? getMutationData<T>(MutationKey mutationKey) {
    final MutationBase? mutation = getMutation(mutationKey);

    return mutation?.stream.value as T?;
  }

  /// Return whether the [MutationBase] is cached or not.
  bool hasMutation(MutationKey mutationKey) {
    return _mutationCache.has(mutationKey);
  }

  /// Remove [MutationBase] from the [MutationCache].
  void removeMutation(MutationKey mutationKey) {
    _mutationCache.remove(mutationKey);
  }
}
