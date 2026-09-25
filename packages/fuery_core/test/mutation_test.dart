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

      final removing = cache
          .findAll(
            const MutationFilters(mutationKey: ['todos', 'remove']),
          )
          .single;
      expect(
        const MutationFilters(mutationKey: ['todos']).matches(removing),
        isTrue,
      );
      expect(
        const MutationFilters(mutationKey: ['todos'], exact: true)
            .matches(removing),
        isFalse,
      );
      expect(
        const MutationFilters(mutationKey: ['todos', 'remove'], exact: true)
            .matches(removing),
        isTrue,
      );
      expect(
        const MutationFilters(status: MutationStatus.pending).matches(removing),
        isFalse,
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

    fakeTest('lets a run go when its observer takes another key', (async) {
      Mutation<String, String, Object?> save(String key) {
        return Mutation(
          mutationKey: [key],
          mutationFn: slowEcho,
          gcTime: const Duration(minutes: 1),
        );
      }

      // Its == and hashCode change with its key.
      final observer = SameKeyMutationObserver(client, save('a'));
      final unsubscribe = observer.subscribe((_) {});
      observer.mutate('a');
      async.elapse(ms10);

      observer.setOptions(save('b'));
      unsubscribe();
      async.elapse(const Duration(minutes: 1));
      expect(client.mutationCache.getAll(), isEmpty);
    });
  });

  group('running from the definition', () {
    /// Makes [replacement] the default client for the rest of the test.
    void useAsFueryClient(QueryClient replacement) {
      final original = Fuery.client;
      Fuery.client = replacement;
      addTearDown(() {
        replacement.clear();
        Fuery.client = original;
      });
    }

    fakeTest('mutate runs on the given client, where its key finds the run',
        (async) {
      final events = <String>[];
      final addTodo = Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: slowEcho,
        onMutate: (title, on) {
          events.add('onMutate $title ${identical(on, client)}');
          return 'context';
        },
        onSuccess: (data, title, context, on) =>
            events.add('onSuccess $data $context ${identical(on, client)}'),
        onSettled: (data, error, title, context, on) =>
            events.add('onSettled $data $error'),
      );
      final slot = MutationStateSlot(addTodo, client);
      final heard = <String>[];
      slot.subscribeToRuns(
        (previous, current) => heard.add('${previous.status.name} '
            '${current.status.name} ${current.variables}'),
      );

      addTodo.mutate('a', client);
      async.flushMicrotasks();
      expect(client.isMutating(mutationKey: const ['todos']), 1);
      expect(slot.result.single.isPending, isTrue);
      expect(slot.result.single.variables, 'a');
      expect(slot.result.single.context, 'context');

      async.elapse(ms10);
      expect(client.isMutating(), 0);
      expect(slot.result.single.isSuccess, isTrue);
      expect(slot.result.single.data, 'a');
      expect(events, [
        'onMutate a true',
        'onSuccess a context true',
        'onSettled a null',
      ]);
      expect(heard.first, 'idle pending a');
      expect(heard.last, 'pending success a');
      slot.dispose();
    });

    fakeTest('mutateAsync returns the data', (async) {
      final addTodo = Mutation(mutationFn: slowEcho);

      String? data;
      addTodo.mutateAsync('a', client).then<void>((value) {
        data = value;
      });
      async.flushMicrotasks();
      expect(client.isMutating(), 1);

      async.elapse(ms10);
      expect(data, 'a');
      expect(client.mutationCache.getAll().single.state.data, 'a');
    });

    fakeTest('runs on Fuery.client when no client is given', (async) {
      final other = QueryClient();
      useAsFueryClient(other);
      final clients = <QueryClient>[];
      final addTodo = Mutation(
        mutationFn: slowEcho,
        onSuccess: (data, title, context, on) {
          clients.add(on);
        },
      );

      addTodo.mutate('a');
      String? data;
      addTodo.mutateAsync('b').then<void>((value) {
        data = value;
      });
      async.flushMicrotasks();
      expect(other.isMutating(), 2);
      expect(client.isMutating(), 0);

      async.elapse(ms10);
      expect(data, 'b');
      expect(
        [for (final run in other.mutationCache.getAll()) run.state.data],
        ['a', 'b'],
      );
      expect(clients, [same(other), same(other)]);
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('mutate reports a failure to the run and the callbacks only',
        (async) {
      final events = <String>[];
      final uncaught = <Object>[];
      final failing = QueryClient(
        mutationCache: MutationCache(
          config: MutationCacheConfig(
            onError: (error, variables, context, mutation) =>
                events.add('cache onError $variables'),
            onSettled: (data, error, variables, context, mutation) =>
                events.add('cache onSettled $variables'),
          ),
        ),
        onUncaughtError: (error, _) => uncaught.add(error),
      );
      addTearDown(failing.clear);
      final addTodo = Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: slowFail,
        onError: (error, title, context, client) =>
            events.add('onError $title'),
        onSettled: (data, error, title, context, client) =>
            events.add('onSettled $title'),
      );

      final zone = <Object>[];
      runZonedGuarded(
        () => addTodo.mutate('a', failing),
        (error, _) => zone.add(error),
      );
      async.elapse(ms10);

      final run = failing.mutationCache.getAll().single;
      expect(run.state.isError, isTrue);
      expect(run.state.error, isA<StateError>());
      expect(events, [
        'cache onError a',
        'onError a',
        'cache onSettled a',
        'onSettled a',
      ]);
      expect(zone, isEmpty);
      expect(uncaught, isEmpty);
    });

    fakeTest('mutateAsync throws the error', (async) {
      final addTodo = Mutation(mutationFn: slowFail);

      Object? error;
      addTodo.mutateAsync('a', client).then<void>(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      );
      async.elapse(ms10);

      expect(error, isA<StateError>());
      expect(client.mutationCache.getAll().single.state.isError, isTrue);
    });

    fakeTest('keeps no observer, so the cache removes the run after gcTime',
        (async) {
      final addTodo = Mutation(
        mutationFn: (String title) async {
          await Future<void>.delayed(const Duration(minutes: 2));
          return title;
        },
        gcTime: const Duration(minutes: 1),
      );

      addTodo.mutate('a', client);
      // Pending past its gcTime: it is kept until it settles.
      async.elapse(const Duration(minutes: 1, seconds: 30));
      expect(client.mutationCache.getAll().single.state.isPending, isTrue);

      async.elapse(const Duration(seconds: 30));
      expect(client.mutationCache.getAll().single.state.isSuccess, isTrue);
      async.elapse(const Duration(minutes: 1));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('applies the defaults of the client that runs it', (async) {
      var attempts = 0;
      client.setMutationDefaults(
        const ['todos'],
        MutationDefaults(
          retry: const RetryPolicy.count(1),
          retryDelay: (_, __) => ms10,
          gcTime: const Duration(minutes: 1),
        ),
      );
      final addTodo = Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: (String title) async {
          if (++attempts == 1) throw StateError('try again');
          return title;
        },
      );

      addTodo.mutate('a', client);
      async.elapse(ms10);
      expect(attempts, 2);
      expect(client.mutationCache.getAll().single.state.data, 'a');
      async.elapse(const Duration(minutes: 1));
      expect(client.mutationCache.getAll(), isEmpty);
    });

    fakeTest('waits for its turn in a scope', (async) {
      final events = <String>[];
      Future<String> save(String title) async {
        events.add('start $title');
        await Future<void>.delayed(ms10);
        events.add('end $title');
        return title;
      }

      final saveDraft = Mutation(
        mutationFn: save,
        scope: const MutationScope('drafts'),
      );
      // Runs from an observer and from the definition share the queue.
      saveDraft.observe(client: client).mutate('a');
      saveDraft.mutate('b', client);
      saveDraft.mutate('c', client);
      async.flushMicrotasks();
      expect(
        [for (final run in client.mutationCache.getAll()) run.state.isPaused],
        [false, true, true],
      );

      async.elapse(ms10 * 3);
      expect(events, [
        'start a',
        'end a',
        'start b',
        'end b',
        'start c',
        'end c',
      ]);
    });

    fakeTest('pauses offline and runs once the connection is back', (async) {
      onlineManager.setOnline(false);
      final addTodo = Mutation(mutationFn: slowEcho);

      addTodo.mutate('a', client);
      async.elapse(ms10);
      final run = client.mutationCache.getAll().single;
      expect(run.state.isPaused, isTrue);

      onlineManager.setOnline(true);
      async.elapse(ms10);
      expect(run.state.isSuccess, isTrue);
    });

    fakeTest('a NoVariablesMutation runs with mutate() and mutateAsync()',
        (async) {
      final other = QueryClient();
      useAsFueryClient(other);
      var calls = 0;
      final refresh = NoVariablesMutation(
        mutationFn: () async => ++calls,
      );

      refresh.mutate();
      int? data;
      refresh.mutateAsync().then<void>((value) {
        data = value;
      });
      async.flushMicrotasks();
      expect(data, 2);
      expect(other.mutationCache.getAll(), hasLength(2));

      // With a client, the variables come first, as null.
      refresh.mutate(null, client);
      refresh.mutateAsync(null, client).then<void>((value) {
        data = value;
      });
      async.flushMicrotasks();
      expect(data, 4);
      expect(client.mutationCache.getAll(), hasLength(2));
    });

    fakeTest('a NoVariablesMutation reports failures like any other', (async) {
      final logout = NoVariablesMutation(
        mutationFn: () async => throw StateError('offline'),
      );

      final zone = <Object>[];
      Object? error;
      runZonedGuarded(() {
        logout.mutate(null, client);
        logout.mutateAsync(null, client).then<void>(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );
      }, (error, _) => zone.add(error));
      async.flushMicrotasks();

      expect(error, isA<StateError>());
      expect(zone, isEmpty);
      expect(
        [for (final run in client.mutationCache.getAll()) run.state.status],
        [MutationStatus.error, MutationStatus.error],
      );
    });

    fakeTest('a NoVariablesMutation takes no client in place of the variables',
        (async) {
      final other = QueryClient();
      useAsFueryClient(other);
      final logout = NoVariablesMutation(mutationFn: () async => 'bye');

      // `logout.mutate(client)` does not compile. Through the base type,
      // whose variables are `void`, it throws rather than dropping the client
      // and running on Fuery.client.
      final Mutation<String, void, Object?> base = logout;
      // ignore: void_checks
      expect(() => base.mutate(client), throwsA(isA<TypeError>()));
      // ignore: void_checks
      expect(() => base.mutateAsync(client), throwsA(isA<TypeError>()));
      async.flushMicrotasks();
      expect(other.mutationCache.getAll(), isEmpty);
      expect(client.mutationCache.getAll(), isEmpty);

      base.mutate(null, client);
      async.flushMicrotasks();
      expect(client.mutationCache.getAll().single.state.data, 'bye');
    });
  });
}

/// A mutation observer equal to every other of its class with the same key.
class SameKeyMutationObserver
    extends MutationObserver<String, String, Object?> {
  SameKeyMutationObserver(super.client, super.options);

  String get _hash => hashKey(options.mutationKey!);

  @override
  bool operator ==(Object other) =>
      other is SameKeyMutationObserver && other._hash == _hash;

  @override
  int get hashCode => _hash.hashCode;
}
