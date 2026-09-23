# fuery

Flutter layer over `fuery_core`. Keep logic in the core; this package only connects observers to widgets and the app lifecycle.

## Structure

- Every widget (`Query*`, `InfiniteQuery*`, `Mutation*` × `Builder` / `Listener` / `Consumer` / `Selector`) is a thin `StatelessWidget` over `ResultSubscriber`, or `ResultSelector` for selectors, in `lib/src/result_subscriber.dart`. Both render through a core `ObserverSlot`: the widget takes a source (a definition or an observer), creates the slot with `FueryProvider.of(context, listen: true)`, calls `slot.update` in `didUpdateWidget` and when the provided client changes, and disposes it. New widget kinds should reuse them, and nothing here may need API the core hides.
- `FueryBinding.ensureInitialized` initializes the Flutter binding first, so it works when called first in `main`. It maps `AppLifecycleState` to `focusManager`: `resumed` is focused; `hidden`, `paused`, and `detached` are not; `inactive` is ignored.
- `FueryProvider` provides and mounts a `QueryClient`. `FueryProvider.of(context)` and `context.queryClient` fall back to `Fuery.client`; `FueryProvider.of(context, listen: true)` also rebuilds when the provided client is replaced.
- `lib/src/devtools.dart` holds `FueryDevtools` (button and panel over the app, off when `kReleaseMode`) and `FueryDevtoolsPanel`. The panel brings its own `Localizations`, `Theme`, and `Overlay`, so it works in an app's `builder` above the navigator. It rebuilds through `client.watch`, reads the caches, and calls public `QueryClient` methods. It finds a provided client with `FueryProvider.of(context, listen: true)`, so it follows a replaced provider client. The child always stays in the same place in the tree, so toggling `enabled` keeps the app's state.

## Widget semantics

These are covered by tests; keep them:

- `buildWhen(previous, current)` compares against the last built result.
- `listenWhen(previous, current)` compares against the previously received result.
- Listeners are not called for the result that already existed when they mounted.
- Selectors rebuild only when the selected value changes. The value goes through `replaceEqualDeep` and is compared with `identical`, and it is selected again when the parent rebuilds.
- The first frame uses the observer's optimistic result, so a query that is about to fetch shows loading instead of an empty frame.
- After the source or the client changes, the builder takes `slot.result` before it builds, so that frame already shows the new key. Listeners still hear the change when it arrives, never during build.
- Results arrive through `notifyManager.batchCalls`, never synchronously. Don't call `setState` from `build` or `initState`.
- In debug builds, `didUpdateWidget` warns once per key (`debugWarnRecreated`, a `debugPrint`, never an error) when a widget gets a different observer with the same key: that is `observe()` in `build`. Definitions, a different key, or the same instance are silent.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`.
- End each test with `await tester.pumpWidget(const SizedBox())` and `client.clear()`. Otherwise cache timers are still pending and the test fails.
- Keep the example app's tests (`example/test/`) passing when the API changes. It is also the web demo, so it must keep building for the web and must not use plugins without web support. It is a social feed with three tabs; `example/test/helpers.dart` opens a tab or a post, and `DemoApi.reset()` gives each test a fresh server. Queries and mutations live in `example/lib/app/data/`, not in the screens.
- In a cubit or bloc, call `subscription.cancel()` in `close()` without awaiting it. Its future never completes under `testWidgets`, so awaiting it hangs the test.
