part of 'core.dart';

typedef QueryFn<TData extends Object> = Future<TData> Function(
  QueryFunctionContext context,
);

/// Returns data to show while a query is pending. [previousData] is the
/// data of the key the observer showed before, and [client] is its client,
/// for example to read a list that holds the item.
typedef PlaceholderDataFn<TData extends Object> = TData? Function(
  TData? previousData,
  QueryClient client,
);

/// When to refetch on mount, focus, or reconnect.
enum RefetchMode {
  /// Never refetch on this event.
  never,

  /// Refetch only if the data is stale.
  ifStale,

  /// Always refetch.
  always,
}

/// Passed to every query function.
class QueryFunctionContext {
  QueryFunctionContext._({
    required this.client,
    required this.queryKey,
    required this.meta,
    required AbortSignal Function() signal,
    AbortSignal Function()? peekSignal,
  })  : _signal = signal,
        _peekSignal = peekSignal;

  final QueryClient client;
  final QueryKey queryKey;
  final Map<String, Object?>? meta;
  final AbortSignal Function() _signal;

  /// Reads the signal without marking the query function as cancellable.
  final AbortSignal Function()? _peekSignal;

  /// Aborted when the fetch is cancelled. Reading it marks the query function
  /// as cancellable.
  AbortSignal get signal => _signal();
}

@immutable
class _FetchOptions {
  const _FetchOptions({this.cancelRefetch = false, this.direction});

  /// Cancel an in-flight fetch and start a new one, instead of reusing it.
  final bool cancelRefetch;

  /// Which page an infinite query fetches, or null to refetch every page.
  final _FetchDirection? direction;
}

/// Hooks into how a [CachedQuery] fetches. Used by infinite queries to fetch pages.
abstract interface class _QueryBehavior<TData extends Object> {
  void onFetch(_FetchContext<TData> context, CachedQuery<TData> query);
}

class _FetchContext<TData extends Object> {
  _FetchContext._({
    required this.fetchFn,
    required this.fetchOptions,
    required this.options,
    required this.client,
    required this.queryKey,
    required this.state,
    required AbortSignal Function() signal,
  }) : _signal = signal;

  /// The function the retryer runs. Behaviors replace it.
  Future<TData> Function() fetchFn;
  final _FetchOptions? fetchOptions;
  final Query<TData> options;
  final QueryClient client;
  final QueryKey queryKey;
  final QueryState<TData> state;
  final AbortSignal Function() _signal;

  AbortSignal get signal => _signal();
}

/// Default values for query options, set on the client or per key prefix.
@immutable
class QueryDefaults {
  const QueryDefaults({
    this.enabled,
    this.staleTime,
    this.gcTime,
    this.refetchInterval,
    this.refetchIntervalInBackground,
    this.refetchOnMount,
    this.refetchOnFocus,
    this.refetchOnReconnect,
    this.retryOnMount,
    this.retry,
    this.retryDelay,
    this.networkMode,
    this.structuralSharing,
    this.meta,
  });

  final bool? enabled;
  final Duration? staleTime;
  final Duration? gcTime;
  final Duration? refetchInterval;
  final bool? refetchIntervalInBackground;
  final RefetchMode? refetchOnMount;
  final RefetchMode? refetchOnFocus;
  final RefetchMode? refetchOnReconnect;
  final bool? retryOnMount;
  final RetryPolicy? retry;
  final RetryDelay? retryDelay;
  final NetworkMode? networkMode;
  final bool? structuralSharing;
  final Map<String, Object?>? meta;

  /// Returns defaults where values set in [other] win.
  QueryDefaults merge(QueryDefaults? other) {
    if (other == null) return this;
    return QueryDefaults(
      enabled: other.enabled ?? enabled,
      staleTime: other.staleTime ?? staleTime,
      gcTime: other.gcTime ?? gcTime,
      refetchInterval: other.refetchInterval ?? refetchInterval,
      refetchIntervalInBackground:
          other.refetchIntervalInBackground ?? refetchIntervalInBackground,
      refetchOnMount: other.refetchOnMount ?? refetchOnMount,
      refetchOnFocus: other.refetchOnFocus ?? refetchOnFocus,
      refetchOnReconnect: other.refetchOnReconnect ?? refetchOnReconnect,
      retryOnMount: other.retryOnMount ?? retryOnMount,
      retry: other.retry ?? retry,
      retryDelay: other.retryDelay ?? retryDelay,
      networkMode: other.networkMode ?? networkMode,
      structuralSharing: other.structuralSharing ?? structuralSharing,
      meta: other.meta ?? meta,
    );
  }
}

