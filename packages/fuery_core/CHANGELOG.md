## 1.5.1
- `MutationStateSlot`, and `MutationFilters` in `find`, `findAll`, and `isMutating`, no longer convert each run's key on every read and flush: a run keeps its converted key while the key holds the same content. With 1,000 runs in the cache, reading the runs of a slot over a `Mutation` is 7 times faster, and over `MutationFilters` 1.3 times. The flush after a run changes is 5 to 6 times faster for a slot over a `Mutation`, and 3 times with `subscribeToRuns`, which `MutationStateListener` and `useOnMutationStateChange` use. This holds for keys of strings, ints, bools, enums, lists, and maps with string keys; other keys are converted on every read, as before.
- An observer given a definition built again with the same key, as a widget's `build` does, no longer hashes the key. `QueryObserver.setOptions` is 2.3 to 3.5 times faster, `QuerySlot.update` 1.9 to 3 times, `QueriesSlot.update` 1.7 to 2 times, and `MutationObserver.setOptions`, which hashed the key four times, 17 times. This holds for keys of strings, ints, bools, enums, lists, and maps with string keys; other keys are hashed as before.
- Subscribing and unsubscribing an observer take the same time however many observers watch the query. With 10,000 on one query, they were 40 and 175 times slower.

## 1.5.0
- Add `MutationStateSlot`, an `ObserverSlot` over the mutation cache. Its `result` is the state of every run a `MutationStateSource` finds, oldest first, wherever the run was started. A `Mutation` finds its runs by its `mutationKey`, typed like the definition, and `MutationFilters` find every matching run, typed `Object?`. Its `subscribe` listeners run in a microtask, once per batch, and only when the list changed. A definition without a key fails an assert, and a run of other types under the key is left out and reported once to `onUncaughtError`.
- Add `MutationStateSlot.subscribeToRuns((previous, current) {...})`, which reports each later change of each run with that run's state before it. It never reports a state a run already had when the listener was added, or a run that the cache removed.
- Add the sealed `MutationStateSource`, which `Mutation` and `MutationFilters` implement.
- Add `QueryResult.observer` and `MutationResult.observer`, the observer that reported a result, so an adapter given only a result can listen to it. `InfiniteQueryResult.observer` is its `InfiniteQueryObserver`, and a `QueryResult` built with its constructor has none.
- Add `ObserverSlot.listen((previous, current) {...})` on every slot, for side effects. It reports each later change with the result before it, in a microtask, and never the result it starts from. It starts over without a call when the slot moves to another observer, and drops what that observer had queued. A listener that throws is reported to the client's `onUncaughtError`, or without it to the zone.
- Add `FueryFocusManager`, the new name of the class of `focusManager`. Flutter has a `FocusManager` class too, so a file that imported Flutter and Fuery could name neither. `focusManager` is the same object.
- Deprecate `FocusManager`, now an alias of `FueryFocusManager`. `dart fix --apply` replaces it, whether the file imports `fuery_core` or `fuery`.
- Fix: a `QueriesSlot` `subscribe` listener that throws is reported to the client's `onUncaughtError` and no longer stops the slot's other listeners.
- Deprecate `GetNextPageParam` and `GetPreviousPageParam`, which no API takes. `InfiniteQuery` takes `Object? Function(InfiniteData<TPage, TParam> data)`.

## 1.4.4
- Add `QueryObserver.client` and `MutationObserver.client`, the client an observer reads and writes.
- Fix: a listener that throws no longer stops the other notifications of its batch, or the other listeners of its observer or slot. Before, it could freeze `QueryClient.watch` streams, `QueriesSlot`, and persistence for the rest of the session.
- Fix: `restore(mutations:)` no longer runs a persisted mutation again while it is still running or paused, or while its stored entry is waiting to be deleted.
- Fix: a query whose function throws a `CancelledError` of its own, for example from awaiting a query that was cancelled or removed, fails like any other error instead of staying in a fetching state.
- Fix: a page param function or an observer callback (`refetchWhile`, `placeholderData`) that throws while a result is built is reported to `onUncaughtError`. Before, it could leave observers loading, fail a successful fetch, or skip the other observers.
- Fix: `fetchNextPage` and `fetchPreviousPage` keep cache writes made while the page loads, such as an item updated with `mapPages`.
- Fix: `maxPages` trims cached pages above the cap when a page loads, and a refetch, or `pages` above `maxPages`, loads only the first `maxPages` pages.
- Fix: `clear()` fails a mutation paused offline or waiting for its turn in a scope with a `CancelledError`, instead of leaving it pending forever, and runs none of its callbacks, so an `onError` rollback can't write the cleared data back. A mutation already sending still finishes.
- Fix: when something deletes stored data while `restore(mutations:)` reads, it reads again, up to three times, instead of skipping the stored mutations.
- Fix: a running mutation keeps the scope it was queued in when its options change, and `submittedAt` no longer changes when `onMutate` returns a context.
- Fix: `refetchQueries` and `invalidateQueries` skip queries that only `setQueryData` wrote, which have no query function yet. Before, they retried for about 7 seconds and left the query in an error.
- Fix: reading a key that holds another data type with `getData`, `updateData`, or `getQueryData` throws the explained `StateError` instead of a cast error.
- Fix: `isFetchedAfterMount` is true again once a reset query has loaded.
- Fix: the default retry delay stays at 30 seconds however many times a query or mutation retries. After about 54 failures it overflowed.
- A query that paused while loading its first data resumes as soon as the app is back online or in the foreground, without waiting for paused mutations. Refetches of queries with data still wait for them.
- Structural sharing compares maps key by key, which is much faster for JSON-shaped data. Filters convert their key once per call, and `find` and `exact: true` filters look the query up by its hash instead of scanning the cache.

## 1.4.3
- Released together with the first version of `fuery_hooks`. No changes in `fuery_core`.

## 1.4.2
- Add `QueryClient.onUncaughtError`, which receives the errors no caller can: errors thrown by `QueryCacheConfig` and `MutateOptions` callbacks or by `onError` and `onSettled` of a failed mutation, and mistakes Fuery finds while running, such as a page param of the wrong type. Without it, they go to the current zone as before.
- Fix: a `QueryCacheConfig` callback that throws no longer turns a successful fetch into an error, and an `onError` that throws no longer skips `onSettled`.
- A mistake Fuery finds while running is reported once per client.

## 1.4.1
- Fix: persisted data is stored under a key that is the same in every build. The stored key included the type name of an enum in the query key, which obfuscated and minified builds rename, so such a query wasn't restored after an app update. Keys in memory are unchanged. Queries an earlier version stored under keys with enums are fetched again once, and `restore()` deletes their old entries once they expire.
- Fix: a persisted mutation whose key holds an enum or a `DateTime` is stored. A key that can't be stored is reported once instead of skipped without a word, and it no longer makes `restore` drop other mutations' runs. `restore` reports two mutations whose keys differ only in enum types and restores neither.

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