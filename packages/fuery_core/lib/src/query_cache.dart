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
  final bool Function(Query<Object> query)? predicate;

  bool matches(Query<Object> query) {
    final queryKey = this.queryKey;
    if (queryKey != null) {
      if (exact) {
        if (query.queryHash != hashKey(queryKey)) return false;
      } else if (!partialMatchKey(query.queryKey, queryKey)) {
        return false;
      }
    }

    if (type != QueryTypeFilter.all) {
      final isActive = query.isActive();
      if (type == QueryTypeFilter.active && !isActive) return false;
      if (type == QueryTypeFilter.inactive && isActive) return false;
    }

    if (stale != null && query.isStale() != stale) return false;

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
    bool Function(Query<Object> query)? predicate,
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

sealed class QueryCacheEvent {
  const QueryCacheEvent(this.query);
  final Query<Object> query;
}

final class QueryAddedEvent extends QueryCacheEvent {
  const QueryAddedEvent(super.query);
}

final class QueryRemovedEvent extends QueryCacheEvent {
  const QueryRemovedEvent(super.query);
}

final class QueryUpdatedEvent extends QueryCacheEvent {
  const QueryUpdatedEvent(super.query, this.action);
  final QueryAction action;
}

final class QueryObserverAddedEvent extends QueryCacheEvent {
  const QueryObserverAddedEvent(super.query, this.observer);
  final QueryObserver<Object> observer;
}

final class QueryObserverRemovedEvent extends QueryCacheEvent {
  const QueryObserverRemovedEvent(super.query, this.observer);
  final QueryObserver<Object> observer;
}

final class QueryObserverResultsUpdatedEvent extends QueryCacheEvent {
  const QueryObserverResultsUpdatedEvent(super.query);
}

final class QueryObserverOptionsUpdatedEvent extends QueryCacheEvent {
  const QueryObserverOptionsUpdatedEvent(super.query, this.observer);
  final QueryObserver<Object> observer;
}

/// Global callbacks for every query in a cache, for example to show an error
/// toast whenever any query fails.
@immutable
class QueryCacheConfig {
  const QueryCacheConfig({this.onError, this.onSuccess, this.onSettled});

  final void Function(Object error, Query<Object> query)? onError;
  final void Function(Object data, Query<Object> query)? onSuccess;
  final void Function(Object? data, Object? error, Query<Object> query)?
      onSettled;
}

class QueryCache extends Subscribable<QueryCacheEvent> {
  QueryCache({this.config = const QueryCacheConfig()});

  final QueryCacheConfig config;
  final Map<String, Query<Object>> _queries = {};

  /// Returns the query for [options], creating it if needed.
  Query<TData> build<TData extends Object>(
    QueryClient client,
    QueryOptions<TData> options, [
    QueryState<TData>? state,
  ]) {
    final defaulted = client.defaultQueryOptions(options);
    final queryHash = defaulted.queryHash!;
    final existing = _queries[queryHash];

    if (existing != null) {
      // Generics are covariant, so `is Query<TData>` would also accept a wider
      // TData and fail later with an unclear cast error.
      if (existing._dataType != TData) {
        throw StateError(
          'Query $queryHash holds ${existing._dataType}, but was requested '
          'as $TData. Use the same data type for the same key.',
        );
      }
      return existing as Query<TData>;
    }

    final query = Query<TData>._(
      client: client,
      queryKey: defaulted.queryKey,
      queryHash: queryHash,
      options: defaulted,
      state: state,
    );
    add(query);
    query._maybeRestore();
    return query;
  }

  void add(Query<Object> query) {
    if (_queries.containsKey(query.queryHash)) return;
    _queries[query.queryHash] = query;
    notify(QueryAddedEvent(query));
  }

  void remove(Query<Object> query) {
    if (!identical(_queries[query.queryHash], query)) return;
    query._removed = true;
    query.destroy();
    _queries.remove(query.queryHash);
    notify(QueryRemovedEvent(query));
  }

  void clear() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        remove(query);
      }
    });
  }

  Query<Object>? get(String queryHash) => _queries[queryHash];

  List<Query<Object>> getAll() => _queries.values.toList();

  /// Returns the first query matching [filters], comparing keys exactly.
  Query<Object>? find(QueryFilters filters) {
    final exact = filters._copyWith(exact: true);
    return getAll().firstWhereOrNull(exact.matches);
  }

  List<Query<Object>> findAll([QueryFilters filters = const QueryFilters()]) {
    return getAll().where(filters.matches).toList();
  }

  void notify(QueryCacheEvent event) {
    notifyManager.batch(() {
      for (final listener in listeners.toList()) {
        listener(event);
      }
    });
  }

  void onFocus() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        query._onFocus();
      }
    });
  }

  void onOnline() {
    notifyManager.batch(() {
      for (final query in getAll()) {
        query._onOnline();
      }
    });
  }
}
