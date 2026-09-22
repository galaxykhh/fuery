# fuery_core

Pure Dart. Never import Flutter. Runtime dependencies are limited to `clock`, `collection`, and `meta`.

## Structure

- `QueryClient` owns a `QueryCache` of `Query`s and a `MutationCache` of `Mutation`s.
- `QueryObserver` / `InfiniteQueryObserver` / `MutationObserver` hold per-subscriber options and report results. `Query.use`, `InfiniteQuery.use`, and `Mutation.use` return observers; a query fetches when its observer gets its first listener.
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
- Generics are covariant. Don't read function-typed fields that take `TData` (such as `placeholderData`) through a widened type like `Query<Object>`; do it inside the generic class. `QueryCache._build` compares data types exactly and throws a `StateError` on a mismatch.
- Put options that need a new type variable for inference on generic functions (see `InfiniteQuery.use` and `infiniteQueryOptions`), not only on constructors.
- `removeQueries` and `clear` move observers that are still subscribed to a new query for the key, which loads again. They do it after deleting stored data, so the new query can't restore it.
- A cancel updates the state when it happens (revert, or an error for `revert: false`); a silent cancel that nothing replaces returns the query to idle. Cancel errors never reach the cache callbacks, and a settling fetch never overwrites a fetch or write that came after it.
- Observers decide whether to fetch on mount after an asynchronous restore finishes, so `refetchOnMount` applies to restored data.
- `MutationObserver.result` is computed when read. `mutateAsync` only attaches the observer to the mutation when it has listeners; a mutation is collected `gcTime` after it settles with no observers.
- Persistence (`persist.dart`, plus `Query` and `QueryClient`): storage calls may be synchronous or asynchronous, and their errors are ignored. Reads and writes wait for asynchronous deletions in flight, so deleted data is never restored or overwritten out of order. Garbage collection never deletes stored data; `removeQueries`, `resetQueries`, and `clear` do.
- Persisted mutations (`MutationPersist`, `Mutation._writeStored`, `QueryClient._restoreMutations`): a run is stored under its own key (`fuery:mutation:<submittedAt>:<id>`) when it starts and deleted when it settles, after a write still in flight. Only `restore(mutations:)` loads them, oldest first, typed through `MutationOptions._restore` so decoded variables reach the callbacks with their real types. A restored run skips `onMutate`. Entries without matching options are kept; a version mismatch or unreadable entry is deleted. `clear()` deletes them all; query deletions never touch them.

## Tests

- Use `fakeTest` from `test/helpers.dart` for anything involving time, retries, or microtasks. Call `resetManagers()` in `setUp`, and `client.unmount()` plus `client.clear()` in `tearDown`. Unsubscribe observers before `clear()` when a test checks timers: `clear()` moves subscribed observers to new queries, which fetch.
- Use `FakeFetcher` for query functions that count calls and resolve after a delay.
- Tests for fixed edge cases go in `test/regression_test.dart`.
- Checks for inference go in `test/inference_test.dart`, without explicit type arguments.
