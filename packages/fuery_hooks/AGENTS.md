# fuery_hooks

Hooks over `fuery`, for apps built with `flutter_hooks`. Fuery's own style is the widgets of `fuery`, which follow Flutter's conventions; this package serves developers who prefer hooks. Keep it thin: every hook renders through a core slot, as the widgets do, with public API only. When a hook needs something `fuery` or `fuery_core` hides, make it public there instead of working around it.

## Structure

- `lib/src/hooks.dart`: `useQuery`, `useInfiniteQuery`, `useMutation`, and `useQueries` are `_SlotHook`s over `QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`, and `QueriesSlot`. `useQueryClient` reads `FueryProvider.of(context, listen: true)`. `useQuery`, `useInfiniteQuery`, and `useMutation` pass their optional `listener` (a `ResultWidgetListener`, as the widgets take) and `listenWhen` to `_SlotHook`, which listens through the core's `slot.listen`; a new hook over a slot takes the same two parameters the same way. `useQueries` has no listener, as there is no widget with one for a list.
- `lib/fuery_hooks.dart` re-exports `fuery`. It hides `debugResetHookWarnings`, which only tests use, and Fuery's `FocusManager` class, whose name Flutter uses too; the `focusManager` singleton stays exported.
- `example/main.dart` is the example pub.dev shows. It is analyzed with the package, so it must compile.

## Hook semantics

These match the widgets and are covered by tests; keep them:

- A build with a new source or client calls `slot.update`, and every build returns `slot.result`, so a new key shows in the same frame. A rebuild with the same source and client, such as one a result caused, skips the update.
- A result that arrives after the hook was disposed, as a hot reload can do while the widget stays, is ignored.
- Results arrive through `notifyManager.batchCalls`, never during a build, and rebuild only when the result changed.
- A definition built in `build` keeps one observer. A shared observer is used as it is and left alone on dispose. A replaced provider client moves the hook to it.
- A new observer for the same key and client on a rebuild prints one debug warning per key and kind (query or mutation), never an error. For `useQueries`, that is a new observer whose key and client an entry of the previous list had. Reordering, the same instances, definitions, and new observers of a replaced client, such as `useMemoized(..., [client])` creates, are silent. The warning says what the new observer does: a query observer refetches, and a mutation observer starts idle. It is this package's own, worded for hooks; `fuery` keeps its widget warning private.
- A hook that gets an observer of another client than the one it uses prints one debug warning per hook name and key, or per hook name for a mutation without a key, so observers created in `build` warn once. It covers a `QueryObserver`, a `MutationObserver`, or the observers in a `useQueries` list. It checks after creating or updating the slot, against the client the hook uses, and never re-reads `Fuery.client`.
- A `listener` follows the rules of the listener widgets, which live in `ObserverSlot.listen`: it runs in a microtask after a change, never during a build, and not for the result it starts from. It gets `(context, result)` with the hook's own `context`, and `listenWhen` compares with the last result received, even when it said no. It doesn't hear a move to another observer, such as a replaced provider client.
- Listening starts on the first build that passes a `listener`, from that build's result, so a hook without one costs nothing. The latest build's `listener` and `listenWhen` are used; a build that passes none keeps the registration and skips the calls. Disposing the hook stops it. `listenWhen` without a `listener` is an `AssertionError`.
- A listener adds no observer and no rebuild: it shares the hook's slot. For a mutation definition, it hears the runs started from the hook's own result; for a shared observer, every run. A listener that throws is reported to the client's `onUncaughtError` and doesn't stop the rebuild.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`, and end it with `await tester.pumpWidget(const SizedBox())` and `client.clear()`.
- Observers made in `build` with `.observe()` refetch on every rebuild once their data is stale, so a test of that warning gives the query `staleTime: infiniteDuration`.
- Tests call the hooks without type arguments, and the package enables `strict-inference`, so they also check inference. Check a hook's inferred type by inferring first (`final result = useQuery(...)`) and then assigning the result to the expected type. A declared type on the call itself would decide the inference and hide a break.
- Capture debug warnings with the `printsOf` helper, which restores `debugPrint` before the test ends.
- Capture listener errors with a client whose `onUncaughtError` collects them. Without it they reach the zone and fail the test.
