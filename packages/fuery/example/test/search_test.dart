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
}
