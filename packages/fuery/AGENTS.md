# fuery

Flutter layer over `fuery_core`. Keep logic in the core; this package only connects observers to widgets and the app lifecycle.

## Structure

- Every widget (`Query*`, `InfiniteQuery*`, `Mutation*` × `Builder` / `Listener` / `Consumer` / `Selector`, plus `QueriesBuilder` and `QueriesSelector` over `QueriesSlot`) is a thin `StatelessWidget` over `ResultSubscriber`, or `ResultSelector` for selectors, in `lib/src/result_subscriber.dart`. Both render through a core `ObserverSlot`: the widget takes a source (a definition or an observer), creates the slot with `FueryProvider.of(context, listen: true)`, calls `slot.update` in `didUpdateWidget` and when the provided client changes, reading the provided client again each time, and disposes it. Flutter runs `didUpdateWidget` before `didChangeDependencies`, so a new key and a new client in one frame must reach the slot together. New widget kinds should reuse them, and nothing here may need API the core hides.
- `FueryBinding.ensureInitialized` initializes the Flutter binding first, so it works when called first in `main`. It maps `AppLifecycleState` to `focusManager`: `resumed` is focused; `hidden`, `paused`, and `detached` are not; `inactive` is ignored.
- `FueryProvider` provides and mounts a `QueryClient`. `FueryProvider.of(context)` and `context.queryClient` fall back to `Fuery.client`; `FueryProvider.of(context, listen: true)` also rebuilds when the provided client is replaced.
- `lib/src/devtools.dart` holds `FueryDevtools` (button and panel over the app, off when `kReleaseMode`) and `FueryDevtoolsPanel`. The panel brings its own `Localizations`, `Theme`, and `Overlay`, so it works in an app's `builder` above the navigator. It rebuilds through `client.watch`, reads the caches, and calls public `QueryClient` methods. It finds a provided client with `FueryProvider.of(context, listen: true)`, so it follows a replaced provider client. The child always stays in the same place in the tree, so toggling `enabled` keeps the app's state. The panel builds its overlay with `Overlay.wrap`, which disposes the entry. `FueryDevtools` sizes the open panel to 55% of the screen above the keyboard's `viewInsets`, and shrinks it only when that doesn't fit, down to 120 dp for its tabs and filter field. With less room above the keyboard, the panel goes under it instead of overflowing. In the Queries tab the list stays the first child of its `Flex` whether or not a query is selected, so selecting or removing a query keeps its scroll position.

## Widget semantics

These are covered by tests; keep them:

- `buildWhen(previous, current)` compares against the last built result.
- `listenWhen(previous, current)` compares against the previously received result.
- Listeners are not called for the result that already existed when they mounted.
- Listeners hear changes through the core's `slot.listen`, registered when the slot is created and before the widget subscribes to rebuild, so the listener runs before the rebuild that shows the change. A listener that throws is reported to the client's `onUncaughtError` and doesn't stop the rebuild. A listener doesn't hear the slot moving to another observer, as when the provided client is replaced.
- Selectors rebuild only when the selected value changes. The value goes through `replaceEqualDeep` and is compared with `identical`, and it is selected again when the parent rebuilds.
- The first frame uses the observer's optimistic result, so a query that is about to fetch shows loading instead of an empty frame.
- After the source or the client changes, the builder takes `slot.result` before it builds, so that frame already shows the new key. Listeners still hear the change when it arrives, never during build.
- Results arrive through `notifyManager.batchCalls`, never synchronously. Don't call `setState` from `build` or `initState`.
- In debug builds, `didUpdateWidget` warns once per kind and key (`debugWarnRecreated`, a `debugPrint`, never an error) when a widget gets a different observer with the same key and client: that is `observe()` in `build`. Each widget passes its name (`debugName`) and a `DebugRecreatedKey`. For `QueriesBuilder` and `QueriesSelector`, the key is that of a new observer in the list whose key an observer in the previous list had. Definitions, a different key, reordering, the same instances, and a new observer of another client (as after the provided client is replaced) are silent. The message says a query observer refetches and a mutation observer starts idle.
- In debug builds, a `MutationListener` given a `Mutation` definition warns once (`debugWarnMutationDefinition`), because nothing can run its observer. Builders, consumers, and selectors don't warn, because they can run the mutation themselves.
- In debug builds, a widget warns once per widget name and key, or once per widget name for a mutation without a key (`debugWarnOtherClient`), so observers created in `build` warn once, when its source holds an observer, or a list entry, of another client than the one it uses. The check runs when the slot is created and after every update. It compares with the widget's client, never with `Fuery.client`.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`.
- End each test with `await tester.pumpWidget(const SizedBox())` and `client.clear()`. Otherwise cache timers are still pending and the test fails.
- Keep the example app's tests (`example/test/`) passing when the API changes. It is also the web demo, so it must keep building for the web and must not use plugins without web support. It is a social feed with three tabs; `example/test/helpers.dart` opens a tab or a post, and `DemoApi.reset()` gives each test a fresh server. Queries and mutations live in `example/lib/app/data/`, not in the screens.
- In a cubit or bloc, call `subscription.cancel()` in `close()` without awaiting it. Its future never completes under `testWidgets`, so awaiting it hangs the test.
