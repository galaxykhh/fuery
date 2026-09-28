import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a fetch retries and succeeds', (tester) async {
    await pumpPlayground(tester, '/retries');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Built by request #1'), findsOneWidget);

    await failNext(tester, 2);
    await press(tester, 'Reset and load');
    expect(find.text('Attempt 1…'), findsOneWidget);

    // Each attempt takes 300 ms, and the retries wait 0.5 s, then 1 s.
    await tester.pump(const Duration(milliseconds: 300));
    expect(stateValue('failureCount', '1'), findsOneWidget);
    expect(stateValue('failureReason', '500 on request #2'), findsOneWidget);
    expect(find.textContaining('Attempt 1 failed'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(stateValue('failureCount', '2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Built by request #4'), findsOneWidget);
    expect(stateValue('failureCount', '0'), findsOneWidget);
    expect(requests, [
      'GET /report',
      'GET /report',
      'GET /report',
      'GET /report',
    ]);

    await closePlayground(tester);
  });

  testWidgets('the error shows once the retries run out', (tester) async {
    await pumpPlayground(tester, '/retries');
    await tester.pump(const Duration(milliseconds: 300));

    await failNext(tester, 5);
    await press(tester, 'Reset and load');
    // Four attempts of 300 ms, with 0.5 s, 1 s, and 2 s between them.
    await tester.pump(const Duration(milliseconds: 4600));
    expect(find.text('Try again'), findsNothing);
    expect(stateValue('failureCount', '3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(stateValue('status', 'error'), findsOneWidget);
    expect(stateValue('failureCount', '4'), findsOneWidget);
    expect(find.text('Could not load: 500 on request #5'), findsOneWidget);

    // One failure is left: the first attempt fails, and the retry succeeds.
    await press(tester, 'Try again');
    await tester.pump(const Duration(milliseconds: 300));
    expect(stateValue('failureCount', '1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Built by request #7'), findsOneWidget);
    expect(stateValue('status', 'success'), findsOneWidget);

    await closePlayground(tester);
  });

  testWidgets('a failed refetch keeps the data', (tester) async {
    await pumpPlayground(tester, '/retries');
    await tester.pump(const Duration(milliseconds: 300));

    await failNext(tester, 4);
    await press(tester, 'Refetch');
    await tester.pump(const Duration(milliseconds: 4700));
    expect(find.text('Built by request #1'), findsOneWidget);
    expect(find.textContaining('The refetch failed'), findsOneWidget);
    expect(stateValue('status', 'error'), findsOneWidget);

    await closePlayground(tester);
  });
}
