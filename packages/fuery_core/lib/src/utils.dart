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
String hashKey(List<Object?> key) => jsonEncode(keyForm(key));

/// [key] in the JSON form [hashKey] encodes, for comparing it with
/// [partialMatchForms] without converting it again for every comparison.
Object? keyForm(List<Object?> key) => _canonicalize(key, false);

/// Like [hashKey], but the same in every build, obfuscated and minified ones
/// included, for storing data under the key.
///
/// It differs only for enums, as values or as map keys: those builds rename
/// types, so an enum becomes `'enum:name'` without its type. A key without
/// enums gets the same hash as [hashKey].
String storageHash(List<Object?> key) => jsonEncode(storageKeyForm(key));

/// [key] in the JSON form [storageHash] encodes, for storing a key and
/// reading it back as the same key.
Object? storageKeyForm(List<Object?> key) => _canonicalize(key, true);

/// Whether keys [a] and [b], or parts of keys, have the same [hashKey], told
/// without hashing them, so a key built again with the same content can keep
/// its hash.
///
/// Strict: true only for `null`, `bool`, `int`, `String`, enums, lists, and
/// maps with `String` keys, alike in content, and for maps in order. False
/// for anything else, such as a double, a `DateTime`, a set, an object with
/// `toJson()`, or a map with other keys, even for the same hash: the caller
/// hashes those.
bool sameKey(Object? a, Object? b) {
  if (a is String) return b is String && a == b;
  if (a is int) {
    // On the web, 1.0, -0.0, and infinity are ints too: 1.0 hashes as 1,
    // but -0.0 hashes as -0.0, and infinity can't be hashed.
    return b is int && a == b && a.isNegative == b.isNegative && a.isFinite;
  }
  if (a == null || a is bool || a is Enum) return identical(a, b);
  if (a is List) {
    if (b is! List || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!sameKey(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map) {
    if (b is! Map || a.length != b.length) return false;
    // By the keys each map holds, in order: a map that finds keys its own
    // way, such as without case, can't pass for another.
    final others = b.entries.iterator;
    for (final MapEntry(:key, :value) in a.entries) {
      if (key is! String ||
          !others.moveNext() ||
          key != others.current.key ||
          !sameKey(value, others.current.value)) {
        return false;
      }
    }
    return true;
  }
  return false;
}

/// A copy of [key] for [sameKey] to compare later keys with, or null when
/// [key] holds a value that [sameKey] leaves to hashing. It keeps the key as
/// it was, so a key changed in place no longer matches it.
List<Object?>? keyCopy(List<Object?> key) {
  final copy = _copyKey(key);
  return identical(copy, _notCopied) ? null : copy! as List<Object?>;
}

/// What [_copyKey] returns for a value [sameKey] leaves to hashing.
final Object _notCopied = Object();

Object? _copyKey(Object? value) {
  if (value == null ||
      value is bool ||
      value is int ||
      value is String ||
      value is Enum) {
    return value;
  }
  if (value is List) {
    final copy = List<Object?>.filled(value.length, null);
    for (var i = 0; i < value.length; i++) {
      final item = _copyKey(value[i]);
      if (identical(item, _notCopied)) return _notCopied;
      copy[i] = item;
    }
    return copy;
  }
  if (value is Map) {
    final copy = <String, Object?>{};
    for (final MapEntry(:key, value: item) in value.entries) {
      if (key is! String) return _notCopied;
      final itemCopy = _copyKey(item);
      if (identical(itemCopy, _notCopied)) return _notCopied;
      copy[key] = itemCopy;
    }
    return copy;
  }
  return _notCopied;
}

/// Returns true when [b] is a prefix (for lists) or subset (for maps) of [a].
bool partialMatchKey(List<Object?> a, List<Object?> b) {
  return partialMatchForms(keyForm(a), keyForm(b));
}

/// [partialMatchKey] for keys already converted with [keyForm].
bool partialMatchForms(Object? a, Object? b) => _partialMatch(a, b);

/// Returns a test for whether [key] is a prefix (for lists) or subset (for
/// maps) of a key read back from storage, stored in the form of
/// [storageHash] or of [hashKey], as keys were before 1.4.1. [key] is
/// converted once, for testing many stored keys.
bool Function(List<Object?> stored) storedKeyMatcher(List<Object?> key) {
  final forms = [_canonicalize(key, true), _canonicalize(key, false)];
  // A key read back is JSON already.
  return (stored) => forms.any((form) => _partialMatch(stored, form));
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
  if (value is Enum) {
    return stable ? 'enum:${value.name}' : '${value.runtimeType}.${value.name}';
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Iterable) {
    return [for (final item in value) _canonicalize(item, stable)];
  }
  if (value is Map) {
    // In memory, an enum map key is its toString(), as it always was.
    String keyOf(Object? key) =>
        stable && key is Enum ? 'enum:${key.name}' : key.toString();
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

  if (a is Map && b is Map) {
    // Compared key by key: DeepCollectionEquality would hash each nested
    // map's whole subtree again at every level.
    if (a.length != b.length || a.runtimeType != b.runtimeType) return b;
    for (final entry in b.entries) {
      final previous = a[entry.key];
      if (previous == null && !a.containsKey(entry.key)) return b;
      final shared = replaceEqualDeep(previous, entry.value, depth + 1);
      if (!identical(shared, previous)) return b;
    }
    return a;
  }

  final equal = a.runtimeType == b.runtimeType &&
      const DeepCollectionEquality().equals(a, b);
  return equal ? a : b;
}

/// Pass as `placeholderData` to keep showing the previous key's data while the
/// next key is loading.
T? keepPreviousData<T>(T? previousData, [Object? client]) => previousData;

/// Adds [item] after [items], and keeps the last [max] items. Items above
/// the cap before the call are dropped too.
List<T> addToEnd<T>(List<T> items, T item, int? max) {
  final next = [...items, item];
  return max != null && max > 0 && next.length > max
      ? next.sublist(next.length - max)
      : next;
}

/// Adds [item] before [items], and keeps the first [max] items. Items above
/// the cap before the call are dropped too.
List<T> addToStart<T>(List<T> items, T item, int? max) {
  final next = [item, ...items];
  return max != null && max > 0 && next.length > max
      ? next.sublist(0, max)
      : next;
}
