import 'package:fuery_core/src/base/typedefs.dart';

abstract class Cache<D> {
  List<D> getAll();

  D? find(FueryKey key);

  List<D> findAll({
    required FueryKey key,
    bool? exact,
  });

  bool has(FueryKey key);

  void add(FueryKey key, D value);

  void remove(FueryKey key);
}
