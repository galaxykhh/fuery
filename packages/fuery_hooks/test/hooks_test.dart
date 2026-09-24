// The hooks render through the same slots as the widgets of `fuery`, so
// these tests follow the widget tests: first frames, rebuilds with new
// definitions, a replaced client, and disposal.
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery_hooks/fuery_hooks.dart';
import 'package:fuery_hooks/src/hooks.dart' show debugResetHookWarnings;

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
    debugResetHookWarnings();
  });

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  Widget app(Widget child, {QueryClient? with_}) => FueryProvider(
        client: with_ ?? client,
        child: MaterialApp(home: child),
      );

  Query<String> post(int id) => Query(
        queryKey: ['post', id],
        queryFn: (_) async {
          fetched.add(id);
          await Future<void>.delayed(ms10);
          return 'post $id';
        },
        placeholderData: keepPreviousData,
      );

  String describe(QueryResult<String> post) =>
      '${post.data ?? 'loading'}${post.isPlaceholderData ? ' (old)' : ''}';

  group('useQuery', () {
    Widget postScreen(int id) => HookBuilder(builder: (context) {
          // The declared type fails to compile if inference widens it.
          final QueryResult<String> result = useQuery(post(id));
          return Text(describe(result));
        });

    testWidgets('keeps one observer for a definition built in build',
        (tester) async {
      await tester.pumpWidget(app(postScreen(1)));
      expect(find.text('loading'), findsOneWidget);
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);

      // Building again with the same definition fetches nothing.
      await tester.pumpWidget(app(postScreen(1)));
      await tester.pump(ms10);
      expect(fetched, [1]);

      // A new key shows in the same frame, with the previous data.
      await tester.pumpWidget(app(postScreen(2)));
      expect(find.text('post 1 (old)'), findsOneWidget);
      await tester.pump(ms10);
      expect(find.text('post 2'), findsOneWidget);
      expect(fetched, [1, 2]);
      await tearDownApp(tester);
    });

    testWidgets('shows in the widget inspector by name', (tester) async {
      await tester.pumpWidget(app(postScreen(1)));
      final element = tester.element(find.byType(HookBuilder));
      expect(element.toDiagnosticsNode().toStringDeep(), contains('useQuery:'));
      await tester.pump(ms10);
      await tearDownApp(tester);
    });

    testWidgets('lets its query go when the widget goes away', (tester) async {
      await tester.pumpWidget(app(postScreen(1)));
      await tester.pump(ms10);
      final query = client.queryCache.find(QueryFilters(queryKey: ['post', 1]));
      expect(query!.observers, hasLength(1));

      await tester.pumpWidget(app(const SizedBox()));
      expect(query.observers, isEmpty);
      await tearDownApp(tester);
    });

    testWidgets('uses a shared observer as it is, and leaves it alone',
        (tester) async {
      final shared = post(1).observe(client: client);
      await tester.pumpWidget(
        app(HookBuilder(builder: (_) => Text(describe(useQuery(shared))))),
      );
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);

      await tester.pumpWidget(app(const SizedBox()));
      expect(shared.result.data, 'post 1');
      shared.destroy();
      await tearDownApp(tester);
    });

    testWidgets('follows a replaced provider client', (tester) async {
      final other = newClient()..setData(post(1), 'other post 1');
      await tester.pumpWidget(app(postScreen(1)));
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);

      await tester.pumpWidget(app(postScreen(1), with_: other));
      expect(find.text('other post 1'), findsOneWidget);
      await tester.pump(ms10); // the other client's data is stale
      await tearDownApp(tester);
      other.clear();
    });

    testWidgets('warns once about an observer created in build',
        (tester) async {
      final printed = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      try {
        // Fresh for good, so the new observers don't refetch after the
        // first fetch, which they would on every rebuild otherwise.
        final fresh = Query(
          queryKey: ['post', 1],
          queryFn: post(1).queryFn!,
          staleTime: infiniteDuration,
        );
        final like = Mutation(
          mutationKey: ['like'],
          mutationFn: (int id) async => id,
        );
        Widget screen() => HookBuilder(builder: (_) {
              // The mistake: new observers on every build.
              useQuery(fresh.observe(client: client));
              useMutation(like.observe(client: client));
              // Definitions built in build are fine.
              useMutation(Mutation(mutationFn: (int id) async => id));
              return const SizedBox();
            });
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
        expect(printed, [
          contains('useQuery received a new observer for the key ["post",1]'),
          contains('useMutation received a new observer for the key ["like"]'),
        ]);
        await tester.pump(ms10);
        await tearDownApp(tester);
      } finally {
        debugPrint = print;
      }
    });
  });

  testWidgets('useInfiniteQuery loads more pages', (tester) async {
    final pages = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async {
        await Future<void>.delayed(ms10);
        return 'page ${context.pageParam}';
      },
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
    );
    await tester.pumpWidget(
      app(
        HookBuilder(builder: (_) {
          final InfiniteQueryResult<String, int> feed = useInfiniteQuery(pages);
          return TextButton(
            onPressed: feed.hasNextPage ? feed.fetchNextPage : null,
            child: Text(feed.pages.join(', ')),
          );
        }),
      ),
    );
    await tester.pump(ms10);
    expect(find.text('page 1'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump(ms10);
    expect(find.text('page 1, page 2'), findsOneWidget);
    await tearDownApp(tester);
  });

  group('useMutation', () {
    testWidgets('runs from the result and rebuilds as it goes', (tester) async {
      final added = <String>[];
      final addTodo = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          added.add(title);
          return title;
        },
      );
      await tester.pumpWidget(
        app(
          HookBuilder(builder: (_) {
            final MutationResult<String, String, Object?> add =
                useMutation(addTodo);
            return TextButton(
              onPressed: () => add.mutate('Buy milk'),
              child: Text(add.status.name),
            );
          }),
        ),
      );
      expect(find.text('idle'), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.text('pending'), findsOneWidget);
      await tester.pump(ms10);
      expect(find.text('success'), findsOneWidget);
      expect(added, ['Buy milk']);
      await tearDownApp(tester);
    });

    testWidgets('drops the callbacks of its calls when it goes away',
        (tester) async {
      final events = <String>[];
      final sync = NoVariablesMutation(
        mutationFn: () => Future<void>.delayed(ms10),
      );
      await tester.pumpWidget(
        app(
          HookBuilder(builder: (_) {
            final run = useMutation(sync);
            return TextButton(
              onPressed: () => run.mutate(
                null,
                MutateOptions(onSuccess: (_, __, ___, ____) {
                  events.add('success');
                }),
              ),
              child: const Text('sync'),
            );
          }),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pump(ms10);
      expect(events, isEmpty);
      await tearDownApp(tester);
    });
  });

  testWidgets('useQueries gives the results in order, and follows the list',
      (tester) async {
    Widget posts(List<int> ids) => HookBuilder(builder: (_) {
          final List<QueryResult<String>> results =
              useQueries([for (final id in ids) post(id)]);
          return Text(results.map(describe).join(', '));
        });
    await tester.pumpWidget(app(posts([1, 2])));
    expect(find.text('loading, loading'), findsOneWidget);
    await tester.pump(ms10);
    expect(find.text('post 1, post 2'), findsOneWidget);

    // Reordered, the queries keep their data and fetch nothing.
    await tester.pumpWidget(app(posts([2, 1])));
    expect(find.text('post 2, post 1'), findsOneWidget);
    await tester.pump(ms10);
    expect(fetched, [1, 2]);
    await tearDownApp(tester);
  });

  testWidgets('useQueryClient gives the provided client', (tester) async {
    QueryClient? used;
    await tester.pumpWidget(
      app(HookBuilder(builder: (_) {
        used = useQueryClient();
        return const SizedBox();
      })),
    );
    expect(used, same(client));
    await tearDownApp(tester);
  });

  testWidgets("leaves Flutter's FocusManager to Flutter", (tester) async {
    // Imported with material, FocusManager must still mean Flutter's class,
    // the usual way to dismiss the keyboard.
    await tester.pumpWidget(app(const SizedBox()));
    expect(FocusManager.instance, same(WidgetsBinding.instance.focusManager));
    await tearDownApp(tester);
  });
}
