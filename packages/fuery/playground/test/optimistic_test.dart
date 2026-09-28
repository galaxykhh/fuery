import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

String saving(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
      of: find.byKey(const Key('saving')),
      matching: find.byType(Text),
    ))
    .data!;

void main() {
  testWidgets('a new todo shows before the server has it', (tester) async {
    await pumpPlayground(tester, '/optimistic');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try the playground'), findsOneWidget);
    expect(saving(tester), 'All saved');

    await press(tester, 'Add "Buy milk"');
    await tester.pump();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('saving'), findsOneWidget);
    expect(saving(tester), 'Saving 1…');

    // The request, then the refetch that onSettled waits for.
    await tester.pump(const Duration(seconds: 1));
    expect(requests, ['GET /todos', 'POST /todos', 'GET /todos']);
    expect(saving(tester), 'Saving 1…');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('saving'), findsNothing);
    expect(saving(tester), 'All saved');

    await closePlayground(tester);
  });

  testWidgets('a failed add rolls back and shows a snackbar', (tester) async {
    await pumpPlayground(tester, '/optimistic');
    await tester.pump(const Duration(seconds: 1));

    await failNext(tester, 1);
    await press(tester, 'Add "Buy milk"');
    await tester.pump();
    expect(find.text('Buy milk'), findsOneWidget);

    // onError takes the draft out as soon as the request fails.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Buy milk'), findsNothing);
    expect(saving(tester), 'Saving 1…');

    // The run fails once onSettled's refetch is done.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(saving(tester), 'All saved');
    expect(
      find.text('Could not add "Buy milk": 500 on request #2'),
      findsOneWidget,
    );

    await closePlayground(tester);
  });
}
