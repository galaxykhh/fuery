import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

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
    return Query.use(
      queryKey: ['todos'],
      queryFn: fetcher.call,
      staleTime: staleTime,
      client: client,
    );
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
      expect(query.hasListeners(), isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(query.hasListeners(), isFalse);
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

    testWidgets('switches to a new query', (tester) async {
      final first = Query.use(
        queryKey: ['a'],
        queryFn: Fetcher('first').call,
        client: client,
      );
      final second = Query.use(
        queryKey: ['b'],
        queryFn: Fetcher('second').call,
        client: client,
      );
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
      expect(first.hasListeners(), isFalse);
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
      final posts = InfiniteQuery.use(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) =>
            data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
        client: client,
      );
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
      return InfiniteQuery.use(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) => data.lastPageParam + 1,
        client: client,
      );
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
      final addTodo = Mutation.use(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
        client: client,
      );
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

    testWidgets('MutationListener reacts to success', (tester) async {
      final addTodo = Mutation.use(
        mutationFn: (String title) async => title,
        client: client,
      );
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
    final addTodo = Mutation.use(
      mutationFn: (String title) async => title,
      client: client,
    );
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

      final other = Query.use(
        queryKey: ['other'],
        queryFn: Fetcher('b').call,
        client: client,
      );
      await pumpApp(tester, selector(other, '2'));
      await tester.pump(ms10);
      expect(find.text('b2'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('InfiniteQuerySelector and MutationSelector', (tester) async {
      final posts = InfiniteQuery.use(
        queryKey: ['posts'],
        queryFn: (context) async {
          await Future<void>.delayed(ms10);
          return 'page ${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) =>
            data.lastPageParam < 2 ? data.lastPageParam + 1 : null,
        client: client,
      );
      final addTodo = Mutation.use(
        mutationFn: (String title) async {
          await Future<void>.delayed(ms10);
          return title;
        },
        client: client,
      );
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

  group('FueryProvider', () {
    testWidgets('provides its client and falls back to Fuery.instance',
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
      expect(fallback, same(Fuery.instance));
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
      QueryObserver<String>(
        other,
        QueryOptions(queryKey: ['todos'], queryFn: fetcher.call),
      ).subscribe((_) {});
      await tester.pump(ms10);
      focusManager.setFocused(false);
      focusManager.setFocused(true);
      await tester.pump(ms10);
      expect(fetcher.calls, 2);

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
      expect(focusManager.isFocused(), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(ms10);

      expect(focusManager.isFocused(), isTrue);
      expect(fetcher.calls, 2);
      await tearDownApp(tester);
    });
  });
}
