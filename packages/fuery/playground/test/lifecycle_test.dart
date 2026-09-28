import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('a stale query refetches when the app comes back',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    expect(find.text('Query lifecycle'), findsWidgets);
    expect(stateValue('fetchStatus', 'fetching'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('12 likes'), findsOneWidget);
    expect(stateValue('status', 'success'), findsOneWidget);
    expect(stateValue('isStale', 'true'), findsOneWidget);

    // The server changes, and the app hears nothing.
    await press(tester, 'Like on the server');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('12 likes'), findsOneWidget);
    expect(requests, ['GET /post']);

    await choose(tester, 'background');
    await tester.pump(const Duration(seconds: 1));
    expect(requests, ['GET /post']);

    await choose(tester, 'foreground');
    expect(requests, ['GET /post', 'GET /post']);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('13 likes'), findsOneWidget);

    await closePlayground(tester);
  });

  testWidgets('fresh data is not refetched until it goes stale',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    await choose(tester, '5 s');
    await tester.pump(const Duration(seconds: 1));
    expect(stateValue('isStale', 'false'), findsOneWidget);

    await choose(tester, 'background');
    await choose(tester, 'foreground');
    await tester.pump();
    expect(requests, ['GET /post']);

    // The data arrived a second in, so it goes stale after 6 s.
    await tester.pump(const Duration(seconds: 5, milliseconds: 100));
    expect(stateValue('isStale', 'true'), findsOneWidget);
    await choose(tester, 'background');
    await choose(tester, 'foreground');
    expect(requests, ['GET /post', 'GET /post']);
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  testWidgets('with an infinite staleTime only refetch and invalidate fetch',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    await choose(tester, 'infinite');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('fresh until invalidated'), findsOneWidget);

    await choose(tester, 'background');
    await choose(tester, 'foreground');
    await tester.pump();
    expect(requests, ['GET /post']);

    await press(tester, 'Invalidate');
    expect(requests, ['GET /post', 'GET /post']);
    await tester.pump(const Duration(seconds: 1));

    await press(tester, 'Refetch');
    expect(requests, ['GET /post', 'GET /post', 'GET /post']);
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  testWidgets('the timeline logs each transition and each request',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('→ GET /post'), findsOneWidget);
    expect(find.text('← 200 GET /post'), findsOneWidget);
    expect(find.text('success · idle · stale'), findsOneWidget);

    await closePlayground(tester);
  });
}
