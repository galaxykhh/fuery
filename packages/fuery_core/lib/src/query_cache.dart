part of 'core.dart';

enum QueryTypeFilter { all, active, inactive }

/// Selects queries, for example in [QueryClient.invalidateQueries].
///
/// Every filter that is set must match. [queryKey] matches by prefix unless
/// [exact] is true.
@immutable
class QueryFilters {
  const QueryFilters({
    this.queryKey,
    this.exact = false,
    this.type = QueryTypeFilter.all,
    this.stale,
    this.fetchStatus,
    this.predicate,
  });

  final QueryKey? queryKey;
  final bool exact;
  final QueryTypeFilter type;
  final bool? stale;
  final FetchStatus? fetchStatus;
  final bool Function(CachedQuery<Object> query)? predicate;

  bool matches(CachedQuery<Object> query) {
    final queryKey = this.queryKey;
    if (queryKey != null) {
      if (exact) {
        if (query.queryHash != hashKey(queryKey)) return false;
      } else if (!partialMatchKey(query.queryKey, queryKey)) {
        return false;
      }
    }

    if (type != QueryTypeFilter.all) {
      final isActive = query.isActive;
      if (type == QueryTypeFilter.active && !isActive) return false;
      if (type == QueryTypeFilter.inactive && isActive) return false;
    }

    if (stale != null && query.isStale != stale) return false;

    if (fetchStatus != null && query.state.fetchStatus != fetchStatus) {
      return false;
    }

    final predicate = this.predicate;
    if (predicate != null && !predicate(query)) return false;

    return true;
  }

  QueryFilters _copyWith({
    bool? exact,
    QueryTypeFilter? type,
    FetchStatus? fetchStatus,
    bool Function(CachedQuery<Object> query)? predicate,
  }) {
    return QueryFilters(
      queryKey: queryKey,
      exact: exact ?? this.exact,
      type: type ?? this.type,
      stale: stale,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      predicate: predicate ?? this.predicate,
    );
  }
}

/// The error for a key used with another data type than the one it holds.
StateError _dataTypeMismatch(String queryHash, Type held, Type requested) {
  return StateError(
    'Query $queryHash holds $held, but was requested as $requested. Use the '
    'same data type for the same key.',
  );
}

/// Global callbacks for every query in a cache, for example to show an error
/// toast whenever any query fails.
@immutable
class QueryCacheConfig {
  const QueryCacheConfig({this.onError, this.onSuccess, this.onSettled});

  final void Function(Object error, CachedQuery<Object> query)? onError;
  final void Function(Object data, CachedQuery<Object> query)? onSuccess;
  final void Function(Object? data, Object? error, CachedQuery<Object> query)?
      onSettled;
}

/// Holds the queries of a [QueryClient].
///
/// Read queries with [find] and [findAll]. Change them through the
/// [QueryClient], and watch them with [QueryClient.watch].
class QueryCache {
  QueryCache({this.config = const QueryCacheConfig()});

  final QueryCacheConfig config;
  final Map<String, CachedQuery<Object>> _queries = {};
  final Set<void Function()> _listeners = {};

  /// Returns the query for [options], creating it if needed.
  CachedQuery<TData> _build<TData extends Object>(
    QueryClient client,
    Query<TData> options,
  ) {
    final defaulted = client._defaultQueryOptions(options);
    final queryHash = defaulted.queryHash!;
    final existing = _queries[queryHash];

    if (existing != null) {
      // Generics are covariant, so `is CachedQuery<TData>` would also accept a wider
      // TData and fail later with an unclear cast error.
      if (existing._dataType != TData) {
        throw _dataTypeMismatch(queryHash, existing._dataType, TData);
      }
      return existing as CachedQuery<TData>;
    }

    final query = CachedQuery<TData>._(
      client: client,
      queryKey: defaulted.queryKey,
      queryHash: queryHash,
      options: defaulted,
    );
    _add(query);
    query._maybeRestore();
    return query;
  }

  void _add(CachedQuery<Object> query) {
    _queries[query.queryHash] = query;
    _notify();
  }

  void _remove(CachedQuery<Object> query) {
    if (!identical(_queries[query.queryHash], query)) return;
    query._removed = true;
    query._destroy();
    _queries.remove(query.queryHash);
    _notify();
  }

  void _clear() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        _remove(query);
      }
    });
  }

  CachedQuery<Object>? get(String queryHash) => _queries[queryHash];

  List<CachedQuery<Object>> getAll() => _queries.values.toList();

  /// Returns the first query matching [filters], comparing keys exactly.
  CachedQuery<Object>? find(QueryFilters filters) {
    final exact = filters._copyWith(exact: true);
    return getAll().firstWhereOrNull(exact.matches);
  }

  List<CachedQuery<Object>> findAll(
      [QueryFilters filters = const QueryFilters()]) {
    return getAll().where(filters.matches).toList();
  }

  /// Calls [listener] whenever a query or its observers change.
  void Function() _subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notify() {
    notifyManager.batch(() {
      for (final listener in _listeners.toList()) {
        listener();
      }
    });
  }

  void _onFocus() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        query._onFocus();
      }
    });
  }

  void _onOnline() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        query._onOnline();
      }
    });
  }
}
