import 'package:example/app/app.dart';
import 'package:example/app/data/demo_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

/// The top post of the feed and the one whose like always fails.
const topPost = 'First post on the new feed. Hello, everyone!';
const flakyPost = 'This post fails to like on purpose, to show the rollback.';

/// The first post of the second page.
const secondPagePost = 'Reminder to cancel the request when the screen closes.';

/// Pumps the app on a fresh server, which opens the feed.
Future<void> pumpApp(WidgetTester tester) async {
  DemoApi.reset();
  onlineManager.setOnline(true);
  await tester.pumpWidget(const FeedApp());
  await tester.pump();
}

/// Switches to a tab of the home shell by its label.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pump();
}

/// Waits for the first feed page, which takes 400 ms.
Future<void> loadFeed(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

/// Opens a post from the feed. [transition] is how long to give the route
/// transition; keep it short to arrive while the screen is still loading.
Future<void> openPost(
  WidgetTester tester,
  String body, {
  Duration transition = const Duration(milliseconds: 400),
}) async {
  await tester.tap(find.text(body));
  await tester.pump();
  await tester.pump(transition);
}

/// Unmounts everything and empties the cache, so no timers are left pending.
Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  onlineManager.setOnline(true);
  Fuery.client.clear();
}
