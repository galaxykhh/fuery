import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/app.dart';
import 'package:playground/fake_server.dart';
import 'package:playground/widgets/state_panels.dart';

/// A screen that shows the sidebar and every panel of a scenario without
/// scrolling.
const wideScreen = Size(1400, 3000);

/// Opens the playground at [path], such as `/lifecycle`, on a screen of
/// [size] logical pixels.
Future<void> pumpPlayground(
  WidgetTester tester,
  String path, {
  Size size = wideScreen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PlaygroundApp(initialLocation: path));
  await tester.pump();
}

/// Unmounts the playground. The scenario clears its clients and drops the
/// requests in flight as it closes, so no timer is left.
Future<void> closePlayground(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// The fake server of the scenario on screen.
FakeServer get fakeServer => FakeServer.current;

/// The requests the fake server received, such as `GET /post`.
List<String> get requests => [for (final request in fakeServer.log) '$request'];

/// The button labeled [label] in the controls or the live UI.
Finder button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );

/// Presses the button labeled [label].
Future<void> press(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

/// Picks [label] in a segmented control.
Future<void> choose(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byWidgetPredicate((widget) => widget is SegmentedButton),
    matching: find.text(label),
  );
  await tester.ensureVisible(segment);
  await tester.tap(segment);
  await tester.pump();
}

/// The value the state panel shows for [label], such as `isStale`.
Finder stateValue(String label, String value) => find.descendant(
      of: find.widgetWithText(StateRow, label),
      matching: find.text(value),
    );

/// Sets how many of the next requests the fake server fails, with its
/// stepper.
Future<void> failNext(WidgetTester tester, int count) async {
  while (fakeServer.failNext < count) {
    await tester.tap(find.byTooltip('Fail one request more'));
    await tester.pump();
  }
}
