import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';
import 'package:fuery/src/devtools.dart';

const ms10 = Duration(milliseconds: 10);

class Todo {
  const Todo(this.title);
  final String title;
  Map<String, Object?> toJson() => {'title': title};
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('count $_count'),
    );
  }
}

void main() {
  late QueryClient client;

  setUp(() {
    focusManager.setFocused(null);
    onlineManager.setOnline(true);
    client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool enabled = true,
    bool initiallyOpen = true,
  }) {
    return tester.pumpWidget(
      FueryProvider(
        client: client,
        child: MaterialApp(
          builder: (context, child) => FueryDevtools(
            enabled: enabled,
            initiallyOpen: initiallyOpen,
            child: child!,
          ),
          home: const Scaffold(body: Text('app')),
        ),
      ),
    );
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  QueryObserver<String> query(
    QueryKey key, {
    String value = 'data',
    Duration delay = ms10,
    Duration? staleTime,
  }) {
    return Query(
      queryKey: key,
      queryFn: (_) async {
        await Future<void>.delayed(delay);
        return value;
      },
      staleTime: staleTime,
    ).observe(client: client);
  }

  Finder openButton() => find.bySemanticsLabel('Open Fuery devtools');

  testWidgets('shows only the app when disabled', (tester) async {
    await pumpApp(tester, enabled: false);

    expect(find.text('app'), findsOneWidget);
    expect(openButton(), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('opens from the button and closes', (tester) async {
    await pumpApp(tester, initiallyOpen: false);
    expect(find.text('Queries (0)'), findsNothing);

    await tester.tap(openButton());
    await tester.pump();
    expect(find.text('Queries (0)'), findsOneWidget);
    expect(find.text('app'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Queries (0)'), findsNothing);
    expect(openButton(), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('leaves a floating action button uncovered by default',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      FueryProvider(
        client: client,
        child: MaterialApp(
          builder: (context, child) => FueryDevtools(child: child!),
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => pressed++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(pressed, 1);
    expect(openButton(), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('turning it off keeps the app state', (tester) async {
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      FueryProvider(
        client: client,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: enabled,
              builder: (context, on, _) =>
                  FueryDevtools(enabled: on, child: const _Counter()),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('count 0'));
    await tester.pump();

    enabled.value = false;
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    expect(openButton(), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets(
    'opens the text selection toolbar on iOS',
    (tester) async {
      client.setQueryData(['todos'], 'some data');
      await pumpApp(tester);
      await tester.tap(find.text('["todos"]'));
      await tester.pump();

      await tester.longPress(find.byType(SelectableText));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('lists queries as they change and filters them by key',
      (tester) async {
    await pumpApp(tester);
    final todos = query(['todos']);
    final unsubscribe = todos.subscribe((_) {});
    client.setQueryData(['user'], 'me');
    await tester.pump(Duration.zero);

    expect(find.text('Queries (2)'), findsOneWidget);
    expect(find.text('["todos"]'), findsOneWidget);
    expect(find.text('fetching'), findsOneWidget);
    expect(find.text('inactive'), findsOneWidget);

    await tester.pump(ms10);
    expect(find.text('stale'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'user');
    await tester.pump();
    expect(find.text('["todos"]'), findsNothing);
    expect(find.text('["user"]'), findsOneWidget);

    // The field still shows the filter after a tab switch.
    await tester.tap(find.text('Mutations (0)'));
    await tester.pump();
    await tester.tap(find.text('Queries (2)'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'user',
    );
    expect(find.text('["todos"]'), findsNothing);
    expect(find.text('["user"]'), findsOneWidget);

    unsubscribe();
    await tearDownApp(tester);
  });

  testWidgets('shows the selected query and runs actions on it',
      (tester) async {
    var fetches = 0;
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async {
        fetches++;
        return [const Todo('Buy milk')];
      },
    ).observe(client: client);
    final unsubscribe = todos.subscribe((_) {});
    await pumpApp(tester);
    await tester.pump(Duration.zero);

    await tester.tap(find.text('["todos"]'));
    await tester.pump();
    expect(find.textContaining('"title": "Buy milk"'), findsOneWidget);
    expect(find.textContaining('success · idle'), findsOneWidget);

    await tester.tap(find.text('Refetch'));
    await tester.pump(Duration.zero);
    expect(fetches, 2);

    await tester.tap(find.text('Invalidate'));
    await tester.pump(Duration.zero);
    expect(fetches, 3);

    await tester.tap(find.text('Reset'));
    await tester.pump(Duration.zero);
    expect(fetches, 4);

    unsubscribe();
    await tester.tap(find.text('Remove'));
    await tester.pump(Duration.zero);
    expect(client.queryCache.getAll(), isEmpty);
    expect(find.text('Refetch'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('stacks the list and details on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(1200, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final failing = Query(
      queryKey: ['broken'],
      queryFn: (_) async => throw StateError('offline'),
    ).observe(client: client);
    final unsubscribe = failing.subscribe((_) {});
    await pumpApp(tester);
    await tester.pump(Duration.zero);

    await tester.tap(find.text('["broken"]'));
    await tester.pump();
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.textContaining('Bad state: offline'), findsOneWidget);

    unsubscribe();
    await tearDownApp(tester);
  });

  testWidgets('lists mutations, newest first', (tester) async {
    final save = Mutation(
      mutationKey: ['todos', 'save'],
      mutationFn: (String title) async => title,
    ).observe(client: client);
    final fail = Mutation(
      mutationFn: (int id) async => throw StateError('nope'),
    ).observe(client: client);
    await pumpApp(tester);
    save.mutate('Buy milk');
    fail.mutate(1);
    await tester.pump(Duration.zero);

    await tester.tap(find.text('Mutations (2)'));
    await tester.pump();
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Mutation 2', '["todos","save"]']);
    expect(find.text('variables: "Buy milk"'), findsOneWidget);
    expect(find.text('variables: 1\nerror: Bad state: nope'), findsOneWidget);

    await tester.tap(find.text('Queries (0)'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('an embedded panel follows the client it is given',
      (tester) async {
    final other = QueryClient();
    other.setQueryData(['other'], 'data');
    client.setQueryData(['mine'], 'data');
    Widget panel(QueryClient client) {
      return MaterialApp(
          home: Scaffold(body: FueryDevtoolsPanel(client: client)));
    }

    await tester.pumpWidget(panel(client));
    expect(find.text('["mine"]'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);

    await tester.tap(find.text('["mine"]'));
    await tester.pumpWidget(panel(client));
    await tester.pumpWidget(panel(other));
    expect(find.text('["other"]'), findsOneWidget);
    expect(find.text('Refetch'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    other.clear();
    client.clear();
  });

  testWidgets('follows a provider whose client is replaced', (tester) async {
    final other = QueryClient();
    other.setQueryData(['other'], 'data');
    client.setQueryData(['mine'], 'data');
    final current = ValueNotifier(client);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: current,
        builder: (context, client, _) => FueryProvider(
          client: client,
          child: const MaterialApp(home: Scaffold(body: FueryDevtoolsPanel())),
        ),
      ),
    );
    expect(find.text('["mine"]'), findsOneWidget);

    current.value = other;
    await tester.pump();
    expect(find.text('["other"]'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    other.clear();
    client.clear();
  });

  testWidgets('shows Fuery.client without a provider', (tester) async {
    Fuery.client = client;
    client.setQueryData(['global'], 'data');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FueryDevtoolsPanel())),
    );
    expect(find.text('["global"]'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('labels disabled queries and unobserved paused fetches',
      (tester) async {
    final disabled = Query(
      queryKey: ['off'],
      queryFn: (_) async => 'data',
      enabled: false,
    ).observe(client: client)
      ..subscribe((_) {});
    onlineManager.setOnline(false);
    client
        .query(Query(queryKey: ['prefetch'], queryFn: (_) async => 'x'))
        .ignore();
    await tester.pump();

    CachedQuery<Object> find(QueryKey queryKey) =>
        client.queryCache.find(QueryFilters(queryKey: queryKey))!;
    expect(queryStatusLabel(find(['off'])), 'disabled');
    expect(queryStatusLabel(find(['prefetch'])), 'paused');

    disabled.destroy();
    client.clear();
  });

  testWidgets('labels paused and fresh queries', (tester) async {
    onlineManager.setOnline(false);
    final paused = query(['paused'])..subscribe((_) {});
    final fresh = query(['fresh'], staleTime: infiniteDuration);
    client.setQueryData(['fresh'], 'data');
    fresh.subscribe((_) {});
    await tester.pump();

    expect(
        queryStatusLabel(client.queryCache.find(
          const QueryFilters(queryKey: ['paused']),
        )!),
        'paused');
    expect(
        queryStatusLabel(client.queryCache.find(
          const QueryFilters(queryKey: ['fresh']),
        )!),
        'fresh');

    paused.destroy();
    fresh.destroy();
    client.clear();
  });

  test('formats data as JSON, falling back to toString', () {
    expect(formatData({'a': 1}), '{\n  "a": 1\n}');
    expect(formatData(const Todo('a')), '{\n  "title": "a"\n}');
    expect(formatData(const Duration(seconds: 1)), '"0:00:01.000000"');

    final cycle = <Object>[];
    cycle.add(cycle);
    expect(formatData(cycle), '[[...]]');
  });

  test('formats timestamps as local time', () {
    expect(formatTime(0), '-');
    final time = DateTime(2026, 9, 20, 7, 5, 9);
    expect(formatTime(time.millisecondsSinceEpoch), '07:05:09');
  });
}
