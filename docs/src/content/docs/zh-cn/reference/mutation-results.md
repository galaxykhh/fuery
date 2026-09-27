---
title: 变更结果
description: 适用于 Flutter 的 Fuery 中 MutationResult 和 MutationState 的字段、分别由哪些 widget 和 hook 报告，以及从结果执行变更的方法。
sourceHash: eee94168efc2
---

widget、hook、slot 和观察者用以下两种类型之一报告变更的进展：

| 报告方 | 类型 |
|---|---|
| `MutationBuilder`、`MutationSelector`、`MutationListener`、`MutationConsumer`、`useMutation`、`useOnMutationChange`、`MutationSlot`，以及观察者的 `result` 和 `stream` | [`MutationResult`](#mutationresult)：观察者最近一次执行的状态，以及开始下一次执行的方法 |
| `MutationStateBuilder`、`MutationStateSelector`、`MutationStateListener`、`useMutationState`、`useOnMutationStateChange` 和 `MutationStateSlot` | 每次执行各一个 [`MutationState`](#mutationstate-字段)，无论执行从哪里开始 |

要用一个 widget 或观察者执行变更，并显示它最近开始的执行，读取 `MutationResult`。要显示变更的每次执行，读取每个 `MutationState`，就像[显示变更的每次执行](../../guides/mutations/#显示变更的每次执行)中那样。从定义开始的执行（比如 `addTodo.mutate('Buy milk')`）只出现在 `MutationState` 中。[执行变更](../mutation-options/#执行变更)列出了定义的 `mutate` 和 `mutateAsync`。

## MutationResult

`MutationResult<TData, TVariables, TContext>` 是观察者最近一次执行的 `MutationState`，第一次执行之前为 `idle`，并带有以下成员：

| 成员 | 类型 | 作用 |
|---|---|---|
| `mutate(variables, [options])` | `void` | 开始一次执行，不等待它。错误记入状态并传给回调，不会传给调用方。 |
| `mutateAsync(variables, [options])` | `Future<TData>` | 开始一次执行，并返回它的数据。执行失败时抛出错误。 |
| `reset()` | `void` | 忘记最近一次执行，回到 `idle`。执行本身继续进行。丢弃最近一次调用的 `MutateOptions` 回调。 |
| `observer` | `MutationObserver<TData, TVariables, TContext>` | 报告这个结果的观察者，让只拿到结果的适配器可以监听它。`==` 不比较它。 |

- `options` 是 [`MutateOptions`](../mutation-options/#mutateoptions)。
- 执行使用观察者的客户端。定义的 `mutate` 和 `mutateAsync` 接受客户端，而不是 `options`。
- 新的执行替换最近一次执行，因此执行重叠时，结果只跟踪最新的执行。
- 对于 `NoVariablesMutation`，变量为 `void`：调用 `mutate(null)`。

## MutationState 字段

`MutationState<TData, TVariables, TContext>` 描述一次执行：

| 字段 | 类型 | 内容 |
|---|---|---|
| `status` | `MutationStatus` | `idle`、`pending`、`success` 或 `error` |
| `data` | `TData?` | `mutationFn` 的返回值。执行成功前为 `null`。 |
| `error` | `Object?` | 执行失败的原因。其他状态下都为 `null`。 |
| `variables` | `TVariables?` | 这次执行的 `mutate` 调用传入的内容。`idle` 时为 `null`。 |
| `context` | `TContext?` | `onMutate` 的返回值。`restore(mutations:)` 开始的执行为 `null`。 |
| `submittedAt` | `int` | 这次执行的 `mutate` 调用时间，以自 Unix 纪元以来的毫秒数表示，即使执行之后等待了一段时间才开始。`idle` 时为 `0`。恢复的执行保留存储它的那次执行的时间。 |
| `failureCount` | `int` | 失败的尝试次数。执行开始和成功时重置为 `0`。 |
| `failureReason` | `Object?` | 最近一次失败尝试的错误。与 `failureCount` 一起重置。 |
| `isPaused` | `bool` | 执行是否在等待：等待网络、等待在 `scope` 中轮到它，或者在重试前等待应用回到前台。 |

`status` 持有一个 `MutationStatus` 值。每个值在状态和 `MutationStatus` 本身上都有对应的 getter：

| 值 | getter | 含义 |
|---|---|---|
| `idle` | `isIdle` | 还没有执行，或调用了 `reset()`。 |
| `pending` | `isPending` | 执行正在等待、运行 `mutationFn`、重试或运行回调。 |
| `success` | `isSuccess` | `mutationFn` 已返回，并且回调已运行完毕。 |
| `error` | `isError` | 执行失败：最后一次尝试失败，或 `onMutate`、`onSuccess` 或 `onSettled` 抛出了错误。它的 `onError` 和 `onSettled` 回调已运行完毕，除非 `clear()` 在执行暂停时丢弃了它。 |
