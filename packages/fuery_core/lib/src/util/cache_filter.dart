import 'package:fuery_core/src/base/cacheable.dart';
import 'package:fuery_core/src/base/typedefs.dart';

mixin CacheFilter<T extends Cacheable> {
  /// Filter items based on their keys.
  ///
  /// If [exact] is true, filter only elements with exactly matching keys.
  List<T> filter({
    required Store<T> items,
    FueryKey? key,
    bool? exact,
  }) {
    if (key == null) {
      return items.entries.map((item) => item.value).toList();
    }

    assert(key.isNotEmpty, 'key should not be empty');

    return items.entries
        .where((item) {
          if (exact == true) {
            return _compare(
              key: key,
              targetKey: item.value.key,
              exact: exact,
            );
          }

          return (_hasSameKeyLength(
                    key: key,
                    targetKey: item.value.key,
                  ) ||
                  _hasLongerKeyLength(
                    key: key,
                    targetKey: item.value.key,
                  )) &&
              _compare(
                key: key,
                targetKey: item.value.key,
              );
        })
        .map((item) => item.value)
        .toList();
  }

  /// Returns true if has same key length.
  bool _hasSameKeyLength({
    required FueryKey key,
    required FueryKey targetKey,
  }) {
    return key.length == targetKey.length;
  }

  /// Returns true if has longer key length.
  bool _hasLongerKeyLength({
    required FueryKey key,
    required FueryKey targetKey,
  }) {
    return key.length <= targetKey.length;
  }

  /// Returns true when it's not a primitive type.
  bool _shouldStringify(dynamic target) {
    return (target is! String &&
        target is! int &&
        target is! double &&
        target is! bool);
  }

  /// Returns true when comparing two keys and they are the same.
  bool _compare({
    required FueryKey key,
    required FueryKey targetKey,
    bool? exact,
  }) {
    if (exact == true && !_hasSameKeyLength(key: key, targetKey: targetKey)) {
      return false;
    }

    for (final (int, dynamic) item in key.indexed.toList()) {
      final dynamic keyItem = item.$2;
      final dynamic targetItem = targetKey[item.$1];
      final bool isSameType = targetItem.runtimeType == keyItem.runtimeType;
      final bool isSame = isSameType && _shouldStringify(targetItem)
          ? targetItem.toString() == keyItem.toString()
          : targetItem == keyItem;

      if (isSame) continue;

      return false;
    }

    return true;
  }
}
