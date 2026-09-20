# fuery

Flutter layer over `fuery_core`. Keep logic in the core; this package only connects observers to widgets and the app lifecycle.

## Structure

- Every widget (`Query*`, `InfiniteQuery*`, `Mutation*` × `Builder` / `Listener` / `Consumer` / `Selector`) is a thin `StatelessWidget` over `ResultSubscriber`, or `ResultSelector` for selectors, in `lib/src/result_subscriber.dart`. New widget kinds should reuse them.
- `FueryBinding.ensureInitialized` initializes the Flutter binding first, so it works when called first in `main`. It maps `AppLifecycleState` to `focusManager`: `resumed` is focused; `hidden`, `paused`, and `detached` are not; `inactive` is ignored.
- `FueryProvider` provides and mounts a `QueryClient`. `FueryProvider.of(context)` and `context.queryClient` fall back to `Fuery.client`.
- `lib/src/devtools.dart` holds `FueryDevtools` (button and panel over the app, off when `kReleaseMode`) and `FueryDevtoolsPanel`. The panel brings its own `Localizations`, `Theme`, and `Overlay`, so it works in an app's `builder` above the navigator. It rebuilds through `client.watch`, reads the caches, and calls public `QueryClient` methods. It finds a provided client with `dependOnQueryClient` (hidden from the exports), so it follows a replaced provider client. The child always stays in the same place in the tree, so toggling `enabled` keeps the app's state.

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
- Keep the example app's tests (`example/test/`) passing when the API changes. Its screens are a case gallery opened from the home screen; `example/test/helpers.dart` opens one by its title. Queries and mutations live in `example/lib/app/data/`, not in the screens.
- In a cubit or bloc, call `subscription.cancel()` in `close()` without awaiting it. Its future never completes under `testWidgets`, so awaiting it hangs the test.
