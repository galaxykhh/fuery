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
    final observer = Mutation.use(mutationFn: slowEcho, client: client);
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
    final observer = Mutation.use(
      mutationFn: (String value) async {
        events.add('mutationFn');
        return value;
      },
      onMutate: (value) {
        events.add('onMutate');
        return 'context';
      },
      onSuccess: (data, variables, context) {
        events.add('onSuccess $data $variables $context');
      },
      onSettled: (data, error, variables, context) {
        events.add('onSettled $data $error');
      },
      client: client,
    );

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

    final observer = Mutation.use(
      mutationFn: slowFail,
      onMutate: (removed) {
        final previous = client.getQueryData<List<String>>(['todos']);
        client.updateQueryData<List<String>>(
          ['todos'],
          (todos) => todos?.where((t) => t != removed).toList(),
        );
        return previous;
      },
      onError: (error, variables, previous) {
        client.setQueryData<List<String>>(['todos'], previous!);
      },
      client: client,
    );

    observer.mutate('a');
    async.flushMicrotasks();
    expect(client.getQueryData<List<String>>(['todos']), ['b']);

    async.elapse(ms10);
    expect(client.getQueryData<List<String>>(['todos']), ['a', 'b']);
  });

  fakeTest('mutate reports failures without throwing', (async) {
    final observer = Mutation.use(mutationFn: slowFail, client: client);
    observer.subscribe((_) {});

    observer.mutate('a');
    async.elapse(ms10);

    expect(observer.result.isError, isTrue);
    expect(observer.result.error, isA<StateError>());
    expect(observer.result.failureCount, 1);
  });

  fakeTest('mutateAsync throws the error', (async) {
    final observer = Mutation.use(mutationFn: slowFail, client: client);

    Object? error;
    observer.mutateAsync('a').catchError((Object e) {
      error = e;
      return '';
    });
    async.elapse(ms10);

    expect(error, isA<StateError>());
  });

  fakeTest('noParam mutations run with mutate()', (async) {
    var calls = 0;
    final observer = Mutation.noParam(
      mutationFn: () async => ++calls,
      client: client,
    );

    observer.mutate();
    async.flushMicrotasks();
    expect(observer.result.data, 1);

    int? data;
    observer.mutateAsync().then((value) => data = value);
    async.flushMicrotasks();
    expect(data, 2);
  });

  fakeTest('noParam mutations report failures', (async) {
    final observer = Mutation.noParam(
      mutationFn: () async => throw StateError('boom'),
      client: client,
    );

    observer.mutate();
    async.flushMicrotasks();

    expect(observer.result.isError, isTrue);
  });

  fakeTest('retries when retry is set', (async) {
    var attempts = 0;
    final observer = Mutation.use(
      mutationFn: (String value) async {
        attempts++;
        if (attempts < 3) throw StateError('try again');
        return value;
      },
      retry: const RetryPolicy.count(2),
      retryDelay: (_, __) => ms10,
      client: client,
    );

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

    final first = Mutation.use(
      mutationFn: run,
      scope: const MutationScope('todos'),
      client: client,
    );
    final second = Mutation.use(
      mutationFn: run,
      scope: const MutationScope('todos'),
      client: client,
    );

    first.mutate('a');
    second.mutate('b');
    async.elapse(const Duration(milliseconds: 30));

    expect(events, ['start a', 'end a', 'start b', 'end b']);
  });

  fakeTest('per-call callbacks run while the observer has listeners', (async) {
    final observer = Mutation.use(mutationFn: slowEcho, client: client);
    final events = <String>[];
    observer.subscribe((_) {});

    observer.mutate(
      'a',
      MutateOptions(
        onSuccess: (data, _, __) => events.add('success $data'),
        onSettled: (data, _, variables, __) => events.add('settled $variables'),
      ),
    );
    async.elapse(ms10);

    expect(events, ['success a', 'settled a']);
  });

  fakeTest('reset returns to idle', (async) {
    final observer = Mutation.use(mutationFn: slowEcho, client: client);
    observer.subscribe((_) {});
    observer.mutate('a');
    async.elapse(ms10);

    observer.reset();
    expect(observer.result.isIdle, isTrue);
    expect(observer.result.data, isNull);
  });

  fakeTest('removes finished mutations after gcTime', (async) {
    final observer = Mutation.use(
      mutationFn: slowEcho,
      gcTime: const Duration(minutes: 1),
      client: client,
    );
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
    final observer = Mutation.use(mutationFn: slowEcho, client: client);
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
    final observer = Mutation.use(
      mutationFn: slowEcho,
      mutationKey: ['todos', 'add'],
      client: client,
    );
    observer.mutate('a');
    async.flushMicrotasks();

    expect(client.isMutating(), 1);
    expect(client.isMutating(mutationKey: ['todos']), 1);
    expect(client.isMutating(mutationKey: ['posts']), 0);
    async.elapse(ms10);
    expect(client.isMutating(), 0);
  });

  fakeTest('stream sends the current state first, then changes', (async) {
    final observer = Mutation.use(mutationFn: slowEcho, client: client);
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
    fakeTest('noParam callbacks receive data, error, and context', (async) {
      final events = <String>[];
      var fail = false;
      final observer = Mutation.noParam(
        mutationFn: () async {
          if (fail) throw StateError('boom');
          return 1;
        },
        onMutate: () => 'ctx',
        onSuccess: (data, context) => events.add('success $data $context'),
        onError: (error, context) => events.add('error $context'),
        onSettled: (data, error, context) =>
            events.add('settled $data ${error != null}'),
        client: client,
      );

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

    fakeTest('fails without a mutationFn', (async) {
      final observer = MutationObserver<int, int, void>(
        client,
        const MutationOptions(),
      );
      observer.mutate(1);
      async.flushMicrotasks();

      expect(observer.result.error, isA<StateError>());
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
      final observer = Mutation.use(
        mutationFn: (int x) async {
          if (x < 0) throw StateError('negative');
          return x;
        },
        client: client,
      );

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
      final observer = Mutation.use(
        mutationFn: (int x) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return x;
        },
        gcTime: ms10,
        client: client,
      );
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
      final observer = Mutation.use(
        mutationFn: (int x) async => x,
        mutationKey: ['a'],
        client: client,
      );
      observer.mutate(1);
      async.flushMicrotasks();
      expect(observer.result.isSuccess, isTrue);

      observer.setOptions(MutationOptions(
        mutationFn: (int x) async => x,
        mutationKey: ['b'],
      ));
      expect(observer.result.isIdle, isTrue);
    });

    fakeTest('new options apply to a pending mutation', (async) {
      final events = <String>[];
      final observer = Mutation.use(
        mutationFn: (int x) async {
          await Future<void>.delayed(ms10);
          return x;
        },
        onSuccess: (_, __, ___) => events.add('old'),
        client: client,
      );
      observer.mutate(1);
      async.flushMicrotasks();

      observer.setOptions(MutationOptions(
        mutationFn: (int x) async => x,
        onSuccess: (_, __, ___) => events.add('new'),
      ));
      async.elapse(ms10);

      expect(events, ['new']);
    });

    fakeTest('a listener added after mutate sees the mutation', (async) {
      final observer = Mutation.use(
        mutationFn: (int x) async {
          await Future<void>.delayed(ms10);
          return x;
        },
        client: client,
      );
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
      final observer = Mutation.use(mutationFn: slowFail, client: client);
      final events = <String>[];
      observer.subscribe((_) {});

      observer.mutate(
        'a',
        MutateOptions(
          onError: (error, variables, _) => events.add('error $variables'),
          onSettled: (data, error, variables, _) =>
              events.add('settled $variables'),
        ),
      );
      async.elapse(ms10);

      expect(events, ['error a', 'settled a']);
    });

    fakeTest('errors thrown by callbacks are reported, not swallowed', (async) {
      final errors = <Object>[];
      runZonedGuarded(() {
        final observer = Mutation.use(
          mutationFn: slowEcho,
          client: client,
        );
        observer.subscribe((_) {});
        observer.mutate(
          'a',
          MutateOptions(onSuccess: (_, __, ___) => throw StateError('cb')),
        );
      }, (error, _) => errors.add(error));
      async.elapse(ms10);

      expect(errors.single, isA<StateError>());
    });

    fakeTest('filters mutations by key, status, and predicate', (async) {
      final add = Mutation.use(
        mutationFn: (int x) async => x,
        mutationKey: ['todos', 'add'],
        client: client,
      );
      final remove = Mutation.use(
        mutationFn: (int x) async => x,
        mutationKey: ['todos', 'remove'],
        meta: {'kind': 'remove'},
        client: client,
      );
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
      final observer = Mutation.use(
        mutationFn: (int x) async => x,
        scope: const MutationScope('todos'),
        gcTime: ms10,
        client: client,
      );
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
