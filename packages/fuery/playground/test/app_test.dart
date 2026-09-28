import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/app.dart';
import 'package:playground/widgets/code_panel.dart';

import 'helpers.dart';

void main() {
  testWidgets('the home page opens each scenario', (tester) async {
    await pumpPlayground(tester, '/');
    expect(find.text('Fuery playground'), findsOneWidget);
    for (final (index, scenario) in scenarios.indexed) {
      expect(find.text('${index + 1}. ${scenario.title}'), findsWidgets);
    }

    // A card of the home page.
    await tester.tap(find.text('3. Retries').last);
    await tester.pump();
    expect(find.text('Try this'), findsOneWidget);
    expect(button('Reset and load'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));

    // The sidebar.
    await tester.tap(find.text('4. Offline'));
    await tester.pump();
    expect(button('Send "On my way"'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  testWidgets('an unknown route opens the home page', (tester) async {
    await pumpPlayground(tester, '/nothing-here');
    expect(find.text('Fuery playground'), findsOneWidget);

    await closePlayground(tester);
  });

  testWidgets('a narrow screen lists the scenarios in a drawer',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle', size: const Size(360, 780));
    expect(find.text('2. One key, one request'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('2. One key, one request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('One key, one request'), findsWidgets);
    expect(find.byType(Drawer), findsNothing);
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  for (final brightness in Brightness.values) {
    for (final scenario in scenarios) {
      testWidgets(
          '${scenario.path} fits a 360 px screen in ${brightness.name} mode',
          (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await pumpPlayground(
          tester,
          '/${scenario.path}',
          size: const Size(360, 6000),
        );
        await tester.pump(const Duration(seconds: 1));
        // Overflows and other layout errors fail the test.
        expect(find.byType(CodeBlock), findsWidgets);

        await closePlayground(tester);
      });
    }
  }

  testWidgets('the code panel shows the snippet regions of the scenario file',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    await tester.pump();

    final code = tester
        .widgetList<CodeBlock>(find.byType(CodeBlock))
        .map((block) => block.code)
        .toList();
    expect(code, hasLength(2));
    expect(code.first, startsWith('Query<Post> postQuery('));
    expect(code.first, contains("queryKey: ['post'],"));
    expect(code.last, startsWith('final query = postQuery('));
    expect(code.join(), isNot(contains('#region')));
    await tester.pump(const Duration(seconds: 1));

    await closePlayground(tester);
  });

  testWidgets('reset starts a scenario over with a new client and server',
      (tester) async {
    await pumpPlayground(tester, '/lifecycle');
    await tester.pump(const Duration(seconds: 1));
    final firstServer = fakeServer;

    await press(tester, 'Like on the server');
    await press(tester, 'Refetch');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('13 likes'), findsOneWidget);
    expect(fakeServer.requestCount, 2);

    await tester.tap(find.text('Reset scenario'));
    await tester.pump();
    expect(identical(fakeServer, firstServer), isTrue);
    expect(fakeServer.requestCount, 1);
    expect(find.text('Loading…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('12 likes'), findsOneWidget);
    expect(find.text('Like on the server'), findsOneWidget);

    await closePlayground(tester);
  });

  testWidgets('extractSnippets joins nothing and dedents each region',
      (_) async {
    const source = '''
void main() {
  // #region snippet
    final a = 1;
    if (a > 0) {
      print(a);
    }
  // #endregion
  // #region snippet
  print(2);
  // #endregion
}
''';
    expect(extractSnippets(source), [
      'final a = 1;\nif (a > 0) {\n  print(a);\n}',
      'print(2);',
    ]);
  });
}
