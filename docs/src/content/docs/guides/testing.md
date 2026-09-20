---
title: Testing
description: Test Flutter widgets, blocs, and queries that use a cache, with fake time and a fresh client.
---

Tests need two things from Fuery: a cache that starts empty, and control over
time. This page shows both, for widgets, for plain Dart, and for blocs.

## Testing widgets

Give each test a fresh client, and turn off retries so failures show up immediately:

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  Fuery.client = client;
  await tester.pumpWidget(const App());
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  client.clear();
});
```

Mutations don't retry unless you ask them to, so `QueryDefaults` is enough. Add `mutations: MutationDefaults(...)` when a test sets a mutation default of its own.

To test what happens when the app leaves the foreground, tell the focus manager: `focusManager.setFocused(false)`, then `setFocused(null)` to hand control back to the app lifecycle.

- Pump the time your fake API takes, or `await tester.pump()` for instant fakes.
- End each test by unmounting the widgets and calling `client.clear()`. Otherwise cache timers are still pending and the test fails.
- Queries and mutations without a `client:` argument use `Fuery.client`. If your widgets pass `client: context.queryClient`, wrap the app in `FueryProvider(client: client, child: const App())` instead.

## Testing without a widget tree

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

## Testing cubits and blocs

Cubits and blocs that use queries work in `testWidgets` or `fakeAsync` as well. In their `close()`, call `subscription.cancel()` without awaiting it. The future it returns doesn't complete in these fake clocks.

## In the example app

The example's tests open one case at a time with [a small helper](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test/helpers.dart), and its [test folder](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test) has a widget test per case.
