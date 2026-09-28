import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The number of observers the cache entry panel shows.
String observers(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
      of: find.byKey(const Key('observers')),
      matching: find.byType(Text),
    ))
    .data!;

Future<void> toggle(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilterChip, label));
  await tester.pump();
}

void main() {
  testWidgets('three widgets share one request', (tester) async {
    await pumpPlayground(tester, '/shared-cache');
    expect(requests, ['GET /user']);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Signed in as @ada'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('3 unread for Ada Lovelace'), findsOneWidget);
    expect(observers(tester), '3');
    expect(requests, ['GET /user']);

    // The data is fresh, so a widget that mounts again shows it at once.
    await toggle(tester, 'profile card');
    expect(find.text('The profile card is unmounted'), findsOneWidget);
    await tester.pump();
    expect(observers(tester), '2');
    await toggle(tester, 'profile card');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tester.pump();
    expect(observers(tester), '3');
    expect(requests, ['GET /user']);

    await closePlayground(tester);
  });

  testWidgets('the entry leaves the cache gcTime after the last widget',
      (tester) async {
    await pumpPlayground(tester, '/shared-cache');
    await tester.pump(const Duration(seconds: 1));

    await toggle(tester, 'header');
    await toggle(tester, 'profile card');
    await toggle(tester, 'inbox badge');
    await tester.pump();
    expect(observers(tester), '0');
    expect(stateValue('in the cache', 'yes'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    expect(stateValue('in the cache', 'yes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(stateValue('in the cache', 'no'), findsOneWidget);
    expect(
      find.text('gcTime passed: [user] left the cache'),
      findsOneWidget,
    );

    // Nothing is cached any more, so the next widget fetches.
    await toggle(tester, 'inbox badge');
    expect(requests, ['GET /user', 'GET /user']);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3 unread for Ada Lovelace'), findsOneWidget);

    await closePlayground(tester);
  });
}
