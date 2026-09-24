import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';
import 'package:fuery/src/result_subscriber.dart'
    show debugResetRecreatedWarnings;

const ms10 = Duration(milliseconds: 10);

class Fetcher {
  Fetcher(this.value);

  String value;
  int calls = 0;

  Future<String> call(QueryFunctionContext context) async {
    calls++;
    await Future<void>.delayed(ms10);
    return value;
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

  Future<void> pumpApp(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      FueryProvider(
        client: client,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  /// Unmounts everything and removes cached queries, so no timers are left.
  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  QueryObserver<String> todos(Fetcher fetcher, {Duration? staleTime}) {
    return Query(
      queryKey: ['todos'],
      queryFn: fetcher.call,
      staleTime: staleTime,
    ).observe(client: client);
  }

  Widget text(QueryResult<String> state) {
    return Text(
      state.isLoading ? 'loading' : state.data ?? 'error: ${state.error}',
    );
  }

  group('QueryBuilder', () {
    testWidgets('shows loading on the first frame, then data', (tester) async {
      final fetcher = Fetcher('a');
      await pumpApp(
        tester,
        QueryBuilder(
          query: todos(fetcher),
          builder: (context, state) => text(state),
        ),
      );
      expect(find.text('loading'), findsOneWidget);

      await tester.pump(ms10);
      expect(find.text('a'), findsOneWidget);
      expect(fetcher.calls, 1);
      await tearDownApp(tester);
    });

    testWidgets('rebuilds only when buildWhen allows it', (tester) async {
      final query = todos(Fetcher('a'));
      final built = <QueryResult<String>>[];
      await pumpApp(
        tester,
        QueryBuilder(
          query: query,
          buildWhen: (previous, current) => previous.data != current.data,
          builder: (context, state) {
            built.add(state);
            return text(state);
          },
        ),
      );
      await tester.pump(ms10);

      query.refetch();
      await tester.pump(ms10);

      expect(built.map((s) => s.data), [null, 'a']);
      await tearDownApp(tester);
    });

    testWidgets('unsubscribes when unmounted', (tester) async {
      final query = todos(Fetcher('a'));
      await pumpApp(
        tester,
        QueryBuilder(query: query, builder: (_, state) => text(state)),
      );
      await tester.pump(ms10);
      expect(query.hasListeners, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(query.hasListeners, isFalse);
      expect(client.queryCache.getAll().single.observersCount, 0);
      client.clear();
    });

    testWidgets('shows fresh data when the same query mounts again',
        (tester) async {
      final query = todos(Fetcher('a'), staleTime: infiniteDuration);
      final visible = ValueNotifier(true);
      await pumpApp(
        tester,
        ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, show, _) => show
              ? QueryBuilder(query: query, builder: (_, s) => text(s))
              : const SizedBox(),
        ),
      );
      await tester.pump(ms10);

      visible.value = false;
      await tester.pump();
      client.setQueryData(['todos'], 'b');

      visible.value = true;
      await tester.pump();
      expect(find.text('b'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('warns once when a rebuild brings a new observer for the key',
        (tester) async {
      final messages = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      debugResetRecreatedWarnings();
      try {
        final rebuild = ValueNotifier(0);
        final fetcher = Fetcher('a');

        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: rebuild,
            // The mistake: a new observer on every build.
            builder: (context, _, __) => QueryBuilder(
              query: Query(
                queryKey: ['todos'],
                queryFn: fetcher.call,
              ).observe(client: client),
              builder: (context, state) => Text(state.data ?? 'loading'),
            ),
          ),
        );
        await tester.pump(ms10);
        expect(messages, isEmpty);

        rebuild.value++;
        await tester.pump();
        expect(messages, hasLength(1));
        expect(messages.single, startsWith('[fuery] QueryBuilder received'));
        expect(messages.single, contains('["todos"]'));
        expect(messages.single, contains('refetches'));
        expect(messages.single, contains('troubleshooting'));

        rebuild.value++;
        await tester.pump();
        expect(messages, hasLength(1), reason: 'warned once per key');
        await tester.pump(ms10); // fetches the extra observers started
        await tester.pumpWidget(const SizedBox());
        client.clear();
      } finally {
        debugPrint = print;
      }
    });

    testWidgets('warns for infinite queries and keyed mutations too',
        (tester) async {
      final messages = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      debugResetRecreatedWarnings();
      try {
        final rebuild = ValueNotifier(0);

        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: rebuild,
            builder: (context, _, __) => Column(
              children: [
                InfiniteQueryBuilder(
                  query: InfiniteQuery(
                    queryKey: ['pages'],
                    queryFn: (context) async => 'page ${context.pageParam}',
                    initialPageParam: 1,
                    getNextPageParam: (data) => null,
                  ).observe(client: client),
                  builder: (context, state) => const Text('pages'),
                ),
                MutationBuilder(
                  // The key of the infinite query: each kind warns once.
                  mutation: Mutation(
                    mutationKey: ['pages'],
                    mutationFn: (int value) async => value,
                  ).observe(client: client),
                  builder: (context, state) => const Text('keyed'),
                ),
                MutationBuilder(
                  mutation: Mutation(
                    mutationFn: (int value) async => value,
                  ).observe(client: client),
                  builder: (context, state) => const Text('unkeyed'),
                ),
              ],
            ),
          ),
        );
        await tester.pump(ms10);
        rebuild.value++;
        await tester.pump();
        // The mutation without a key can't be told apart, so it is silent.
        expect(messages, hasLength(2));
        expect(messages[0], contains('InfiniteQueryBuilder received'));
        expect(messages[0], contains('["pages"]'));
        expect(messages[0], contains('refetches'));
        expect(messages[1], contains('MutationBuilder received'));
        expect(messages[1], contains('["pages"]'));
        expect(messages[1], contains('starts idle'));
        expect(messages[1], isNot(contains('refetches')));
        await tester.pump(ms10); // fetches the extra observers started
        await tester.pumpWidget(const SizedBox());
        client.clear();
      } finally {
        debugPrint = print;
      }
    });

    testWidgets('does not warn when the observer or the key changes on purpose',
        (tester) async {
      final messages = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      debugResetRecreatedWarnings();
      try {
        final key = ValueNotifier('a');
        final fetcher = Fetcher('a');
        final same = Query(
          queryKey: ['same'],
          queryFn: fetcher.call,
        ).observe(client: client);

        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: key,
            builder: (context, value, _) => Column(
              children: [
                QueryBuilder(
                  query: same,
                  builder: (context, state) => const Text('same'),
                ),
                QueryBuilder(
                  query: Query(
                    queryKey: ['todos', value],
                    queryFn: fetcher.call,
                  ).observe(client: client),
                  builder: (context, state) => const Text('keyed'),
                ),
              ],
            ),
          ),
        );
        await tester.pump(ms10);
        key.value = 'b';
        await tester.pump(ms10);
        expect(messages, isEmpty);
        await tester.pump(ms10); // fetches the extra observers started
        await tester.pumpWidget(const SizedBox());
        client.clear();
      } finally {
        debugPrint = print;
      }
    });

    testWidgets('switches to a new query', (tester) async {
      final first = Query(
        queryKey: ['a'],
        queryFn: Fetcher('first').call,
      ).observe(client: client);
      final second = Query(
        queryKey: ['b'],
        queryFn: Fetcher('second').call,
      ).observe(client: client);
      final current = ValueNotifier(first);
      await pumpApp(
        tester,
        ValueListenableBuilder(
          valueListenable: current,
          builder: (context, query, _) =>
              QueryBuilder(query: query, builder: (_, s) => text(s)),
        ),
      );
      await tester.pump(ms10);
      expect(find.text('first'), findsOneWidget);

      current.value = second;
      await tester.pump();
      expect(find.text('loading'), findsOneWidget);
      await tester.pump(ms10);
      expect(find.text('second'), findsOneWidget);
      expect(first.hasListeners, isFalse);
      await tearDownApp(tester);
    });
  });

