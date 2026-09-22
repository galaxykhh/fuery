import 'package:example/app/data/feed_queries.dart';
import 'package:example/app/screens/feed/feed_screen.dart';
import 'package:example/app/screens/post/post_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'helpers.dart';

void main() {
  testWidgets('loads the feed a page at a time', (tester) async {
    await pumpApp(tester);
    expect(
      find.descendant(
        of: find.byType(FeedScreen),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await loadFeed(tester);
    expect(find.text(topPost), findsOneWidget);
    expect(find.text(secondPagePost), findsNothing);

    // Scrolling near the end loads the next page on its own.
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(Fuery.client.isFetching(queryKey: feedKey), 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text(secondPagePost), 300);
    expect(find.text(secondPagePost), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('pulling the feed down refetches it', (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.fling(find.text(topPost), const Offset(0, 300), 1000);
    await tester.pump();
    // The indicator snaps into place first, and calls onRefresh after it.
    await tester.pump(const Duration(milliseconds: 300));

    // It stays up until the future refetch() returns.
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(Fuery.client.isFetching(queryKey: ['posts']), 1);

    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.text(topPost), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('a like applies at once and rolls back when it fails',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);

    // Post 30 starts with 30 * 7 % 40 = 10 likes and is liked (30 % 5 == 0).
    final topCard = find.ancestor(
      of: find.text(topPost),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: topCard, matching: find.text('10')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: topCard, matching: find.byIcon(Icons.favorite)),
    );
    await tester.pump();
    expect(
      find.descendant(of: topCard, matching: find.text('9')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 300)); // the request
    await tester.pump(const Duration(milliseconds: 300)); // the refetch
    expect(
      find.descendant(of: topCard, matching: find.text('9')),
      findsOneWidget,
    );

    // Post 29 has 29 * 7 % 40 = 3 likes and its like always fails.
    final flakyCard = find.ancestor(
      of: find.text(flakyPost),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: flakyCard,
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(of: flakyCard, matching: find.text('4')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(of: flakyCard, matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('Could not like the post'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('hovering a post prefetches it, so it opens without loading',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text(flakyPost)));
    await tester.pump();
    expect(Fuery.client.isFetching(queryKey: ['posts', 'detail']), 1);
    await tester.pump(const Duration(milliseconds: 300));

    await openPost(tester, flakyPost);
    expect(find.byType(PostScreen), findsOneWidget);
    // Loaded from the cache, not the feed's placeholder.
    expect(find.textContaining('from the feed'), findsNothing);
    expect(find.textContaining('3 likes'), findsOneWidget);

    await tearDownApp(tester);
  });
}
