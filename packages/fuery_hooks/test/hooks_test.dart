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
          // Inferred without a context type, then checked: this stops
          // compiling if the hook infers a wider type.
          final result = useQuery(post(id));
          final QueryResult<String> typed = result;
          return Text(describe(typed));
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

    testWidgets('rebuilds only when the result changed', (tester) async {
      var builds = 0;
      Widget screen(int id) => HookBuilder(builder: (_) {
            builds++;
            return Text(describe(useQuery(post(id))));
          });
      await tester.pumpWidget(app(screen(1)));
      await tester.pump();
      expect(builds, 1);
      await tester.pump(ms10);
      expect(builds, 2);

      // The new key shows in the build that changed it, and the result the
      // update caused doesn't build again.
      await tester.pumpWidget(app(screen(2)));
      await tester.pump();
      expect(builds, 3);
      expect(find.text('post 1 (old)'), findsOneWidget);
      await tester.pump(ms10);
      expect(builds, 4);
      expect(find.text('post 2'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('ignores a result that arrives after its widget went away',
        (tester) async {
      Widget screen(int n) => HookBuilder(
            key: ValueKey(n),
            builder: (_) => Text(describe(useQuery(post(1)))),
          );
      await tester.pumpWidget(app(screen(1)));
      await tester.pump(ms10);

      // The new screen refetches the stale query while the old one is
      // still subscribed, and the old one is gone when the result arrives.
      await tester.pumpWidget(app(screen(2)));
      expect(tester.takeException(), isNull);
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('ignores a result that arrives after the hook was dropped',
        (tester) async {
      var builds = 0;
      // flutter_hooks disposes a trailing hook that a build no longer calls
      // while the element stays, as a hot reload can do.
      Widget screen({required bool show}) => Column(children: [
            HookBuilder(
              key: const ValueKey('refetches'),
              builder: (_) {
                if (!show) useQuery(post(1));
                return const SizedBox();
              },
            ),
            HookBuilder(
              key: const ValueKey('drops'),
              builder: (_) {
                builds++;
                if (show) useQuery(post(1));
                return const SizedBox();
              },
            ),
          ]);
      await tester.pumpWidget(app(screen(show: true)));
      await tester.pump(ms10);

      builds = 0;
      await tester.pumpWidget(app(screen(show: false)));
      await tester.pump();
      expect(builds, 1);
      await tester.pump(ms10);
      await tearDownApp(tester);
    });

    testWidgets('skips the update on a rebuild its own result caused',
        (tester) async {
      final query = _CountingQuery(
        queryKey: ['post', 1],
        queryFn: post(1).queryFn!,
      );
      await tester.pumpWidget(
        app(HookBuilder(builder: (_) => Text(describe(useQuery(query))))),
      );
      final calls = query.observer!.setOptionsCalls;
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);
      expect(query.observer!.setOptionsCalls, calls);
      await tearDownApp(tester);
    });

    testWidgets('follows a replaced client with the same definition',
        (tester) async {
      final other = newClient()..setData(post(1), 'other post 1');
      final definition = post(1);
      final screen = HookBuilder(
        builder: (_) => Text(describe(useQuery(definition))),
      );
      await tester.pumpWidget(app(screen));
      await tester.pump(ms10);
      expect(find.text('post 1'), findsOneWidget);

      await tester.pumpWidget(app(screen, with_: other));
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
          final result = useInfiniteQuery(pages);
          final InfiniteQueryResult<String, int> feed = result;
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
            final result = useMutation(addTodo);
            final MutationResult<String, String, Object?> add = result;
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
            final result = useMutation(sync);
            final MutationResult<void, void, Object?> run = result;
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
          final inferred = useQueries([for (final id in ids) post(id)]);
          final List<QueryResult<String>> results = inferred;
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

  testWidgets('hooks infer their types from observers and mixed lists',
      (tester) async {
    final shared = post(2).observe(client: client);
    final pages = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async => 'page ${context.pageParam}',
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    ).observe(client: client);
    final rename = Mutation(
      mutationFn: (String name) async => name.length,
      onMutate: (_, client) => ['renaming'],
    );
    await tester.pumpWidget(
      app(HookBuilder(builder: (_) {
        // Each is inferred without a context type, then checked.
        final posts = useQueries([post(1), shared]);
        final List<QueryResult<String>> typedPosts = posts;
        final feed = useInfiniteQuery(pages);
        final InfiniteQueryResult<String, int> typedFeed = feed;
        final renaming = useMutation(rename);
        final MutationResult<int, String, List<String>> typedRenaming =
            renaming;
        return Text(
          '${typedPosts.length} ${typedFeed.pages.length} '
          '${typedRenaming.status.name}',
        );
      })),
    );
    await tester.pump(ms10);
    expect(find.text('2 1 idle'), findsOneWidget);
    await tearDownApp(tester);
    shared.destroy();
    pages.destroy();
  });

  testWidgets('useQueryClient gives the provided client, and follows it',
      (tester) async {
    final other = newClient();
    QueryClient? used;
    // The same widget, so only the provider can rebuild it.
    final screen = HookBuilder(builder: (_) {
      used = useQueryClient();
      return const SizedBox();
    });
    await tester.pumpWidget(app(screen));
    expect(used, same(client));

    await tester.pumpWidget(app(screen, with_: other));
    expect(used, same(other));
    await tearDownApp(tester);
    other.clear();
  });

  testWidgets("leaves Flutter's FocusManager to Flutter", (tester) async {
    // Imported with material, FocusManager must still mean Flutter's class,
    // the usual way to dismiss the keyboard.
    await tester.pumpWidget(app(const SizedBox()));
    expect(FocusManager.instance, same(WidgetsBinding.instance.focusManager));
    await tearDownApp(tester);
  });
}

/// A query that keeps the observer it creates, to count its option updates.
class _CountingQuery extends Query<String> {
  _CountingQuery({required super.queryKey, required super.queryFn});

  _CountingObserver? observer;

  @override
  QueryObserver<String> observe({QueryClient? client}) {
    return observer = _CountingObserver(client ?? Fuery.client, this);
  }
}

class _CountingObserver extends QueryObserver<String> {
  _CountingObserver(super.client, super.options);

  int setOptionsCalls = 0;

  @override
  void setOptions(Query<String> options) {
    setOptionsCalls++;
    super.setOptions(options);
  }
}
