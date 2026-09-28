import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('load more adds a page until there are none', (tester) async {
    await pumpPlayground(tester, '/infinite');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Post 5'), findsOneWidget);
    expect(find.text('Post 6'), findsNothing);
    expect(stateValue('pages.length', '1'), findsOneWidget);
    expect(stateValue('hasNextPage', 'true'), findsOneWidget);

    await press(tester, 'Load more');
    expect(find.text('Loading the next page…'), findsOneWidget);
    expect(stateValue('isFetchingNextPage', 'true'), findsOneWidget);
    expect(requests, ['GET /feed?page=1', 'GET /feed?page=2']);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Post 6'), findsOneWidget);
    expect(stateValue('pages.length', '2'), findsOneWidget);
    expect(stateValue('isFetchingNextPage', 'false'), findsOneWidget);

    for (var page = 3; page <= 4; page++) {
      await press(tester, 'Load more');
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Post 20'), findsOneWidget);
    expect(stateValue('hasNextPage', 'false'), findsOneWidget);
    expect(find.text('No more pages.'), findsOneWidget);

    // A refetch reloads every page, in order.
    await press(tester, 'Refetch all pages');
    expect(stateValue('isFetchingNextPage', 'false'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(requests.skip(4), [
      'GET /feed?page=1',
      'GET /feed?page=2',
      'GET /feed?page=3',
      'GET /feed?page=4',
    ]);

    await closePlayground(tester);
  });
}
