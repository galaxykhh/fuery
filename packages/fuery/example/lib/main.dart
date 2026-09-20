import 'package:example/app/app.dart';
import 'package:example/app/data/preferences_storage.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Queries with `persist` are stored here, so the todo list is on screen
  // before the first request finishes.
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  Fuery.client = QueryClient(storage: PreferencesStorage(preferences));

  runApp(const TodoApp());
}
