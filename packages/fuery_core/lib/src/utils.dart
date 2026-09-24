import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';

/// Key that identifies a query in the cache.
///
/// Keys are compared by value: `['todos', 1]` and `['todos', 1]` point to the
/// same query, and `{'a': 1, 'b': 2}` matches `{'b': 2, 'a': 1}`.
typedef QueryKey = List<Object?>;

/// Key that identifies a mutation.
typedef MutationKey = List<Object?>;

/// A duration that never elapses.
///
/// Use it for `staleTime` to keep data fresh until it is invalidated, or for
/// `gcTime` to never garbage collect a query.
const Duration infiniteDuration = Duration(microseconds: 9007199254740991);

/// A `staleTime` for data that never changes.
///
/// The data is never stale, even after it is invalidated, and it is never
/// refetched automatically, even with `RefetchMode.always`.
const Duration staticStaleTime = Duration(microseconds: 9007199254740990);

/// Current time in milliseconds since epoch. Uses `package:clock` so tests can
/// control it with `fake_async` or `withClock`.
int now() => clock.now().millisecondsSinceEpoch;

bool isValidTimeout(Duration? value) {
  return value != null &&
      !value.isNegative &&
      value != infiniteDuration &&
      value != staticStaleTime;
}

/// Milliseconds until data updated at [updatedAt] becomes stale.
int timeUntilStale(int updatedAt, Duration? staleTime) {
  final stale = (staleTime ?? Duration.zero).inMilliseconds;
  return math.max(updatedAt + stale - now(), 0);
}

/// Returns a stable hash of [key]. Map entries are sorted, so key order does not
/// affect the hash.
///
/// Supported values are `null`, [bool], [num], [String], [Enum], [DateTime],
/// [Iterable], [Map], and objects that implement `toJson()`.
String hashKey(List<Object?> key) => jsonEncode(_canonicalize(key, false));

/// Like [hashKey], but the same in every build, obfuscated and minified ones
/// included, for storing data under the key.
///
/// It differs only for enums, as values or as map keys: those builds rename
/// types, so an enum becomes `'enum:name'` without its type. A key without
/// enums gets the same hash as [hashKey].
String storageHash(List<Object?> key) => jsonEncode(_canonicalize(key, true));

/// [key] in the JSON form [storageHash] encodes, for storing a key and
/// reading it back as the same key.
Object? storageKeyForm(List<Object?> key) => _canonicalize(key, true);

/// Returns true when [b] is a prefix (for lists) or subset (for maps) of [a].
bool partialMatchKey(List<Object?> a, List<Object?> b) {
  return _partialMatch(_canonicalize(a, false), _canonicalize(b, false));
}

/// Like [partialMatchKey], for a key read back from [storageHash].
bool partialMatchStoredKey(List<Object?> stored, List<Object?> key) {
  return _partialMatch(_canonicalize(stored, true), _canonicalize(key, true));
}

bool _partialMatch(Object? a, Object? b) {
  if (a == b) return true;

  if (a is List && b is List) {
    if (b.length > a.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (!_partialMatch(a[i], b[i])) return false;
    }
    return true;
  }

  if (a is Map && b is Map) {
    for (final key in b.keys) {
      if (!_partialMatch(a[key], b[key])) return false;
    }
    return true;
  }

  return false;
}

/// [value] as JSON. With [stable], enums leave out their type, whose name
/// obfuscated and minified builds change.
Object? _canonicalize(Object? value, bool stable) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is Enum) return _enumForm(value, stable);
  if (value is DateTime) return value.toIso8601String();
  if (value is Iterable) {
    return [for (final item in value) _canonicalize(item, stable)];
  }
  if (value is Map) {
    String keyOf(Object? key) =>
        key is Enum ? _enumForm(key, stable) : key.toString();
    final keys = value.keys.map(keyOf).toList()..sort();
    final byString = {for (final e in value.entries) keyOf(e.key): e.value};
    return {for (final k in keys) k: _canonicalize(byString[k], stable)};
  }

  try {
    // ignore: avoid_dynamic_calls
    return _canonicalize((value as dynamic).toJson(), stable);
  } on NoSuchMethodError {
    throw ArgumentError.value(
      value,
      'key',
      'Keys must contain only null, bool, num, String, Enum, DateTime, '
          'Iterable, Map, or objects with a toJson() method',
    );
  }
}

String _enumForm(Enum value, bool stable) {
  return stable ? 'enum:${value.name}' : '${value.runtimeType}.${value.name}';
}

/// Reuses parts of [prevData] that are equal to [data], so listeners can skip
/// work for data that did not change.
///
/// Returns [prevData] itself when everything is equal. For lists, items equal
/// to the previous item at the same index keep the previous instance.
T replaceData<T>(T? prevData, T data, {required bool structuralSharing}) {
  if (!structuralSharing || prevData == null) return data;
  final result = replaceEqualDeep(prevData, data);
  return result is T ? result : data;
}

/// Returns [a] if it is deeply equal to [b], otherwise [b] with every deeply
/// equal list item replaced by the one from [a].
Object? replaceEqualDeep(Object? a, Object? b, [int depth = 0]) {
  if (identical(a, b)) return a;
  if (depth > 500) return b;

  if (a is List && b is List) {
    // toList keeps b's element type, so the copy has the same runtime type.
    // An item from a is only reused when its runtime type matches b's item,
    // so it always fits.
    final copy = b.toList();
    var equalItems = 0;
    for (var i = 0; i < b.length && i < a.length; i++) {
      final item = replaceEqualDeep(a[i], b[i], depth + 1);
      if (!identical(item, a[i])) continue;
      copy[i] = item;
      equalItems++;
    }
    final allEqual = a.length == b.length && equalItems == a.length;
    return allEqual && a.runtimeType == b.runtimeType ? a : copy;
  }

  final equal = a.runtimeType == b.runtimeType &&
      const DeepCollectionEquality().equals(a, b);
  return equal ? a : b;
}

/// Pass as `placeholderData` to keep showing the previous key's data while the
/// next key is loading.
T? keepPreviousData<T>(T? previousData, [Object? client]) => previousData;

List<T> addToEnd<T>(List<T> items, T item, int? max) {
  final next = [...items, item];
  return max != null && max > 0 && next.length > max ? next.sublist(1) : next;
}

List<T> addToStart<T>(List<T> items, T item, int? max) {
  final next = [item, ...items];
  return max != null && max > 0 && next.length > max
      ? next.sublist(0, next.length - 1)
      : next;
}