  group('QueryListener', () {
    testWidgets('calls the listener on changes, not for the initial result',
        (tester) async {
      final query = todos(Fetcher('a'));
      final heard = <QueryResult<String>>[];
      await pumpApp(
        tester,
        QueryListener(
          query: query,
          listenWhen: (previous, current) => previous.data != current.data,
          listener: (context, state) => heard.add(state),
          child: const Text('child'),
        ),
      );
      expect(find.text('child'), findsOneWidget);
      expect(heard, isEmpty);

      await tester.pump(ms10);
      expect(heard.map((s) => s.data), ['a']);

      query.refetch();
      await tester.pump(ms10);
      expect(heard, hasLength(1));
      await tearDownApp(tester);
    });
  });

  group('QueryConsumer', () {
    testWidgets('builds and listens', (tester) async {
      final heard = <String?>[];
      await pumpApp(
        tester,
        QueryConsumer(
          query: todos(Fetcher('a')),
          listener: (context, state) => heard.add(state.data),
          builder: (context, state) => text(state),
        ),
      );
      await tester.pump(ms10);

      expect(find.text('a'), findsOneWidget);
      expect(heard, ['a']);
      await tearDownApp(tester);
    });
  });

  group('InfiniteQueryBuilder', () {
    testWidgets('shows pages and loads more', (tester) async {
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) =>
            data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
      ).observe(client: client);
      await pumpApp(
        tester,
        InfiniteQueryBuilder(
          query: posts,
          builder: (context, state) => Column(
            children: [
              for (final page in state.pages) Text(page),
              if (state.hasNextPage)
                TextButton(
                  onPressed: posts.fetchNextPage,
                  child: const Text('more'),
                ),
            ],
          ),
        ),
      );
      await tester.pump(ms10);
      expect(find.text('page 1'), findsOneWidget);

      await tester.tap(find.text('more'));
      await tester.pump(ms10);
      expect(find.text('page 2'), findsOneWidget);
      expect(find.text('more'), findsNothing);
      await tearDownApp(tester);
    });
  });

  group('InfiniteQuery listener and consumer', () {
    InfiniteQueryObserver<String, int> posts() {
      return InfiniteQuery(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) => data.lastPageParam + 1,
      ).observe(client: client);
    }

    testWidgets('InfiniteQueryListener hears new pages', (tester) async {
      final query = posts();
      final heard = <int>[];
      await pumpApp(
        tester,
        InfiniteQueryListener(
          query: query,
          listenWhen: (previous, current) =>
              previous.pages.length != current.pages.length,
          listener: (context, state) => heard.add(state.pages.length),
          child: const SizedBox(),
        ),
      );
      await tester.pump(ms10);
      query.fetchNextPage();
      await tester.pump(ms10);

      expect(heard, [1, 2]);
      await tearDownApp(tester);
    });

    testWidgets('InfiniteQueryConsumer builds and listens', (tester) async {
      final heard = <int>[];
      await pumpApp(
        tester,
        InfiniteQueryConsumer(
          query: posts(),
          listener: (context, state) => heard.add(state.pages.length),
          builder: (context, state) => Text('${state.pages.length} pages'),
        ),
      );
      await tester.pump(ms10);

      expect(find.text('1 pages'), findsOneWidget);
      expect(heard, [1]);
      await tearDownApp(tester);
    });
  });

  group('Mutation widgets', () {
    testWidgets('MutationBuilder shows each status', (tester) async {
      final addTodo = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
      ).observe(client: client);
      await pumpApp(
        tester,
        MutationBuilder(
          mutation: addTodo,
          builder: (context, state) => Text(state.status.name),
        ),
      );
      expect(find.text('idle'), findsOneWidget);

      addTodo.mutate('a');
      await tester.pump();
      expect(find.text('pending'), findsOneWidget);

      await tester.pump(ms10);
      expect(find.text('success'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('MutationBuilder shows the latest state when it mounts again',
        (tester) async {
      final save = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
      ).observe(client: client);
      final visible = ValueNotifier(true);
      await pumpApp(
        tester,
        ValueListenableBuilder(
          valueListenable: visible,
          builder: (context, show, _) => show
              ? MutationBuilder(
                  mutation: save,
                  builder: (_, state) => Text(state.status.name),
                )
              : const Text('hidden'),
        ),
      );

      save.mutate('a');
      await tester.pump();
      expect(find.text('pending'), findsOneWidget);

      // For example a tab switch while saving.
      visible.value = false;
      await tester.pump();
      await tester.pump(ms10);
      visible.value = true;
      await tester.pump();
      expect(find.text('success'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('MutationListener reacts to success', (tester) async {
      final addTodo = Mutation(
        mutationFn: (String title) async => title,
      ).observe(client: client);
      final created = <String>[];
      await pumpApp(
        tester,
        MutationListener(
          mutation: addTodo,
          listenWhen: (previous, current) => current.isSuccess,
          listener: (context, state) => created.add(state.data!),
          child: const SizedBox(),
        ),
      );

      addTodo.mutate('a');
      await tester.pump();
      expect(created, ['a']);
      await tearDownApp(tester);
    });
  });

  testWidgets('MutationConsumer builds and listens', (tester) async {
    final addTodo = Mutation(
      mutationFn: (String title) async => title,
    ).observe(client: client);
    final heard = <MutationStatus>[];
    await pumpApp(
      tester,
      MutationConsumer(
        mutation: addTodo,
        listener: (context, state) => heard.add(state.status),
        builder: (context, state) => Text(state.data ?? 'none'),
      ),
    );

    addTodo.mutate('a');
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    expect(heard, [MutationStatus.pending, MutationStatus.success]);
    await tearDownApp(tester);
  });

  group('Selectors', () {
    testWidgets('QuerySelector rebuilds only when the value changes',
        (tester) async {
      final fetcher = Fetcher('a');
      final query = todos(fetcher);
      final built = <int>[];
      await pumpApp(
        tester,
        QuerySelector(
          query: query,
          selector: (state) => state.data?.length ?? 0,
          builder: (context, length) {
            built.add(length);
            return Text('$length');
          },
        ),
      );
      await tester.pump(ms10);

      fetcher.value = 'b';
      query.refetch();
      await tester.pump(ms10);

      fetcher.value = 'abc';
      query.refetch();
      await tester.pump(ms10);

      expect(built, [0, 1, 3]);
      await tearDownApp(tester);
    });

    testWidgets('compares selected lists by content', (tester) async {
      final query = todos(Fetcher('ab'));
      final built = <List<String>>[];
      await pumpApp(
        tester,
        QuerySelector(
          query: query,
          selector: (state) => state.data?.split('') ?? const <String>[],
          builder: (context, letters) {
            built.add(letters);
            return Text(letters.join());
          },
        ),
      );
      await tester.pump(ms10);

      query.refetch();
      await tester.pump(ms10);

      expect(built, [
        <String>[],
        ['a', 'b'],
      ]);
      await tearDownApp(tester);
    });

    testWidgets('selects again when the parent rebuilds or the query changes',
        (tester) async {
      final query = todos(Fetcher('a'));
      Widget selector(QueryObserver<String> query, String suffix) {
        return QuerySelector(
          query: query,
          selector: (state) => '${state.data}$suffix',
          builder: (context, value) => Text(value),
        );
      }

      await pumpApp(tester, selector(query, '1'));
      await tester.pump(ms10);
      expect(find.text('a1'), findsOneWidget);

      await pumpApp(tester, selector(query, '2'));
      expect(find.text('a2'), findsOneWidget);

      final other = Query(
        queryKey: ['other'],
        queryFn: Fetcher('b').call,
      ).observe(client: client);
      await pumpApp(tester, selector(other, '2'));
      await tester.pump(ms10);
      expect(find.text('b2'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('InfiniteQuerySelector and MutationSelector', (tester) async {
      final posts = InfiniteQuery(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) =>
            data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
      ).observe(client: client);
      final addTodo = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
      ).observe(client: client);
      await pumpApp(
        tester,
        Column(
          children: [
            InfiniteQuerySelector(
              query: posts,
              selector: (state) => state.pages.length,
              builder: (context, count) => Text('$count pages'),
            ),
            MutationSelector(
              mutation: addTodo,
              selector: (state) => state.isPending,
              builder: (context, saving) => Text(saving ? 'saving' : 'idle'),
            ),
          ],
        ),
      );
      await tester.pump(ms10);
      expect(find.text('1 pages'), findsOneWidget);

      posts.fetchNextPage();
      addTodo.mutate('a');
      await tester.pump(Duration.zero);
      expect(find.text('saving'), findsOneWidget);

      await tester.pump(ms10);
      expect(find.text('2 pages'), findsOneWidget);
      expect(find.text('idle'), findsOneWidget);
      await tearDownApp(tester);
    });
  });

  group('Debug warnings', () {
    /// Runs [body] with every debugPrint collected, and restores debugPrint
    /// before the test ends, as flutter_test requires.
    Future<void> withWarnings(
      Future<void> Function(List<String> messages) body,
    ) async {
      final messages = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
      debugResetRecreatedWarnings();
      try {
        await body(messages);
      } finally {
        debugPrint = print;
      }
    }

    Query<String> fresh(String name, int id) => Query(
          queryKey: [name, id],
          queryFn: (_) async => '$name $id',
          staleTime: infiniteDuration,
        );

    testWidgets('lists of queries warn about observers created in build',
        (tester) async {
      await withWarnings((messages) async {
        final rebuild = ValueNotifier(0);
        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: rebuild,
            builder: (context, _, __) => Column(
              children: [
                QueriesBuilder(
                  queries: [
                    for (final id in [1, 2])
                      fresh('post', id).observe(client: client),
                  ],
                  builder: (context, results) => Text('${results.length}'),
                ),
                QueriesSelector(
                  queries: [
                    for (final id in [1, 2])
                      fresh('user', id).observe(client: client),
                  ],
                  selector: (results) => results.length,
                  builder: (context, count) => Text('$count'),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 2; i++) {
          rebuild.value++;
          await tester.pump();
        }

        expect(messages, hasLength(2), reason: 'once per widget and key');
        expect(
          messages[0],
          contains('QueriesBuilder received a new observer for the key '
              '["post",1]'),
        );
        expect(messages[0], contains('refetches'));
        expect(
          messages[0],
          contains(
            'QueriesBuilder(queries: [for (final id in ids) todoQuery(id)])',
          ),
        );
        expect(
          messages[1],
          contains('QueriesSelector received a new observer for the key '
              '["user",1]'),
        );
        await tearDownApp(tester);
      });
    });

    testWidgets('lists of shared observers or definitions are silent',
        (tester) async {
      await withWarnings((messages) async {
        final rebuild = ValueNotifier(0);
        final shared = [
          for (final id in [1, 2]) fresh('post', id).observe(client: client),
        ];
        // Two observers of one key, passed again on every build.
        final twins = [
          fresh('twin', 1).observe(client: client),
          fresh('twin', 1).observe(client: client),
        ];
        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: rebuild,
            builder: (context, count, _) => Column(
              children: [
                QueriesBuilder(
                  // A new list each build, reordered every other one.
                  queries: count.isEven ? [...shared] : [...shared.reversed],
                  builder: (context, results) => Text('${results.length}'),
                ),
                QueriesBuilder(
                  queries: [...twins],
                  builder: (context, results) => Text('${results.length}'),
                ),
                QueriesSelector(
                  queries: [
                    for (final id in [1, 2]) fresh('user', id)
                  ],
                  selector: (results) => results.length,
                  builder: (context, count) => Text('$count'),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          rebuild.value++;
          await tester.pump();
        }

        expect(messages, isEmpty);
        await tearDownApp(tester);
      });
    });

    Mutation<String, String, Object?> addTodo() => Mutation(
          mutationFn: (String title) async => title,
        );

    testWidgets('a MutationListener warns once when it gets a definition',
        (tester) async {
      await withWarnings((messages) async {
        final rebuild = ValueNotifier(0);
        await pumpApp(
          tester,
          ValueListenableBuilder(
            valueListenable: rebuild,
            builder: (context, _, __) => MutationListener(
              mutation: addTodo(),
              listener: (context, state) {},
              child: const SizedBox(),
            ),
          ),
        );
        rebuild.value++;
        await tester.pump();

        expect(messages, hasLength(1));
        expect(
          messages.single,
          startsWith('[fuery] MutationListener got a Mutation definition'),
        );
        expect(messages.single, contains('#a-mutationlistener-never-runs'));
        await tearDownApp(tester);
      });
    });

    testWidgets(
        'a shared observer, or a definition for a widget that can run it, '
        'is silent', (tester) async {
      await withWarnings((messages) async {
        final adding = addTodo().observe(client: client);
        final heard = <String>[];
        await pumpApp(
          tester,
          Column(
            children: [
              // One observer: the button runs it, and the listener hears it.
              MutationListener(
                mutation: adding,
                listenWhen: (previous, current) => current.isSuccess,
                listener: (context, state) => heard.add(state.data!),
                child: MutationBuilder(
                  mutation: adding,
                  builder: (context, state) => TextButton(
                    onPressed: () => state.mutate('milk'),
                    child: const Text('add'),
                  ),
                ),
              ),
              MutationBuilder(
                mutation: addTodo(),
                builder: (context, state) => const SizedBox(),
              ),
              MutationConsumer(
                mutation: addTodo(),
                listener: (context, state) {},
                builder: (context, state) => const SizedBox(),
              ),
              MutationSelector(
                mutation: addTodo(),
                selector: (state) => state.isPending,
                builder: (context, pending) => const SizedBox(),
              ),
            ],
          ),
        );
        await tester.tap(find.text('add'));
        await tester.pump();

        expect(heard, ['milk']);
        expect(messages, isEmpty);
        await tearDownApp(tester);
      });
    });
  });

  group('FueryProvider', () {
    testWidgets('provides its client and falls back to Fuery.client',
        (tester) async {
      QueryClient? provided;
      QueryClient? fallback;
      await tester.pumpWidget(
        Column(
          children: [
            FueryProvider(
              client: client,
              child: Builder(builder: (context) {
                provided = context.queryClient;
                return const SizedBox();
              }),
            ),
            Builder(builder: (context) {
              fallback = context.queryClient;
              return const SizedBox();
            }),
          ],
        ),
      );

      expect(provided, same(client));
      expect(fallback, same(Fuery.client));
      await tearDownApp(tester);
    });

    testWidgets('mounts a replacement client and notifies dependents',
        (tester) async {
      final other = QueryClient();
      final current = ValueNotifier(client);
      final seen = <QueryClient>[];
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: current,
          builder: (context, value, _) => FueryProvider(
            client: value,
            child: Builder(builder: (context) {
              seen.add(context.queryClient);
              return const SizedBox();
            }),
          ),
        ),
      );

      current.value = other;
      await tester.pump();

      expect(seen, [client, other]);
      // The old client no longer refetches on focus; the new one does.
      final fetcher = Fetcher('a');
      final unsubscribe = QueryObserver<String>(
        other,
        Query(queryKey: ['todos'], queryFn: fetcher.call),
      ).subscribe((_) {});
      await tester.pump(ms10);
      focusManager.setFocused(false);
      focusManager.setFocused(true);
      await tester.pump(ms10);
      expect(fetcher.calls, 2);

      unsubscribe();
      await tester.pumpWidget(const SizedBox());
      other.clear();
      client.clear();
    });

    testWidgets('refetches stale queries when the app resumes', (tester) async {
      final fetcher = Fetcher('a');
      await pumpApp(
        tester,
        QueryBuilder(query: todos(fetcher), builder: (_, s) => text(s)),
      );
      await tester.pump(ms10);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(focusManager.isFocused, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(ms10);

      expect(focusManager.isFocused, isTrue);
      expect(fetcher.calls, 2);
      await tearDownApp(tester);
    });
  });
}
