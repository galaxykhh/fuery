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

  /// Every stored entry. Used by [QueryClient.restore], and to delete
  /// entries that aren't loaded when removing, resetting, or clearing queries.
  FutureOr<Map<String, String>> readAll();
}

/// Storage keys of persisted queries start with this prefix.
const String persistKeyPrefix = 'fuery:';

/// Storage keys of persisted mutations start with this prefix, so they
/// never collide with a query hash.
const String _mutationKeyPrefix = '${persistKeyPrefix}mutation:';

/// Persists a query's data with the client's [QueryStorage].
///
/// `toJson` must return a value that `jsonEncode` accepts, and `fromJson`
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
/// numbers, strings, or `null`, unless `paramToJson` and `paramFromJson` are
/// given.
class InfiniteQueryPersist<TPage, TParam extends Object?> {
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

  /// Converts to a [QueryPersist] for an infinite query whose page params
  /// are [P]. Queries accept any `InfiniteQueryPersist<TPage, Object?>`, so
  /// a persist without param codecs doesn't affect how [P] is inferred.
  QueryPersist<InfiniteData<TPage, P>> _toQueryPersist<P>() {
    final paramToJson = _paramToJson;
    final paramFromJson = _paramFromJson;
    return QueryPersist(
      version: version,
      maxAge: maxAge,
      toJson: (data) => {
        'pages': [for (final page in data.pages) _pageToJson(page)],
        'pageParams': [
          for (final param in data.pageParams)
            paramToJson == null ? param : paramToJson(param as TParam),
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
              (paramFromJson == null ? param : paramFromJson(param)) as P,
          ],
        );
      },
    );
  }
}

/// Persists a mutation's variables with the client's [QueryStorage] while it
/// runs, so a mutation that was paused or in flight when the app was closed
/// runs again after [QueryClient.restore].
///
/// The mutation needs a `mutationKey`: that is how `restore` finds the
/// options to run it with. `toJson` must return a value that `jsonEncode`
/// accepts, and `fromJson` must turn it back into the variables.
class MutationPersist<TVariables> {
  const MutationPersist({
    required Object? Function(TVariables variables) toJson,
    required TVariables Function(Object? json) fromJson,
    this.version = 1,
  })  : _toJson = toJson,
        _fromJson = fromJson;

  /// For [Mutation.noVariables], which has no variables to store.
  static const MutationPersist<void> noVariables = MutationPersist<void>(
    toJson: _noVariablesToJson,
    fromJson: _noVariablesFromJson,
  );

  final Object? Function(TVariables variables) _toJson;
  final TVariables Function(Object? json) _fromJson;

  /// Stored mutations with another version are discarded. Increase it when
  /// the JSON format changes.
  final int version;

  Object? _encode(TVariables variables) => _toJson(variables);

  TVariables _decode(Object? json) => _fromJson(json);
}

Object? _noVariablesToJson(void variables) => null;

void _noVariablesFromJson(Object? json) {}

/// Decodes a stored query entry, or returns null if it can't be read.
Map<String, Object?>? _decodeEntry(String raw) {
  try {
    return jsonDecode(raw) as Map<String, Object?>;
  } catch (_) {
    return null;
  }
}

/// Whether a stored query [entry] is past the expiry it was stored with.
/// Entries stored before expiries were recorded have none, and only expire
/// when their query reads them.
bool _isExpired(Map<String, Object?> entry) {
  final expires = entry['e'];
  return expires is int && now() > expires;
}

/// Runs a storage call and ignores its errors, so a failing storage never
/// breaks a query.
void _ignoreErrors(FutureOr<void> Function() call) {
  Future<void>.sync(call).ignore();
}
