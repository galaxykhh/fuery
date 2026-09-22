import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Finder badge(String count) =>
    find.descendant(of: find.byType(Badge), matching: find.text(count));

void main() {
  testWidgets('the badge and the list share one polled query', (tester) async {
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 200)); // notifications
    await loadFeed(tester);

    // Two unread, counted by the cubit behind the badge.
    expect(badge('2'), findsOneWidget);

    // The second poll, five seconds later, brings a new notification.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(badge('3'), findsOneWidget);

    await openTab(tester, 'Notifications');
    expect(find.byIcon(Icons.notifications_active), findsNWidgets(3));

    // Read at once on screen, then confirmed by the server.
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(find.byIcon(Icons.notifications_active), findsNothing);
    expect(badge('3'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.notifications_active), findsNothing);

    await tearDownApp(tester);
  });
}
