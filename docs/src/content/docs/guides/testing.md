---
title: Testing
description: Test widgets, blocs, and queries that use Fuery.
---

## Widget tests

Give each test a fresh client, and turn off retries so failures show up immediately:

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  await tester.pumpWidget(FueryProvider(client: client, child: const App()));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  client.clear();
});
```

- Pump the time your fake API takes, or `await tester.pump()` for instant fakes.
- End each test by unmounting the widgets and calling `client.clear()`. Otherwise cache timers are still pending and the test fails.
- Queries must use the provided client, for example with `client: context.queryClient`.

## Testing without widgets

Add [`fake_async`](https://pub.dev/packages/fake_async) as a dev dependency to control time in plain Dart tests:

```dart
test('loads todos', () {
  fakeAsync((async) {
    final client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
    final todos = Query.use(
      queryKey: ['todos'],
      queryFn: (_) async => ['Buy milk'],
      client: client,
    );

    final subscription = todos.stream.listen((_) {});
    async.flushMicrotasks();
    expect(todos.result.data, ['Buy milk']);

    subscription.cancel();
    client.clear();
  });
});
```

## Cubits and blocs

Cubits and blocs that use queries work in `testWidgets` or `fakeAsync` as well. In their `close()`, call `subscription.cancel()` without awaiting it. The future it returns doesn't complete in these fake clocks.
