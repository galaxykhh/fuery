// The MutationState widgets show and hear every run of a mutation, found by
// its key, wherever the run was started. They are called without type
// arguments, and the package enables strict-inference, so these tests also
// check that they infer their types.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

const ms10 = Duration(milliseconds: 10);

typedef Run = MutationState<String, String, Object?>;

/// Saves a todo after [ms10]. A title that starts with 'fail' fails.
Mutation<String, String, Object?> addTodo([String list = 'home']) => Mutation(
      mutationKey: ['todos', list, 'add'],
      mutationFn: (title) async {
        await Future<void>.delayed(ms10);
        if (title.startsWith('fail')) throw StateError(title);
        return 'saved $title';
      },
    );

String describe(List<Run> runs) => runs.isEmpty
    ? 'no runs'
    : [for (final run in runs) '${run.variables} ${run.status.name}']
        .join(', ');

/// A button that runs [addTodo] with an observer of its own.
class AddButton extends StatelessWidget {
  const AddButton(this.title, {super.key, this.list = 'home'});

  final String title;
  final String list;

  @override
  Widget build(BuildContext context) {
    return MutationBuilder(
      mutation: addTodo(list),
      builder: (context, state) => TextButton(
        onPressed: () => state.mutate(title),
        child: Text('add $title'),
      ),
    );
  }
}

/// Every run of [addTodo] for [list], from anywhere, with no State.
class TodoRuns extends StatelessWidget {
  const TodoRuns({super.key, this.list = 'home'});

  final String list;

  @override
  Widget build(BuildContext context) {
    return MutationStateBuilder(
      mutation: addTodo(list),
      builder: (context, runs) {
        // Inferred from the definition.
        final List<Run> typed = runs;
        return Text(describe(typed));
      },
    );
  }
}