/// Describes a query and the observers watching it.
///
/// Unset values fall back to [QueryClient] defaults: data is stale immediately,
/// unused queries are removed after 5 minutes, failed fetches retry 3 times,
/// and stale queries refetch on mount, focus, and reconnect.
class Query<TData extends Object> implements QuerySource<TData> {
  /// Describes a query. The data type is inferred from [queryFn].
  ///
  /// ```dart
  /// final todos = Query(queryKey: ['todos'], queryFn: (_) => api.getTodos());
  /// ```
  const Query({
    required this.queryKey,
    required QueryFn<TData> this.queryFn,
    this.enabled,
    this.staleTime,
    this.gcTime,
    this.refetchInterval,
    this.refetchIntervalInBackground,
    this.refetchWhile,
    this.refetchOnMount,
    this.refetchOnFocus,
    this.refetchOnReconnect,
    this.retryOnMount,
    this.retry,
    this.retryDelay,
    this.networkMode,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.structuralSharing,
    this.persist,
    this.meta,
  })  : queryHash = null,
        _behavior = null,
        _defaulted = false;

  /// A query known only by its key, for data written to the cache before
  /// anything describes the query.
  const Query._key(this.queryKey)
      : queryFn = null,
        enabled = null,
        staleTime = null,
        gcTime = null,
        refetchInterval = null,
        refetchIntervalInBackground = null,
        refetchWhile = null,
        refetchOnMount = null,
        refetchOnFocus = null,
        refetchOnReconnect = null,
        retryOnMount = null,
        retry = null,
        retryDelay = null,
        networkMode = null,
        initialData = null,
        initialDataUpdatedAt = null,
        placeholderData = null,
        structuralSharing = null,
        persist = null,
        meta = null,
        queryHash = null,
        _behavior = null,
        _defaulted = false;

  /// Used by [InfiniteQuery], which fetch pages through [behavior].
  const Query._withBehavior({
    required this.queryKey,
    required _QueryBehavior<TData> behavior,
    this.enabled,
    this.staleTime,
    this.gcTime,
    this.refetchInterval,
    this.refetchIntervalInBackground,
    this.refetchWhile,
    this.refetchOnMount,
    this.refetchOnFocus,
    this.refetchOnReconnect,
    this.retryOnMount,
    this.retry,
    this.retryDelay,
    this.networkMode,
    this.initialData,
    this.initialDataUpdatedAt,
    this.placeholderData,
    this.structuralSharing,
    this.persist,
    this.meta,
  })  : queryFn = null,
        queryHash = null,
        _behavior = behavior,
        _defaulted = false;

  const Query._defaulted({
    required this.queryKey,
    required this.queryHash,
    required this.queryFn,
    required this.enabled,
    required this.staleTime,
    required this.gcTime,
    required this.refetchInterval,
    required this.refetchIntervalInBackground,
    required this.refetchWhile,
    required this.refetchOnMount,
    required this.refetchOnFocus,
    required this.refetchOnReconnect,
    required this.retryOnMount,
    required this.retry,
    required this.retryDelay,
    required this.networkMode,
    required this.initialData,
    required this.initialDataUpdatedAt,
    required this.placeholderData,
    required this.structuralSharing,
    required this.persist,
    required this.meta,
    required _QueryBehavior<TData>? behavior,
  })  : _behavior = behavior,
        _defaulted = true;

  final QueryKey queryKey;

  /// Fetches the data. Must not resolve to `null`; `null` means "no data".
  final QueryFn<TData>? queryFn;

  /// Set to false to stop the query from fetching automatically.
  final bool? enabled;

  /// How long data stays fresh. Fresh data is not refetched on mount, focus,
  /// or reconnect. Use [infiniteDuration] to stay fresh until invalidated.
  final Duration? staleTime;

  /// How long an unused query stays in the cache.
  final Duration? gcTime;

  /// Refetch when this much time has passed since the query last changed,
  /// while observed.
  final Duration? refetchInterval;

  /// Keep polling with [refetchInterval] while the app is in the background.
  final bool? refetchIntervalInBackground;

  /// Polls with [refetchInterval] only while this returns true for the latest
  /// result, for example until a job finishes. It is checked on every change,
  /// so polling resumes when it returns true again.
  final bool Function(QueryResult<TData> result)? refetchWhile;

  final RefetchMode? refetchOnMount;

  /// Refetch when the app returns to the foreground.
  final RefetchMode? refetchOnFocus;

  final RefetchMode? refetchOnReconnect;

  /// Set to false to not retry a query that failed when a new observer mounts.
  final bool? retryOnMount;

  final RetryPolicy? retry;
  final RetryDelay? retryDelay;
  final NetworkMode? networkMode;

  /// Data to seed the cache with. Treated as real, cached data.
  final TData? initialData;

  /// When [initialData] was fetched, in milliseconds since epoch. Defaults to
  /// now, which makes it fresh for [staleTime].
  final int? initialDataUpdatedAt;

  /// Data to show while pending, without writing it to the cache. Pass
  /// [keepPreviousData] to keep showing the previous key's data.
  final PlaceholderDataFn<TData>? placeholderData;

  /// Reuse the previous data instance when a refetch returns deeply equal
  /// data. Defaults to true.
  final bool? structuralSharing;

