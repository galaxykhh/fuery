---
title: QueryClient
description: Every QueryClient option, method, filter, default, and cache field in Fuery for Flutter, with its type and default.
---

A `QueryClient` owns the query cache and the mutation cache, and every read, write, and refetch of cached data goes through it. This page lists its API with types and defaults. For tasks, see [Reading and updating the cache](../../guides/query-client/) and [Setting up the client](../../guides/client-setup/).

## Constructor options

| Name | Type | Default | Description |
|---|---|---|---|
| `queryCache` | `QueryCache` | `QueryCache()` | Holds the cache entries of queries. Pass one to give it a [`QueryCacheConfig`](#cache-callbacks). |
| `mutationCache` | `MutationCache` | `MutationCache()` | Holds the mutation runs. Pass one to give it a [`MutationCacheConfig`](#cache-callbacks). |
| `defaultOptions` | `DefaultOptions` | `DefaultOptions()` | Defaults for every query and mutation. See [Defaults](#defaults). |
| `storage` | `QueryStorage?` | `null` | Where queries and mutations with `persist` store their data. Without a storage, `persist` does nothing. |
| `persistMaxAge` | `Duration` | 1 day | How old stored data can be and still be restored, unless the query's `QueryPersist` sets `maxAge`. |
| `onUncaughtError` | `void Function(Object error, StackTrace stackTrace)?` | `null` | Receives the errors no caller can. Without it, they go to the current zone. See [Catching errors that callbacks throw](../../guides/client-setup/#catching-errors-that-callbacks-throw). |

Each option is also a field of the client.

A client refetches on focus and on reconnect, and resumes paused mutations, only while it is mounted. Assigning `Fuery.client` and `FueryProvider` mount their clients. For any other client, call `mount()` and `unmount()` yourself.

## Reading and writing data

`TData` is the data type of the query. `updatedAt` sets when the data counts as fetched, in milliseconds since epoch, and defaults to now.

| Method | Returns | Description |
|---|---|---|
| `getData(query)` | `TData?` | The cached data of the query, or `null`. |
| `setData(query, data, {updatedAt})` | `TData` | Writes the data. A cache entry this creates gets every option of the query, including `persist`. |
| `updateData(query, updater, {updatedAt})` | `TData?` | Writes what `updater` returns for the current data, which is `null` when nothing is cached. Returning `null` leaves the cache unchanged. |
| `getQueryData<TData>(queryKey)` | `TData?` | The cached data for the key, or `null`. Throws a `StateError` when the key holds another data type. |
| `setQueryData<TData>(queryKey, data, {updatedAt})` | `TData` | Writes the data by key. A cache entry this creates has no query function, so refetches skip it until a query for the key is fetched or observed. |
| `updateQueryData<TData>(queryKey, updater, {updatedAt})` | `TData?` | `updateData` by key. |
| `getQueriesData<TData>({queryKey, exact, predicate})` | `List<(List<Object?>, TData?)>` | The key and data of every match. Every match must hold a `TData`. |
| `updateQueriesData<TData>(updater, {queryKey, exact, predicate, updatedAt})` | `void` | Updates every match that has data of exactly the type `TData`. Takes `TData` from the updater's parameter, and throws an `ArgumentError` when that parameter has no type. |
| `getQueryState(queryKey)` | `QueryState<Object>?` | The state of the key's cache entry, or `null`. See [QueryState fields](#querystate-fields). |
| `watch<T>(selector)` | `Stream<T>` | A broadcast stream of `selector(client)`. See below. |

`watch` gives each listener the current value first. It emits again after a query or a mutation changes, when the new value differs. It compares lists, maps, and sets by content and other values with `==`. An error the selector throws goes to the stream. Watching fetches nothing.

## Fetching

| Method | Returns | Description |
|---|---|---|
| `query(query)` | `Future<TData>` | Returns the cached data while it is fresh for the query's `staleTime`, and fetches otherwise. |
| `infiniteQuery(query)` | `Future<InfiniteData<TPage, TParam>>` | `query` for an `InfiniteQuery`. With nothing cached, the fetch loads the query's `pages` (default 1, at most `maxPages`). With pages cached, it reloads those. |

Both methods follow these rules:

- A call made while the query is fetching waits for that fetch.
- The future fails when the fetch fails.
- A failed fetch is retried only when `retry` is set on the query or in the client's defaults.

## Operations on matching queries

Each method takes the [query filters](#query-filters), plus the arguments in its row.

| Method | Returns | What it does | Its own arguments |
|---|---|---|---|
| `invalidateQueries` | `Future<void>` | Marks the matches stale and refetches the active ones. | `refetchType`, `cancelRefetch`, `throwOnError` |
| `refetchQueries` | `Future<void>` | Refetches the matches. | `cancelRefetch`, `throwOnError` |
| `resetQueries` | `Future<void>` | Returns the matches to their initial state, deletes their persisted data, and refetches the active ones. | `cancelRefetch`, `throwOnError` |
| `cancelQueries` | `Future<void>` | Cancels the fetches in flight. | `revert`, `silent` |
| `removeQueries` | `void` | Deletes the matches from the cache, with their persisted data. | none |
| `isFetching` | `int` | Counts the matches that are fetching. | none |

`invalidateQueries`, `refetchQueries`, and `resetQueries` skip three kinds of cache entries when they refetch:

- Disabled entries, whose `isDisabled` is `true`.
- Static entries that have data: an observer uses `staleTime: staticStaleTime`.
- Entries that only `setQueryData` has written, which have no query function yet.

Their futures complete when the refetches finish. They don't wait for a paused fetch, such as one waiting for the network.

`removeQueries` and `clear()` don't stop an observer that is still subscribed. Fuery moves it to a new cache entry for the same key, which loads again.

```dart
// Refetch the stale todo queries now, and fail if a refetch fails.
await client.refetchQueries(
  queryKey: ['todos'],
  stale: true,
  throwOnError: true,
);

// Stop the list's fetch and put back the state it had before.
await client.cancelQueries(queryKey: ['todos'], exact: true);
```

## Query filters

Every filter you set must match the cache entry.

| Filter | Type | Default | Selects |
|---|---|---|---|
| `queryKey` | `List<Object?>?` | every entry | Entries whose key starts with this key. `['todos']` matches `['todos', 1]`. |
| `exact` | `bool` | `false` | With `true`, only the entry whose key equals `queryKey`. |
| `type` | `QueryTypeFilter` | `QueryTypeFilter.all` | `.active`: at least one enabled observer uses the entry. `.inactive`: none does. |
| `stale` | `bool?` | `null` | `true` selects stale entries, `false` fresh ones. |
| `predicate` | `bool Function(CachedQuery<Object> query)?` | `null` | Entries this function returns `true` for. |

`QueryFilters`, which `queryCache.find` and `findAll` take, has these fields plus `fetchStatus`, a `FetchStatus?` that selects entries in that fetch status. `matches(query)` tests one entry.

## Refetch and cancel arguments

| Argument | Type | Default | What it does |
|---|---|---|---|
| `refetchType` | `RefetchType?` | `null` | Which matches `invalidateQueries` refetches: `RefetchType.active`, `.inactive`, `.all`, or `.none` to only mark them stale. |
| `cancelRefetch` | `bool` | `true` | Cancels the fetch in flight of an entry that has data, and starts a new one. With `false`, waits for the fetch in flight. An entry loading its first data always keeps its fetch. |
| `throwOnError` | `bool` | `false` | With `true`, the returned future fails when a refetch fails. |
| `revert` | `bool` | `true` | Puts a cancelled entry back in the state it had before the fetch. With `false`, records the `CancelledError` as its error. |
| `silent` | `bool` | `false` | With `true` and `revert: false`, records no error: the entry keeps its state and returns to idle. |

Without `refetchType`, `invalidateQueries` refetches the matches that `type` selects, or the active ones when `type` is unset.

```dart
// Mark every todo query stale, refetch the ones nothing shows too,
// and let fetches in flight finish instead of restarting them.
await client.invalidateQueries(
  queryKey: ['todos'],
  refetchType: RefetchType.all,
  cancelRefetch: false,
);
```

## Mutations

| Method | Returns | Description |
|---|---|---|
| `isMutating({mutationKey, exact, predicate})` | `int` | Counts the pending mutation runs that match. |
| `resumePausedMutations()` | `Future<void>` | Resumes every paused mutation run. Does nothing while the device is offline. |

`MutationFilters` select mutation runs. `isMutating` builds one, and `mutationCache.find` and `findAll` take one:

| Filter | Type | Default | Selects |
|---|---|---|---|
| `mutationKey` | `List<Object?>?` | every run | Runs whose `mutationKey` starts with this key. A run without a key never matches it. |
| `exact` | `bool` | `false` | With `true`, only runs whose key equals `mutationKey`. |
| `status` | `MutationStatus?` | `null` | Runs in this status. `isMutating` sets `MutationStatus.pending`. |
| `predicate` | `bool Function(AnyCachedMutation mutation)?` | `null` | Runs this function returns `true` for. |

`matches(mutation)` tests one run.

```dart
final savingTodos = client.isMutating(
  mutationKey: ['todos'],
  exact: true,
  predicate: (mutation) => !mutation.state.isPaused,
);
```

## Defaults

`DefaultOptions` holds the client's defaults:

| Field | Type | Default |
|---|---|---|
| `queries` | `QueryDefaults` | `QueryDefaults()` |
| `mutations` | `MutationDefaults` | `MutationDefaults()` |

`QueryDefaults` takes the [query options](../query-options/) that aren't specific to one query: `enabled`, `staleTime`, `gcTime` (garbage collection time), `refetchInterval`, `refetchIntervalInBackground`, `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect`, `retryOnMount`, `retry`, `retryDelay`, `networkMode`, `structuralSharing`, and `meta`.

`MutationDefaults` takes the [mutation options](../mutation-options/#options) `gcTime`, `retry`, `retryDelay`, `networkMode`, and `meta`.

Every field is nullable, and an unset field leaves the option's own default.

| Method | Returns | Description |
|---|---|---|
| `setQueryDefaults(queryKey, defaults)` | `void` | Sets defaults for every query whose key starts with `queryKey`. Setting the same key again replaces them. |
| `getQueryDefaults(queryKey)` | `QueryDefaults` | The per-key defaults for this key, merged from every matching prefix. |
| `setMutationDefaults(mutationKey, defaults)` | `void` | Sets defaults for every mutation whose `mutationKey` starts with `mutationKey`. |
| `getMutationDefaults(mutationKey)` | `MutationDefaults` | The per-key defaults for this key, merged from every matching prefix. |

Precedence, from strongest to weakest:

1. An option set on the query or the mutation.
2. Per-key defaults. When several prefixes match, they merge in the order the prefixes were first registered, and a later one wins.
3. `defaultOptions`.

A mutation without a `mutationKey` gets only `defaultOptions.mutations`. `meta` is replaced as a whole, never merged.

## Cache callbacks

A cache takes its config when it is constructed and keeps it for its whole life, as `config`.

`QueryCacheConfig` runs a callback for every query in the cache. Each callback returns `void` and receives the `CachedQuery<Object>` last:

| Callback | Runs |
|---|---|
| `onSuccess(data, query)` | After a fetch resolves. |
| `onError(error, query)` | After a fetch fails and its retries are used up. |
| `onSettled(data, error, query)` | After either. |

A cancelled fetch reaches none of them. An error they throw goes to `onUncaughtError`.

`MutationCacheConfig` runs a callback for every mutation run in the cache. Each callback may return a future and receives the `AnyCachedMutation` last. `error` is an `Object`, and `data`, `variables`, and `context` are `Object?`:

| Callback | Runs |
|---|---|
| `onMutate(variables, mutation)` | Before `mutationFn`. |
| `onSuccess(data, variables, context, mutation)` | After success. |
| `onError(error, variables, context, mutation)` | After failure. |
| `onSettled(data, error, variables, context, mutation)` | After either. |

- Each runs before the matching [callback of the mutation](../mutation-options/#callbacks), and Fuery awaits a future it returns.
- A run that `restore` starts again skips both `onMutate` callbacks.
- An error thrown by `onMutate`, or by `onSuccess` or `onSettled` after a success, fails the mutation.
- An error thrown by `onError` or `onSettled` after a failure goes to `onUncaughtError`.

## Caches

`client.queryCache` and `client.mutationCache` read the cache. Change it through the client.

| Method | Returns | Description |
|---|---|---|
| `queryCache.getAll()` | `List<CachedQuery<Object>>` | Every cache entry. |
| `queryCache.find(filters)` | `CachedQuery<Object>?` | The first match. Compares `queryKey` exactly. |
| `queryCache.findAll([filters])` | `List<CachedQuery<Object>>` | Every match, or every entry without filters. |
| `queryCache.get(queryHash)` | `CachedQuery<Object>?` | The entry with this `queryHash`. |
| `mutationCache.getAll()` | `List<AnyCachedMutation>` | Every mutation run. |
| `mutationCache.find(filters)` | `AnyCachedMutation?` | The first match. Compares `mutationKey` exactly. |
| `mutationCache.findAll([filters])` | `List<AnyCachedMutation>` | Every match, or every run without filters. |

A `CachedQuery<TData>` is the cache entry of one key:

| Field | Type | Description |
|---|---|---|
| `queryKey` | `List<Object?>` | The key. |
| `queryHash` | `String` | The hash of the key, which identifies the entry in its cache. |
| `state` | `QueryState<TData>` | See [QueryState fields](#querystate-fields). |
| `options` | `Query<TData>` | The options the entry fetches with, defaults applied. |
| `meta` | `Map<String, Object?>?` | `options.meta`. |
| `observers` | `List<QueryObserver<TData>>` | The observers using the entry, in the order they subscribed. |
| `observersCount` | `int` | How many observers use the entry. |
| `isActive` | `bool` | At least one observer is enabled. |
| `isDisabled` | `bool` | The entry won't fetch on its own: every observer is disabled, or nothing observes it and it has never fetched. |
| `isStale` | `bool` | Stale for at least one observer. Without observers, `true` when it has no data or is invalidated. |
| `isStatic` | `bool` | An observer uses `staticStaleTime`, so the entry is never stale. |
| `isFetched` | `bool` | The entry received data or an error at least once. |
| `isStaleByTime([staleTime])` | `bool` | The data is missing, invalidated, or older than `staleTime`. With `staticStaleTime`, `false` whenever there is data. |
| `future` | `Future<TData>?` | The fetch in flight, if any. |

A `CachedMutation<TData, TVariables, TContext>` is one mutation run:

| Field | Type | Description |
|---|---|---|
| `mutationId` | `int` | Numbers the runs of a cache in the order they were created. |
| `options` | `Mutation<TData, TVariables, TContext>` | The options the run uses, defaults applied. |
| `state` | `MutationState<TData, TVariables, TContext>` | See [MutationState fields](../mutation-results/#mutationstate-fields). |
| `meta` | `Map<String, Object?>?` | `options.meta`. |

`AnyCachedMutation` is `CachedMutation<Object?, Object?, Object?>`, a run whose types the caller doesn't know. Filters and cache callbacks receive runs as this type. `AnyMutation` is the same for a mutation definition, as `restore` takes them.

## QueryState fields

`QueryState<TData>` is the state stored in a cache entry. A `QueryResult` is built from it.

| Field | Type | Description |
|---|---|---|
| `data` | `TData?` | The last data the entry received. `null` means no data. |
| `status` | `QueryStatus` | `pending`, `error`, or `success`. |
| `fetchStatus` | `FetchStatus` | `fetching`, `paused`, or `idle`. |
| `error` | `Object?` | The error of the last attempt, if it failed. |
| `dataUpdatedAt` | `int` | When `data` was last written, in milliseconds since epoch. `0` if never. |
| `errorUpdatedAt` | `int` | When `error` was last set, in milliseconds since epoch. `0` if never. |
| `dataUpdateCount` | `int` | How many times the entry received data, from a fetch or a write such as `setData`. |
| `errorUpdateCount` | `int` | How many times a fetch ended with an error, including a cancel with `revert: false`. |
| `fetchFailureCount` | `int` | Failures of the latest fetch, retries included. Reset when a fetch starts. A `QueryResult` shows it as `failureCount`. |
| `fetchFailureReason` | `Object?` | The latest of those failures. A `QueryResult` shows it as `failureReason`. |
| `isInvalidated` | `bool` | `true` after `invalidateQueries` or a failed fetch. Reset by new data. |

`copyWith` returns a copy with the fields you pass replaced.

## Persistence and cleanup

| Member | Type | Description |
|---|---|---|
| `storage` | `QueryStorage?` | The storage passed to the constructor. |
| `restore({mutations})` | `Future<void>` | Reads every persisted query ahead of time, and starts again the stored runs of the mutations passed. Does nothing without a storage. See [Restoring ahead of time](../../guides/persistence/#restoring-ahead-of-time). |
| `clear()` | `void` | Removes every query and mutation, and deletes all persisted data. Keeps the client and its per-key defaults. See [Clearing everything at logout](../../guides/query-client/#clearing-everything-at-logout). |
