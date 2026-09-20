import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('the archive loads one page at a time', (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseArchive);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Archived todo 1'), findsOneWidget);
    expect(find.text('Archived todo 9'), findsNothing);

    await tester.scrollUntilVisible(find.text('Load more'), 300);
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('Archived todo 9'), 300);
    expect(find.text('Archived todo 9'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('search keeps the previous results while the next ones load',
      (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseSearch);
    expect(find.text('Type to search'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'todo 1');
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pump(const Duration(milliseconds: 300)); // request
    expect(find.text('Archived todo 1'), findsOneWidget);

    // A new term shows the previous results until the new ones arrive.
    await tester.enterText(find.byType(TextField), 'todo 2');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Archived todo 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Archived todo 2'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('polling a job stops when it finishes', (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseJob);
    expect(find.text('No job yet'), findsOneWidget);

    await tester.tap(find.text('Start a job'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Polling…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Done, polling stopped'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('a streamed answer grows while it arrives', (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseAnswer);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Streaming…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Complete, and cached'), findsOneWidget);
    expect(
        find.textContaining('Fuery keeps your todos cached'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('prefetching opens the archive without a spinner',
      (tester) async {
    await pumpApp(tester);
    await openCase(tester, casePrefetch);

    await tester.tap(find.text('Prefetch, then open'));
    await tester.pump();
    expect(find.text('Prefetching…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400)); // the request
    await tester.pump(); // the route
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Archived todo 1'), findsOneWidget);

    await tearDownApp(tester);
  });
}
