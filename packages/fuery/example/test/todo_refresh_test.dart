import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a refetch in flight does not bring a deleted todo back',
      (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseList);
    await tester.pump(const Duration(milliseconds: 500));

    // Refresh, then delete while the refetch is still running.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.remove_circle).first);
    await tester.pump();

    // The refetch would have finished by now; the delete is still running.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ModalBarrier), findsNWidgets(2));
    expect(find.text('Grocery Shopping'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Grocery Shopping'), findsNothing);

    await tearDownApp(tester);
  });
}