  /// Stores the data with the client's [QueryStorage] and restores it when
  /// the query is used again, even after the app restarts.
  final QueryPersist<TData>? persist;

  final Map<String, Object?>? meta;

  final _QueryBehavior<TData>? _behavior;

  /// Hash of [queryKey]. Set once the options are defaulted by a client.
  final String? queryHash;

  final bool _defaulted;

  /// Returns an observer that watches this query, with [Fuery.client] unless
  /// [client] is given. The query fetches when the observer gets its first
  /// listener. Create the observer once, not in `build`.
  ///
  /// Define a query once, then pass it to widgets, fetch it with
  /// [QueryClient.query], and read or write its data with
  /// [QueryClient.getData] and [QueryClient.updateData]. A widget given the
  /// query observes it with its own client, and follows a new key. Call
  /// `observe()` where code outside widgets needs the observer, such as a
  /// cubit or a service:
  ///
  /// ```dart
  /// Query<Post> postQuery(int id) => Query(
  ///       queryKey: ['posts', id],
  ///       queryFn: (_) => api.getPost(id),
  ///     );
  ///
  /// final post = postQuery(1).observe();
  /// post.stream.listen((result) => print(result.data));
  /// ```
  QueryObserver<TData> observe({QueryClient? client}) {
    return QueryObserver<TData>(client ?? Fuery.client, this);
  }

  /// These options with [defaults] for what they leave unset, and
  /// [knownHash], the hash of [queryKey] if the caller knows it.
  Query<TData> _withDefaults(QueryDefaults defaults, [String? knownHash]) {
    final networkMode = this.networkMode ?? defaults.networkMode;
    return Query<TData>._defaulted(
      queryKey: queryKey,
      queryHash: queryHash ?? knownHash ?? hashKey(queryKey),
      queryFn: queryFn,
      enabled: enabled ?? defaults.enabled,
      staleTime: staleTime ?? defaults.staleTime,
      gcTime: gcTime ?? defaults.gcTime,
      refetchInterval: refetchInterval ?? defaults.refetchInterval,
      refetchIntervalInBackground:
          refetchIntervalInBackground ?? defaults.refetchIntervalInBackground,
      refetchWhile: refetchWhile,
      refetchOnMount: refetchOnMount ?? defaults.refetchOnMount,
      refetchOnFocus: refetchOnFocus ?? defaults.refetchOnFocus,
      refetchOnReconnect: refetchOnReconnect ??
          defaults.refetchOnReconnect ??
          (networkMode == NetworkMode.always
              ? RefetchMode.never
              : RefetchMode.ifStale),
      retryOnMount: retryOnMount ?? defaults.retryOnMount,
      retry: retry ?? defaults.retry,
      retryDelay: retryDelay ?? defaults.retryDelay,
      networkMode: networkMode,
      initialData: initialData,
      initialDataUpdatedAt: initialDataUpdatedAt,
      placeholderData: placeholderData,
      structuralSharing: structuralSharing ?? defaults.structuralSharing,
      persist: persist,
      meta: meta ?? defaults.meta,
      behavior: _behavior,
    );
  }

  /// Whether [other] configures the query the same way, as far as anything
  /// watching the cache can tell. Functions and codecs are compared only by
  /// whether they are set: options built again, for example in a widget's
  /// `build`, have new closures for the same query, and the observer uses the
  /// latest ones either way.
  bool _sameConfig(Query<TData> other) {
    bool sameSet(Object? a, Object? b) => (a == null) == (b == null);
    return queryHash == other.queryHash &&
        enabled == other.enabled &&
        staleTime == other.staleTime &&
        gcTime == other.gcTime &&
        refetchInterval == other.refetchInterval &&
        refetchIntervalInBackground == other.refetchIntervalInBackground &&
        refetchOnMount == other.refetchOnMount &&
        refetchOnFocus == other.refetchOnFocus &&
        refetchOnReconnect == other.refetchOnReconnect &&
        retryOnMount == other.retryOnMount &&
        networkMode == other.networkMode &&
        const DeepCollectionEquality().equals(initialData, other.initialData) &&
        initialDataUpdatedAt == other.initialDataUpdatedAt &&
        structuralSharing == other.structuralSharing &&
        const DeepCollectionEquality().equals(meta, other.meta) &&
        sameSet(queryFn, other.queryFn) &&
        sameSet(refetchWhile, other.refetchWhile) &&
        sameSet(retry, other.retry) &&
        sameSet(retryDelay, other.retryDelay) &&
        sameSet(placeholderData, other.placeholderData) &&
        sameSet(persist, other.persist) &&
        sameSet(_behavior, other._behavior);
  }

  Query<TData> _withRetry(RetryPolicy retry) {
    return Query<TData>._defaulted(
      queryKey: queryKey,
      queryHash: queryHash,
      queryFn: queryFn,
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
      behavior: _behavior,
    );
  }
}

@Deprecated('Use Query.')
typedef QueryOptions<TData extends Object> = Query<TData>;
