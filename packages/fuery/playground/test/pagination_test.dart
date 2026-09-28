import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('the previous page stays while the next one loads',
      (tester) async {
    await pumpPlayground(tester, '/pagination');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Page 1 of 5'), findsOneWidget);

    await press(tester, 'Next');
    expect(find.text('Page 2 of 5'), findsOneWidget);
    expect(find.text('Aurora'), findsOneWidget);
    expect(stateValue('isPlaceholderData', 'true'), findsOneWidget);
    expect(stateValue('status', 'success'), findsOneWidget);
    // The next page can't be asked for until this one arrives.
    expect(
      tester.widget<ButtonStyleButton>(button('Next')).onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ember'), findsOneWidget);
    expect(find.text('Aurora'), findsNothing);
    expect(stateValue('isPlaceholderData', 'false'), findsOneWidget);

    // Page 1 is cached: it shows at once and refetches in the background.
    await press(tester, 'Previous');
    expect(find.text('Aurora'), findsOneWidget);
    expect(stateValue('isPlaceholderData', 'false'), findsOneWidget);
    expect(stateValue('fetchStatus', 'fetching'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  testWidgets('without keepPreviousData a new page shows the loading state',
      (tester) async {
    await pumpPlayground(tester, '/pagination');
    await tester.pump(const Duration(seconds: 1));

    await choose(tester, 'none');
    await press(tester, 'Next');
    expect(find.text('Aurora'), findsNothing);
    expect(find.text('Loading…'), findsOneWidget);
    expect(stateValue('status', 'pending'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ember'), findsOneWidget);

    await closePlayground(tester);
  });
}
