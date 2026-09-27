---
title: QueryClient
description: 适用于 Flutter 的 Fuery 中 QueryClient 的所有选项、方法、过滤器、默认值和缓存字段，以及它们的类型和默认值。
sourceHash: 0f608d9305c6
---

`QueryClient` 持有查询缓存和变更缓存，对缓存数据的每次读取、写入和重新获取都经由它进行。查询缓存为每个查询键保存一个缓存条目（`CachedQuery`），也就是这个键的数据和状态。变更缓存为每次 `mutate` 调用保存一次执行（`CachedMutation`）。具体任务参见[读取和更新缓存](../../guides/query-client/)和[配置客户端](../../guides/client-setup/)。

## 构造函数选项

| 名称 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `queryCache` | `QueryCache` | `QueryCache()` | 保存缓存条目。传入自己的实例，为它提供 [`QueryCacheConfig`](#缓存回调)。 |
| `mutationCache` | `MutationCache` | `MutationCache()` | 保存变更的执行。传入自己的实例，为它提供 [`MutationCacheConfig`](#缓存回调)。 |
| `defaultOptions` | `DefaultOptions` | `DefaultOptions()` | 所有查询和变更的默认值。参见[默认值](#默认值)。 |
| `storage` | `QueryStorage?` | `null` | 设置了 `persist` 的查询和变更存储数据的位置。没有存储时，`persist` 不起作用。 |
| `persistMaxAge` | `Duration` | 1 天 | 存储的数据最多多久仍能恢复，除非查询的 `QueryPersist` 设置了 `maxAge`。 |
| `onUncaughtError` | `void Function(Object error, StackTrace stackTrace)?` | `null` | 接收任何调用方都无法捕获的错误。不设置时，这些错误进入当前 zone。参见[捕获回调抛出的错误](../../guides/client-setup/#捕获回调抛出的错误)。 |

每个选项也是客户端的字段。

客户端只有在挂载后，才会在获得焦点和重新连接时重新获取，并继续执行暂停的变更。给 `Fuery.client` 赋值和 `FueryProvider` 都会挂载各自的客户端。对于其他客户端，自己调用 `mount()` 和 `unmount()`。

## 读取和写入数据

`TData` 是查询的数据类型。`updatedAt` 设置数据算作获取完成的时间，以自 Unix 纪元以来的毫秒数表示，默认为当前时间。

| 方法 | 返回 | 说明 |
|---|---|---|
| `getData(query)` | `TData?` | 查询的缓存数据，或 `null`。 |
| `setData(query, data, {updatedAt})` | `TData` | 写入数据。由此创建的缓存条目获得查询的所有选项，包括 `persist`。 |
| `updateData(query, updater, {updatedAt})` | `TData?` | 写入 `updater` 针对当前数据返回的值；没有缓存时，当前数据为 `null`。返回 `null` 时，缓存保持不变。 |
| `getQueryData<TData>(queryKey)` | `TData?` | 这个键的缓存数据，或 `null`。键持有其他数据类型时抛出 `StateError`。 |
| `setQueryData<TData>(queryKey, data, {updatedAt})` | `TData` | 按键写入数据。由此创建的缓存条目没有查询函数，因此重新获取会跳过它，直到某个观察者或 `client.query` 为这个键带来一个查询。 |
| `updateQueryData<TData>(queryKey, updater, {updatedAt})` | `TData?` | `updateData` 的按键版本。 |
| `getQueriesData<TData>({queryKey, exact, predicate})` | `List<(List<Object?>, TData?)>` | 每个匹配项的键和数据。每个匹配项都必须持有 `TData`。 |
| `updateQueriesData<TData>(updater, {queryKey, exact, predicate, updatedAt})` | `void` | 更新数据类型恰好为 `TData` 的每个匹配项。从更新函数的参数取得 `TData`，参数没有类型时抛出 `ArgumentError`。 |
| `getQueryState(queryKey)` | `QueryState<Object>?` | 这个键的缓存条目的状态，或 `null`。参见 [QueryState 字段](#querystate-字段)。 |
| `watch<T>(selector)` | `Stream<T>` | `selector(client)` 的广播 stream。 |

`watch` 先给每个监听器发送当前值。查询缓存或变更缓存发生变化后，如果新值不同，它再次发出。它按内容比较列表、Map 和 Set，其他值用 `==` 比较。选择器抛出的错误进入 stream。观察不会获取任何数据。

## 获取

| 方法 | 返回 | 说明 |
|---|---|---|
| `query(query)` | `Future<TData>` | 缓存数据在查询的 `staleTime` 内保持新鲜时返回它，否则发起获取。 |
| `infiniteQuery(query)` | `Future<InfiniteData<TPage, TParam>>` | 用于 `InfiniteQuery` 的 `query`。没有缓存时，获取加载查询的 `pages` 页（默认 1 页，最多 `maxPages` 页）。有已缓存的页时，从第一页开始重新加载，最多 `maxPages` 页。 |

两个方法都遵循以下规则：

- 需要获取的调用会等待这个键上已在进行的获取，而不是再发起一次。
- 获取失败时，返回的 `Future` 失败。
- 只有查询、`defaultOptions` 或针对它的键的 `setQueryDefaults` 调用设置了 `retry` 时，Fuery 才会重试失败的获取。

## 对匹配查询的操作

每个方法都接受[查询过滤器](#查询过滤器)，以及所在行列出的参数。

| 方法 | 返回 | 作用 | 专有参数 |
|---|---|---|---|
| `invalidateQueries` | `Future<void>` | 把匹配项标记为过期，并重新获取活跃的匹配项。 | `refetchType`、`cancelRefetch`、`throwOnError` |
| `refetchQueries` | `Future<void>` | 重新获取匹配项。 | `cancelRefetch`、`throwOnError` |
| `resetQueries` | `Future<void>` | 把匹配项重置为初始状态，删除它们的持久化数据，并重新获取活跃的匹配项。 | `cancelRefetch`、`throwOnError` |
| `cancelQueries` | `Future<void>` | 取消进行中的获取。 | `revert`、`silent` |
| `removeQueries` | `void` | 从缓存中移除匹配项，并删除它们的持久化数据。 | 无 |
| `isFetching` | `int` | 统计正在获取的匹配项数量。 | 无 |

`invalidateQueries`、`refetchQueries` 和 `resetQueries` 不会重新获取以下缓存条目：

- 已禁用：它的 `isDisabled` 为 `true`。
- 静态且有数据：某个观察者使用 `staleTime: staticStaleTime`。
- 只由 `setQueryData` 写入，因此还没有查询函数。

它们返回的 `Future` 在重新获取完成时完成。它们不等待暂停的获取，比如等待网络的获取。

`removeQueries` 和 `clear()` 不会停止仍在订阅的观察者。Fuery 把它转到同一个键的新缓存条目上，这个缓存条目会重新加载。

```dart
// Refetch the stale cache entries under ['todos'] now,
// and fail if a refetch fails.
await client.refetchQueries(
  queryKey: ['todos'],
  stale: true,
  throwOnError: true,
);

// Stop the list's fetch and put back the state it had before.
await client.cancelQueries(queryKey: ['todos'], exact: true);
```

## 查询过滤器

你设置的每个过滤器都必须与缓存条目匹配。

| 过滤器 | 类型 | 默认值 | 选择 |
|---|---|---|---|
| `queryKey` | `List<Object?>?` | 所有缓存条目 | 键以这个键开头的缓存条目。`['todos']` 匹配 `['todos', 1]`。 |
| `exact` | `bool` | `false` | 为 `true` 时，只选择键等于 `queryKey` 的缓存条目。 |
| `type` | `QueryTypeFilter` | `QueryTypeFilter.all` | `.active`：至少有一个启用的观察者使用这个缓存条目。`.inactive`：没有启用的观察者使用它。 |
| `stale` | `bool?` | `null` | `true` 选择过期的缓存条目，`false` 选择新鲜的缓存条目。 |
| `predicate` | `bool Function(CachedQuery<Object> query)?` | `null` | 这个函数返回 `true` 的缓存条目。 |

`invalidateQueries` 接受的 `type` 是 `QueryTypeFilter?`，默认值为 `null`。不设置时，它像 `.all` 一样把每个匹配项标记为过期，但只重新获取活跃的匹配项。设置为 `.all` 时，它也重新获取非活跃的匹配项。

`queryCache.find` 和 `findAll` 接受的 `QueryFilters` 具有这些字段，另外还有 `fetchStatus`：一个 `FetchStatus?`，选择处于这个获取状态的缓存条目。`matches(query)` 检查一个缓存条目。

## 重新获取和取消的参数

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `refetchType` | `RefetchType?` | `null` | `invalidateQueries` 重新获取哪些匹配项：`RefetchType.active`、`.inactive`、`.all`，或用 `.none` 只把它们标记为过期。 |
| `cancelRefetch` | `bool` | `true` | 对有数据的缓存条目，取消进行中的获取并开始新的获取。为 `false` 时，等待进行中的获取。正在加载首批数据的缓存条目始终保留它的获取。 |
| `throwOnError` | `bool` | `false` | 为 `true` 时，重新获取失败会让返回的 `Future` 失败。 |
| `revert` | `bool` | `true` | 把取消的缓存条目还原到获取前的状态。为 `false` 时，把 `CancelledError` 记为它的错误。 |
| `silent` | `bool` | `false` | 为 `true` 且 `revert: false` 时，不记录错误：缓存条目保持原有状态并回到 `idle`。 |

不设置 `refetchType` 时，`invalidateQueries` 重新获取 `type` 选择的匹配项；`type` 未设置时，重新获取活跃的匹配项。

```dart
// Mark every cache entry under ['todos'] stale, refetch the ones
// nothing shows too, and let fetches in flight finish instead of
// restarting them.
await client.invalidateQueries(
  queryKey: ['todos'],
  refetchType: RefetchType.all,
  cancelRefetch: false,
);
```

## 变更

| 方法 | 返回 | 说明 |
|---|---|---|
| `isMutating({mutationKey, exact, predicate})` | `int` | 统计处于 `pending` 状态的匹配执行数量。 |
| `resumePausedMutations()` | `Future<void>` | 继续执行所有暂停的变更。设备离线时什么也不做。 |

`MutationFilters` 选择变更的执行。`isMutating` 会构建一个，`mutationCache.find` 和 `findAll` 接受一个：

| 过滤器 | 类型 | 默认值 | 选择 |
|---|---|---|---|
| `mutationKey` | `List<Object?>?` | 所有执行 | `mutationKey` 以这个键开头的执行。没有键的执行永远不匹配。 |
| `exact` | `bool` | `false` | 为 `true` 时，只选择键等于 `mutationKey` 的执行。 |
| `status` | `MutationStatus?` | `null` | 处于这个状态的执行。`isMutating` 设置为 `MutationStatus.pending`。 |
| `predicate` | `bool Function(AnyCachedMutation mutation)?` | `null` | 这个函数返回 `true` 的执行。 |

`matches(mutation)` 检查一次执行。

```dart
final savingTodos = client.isMutating(
  mutationKey: ['todos'],
  exact: true,
  predicate: (mutation) => !mutation.state.isPaused,
);
```

## 默认值

`DefaultOptions` 保存客户端的默认值：

| 字段 | 类型 | 默认值 |
|---|---|---|
| `queries` | `QueryDefaults` | `QueryDefaults()` |
| `mutations` | `MutationDefaults` | `MutationDefaults()` |

`QueryDefaults` 接受不针对单个查询的[查询选项](../query-options/)：`enabled`、`staleTime`、`gcTime`（垃圾回收时间）、`refetchInterval`、`refetchIntervalInBackground`、`refetchOnMount`、`refetchOnFocus`、`refetchOnReconnect`、`retryOnMount`、`retry`、`retryDelay`、`networkMode`、`structuralSharing` 和 `meta`。

`MutationDefaults` 接受[变更选项](../mutation-options/#选项)中的 `gcTime`、`retry`、`retryDelay`、`networkMode` 和 `meta`。

每个字段都可空，未设置的字段保留选项自身的默认值。

| 方法 | 返回 | 说明 |
|---|---|---|
| `setQueryDefaults(queryKey, defaults)` | `void` | 为键以 `queryKey` 开头的每个查询设置默认值。再次为同一个键设置会替换它们。 |
| `getQueryDefaults(queryKey)` | `QueryDefaults` | 这个键的按键设置的默认值，由所有匹配的前缀合并而来。 |
| `setMutationDefaults(mutationKey, defaults)` | `void` | 为 `mutationKey` 以 `mutationKey` 开头的每个变更设置默认值。 |
| `getMutationDefaults(mutationKey)` | `MutationDefaults` | 这个键的按键设置的默认值，由所有匹配的前缀合并而来。 |

优先级从高到低：

1. 在查询或变更上设置的选项。
2. 按键设置的默认值。多个前缀匹配时，按前缀首次注册的顺序合并，后注册的优先。
3. `defaultOptions`。

没有 `mutationKey` 的变更只获得 `defaultOptions.mutations`。`meta` 整体替换，从不合并。

## 缓存回调

缓存在构造函数中接收配置，并在整个生命周期中以 `config` 保留它。

`QueryCacheConfig` 为查询缓存中的每次获取运行它的回调。每个回调都返回 `void`，最后一个参数是缓存条目（`CachedQuery<Object>`）：

| 回调 | 运行时机 |
|---|---|
| `onSuccess(data, query)` | 获取成功后。 |
| `onError(error, query)` | 获取失败且重试次数用尽后。 |
| `onSettled(data, error, query)` | 两者任一发生后。 |

取消的获取不会到达任何回调。它们抛出的错误进入 `onUncaughtError`。

`MutationCacheConfig` 为缓存中变更的每次执行运行回调。每个回调都可以返回 `Future`，最后一个参数是 `AnyCachedMutation`。`error` 是 `Object`，`data`、`variables` 和 `context` 是 `Object?`：

| 回调 | 运行时机 |
|---|---|
| `onMutate(variables, mutation)` | `mutationFn` 之前。 |
| `onSuccess(data, variables, context, mutation)` | 成功后。 |
| `onError(error, variables, context, mutation)` | 失败后。 |
| `onSettled(data, error, variables, context, mutation)` | 两者任一发生后。 |

- 每个回调都在[变更的对应回调](../mutation-options/#回调)之前运行，Fuery 会等待它返回的 `Future`。
- `restore` 重新开始的执行会跳过两个 `onMutate` 回调。
- `onMutate` 抛出的错误，或成功后 `onSuccess` 或 `onSettled` 抛出的错误，会让变更失败。
- 失败后 `onError` 或 `onSettled` 抛出的错误进入 `onUncaughtError`。

## 缓存

`client.queryCache` 和 `client.mutationCache` 用于读取缓存。用客户端更改缓存。

| 方法 | 返回 | 说明 |
|---|---|---|
| `queryCache.getAll()` | `List<CachedQuery<Object>>` | 所有缓存条目。 |
| `queryCache.find(filters)` | `CachedQuery<Object>?` | 第一个匹配项。精确匹配 `queryKey`。 |
| `queryCache.findAll([filters])` | `List<CachedQuery<Object>>` | 所有匹配项；不传过滤器时为所有缓存条目。 |
| `queryCache.get(queryHash)` | `CachedQuery<Object>?` | 具有这个 `queryHash` 的缓存条目。 |
| `mutationCache.getAll()` | `List<AnyCachedMutation>` | 变更的所有执行。 |
| `mutationCache.find(filters)` | `AnyCachedMutation?` | 第一个匹配项。精确匹配 `mutationKey`。 |
| `mutationCache.findAll([filters])` | `List<AnyCachedMutation>` | 所有匹配项；不传过滤器时为所有执行。 |

`CachedQuery<TData>` 是一个键的缓存条目：

| 字段 | 类型 | 说明 |
|---|---|---|
| `queryKey` | `List<Object?>` | 键。 |
| `queryHash` | `String` | 键的哈希，在所属缓存中标识这个缓存条目。 |
| `state` | `QueryState<TData>` | 参见 [QueryState 字段](#querystate-字段)。 |
| `options` | `Query<TData>` | 缓存条目获取时使用的选项，已应用默认值。 |
| `meta` | `Map<String, Object?>?` | `options.meta`。 |
| `observers` | `List<QueryObserver<TData>>` | 使用这个缓存条目的观察者，按订阅顺序排列。 |
| `observersCount` | `int` | 使用这个缓存条目的观察者数量。 |
| `isActive` | `bool` | 至少有一个观察者处于启用状态。 |
| `isDisabled` | `bool` | 缓存条目不会自动获取：所有观察者都已禁用，或者没有观察者且 `isFetched` 为 `false`。 |
| `isStale` | `bool` | 对至少一个观察者而言已过期。没有观察者时，没有数据或已失效时为 `true`。 |
| `isStatic` | `bool` | 某个观察者使用 `staticStaleTime`，因此缓存条目永不过期。 |
| `isFetched` | `bool` | 缓存条目至少收到过一次数据或错误，来自获取或 `setData` 等写入。从存储恢复的数据不算。 |
| `isStaleByTime([staleTime])` | `bool` | 数据不存在、已失效或超过 `staleTime`。使用 `staticStaleTime` 时，只要有数据就为 `false`。 |
| `future` | `Future<TData>?` | 进行中的获取（如果有）。 |

`CachedMutation<TData, TVariables, TContext>` 是变更的一次执行：

| 字段 | 类型 | 说明 |
|---|---|---|
| `mutationId` | `int` | 按创建顺序为缓存中的执行编号。 |
| `options` | `Mutation<TData, TVariables, TContext>` | 执行使用的选项，已应用默认值。 |
| `state` | `MutationState<TData, TVariables, TContext>` | 参见 [MutationState 字段](../mutation-results/#mutationstate-字段)。 |
| `meta` | `Map<String, Object?>?` | `options.meta`。 |

`AnyCachedMutation` 是 `CachedMutation<Object?, Object?, Object?>`，即调用方不知道具体类型的执行。过滤器和缓存回调以这个类型接收执行。`AnyMutation` 是 `Mutation<Object?, Object?, Object?>`，即 `restore(mutations:)` 接受的每个定义的类型。

## QueryState 字段

`QueryState<TData>` 是缓存条目持有的状态。观察者基于它构建每个 `QueryResult`。

| 字段 | 类型 | 说明 |
|---|---|---|
| `data` | `TData?` | 缓存条目最后收到的数据。`null` 表示没有数据。 |
| `status` | `QueryStatus` | `pending`、`error` 或 `success`。 |
| `fetchStatus` | `FetchStatus` | `fetching`、`paused` 或 `idle`。 |
| `error` | `Object?` | 最后一次尝试的错误（如果失败）。 |
| `dataUpdatedAt` | `int` | `data` 最后一次写入的时间，以自 Unix 纪元以来的毫秒数表示。从未写入时为 `0`。 |
| `errorUpdatedAt` | `int` | `error` 最后一次设置的时间，以自 Unix 纪元以来的毫秒数表示。从未设置时为 `0`。 |
| `dataUpdateCount` | `int` | 缓存条目收到数据的次数，来自获取或 `setData` 等写入。从存储恢复的数据不计入。 |
| `errorUpdateCount` | `int` | 获取以错误结束的次数，包括使用 `revert: false` 的取消。 |
| `fetchFailureCount` | `int` | 最近一次获取的失败次数，包括重试。获取开始时重置。`QueryResult` 以 `failureCount` 显示它。 |
| `fetchFailureReason` | `Object?` | 这些失败中最近的一次。`QueryResult` 以 `failureReason` 显示它。 |
| `isInvalidated` | `bool` | 调用 `invalidateQueries` 或获取失败后为 `true`。收到新数据时重置。 |

`copyWith` 返回一个副本，其中你传入的字段已替换。

## 持久化和清理

| 成员 | 类型 | 说明 |
|---|---|---|
| `storage` | `QueryStorage?` | 传给构造函数的存储。 |
| `restore({mutations})` | `Future<void>` | 提前读取所有持久化的查询，并重新开始你传入的变更的存储执行。没有存储时什么也不做。参见[提前恢复](../../guides/persistence/#提前恢复)。 |
| `clear()` | `void` | 移除所有缓存条目和所有变更的执行，并删除所有持久化数据。保留客户端及其按键设置的默认值。参见[退出登录时清空所有数据](../../guides/query-client/#退出登录时清空所有数据)。 |
