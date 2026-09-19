import 'package:fuery_core/src/base/typedefs.dart';

class Cacheable {
  Cacheable({required FueryKey key})
      : _key = key,
        _encodedKey = key.toString();

  final FueryKey _key;
  FueryKey get key => _key;

  final String _encodedKey;
  String get encodedKey => _encodedKey;
}
