import 'package:example/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  testWidgets('loads todos and deletes one optimistically', (tester) async {
    await tester.pumpWidget(const TodoApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Grocery Shopping'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle).first);
    await tester.pump();
    expect(find.text('Grocery Shopping'), findsNothing);
    expect(find.byType(ModalBarrier), findsNWidgets(2));

    // The delete takes 3 seconds, then the list refetches.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Grocery Shopping'), findsNothing);
    expect(find.text('Finish Assignment'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Fuery.client.clear();
  });
}
