part of 'core.dart';

/// Stores persisted queries as strings, for example in shared preferences, a
/// file, or a database.
///
/// Methods may return synchronously. With a storage that reads synchronously,
/// a persisted query is restored before its first result, so the first frame
/// already shows the stored data.
abstract interface class QueryStorage {
  FutureOr<String?> read(String key);

  FutureOr<void> write(String key, String value);

  FutureOr<void> delete(String key);

  /// Every stored entry. Used by [QueryClient.restore] and when clearing.
  FutureOr<Map<String, String>> readAll();
}

/// Storage keys of persisted queries start with this prefix.
const String persistKeyPrefix = 'fuery:';

/// Persists a query's data with the client's [QueryStorage].
///
/// [toJson] must return a value that `jsonEncode` accepts, and [fromJson]
/// must turn it back into the data.
class QueryPersist<TData extends Object> {
  const QueryPersist({
    required Object? Function(TData data) toJson,
    required TData Function(Object? json) fromJson,
    this.version = 1,
    this.maxAge,
  })  : _toJson = toJson,
        _fromJson = fromJson;

  final Object? Function(TData data) _toJson;
  final TData Function(Object? json) _fromJson;

  /// Stored data with another version is discarded. Increase it when the
  /// JSON format changes.
  final int version;

  /// Stored data older than this is discarded. Defaults to
  /// [QueryClient.persistMaxAge].
  final Duration? maxAge;

  Object? _encode(TData data) => _toJson(data);

  TData _decode(Object? json) => _fromJson(json);
}

/// Persists an infinite query's pages with the client's [QueryStorage].
///
/// Page params are stored as they are, so they must be JSON values such as
/// numbers, strings, or `null`, unless [paramToJson] and [paramFromJson] are
/// given.
class InfiniteQueryPersist<TPage, TParam> {
  const InfiniteQueryPersist({
    required Object? Function(TPage page) pageToJson,
    required TPage Function(Object? json) pageFromJson,
    Object? Function(TParam param)? paramToJson,
    TParam Function(Object? json)? paramFromJson,
    this.version = 1,
    this.maxAge,
  })  : _pageToJson = pageToJson,
        _pageFromJson = pageFromJson,
        _paramToJson = paramToJson,
        _paramFromJson = paramFromJson;

  final Object? Function(TPage page) _pageToJson;
  final TPage Function(Object? json) _pageFromJson;
  final Object? Function(TParam param)? _paramToJson;
  final TParam Function(Object? json)? _paramFromJson;

  /// See [QueryPersist.version].
  final int version;

  /// See [QueryPersist.maxAge].
  final Duration? maxAge;

  QueryPersist<InfiniteData<TPage, TParam>> _toQueryPersist() {
    return QueryPersist(
      version: version,
      maxAge: maxAge,
      toJson: (data) => {
        'pages': [for (final page in data.pages) _pageToJson(page)],
        'pageParams': [
          for (final param in data.pageParams)
            _paramToJson == null ? param : _paramToJson(param),
        ],
      },
      fromJson: (json) {
        final map = json! as Map<String, Object?>;
        return InfiniteData(
          pages: [
            for (final page in map['pages']! as List) _pageFromJson(page),
          ],
          pageParams: [
            for (final param in map['pageParams']! as List)
              _paramFromJson == null ? param as TParam : _paramFromJson(param),
          ],
        );
      },
    );
  }
}

/// Runs a storage call and ignores its errors, so a failing storage never
/// breaks a query.
void _ignoreErrors(FutureOr<void> Function() call) {
  Future<void>.sync(call).ignore();
}
