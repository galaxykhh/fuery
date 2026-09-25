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

  /// Saves a todo after [ms10]. A title that starts with 'fail' fails.
  Mutation<String, String, Object?> addTodo([String list = 'home']) => Mutation(
        mutationKey: ['todos', list, 'add'],
        mutationFn: (title) async {
          await Future<void>.delayed(ms10);
          if (title.startsWith('fail')) throw StateError(title);
          return 'saved $title';
        },
      );

  String describeRuns(List<MutationState<String, String, Object?>> runs) {
    if (runs.isEmpty) return 'no runs';
    return [for (final run in runs) '${run.variables} ${run.status.name}']
        .join(', ');
  }

  /// Starts a run of [addTodo] from an observer of its own.
  void run(String title, {String list = 'home', QueryClient? on}) {
    addTodo(list).observe(client: on ?? client).mutate(title);
  }

  /// A button that runs [addTodo] with a useMutation of its own.
  Widget addButton(String title) => HookBuilder(builder: (_) {
        final add = useMutation(addTodo());
        return TextButton(
          onPressed: () => add.mutate(title),
          child: Text('add $title'),
        );
      });

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

  group('useOnQueryChange', () {
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
        useOnQueryChange(
          useQuery(post(1)),
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
          useOnQueryChange(
            useQuery(post(1)),
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
            final shown = useQuery(post(id));
            useOnQueryChange(
              shown,
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
            useOnQueryChange(
              useQuery(source),
              listener: (context, result) => heard.add(describe(result)),
            );
            return const SizedBox();
          });

      // A replaced provider client: the result comes from a new observer.
      await tester.pumpWidget(app(screen(fresh(1))));
      await tester.pumpWidget(app(screen(fresh(1)), with_: other));
      await tester.pump();
      expect(heard, isEmpty);
      other.setData(fresh(1), 'other post 1!');
      await tester.pump();
      expect(heard, ['other post 1!']);

      // A definition replaced by a shared observer, then by another one.
      await tester.pumpWidget(app(screen(shared[0])));
      await tester.pumpWidget(app(screen(shared[1])));
      await tester.pump();
      expect(heard, ['other post 1!']);
      client.setData(fresh(2), 'post 2!');
      client.setData(fresh(3), 'post 3!');
      await tester.pump();
      expect(heard, ['other post 1!', 'post 3!']);
      await tearDownApp(tester);
      for (final observer in shared) {
        observer.destroy();
      }
      other.clear();
    });

    testWidgets('moves between a query and an infinite query without a call',
        (tester) async {
      client.setData(fresh(1), 'post 1');
      final feed = InfiniteQuery(
        queryKey: ['feed'],
        queryFn: (context) async => 'page ${context.pageParam}',
        initialPageParam: 1,
        getNextPageParam: (data) => null,
        staleTime: infiniteDuration,
      );
      client.setData(feed, const InfiniteData(pages: ['a'], pageParams: [1]));
      final heard = <QueryResult<Object>>[];
      Widget screen({required bool pages}) => HookBuilder(builder: (_) {
            final shownPost = useQuery(fresh(1));
            final shownFeed = useInfiniteQuery(feed);
            // One of two kinds, so the type is declared.
            final QueryResult<Object> shown = pages ? shownFeed : shownPost;
            useOnQueryChange(
              shown,
              listener: (context, result) => heard.add(result),
            );
            return const SizedBox();
          });
      await tester.pumpWidget(app(screen(pages: true)));
      client.setData(feed, const InfiniteData(pages: ['b'], pageParams: [1]));
      await tester.pump();
      expect(heard.single, isA<InfiniteQueryResult<String, int>>());

      await tester.pumpWidget(app(screen(pages: false)));
      await tester.pump();
      client.setData(feed, const InfiniteData(pages: ['c'], pageParams: [1]));
      client.setData(fresh(1), 'post 1!');
      await tester.pump();
      expect(heard, hasLength(2));
      expect(heard.last.data, 'post 1!');

      await tester.pumpWidget(app(screen(pages: true)));
      await tester.pump();
      client.setData(fresh(1), 'post 1!!');
      client.setData(feed, const InfiniteData(pages: ['d'], pageParams: [1]));
      await tester.pump();
      expect(heard, hasLength(3));
      expect(heard.last, isA<InfiniteQueryResult<String, int>>());
      await tearDownApp(tester);
    });

    testWidgets('calls the listener of the latest build', (tester) async {
      client.setData(fresh(1), 'post 1');
      var builds = 0;
      final heard = <String>[];
      Widget screen() => HookBuilder(builder: (_) {
            final build = ++builds;
            useOnQueryChange(
              useQuery(fresh(1)),
              listenWhen: (previous, current) {
                heard.add('listenWhen of build $build');
                return true;
              },
              listener: (context, result) {
                heard.add('listener of build $build');
              },
            );
            return const SizedBox();
          });
      await tester.pumpWidget(app(screen()));
      final query = client.queryCache.find(QueryFilters(queryKey: ['post', 1]));
      final observer = query!.observers.single;
      await tester.pumpWidget(app(screen()));

      client.setData(fresh(1), 'post 1!');
      await tester.pump();
      expect(heard, ['listenWhen of build 2', 'listener of build 2']);
      expect(query.observers.single, same(observer));
      await tearDownApp(tester);
    });

    testWidgets('starts from the result of the build that first calls it',
        (tester) async {
      client.setData(fresh(1), 'a');
      final heard = <String>[];
      Widget screen({required bool listen}) => HookBuilder(builder: (_) {
            final result = useQuery(fresh(1));
            // A trailing hook, which flutter_hooks adds and drops as a hot
            // reload can.
            if (listen) {
              useOnQueryChange(
                result,
                listenWhen: (previous, current) {
                  heard.add('${previous.data} > ${current.data}');
                  return true;
                },
                listener: (context, result) {},
              );
            }
            return const SizedBox();
          });
      await tester.pumpWidget(app(screen(listen: false)));
      client.setData(fresh(1), 'b');
      await tester.pump();

      await tester.pumpWidget(app(screen(listen: true)));
      client.setData(fresh(1), 'c');
      await tester.pump();
      expect(heard, ['b > c']);

      // Dropped, it hears nothing. Called again, it starts over.
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
        useOnQueryChange(useQuery(post(1)), listener: listener);
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
                final result = useQuery(post(1));
                if (show) useOnQueryChange(result, listener: listener);
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

    testWidgets('leaves a shared observer to the code that shares it',
        (tester) async {
      client.setData(fresh(1), 'post 1');
      final shared = fresh(1).observe(client: client);
      final outside = <String?>[];
      final stop = shared.subscribe((result) => outside.add(result.data));
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useOnQueryChange(useQuery(shared), listener: (context, result) {});
        return const SizedBox();
      })));
      await tester.pumpWidget(app(const SizedBox()));

      // Destroying the observer would have removed this listener too.
      client.setData(fresh(1), 'still heard');
      await tester.pump();
      expect(outside.last, 'still heard');
      stop();
      await tearDownApp(tester);
    });

    testWidgets('hears new pages of useInfiniteQuery', (tester) async {
      final pages = InfiniteQuery(
        queryKey: ['pages'],
        queryFn: (context) async => 'page ${context.pageParam}',
        initialPageParam: 1,
        getNextPageParam: (data) => data.lastPageParam + 1,
      );
      final heard = <int>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final feed = useInfiniteQuery(pages);
        useOnQueryChange(
          feed,
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
        final result = useQuery(post(1));
        useOnQueryChange(
          result,
          listener: (context, result) => throw StateError('listener'),
        );
        return Text(describe(result));
      })));
      await tester.pump(ms10);

      expect(find.text('post 1'), findsOneWidget);
      expect(errors, [isA<StateError>()]);
      await tearDownApp(tester);
    });

    testWidgets('adds no builds and no observer', (tester) async {
      var withListener = 0;
      var without = 0;
      await tester.pumpWidget(app(Column(children: [
        HookBuilder(builder: (_) {
          withListener++;
          useOnQueryChange(useQuery(post(1)), listener: (context, result) {});
          return const SizedBox();
        }),
        HookBuilder(builder: (_) {
          without++;
          useQuery(post(1));
          return const SizedBox();
        }),
      ])));
      final query = client.queryCache.find(QueryFilters(queryKey: ['post', 1]));
      expect(query!.observers, hasLength(2));
      await tester.pump(ms10);
      client.setData(post(1), 'edited');
      await tester.pump(Duration.zero);

      // The first frame, the data, and the edit.
      expect(without, 3);
      expect(withListener, without);
      await tearDownApp(tester);
    });

    testWidgets('calls nothing for a result that no observer reported',
        (tester) async {
      // Made up, as a test of a view that takes a result would pass it.
      const handMade = QueryResult<String>(
        status: QueryStatus.success,
        fetchStatus: FetchStatus.idle,
        data: 'made up',
        dataUpdatedAt: 0,
        error: null,
        errorUpdatedAt: 0,
        errorUpdateCount: 0,
        failureCount: 0,
        failureReason: null,
        isFetched: true,
        isFetchedAfterMount: true,
        isPlaceholderData: false,
        isStale: false,
        isEnabled: true,
      );
      client.setData(fresh(1), 'post 1');
      final heard = <String>[];
      // The view listens to the result it is given.
      Widget view(QueryResult<String> shown) => HookBuilder(builder: (_) {
            useOnQueryChange(
              shown,
              listener: (context, result) => heard.add(describe(result)),
            );
            return Text(describe(shown));
          });
      Widget screen({required bool madeUp}) => HookBuilder(builder: (_) {
            final result = useQuery(fresh(1));
            return view(madeUp ? handMade : result);
          });
      await tester.pumpWidget(app(screen(madeUp: true)));
      client.setData(fresh(1), 'post 1!');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('made up'), findsOneWidget);
      expect(heard, isEmpty);

      // A reported result starts listening, without a call for itself.
      await tester.pumpWidget(app(screen(madeUp: false)));
      await tester.pump();
      expect(heard, isEmpty);
      client.setData(fresh(1), 'post 1!!');
      await tester.pump();
      expect(heard, ['post 1!!']);

      // A made-up one again stops it.
      await tester.pumpWidget(app(screen(madeUp: true)));
      client.setData(fresh(1), 'post 1!!!');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(heard, ['post 1!!']);
      await tearDownApp(tester);
    });
  });

  group('useOnMutationChange', () {
    testWidgets('hears the runs of the result it gets', (tester) async {
      final heard = <MutationStatus>[];
      final screen = HookBuilder(builder: (_) {
        final add = useMutation(addTodo());
        useOnMutationChange(
          add,
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

    testWidgets('hears every run of a shared observer, and leaves it alone',
        (tester) async {
      final shared = Mutation(
        mutationFn: (String title) async => title,
      ).observe(client: client);
      final heard = <String>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useOnMutationChange(
          useMutation(shared),
          listenWhen: (previous, current) => current.isSuccess,
          listener: (context, result) => heard.add(result.data!),
        );
        return const SizedBox();
      })));

      shared.mutate('from elsewhere');
      await tester.pump();
      expect(heard, ['from elsewhere']);

      // Resetting the observer would have dropped the state of its run.
      await tester.pumpWidget(app(const SizedBox()));
      expect(shared.result.data, 'from elsewhere');
      await tearDownApp(tester);
      shared.reset();
    });

    testWidgets('moves with the result to a new observer without a call',
        (tester) async {
      final other = newClient();
      final heard = <String>[];
      Widget screen() => HookBuilder(builder: (_) {
            final add = useMutation(addTodo());
            useOnMutationChange(
              add,
              listener: (context, result) {
                heard.add('${result.variables} ${result.status.name}');
              },
            );
            return TextButton(
              onPressed: () => add.mutate('milk'),
              child: const Text('add'),
            );
          });
      await tester.pumpWidget(app(screen()));
      await tester.tap(find.text('add'));
      await tester.pump();
      expect(heard, ['milk pending']);

      // The replaced client gives the hook a new, idle observer.
      await tester.pumpWidget(app(screen(), with_: other));
      await tester.pump(ms10);
      expect(heard, ['milk pending']);

      await tester.tap(find.text('add'));
      await tester.pump(ms10);
      expect(heard, ['milk pending', 'milk pending', 'milk success']);
      await tester.pumpWidget(const SizedBox());
      other.clear();
      await tearDownApp(tester);
    });

    testWidgets('hears a NoVariablesMutation', (tester) async {
      final logout = NoVariablesMutation(mutationFn: () async {});
      final heard = <MutationStatus>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final run = useMutation(logout);
        useOnMutationChange(
          run,
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
  });

  group('useMutationState', () {
    Widget runsOf(String list, {void Function()? onBuild}) {
      return HookBuilder(builder: (_) {
        onBuild?.call();
        // Inferred without a context type, then checked.
        final runs = useMutationState(addTodo(list));
        final List<MutationState<String, String, Object?>> typed = runs;
        return Text(describeRuns(typed));
      });
    }

    testWidgets('shows the runs a useMutation in another widget starts',
        (tester) async {
      var builds = 0;
      await tester.pumpWidget(app(Column(children: [
        addButton('milk'),
        runsOf('home', onBuild: () => builds++),
      ])));
      expect(find.text('no runs'), findsOneWidget);

      await tester.tap(find.text('add milk'));
      await tester.pump();
      expect(find.text('milk pending'), findsOneWidget);
      await tester.pump(ms10);
      expect(find.text('milk success'), findsOneWidget);
      expect(builds, 3);

      // A run of another key changes nothing it shows.
      run('report', list: 'work');
      await tester.pump(Duration.zero);
      await tester.pump(ms10);
      expect(builds, 3);
      expect(
        tester
            .element(find.byType(HookBuilder).last)
            .toDiagnosticsNode()
            .toStringDeep(),
        contains('useMutationState:'),
      );
      await tearDownApp(tester);
    });

    testWidgets(
        'shows a new key in the same frame, and follows a replaced '
        'client', (tester) async {
      final other = newClient();
      run('milk');
      run('report', list: 'work');
      run('plan', list: 'work', on: other);
      await tester.pump(ms10);

      await tester.pumpWidget(app(runsOf('home')));
      expect(find.text('milk success'), findsOneWidget);
      await tester.pumpWidget(app(runsOf('work')));
      expect(find.text('report success'), findsOneWidget);
      await tester.pumpWidget(app(runsOf('work'), with_: other));
      expect(find.text('plan success'), findsOneWidget);

      run('schedule', list: 'work', on: other);
      await tester.pump(Duration.zero);
      expect(find.text('plan success, schedule pending'), findsOneWidget);
      await tester.pump(ms10);
      await tester.pumpWidget(const SizedBox());
      other.clear();
      await tearDownApp(tester);
    });

    testWidgets('ignores what changes after the hook was dropped',
        (tester) async {
      var builds = 0;
      Widget screen({required bool show}) => Column(children: [
            HookBuilder(
              key: const ValueKey('runs'),
              builder: (_) {
                // Its new observer changes the mutation cache in this build.
                if (!show) useMutation(addTodo());
                return const SizedBox();
              },
            ),
            HookBuilder(
              key: const ValueKey('drops'),
              builder: (_) {
                builds++;
                if (show) useMutationState(addTodo());
                return const SizedBox();
              },
            ),
          ]);
      await tester.pumpWidget(app(screen(show: true)));

      builds = 0;
      await tester.pumpWidget(app(screen(show: false)));
      await tester.pump();
      expect(builds, 1);
      await tearDownApp(tester);
    });

    testWidgets('infers its types from the source', (tester) async {
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        final all = useMutationState(
          const MutationFilters(mutationKey: ['todos']),
        );
        final List<MutationState<Object?, Object?, Object?>> typedAll = all;
        final clearing = useMutationState(NoVariablesMutation(
          mutationKey: const ['todos', 'clear'],
          mutationFn: () async => 0,
        ));
        final List<MutationState<int, void, Object?>> typedClearing = clearing;
        final adding = useMutationState(addTodo());
        final List<MutationState<String, String, Object?>> typedAdding = adding;
        return Text('${typedAll.length} ${typedClearing.length} '
            '${typedAdding.length}');
      })));
      run('milk');
      await tester.pump(ms10);
      expect(find.text('1 0 1'), findsOneWidget);
      await tearDownApp(tester);
    });
  });

  group('useOnMutationStateChange', () {
    /// Records each run that failed, from a hook of its own.
    Widget failures(
      List<String?> heard, {
      String list = 'home',
      Widget child = const SizedBox(),
    }) {
      return HookBuilder(builder: (_) {
        useOnMutationStateChange(
          addTodo(list),
          listenWhen: (previous, current) => current.isError,
          listener: (context, run) => heard.add(run.variables),
        );
        return child;
      });
    }

    testWidgets('hears every run that fails, from any widget, once',
        (tester) async {
      final heard = <String?>[];
      run('fail before');
      await tester.pump(ms10);
      run('fail while mounting');

      await tester.pumpWidget(app(failures(
        heard,
        child: Column(children: [addButton('fail a'), addButton('fail b')]),
      )));
      await tester.pump();
      expect(heard, isEmpty);

      // Overlapping runs are heard one by one, and each only once.
      await tester.tap(find.text('add fail a'));
      await tester.tap(find.text('add fail b'));
      await tester.pump(ms10);
      expect(heard, ['fail while mounting', 'fail a', 'fail b']);
      await tester.pump(const Duration(minutes: 5));
      expect(heard, hasLength(3));
      await tearDownApp(tester);
    });

    testWidgets('hears a run whose useMutation went away', (tester) async {
      final heard = <String?>[];
      await tester.pumpWidget(
        app(failures(heard, child: addButton('fail x'))),
      );
      await tester.tap(find.text('add fail x'));
      await tester.pumpWidget(app(failures(heard)));
      expect(find.text('add fail x'), findsNothing);
      await tester.pump(ms10);
      expect(heard, ['fail x']);
      await tearDownApp(tester);
    });

    testWidgets(
        'runs with the context of the widget, and the state the run had '
        'before', (tester) async {
      final compared = <String>[];
      await tester.pumpWidget(app(Scaffold(
        body: HookBuilder(builder: (_) {
          useOnMutationStateChange(
            addTodo(),
            listenWhen: (previous, current) {
              compared.add('${current.variables}: '
                  '${previous.status.name} > ${current.status.name}');
              return current.isSuccess;
            },
            listener: (context, run) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added ${run.variables}')),
              );
            },
          );
          return const SizedBox();
        }),
      )));
      run('milk');
      await tester.pump(ms10);
      await tester.pump();
      expect(compared, ['milk: idle > pending', 'milk: pending > success']);
      expect(find.text('Added milk'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets(
        'hears nothing for the runs of a new key or client until they '
        'change', (tester) async {
      final other = newClient();
      final heard = <String?>[];
      run('fail report', list: 'work');
      run('fail plan', list: 'work', on: other);
      await tester.pump(ms10);

      await tester.pumpWidget(app(failures(heard)));
      await tester.pumpWidget(app(failures(heard, list: 'work')));
      await tester.pump();
      await tester.pumpWidget(
        app(failures(heard, list: 'work'), with_: other),
      );
      await tester.pump();
      expect(heard, isEmpty);

      run('fail schedule', list: 'work', on: other);
      run('fail on the old client', list: 'work');
      await tester.pump(ms10);
      expect(heard, ['fail schedule']);
      await tester.pumpWidget(const SizedBox());
      other.clear();
      await tearDownApp(tester);
    });

    testWidgets('calls the listener of the latest build', (tester) async {
      final heard = <String>[];
      Widget screen(String name) => HookBuilder(builder: (_) {
            useOnMutationStateChange(
              addTodo(),
              listenWhen: (previous, current) {
                heard.add('$name listenWhen');
                return true;
              },
              listener: (context, run) {
                heard.add('$name: ${run.variables} ${run.status.name}');
              },
            );
            return const SizedBox();
          });
      // Listening starts with the first build's listener.
      await tester.pumpWidget(app(screen('first')));
      await tester.pumpWidget(app(screen('second')));
      run('milk');
      await tester.pump(ms10);
      expect(heard, [
        'second listenWhen',
        'second: milk pending',
        'second listenWhen',
        'second: milk success',
      ]);
      await tearDownApp(tester);
    });

    testWidgets(
        'hears nothing when clear() removes a run, or after it went '
        'away', (tester) async {
      final heard = <String>[];
      final screen = HookBuilder(builder: (_) {
        useOnMutationStateChange(
          addTodo(),
          listener: (context, run) {
            heard.add('${run.variables} ${run.status.name}');
          },
        );
        return const SizedBox();
      });
      onlineManager.setOnline(false);
      await tester.pumpWidget(app(screen));
      run('offline');
      await tester.pump();
      expect(heard, ['offline pending']);
      client.clear();
      await tester.pump();
      expect(heard, ['offline pending']);

      onlineManager.setOnline(true);
      await tester.pumpWidget(app(const SizedBox()));
      run('milk');
      await tester.pump(ms10);
      expect(heard, ['offline pending']);
      await tearDownApp(tester);
    });

    testWidgets('adds no builds, and a listener that throws is reported',
        (tester) async {
      final errors = <Object>[];
      final reporting = QueryClient(
        onUncaughtError: (error, _) => errors.add(error),
      );
      var withListener = 0;
      var without = 0;
      var listening = 0;
      await tester.pumpWidget(app(
        Column(children: [
          HookBuilder(builder: (_) {
            withListener++;
            final runs = useMutationState(addTodo());
            useOnMutationStateChange(
              addTodo(),
              listener: (context, run) => throw StateError('listener'),
            );
            return Text('with ${describeRuns(runs)}');
          }),
          HookBuilder(builder: (_) {
            without++;
            final runs = useMutationState(addTodo());
            return Text('without ${describeRuns(runs)}');
          }),
          // It only listens, so a run never rebuilds it.
          HookBuilder(builder: (_) {
            listening++;
            useOnMutationStateChange(
              addTodo(),
              listener: (context, run) {},
            );
            return const SizedBox();
          }),
        ]),
        with_: reporting,
      ));
      run('milk', on: reporting);
      await tester.pump(Duration.zero);
      await tester.pump(ms10);

      // The first frame, the pending run, and its success.
      expect(without, 3);
      expect(withListener, without);
      expect(listening, 1);
      expect(find.text('with milk success'), findsOneWidget);
      expect(errors, [isA<StateError>(), isA<StateError>()]);
      await tester.pumpWidget(const SizedBox());
      reporting.clear();
      await tearDownApp(tester);
    });

    testWidgets('rebuilds once when the provided client is replaced',
        (tester) async {
      final other = newClient();
      var builds = 0;
      final heard = <String?>[];
      // The same widget on every pump, so only the provided client can
      // rebuild it.
      final screen = HookBuilder(builder: (_) {
        builds++;
        useOnMutationStateChange(
          addTodo(),
          listenWhen: (previous, current) => current.isSuccess,
          listener: (context, run) => heard.add(run.variables),
        );
        return const SizedBox();
      });
      await tester.pumpWidget(app(screen));
      run('milk');
      await tester.pump(ms10);
      expect(builds, 1);

      await tester.pumpWidget(app(screen, with_: other));
      expect(builds, 2);
      run('eggs', on: other);
      await tester.pump(ms10);
      expect(builds, 2);
      expect(heard, ['milk', 'eggs']);
      await tester.pumpWidget(const SizedBox());
      other.clear();
      await tearDownApp(tester);
    });

    testWidgets('infers its types from the source', (tester) async {
      final heard = <Object?>[];
      await tester.pumpWidget(app(HookBuilder(builder: (_) {
        useOnMutationStateChange(
          addTodo(),
          listenWhen: (previous, current) {
            final MutationState<String, String, Object?> typedPrevious =
                previous;
            return typedPrevious.status != current.status;
          },
          listener: (context, run) {
            final MutationState<String, String, Object?> typed = run;
            heard.add(typed.data);
          },
        );
        useOnMutationStateChange(
          const MutationFilters(mutationKey: ['todos']),
          listenWhen: (previous, current) => current.isSuccess,
          listener: (context, run) {
            final MutationState<Object?, Object?, Object?> typed = run;
            heard.add(typed.variables);
          },
        );
        return const SizedBox();
      })));
      run('milk');
      await tester.pump(ms10);
      expect(heard, [null, 'saved milk', 'milk']);
      await tearDownApp(tester);
    });
  });

  testWidgets(
      'a snackbar and a Navigator.pop run from the change hooks, with no '
      'useEffect', (tester) async {
    final form = HookBuilder(builder: (context) {
      final add = useMutation(addTodo());
      // Closes the form after its own save.
      useOnMutationChange(
        add,
        listenWhen: (previous, current) => current.isSuccess,
        listener: (context, result) => Navigator.pop(context),
      );
      return Scaffold(
        body: Column(children: [
          TextButton(
            onPressed: () => add.mutate('fail x'),
            child: const Text('save fail x'),
          ),
          TextButton(
            onPressed: () => add.mutate('milk'),
            child: const Text('save milk'),
          ),
        ]),
      );
    });
    // Reports every failed save, from any screen.
    final home = HookBuilder(builder: (context) {
      useOnMutationStateChange(
        addTodo(),
        listenWhen: (previous, current) => current.isError,
        listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add ${run.variables}')),
        ),
      );
      return Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => form),
          ),
          child: const Text('open'),
        ),
      );
    });
    await tester.pumpWidget(app(home));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('save fail x'));
    await tester.pump(ms10);
    await tester.pump();
    expect(find.text('Could not add fail x'), findsOneWidget);

    await tester.tap(find.text('save milk'));
    await tester.pump(ms10);
    await tester.pumpAndSettle();
    expect(find.text('save milk'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('the change hooks show in the widget inspector by name',
      (tester) async {
    await tester.pumpWidget(app(HookBuilder(builder: (_) {
      useOnQueryChange(useQuery(post(1)), listener: (context, result) {});
      useOnMutationChange(
        useMutation(addTodo()),
        listener: (context, result) {},
      );
      useOnMutationStateChange(addTodo(), listener: (context, run) {});
      return const SizedBox();
    })));
    final description = tester
        .element(find.byType(HookBuilder))
        .toDiagnosticsNode()
        .toStringDeep();
    expect(description, contains('useOnQueryChange'));
    expect(description, contains('useOnMutationChange'));
    expect(description, contains('useOnMutationStateChange'));
    await tester.pump(ms10);
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
        final one = useQuery(post(1));
        final QueryResult<String> typedOne = one;

        // The change hooks give their closures the type of the result they
        // get, an InfiniteQueryResult included.
        useOnQueryChange(
          one,
          listenWhen: (previous, current) {
            final QueryResult<String> typedPrevious = previous;
            return typedPrevious.data != current.data;
          },
          listener: (context, result) {
            final QueryResult<String> typed = result;
            heard.add(typed.data);
          },
        );
        useOnQueryChange(
          feed,
          listenWhen: (previous, current) {
            final InfiniteQueryResult<String, int> typedPrevious = previous;
            return typedPrevious.pages.length != current.pages.length;
          },
          listener: (context, result) {
            final InfiniteQueryResult<String, int> typed = result;
            heard.add(typed.pages.length);
          },
        );
        useOnMutationChange(
          renaming,
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

        // A listener for any query fits the result of any query.
        final two = useQuery(post(2));
        useOnQueryChange(two, listener: _recordAnyQuery);
        return Text(
          '${typedPosts.length} ${typedFeed.pages.length} '
          '${typedRenaming.status.name} ${typedOne.data} ${two.data}',
        );
      })),
    );
    await tester.pump(ms10);
    expect(find.text('2 1 idle post 1 post 2'), findsOneWidget);
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
    // the usual way to dismiss the keyboard. Fuery's class keeps its own name.
    await tester.pumpWidget(app(const SizedBox()));
    expect(FocusManager.instance, same(WidgetsBinding.instance.focusManager));
    expect(focusManager, isA<FueryFocusManager>());
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
