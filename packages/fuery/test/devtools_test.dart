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
    return Query.use(
      queryKey: key,
      queryFn: (_) async {
        await Future<void>.delayed(delay);
        return value;
      },
      staleTime: staleTime,
      client: client,
    );
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

    unsubscribe();
    await tearDownApp(tester);
  });

  testWidgets('shows the selected query and runs actions on it',
      (tester) async {
    var fetches = 0;
    final todos = Query.use(
      queryKey: ['todos'],
      queryFn: (_) async {
        fetches++;
        return [const Todo('Buy milk')];
      },
      client: client,
    );
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
    final failing = Query.use(
      queryKey: ['broken'],
      queryFn: (_) async => throw StateError('offline'),
      client: client,
    );
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
    final save = Mutation.use(
      mutationKey: ['todos', 'save'],
      mutationFn: (String title) async => title,
      client: client,
    );
    final fail = Mutation.use(
      mutationFn: (int id) async => throw StateError('nope'),
      client: client,
    );
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
