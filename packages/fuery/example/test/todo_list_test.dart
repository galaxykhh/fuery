import 'package:example/app/screens/todo_detail/todo_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'helpers.dart';

void main() {
  testWidgets('loads todos and deletes one optimistically', (tester) async {
    await pumpApp(tester);
    // Arrive while the list the cases screen started is still loading.
    await openCase(tester, caseList, transition: Duration.zero);
    expect(find.text('Grocery Shopping'), findsNothing);

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

    await tearDownApp(tester);
  });

  testWidgets('pulling the list down refetches it', (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseList);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.fling(
        find.text('Finish Assignment'), const Offset(0, 300), 1000);
    await tester.pump();
    // The indicator snaps into place first, and calls onRefresh after it.
    await tester.pump(const Duration(milliseconds: 300));

    // It stays up until the future refetch() returns.
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(Fuery.client.isFetching(), 1);

    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(Fuery.client.isFetching(), 0);
    expect(find.text('Finish Assignment'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('opens a todo with the list\'s copy already on screen',
      (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseList);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Finish Assignment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No spinner: the detail query starts with the list's todo as placeholder.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Showing the list\'s copy while loading'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Loaded from the server'), findsOneWidget);
    expect(find.byType(TodoDetailScreen), findsOneWidget);

    await tearDownApp(tester);
  });
}
