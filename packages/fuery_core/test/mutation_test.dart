import 'dart:async';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late QueryClient client;

  setUp(() {
    resetManagers();
    client = QueryClient()..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  Future<String> slowEcho(String value) async {
    await Future<void>.delayed(ms10);
    return value;
  }

  Future<String> slowFail(String value) async {
    await Future<void>.delayed(ms10);
    throw StateError('failed $value');
  }

  fakeTest('goes from idle to pending to success', (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final statuses = <MutationStatus>[];
    observer.subscribe((state) => statuses.add(state.status));

    expect(observer.result.isIdle, isTrue);
    observer.mutate('a');
    async.elapse(ms10);

    expect(statuses, [MutationStatus.pending, MutationStatus.success]);
    expect(observer.result.data, 'a');
    expect(observer.result.variables, 'a');
    expect(
      client.mutationCache.getAll().single.toString(),
      contains('success'),
    );
  });

  fakeTest('runs onMutate before the mutation function', (async) {
    final events = <String>[];
    final observer = Mutation(
      mutationFn: (String value) async {
        events.add('mutationFn');
        return value;
      },
      onMutate: (value, client) {
        events.add('onMutate');
        return 'context';
      },
      onSuccess: (data, variables, context, client) {
        events.add('onSuccess $data $variables $context');
      },
      onSettled: (data, error, variables, context, client) {
        events.add('onSettled $data $error');
      },
    ).observe(client: client);

    observer.mutate('a');
    async.flushMicrotasks();

    expect(events, [
      'onMutate',
      'mutationFn',
      'onSuccess a a context',
      'onSettled a null',
    ]);
  });

  fakeTest('rolls back an optimistic update with the onMutate context',
      (async) {
    client.setQueryData<List<String>>(['todos'], ['a', 'b']);

    final observer = Mutation(
      mutationFn: slowFail,
      onMutate: (removed, client) {
        final previous = client.getQueryData<List<String>>(['todos']);
        client.updateQueryData<List<String>>(
          ['todos'],
          (todos) => todos?.where((t) => t != removed).toList(),
        );
        return previous;
      },
      onError: (error, variables, previous, client) {
        client.setQueryData<List<String>>(['todos'], previous!);
      },
    ).observe(client: client);

    observer.mutate('a');
    async.flushMicrotasks();
    expect(client.getQueryData<List<String>>(['todos']), ['b']);

    async.elapse(ms10);
    expect(client.getQueryData<List<String>>(['todos']), ['a', 'b']);
  });

  fakeTest('mutate reports failures without throwing', (async) {
    final observer = Mutation(mutationFn: slowFail).observe(client: client);
    observer.subscribe((_) {});

    observer.mutate('a');
    async.elapse(ms10);

    expect(observer.result.isError, isTrue);
    expect(observer.result.error, isA<StateError>());
    expect(observer.result.failureCount, 1);
  });

  fakeTest('mutateAsync throws the error', (async) {
    final observer = Mutation(mutationFn: slowFail).observe(client: client);

    Object? error;
    observer.mutateAsync('a').catchError((Object e) {
      error = e;
      return '';
    });
    async.elapse(ms10);

    expect(error, isA<StateError>());
  });

  fakeTest('noVariables mutations run with mutate()', (async) {
    var calls = 0;
    final observer = NoVariablesMutation(
      mutationFn: () async => ++calls,
    ).observe(client: client);

    observer.mutate();
    async.flushMicrotasks();
    expect(observer.result.data, 1);

    int? data;
    observer.mutateAsync().then((value) => data = value);
    async.flushMicrotasks();
    expect(data, 2);
  });

  fakeTest('noVariables mutations report failures', (async) {
    final observer = NoVariablesMutation(
      mutationFn: () async => throw StateError('boom'),
    ).observe(client: client);

    observer.mutate();
    async.flushMicrotasks();

    expect(observer.result.isError, isTrue);
  });

  fakeTest('retries when retry is set', (async) {
    var attempts = 0;
    final observer = Mutation(
      mutationFn: (String value) async {
        attempts++;
        if (attempts < 3) throw StateError('try again');
        return value;
      },
      retry: const RetryPolicy.count(2),
      retryDelay: (_, __) => ms10,
    ).observe(client: client);

    observer.mutate('a');
    async.elapse(const Duration(milliseconds: 50));

    expect(attempts, 3);
    expect(observer.result.data, 'a');
  });

  fakeTest('mutations in the same scope run one after another', (async) {
    final events = <String>[];
    Future<String> run(String value) async {
      events.add('start $value');
      await Future<void>.delayed(ms10);
      events.add('end $value');
      return value;
    }

    final first = Mutation(
      mutationFn: run,
      scope: const MutationScope('todos'),
    ).observe(client: client);
    final second = Mutation(
      mutationFn: run,
      scope: const MutationScope('todos'),
    ).observe(client: client);

    first.mutate('a');
    second.mutate('b');
    async.elapse(const Duration(milliseconds: 30));

    expect(events, ['start a', 'end a', 'start b', 'end b']);
  });

  fakeTest('per-call callbacks run while the observer has listeners', (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final events = <String>[];
    observer.subscribe((_) {});

    observer.mutate(
      'a',
      MutateOptions(
        onSuccess: (data, _, __, client) => events.add('success $data'),
        onSettled: (data, _, variables, __, client) =>
            events.add('settled $variables'),
      ),
    );
    async.elapse(ms10);

    expect(events, ['success a', 'settled a']);
  });

  fakeTest('per-call callbacks run without listeners', (async) {
    // An observer kept in a State field that no widget listens to.
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final events = <String>[];

    observer.mutate(
      'a',
      MutateOptions(
        onSuccess: (data, _, __, client) => events.add('success $data'),
        onSettled: (data, _, variables, __, client) =>
            events.add('settled $variables'),
      ),
    );
    int? length;
    observer
        .mutateAsync(
          'bb',
          MutateOptions(
            onError: (error, _, __, client) => events.add('error'),
          ),
        )
        .then((data) => length = data.length);
    async.elapse(ms10);

    // A later call replaces the callbacks of the earlier one.
    expect(events, isEmpty);
    expect(length, 2);

    observer.mutate(
      'c',
      MutateOptions(onSuccess: (data, _, __, client) => events.add(data)),
    );
    async.elapse(ms10);
    expect(events, ['c']);
  });

  fakeTest('per-call callbacks run before listeners react to the result',
      (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final events = <String>[];
    // A listener that resets once the mutation succeeds.
    observer.subscribe((result) {
      if (result.isSuccess) observer.reset();
    });

    observer.mutate(
      'a',
      MutateOptions(
        onSuccess: (data, _, __, client) => events.add('success $data'),
        onSettled: (data, _, __, ___, client) => events.add('settled $data'),
      ),
    );
    async.elapse(ms10);
    expect(events, ['success a', 'settled a']);

    // A call started from onSuccess replaces the rest of the callbacks.
    events.clear();
    observer.mutate(
      'b',
      MutateOptions(
        onSuccess: (data, _, __, client) {
          events.add('success $data');
          observer.mutate('c');
        },
        onSettled: (data, _, __, ___, client) => events.add('settled $data'),
      ),
    );
    async.elapse(ms10 * 2);
    expect(events, ['success b']);
  });

  fakeTest('per-call callbacks stop after reset', (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final events = <String>[];
    observer.mutate(
      'a',
      MutateOptions(onSuccess: (data, _, __, client) => events.add(data)),
    );
    observer.reset();
    async.elapse(ms10);

    expect(events, isEmpty);
  });

  fakeTest('per-call callbacks stop when the owning slot is disposed', (async) {
    final slot = MutationSlot(Mutation(mutationFn: slowEcho), client);
    final events = <String>[];
    slot.result.mutate(
      'a',
      MutateOptions(onSuccess: (data, _, __, client) => events.add(data)),
    );
    slot.dispose(); // the widget that rendered it unmounted
    async.elapse(ms10);

    expect(events, isEmpty);
  });

  fakeTest('reset returns to idle', (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    observer.subscribe((_) {});
    observer.mutate('a');
    async.elapse(ms10);

    observer.reset();
    expect(observer.result.isIdle, isTrue);
    expect(observer.result.data, isNull);
  });

  fakeTest('removes finished mutations after gcTime', (async) {
    final observer = Mutation(
      mutationFn: slowEcho,
      gcTime: const Duration(minutes: 1),
    ).observe(client: client);
    final unsubscribe = observer.subscribe((_) {});
    observer.mutate('a');
    async.elapse(ms10);
    unsubscribe();

    expect(client.mutationCache.getAll(), hasLength(1));
    async.elapse(const Duration(minutes: 1));
    expect(client.mutationCache.getAll(), isEmpty);
  });

  fakeTest('pauses while offline and resumes on reconnect', (async) {
    onlineManager.setOnline(false);
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    observer.subscribe((_) {});

    observer.mutate('a');
    async.elapse(ms10);
    expect(observer.result.isPending, isTrue);
    expect(observer.result.isPaused, isTrue);

    onlineManager.setOnline(true);
    async.elapse(ms10);
    expect(observer.result.isSuccess, isTrue);
  });

  fakeTest('isMutating counts pending mutations', (async) {
    final observer = Mutation(
      mutationFn: slowEcho,
      mutationKey: ['todos', 'add'],
    ).observe(client: client);
    observer.mutate('a');
    async.flushMicrotasks();

    expect(client.isMutating(), 1);
    expect(client.isMutating(mutationKey: ['todos']), 1);
    expect(client.isMutating(mutationKey: ['posts']), 0);
    async.elapse(ms10);
    expect(client.isMutating(), 0);
  });

  fakeTest('stream sends the current state first, then changes', (async) {
    final observer = Mutation(mutationFn: slowEcho).observe(client: client);
    final statuses = <MutationStatus>[];
    observer.stream.listen((state) => statuses.add(state.status));
    async.flushMicrotasks();

    observer.mutate('a');
    async.elapse(ms10);

    expect(statuses, [
      MutationStatus.idle,
      MutationStatus.pending,
      MutationStatus.success,
    ]);
  });

  group('edge cases', () {
    fakeTest('noVariables callbacks receive data, error, and context', (async) {
      final events = <String>[];
      var fail = false;
      final observer = NoVariablesMutation(
        mutationFn: () async {
          if (fail) throw StateError('boom');
          return 1;
        },
        onMutate: (client) => 'ctx',
        onSuccess: (data, context, client) =>
            events.add('success $data $context'),
        onError: (error, context, client) => events.add('error $context'),
        onSettled: (data, error, context, client) =>
            events.add('settled $data ${error != null}'),
      ).observe(client: client);

      observer.mutate();
      async.flushMicrotasks();
      fail = true;
      observer.mutate();
      async.flushMicrotasks();

      expect(events, [
        'success 1 ctx',
        'settled 1 false',
        'error ctx',
        'settled null true',
      ]);
    });

    fakeTest('cache callbacks run for every mutation', (async) {
      final events = <String>[];
      final client = QueryClient(
        mutationCache: MutationCache(
          config: MutationCacheConfig(
            onMutate: (variables, _) => events.add('mutate $variables'),
            onSuccess: (data, _, __, ___) => events.add('success $data'),
            onError: (error, _, __, ___) => events.add('error'),
            onSettled: (data, error, _, __, ___) => events.add('settled'),
          ),
        ),
      );
      final observer = Mutation(
        mutationFn: (int x) async {
          if (x < 0) throw StateError('negative');
          return x;
        },
      ).observe(client: client);

      observer.mutate(1);
      async.flushMicrotasks();
      observer.mutate(-1);
      async.flushMicrotasks();

      expect(events, [
        'mutate 1',
        'success 1',
        'settled',
        'mutate -1',
        'error',
        'settled',
      ]);
      client.clear();
    });

    fakeTest('keeps a pending mutation past gcTime until it settles', (async) {
      final observer = Mutation(
        mutationFn: (int x) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return x;
        },
        gcTime: ms10,
      ).observe(client: client);
      final unsubscribe = observer.subscribe((_) {});
      observer.mutate(1);
      async.flushMicrotasks();
      unsubscribe();

      async.elapse(const Duration(milliseconds: 500));
      expect(client.mutationCache.getAll(), hasLength(1));

      async.elapse(const Duration(seconds: 1));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('changing the mutation key resets the observer', (async) {
      final observer = Mutation(
        mutationFn: (int x) async => x,
        mutationKey: ['a'],
      ).observe(client: client);
      observer.mutate(1);
      async.flushMicrotasks();
      expect(observer.result.isSuccess, isTrue);

      observer.setOptions(Mutation(
        mutationFn: (int x) async => x,
        mutationKey: ['b'],
      ));
      expect(observer.result.isIdle, isTrue);
    });

    fakeTest('new options apply to a pending mutation', (async) {
      final events = <String>[];
      final observer = Mutation(
        mutationFn: (int x) async {
          await Future<void>.delayed(ms10);
          return x;
        },
        onSuccess: (_, __, ___, client) => events.add('old'),
      ).observe(client: client);
      observer.mutate(1);
      async.flushMicrotasks();

      observer.setOptions(Mutation(
        mutationFn: (int x) async => x,
        onSuccess: (_, __, ___, client) => events.add('new'),
      ));
      async.elapse(ms10);

      expect(events, ['new']);
    });

    fakeTest('a listener added after mutate sees the mutation', (async) {
      final observer = Mutation(
        mutationFn: (int x) async {
          await Future<void>.delayed(ms10);
          return x;
        },
      ).observe(client: client);
      observer.mutate(1);
      async.flushMicrotasks();

      final statuses = <MutationStatus>[];
      observer.subscribe((state) => statuses.add(state.status));
      async.elapse(ms10);

      expect(statuses, [MutationStatus.success]);
      expect(
        client.mutationCache.getAll().single.state.status,
        MutationStatus.success,
      );
    });

    fakeTest('per-call error callbacks run while listened to', (async) {
      final observer = Mutation(mutationFn: slowFail).observe(client: client);
      final events = <String>[];
      observer.subscribe((_) {});

      observer.mutate(
        'a',
        MutateOptions(
          onError: (error, variables, _, client) =>
              events.add('error $variables'),
          onSettled: (data, error, variables, _, client) =>
              events.add('settled $variables'),
        ),
      );
      async.elapse(ms10);

      expect(events, ['error a', 'settled a']);
    });

    fakeTest('errors thrown by callbacks are reported, not swallowed', (async) {
      final errors = <Object>[];
      runZonedGuarded(() {
        final observer = Mutation(
          mutationFn: slowEcho,
        ).observe(client: client);
        observer.subscribe((_) {});
        observer.mutate(
          'a',
          MutateOptions(
              onSuccess: (_, __, ___, client) => throw StateError('cb')),
        );
      }, (error, _) => errors.add(error));
      async.elapse(ms10);

      expect(errors.single, isA<StateError>());
    });

    fakeTest('filters mutations by key, status, and predicate', (async) {
      final add = Mutation(
        mutationFn: (int x) async => x,
        mutationKey: ['todos', 'add'],
      ).observe(client: client);
      final remove = Mutation(
        mutationFn: (int x) async => x,
        mutationKey: ['todos', 'remove'],
        meta: {'kind': 'remove'},
      ).observe(client: client);
      add.mutate(1);
      remove.mutate(2);
      async.flushMicrotasks();

      final cache = client.mutationCache;
      expect(cache.findAll(const MutationFilters(mutationKey: ['todos'])),
          hasLength(2));
      expect(
        cache.find(const MutationFilters(mutationKey: ['todos', 'add'])),
        isNotNull,
      );
      expect(cache.find(const MutationFilters(mutationKey: ['todos'])), isNull);
      expect(
        cache.findAll(
          MutationFilters(predicate: (m) => m.meta?['kind'] == 'remove'),
        ),
        hasLength(1),
      );
      expect(
        cache.findAll(const MutationFilters(status: MutationStatus.pending)),
        isEmpty,
      );
    });

    fakeTest('scoped mutations leave the scope when removed', (async) {
      final observer = Mutation(
        mutationFn: (int x) async => x,
        scope: const MutationScope('todos'),
        gcTime: ms10,
      ).observe(client: client);
      final unsubscribe = observer.subscribe((_) {});
      observer.mutate(1);
      async.flushMicrotasks();
      unsubscribe();
      async.elapse(const Duration(milliseconds: 20));

      expect(client.mutationCache.getAll(), isEmpty);

      observer.mutate(2);
      async.flushMicrotasks();
      expect(observer.result.data, 2);
    });
  });
}
