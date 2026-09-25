# fuery_hooks

Hooks over `fuery`, for apps built with `flutter_hooks`. Fuery's own style is the widgets of `fuery`, which follow Flutter's conventions; this package serves developers who prefer hooks. Keep it thin: every hook renders through a core slot, as the widgets do, with public API only. When a hook needs something `fuery` or `fuery_core` hides, make it public there instead of working around it.

## Structure

- `lib/src/hooks.dart`: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useMutationState` read: they are `_SlotHook`s over `QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`, `QueriesSlot`, and `MutationStateSlot`, and take no listener. Side effects have hooks of their own, named after `flutter_hooks`' `useOn...Change` hooks: `useOnQueryChange`, `useOnMutationChange`, and `useOnMutationStateChange` are `_ChangeHook`s, which create a slot of their own and call the `ResultWidgetListener` and `ResultCondition` that the listener widgets take, through the core: `ObserverSlot.listen`, or `MutationStateSlot.subscribeToRuns` for `useOnMutationStateChange`. `useOnQueryChange` and `useOnMutationChange` take a reading hook's result and wrap its `observer` (`QueryResult.observer`, `MutationResult.observer`) with the observer's own `client`; `useOnQueryChange` wraps an `InfiniteQueryObserver` in an `InfiniteQuerySlot`, and its hook `keys` start it over when the kind changes, as a slot takes observers of one kind. `useOnMutationStateChange` takes the source and the provided client. A new side effect gets a change hook, never a parameter of a reading hook. `useQueryClient` reads `FueryProvider.of(context, listen: true)`.
- `lib/fuery_hooks.dart` re-exports `fuery`. It hides `debugResetHookWarnings`, which only tests use, and `FocusManager`, the deprecated alias of `FueryFocusManager`, whose name Flutter uses too. `FueryFocusManager` and the `focusManager` singleton stay exported.
- `example/main.dart` is the example pub.dev shows. It is analyzed with the package, so it must compile.

## Hook semantics

These match the widgets and are covered by tests; keep them:

- A build with a new source or client calls `slot.update`, and every build returns `slot.result`, so a new key shows in the same frame. A rebuild with the same source and client, such as one a result caused, skips the update.
- A result that arrives after the hook was disposed, as a hot reload can do while the widget stays, is ignored.
- Results arrive through `notifyManager.batchCalls`, never during a build, and rebuild only when the result changed.
- A definition built in `build` keeps one observer. A shared observer is used as it is and left alone on dispose. A replaced provider client moves the hook to it.
- A new observer for the same key and client on a rebuild prints one debug warning per key and kind (query or mutation), never an error. For `useQueries`, that is a new observer whose key and client an entry of the previous list had. Reordering, the same instances, definitions, and new observers of a replaced client, such as `useMemoized(..., [client])` creates, are silent. The warning says what the new observer does: a query observer refetches, and a mutation observer starts idle. It is this package's own, worded for hooks; `fuery` keeps its widget warning private.
- A hook that gets an observer of another client than the one it uses prints one debug warning per hook name and key, or per hook name for a mutation without a key, so observers created in `build` warn once. It covers a `QueryObserver`, a `MutationObserver`, or the observers in a `useQueries` list. It checks after creating or updating the slot, against the client the hook uses, and never re-reads `Fuery.client`.
- The change hooks follow the rules of the listener widgets, which live in the core: the listener runs in a microtask after a change, never during a build, and never for the result, or the states of the runs, there are when the hook first runs. It gets `(context, result)` with the hook's own `context`, and `listenWhen` compares the previous result received with the new one (for `useOnMutationStateChange`, that run's state before), even after it said no. The latest build's `listener` and `listenWhen` are used.
- A change hook adds no observer and no rebuild. A result from another observer (a replaced client, a definition replaced by an observer) calls `slot.update`, which moves the slot without a call; so does a new source or client for `useOnMutationStateChange`. Disposing the hook disposes its slot, which never destroys or resets an observer it was given. A listener that throws is reported to the client's `onUncaughtError`.
- `useOnMutationChange` hears the runs of the result's observer: for a definition, the runs started from that `useMutation`'s result; for a shared observer, every run. `useOnMutationStateChange` hears each run found by the `mutationKey` (or `MutationFilters`), from any widget, once per run that changed, as `MutationStateListener` does.
- `useOnQueryChange` given a result that no observer reported (built with the `QueryResult` constructor) listens to nothing and calls nothing, in every build mode, so a view that takes a result renders with a made-up one in tests. It never asserts.
- `useMutationState` returns every run of a mutation found by its `mutationKey` (or `MutationFilters`), as `MutationStateBuilder` does.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`, and end it with `await tester.pumpWidget(const SizedBox())` and `client.clear()`.
- Observers made in `build` with `.observe()` refetch on every rebuild once their data is stale, so a test of that warning gives the query `staleTime: infiniteDuration`.
- Tests call the hooks without type arguments, and the package enables `strict-inference`, so they also check inference. Check a hook's inferred type by inferring first (`final result = useQuery(...)`) and then assigning the result to the expected type. A declared type on the call itself would decide the inference and hide a break. For a change hook, pass untyped closures and assign their parameters to the expected type inside them.
- Wait for a route transition with `pumpAndSettle`, never a fixed duration.
- Capture debug warnings with the `printsOf` helper, which restores `debugPrint` before the test ends.
- Capture listener errors with a client whose `onUncaughtError` collects them. Without it they reach the zone and fail the test.
