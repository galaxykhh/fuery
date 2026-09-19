# fuery

Flutter layer over `fuery_core`. Keep logic in the core; this package only connects observers to widgets and the app lifecycle.

## Structure

- Every widget (`Query*`, `InfiniteQuery*`, `Mutation*` × `Builder` / `Listener` / `Consumer` / `Selector`) is a thin `StatelessWidget` over `ResultSubscriber`, or `ResultSelector` for selectors, in `lib/src/result_subscriber.dart`. New widget kinds should reuse them.
- `FueryBinding` maps `AppLifecycleState` to `focusManager`: `resumed` is focused; `hidden`, `paused`, and `detached` are not; `inactive` is ignored.
- `FueryProvider` provides and mounts a `QueryClient`. `FueryProvider.of(context)` and `context.queryClient` fall back to `Fuery.instance`.

## Widget semantics

These are covered by tests; keep them:

- `buildWhen(previous, current)` compares against the last built result.
- `listenWhen(previous, current)` compares against the previously received result.
- Listeners are not called for the result that already existed when they mounted.
- Selectors rebuild only when the selected value changes. The value goes through `replaceEqualDeep` and is compared with `identical`, and it is selected again when the parent rebuilds.
- The first frame uses the observer's optimistic result, so a query that is about to fetch shows loading instead of an empty frame.
- Results arrive through `notifyManager.batchCalls`, never synchronously. Don't call `setState` from `build` or `initState`.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`.
- End each test with `await tester.pumpWidget(const SizedBox())` and `client.clear()`. Otherwise cache timers are still pending and the test fails.
- Keep the example app's tests (`example/test/`) passing when the API changes.
- In a cubit or bloc, call `subscription.cancel()` in `close()` without awaiting it. Its future never completes under `testWidgets`, so awaiting it hangs the test.
