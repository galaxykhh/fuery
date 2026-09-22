import 'package:example/app/app.dart';
import 'package:example/app/data/feed_mutations.dart';
import 'package:example/app/data/preferences_storage.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Queries and mutations with `persist` are stored here, so the feed is on
  // screen before the first request finishes, and a comment written offline
  // is sent even if the app was closed in between.
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  Fuery.client = QueryClient(storage: PreferencesStorage(preferences));
  await Fuery.client.restore(mutations: [addCommentOptions()]);

  runApp(const FeedApp());
}
