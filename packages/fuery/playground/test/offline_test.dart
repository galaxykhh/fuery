import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'helpers.dart';

void main() {
  testWidgets('a paused fetch keeps the data and resumes online',
      (tester) async {
    await pumpPlayground(tester, '/offline');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Go offline, then send one.'), findsOneWidget);

    await choose(tester, 'offline');
    expect(onlineManager.isOnline, isFalse);
    await press(tester, 'Refetch');
    await tester.pump();
    expect(stateValue('fetchStatus', 'paused'), findsOneWidget);
    expect(find.text('Go offline, then send one.'), findsOneWidget);
    expect(requests, ['GET /messages']);

    await choose(tester, 'online');
    expect(requests, ['GET /messages', 'GET /messages']);
    await tester.pump(const Duration(seconds: 1));
    expect(stateValue('fetchStatus', 'idle'), findsOneWidget);

    await closePlayground(tester);
    expect(onlineManager.isOnline, isTrue);
  });

  testWidgets(
      'a mutation sent offline runs on reconnect, then the list '
      'refetches', (tester) async {
    await pumpPlayground(tester, '/offline');
    await tester.pump(const Duration(seconds: 1));

    await choose(tester, 'offline');
    await press(tester, 'Send "On my way"');
    await tester.pump();
    expect(find.text('waiting for the network'), findsOneWidget);
    expect(find.widgetWithText(Wrap, 'isPaused'), findsOneWidget);
    expect(requests, ['GET /messages']);

    await choose(tester, 'online');
    await tester.pump();
    expect(requests, ['GET /messages', 'POST /messages']);
    await tester.pump(const Duration(seconds: 1));
    expect(requests, ['GET /messages', 'POST /messages', 'GET /messages']);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('waiting for the network'), findsNothing);
    expect(find.text('sending'), findsNothing);

    // Only the refetch of the invalidated list: the data is fresh after it.
    await tester.pump(const Duration(seconds: 2));
    expect(requests, ['GET /messages', 'POST /messages', 'GET /messages']);

    await closePlayground(tester);
  });

  testWidgets('reset and leaving the scenario put the device back online',
      (tester) async {
    await pumpPlayground(tester, '/offline');
    await tester.pump(const Duration(seconds: 1));

    await choose(tester, 'offline');
    await tester.tap(find.text('Reset scenario'));
    await tester.pump();
    expect(onlineManager.isOnline, isTrue);
    expect(stateValue('fetchStatus', 'fetching'), findsOneWidget);
    final online = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(online.selected, {true});
    await tester.pump(const Duration(seconds: 1));

    // The next scenario starts online, not paused.
    await choose(tester, 'offline');
    await tester.tap(find.text('1. Query lifecycle'));
    await tester.pump();
    expect(onlineManager.isOnline, isTrue);
    expect(stateValue('fetchStatus', 'fetching'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('12 likes'), findsOneWidget);

    await closePlayground(tester);
  });
}
