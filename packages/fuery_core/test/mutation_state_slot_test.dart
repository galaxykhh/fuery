// MutationStateSlot: the state of every run of a mutation, found by its key
// or by filters, wherever the run was started.
import 'dart:convert';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'storages.dart';

typedef Run = MutationState<String, String, Object?>;

/// Saves a todo after [ms10]. A title that starts with 'fail' fails.
Future<String> save(String title) async {
  await Future<void>.delayed(ms10);
  if (title.startsWith('fail')) throw StateError(title);
  return 'saved $title';
}

Mutation<String, String, Object?> addTodo() => Mutation(
      mutationKey: const ['todos', 'add'],
      mutationFn: save,
    );

Mutation<String, String, Object?> removeTodo() => Mutation(
      mutationKey: const ['todos', 'remove'],
      mutationFn: save,
    );

/// Starts a run of [mutation] from an observer of its own, as a widget
/// elsewhere would.
void run(
  Mutation<String, String, Object?> mutation,
  String title,
  QueryClient on,
) {
  mutation.observe(client: on).mutate(title);
}

List<Object?> variablesOf(List<MutationState<Object?, Object?, Object?>> runs) {
  return [for (final run in runs) run.variables];
}

void main() {
  late QueryClient client;
  late List<Object> errors;

  QueryClient newClient({QueryStorage? storage}) => QueryClient(
        storage: storage,
        onUncaughtError: (error, _) => errors.add(error),
      );

  setUp(() {
    resetManagers();
    errors = [];
    client = newClient()..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  group('result', () {
    fakeTest('lists every run with the key, oldest first, wherever it started',
        (async) {
      final shared = addTodo().observe(client: client);
      shared.mutate('a');
      run(addTodo(), 'b', client);
      // Another definition with the same key and types counts too.
      run(
        Mutation(
          mutationKey: const ['todos', 'add'],
          mutationFn: (String title) async => 'other $title',
        ),
        'c',
        client,
      );
      run(removeTodo(), 'x', client);

      final slot = MutationStateSlot(addTodo(), client);
      expect(variablesOf(slot.result), ['a', 'b', 'c']);
      expect(slot.result.every((run) => run.isPending), isTrue);
      expect(() => slot.result.add(const Run()), throwsUnsupportedError);

      async.elapse(ms10);
      expect(
        [for (final run in slot.result) run.data],
        ['saved a', 'saved b', 'other c'],
      );
      // The runs' own states, with no way to run them from here.
      expect(slot.result.first, shared.result);
      expect(slot.result.first,
          isNot(isA<MutationResult<String, String, Object?>>()));
      slot.dispose();
    });

    fakeTest(
        'MutationFilters find runs by prefix, exact key, status, and '
        'predicate', (async) {
      run(addTodo(), 'a', client);
      run(addTodo(), 'fail b', client);
      run(removeTodo(), 'c', client);
      Mutation(mutationKey: const ['users'], mutationFn: save)
          .observe(client: client)
          .mutate('d');
      async.elapse(ms10);

      List<Object?> found(MutationFilters filters) {
        final slot = MutationStateSlot(filters, client);
        final variables = variablesOf(slot.result);
        slot.dispose();
        return variables;
      }

      expect(found(const MutationFilters()), ['a', 'fail b', 'c', 'd']);
      expect(
        found(const MutationFilters(mutationKey: ['todos'])),
        ['a', 'fail b', 'c'],
      );
      expect(
        found(const MutationFilters(mutationKey: ['todos'], exact: true)),
        isEmpty,
      );
      expect(
        found(
            const MutationFilters(mutationKey: ['todos', 'add'], exact: true)),
        ['a', 'fail b'],
      );
      expect(
        found(const MutationFilters(status: MutationStatus.error)),
        ['fail b'],
      );
      expect(
        found(MutationFilters(
          predicate: (mutation) => mutation.state.variables == 'c',
        )),
        ['c'],
      );
      // States of any type, as the cache holds them.
      final slot = MutationStateSlot(const MutationFilters(), client);
      expect(
        identical(slot.result.first, client.mutationCache.getAll().first.state),
        isTrue,
      );
      slot.dispose();
    });

    fakeTest('is current as soon as update returns', (async) {
      final other = newClient();
      run(addTodo(), 'a', client);
      run(removeTodo(), 'b', client);
      run(addTodo(), 'c', other);
      final slot = MutationStateSlot(addTodo(), client);
      final cache = slot.observer;
      expect(identical(cache, client.mutationCache), isTrue);

      slot.update(removeTodo(), client);
      expect(variablesOf(slot.result), ['b']);
      expect(identical(slot.observer, cache), isTrue);

      slot.update(addTodo(), other);
      expect(variablesOf(slot.result), ['c']);
      expect(identical(slot.observer, other.mutationCache), isTrue);
      slot.dispose();
      async.elapse(ms10);
      other.clear();
    });

    fakeTest(
        'keeps its list until a listed run changes, and pushes each '
        'change once, in a microtask', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final pushed = <List<Run>>[];
      slot.subscribe(pushed.add);
      final adding = addTodo().observe(client: client);

      adding.mutate('a');
      expect(pushed, isEmpty);
      async.flushMicrotasks();
      expect(pushed, hasLength(1));
      expect(pushed.single.single.isPending, isTrue);
      expect(identical(slot.result, pushed.single), isTrue);
      expect(identical(slot.result, slot.result), isTrue);

      // An observer attaching, new options, and another key push nothing.
      final unsubscribe = adding.subscribe((_) {});
      adding.setOptions(Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: save,
        gcTime: const Duration(minutes: 1),
      ));
      run(removeTodo(), 'x', client);
      async.flushMicrotasks();
      expect(pushed, hasLength(1));

      // Changes that arrive together push once.
      notifyManager.batch(() {
        run(addTodo(), 'b', client);
        run(addTodo(), 'c', client);
      });
      async.flushMicrotasks();
      expect(pushed, hasLength(2));
      expect(variablesOf(pushed.last), ['a', 'b', 'c']);

      async.elapse(ms10);
      expect(pushed.last.every((run) => run.isSuccess), isTrue);
      unsubscribe();
      slot.dispose();
    });

    fakeTest('pushes the list of a new key, and of a new client', (async) {
      final other = newClient();
      run(addTodo(), 'a', client);
      run(removeTodo(), 'b', client);
      run(addTodo(), 'c', other);
      final slot = MutationStateSlot(addTodo(), client);
      final pushed = <List<Run>>[];
      slot.subscribe(pushed.add);

      slot.update(removeTodo(), client);
      async.flushMicrotasks();
      expect(variablesOf(pushed.single), ['b']);

      // The same source again changes nothing.
      slot.update(removeTodo(), client);
      async.flushMicrotasks();
      expect(pushed, hasLength(1));

      slot.update(addTodo(), other);
      async.flushMicrotasks();
      expect(variablesOf(pushed.last), ['c']);
      async.elapse(ms10);
      expect(pushed.last.single.isSuccess, isTrue);
      slot.dispose();
      other.clear();
    });

    fakeTest('lists runs that restore brought back', (async) {
      final storage = MemoryStorage({
        '${persistKeyPrefix}mutation:1000:1': jsonEncode({
          'v': 1,
          'k': ['todos', 'add'],
          't': 1000,
          'd': 'restored',
        }),
      });
      final restarted = newClient(storage: storage);
      Mutation<String, String, Object?> persisted() => Mutation(
            mutationKey: const ['todos', 'add'],
            mutationFn: save,
            persist: MutationPersist(
              toJson: (title) => title,
              fromJson: (json) => json! as String,
            ),
          );
      restarted.restore(mutations: [persisted()]);
      async.flushMicrotasks();

      final slot = MutationStateSlot(addTodo(), restarted);
      expect(variablesOf(slot.result), ['restored']);
      expect(slot.result.single.submittedAt, 1000);
      async.elapse(ms10);
      expect(slot.result.single.data, 'saved restored');
      slot.dispose();
      restarted.clear();
    });

    fakeTest('lets runs go after gcTime, and clear() empties it', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final pushed = <List<Run>>[];
      slot.subscribe(pushed.add);
      run(addTodo(), 'a', client);
      async.elapse(ms10);
      expect(slot.result.single.isSuccess, isTrue);

      // The slot doesn't hold the run: it goes after the default gcTime.
      async.elapse(const Duration(minutes: 5));
      expect(slot.result, isEmpty);
      expect(pushed.last, isEmpty);

      run(addTodo(), 'b', client);
      async.flushMicrotasks();
      expect(pushed.last, hasLength(1));
      client.clear();
      async.flushMicrotasks();
      expect(slot.result, isEmpty);
      expect(pushed.last, isEmpty);
      slot.dispose();
    });

    test('a definition without a mutationKey fails an assert', () {
      final keyless = Mutation(mutationFn: save);
      expect(
        () => MutationStateSlot(keyless, client),
        throwsA(isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('MutationStateSlot got a Mutation without a mutationKey'),
        )),
      );
      final slot = MutationStateSlot(addTodo(), client);
      expect(
          () => slot.update(keyless, client), throwsA(isA<AssertionError>()));
      slot.dispose();
    });

    fakeTest('leaves out runs of other types under the key, reported once',
        (async) {
      Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: (int id) async => id,
      ).observe(client: client).mutate(1);
      run(addTodo(), 'a', client);

      final slot = MutationStateSlot(addTodo(), client);
      expect(variablesOf(slot.result), ['a']);
      final heard = <String>[];
      slot.subscribe((runs) => heard.add('list ${variablesOf(runs)}'));
      slot.subscribeToRuns((previous, current) {
        heard.add('run ${current.data}');
      });
      async.elapse(ms10);
      expect(variablesOf(slot.result), ['a']);
      expect(heard, ['run saved a', 'list [a]']);

      expect(errors, hasLength(1));
      expect(
        '${errors.single}',
        allOf(
          contains('MutationState<int, int, Object?>'),
          contains('MutationStateSlot<String, String, Object?>'),
          contains('[todos, add]'),
        ),
      );
      slot.dispose();
    });
  });

  group('subscribeToRuns', () {
    /// Records each change as 'variables: previous > current'.
    List<String> changesOf(MutationStateSlot<Object?, Object?, Object?> slot) {
      final heard = <String>[];
      slot.subscribeToRuns((previous, current) {
        heard.add('${current.variables}: '
            '${previous.status.name} > ${current.status.name}');
      });
      return heard;
    }

    fakeTest('reports later changes, never the states runs had before',
        (async) {
      run(addTodo(), 'done', client);
      run(addTodo(), 'fail done', client);
      async.elapse(ms10);
      run(addTodo(), 'pending', client);

      final slot = MutationStateSlot(addTodo(), client);
      final heard = changesOf(slot);
      run(removeTodo(), 'other key', client);
      async.flushMicrotasks();
      expect(heard, isEmpty);

      // A run that was pending when listening started is heard settling.
      run(addTodo(), 'new', client);
      expect(heard, isEmpty);
      async.flushMicrotasks();
      expect(heard, ['new: idle > pending']);
      async.elapse(ms10);
      expect(heard, [
        'new: idle > pending',
        'pending: pending > success',
        'new: pending > success',
      ]);
      slot.dispose();
    });

    fakeTest('reports a failure once, with the state before it', (async) {
      run(addTodo(), 'fail a', client);
      final slot = MutationStateSlot(addTodo(), client);
      final heard = <(Run, Run)>[];
      slot.subscribeToRuns(
          (previous, current) => heard.add((previous, current)));

      async.elapse(ms10);
      expect(heard, hasLength(1));
      final (previous, current) = heard.single;
      expect(previous.isPending, isTrue);
      expect(current.error, isA<StateError>());
      expect(current.variables, 'fail a');

      async.elapse(const Duration(minutes: 5));
      expect(heard, hasLength(1));
      slot.dispose();
    });

    fakeTest('reports nothing for a paused run that clear() removes', (async) {
      onlineManager.setOnline(false);
      final slot = MutationStateSlot(addTodo(), client);
      final heard = changesOf(slot);
      run(addTodo(), 'offline', client);
      async.flushMicrotasks();
      expect(heard, ['offline: idle > pending']);
      expect(slot.result.single.isPaused, isTrue);

      client.clear();
      async.flushMicrotasks();
      expect(heard, hasLength(1));
      expect(slot.result, isEmpty);
      slot.dispose();
    });

    fakeTest('a new source reports only later changes of its runs', (async) {
      run(removeTodo(), 'a', client);
      final slot = MutationStateSlot(addTodo(), client);
      final heard = changesOf(slot);

      slot.update(removeTodo(), client);
      async.flushMicrotasks();
      expect(heard, isEmpty);
      async.elapse(ms10);
      expect(heard, ['a: pending > success']);
      slot.dispose();
    });

    fakeTest(
        'a run that starts to match a filter reports its real previous '
        'state', (async) {
      final slot = MutationStateSlot(
        const MutationFilters(status: MutationStatus.error),
        client,
      );
      final heard = changesOf(slot);
      run(addTodo(), 'fail a', client);
      run(addTodo(), 'b', client);
      async.flushMicrotasks();
      expect(heard, isEmpty);

      async.elapse(ms10);
      expect(heard, ['fail a: pending > error']);
      slot.dispose();
    });

    fakeTest('a new client reports only later changes of its runs', (async) {
      final other = newClient();
      run(addTodo(), 'other', other);
      final slot = MutationStateSlot(addTodo(), client);
      final heard = changesOf(slot);
      run(addTodo(), 'left behind', client);

      slot.update(addTodo(), other);
      async.flushMicrotasks();
      expect(heard, isEmpty);
      async.elapse(ms10);
      expect(heard, ['other: pending > success']);
      slot.dispose();
      other.clear();
    });

    fakeTest(
        'a listener added before a flush does not hear the changes '
        'before it', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final first = changesOf(slot);
      run(addTodo(), 'a', client);
      final second = changesOf(slot);

      async.flushMicrotasks();
      expect(first, ['a: idle > pending']);
      expect(second, isEmpty);
      async.elapse(ms10);
      expect(first.last, 'a: pending > success');
      expect(second, ['a: pending > success']);
      slot.dispose();
    });

    fakeTest('starts over after its last listener was removed', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final stop = slot.subscribeToRuns((previous, current) {
        fail('removed before the run started');
      });
      stop();
      stop();
      run(addTodo(), 'a', client);
      async.flushMicrotasks();

      final heard = changesOf(slot);
      async.flushMicrotasks();
      expect(heard, isEmpty);
      async.elapse(ms10);
      expect(heard, ['a: pending > success']);
      slot.dispose();
    });

    fakeTest('the same listener twice is one subscription', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final heard = <Run>[];
      void listener(Run previous, Run current) => heard.add(current);
      final stop = slot.subscribeToRuns(listener);
      slot.subscribeToRuns(listener);
      run(addTodo(), 'a', client);
      async.flushMicrotasks();
      expect(heard, hasLength(1));

      stop();
      async.elapse(ms10);
      expect(heard, hasLength(1));
      slot.dispose();
    });

    fakeTest('reports a listener that throws, and calls the others', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      slot.subscribeToRuns((previous, current) => throw StateError('run'));
      slot.subscribe((runs) => throw StateError('list'));
      final heard = changesOf(slot);
      final pushed = <List<Run>>[];
      slot.subscribe(pushed.add);

      run(addTodo(), 'a', client);
      async.flushMicrotasks();
      expect(heard, ['a: idle > pending']);
      expect(pushed, hasLength(1));
      expect(errors.map((error) => '$error'),
          ['Bad state: run', 'Bad state: list']);
      slot.dispose();
    });

    fakeTest('skips a listener that another one removed', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final heard = <String>[];
      late void Function() stopSecond;
      slot.subscribeToRuns((previous, current) {
        heard.add('first ${current.variables}');
        stopSecond();
      });
      stopSecond = slot.subscribeToRuns((previous, current) {
        heard.add('second ${current.variables}');
      });

      run(addTodo(), 'a', client);
      run(addTodo(), 'b', client);
      async.flushMicrotasks();
      expect(heard, ['first a', 'first b']);
      slot.dispose();
    });

    fakeTest('a listener that another one adds hears only later changes',
        (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final heard = <String>[];
      var added = false;
      slot.subscribeToRuns((previous, current) {
        heard.add('first ${current.variables} ${current.status.name}');
        if (added) return;
        added = true;
        // A run that starts before the new listener is added.
        run(addTodo(), 'b', client);
        slot.subscribeToRuns((previous, current) {
          heard.add('second ${current.variables} ${current.status.name}');
        });
      });

      run(addTodo(), 'a', client);
      async.flushMicrotasks();
      expect(heard, ['first a pending', 'first b pending']);
      async.elapse(ms10);
      expect(heard.skip(2), [
        'first a success',
        'second a success',
        'first b success',
        'second b success',
      ]);
      slot.dispose();
    });

    fakeTest('a predicate that throws is reported, and delivers nothing',
        (async) {
      var broken = false;
      final slot = MutationStateSlot(
        MutationFilters(
          predicate: (mutation) =>
              broken ? throw StateError('predicate') : true,
        ),
        client,
      );
      final heard = changesOf(slot);
      final pushed = <List<Object?>>[];
      slot.subscribe(pushed.add);

      broken = true;
      run(addTodo(), 'a', client);
      async.flushMicrotasks();
      expect(errors.map((error) => '$error'), ['Bad state: predicate']);
      expect(heard, isEmpty);
      expect(pushed, isEmpty);
      expect(() => slot.result, throwsStateError);

      // What the throwing flush saw is not reported again.
      broken = false;
      async.elapse(ms10);
      expect(heard, ['a: pending > success']);
      expect(pushed, hasLength(1));
      slot.dispose();
    });

    fakeTest(
        'delivers nothing after the listener stops or the slot is '
        'disposed', (async) {
      final slot = MutationStateSlot(addTodo(), client);
      final heard = changesOf(slot);
      final pushed = <List<Run>>[];
      final unsubscribe = slot.subscribe(pushed.add);

      // A flush already scheduled when the last listener goes.
      run(addTodo(), 'a', client);
      unsubscribe();
      slot.dispose();
      async.elapse(ms10);
      expect(heard, isEmpty);
      expect(pushed, isEmpty);
    });
  });
}
