import 'package:example/app/screens/todo_stats/todo_stats_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

import 'helpers.dart';

void main() {
  testWidgets('the cubit fetches todos when it starts listening',
      (tester) async {
    final cubit = TodoStatsCubit();
    expect(cubit.state.isLoading, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.total, 5);

    await cubit.close();
    expect(cubit.isClosed, isTrue);
    Fuery.client.clear();
  });

  testWidgets('the stats screen shares the list screen\'s cache',
      (tester) async {
    await pumpApp(tester);
    await openCase(tester, caseList);
    await tester.pump(const Duration(milliseconds: 500));

    // Complete a todo on the list screen.
    await tester.tap(find.text('In Progress').first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Done'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    await openCase(tester, caseStats);

    // The stats screen shows it right away, from the shared cache.
    expect(find.text('1 of 5 completed'), findsOneWidget);

    // It still matches after its own background refetch.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 of 5 completed'), findsOneWidget);

    await tearDownApp(tester);
  });
}
