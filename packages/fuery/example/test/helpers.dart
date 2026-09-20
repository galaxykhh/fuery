import 'package:example/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

const caseList = 'List, refresh, and optimistic delete';
const caseStats = 'Stats in a cubit';
const caseArchive = 'Paged archive';
const caseSearch = 'Search as you type';
const caseJob = 'Poll a job until it finishes';
const caseAnswer = 'Streamed answer';
const casePrefetch = 'Prefetch before navigating';

/// Pumps the app, which opens the list of cases.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const TodoApp());
  await tester.pump();
}

/// Opens one case from the list. [transition] is how long to give the route
/// transition; keep it short to arrive while the screen is still loading.
Future<void> openCase(
  WidgetTester tester,
  String title, {
  Duration transition = const Duration(milliseconds: 400),
}) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(transition);
}

/// Unmounts everything and empties the cache, so no timers are left pending.
Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  Fuery.client.clear();
}
