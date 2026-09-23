// Widgets that get a definition: built in build, followed on every rebuild,
// and observed with the provided client.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

const ms10 = Duration(milliseconds: 10);

void main() {
  late QueryClient client;
  late List<Object> fetched;

  QueryClient newClient() => QueryClient(
        defaultOptions: const DefaultOptions(
          queries: QueryDefaults(retry: RetryPolicy.never()),
        ),
      );

  setUp(() {
    focusManager.setFocused(null);
    onlineManager.setOnline(true);
    client = newClient();
    fetched = [];
  });

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  Query<String> post(int id) => Query(
        queryKey: ['post', id],
        queryFn: (_) async {
          fetched.add(id);
          await Future<void>.delayed(ms10);
          return 'post $id';
        },
        placeholderData: keepPreviousData,
      );

  /// A stateless screen that builds the definition in build.
  Widget postScreen(int id) => QueryBuilder(
        query: post(id),
        builder: (context, state) => Text(
          '${state.data ?? 'loading'}${state.isPlaceholderData ? ' (old)' : ''}',
        ),
      );

  testWidgets('a definition built in build keeps one observer', (tester) async {
    Widget app(int id) => FueryProvider(
          client: client,
          child: MaterialApp(home: postScreen(id)),
        );
    await tester.pumpWidget(app(1));
    expect(find.text('loading'), findsOneWidget);
    await tester.pump(ms10);
    expect(find.text('post 1'), findsOneWidget);

    // Rebuilding with the same definition fetches nothing.
    await tester.pumpWidget(app(1));
    await tester.pump(ms10);
    expect(fetched, [1]);

    // A new key keeps the previous data on screen while it loads.
    await tester.pumpWidget(app(2));
    expect(find.text('post 1 (old)'), findsOneWidget);
    await tester.pump(ms10);
    expect(find.text('post 2'), findsOneWidget);
    expect(fetched, [1, 2]);

    // Cached data for the next key shows in the same frame.
    await tester.pumpWidget(app(1));
    expect(find.text('post 1'), findsOneWidget);
    await tester.pump(ms10); // the stale data refetches
    await tearDownApp(tester);
  });

  testWidgets('definitions use the provided client, and follow a new one',
      (tester) async {
    final other = newClient();
    client.setQueryData(['post', 1], 'from the first client');
    other.setQueryData(['post', 1], 'from the second client');
    const staleTime = Duration(minutes: 1);
    Widget app(QueryClient on) => FueryProvider(
          client: on,
          child: MaterialApp(
            home: QueryBuilder(
              query: Query(
                queryKey: ['post', 1],
                queryFn: (_) async => 'fetched',
                staleTime: staleTime,
              ),
              builder: (context, state) => Text(state.data ?? 'loading'),
            ),
          ),
        );

    await tester.pumpWidget(app(client));
    expect(find.text('from the first client'), findsOneWidget);
    await tester.pumpWidget(app(other));
    expect(find.text('from the second client'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    other.clear();
    await tearDownApp(tester);
  });

  testWidgets('definitions never trigger the rebuild warning', (tester) async {
    final printed = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message);

    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(FueryProvider(
        client: client,
        child: MaterialApp(home: postScreen(1)),
      ));
    }
    debugPrint = print;
    expect(printed, isEmpty);
    await tester.pump(ms10);
    await tearDownApp(tester);
  });

  testWidgets('an infinite query loads more from its result', (tester) async {
    await tester.pumpWidget(FueryProvider(
      client: client,
      child: MaterialApp(
        home: InfiniteQueryBuilder(
          query: InfiniteQuery(
            queryKey: ['pages'],
            queryFn: (context) async => 'page ${context.pageParam}',
            initialPageParam: 1,
            getNextPageParam: (data) => data.lastPageParam + 1,
          ),
          builder: (context, state) => TextButton(
            onPressed: state.fetchNextPage,
            child: Text(state.pages.join(', ')),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('page 1'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('page 1, page 2'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('a mutation runs from its builder, in a stateless widget',
      (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(FueryProvider(
      client: client,
      child: MaterialApp(
        home: MutationBuilder(
          mutation: Mutation(
            mutationFn: (String title) async {
              saved.add(title);
              return title.length;
            },
          ),
          builder: (context, state) => TextButton(
            onPressed: () => state.mutate('milk'),
            child: Text(state.isSuccess ? 'saved ${state.data}' : 'save'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('save'));
    await tester.pump();
    expect(saved, ['milk']);
    expect(find.text('saved 4'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('selectors and listeners take definitions', (tester) async {
    final heard = <String?>[];
    Widget app(int id) => FueryProvider(
          client: client,
          child: MaterialApp(
            home: QueryListener(
              query: post(id),
              listener: (context, state) => heard.add(state.data),
              child: QuerySelector(
                query: post(id),
                selector: (state) => state.data?.length ?? 0,
                builder: (context, length) => Text('$length'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(app(1));
    await tester.pump(ms10);
    expect(find.text('6'), findsOneWidget);
    expect(heard.last, 'post 1');

    await tester.pumpWidget(app(22));
    await tester.pump(ms10);
    expect(find.text('7'), findsOneWidget);
    expect(heard.last, 'post 22');
    await tearDownApp(tester);
  });

  testWidgets('FueryProvider.of with listen rebuilds for a new client',
      (tester) async {
    final other = newClient();
    final seen = <QueryClient>[];
    Widget app(QueryClient on) => FueryProvider(
          client: on,
          child: Builder(builder: (context) {
            seen.add(FueryProvider.of(context, listen: true));
            return const SizedBox();
          }),
        );

    await tester.pumpWidget(app(client));
    await tester.pumpWidget(app(other));
    expect(seen, [client, other]);
    await tester.pumpWidget(const SizedBox());
    other.clear();
    await tearDownApp(tester);
  });
}
