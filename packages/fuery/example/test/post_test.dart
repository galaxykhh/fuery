import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'helpers.dart';

void main() {
  testWidgets('a post opens with the feed\'s copy, then its comments',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);

    await openPost(tester, topPost, transition: Duration.zero);
    // No spinner: the post query starts with the feed's post as placeholder.
    expect(
      find.descendant(
        of: find.byType(PostScreen),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(find.textContaining('from the feed'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('from the feed'), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Can you share the onboarding numbers?'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('a comment written offline sends when the app is back online',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);
    await tester.tap(find.byIcon(Icons.wifi));
    await tester.pump();
    expect(onlineManager.isOnline, isFalse);

    await openPost(tester, topPost);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Congrats on the launch');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(
      find.text('Comment will send when you\'re back online'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Congrats on the launch'), findsNothing);

    // Back online: the paused mutation runs, then the comments refetch. The
    // post and comments queries that paused while offline resume as well.
    onlineManager.setOnline(true);
    await tester.pump();
    expect(find.text('Sending…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // the request
    await tester.pump(const Duration(milliseconds: 300)); // the refetch
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Congrats on the launch'), findsOneWidget);
    expect(find.text('Sending…'), findsNothing);

    await tearDownApp(tester);
  });

  testWidgets('a thread summary streams in, and is cached when reopened',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);
    await openPost(tester, topPost);

    await tester.tap(find.text('Summarize thread'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Summarizing…'), findsOneWidget);
    expect(find.text('3 comments'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Summary'), findsOneWidget);
    expect(find.textContaining('ask for a follow-up'), findsOneWidget);

    // Reopened: the cached summary is complete on the first frame.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openPost(tester, topPost);
    await tester.tap(find.text('Summarize thread'));
    await tester.pump();
    expect(find.text('Summary'), findsOneWidget);
    expect(find.textContaining('ask for a follow-up'), findsOneWidget);

    await tearDownApp(tester);
  });
}
