## 1.4.1
- Fix: keys with enums hash the enum by its `name`, without its type. Obfuscated and minified builds rename types, so the hash changed from build to build, and a query persisted under such a key wasn't restored after an app update. Data persisted under keys with enums by an earlier version isn't restored once after upgrading; it is refetched, and the old entry is deleted from the storage when it expires.

## 1.4.0
- Add `QueriesSlot`, which renders a list of queries of one data type, keeps each query's observer while its key stays in the list, and gives their results in order, for adapters such as a `useQueries` hook.
- Add `QueryClient.updateQueriesData`, which updates every query under a key that holds the updater's type, such as a post in every cached search result. It skips queries of other types and queries without data.
- Add `InfiniteData.mapPages`, which replaces every page and keeps the params, for optimistic updates of infinite queries.
- `MutateOptions` callbacks run once their `mutate` call settles, whether or not the observer has listeners. A later call on the same observer or `reset()` still drops them, and `MutationSlot` resets the observer it owns when disposed. Before, an observer without listeners dropped them silently.

## 1.3.0
This release has breaking changes in a minor version. Each **Breaking** entry says what to write instead.

- **Breaking:** a query or mutation is now a definition you build anywhere and pass around. `QueryOptions`, `InfiniteQueryOptions`, and `MutationOptions` are renamed `Query`, `InfiniteQuery`, and `Mutation`; the old names stay as deprecated typedefs. `observe()` on a definition returns its observer. `Query(...)` needs `queryFn`, and `Mutation(...)` needs `mutationFn`.
- **Breaking:** the cache entries formerly named `Query` and `Mutation` are `CachedQuery` and `CachedMutation`, and `AnyMutation` is `AnyCachedMutation`. `AnyMutation` now names any mutation definition, as `QueryClient.restore` takes them.
- **Breaking:** removed `Query.observe`/`use`, `InfiniteQuery.observe`/`use`, `Mutation.observe`/`use`, `Mutation.noVariables`/`noParam`, and `NoParamMutationObserver`. Write `Query(...).observe()`, `InfiniteQuery(...).observe()`, `Mutation(...).observe()`, and `NoVariablesMutation(...).observe()`. `infiniteQueryOptions()` is deprecated: the `InfiniteQuery` constructor infers the same types.
- **Breaking:** mutation callbacks and `MutateOptions` callbacks receive the client that runs the mutation as their last argument, such as `onSuccess: (data, variables, context, client)`. `placeholderData` receives the client as its second argument; `keepPreviousData` still fits.
- **Breaking:** `MutationObserver.result` and `stream` report a `MutationResult`, a `MutationState` with `mutate`, `mutateAsync`, and `reset`.
- `QueryResult.refetch()`, and `InfiniteQueryResult.fetchNextPage()` and `fetchPreviousPage()`, act on the query of the observer that reported the result.
- `QuerySlot`, `InfiniteQuerySlot`, and `MutationSlot` hold the observer for a query or mutation that an adapter, such as a widget or a hook, renders on every build. `QuerySource`, `InfiniteQuerySource`, and `MutationSource` are what they take: a definition or an observer.
- `InfiniteQuery.getNextPageParam` and `getPreviousPageParam` return `Object?` so the constructor infers its types. A param of another type is reported as an error and counts as no page.
- Options built again, with new closures, no longer notify cache watchers when nothing a watcher can see changed.

## 1.2.0
- Define a query once as options: `QueryOptions`, `InfiniteQueryOptions`, and `MutationOptions` have `observe()`, which returns their observer, and `QueryClient.getData`, `setData`, and `updateData` read and write a query's data with the type taken from its options. A query that `setData` creates gets all of the options, so it persists its data and can refetch.
- `Query.observe`, `InfiniteQuery.observe`, and `Mutation.observe` replace `Query.use`, `InfiniteQuery.use`, and `Mutation.use`, and `Mutation.noVariables` with `NoVariablesMutationObserver` replaces `Mutation.noParam` with `NoParamMutationObserver`. The old names are deprecated and keep working until 2.0.
- Fix: `MutationOptions(...)` infers its types without type arguments in apps that enable `strict-inference`.

## 1.1.1
- Fix: `fetchNextPage()` and `fetchPreviousPage()` do nothing when there is no such page, instead of cancelling a refetch in flight and marking the old pages as fresh. A call while that page is already loading waits for it instead of fetching it again.
- Fix: `isFetchedAfterMount` counts from when the observer gets its first listener, and starts over when it is listened to again, instead of from when the observer was created.
- Fix: `restore()` deletes stored queries that have expired, so data of keys the app no longer uses doesn't stay in the storage. Entries now record when they expire.

## 1.1.0
- No changes. Released together with `fuery` 1.1.0.

## 1.0.0
- The public API is stable: from here, a breaking change bumps the major version. No changes since 0.10.0.

## 0.10.0
- Add persisted mutations: give a mutation with a `mutationKey` a `persist: MutationPersist(...)`, and `client.restore(mutations: [...])` runs the ones that were paused or in flight when the app closed.
- `QueryClient.restore` takes `mutations`, and `AnyMutationOptions` names their type.

## 0.9.0
- **Breaking:** boolean reads are getters. Drop the `()` from `Query.isStale`, `isActive`, `isDisabled`, `isFetched`, `isStatic`, `focusManager.isFocused`, `onlineManager.isOnline`, and `hasListeners`.
- **Breaking:** the listeners of an observer, `focusManager`, and `onlineManager` can no longer be replaced or changed from outside. Use `subscribe`.
- **Breaking:** removed API that only the package called: `QueryClient.defaultQueryOptions`, `QueryClient.defaultMutationOptions`, and `NotifyManager.setScheduler`, `setNotifyFunction`, and `setBatchNotifyFunction`.

## 0.8.3
- Documentation only: a description and topics that match what people search for, and a new page on server state in Flutter.

## 0.8.2
- Documentation only: the README and the persistence guide narrow decoded JSON once in the codec, and the storage examples no longer use a class that doesn't exist.

## 0.8.1
- Fix: entry points no longer report an inference failure in apps that enable `strict-inference`, such as those using `very_good_analysis`.

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