import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  setUp(resetManagers);

  group('AbortSignal', () {
    test('notifies listeners once and reports the reason', () async {
      final controller = AbortController();
      final signal = controller.signal;
      var calls = 0;
      signal.onAbort(() => calls++);
      final removed = signal.onAbort(() => calls += 100);
      removed();

      expect(signal.aborted, isFalse);
      expect(signal.throwIfAborted, returnsNormally);

      controller.abort('stop');
      controller.abort('again');

      expect(signal.aborted, isTrue);
      expect(signal.reason, 'stop');
      expect(calls, 1);
      expect(signal.throwIfAborted, throwsA('stop'));
      await signal.whenAborted;
    });

    test('calls late listeners right away', () async {
      final controller = AbortController()..abort();
      var called = false;
      final remove = controller.signal.onAbort(() => called = true);
      remove();

      expect(called, isTrue);
      expect(controller.signal.reason, isA<AbortedException>());
      expect(controller.signal.reason.toString(), contains('aborted'));
    });

    test('whenAborted completes on abort', () {
      fakeAsync((async) {
        final controller = AbortController();
        var done = false;
        controller.signal.whenAborted.then((_) => done = true);
        async.flushMicrotasks();
        expect(done, isFalse);

        controller.abort();
        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });
  });

  group('NotifyManager', () {
    test('batches notifications until the outermost batch ends', () {
      fakeAsync((async) {
        final manager = NotifyManager();
        final calls = <int>[];
        final notify = manager.batchCalls<int>(calls.add);

        manager.batch(() {
          notify(1);
          manager.batch(() => notify(2));
          async.flushMicrotasks();
          expect(calls, isEmpty);
        });
        async.flushMicrotasks();
        expect(calls, [1, 2]);

        notify(3);
        expect(calls, [1, 2]);
        async.flushMicrotasks();
        expect(calls, [1, 2, 3]);
      });
    });

    test('uses custom scheduler and notify functions', () {
      final manager = NotifyManager();
      final events = <String>[];
      manager
        ..setScheduler((callback) {
          events.add('schedule');
          callback();
        })
        ..setBatchNotifyFunction((callback) {
          events.add('batch');
          callback();
        })
        ..setNotifyFunction((callback) {
          events.add('notify');
          callback();
        });

      manager.batch(() => manager.schedule(() => events.add('run')));

      expect(events, ['schedule', 'batch', 'notify', 'run']);
    });

    test('returns the batch result', () {
      expect(NotifyManager().batch(() => 42), 42);
    });
  });

  group('FocusManager', () {
    test('uses the event source passed to setEventListener', () {
      final manager = FocusManager();
      void Function([bool? focused])? setFocused;
      var cleanedUp = false;
      manager.setEventListener((callback) {
        setFocused = callback;
        return () => cleanedUp = true;
      });

      final events = <bool>[];
      final unsubscribe = manager.subscribe(events.add);

      setFocused!(false);
      setFocused!(false);
      setFocused!();
      setFocused!(true);

      expect(events, [false, false, true]);
      expect(manager.isFocused(), isTrue);

      unsubscribe();
      expect(cleanedUp, isTrue);
    });

    test('is focused by default', () {
      expect(FocusManager().isFocused(), isTrue);
    });
  });

  group('OnlineManager', () {
    test('uses the event source passed to setEventListener', () {
      final manager = OnlineManager();
      late void Function(bool online) setOnline;
      var cleanedUp = false;
      manager.setEventListener((callback) {
        setOnline = callback;
        return () => cleanedUp = true;
      });

      final events = <bool>[];
      final unsubscribe = manager.subscribe(events.add);
      setOnline(false);
      setOnline(false);
      setOnline(true);

      expect(events, [false, true]);
      unsubscribe();
      expect(cleanedUp, isTrue);
    });
  });

  group('RetryPolicy', () {
    test('decides by count, predicate, or always', () {
      final error = StateError('x');
      expect(const RetryPolicy.count(2).shouldRetry(1, error), isTrue);
      expect(const RetryPolicy.count(2).shouldRetry(2, error), isFalse);
      expect(const RetryPolicy.never().shouldRetry(0, error), isFalse);
      expect(const RetryPolicy.always().shouldRetry(1000, error), isTrue);
      expect(
        RetryPolicy.when((count, e) => e is StateError && count < 1)
            .shouldRetry(0, error),
        isTrue,
      );
    });

    test('backs off exponentially up to 30 seconds', () {
      final error = StateError('x');
      expect(defaultRetryDelay(0, error), const Duration(seconds: 1));
      expect(defaultRetryDelay(3, error), const Duration(seconds: 8));
      expect(defaultRetryDelay(10, error), const Duration(seconds: 30));
    });

    test('CancelledError describes its options', () {
      expect(
        const CancelledError(revert: true).toString(),
        'CancelledError(revert: true, silent: false)',
      );
    });
  });

  group('Fuery.instance', () {
    test('is created lazily and can be replaced', () {
      final original = Fuery.instance;
      expect(Fuery.instance, same(original));

      final replacement = QueryClient();
      Fuery.instance = replacement;
      expect(Fuery.instance, same(replacement));

      Fuery.instance = original;
    });

    fakeTest('is used by the entry points when no client is given', (async) {
      final original = Fuery.instance;
      final client = QueryClient();
      Fuery.instance = client;
      addTearDown(() {
        client.clear();
        Fuery.instance = original;
      });

      final query = Query.use(queryKey: ['a'], queryFn: (_) async => 'a');
      final pages = InfiniteQuery.use(
        queryKey: ['b'],
        queryFn: (context) async => context.pageParam,
        initialPageParam: 1,
        getNextPageParam: (_) => null,
      );
      final mutation = Mutation.use(mutationFn: (int x) async => x);
      final noParam = Mutation.noParam(mutationFn: () async => 1);
      query.subscribe((_) {});
      pages.subscribe((_) {});
      mutation.mutate(1);
      noParam.mutate();
      async.flushMicrotasks();

      expect(client.getQueryData<String>(['a']), 'a');
      expect(client.queryCache.getAll(), hasLength(2));
      expect(client.mutationCache.getAll(), hasLength(2));
    });
  });

  group('value objects', () {
    test('QueryState compares by value', () {
      const a = QueryState<String>(data: 'x');
      const b = QueryState<String>(data: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(isInvalidated: true)));
      expect(a.copyWith(data: null).data, isNull);
      expect(a.toString(), contains('pending'));
    });

    test('QueryResult compares by value', () {
      QueryResult<String> result({String? data}) => QueryResult<String>(
            status: QueryStatus.success,
            fetchStatus: FetchStatus.idle,
            data: data,
            dataUpdatedAt: 1,
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
      expect(result(data: 'x'), result(data: 'x'));
      expect(result(data: 'x').hashCode, result(data: 'x').hashCode);
      expect(result(data: 'x'), isNot(result(data: 'y')));
      expect(result(data: 'x').toString(), contains('success'));
    });

    test('MutationState compares by value', () {
      const a = MutationState<int, String, void>(data: 1, variables: 'v');
      const b = MutationState<int, String, void>(data: 1, variables: 'v');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(variables: 'w')));
      expect(a.toString(), contains('idle'));
    });

    test('InfiniteData compares pages deeply', () {
      const a = InfiniteData(pages: [
        [1, 2],
      ], pageParams: [
        0,
      ]);
      final b = InfiniteData(pages: [
        [1, 2],
      ], pageParams: [
        0,
      ]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.firstPage, [1, 2]);
      expect(a.lastPage, [1, 2]);
      expect(a.firstPageParam, 0);
      expect(a.lastPageParam, 0);
      expect(a.toString(), contains('pages'));
    });

    test('FetchMeta compares by direction', () {
      const forward = FetchMeta(direction: FetchDirection.forward);
      expect(forward, const FetchMeta(direction: FetchDirection.forward));
      expect(forward.hashCode, FetchDirection.forward.hashCode);
      expect(forward, isNot(const FetchMeta()));
    });

    test('status enums expose flags', () {
      expect(QueryStatus.error.isError, isTrue);
      expect(QueryStatus.success.isSuccess, isTrue);
      expect(QueryStatus.pending.isPending, isTrue);
      expect(FetchStatus.fetching.isFetching, isTrue);
      expect(FetchStatus.paused.isPaused, isTrue);
      expect(FetchStatus.idle.isIdle, isTrue);
      expect(MutationStatus.idle.isIdle, isTrue);
      expect(MutationStatus.pending.isPending, isTrue);
      expect(MutationStatus.success.isSuccess, isTrue);
      expect(MutationStatus.error.isError, isTrue);
    });
  });

  test('uncaught callback errors reach the zone', () async {
    final errors = <Object>[];
    await runZonedGuarded(
      () async {
        final client = QueryClient();
        final mutation = Mutation.use(
          mutationFn: (int x) async => throw StateError('mutation'),
          onError: (_, __, ___) => throw StateError('callback'),
          client: client,
        );
        await mutation.mutateAsync(1).then((_) {}, onError: (_) {});
      },
      (error, _) => errors.add(error),
    );

    expect(errors.single, isA<StateError>());
    expect((errors.single as StateError).message, 'callback');
  });
}
