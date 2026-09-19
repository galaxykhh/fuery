import 'package:fuery_core/src/base/cache.dart';
import 'package:fuery_core/src/base/mutation.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/util/cache_filter.dart';

class MutationCache
    with CacheFilter<MutationBase>
    implements Cache<MutationBase> {
  MutationCache._();

  factory MutationCache() => MutationCache._();

  final Store<MutationBase> _mutations = {};

  @override
  void add(MutationKey key, MutationBase mutation) {
    _mutations[key.toString()] = mutation;
  }

  @override
  List<MutationBase> getAll() {
    return _mutations.entries.map((e) => e.value).toList();
  }

  @override
  MutationBase? find(MutationKey key) {
    return _mutations[key.toString()];
  }

  @override
  List<MutationBase> findAll({
    required MutationKey key,
    bool? exact,
  }) {
    return filter(
      items: _mutations,
      key: key,
      exact: exact,
    );
  }

  @override
  bool has(MutationKey key) {
    return find(key) != null;
  }

  @override
  Future<void> remove(MutationKey key) async {
    await find(key)?.sleep();
    _mutations.remove(key.toString());
  }
}
