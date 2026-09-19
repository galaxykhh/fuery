# fuery_core

Pure Dart. Never import Flutter. Runtime dependencies are limited to `clock`, `collection`, and `meta`.

## Structure

- `QueryClient` owns a `QueryCache` of `Query`s and a `MutationCache` of `Mutation`s.
- `QueryObserver` / `InfiniteQueryObserver` / `MutationObserver` hold per-subscriber options and report results. `Query.use`, `InfiniteQuery.use`, and `Mutation.use` return observers; a query fetches when its observer gets its first listener.
- The query and mutation classes are `part` files of `lib/src/core.dart` so they can share private members. Add related classes there. Standalone pieces (`retryer.dart`, `notify_manager.dart`, `focus_manager.dart`, `online_manager.dart`, `utils.dart`, `abort.dart`) are separate libraries.
- `lib/fuery_core.dart` controls the public API with `show`/`hide`. Export new public types there.

## Conventions

- Query data types are `extends Object`. `null` means "no data", so query data can never be null.
- Errors are `Object`; there is no error type parameter.
- Durations are `Duration`. Timestamps are milliseconds from `now()` in `utils.dart`, which uses `package:clock`. Never call `DateTime.now()`: it ignores `fake_async`.
- `infiniteDuration` means "fresh until invalidated"; `staticStaleTime` means "never stale, never refetched automatically".
- Notify listeners through `notifyManager.batch` / `batchCalls`, and iterate over a copy (`.toList()`) so listeners can unsubscribe while being notified.
- A future that may be dropped must not leak errors: use `.ignore()` or `then(..., onError: ...)`.
- Cancel every `Timer` in the matching destroy/clear path. Leftover timers keep Dart processes alive and fail Flutter widget tests.
- Generics are covariant. Don't read function-typed fields that take `TData` (such as `placeholderData`) through a widened type like `Query<Object>`; do it inside the generic class. `QueryCache.build` compares data types exactly and throws a `StateError` on a mismatch.
- Put options that need a new type variable for inference on generic functions (see `InfiniteQuery.use` and `infiniteQueryOptions`), not only on constructors.

## Tests

- Use `fakeTest` from `test/helpers.dart` for anything involving time, retries, or microtasks. Call `resetManagers()` in `setUp`, and `client.unmount()` plus `client.clear()` in `tearDown`.
- Use `FakeFetcher` for query functions that count calls and resolve after a delay.
- Tests for fixed edge cases go in `test/regression_test.dart`.
- Checks for inference go in `test/inference_test.dart`, without explicit type arguments.
