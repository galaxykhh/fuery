import 'package:fuery/fuery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores persisted queries in shared preferences.
///
/// Reads are synchronous, so a persisted query shows its data on the first
/// frame after a restart.
class PreferencesStorage implements QueryStorage {
  PreferencesStorage(this.preferences);

  final SharedPreferencesWithCache preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<void> delete(String key) => preferences.remove(key);

  @override
  Map<String, String> readAll() => {
        for (final key in preferences.keys)
          if (key.startsWith(persistKeyPrefix))
            key: preferences.getString(key)!,
      };
}
