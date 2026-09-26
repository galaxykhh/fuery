---
title: Mutation results
description: The fields of MutationResult and MutationState, and the methods that run a mutation from a result.
---

Widgets, hooks, slots, and observers report a mutation's progress as one of two types:

| Reported by | Type |
|---|---|
| `MutationBuilder`, `MutationSelector`, `MutationListener`, `MutationConsumer`, `useMutation`, `useOnMutationChange`, a `MutationSlot`, and an observer's `result` and `stream` | A [`MutationResult`](#mutationresult): the state of the observer's latest run, with the methods that start another |
| `MutationStateBuilder`, `MutationStateSelector`, `MutationStateListener`, `useMutationState`, `useOnMutationStateChange`, and a `MutationStateSlot` | One [`MutationState`](#mutationstate-fields) for each run, wherever it started |

Read a `MutationResult` to run the mutation through one widget or observer, and to show the latest run it started. Read the `MutationState`s to show every run of a mutation, as in [Showing every run of a mutation](../../guides/mutations/#showing-every-run-of-a-mutation). A run started from the definition, as with `addTodo.mutate('Buy milk')`, shows only in the `MutationState`s. [Running the mutation](../mutation-options/#running-the-mutation) lists the definition's `mutate` and `mutateAsync`.

## MutationResult

A `MutationResult<TData, TVariables, TContext>` is the `MutationState` of the observer's latest run, idle before the first one, with these members:

| Member | Type | What it does |
|---|---|---|
| `mutate(variables, [options])` | `void` | Starts a run without waiting for it. An error goes to the state and the callbacks, not to the caller. |
| `mutateAsync(variables, [options])` | `Future<TData>` | Starts a run and returns its data. Throws the error if the run fails. |
| `reset()` | `void` | Forgets the latest run and returns to idle. The run itself goes on. The `MutateOptions` callbacks of the latest call are dropped. |
| `observer` | `MutationObserver<TData, TVariables, TContext>` | The observer that reported this result, so an adapter given only a result can listen to it. `==` leaves it out. |

- `options` is a [`MutateOptions`](../mutation-options/#mutateoptions).
- The run uses the observer's client. The definition's `mutate` and `mutateAsync` take a client instead of `options`.
- A new run replaces the latest one, so the result follows only the newest run when runs overlap.
- For a `NoVariablesMutation`, the variables are `void`: call `mutate(null)`.

## MutationState fields

A `MutationState<TData, TVariables, TContext>` describes one run:

| Field | Type | What it holds |
|---|---|---|
| `status` | `MutationStatus` | `idle`, `pending`, `success`, or `error` |
| `data` | `TData?` | What `mutationFn` returned. `null` until the run succeeds. |
| `error` | `Object?` | Why the run failed. `null` in every other status. |
| `variables` | `TVariables?` | What the run's `mutate` call passed. `null` while idle. |
| `context` | `TContext?` | What `onMutate` returned. `null` for a run that `restore(mutations:)` started. |
| `submittedAt` | `int` | The time of the run's `mutate` call, in milliseconds since epoch, even if the run then waited to start. `0` while idle. A restored run keeps the time of the run that stored it. |
| `failureCount` | `int` | How many attempts have failed. Resets to `0` when a run starts and when it succeeds. |
| `failureReason` | `Object?` | The error of the latest failed attempt. Resets with `failureCount`. |
| `isPaused` | `bool` | Whether the run waits: for the network, for its turn in a `scope`, or, before a retry, for the app to return to the foreground. |

`status` holds one of the `MutationStatus` values. Each has a getter on the state, and on `MutationStatus` itself:

| Value | Getter | Meaning |
|---|---|---|
| `idle` | `isIdle` | No run yet, or `reset()` was called. |
| `pending` | `isPending` | The run is waiting, running `mutationFn`, retrying, or running its callbacks. |
| `success` | `isSuccess` | `mutationFn` returned, and the callbacks have finished. |
| `error` | `isError` | The run failed: its last attempt failed, or `onMutate`, `onSuccess`, or `onSettled` threw. Its `onError` and `onSettled` callbacks have finished, unless `clear()` dropped the run while it was paused. |
