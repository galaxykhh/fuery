---
title: Testing
description: Test Flutter widgets, blocs, and queries that use a cache, with fake time and a fresh client.
---

Tests need an empty cache and control over time. Give each test a fresh `QueryClient` with retries turned off, and run it on a fake clock.

## Testing widgets

Give each test a fresh client, and turn off retries so a failure shows at once:

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

- **Pump the time your fake API takes.** A fake that answers at once needs only `await tester.pump()`.
- **End each test by unmounting the widgets and calling `client.clear()`.** Otherwise the cache's garbage collection timers are still pending, and [the test fails](../../troubleshooting/#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed).
- **Only queries need retries turned off.** Mutations don't retry unless you set `retry`, so `QueryDefaults` is enough. Add `mutations: MutationDefaults(...)` only when a test needs a mutation default of its own.
- **`FueryProvider` works too.** Widgets use the client of the nearest `FueryProvider`, so `FueryProvider(client: client, child: const App())` can replace assigning `Fuery.client`. `observe()` and a definition's `mutate` still use `Fuery.client` unless you pass a client, so an observer that the test or a cubit creates needs `observe(client: client)`, and a run needs `addTodo.mutate('Buy milk', client)`.
- **Create observers inside the test.** An observer keeps its client, so one created at the top level of a file [keeps the first test's client](../../troubleshooting/#a-test-passes-only-when-it-runs-first).

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
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => ['Buy milk'],
    ).observe(client: client);

    final subscription = todos.stream.listen((_) {});
    async.flushMicrotasks();
    expect(todos.result.data, ['Buy milk']);

    subscription.cancel();
    client.clear();
  });
});
```

Listening to `stream` subscribes the observer and starts the fetch. For a fake that waits, advance the clock with `async.elapse(...)` instead of `flushMicrotasks()`.

## Testing cubits and blocs

Test a cubit or a bloc that uses queries in `testWidgets` or `fakeAsync`, like the tests above.

- **Call `subscription.cancel()` in `close()` without `await`.** Under a fake clock, the future that `cancel()` returns never completes, and the test hangs.
- **Close the cubit before `client.clear()`.** `clear()` moves an observer that is still subscribed to a new query, which loads again.

## Testing the app in the background

`focusManager.setFocused(false)` makes Fuery treat the app as [in the background](../lifecycle/#when-the-app-resumes): retries wait, and polling pauses unless `refetchIntervalInBackground` is set. `focusManager.setFocused(null)` hands focus back to the app lifecycle, and Fuery refetches the stale queries in use.

Every test in a file shares `focusManager`, so reset it in a tear-down. A tear-down runs after the widgets are gone, and it runs even when the test fails:

```dart
addTearDown(() => focusManager.setFocused(null));
```

## In the example app

The example's tests open a tab or a post with [a small helper](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test/helpers.dart), and its [test folder](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test) has a widget test per screen.