void main() {
  late QueryClient client;
  late List<Object> errors;

  QueryClient newClient() => QueryClient(
        defaultOptions: const DefaultOptions(
          queries: QueryDefaults(retry: RetryPolicy.never()),
        ),
        onUncaughtError: (error, _) => errors.add(error),
      );

  setUp(() {
    focusManager.setFocused(null);
    onlineManager.setOnline(true);
    errors = [];
    client = newClient();
  });

  Widget app(Widget child, {QueryClient? on}) => FueryProvider(
        client: on ?? client,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    client.clear();
  }

  /// Starts a run of [addTodo] from an observer of its own.
  void run(String title, {String list = 'home', QueryClient? on}) {
    addTodo(list).observe(client: on ?? client).mutate(title);
  }

  group('MutationStateBuilder', () {
    testWidgets('shows the runs a MutationBuilder elsewhere starts',
        (tester) async {
      await tester.pumpWidget(app(const Column(
        children: [AddButton('milk'), AddButton('fail eggs'), TodoRuns()],
      )));
      expect(find.text('no runs'), findsOneWidget);

      await tester.tap(find.text('add milk'));
      await tester.pump();
      expect(find.text('milk pending'), findsOneWidget);
      await tester.tap(find.text('add fail eggs'));
      await tester.pump();
      expect(find.text('milk pending, fail eggs pending'), findsOneWidget);

      await tester.pump(ms10);
      expect(find.text('milk success, fail eggs error'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('shows a new key and a replaced client in the same frame',
        (tester) async {
      final other = newClient();
      run('milk');
      run('report', list: 'work');
      run('plan', list: 'work', on: other);
      await tester.pump(ms10);

      await tester.pumpWidget(app(const TodoRuns()));
      expect(find.text('milk success'), findsOneWidget);
      await tester.pumpWidget(app(const TodoRuns(list: 'work')));
      expect(find.text('report success'), findsOneWidget);
      await tester.pumpWidget(app(const TodoRuns(list: 'work'), on: other));
      expect(find.text('plan success'), findsOneWidget);

      run('schedule', list: 'work', on: other);
      await tester.pump(Duration.zero);
      expect(find.text('plan success, schedule pending'), findsOneWidget);
      await tester.pump(ms10);
      await tester.pumpWidget(const SizedBox());
      other.clear();
      await tearDownApp(tester);
    });

    testWidgets('rebuilds only when buildWhen says so', (tester) async {
      var builds = 0;
      await tester.pumpWidget(app(MutationStateBuilder(
        mutation: addTodo(),
        buildWhen: (previous, current) => previous.length != current.length,
        builder: (context, runs) {
          builds++;
          return Text(describe(runs));
        },
      )));
      run('milk');
      await tester.pump(Duration.zero);
      expect(find.text('milk pending'), findsOneWidget);

      await tester.pump(ms10);
      expect(find.text('milk pending'), findsOneWidget);
      expect(builds, 2);
      await tearDownApp(tester);
    });
  });

  testWidgets('MutationStateSelector rebuilds only when its value changes',
      (tester) async {
    final built = <int>[];
    await tester.pumpWidget(app(MutationStateSelector(
      mutation: addTodo(),
      selector: (runs) => runs.where((run) => run.isPending).length,
      builder: (context, saving) {
        final int typed = saving;
        built.add(typed);
        return Text('saving $typed');
      },
    )));
    run('milk');
    run('eggs');
    await tester.pump(Duration.zero);
    expect(find.text('saving 2'), findsOneWidget);

    await tester.pump(ms10);
    expect(find.text('saving 0'), findsOneWidget);
    // A run of another key changes nothing it selects.
    run('report', list: 'work');
    await tester.pump(Duration.zero);
    expect(built, [0, 2, 0]);

    // Filters select from every mutation under a key prefix.
    await tester.pumpWidget(app(MutationStateSelector(
      mutation: const MutationFilters(mutationKey: ['todos']),
      selector: (runs) => runs.length,
      builder: (context, count) => Text('$count runs'),
    )));
    expect(find.text('3 runs'), findsOneWidget);
    run('plan', list: 'work');
    await tester.pump(Duration.zero);
    expect(find.text('4 runs'), findsOneWidget);
    await tester.pump(ms10);
    await tearDownApp(tester);
  });

  group('MutationStateListener', () {
    /// Records each run that failed, from a listener around [child].
    Widget failures(List<String?> heard,
        {String list = 'home', Widget? child}) {
      return MutationStateListener(
        mutation: addTodo(list),
        listenWhen: (previous, current) => current.isError,
        listener: (context, run) {
          final Run typed = run;
          heard.add(typed.variables);
        },
        child: child ?? const SizedBox(),
      );
    }

    testWidgets('hears every run that fails, from any widget, once',
        (tester) async {
      final heard = <String?>[];
      run('fail before');
      await tester.pump(ms10);
      run('fail while mounting');

      await tester.pumpWidget(app(failures(
        heard,
        child: const Column(
          children: [AddButton('fail a'), AddButton('fail b')],
        ),
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

    testWidgets('hears a run whose MutationBuilder went away', (tester) async {
      final heard = <String?>[];
      await tester
          .pumpWidget(app(failures(heard, child: const AddButton('x'))));
      await tester.tap(find.text('add x'));
      await tester.pumpWidget(app(failures(heard)));
      expect(find.text('add x'), findsNothing);

      await tester.pump(ms10);
      expect(heard, isEmpty); // 'x' saved
      await tester.pumpWidget(
        app(failures(heard, child: const AddButton('fail y'))),
      );
      await tester.tap(find.text('add fail y'));
      await tester.pumpWidget(app(failures(heard)));
      await tester.pump(ms10);
      expect(heard, ['fail y']);
      await tearDownApp(tester);
    });

    testWidgets('gives listenWhen the state that run had before',
        (tester) async {
      final compared = <String>[];
      final heard = <String>[];
      await tester.pumpWidget(app(MutationStateListener(
        mutation: addTodo(),
        listenWhen: (previous, current) {
          compared.add('${current.variables}: '
              '${previous.status.name} > ${current.status.name}');
          return current.isSuccess;
        },
        listener: (context, run) {
          heard.add(run.data!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${run.variables}')),
          );
        },
        child: const SizedBox(),
      )));
      run('milk');
      await tester.pump(ms10);

      expect(compared, ['milk: idle > pending', 'milk: pending > success']);
      expect(heard, ['saved milk']);
      await tester.pump();
      expect(find.text('Added milk'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets(
        'hears nothing for the runs of a new key or client until '
        'they change', (tester) async {
      final other = newClient();
      final heard = <String?>[];
      run('fail report', list: 'work');
      run('fail plan', list: 'work', on: other);
      await tester.pump(ms10);

      await tester.pumpWidget(app(failures(heard)));
      await tester.pumpWidget(app(failures(heard, list: 'work')));
      await tester.pump();
      await tester.pumpWidget(app(failures(heard, list: 'work'), on: other));
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

    testWidgets('keeps listening to a definition built on every rebuild',
        (tester) async {
      final heard = <String?>[];
      final rebuild = ValueNotifier(0);
      await tester.pumpWidget(app(ValueListenableBuilder(
        valueListenable: rebuild,
        builder: (context, _, __) => failures(heard),
      )));
      run('fail a');
      for (var i = 0; i < 3; i++) {
        rebuild.value++;
        await tester.pump();
      }
      await tester.pump(ms10);
      expect(heard, ['fail a']);
      await tearDownApp(tester);
    });

    testWidgets(
        'hears nothing when clear() removes a run, or after it went '
        'away', (tester) async {
      final heard = <String>[];
      final listener = MutationStateListener(
        mutation: addTodo(),
        listener: (context, run) {
          heard.add('${run.variables} ${run.status.name}');
        },
        child: const SizedBox(),
      );
      onlineManager.setOnline(false);
      await tester.pumpWidget(app(listener));
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

    testWidgets('reports a listener that throws to the client', (tester) async {
      await tester.pumpWidget(app(MutationStateListener(
        mutation: addTodo(),
        listener: (context, run) => throw StateError('listener'),
        child: const TodoRuns(),
      )));
      run('milk');
      await tester.pump(Duration.zero);
      expect(errors, [isA<StateError>()]);
      expect(find.text('milk pending'), findsOneWidget);
      await tester.pump(ms10);
      expect(errors, hasLength(2));
      expect(find.text('milk success'), findsOneWidget);
      await tearDownApp(tester);
    });
  });

  testWidgets('a definition without a mutationKey fails an assert',
      (tester) async {
    // Without a provider or an app, so the widget that fails to mount
    // depends on nothing.
    await tester.pumpWidget(MutationStateBuilder(
      mutation: Mutation(mutationFn: (String title) async => title),
      builder: (context, runs) => Text('${runs.length}'),
    ));
    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (error) => error.message,
        'message',
        contains('without a mutationKey'),
      ),
    );
    await tearDownApp(tester);
  });
}
