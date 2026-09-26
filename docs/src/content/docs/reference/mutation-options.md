---
title: Mutation options
description: Every option of Mutation and NoVariablesMutation, with its type and default, the methods that run it, and the callbacks of one mutate call.
---

Every option of `Mutation` and `NoVariablesMutation`, with its type and default, the methods that run the mutation, plus `MutateOptions` and `MutationPersist`. To set `gcTime`, `retry`, `retryDelay`, `networkMode`, or `meta` for every mutation, or for the mutations under a key, use `MutationDefaults` ([Defaults](../query-client/#defaults)). [Mutations](../../guides/mutations/) shows the options in use.

## Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `mutationFn` | `Future<TData> Function(TVariables variables)` | required | Sends the change to the server. Its parameter type sets `TVariables`, and its return type sets `TData`. |
| `mutationKey` | `List<Object?>` | none | Identifies the runs. The MutationState widgets, `useMutationState`, `MutationFilters`, and `restore` find runs by it, and `setMutationDefaults` applies defaults to every mutation whose key starts with the key it gets. |
| `gcTime` | `Duration` | 5 minutes | How long a run stays in the mutation cache after it settles and no observer follows it. `infiniteDuration` keeps it until `clear()`. |
| `retry` | `RetryPolicy` | `RetryPolicy.never()` | How often to retry a failed attempt: `.count(n)`, `.always()`, or `.when((count, error) => ...)`. |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1s, 2s, 4s, … up to 30s | How long to wait before each retry. |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `online` waits for the network before each attempt. `always` ignores the network. `offlineFirst` runs the first attempt and waits for the network before retries. |
| `scope` | `MutationScope` | none | Runs whose scopes have the same `id` run one at a time, in the order they started. A run waiting for its turn reports `isPaused`. |
| `persist` | `MutationPersist<TVariables>` | none | Stores the variables while a run is pending, so `restore(mutations:)` runs it again after a restart. Needs a `mutationKey`, which an assert checks, and a client with a `storage`. See [MutationPersist](#mutationpersist). |
| `meta` | `Map<String, Object?>` | none | Any values. `MutationCacheConfig` callbacks and `MutationFilters.predicate` read them as `mutation.options.meta`. |
| `onMutate` | See [Callbacks](#callbacks) | none | Runs before `mutationFn`. Its return value sets `TContext` and becomes `context`. |
| `onSuccess` | See [Callbacks](#callbacks) | none | Runs after `mutationFn` succeeds. |
| `onError` | See [Callbacks](#callbacks) | none | Runs after the last attempt fails. |
| `onSettled` | See [Callbacks](#callbacks) | none | Runs after either. |

## Running the mutation

A definition runs itself with these methods. `client` is optional, and defaults to `Fuery.client` at the time of the call:

| Method | Returns | What it does |
|---|---|---|
| `mutate(variables, [client])` | `void` | Starts a run without waiting for it. An error goes to the run's state and to the callbacks, not to the caller. |
| `mutateAsync(variables, [client])` | `Future<TData>` | Starts a run and returns its data. Throws the error if the run fails. |
| `observe({client})` | `MutationObserver<TData, TVariables, TContext>` | Returns a new observer that runs the mutation and reports its latest run. See [Sharing one observer](../../guides/mutations/#sharing-one-observer). |

- A definition holds no state. A run started with `mutate` or `mutateAsync` belongs to the client's mutation cache, and no observer holds it. It leaves the cache `gcTime` after it settles.
- The MutationState widgets, `useMutationState`, and `isMutating` find the run by `mutationKey`. No `MutationResult` shows it.
- The run gets the client's defaults, its `scope`, and `persist`, as a run from an observer does.
- Neither method takes `MutateOptions`. Await `mutateAsync` for the effects of one call.
- Under a `FueryProvider` with a client of its own, pass `context.queryClient`.

## Callbacks

| Callback | Arguments | Returns |
|---|---|---|
| `onMutate` | `TVariables variables, QueryClient client` | `FutureOr<TContext?>`, which becomes `context` |
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |

`client` is the client running the mutation. Fuery runs each callback in this order:

1. The one in the client's `MutationCacheConfig` ([Cache callbacks](../query-client/#cache-callbacks)).
2. The mutation's own.
3. After both `onSettled` callbacks, the run's state changes to success or error. The `MutateOptions` callbacks of the call run next, before widgets hear of the new state.

- Fuery awaits a future returned in steps 1 and 2, so the run stays pending until the future completes.
- An error thrown by `onMutate`, or by `onSuccess` or `onSettled` after a success, fails the run and reaches `onError`.
- An error thrown by `onError` or `onSettled` of a failed run goes to [`onUncaughtError`](../../guides/client-setup/#catching-errors-that-callbacks-throw).
- A run restored by `restore(mutations:)` skips `onMutate`, and its callbacks receive `null` as `context`.
- When `clear()` drops a paused run, the run fails with a `CancelledError`. None of its callbacks after `onMutate` run, and neither do the `MutateOptions` callbacks of its call.

## NoVariablesMutation

`NoVariablesMutation<TData, TContext>` takes the same options as `Mutation`, except that `mutationFn` and the callbacks leave out the variables:

| Option | Arguments | Returns |
|---|---|---|
| `mutationFn` | none | `Future<TData>` |
| `onMutate` | `QueryClient client` | `FutureOr<TContext?>` |
| `onSuccess` | `TData data, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TContext? context, QueryClient client` | `FutureOr<void>` |

The definition runs it with `mutate()` and `mutateAsync()`. To pass a client, pass `null` first: `mutate(null, client)`.

It is a `Mutation<TData, void, TContext>`, so:

- Widgets and hooks run it with `mutate(null)` or `mutateAsync(null)`.
- Its `MutateOptions` callbacks keep the variables argument, which is `null`.
- `observe()` returns a `NoVariablesMutationObserver`, which runs it with `mutate()` and `mutateAsync()`. To pass `MutateOptions`, pass `null` first: `mutate(null, options)`.

To persist it, pass `MutationPersist.noVariables`.

## MutateOptions

`MutateOptions` holds callbacks for one call, passed as the second argument of the `mutate` or `mutateAsync` of a result or an observer. A definition's `mutate` takes none:

| Field | Arguments | Runs |
|---|---|---|
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | After the call succeeds |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | After the call fails |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | After either |

- They run after the mutation's own callbacks, once the run has settled. Fuery doesn't await them.
- A new call on the same observer replaces them, so only the latest call's callbacks run.
- `reset()` drops them. So does unmounting the widget, or disposing the hook or slot, that owns the observer.
- A shared observer runs them whether or not anything listens to it. Check `context.mounted` before using a `BuildContext` in them.
- An error they throw goes to `onUncaughtError`.

## MutationPersist

`MutationPersist<TVariables>` converts a mutation's variables to JSON and back, so `restore(mutations:)` can run a stored run after a restart. [Persisting mutations](../../guides/persistence/#persisting-mutations) shows the setup.

| Parameter | Type | Default | What it does |
|---|---|---|---|
| `toJson` | `Object? Function(TVariables variables)` | required | Converts the variables to a value that `jsonEncode` accepts. Variables it can't encode aren't stored, and the run goes on. |
| `fromJson` | `TVariables Function(Object? json)` | required | Converts what `jsonDecode` produced back to the variables. |
| `version` | `int` | `1` | Fuery deletes a stored run with another version instead of running it. Increase it when the JSON format changes. |

`MutationPersist.noVariables` is a `MutationPersist<void>` for a `NoVariablesMutation`, which has no variables to store.
