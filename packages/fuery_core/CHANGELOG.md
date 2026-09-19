## 0.8.0
- **Breaking:** after `removeQueries` or `clear()`, observers that are still subscribed move to a new query and load again, instead of keeping the removed data. Cancel subscriptions before calling `clear()` in tests and CLIs.
- Cancelling a fetch updates its state right away, and cancel errors are no longer reported to `QueryCacheConfig.onError`.
- `pages` in `infiniteQueryOptions` only applies when nothing is cached.
- Fix many cache, cancellation, retry, persistence, and mutation edge cases, including leftover retry timers, mutations that were never garbage collected, and restores racing with resets.
- Persisted infinite queries infer their page param type.

## 0.7.0
- **Breaking:** the public API only covers what apps use. Queries and mutations in the caches are read-only: change them through `QueryClient`, and watch them with `QueryClient.watch`.
- **Breaking:** removed the cache events and `QueryCache.subscribe` / `MutationCache.subscribe`. Use `QueryClient.watch`.
- **Breaking:** made internal types and members private, including the state action classes, `FetchOptions`, `FetchMeta`, `QueryState.fetchMeta`, `partialMatchKey`, and methods like `Query.fetch`, `Query.setState`, `QueryCache.build`, and `MutationCache.runNext`.

## 0.6.0
- **Breaking:** `Fuery.instance` is renamed to `Fuery.client`. Assigning it mounts the new client and unmounts the previous one.
- Fix: removed queries and mutations no longer start garbage collection timers, which kept Dart processes alive and failed widget tests after `clear()`.

## 0.5.0
- Add persistence: give `QueryClient` a `QueryStorage`, and add `persist: QueryPersist(...)` (or `InfiniteQueryPersist`) to queries whose data should survive restarts.
- Add `QueryClient.restore` to read persisted data ahead of time.
- `removeQueries`, `resetQueries`, and `clear` also delete persisted data.

## 0.4.0
- Add `refetchWhile` to poll with `refetchInterval` only while a condition holds.
- Add `QueryClient.watch` to watch any value computed from the client as a `Stream`.
- Add `streamedQuery` to fold a `Stream` into query data as it arrives.

## 0.3.2
- No changes. Released together with `fuery` 0.3.2.

## 0.3.1
- Link the documentation site at https://galaxykhh.github.io/fuery/.

## 0.3.0
- Rewrite the core around `QueryClient`, `QueryCache`, and observers. Most APIs changed; see the README.
- Add retries with backoff, cancellation, pausing while offline, placeholder data, structural sharing, mutation scopes, `client.query`, and `client.infiniteQuery`.
- Replace `rxdart` with `clock`, `collection`, and `meta`.

## 0.2.2
- fix: The type error for `getQueryData` has been resolved.

## 0.2.1
- fix: include export `QueryStatus`, `MutationStatus` and `FetchStatus`

## 0.2.0
- feat: `QueryStatus` getters added in `QueryResult`
  `isSuccess`, `isPending`, `isFetching`, `isLoading`, `isRefetching`, `isError`
- test: Tests for the following items have been added.
  `FetchStatus`, `QueryStatus`, `MutationStatus`, `Cacheable`, `QueryState`, `QueryResult`

## 0.1.0
- docs: utils documentations
- fix: export typedefs

## 0.0.5
- docs: add examples.

## 0.0.4
- docs: update some basic descriptions.

## 0.0.3
- feat: `InfiniteQuery`
- docs: `InfiniteQuery` usage

## 0.0.2
- docs: update dependencies and license.

## 0.0.1
- chore: Fuery core pre release.