import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a restart restores the stored data at once', (tester) async {
    await pumpPlayground(tester, '/persistence');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Neuromancer'), findsOneWidget);
    expect(find.text('restored from storage'), findsNothing);
    expect(find.textContaining('fuery:'), findsOneWidget);

    await press(tester, 'Restart app');
    await tester.pump();
    expect(find.text('Neuromancer'), findsOneWidget);
    expect(find.text('restored from storage'), findsOneWidget);
    // Fresh for 10 s, so the restored data isn't fetched again.
    expect(stateValue('isStale', 'false'), findsOneWidget);
    expect(requests, ['GET /books']);

    await closePlayground(tester);
  });

  testWidgets('stale restored data refetches after the restart',
      (tester) async {
    await pumpPlayground(tester, '/persistence');
    await tester.pump(const Duration(seconds: 1));

    await press(tester, 'Add a book on the server');
    await tester.pump(const Duration(seconds: 11));
    await press(tester, 'Restart app');
    await tester.pump();
    expect(find.text('Neuromancer'), findsOneWidget);
    expect(find.text('Hyperion'), findsNothing);
    expect(find.text('restored from storage'), findsOneWidget);
    expect(requests, ['GET /books', 'GET /books']);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hyperion'), findsOneWidget);
    expect(find.text('restored from storage'), findsNothing);

    await closePlayground(tester);
  });

  testWidgets('reset starts over with an empty storage', (tester) async {
    await pumpPlayground(tester, '/persistence');
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Reset scenario'));
    await tester.pump();
    expect(find.text('Loading…'), findsOneWidget);
    expect(requests, ['GET /books']);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Neuromancer'), findsOneWidget);

    await closePlayground(tester);
  });
}
