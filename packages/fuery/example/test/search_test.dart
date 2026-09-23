import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('search keeps the previous results while the next ones load',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);
    await openTab(tester, 'Search');
    expect(find.text('Type to search'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'airplane');
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pump(const Duration(milliseconds: 300)); // request
    expect(find.textContaining('Airplane mode'), findsOneWidget);

    // A new term shows the previous results until the new ones arrive.
    await tester.enterText(find.byType(TextField), 'devtools');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Airplane mode'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('devtools panel'), findsOneWidget);
    expect(find.textContaining('Airplane mode'), findsNothing);

    await tearDownApp(tester);
  });

  testWidgets('a like in the feed shows in cached search results at once',
      (tester) async {
    await pumpApp(tester);
    await loadFeed(tester);
    await openTab(tester, 'Search');
    await tester.enterText(find.byType(TextField), 'hello, everyone');
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pump(const Duration(milliseconds: 300)); // request
    Finder likesOfTopPost() => find.descendant(
          of: find.ancestor(
            of: find.text(topPost),
            matching: find.byType(ListTile),
          ),
          matching: find.textContaining('likes'),
        );
    expect(tester.widget<Text>(likesOfTopPost()).data, endsWith('10 likes'));

    // Unlike the top post in the feed, then look at the search results
    // before the request finishes.
    await openTab(tester, 'Feed');
    final topCard = find.ancestor(
      of: find.text(topPost),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: topCard, matching: find.byIcon(Icons.favorite)),
    );
    await tester.pump();
    await openTab(tester, 'Search');
    expect(tester.widget<Text>(likesOfTopPost()).data, endsWith('9 likes'));

    await tester.pump(const Duration(milliseconds: 300)); // the request
    await tester.pump(const Duration(milliseconds: 300)); // results refetch
    expect(tester.widget<Text>(likesOfTopPost()).data, endsWith('9 likes'));
    await tearDownApp(tester);
  });
}
