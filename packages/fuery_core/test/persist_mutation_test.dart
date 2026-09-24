import 'dart:async';
import 'dart:convert';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'storages.dart';

enum Visibility { public }

/// A mutation function that records its calls and resolves after [delay].
class FakeMutator {
  FakeMutator({this.delay = ms10});

  final Duration delay;
  final List<String> calls = [];
  Object? error;

  Future<String> call(String variables) async {
    calls.add(variables);
    await Future<void>.delayed(delay);
    final error = this.error;
    if (error != null) throw error;
    return 'saved $variables';
  }
}

const persist = MutationPersist<String>(
  toJson: _same,
  fromJson: _string,
);

Object? _same(String variables) => variables;

String _string(Object? json) => json! as String;

/// A mutation that stores its variables, for screens and for `restore`.
Mutation<String, String, void> commentOptions(
  FakeMutator mutator, {
  MutationScope? scope,
  int version = 1,
  MutationOnSuccess<String, String, void>? onSuccess,
  MutationOnMutate<String, void>? onMutate,
}) {
  return Mutation(
    mutationKey: const ['comments', 'add'],
    mutationFn: mutator.call,
    scope: scope,
    persist:
        MutationPersist(toJson: _same, fromJson: _string, version: version),
    onSuccess: onSuccess,
    onMutate: onMutate,
  );
}

/// What a previous run would have stored for [variables].
MapEntry<String, String> storedEntry(
  String variables, {
  List<Object?> key = const ['comments', 'add'],
  int submittedAt = 1000,
  int version = 1,
  int id = 1,
}) {
  return MapEntry(
    '${persistKeyPrefix}mutation:$submittedAt:$id',
    jsonEncode({
      'v': version,
      'k': key,
      't': submittedAt,
      'd': variables,
    }),
  );
}

