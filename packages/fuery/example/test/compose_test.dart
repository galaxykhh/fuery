import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a new post polls until it is published, then stops',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trying out the feed');
    await tester.tap(find.text('Post'));
    await tester.pump();
    expect(find.text('Posting…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // the request
    await tester.pump(); // the screen switches to the new post
    expect(find.text('Publishing…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // the first poll
    expect(find.text('Publishing…'), findsOneWidget);
    expect(find.text('Trying out the feed'), findsOneWidget);

    // Published on the third poll, half a second apart. The feed refetch the
    // mutation started finishes in the meantime.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Polling stopped'), findsOneWidget);

    await tester.tap(find.text('View post'));
    await tester.pumpAndSettle();
    expect(find.byType(PostScreen), findsOneWidget);
    expect(find.text('Trying out the feed'), findsOneWidget);

    await tearDownApp(tester);
  });
}
