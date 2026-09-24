# fuery_hooks

Hooks over `fuery`, for apps built with `flutter_hooks`. Fuery's own style is the widgets of `fuery`, which follow Flutter's conventions; this package serves developers who prefer hooks. Keep it thin: every hook renders through a core slot, as the widgets do, with public API only. When a hook needs something `fuery` or `fuery_core` hides, make it public there instead of working around it.

## Structure

- `lib/src/hooks.dart`: `useQuery`, `useInfiniteQuery`, `useMutation`, and `useQueries` are `_SlotHook`s over `QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`, and `QueriesSlot`. `useQueryClient` reads `FueryProvider.of(context, listen: true)`.
- `lib/fuery_hooks.dart` re-exports `fuery`, and hides `debugResetHookWarnings`, which only tests use.
- `example/main.dart` is the example pub.dev shows. It is analyzed with the package, so it must compile.

## Hook semantics

These match the widgets and are covered by tests; keep them:

- Every build calls `slot.update` with the latest source and client and returns `slot.result`, so a new key shows in the same frame.
- Results arrive through `notifyManager.batchCalls`, never during a build, and rebuild only when the result changed.
- A definition built in `build` keeps one observer. A shared observer is used as it is and left alone on dispose. A replaced provider client moves the hook to it.
- A new observer for the same key on a rebuild prints one debug warning per key, never an error.

## Tests

- Give each test a fresh `QueryClient` with `QueryDefaults(retry: RetryPolicy.never())`, wrapped in `FueryProvider`, and end it with `await tester.pumpWidget(const SizedBox())` and `client.clear()`.
- Observers made in `build` with `.observe()` refetch on every rebuild once their data is stale, so a test of that warning gives the query `staleTime: infiniteDuration`.
- Tests call the hooks without type arguments, and the package enables `strict-inference`, so they also check inference.
