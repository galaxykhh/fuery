// The hooks render through the same slots as the widgets of `fuery`, so
// these tests follow the widget tests: first frames, rebuilds with new
// definitions, a replaced client, and disposal.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  /// Runs [body] and returns what it printed with `debugPrint`.
  Future<List<String>> printsOf(Future<void> Function() body) async {
    final printed = <String>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    try {
      await body();
    } finally {
      debugPrint = print;
    }
    return printed;
  }

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
      // Fresh for good, so the new observers don't refetch after the first
      // fetch, which they would on every rebuild otherwise.
      Query<String> freshPost(int id) => Query(
            queryKey: ['post', id],
            queryFn: post(id).queryFn!,
            staleTime: infiniteDuration,
          );
      final fresh = freshPost(1);
      // The same key as the query, which gets a warning of its own.
      final like = Mutation(
        mutationKey: ['post', 1],
        mutationFn: (int id) async => id,
      );
      // Observers created once, each of its own key.
      final shared = [
        for (final id in [2, 3, 4]) freshPost(id).observe(client: client),
      ];
      var builds = 0;
      Widget screen() => HookBuilder(builder: (_) {
            builds++;
            // The mistake: new observers on every build.
            useQuery(fresh.observe(client: client));
            useMutation(like.observe(client: client));
            // Definitions built in build are fine.
            useMutation(Mutation(mutationFn: (int id) async => id));
            // So is a switch to an observer of another key, or from a
            // definition to an observer of its key.
            useQuery(builds.isEven ? shared[0] : shared[1]);
            useQuery(builds == 1 ? freshPost(4) : shared[2]);
            return const SizedBox();
          });
      final printed = await printsOf(() async {
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
      });
      expect(printed, [
        allOf(
          contains('useQuery received a new observer for the key ["post",1]'),
          contains('refetches'),
          contains('useQuery(todosQuery)'),
        ),
        allOf(
          contains('useMutation received a new observer for the key '
              '["post",1]'),
          contains('starts idle'),
          contains('useMutation(addTodoMutation)'),
          isNot(contains('refetches')),
          isNot(contains('todosQuery')),
        ),
      ]);
      await tester.pump(ms10);
      await tearDownApp(tester);
      for (final observer in shared) {
        observer.destroy();
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

    testWidgets('leaves the callbacks of a shared observer to run',
        (tester) async {
      final events = <String>[];
      final shared = NoVariablesMutation(
        mutationFn: () => Future<void>.delayed(ms10),
      ).observe(client: client);
      await tester.pumpWidget(
        app(
          HookBuilder(builder: (_) {
            final run = useMutation(shared);
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
      expect(events, ['success']);
      shared.reset();
      await tearDownApp(tester);
    });
  });

  testWidgets('a memoized watch stream rebuilds only when its value changes',
      (tester) async {
    var builds = 0;
    final seen = <bool?>[];
    await tester.pumpWidget(
      app(HookBuilder(builder: (_) {
        builds++;
        // As the hooks guide shows it.
        final client = useQueryClient();
        final fetching = useStream(
          useMemoized(
            () => client.watch((client) => client.isFetching() > 0),
            [client],
          ),
        );
        seen.add(fetching.data);
        return const SizedBox();
      })),
    );
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The first build, then the first value.
    expect(builds, 2);
    expect(seen, [null, false]);

    // The stream delivers the change in a microtask, and the next frame
    // shows it.
    final done = client.query(post(1));
    await tester.pump();
    await tester.pump();
    expect(seen.last, isTrue);
    await tester.pump(ms10);
    expect(seen.last, isFalse);
    expect(await done, 'post 1');
    await tearDownApp(tester);
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

  testWidgets('useQueries warns once about observers created in build',
      (tester) async {
    Query<String> fresh(int id) => Query(
          queryKey: ['post', id],
          queryFn: post(id).queryFn!,
          staleTime: infiniteDuration,
        );
    final shared = [
      fresh(1).observe(client: client),
      fresh(2).observe(client: client),
    ];
    final added = fresh(3).observe(client: client);
    var builds = 0;
    Widget screen() => HookBuilder(builder: (_) {
          builds++;
          // The mistake: new observers on every build.
          useQueries([
            for (final id in [1, 2]) fresh(id).observe(client: client)
          ]);
          // Observers created once, in a new list that is reordered on
          // every build, and definitions are fine.
          useQueries(builds.isEven ? [shared[1], shared[0]] : [...shared]);
          useQueries([
            for (final id in [1, 2]) fresh(id)
          ]);
          // So is an observer created once, added for a new key.
          useQueries([...shared, if (builds > 1) added]);
          return const SizedBox();
        });
    final printed = await printsOf(() async {
      await tester.pumpWidget(app(screen()));
      await tester.pumpWidget(app(screen()));
      await tester.pumpWidget(app(screen()));
    });
    expect(printed, [
      allOf(
        contains('useQueries received a new observer for the key ["post",1]'),
        contains('useQueries([for (final id in ids) todoQuery(id)])'),
      ),
    ]);
    await tester.pump(ms10);
    await tearDownApp(tester);
    for (final observer in [...shared, added]) {
      observer.destroy();
    }
  });

  group('an observer of another client', () {
    const warning = 'received an observer of another QueryClient';

    testWidgets('warns once for each hook given one', (tester) async {
      final other = newClient();
      final otherPost = post(1).observe(client: other);
      final otherLike =
          Mutation(mutationFn: (int id) async => id).observe(client: other);
      final otherPosts = [post(2).observe(client: other)];
      final own = post(3).observe(client: client);
      Widget screen() => HookBuilder(builder: (_) {
            useQuery(otherPost);
            useMutation(otherLike);
            // A new list on every build, with the same foreign observer.
            useQueries([post(4), ...otherPosts]);
            // Observers of the provided client, and definitions, are fine.
            useQuery(own);
            useQuery(post(5));
            useMutation(Mutation(mutationFn: (int id) async => id));
            return const SizedBox();
          });
      final printed = await printsOf(() async {
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
      });
      expect(printed, [
        allOf(
          contains('useQuery $warning'),
          contains('useQuery(todosQuery)'),
          contains('the client useQueryClient() returns'),
          contains('#a-screen-reads-another-clients-cache'),
        ),
        allOf(
          contains('useMutation $warning'),
          contains('useMutation(addTodoMutation)'),
        ),
        contains('useQueries $warning'),
      ]);
      await tester.pump(ms10);
      await tearDownApp(tester);
      for (final observer in [otherPost, ...otherPosts, own]) {
        observer.destroy();
      }
      otherLike.reset();
      other.clear();
    });

    testWidgets('warns once per hook and key about observers created in build',
        (tester) async {
      final other = newClient();
      Query<String> fresh(int id) => Query(
            queryKey: ['post', id],
            queryFn: post(id).queryFn!,
            staleTime: infiniteDuration,
          );
      Widget screen() => HookBuilder(builder: (_) {
            // The mistake: observers of another client, created in build.
            useQuery(fresh(1).observe(client: other));
            useQueries([
              for (final id in [2, 3]) fresh(id).observe(client: other),
            ]);
            useMutation(
              Mutation(
                mutationKey: ['like'],
                mutationFn: (int id) async => id,
              ).observe(client: other),
            );
            useMutation(
              Mutation(mutationFn: (int id) async => id).observe(client: other),
            );
            return const SizedBox();
          });
      final printed = await printsOf(() async {
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
        await tester.pumpWidget(app(screen()));
      });
      expect(
        [
          for (final message in printed)
            if (message.contains(warning)) message,
        ],
        [
          contains('useQuery $warning'),
          contains('useQueries $warning'),
          contains('useQueries $warning'),
          contains('useMutation $warning'),
          contains('useMutation $warning'),
        ],
        reason: 'once per hook and key, or per hook without a key',
      );
      await tester.pump(ms10);
      await tearDownApp(tester);
      other.clear();
    });

    testWidgets('new observers of a replaced client are silent',
        (tester) async {
      final other = newClient();
      final like = Mutation(
        mutationKey: ['like'],
        mutationFn: (int id) async => id,
      );
      final screen = HookBuilder(builder: (_) {
        // Observers created again for a replaced client, as they should be.
        final client = useQueryClient();
        useQuery(useMemoized(() => post(1).observe(client: client), [client]));
        useMutation(useMemoized(() => like.observe(client: client), [client]));
        useQueries(
          useMemoized(
            () => [
              for (final id in [2, 3]) post(id).observe(client: client),
            ],
            [client],
          ),
        );
        return const SizedBox();
      });
      final printed = await printsOf(() async {
        await tester.pumpWidget(app(screen));
        await tester.pump(ms10);
        await tester.pumpWidget(app(screen, with_: other));
        await tester.pump(ms10);
      });
      expect(printed, isEmpty);
      await tearDownApp(tester);
      other.clear();
    });

    testWidgets('warns when the provided client is replaced', (tester) async {
      final shared = post(1).observe(client: client);
      final other = newClient();
      final screen = HookBuilder(
        builder: (_) => Text(describe(useQuery(shared))),
      );
      final printed = await printsOf(() async {
        await tester.pumpWidget(app(screen));
        await tester.pump(ms10);
        expect(find.text('post 1'), findsOneWidget);
        await tester.pumpWidget(app(screen, with_: other));
      });
      expect(printed, [contains('useQuery $warning')]);
      // The observer keeps its own client.
      expect(find.text('post 1'), findsOneWidget);
      await tearDownApp(tester);
      shared.destroy();
      other.clear();
    });
  });

  group('listener', () {
    // Fresh for good, so cached data isn't refetched.
    Query<String> fresh(int id) => Query(
          queryKey: ['post', id],
          queryFn: post(id).queryFn!,
          staleTime: infiniteDuration,
        );

    testWidgets('hears later changes, not the result at mount', (tester) async {
      client.setData(post(1), 'cached');
      final heard = <String>[];
      final compared = <String>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useQuery(
          post(1),
          listenWhen: (previous, current) {
            compared.add('${previous.data} > ${current.data}');
            return current.data != 'skipped';
          },
          listener: (context, result) => heard.add(describe(result)),
        );
        return const SizedBox();
      })));
      // The cached data is stale, so it refetches: the start of that fetch
      // is the result at mount.
      await tester.pump();
      expect(compared, isEmpty);

      await tester.pump(ms10);
      expect(heard, ['post 1']);

      // listenWhen compares with the last result received, also after it
      // said no.
      client.setData(post(1), 'skipped');
      await tester.pump();
      client.setData(post(1), 'shown');
      await tester.pump();
      expect(
          compared, ['cached > post 1', 'post 1 > skipped', 'skipped > shown']);
      expect(heard, ['post 1', 'shown']);
      await tearDownApp(tester);
    });

    testWidgets('runs outside build, with the context of the widget',
        (tester) async {
      final phases = <SchedulerPhase>[];
      BuildContext? built;
      BuildContext? given;
      await tester.pumpWidget(app(Scaffold(
        body: HookBuilder(builder: (context) {
          built = context;
          useQuery(
            post(1),
            listener: (context, result) {
              phases.add(SchedulerBinding.instance.schedulerPhase);
              given = context;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('heard ${result.data}')),
              );
            },
          );
          return const SizedBox();
        }),
      )));
      await tester.pump(ms10);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('heard post 1'), findsOneWidget);
      expect(phases, [isNot(SchedulerPhase.persistentCallbacks)]);
      expect(given, same(built));
      await tearDownApp(tester);
    });

    testWidgets('hears a new key after the frame that shows it',
        (tester) async {
      var building = false;
      final heard = <String>[];
      Widget screen(int id) => HookBuilder(builder: (_) {
            building = true;
            final shown = useQuery(
              post(id),
              listener: (context, result) {
                heard.add('${describe(result)}${building ? ' in build' : ''}');
              },
            );
            building = false;
            return Text(describe(shown));
          });
      await tester.pumpWidget(app(screen(1)));
      await tester.pump(ms10);
      expect(heard, ['post 1']);

      await tester.pumpWidget(app(screen(2)));
      expect(find.text('post 1 (old)'), findsOneWidget);
      expect(heard, ['post 1', 'post 1 (old)']);
      await tester.pump(ms10);
      expect(heard, ['post 1', 'post 1 (old)', 'post 2']);
      await tearDownApp(tester);
    });

    testWidgets('does not hear a move to another observer', (tester) async {
      final other = newClient()..setData(fresh(1), 'other post 1');
      client.setData(fresh(1), 'post 1');
      client.setData(fresh(2), 'post 2');
      client.setData(fresh(3), 'post 3');
      final shared = [
        for (final id in [2, 3]) fresh(id).observe(client: client),
      ];
      final heard = <String>[];
      Widget screen(QuerySource<String> source) => HookBuilder(builder: (_) {
            useQuery(
              source,
              listener: (context, result) => heard.add(describe(result)),
            );
            return const SizedBox();
          });

      // A replaced provider client.
      await tester.pumpWidget(app(screen(fresh(1))));
      await tester.pumpWidget(app(screen(fresh(1)), with_: other));
      await tester.pump();
      expect(heard, isEmpty);
      other.setData(fresh(1), 'other post 1!');
      await tester.pump();
      expect(heard, ['other post 1!']);

      // Another shared observer.
      await tester.pumpWidget(app(screen(shared[0])));
      await tester.pumpWidget(app(screen(shared[1])));
      await tester.pump();
      expect(heard, ['other post 1!']);
      client.setData(fresh(3), 'post 3!');
      await tester.pump();
      expect(heard, ['other post 1!', 'post 3!']);
      await tearDownApp(tester);
      for (final observer in shared) {
        observer.destroy();
      }
      other.clear();
    });

    testWidgets('calls the listener of the latest build', (tester) async {
      client.setData(fresh(1), 'post 1');
      var builds = 0;
      final heard = <int>[];
      Widget screen() => HookBuilder(builder: (_) {
            final build = ++builds;
            useQuery(fresh(1), listener: (context, result) => heard.add(build));
            return const SizedBox();
          });
      await tester.pumpWidget(app(screen()));
      final query = client.queryCache.find(QueryFilters(queryKey: ['post', 1]));
      final observer = query!.observers.single;
      await tester.pumpWidget(app(screen()));

      client.setData(fresh(1), 'post 1!');
      await tester.pump();
      expect(heard, [2]);
      expect(query.observers.single, same(observer));
      await tearDownApp(tester);
    });

    testWidgets(
        'starts with the first build that passes one, and skips '
        'builds without one', (tester) async {
      client.setData(fresh(1), 'a');
      final heard = <String>[];
      Widget screen({required bool listen}) => HookBuilder(builder: (_) {
            useQuery(
              fresh(1),
              listenWhen: listen
                  ? (previous, current) {
                      heard.add('${previous.data} > ${current.data}');
                      return true;
                    }
                  : null,
              listener: listen ? (context, result) {} : null,
            );
            return const SizedBox();
          });
      await tester.pumpWidget(app(screen(listen: false)));
      client.setData(fresh(1), 'b');
      await tester.pump();

      await tester.pumpWidget(app(screen(listen: true)));
      client.setData(fresh(1), 'c');
      await tester.pump();
      expect(heard, ['b > c']);

      await tester.pumpWidget(app(screen(listen: false)));
      client.setData(fresh(1), 'd');
      await tester.pump();
      await tester.pumpWidget(app(screen(listen: true)));
      client.setData(fresh(1), 'e');
      await tester.pump();
      expect(heard, ['b > c', 'd > e']);
      await tearDownApp(tester);
    });

    testWidgets('hears nothing after the widget or the hook goes away',
        (tester) async {
      final heard = <String>[];
      void listener(BuildContext context, QueryResult<String> result) {
        heard.add(describe(result));
      }

      // A fetch in flight when the widget goes away.
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useQuery(post(1), listener: listener);
        return const SizedBox();
      })));
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pump(ms10);
      expect(heard, isEmpty);

      // flutter_hooks disposes a trailing hook that a build no longer calls
      // while the element stays, as a hot reload can do. The other widget
      // refetches the stale query in the same frame.
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
                if (show) useQuery(post(1), listener: listener);
                return const SizedBox();
              },
            ),
          ]);
      await tester.pumpWidget(app(screen(show: true)));
      await tester.pump(ms10);
      expect(heard, ['post 1']);
      await tester.pumpWidget(app(screen(show: false)));
      await tester.pump(ms10);
      expect(heard, ['post 1']);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });

    testWidgets('useMutation hears the runs of its result', (tester) async {
      final addTodo = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
      );
      final heard = <MutationStatus>[];
      final screen = HookBuilder(builder: (_) {
        final add = useMutation(
          addTodo,
          listener: (context, result) => heard.add(result.status),
        );
        return TextButton(
          onPressed: () => add.mutate('Buy milk'),
          child: Text(add.status.name),
        );
      });
      await tester.pumpWidget(app(screen));
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(heard, [MutationStatus.pending]);
      await tester.pump(ms10);
      expect(heard, [MutationStatus.pending, MutationStatus.success]);

      // Nothing after the widget goes away mid-run.
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pump(ms10);
      expect(heard, [
        MutationStatus.pending,
        MutationStatus.success,
        MutationStatus.pending,
      ]);
      await tearDownApp(tester);
    });

    testWidgets('useMutation hears every run of a shared observer',
        (tester) async {
      final shared = Mutation(
        mutationFn: (String title) async => title,
      ).observe(client: client);
      final heard = <String>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useMutation(
          shared,
          listenWhen: (previous, current) => current.isSuccess,
          listener: (context, result) => heard.add(result.data!),
        );
        return const SizedBox();
      })));

      shared.mutate('from elsewhere');
      await tester.pump();
      expect(heard, ['from elsewhere']);
      await tearDownApp(tester);
      shared.reset();
    });

    testWidgets('useMutation hears a NoVariablesMutation', (tester) async {
      final logout = NoVariablesMutation(mutationFn: () async {});
      final heard = <MutationStatus>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final run = useMutation(
          logout,
          listener: (context, result) => heard.add(result.status),
        );
        return TextButton(
          onPressed: () => run.mutate(null),
          child: const Text('Log out'),
        );
      })));
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(heard, [MutationStatus.pending, MutationStatus.success]);
      await tearDownApp(tester);
    });

    testWidgets('useInfiniteQuery hears new pages', (tester) async {
      final pages = InfiniteQuery(
        queryKey: ['pages'],
        queryFn: (context) async => 'page ${context.pageParam}',
        initialPageParam: 1,
        getNextPageParam: (data) => data.lastPageParam + 1,
      );
      final heard = <int>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final feed = useInfiniteQuery(
          pages,
          listenWhen: (previous, current) =>
              previous.pages.length != current.pages.length,
          listener: (context, result) => heard.add(result.pages.length),
        );
        return TextButton(
          onPressed: feed.fetchNextPage,
          child: Text('${feed.pages.length} pages'),
        );
      })));
      await tester.pump();
      expect(heard, [1]);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(heard, [1, 2]);
      expect(find.text('2 pages'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('a listener that throws is reported, and the widget rebuilds',
        (tester) async {
      final errors = <Object>[];
      client = QueryClient(
        defaultOptions: const DefaultOptions(
          queries: QueryDefaults(retry: RetryPolicy.never()),
        ),
        onUncaughtError: (error, _) => errors.add(error),
      );
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final result = useQuery(
          post(1),
          listener: (context, result) => throw StateError('listener'),
        );
        return Text(describe(result));
      })));
      await tester.pump(ms10);

      expect(find.text('post 1'), findsOneWidget);
      expect(errors, [isA<StateError>()]);
      await tearDownApp(tester);
    });

    testWidgets('adds no builds', (tester) async {
      var withListener = 0;
      var without = 0;
      await tester.pumpWidget(app(Column(children: [
        HookBuilder(builder: (_) {
          withListener++;
          useQuery(post(1), listener: (context, result) {});
          return const SizedBox();
        }),
        HookBuilder(builder: (_) {
          without++;
          useQuery(post(1));
          return const SizedBox();
        }),
      ])));
      await tester.pump(ms10);
      client.setData(post(1), 'edited');
      await tester.pump(Duration.zero);

      // The first frame, the data, and the edit.
      expect(without, 3);
      expect(withListener, without);
      await tearDownApp(tester);
    });

    testWidgets('listenWhen needs a listener', (tester) async {
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useQuery(post(1), listenWhen: (previous, current) => true);
        return const SizedBox();
      })));
      expect(tester.takeException(), isA<AssertionError>());
      await tearDownApp(tester);
    });
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
    final heard = <Object?>[];
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

        // Listener closures get the result type of their hook.
        final one = useQuery(
          post(1),
          listenWhen: (previous, current) {
            final QueryResult<String> typedPrevious = previous;
            return typedPrevious.data != current.data;
          },
          listener: (context, result) {
            final QueryResult<String> typed = result;
            heard.add(typed.data);
          },
        );
        final QueryResult<String> typedOne = one;
        final listenedFeed = useInfiniteQuery(
          pages,
          listenWhen: (previous, current) {
            final InfiniteQueryResult<String, int> typedPrevious = previous;
            return typedPrevious.pages.length != current.pages.length;
          },
          listener: (context, result) {
            final InfiniteQueryResult<String, int> typed = result;
            heard.add(typed.pages.length);
          },
        );
        final InfiniteQueryResult<String, int> typedListenedFeed = listenedFeed;
        final listenedRenaming = useMutation(
          rename,
          listenWhen: (previous, current) {
            final MutationResult<int, String, List<String>> typedPrevious =
                previous;
            return typedPrevious.status != current.status;
          },
          listener: (context, result) {
            final MutationResult<int, String, List<String>> typed = result;
            heard.add(typed.data);
          },
        );
        final MutationResult<int, String, List<String>> typedListenedRenaming =
            listenedRenaming;

        // A listener for any query still leaves the data type to the query.
        final two = useQuery(post(2), listener: _recordAnyQuery);
        final QueryResult<String> typedTwo = two;
        return Text(
          '${typedPosts.length} ${typedFeed.pages.length} '
          '${typedRenaming.status.name} ${typedOne.data} '
          '${typedListenedFeed.pages.length} '
          '${typedListenedRenaming.status.name} ${typedTwo.data}',
        );
      })),
    );
    await tester.pump(ms10);
    expect(find.text('2 1 idle post 1 1 idle post 2'), findsOneWidget);
    expect(heard, [1, 'post 1']);
    expect(_anyQueryData, ['post 2']);
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

final _anyQueryData = <Object?>[];

/// A listener for a query of any data type, as a widget and a hook can
/// share.
void _recordAnyQuery(BuildContext context, QueryResult<Object> result) {
  _anyQueryData.add(result.data);
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
