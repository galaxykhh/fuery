# fuery_core

Pure Dart. Never import Flutter. Runtime dependencies are limited to `clock`, `collection`, and `meta`.

## Structure

- `Query`, `InfiniteQuery`, `Mutation`, and `NoVariablesMutation` are definitions: plain descriptions that apps build anywhere and pass around. They hold no client and no state.
- `QueryClient` owns a `QueryCache` of `CachedQuery`s and a `MutationCache` of `CachedMutation`s, the entries with state.
- `QueryObserver` / `InfiniteQueryObserver` / `MutationObserver` hold per-subscriber options and report results. A definition's `observe()` returns one; a query fetches when its observer gets its first listener. Results (`QueryResult`, `InfiniteQueryResult`, `MutationResult`) carry the observer that reported them, so `refetch`, `fetchNextPage`, and `mutate` work from a result; it is left out of `==`.
- `slot.dart` holds the adapter API: `QuerySource` / `InfiniteQuerySource` / `MutationSource` (a definition or an observer) and `ObserverSlot` with `QuerySlot`, `InfiniteQuerySlot`, and `MutationSlot`. A slot owns the observer for a definition and updates its options on every `update`, uses a given observer as it is, creates a new observer for a new client, and keeps its subscription across observer changes. Its `result` is current as soon as `update` returns. `QueriesSlot` keeps one `QuerySlot` per query of a list, reused by query hash (or observer identity) across reorders, and pushes the combined result once per batch; its `observer` is a list that changes identity only when an observer is added, removed, replaced, or moved.
- Callbacks that can need the cache receive the client that runs them: query functions (`context.client`), `placeholderData`, and mutation callbacks and `MutateOptions`.
- `QueryOptions`, `InfiniteQueryOptions`, `MutationOptions`, `AnyMutationOptions`, and `infiniteQueryOptions` are deprecated names for the definitions. Don't use them outside `test/deprecated_test.dart`.
- The query and mutation classes are `part` files of `lib/src/core.dart` so they can share private members. Add related classes there. Anything only the library itself calls (building, adding, and removing cache entries, fetching, state actions, change notifications, garbage collection in `removable.dart`) stays private with a leading `_`. `QueryCache` and `MutationCache` expose only reads (`get`, `getAll`, `find`, `findAll`); `QueryClient.watch` is the only way to observe them. Standalone pieces (`retryer.dart`, `notify_manager.dart`, `focus_manager.dart`, `online_manager.dart`, `utils.dart`, `abort.dart`) are separate libraries.
- `lib/fuery_core.dart` controls the public API with `show`/`hide`. Export new public types there.

## Conventions

- Query data types are `extends Object`. `null` means "no data", so query data can never be null.
- Errors are `Object`; there is no error type parameter.
- Durations are `Duration`. Timestamps are milliseconds from `now()` in `utils.dart`, which uses `package:clock`. Never call `DateTime.now()`: it ignores `fake_async`.
- `infiniteDuration` means "fresh until invalidated"; `staticStaleTime` means "never stale, never refetched automatically".
- Notify listeners through `notifyManager.batch` / `batchCalls`, and iterate over a copy (`.toList()`) so listeners can unsubscribe while being notified.
- A future that may be dropped must not leak errors: use `.ignore()` or `then(..., onError: ...)`.
- Cancel every `Timer` in the matching destroy/clear path. Leftover timers keep Dart processes alive and fail Flutter widget tests.
- Generics are covariant. Don't read function-typed fields that take `TData` (such as `placeholderData`) through a widened type like `CachedQuery<Object>`; do it inside the generic class. `QueryCache._build` compares data types exactly and throws a `StateError` on a mismatch.
- `setOptions` notifies the cache only when `_sameConfig` finds a change a cache watcher could see. It compares functions and codecs (`queryFn`, `placeholderData`, `retry`, `persist`, callbacks) only by whether they are set, so options built again in every `build` cost no notifications. A new option must be added to `_sameConfig` of `Query` or `Mutation`.
- Definitions are constructors, so they can't declare type variables of their own. `InfiniteQuery` takes `getNextPageParam` and `getPreviousPageParam` returning `Object?`, because a return type of `TParam?` makes Dart infer `TPage` too early; `_PageParamCheck` reports a param of another type once, as an uncaught error, and treats it as no page. Its `persist` is typed `InfiniteQueryPersist<TPage, Object?>` for the same reason.
- `removeQueries` and `clear` move observers that are still subscribed to a new query for the key, which loads again. They do it after deleting stored data, so the new query can't restore it.
- A cancel updates the state when it happens (revert, or an error for `revert: false`); a silent cancel that nothing replaces returns the query to idle. Cancel errors never reach the cache callbacks, and a settling fetch never overwrites a fetch or write that came after it.
- Observers decide whether to fetch on mount after an asynchronous restore finishes, so `refetchOnMount` applies to restored data.
- `MutateOptions` callbacks run from the future of their `mutate` call, whether or not the observer has listeners, unless a later call replaced them or `reset()` detached the observer. `MutationSlot` resets the observer it owns when disposed, so a widget's callbacks stop with it.
- `MutationObserver.result` is computed when read. `mutateAsync` only attaches the observer to the mutation when it has listeners; a mutation is collected `gcTime` after it settles with no observers.
- Persistence (`persist.dart`, plus `CachedQuery` and `QueryClient`): storage calls may be synchronous or asynchronous, and their errors are ignored. Reads and writes wait for asynchronous deletions in flight, so deleted data is never restored or overwritten out of order. Garbage collection never deletes stored data; `removeQueries`, `resetQueries`, and `clear` do, and `restore()` deletes entries past the expiry (`e`) they were written with, except for queries that are loaded.
- Persisted mutations (`MutationPersist`, `CachedMutation._writeStored`, `QueryClient._restoreMutations`): a run is stored under its own key (`fuery:mutation:<submittedAt>:<id>`) when it starts and deleted when it settles, after a write still in flight. Only `restore(mutations:)` loads them, oldest first, typed through `Mutation._restore` so decoded variables reach the callbacks with their real types. A restored run skips `onMutate`. Entries without a matching definition are kept; a version mismatch or unreadable entry is deleted. `clear()` deletes them all; query deletions never touch them.

## Tests

- Use `fakeTest` from `test/helpers.dart` for anything involving time, retries, or microtasks. Call `resetManagers()` in `setUp`, and `client.unmount()` plus `client.clear()` in `tearDown`. Unsubscribe observers before `clear()` when a test checks timers: `clear()` moves subscribed observers to new queries, which fetch.
- Use `FakeFetcher` for query functions that count calls and resolve after a delay.
- Tests for fixed edge cases go in `test/regression_test.dart`.
- Checks for inference go in `test/inference_test.dart`, without explicit type arguments.
- `test/adapter_test.dart` renders through slots with only the public API, the way any adapter would. Extend it when the widgets need something new from the core.