void main() {
  late MemoryStorage storage;
  late QueryClient client;

  setUp(() {
    resetManagers();
    storage = MemoryStorage();
    client = QueryClient(storage: storage);
    client.mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  Iterable<String> storedMutations() => storage.entries.keys
      .where((k) => k.startsWith('${persistKeyPrefix}mutation:'));

  group('storing', () {
    fakeTest('stores a mutation while it runs and deletes it when it settles',
        (async) {
      final mutator = FakeMutator();
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: mutator.call,
        persist: persist,
      ).observe(client: client);

      addComment.mutate('hello');
      async.flushMicrotasks();
      expect(storedMutations(), hasLength(1));
      final entry = jsonDecode(storage.entries[storedMutations().single]!)
          as Map<String, Object?>;
      expect(entry['k'], ['comments', 'add']);
      expect(entry['d'], 'hello');
      expect(entry['v'], 1);
      expect(entry['t'], isA<int>());

      async.elapse(ms10);
      expect(addComment.result.isSuccess, isTrue);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('stores a mutation that paused offline', (async) {
      onlineManager.setOnline(false);
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: FakeMutator().call,
        persist: persist,
      ).observe(client: client);

      addComment.mutate('later');
      async.flushMicrotasks();
      expect(addComment.result.isPaused, isTrue);
      expect(storedMutations(), hasLength(1));
    });

    fakeTest('a key with an enum is stored and restored', (async) {
      Mutation<String, String, void> share(FakeMutator mutator) => Mutation(
            mutationKey: const ['share', Visibility.public],
            mutationFn: mutator.call,
            persist: persist,
          );
      onlineManager.setOnline(false);
      share(FakeMutator()).observe(client: client).mutate('later');
      async.flushMicrotasks();
      expect(storedMutations(), hasLength(1));

      // The app restarts.
      final restarted = QueryClient(storage: storage);
      final mutator = FakeMutator();
      restarted.restore(mutations: [share(mutator)]);
      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(mutator.calls, ['later']);
      restarted.clear();
    });

    fakeTest('a key that cannot be stored is reported, and the run goes on',
        (async) {
      final errors = <Object>[];
      final mutator = FakeMutator();
      runZonedGuarded(() {
        Mutation(
          mutationKey: [Object()], // no toJson
          mutationFn: mutator.call,
          persist: persist,
        ).observe(client: client).mutate('a');
        async.elapse(ms10);
      }, (error, _) => errors.add(error));

      expect(errors.single, isA<ArgumentError>());
      expect(mutator.calls, ['a']);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('a key JSON cannot hold is reported', (async) {
      final errors = <Object>[];
      runZonedGuarded(() {
        Mutation(
          mutationKey: ['rate', double.nan],
          mutationFn: FakeMutator().call,
          persist: persist,
        ).observe(client: client).mutate('a');
        async.elapse(ms10);
      }, (error, _) => errors.add(error));

      expect(errors.single, isA<JsonUnsupportedObjectError>());
      expect(storedMutations(), isEmpty);
    });

    fakeTest('deletes the entry when the mutation fails', (async) {
      final mutator = FakeMutator()..error = StateError('no');
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: mutator.call,
        persist: persist,
      ).observe(client: client);

      addComment.mutate('hello');
      async.elapse(ms10);
      expect(addComment.result.isError, isTrue);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('deletes after an asynchronous write has landed', (async) {
      final async10 = AsyncStorage(storage);
      client.unmount();
      client = QueryClient(storage: async10)..mount();
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: FakeMutator(delay: const Duration(milliseconds: 5)).call,
        persist: persist,
      ).observe(client: client);

      addComment.mutate('hello');
      async.elapse(const Duration(milliseconds: 5));
      expect(addComment.result.isSuccess, isTrue);
      // The write lands at 10 ms and the delete after it.
      async.elapse(const Duration(milliseconds: 30));
      expect(storedMutations(), isEmpty);
    });

    fakeTest('a mutation without a key or a storage is not stored', (async) {
      final noStorage = QueryClient();
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: FakeMutator().call,
        persist: persist,
      ).observe(client: noStorage);
      addComment.mutate('hello');
      async.elapse(ms10);
      expect(storedMutations(), isEmpty);
      noStorage.clear();

      expect(
        () => Mutation(
          mutationFn: FakeMutator().call,
          persist: persist,
        ).observe(client: client),
        throwsA(isA<AssertionError>()),
      );
    });

    fakeTest('a failing storage does not break the mutation', (async) {
      client.unmount();
      client = QueryClient(storage: FailingStorage())..mount();
      final addComment = Mutation(
        mutationKey: const ['comments', 'add'],
        mutationFn: FakeMutator().call,
        persist: persist,
      ).observe(client: client);
      addComment.mutate('hello');
      async.elapse(ms10);
      expect(addComment.result.data, 'saved hello');
    });

    fakeTest('NoVariablesMutation stores with MutationPersist.noVariables',
        (async) {
      onlineManager.setOnline(false);
      final refresh = NoVariablesMutation(
        mutationKey: const ['refresh'],
        mutationFn: () async => 42,
        persist: MutationPersist.noVariables,
      ).observe(client: client);
      refresh.mutate();
      async.flushMicrotasks();
      expect(storedMutations(), hasLength(1));
    });
  });

  group('restoring', () {
    fakeTest('restore runs stored mutations with the options for their key',
        (async) {
      final entry = storedEntry('from last time');
      storage.entries[entry.key] = entry.value;
      final mutator = FakeMutator();
      final results = <String>[];
      final options = commentOptions(
        mutator,
        onSuccess: (data, _, __, client) => results.add(data),
      );

      client.restore(mutations: [options]);
      async.flushMicrotasks();
      expect(mutator.calls, ['from last time']);
      final mutation = client.mutationCache.getAll().single;
      expect(mutation.state.isPending, isTrue);
      expect(mutation.state.variables, 'from last time');
      expect(mutation.state.submittedAt, 1000);
      expect(mutation.options.mutationKey, ['comments', 'add']);

      async.elapse(ms10);
      expect(results, ['saved from last time']);
      expect(mutation.state.isSuccess, isTrue);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('restored mutations wait while offline and run on reconnect',
        (async) {
      onlineManager.setOnline(false);
      final entry = storedEntry('offline');
      storage.entries[entry.key] = entry.value;
      final mutator = FakeMutator();

      client.restore(mutations: [commentOptions(mutator)]);
      async.flushMicrotasks();
      expect(mutator.calls, isEmpty);
      final mutation = client.mutationCache.getAll().single;
      expect(mutation.state.isPaused, isTrue);
      expect(storedMutations(), hasLength(1));

      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(mutator.calls, ['offline']);
      expect(mutation.state.isSuccess, isTrue);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('restored mutations in a scope run one at a time, oldest first',
        (async) {
      final second = storedEntry('second', submittedAt: 2000, id: 2);
      final first = storedEntry('first', submittedAt: 1000, id: 1);
      storage.entries[second.key] = second.value;
      storage.entries[first.key] = first.value;
      final mutator = FakeMutator();

      client.restore(
        mutations: [
          commentOptions(mutator, scope: const MutationScope('comments'))
        ],
      );
      async.flushMicrotasks();
      expect(mutator.calls, ['first']);
      async.elapse(ms10);
      expect(mutator.calls, ['first', 'second']);
      async.elapse(ms10);
      expect(storedMutations(), isEmpty);
      expect(
        client.mutationCache.getAll().every((m) => m.state.isSuccess),
        isTrue,
      );
    });

    fakeTest('restored mutations skip onMutate and have no context', (async) {
      final entry = storedEntry('x');
      storage.entries[entry.key] = entry.value;
      var onMutateCalls = 0;

      client.restore(
        mutations: [
          commentOptions(FakeMutator(),
              onMutate: (_, client) => onMutateCalls++),
        ],
      );
      async.elapse(ms10);
      expect(onMutateCalls, 0);
      expect(client.mutationCache.getAll().single.state.context, isNull);
    });

    fakeTest('entries with another version or unreadable are dropped', (async) {
      final outdated = storedEntry('b', version: 2, id: 2);
      storage.entries[outdated.key] = outdated.value;
      storage.entries['${persistKeyPrefix}mutation:3:3'] = 'not json';
      final mutator = FakeMutator();

      client.restore(mutations: [commentOptions(mutator)]);
      async.elapse(ms10);
      expect(mutator.calls, isEmpty);
      expect(client.mutationCache.getAll(), isEmpty);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('a definition whose key cannot be hashed leaves other entries',
        (async) {
      final entry = storedEntry('from last time');
      storage.entries[entry.key] = entry.value;
      final mutator = FakeMutator();
      final broken = Mutation(
        mutationKey: [Object()],
        mutationFn: FakeMutator().call,
      );

      final errors = <Object>[];
      runZonedGuarded(() {
        client.restore(mutations: [broken, commentOptions(mutator)]);
        async.elapse(ms10);
      }, (error, _) => errors.add(error));
      expect(errors.single, isA<ArgumentError>());
      expect(mutator.calls, ['from last time']);
    });

    fakeTest('entries whose options were not passed are kept for later',
        (async) {
      final unknown = storedEntry('a', key: ['likes']);
      storage.entries[unknown.key] = unknown.value;

      client.restore(mutations: [commentOptions(FakeMutator())]);
      async.elapse(ms10);
      expect(client.mutationCache.getAll(), isEmpty);
      expect(storedMutations(), hasLength(1));
    });

    fakeTest('variables that cannot be decoded are dropped', (async) {
      final entry = storedEntry('x');
      storage.entries[entry.key] = entry.value.replaceFirst('"d":"x"', '"d":1');

      client.restore(mutations: [commentOptions(FakeMutator())]);
      async.elapse(ms10);
      expect(client.mutationCache.getAll(), isEmpty);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('restore does not load a mutation twice', (async) {
      final entry = storedEntry('once');
      storage.entries[entry.key] = entry.value;
      final mutator = FakeMutator();
      final options = commentOptions(mutator);

      client.restore(mutations: [options]);
      client.restore(mutations: [options]);
      async.elapse(ms10);
      expect(mutator.calls, ['once']);
      expect(client.mutationCache.getAll(), hasLength(1));
    });

    fakeTest('restore reads an asynchronous storage', (async) {
      final entry = storedEntry('async');
      storage.entries[entry.key] = entry.value;
      client.unmount();
      client = QueryClient(storage: AsyncStorage(storage))..mount();
      final mutator = FakeMutator();

      client.restore(mutations: [commentOptions(mutator)]);
      async.flushMicrotasks();
      expect(mutator.calls, isEmpty);
      async.elapse(ms10);
      expect(mutator.calls, ['async']);
    });

    fakeTest('restore runs a stored mutation without variables', (async) {
      final entry = storedEntry('', key: ['refresh']);
      storage.entries[entry.key] =
          entry.value.replaceFirst('"d":""', '"d":null');
      var calls = 0;

      client.restore(
        mutations: [
          Mutation<int, void, void>(
            mutationKey: const ['refresh'],
            mutationFn: (_) async => ++calls,
            persist: MutationPersist.noVariables,
          ),
        ],
      );
      async.elapse(ms10);
      expect(calls, 1);
      expect(storedMutations(), isEmpty);
    });

    fakeTest('a stored mutation is not restored by a query restore alone',
        (async) {
      final entry = storedEntry('kept');
      storage.entries[entry.key] = entry.value;

      client.restore();
      async.elapse(ms10);
      expect(client.mutationCache.getAll(), isEmpty);
      expect(storedMutations(), hasLength(1));
    });
  });

  group('deleting', () {
    fakeTest('clear deletes stored mutations', (async) {
      final entry = storedEntry('gone');
      storage.entries[entry.key] = entry.value;

      client.clear();
      async.flushMicrotasks();
      expect(storedMutations(), isEmpty);
    });

    fakeTest('deleting queries by key leaves stored mutations alone', (async) {
      final entry = storedEntry('kept');
      storage.entries[entry.key] = entry.value;

      client.removeQueries(queryKey: ['comments']);
      client.resetQueries();
      async.flushMicrotasks();
      expect(storedMutations(), hasLength(1));
    });
  });
}
