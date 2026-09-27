---
title: 变更选项
description: 适用于 Flutter 的 Fuery 中 Mutation 和 NoVariablesMutation 的所有选项，包括类型和默认值、执行变更的方法，以及一次 mutate 调用的回调。
sourceHash: 6b3b19657ff1
---

`Mutation` 和 `NoVariablesMutation` 的所有选项及其类型和默认值、执行变更的方法，以及 `MutateOptions` 和 `MutationPersist`。要为所有变更，或为某个键下的变更设置 `gcTime`、`retry`、`retryDelay`、`networkMode` 或 `meta`，使用 `MutationDefaults`（[默认值](../query-client/#默认值)）。[变更](../../guides/mutations/)展示了这些选项的用法。

## 选项

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `mutationFn` | `Future<TData> Function(TVariables variables)` | 必填 | 把更改发送到服务器。它的参数类型决定 `TVariables`，返回类型决定 `TData`。 |
| `mutationKey` | `List<Object?>` | 无 | 标识各次执行。MutationState 系列 widget、`useMutationState`、`MutationFilters` 和 `restore` 按它查找执行，`setMutationDefaults` 把默认值应用于键以它收到的键开头的每个变更。 |
| `gcTime` | `Duration` | 5 分钟 | 执行结束且没有观察者跟踪它之后，在变更缓存中保留的时长。`infiniteDuration` 让它保留到 `clear()`。 |
| `retry` | `RetryPolicy` | `RetryPolicy.never()` | 失败的尝试重试多少次：`.count(n)`、`.always()` 或 `.when((count, error) => ...)`。 |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1 秒、2 秒、4 秒……最长 30 秒 | 每次重试前等待的时长。 |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `online` 在每次尝试前等待网络。`always` 忽略网络。`offlineFirst` 运行第一次尝试，重试前等待网络。 |
| `scope` | `MutationScope` | 无 | 作用域 `id` 相同的执行按开始顺序逐个进行。等待轮到自己的执行报告 `isPaused`。 |
| `persist` | `MutationPersist<TVariables>` | 无 | 在执行处于 `pending` 状态时存储变量，让 `restore(mutations:)` 在重启后再次执行它。需要 `mutationKey`（由断言检查）和带 `storage` 的客户端。参见 [MutationPersist](#mutationpersist)。 |
| `meta` | `Map<String, Object?>` | 无 | 任意值。`MutationCacheConfig` 的回调和 `MutationFilters.predicate` 以 `mutation.options.meta` 读取它们。 |
| `onMutate` | 参见[回调](#回调) | 无 | 在 `mutationFn` 之前运行。它的返回值决定 `TContext`，并成为 `context`。 |
| `onSuccess` | 参见[回调](#回调) | 无 | `mutationFn` 成功后运行。 |
| `onError` | 参见[回调](#回调) | 无 | 最后一次尝试失败后运行。 |
| `onSettled` | 参见[回调](#回调) | 无 | 两者任一发生后运行。 |

## 执行变更

定义用以下方法执行自身。`client` 是可选的，默认为调用时的 `Fuery.client`：

| 方法 | 返回 | 作用 |
|---|---|---|
| `mutate(variables, [client])` | `void` | 开始一次执行，不等待它。错误记入这次执行的状态并传给回调，不会传给调用方。 |
| `mutateAsync(variables, [client])` | `Future<TData>` | 开始一次执行，并返回它的数据。执行失败时抛出错误。 |
| `observe({client})` | `MutationObserver<TData, TVariables, TContext>` | 返回一个新的观察者，它执行变更并报告最近一次执行。参见[共享一个观察者](../../guides/mutations/#共享一个观察者)。 |

- 定义不持有状态。用 `mutate` 或 `mutateAsync` 开始的执行属于客户端的变更缓存，没有观察者持有它。执行结束 `gcTime` 之后，它离开缓存。
- MutationState 系列 widget、`useMutationState` 和 `isMutating` 按 `mutationKey` 找到这次执行。任何 `MutationResult` 都不显示它。
- 与来自观察者的执行一样，这次执行获得客户端的默认值、它的 `scope` 和 `persist`。
- 两个方法都不接受 `MutateOptions`。要处理一次调用的副作用，用 `await` 等待 `mutateAsync`。
- 在拥有自己客户端的 `FueryProvider` 下，传入 `context.queryClient`。

## 回调

| 回调 | 参数 | 返回 |
|---|---|---|
| `onMutate` | `TVariables variables, QueryClient client` | `FutureOr<TContext?>`，成为 `context` |
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |

`client` 是执行这个变更的客户端。Fuery 按以下顺序运行每个回调：

1. 客户端 `MutationCacheConfig` 中的回调（[缓存回调](../query-client/#缓存回调)）。
2. 变更自身的回调。
3. 两个 `onSettled` 回调运行后，执行的状态变为 `success` 或 `error`。接着运行这次调用的 `MutateOptions` 回调，然后 widget 才接收到新状态。

- Fuery 会等待第 1 步和第 2 步返回的 `Future`，因此在 `Future` 完成前，执行保持 `pending` 状态。
- `onMutate` 抛出的错误，或成功后 `onSuccess` 或 `onSettled` 抛出的错误，会让执行失败，并到达 `onError`。
- 失败执行的 `onError` 或 `onSettled` 抛出的错误进入 [`onUncaughtError`](../../guides/client-setup/#捕获回调抛出的错误)。
- `restore(mutations:)` 恢复的执行跳过 `onMutate`，它的回调收到的 `context` 为 `null`。
- `clear()` 丢弃暂停的执行时，这次执行以 `CancelledError` 失败。`onMutate` 之后的回调都不运行，这次调用的 `MutateOptions` 回调也不运行。

## NoVariablesMutation

`NoVariablesMutation<TData, TContext>` 接受与 `Mutation` 相同的选项，只是 `mutationFn` 和回调省略了变量：

| 选项 | 参数 | 返回 |
|---|---|---|
| `mutationFn` | 无 | `Future<TData>` |
| `onMutate` | `QueryClient client` | `FutureOr<TContext?>` |
| `onSuccess` | `TData data, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TContext? context, QueryClient client` | `FutureOr<void>` |

定义用 `mutate()` 和 `mutateAsync()` 执行它。要传入客户端，先传 `null`：`mutate(null, client)`。

它是 `Mutation<TData, void, TContext>`，因此：

- widget 和 hook 用 `mutate(null)` 或 `mutateAsync(null)` 执行它。
- 它的 `MutateOptions` 回调保留变量参数，值为 `null`。
- `observe()` 返回 `NoVariablesMutationObserver`，它用 `mutate()` 和 `mutateAsync()` 执行变更。要传入 `MutateOptions`，先传 `null`：`mutate(null, options)`。

要持久化它，传入 `MutationPersist.noVariables`。

## MutateOptions

`MutateOptions` 保存一次调用的回调，作为结果或观察者的 `mutate` 或 `mutateAsync` 的第二个参数传入。定义的 `mutate` 不接受它：

| 字段 | 参数 | 运行时机 |
|---|---|---|
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | 调用成功后 |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | 调用失败后 |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | 两者任一发生后 |

- 执行结束后，它们在变更自身的回调之后运行。Fuery 不等待它们。
- 同一个观察者上的新调用会替换它们，因此只有最近一次调用的回调会运行。
- `reset()` 丢弃它们。卸载持有观察者的 widget，或释放持有观察者的 hook 或 slot，也会丢弃它们。
- 无论有没有东西监听，共享观察者都会运行它们。在这些回调中使用 `BuildContext` 之前，检查 `context.mounted`。
- 它们抛出的错误进入 `onUncaughtError`。

## MutationPersist

`MutationPersist<TVariables>` 在变更的变量和 JSON 之间相互转换，让 `restore(mutations:)` 能在重启后重新开始存储的执行。[持久化变更](../../guides/persistence/#持久化变更)展示了配置方法。

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `toJson` | `Object? Function(TVariables variables)` | 必填 | 把变量转换为 `jsonEncode` 接受的值。无法编码的变量不存储，执行照常进行。 |
| `fromJson` | `TVariables Function(Object? json)` | 必填 | 把 `jsonDecode` 的结果转换回变量。 |
| `version` | `int` | `1` | 版本不同的存储执行，Fuery 会删除而不执行。JSON 格式变化时增大它。 |

`MutationPersist.noVariables` 是用于 `NoVariablesMutation` 的 `MutationPersist<void>`，因为这种变更没有要存储的变量。
