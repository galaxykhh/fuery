import 'dart:async';

import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late QueryClient client;

  setUp(() {
    resetManagers();
    client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    )..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  /// Streams each fetch from a new controller, collected in [controllers].
  QueryObserver<String> answer(
    List<StreamController<String>> controllers, {
    QueryKey queryKey = const ['answer'],
    StreamRefetchMode refetchMode = StreamRefetchMode.reset,
    bool readsSignal = false,
  }) {
    return Query.use(
      queryKey: queryKey,
      queryFn: streamedQuery(
        stream: (context) {
          if (readsSignal) context.signal;
          final controller = StreamController<String>();
          controllers.add(controller);
          return controller.stream;
        },
        initialValue: '',
        combine: (text, token) => text + token,
        refetchMode: refetchMode,
      ),
      client: client,
    );
  }

  fakeTest('shows chunks as they arrive until the stream is done', (async) {
    final controllers = <StreamController<String>>[];
    final observer = answer(controllers)..subscribe((_) {});
    async.flushMicrotasks();
    expect(observer.result.isPending, isTrue);
    expect(observer.result.isFetching, isTrue);

    controllers.single.add('Hel');
    async.flushMicrotasks();
    expect(observer.result.data, 'Hel');
    expect(observer.result.isSuccess, isTrue);
    expect(observer.result.isFetching, isTrue);

    controllers.single.add('lo');
    async.flushMicrotasks();
    expect(observer.result.data, 'Hello');

    controllers.single.close();
    async.flushMicrotasks();
    expect(observer.result.data, 'Hello');
    expect(observer.result.isFetching, isFalse);
  });

  fakeTest('an empty stream succeeds with the initial value', (async) {
    final observer = Query.use(
      queryKey: ['empty'],
      queryFn: streamedQuery(
        stream: (context) => const Stream<String>.empty(),
        initialValue: 'nothing',
        combine: (text, token) => text + token,
      ),
      client: client,
    )..subscribe((_) {});
    async.flushMicrotasks();

    expect(observer.result.data, 'nothing');
    expect(observer.result.isFetching, isFalse);
  });

  group('refetching', () {
    fakeTest('reset clears the data and streams from the start', (async) {
      final controllers = <StreamController<String>>[];
      final observer = answer(controllers)..subscribe((_) {});
      async.flushMicrotasks();
      controllers[0]
        ..add('a')
        ..close();
      async.flushMicrotasks();

      observer.refetch();
      async.flushMicrotasks();
      expect(observer.result.data, isNull);
      expect(observer.result.isPending, isTrue);

      controllers[1]
        ..add('b')
        ..close();
      async.flushMicrotasks();
      expect(observer.result.data, 'b');
    });

    fakeTest('append folds the new stream onto the data', (async) {
      final controllers = <StreamController<String>>[];
      final observer = answer(
        controllers,
        refetchMode: StreamRefetchMode.append,
      )..subscribe((_) {});
      async.flushMicrotasks();
      controllers[0]
        ..add('a')
        ..close();
      async.flushMicrotasks();

      observer.refetch();
      async.flushMicrotasks();
      expect(observer.result.data, 'a');

      controllers[1]
        ..add('b')
        ..close();
      async.flushMicrotasks();
      expect(observer.result.data, 'ab');
    });

    fakeTest('replace keeps the data until the new stream is done', (async) {
      final controllers = <StreamController<String>>[];
      final observer = answer(
        controllers,
        refetchMode: StreamRefetchMode.replace,
      )..subscribe((_) {});
      async.flushMicrotasks();
      controllers[0]
        ..add('a')
        ..close();
      async.flushMicrotasks();

      observer.refetch();
      controllers[1].add('b');
      async.flushMicrotasks();
      expect(observer.result.data, 'a');
      expect(observer.result.isFetching, isTrue);

      controllers[1]
        ..add('c')
        ..close();
      async.flushMicrotasks();
      expect(observer.result.data, 'bc');
    });
  });

  group('errors', () {
    fakeTest('a stream error fails the query', (async) {
      final controllers = <StreamController<String>>[];
      final observer = answer(controllers)..subscribe((_) {});
      async.flushMicrotasks();

      controllers.single
        ..add('a')
        ..addError(StateError('lost connection'));
      async.flushMicrotasks();
      expect(observer.result.isError, isTrue);
      expect(observer.result.error, isA<StateError>());
      expect(observer.result.data, 'a');
      expect(controllers.single.hasListener, isFalse);
    });

    fakeTest('an error in combine fails the query', (async) {
      final controller = StreamController<String>();
      final observer = Query.use(
        queryKey: ['answer'],
        queryFn: streamedQuery(
          stream: (context) => controller.stream,
          initialValue: '',
          combine: (String text, String token) =>
              token == 'bad' ? throw FormatException(token) : text + token,
        ),
        client: client,
      )..subscribe((_) {});
      async.flushMicrotasks();

      controller.add('bad');
      async.flushMicrotasks();
      expect(observer.result.error, isA<FormatException>());
      expect(controller.hasListener, isFalse);
    });

    fakeTest('handles a stream that fails while it is listened to', (async) {
      final controller = StreamController<String>(sync: true);
      controller.onListen = () => controller.add('bad');
      final observer = Query.use(
        queryKey: ['answer'],
        queryFn: streamedQuery(
          stream: (context) => controller.stream,
          initialValue: '',
          combine: (String text, String token) => throw FormatException(token),
        ),
        client: client,
      )..subscribe((_) {});
      async.flushMicrotasks();

      expect(observer.result.error, isA<FormatException>());
      expect(controller.hasListener, isFalse);
    });
  });

  group('cancelling', () {
    fakeTest('stops the stream when the fetch is cancelled', (async) {
      final controllers = <StreamController<String>>[];
      final observer = answer(controllers)..subscribe((_) {});
      async.flushMicrotasks();
      controllers.single.add('a');
      async.flushMicrotasks();

      client.cancelQueries(queryKey: ['answer']);
      async.flushMicrotasks();
      expect(controllers.single.hasListener, isFalse);
      expect(observer.result.data, 'a');
      expect(observer.result.isFetching, isFalse);
    });

    fakeTest('keeps streaming after the last listener leaves', (async) {
      final controllers = <StreamController<String>>[];
      final unsubscribe = answer(controllers).subscribe((_) {});
      async.flushMicrotasks();
      controllers.single.add('a');
      async.flushMicrotasks();

      unsubscribe();
      controllers.single
        ..add('b')
        ..close();
      async.flushMicrotasks();
      expect(client.getQueryData<String>(['answer']), 'ab');
    });

    fakeTest('stops on unmount when the stream reads the signal', (async) {
      final controllers = <StreamController<String>>[];
      final unsubscribe =
          answer(controllers, readsSignal: true).subscribe((_) {});
      async.flushMicrotasks();
      controllers.single.add('a');
      async.flushMicrotasks();

      unsubscribe();
      async.flushMicrotasks();
      expect(controllers.single.hasListener, isFalse);
      expect(client.getQueryData<String>(['answer']), 'a');
    });
  });
}
