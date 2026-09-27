---
title: 缓存的工作原理
description: Fuery 如何在 Flutter 应用中缓存服务端数据：两个界面为什么共享一个请求，缓存数据何时重新获取，何时从内存中移除。
sourceHash: acb51a99f4ec
---

两个界面共享一个请求，过期数据自动重新获取，未使用的数据默认在 5 分钟后从内存中移除。下面这些部分共同实现了这些行为：

| 术语 | 是什么 | API 类型 |
|---|---|---|
| 查询 | 服务端数据的定义：它的键、查询函数和选项。它不保存数据。 | `Query`、`InfiniteQuery` |
| 变更 | 一次更改的定义：它的变更函数和选项。它不保存状态。 | `Mutation`、`NoVariablesMutation` |
| 客户端 | 查询缓存和变更缓存的所有者。 | `QueryClient` |
| 缓存条目 | 一个客户端中一个键的数据和状态。 | `CachedQuery` |
| 观察者 | 定义与一个客户端之间的连接。查询观察者观察一个缓存条目。变更观察者开始执行，并报告最近一次执行。 | `QueryObserver`、`InfiniteQueryObserver`、`MutationObserver` |
| 结果 | 观察者报告的内容：它看到的状态，以及 `refetch` 或 `mutate` 等操作。 | `QueryResult`、`InfiniteQueryResult`、`MutationResult` |
| 执行 | 一次 `mutate` 调用，包括它的变量和状态。 | `CachedMutation` |

## 定义

定义只说明要获取或更改什么，不包含别的。`Query` 包含键、查询函数和选项。`Mutation` 包含变更函数和选项。两者都不保存数据，也不持有客户端。创建定义不会启动任何操作。

因此，定义可以是顶层值，也可以由函数或在 `build` 中构建：

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (_) => api.getTodo(id),
    );
```

调用两次 `todoQuery(1)` 会构建两个键为 `['todos', 1]` 的对象。Fuery 按值比较键，因此两个对象使用同一个缓存条目。[查询键](../guides/queries/#查询键)列出键可以包含的内容。

## 客户端和缓存

`QueryClient` 把缓存的所有内容保存在两个缓存中：

- 它的 `QueryCache` 为每个键保存一个缓存条目；
- 它的 `MutationCache` 为每次 `mutate` 调用保存一次执行。

客户端还保存它的缓存所使用的默认值和存储。

`Fuery.client` 是默认客户端，在首次使用时创建。`FueryProvider` 为一棵子树提供它自己的客户端，它下面的 widget 使用这个客户端。每个客户端都有自己的缓存，因此两个客户端中的同一个键是两个缓存条目，各自保存数据。[查询使用哪个客户端](../guides/client-setup/#查询使用哪个客户端)列出 widget、`observe()` 和查询函数遵循的规则。

## 观察者

观察者把定义连接到一个客户端中的缓存条目。有两种方式创建观察者：

- 接收定义的 widget 或 hook 在挂载期间保持一个观察者。
- `observe()` 在 widget 之外的代码中创建观察者，例如 cubit 或服务。只调用一次，不要在 `build` 中调用：每次调用都会创建一个新的观察者。

观察者做这些事：

- **订阅**。观察者获得第一个监听器时订阅它的缓存条目：监听器可以是已挂载的 widget 或 hook，也可以是对 `observe()` 创建的观察者调用的 `stream.listen`。如果缓存条目没有数据，或者数据已过期，观察者就会获取数据（后一种情况由 `refetchOnMount` 控制）。
- **共享获取**。在缓存条目获取期间订阅的观察者加入这次获取。同时打开的两个界面只发送一个请求。
- **取消订阅**。最后一个监听器离开时，观察者取消订阅，例如它的 widget 卸载时，或者取消了 stream 订阅时。
- **应用自己的选项**。每个观察者应用自己的 `staleTime` 和 `refetchOnMount`。两个界面可以观察同一个缓存条目，并各自判断数据是否过期。
- **设置缓存条目保留多久**。每个观察者都会请求一个垃圾回收时间（`gcTime`）：没有观察者观察缓存条目后，缓存条目在内存中保留多久。缓存条目采用所有观察者和获取所请求的最长时间。
- **跟随键**。widget 用另一个键的定义重建时，它的观察者转到那个键的缓存条目。
- **报告结果**。每次发生变化，观察者都会报告一个结果。结果按观察者的选项呈现缓存条目的状态，例如按它自己的 `staleTime` 计算的 `isStale`。[QueryResult 字段](../reference/query-results/#queryresult-字段)列出所有字段。

[使用查询](../guides/queries/#使用查询)展示观察查询的两种方式。[widget](../guides/widgets/) 列出保持观察者的 widget。

## 查询生命周期

缓存条目会经历以下阶段。阶段 3 和阶段 4 因观察者而异，因为每个观察者按自己的 `staleTime` 判断新鲜度。

| 阶段 | 发生什么 | 什么结束这个阶段 |
|---|---|---|
| 1. 已创建 | 某个键的第一个观察者或第一次 `client.query` 调用创建它的缓存条目，此时没有数据。 | 观察者订阅，或者 `client.query` 获取数据。 |
| 2. 等待中 | 查询函数运行。`status` 为 `pending`。`fetchStatus` 为 `fetching`。重试等待应用回到前台时，以及接入[网络状态来源](../guides/lifecycle/#网络重新连接时)后设备离线时，它为 `paused`。 | 数据到达（`success`），或者获取在重试后仍然失败（`error`）。 |
| 3. 新鲜 | 数据的存在时间短于 `staleTime`（默认值：0，因此除非你设置它，否则数据会跳过这个阶段）。默认情况下，挂载、获得焦点和重新连接都不会重新获取数据。 | `staleTime` 过去，或者 `invalidateQueries` 把数据标记为过期。 |
| 4. 过期 | 数据留在屏幕上。观察者订阅时、应用回到前台时，以及接入网络状态来源后网络重新连接时，Fuery 在后台重新获取数据。 | 重新获取带来新数据，回到阶段 3。 |
| 5. 非活跃 | 没有观察者观察这个缓存条目：最后一个观察者已经离开，或者从来没有观察者，例如只由 `client.query` 或 `setData` 填充的缓存条目。数据留在内存中，因此返回的界面会立即显示它。 | 观察者订阅（回到阶段 3 或 4），或者 `gcTime` 过去。 |
| 6. 已移除 | 在没有观察者的情况下经过 `gcTime`（默认值：5 分钟）后，Fuery 移除这个缓存条目。持久化的数据保留在存储中。 | 下次使用这个键时从阶段 1 重新开始，如果有持久化的数据，就恢复它。 |

在这个过程中：

- 用 `initialData` 创建、由 `setData` 创建或从持久化数据创建的缓存条目一开始就有数据，处于阶段 3 或 4。
- 观察者发起的获取默认重试 3 次，依次等待 1 秒、2 秒和 4 秒。只有查询或客户端的默认值（`DefaultOptions`、`setQueryDefaults`）设置了 `retry` 时，`client.query` 才会重试。
- 首次获取失败后，缓存条目处于 `error` 状态，没有数据。观察者订阅时，它会再次获取（除非 `retryOnMount` 为 `false`），并且和过期数据一样，在获得焦点和重新连接时也会获取。
- 重新获取失败时，数据保留。`status` 变为 `error`，数据保持过期，因此下一次触发时重新获取。
- `invalidateQueries` 把匹配的缓存条目标记为过期，并重新获取有观察者观察的缓存条目。
- `refetchInterval` 在设置了它的已启用观察者订阅期间，按计时器重新获取。应用在后台时它会暂停，除非 `refetchIntervalInBackground` 为 `true`。
- 设置了 `staleTime: staticStaleTime` 的观察者让数据永久停留在阶段 3，即使调用了 `invalidateQueries` 也一样。
- `removeQueries` 和 `clear()` 立即移除缓存条目，同时删除它们的持久化数据。
- 重新获取返回的数据与缓存的数据相等时，Fuery 保留之前的对象，因此比较它的 widget 不会重建。列表发生变化时，与同一索引处的上一项相等的每一项仍然是之前的对象。你自己的类只有实现了 `==` 才算相等。[只重建发生变化的部分](../guides/queries/#只重建发生变化的部分)展示了这对列表的效果。

每种重新获取的触发条件都有一个选项，例如 `refetchOnFocus`。[查询选项](../reference/query-options/)列出这些选项和它们的默认值。

## 变更的执行

变更不像查询那样共享缓存条目。每次 `mutate` 调用都会向变更缓存添加一次执行，它有自己的变量和状态。执行属于客户端的缓存，不属于定义或 widget。

- **从定义执行**。`addTodo.mutate('Buy milk')` 向 `Fuery.client` 或你传入的客户端的缓存添加一次执行。没有观察者持有这次执行。
- **显示最近一次执行**。`MutationResult` 显示它的观察者最近开始的一次执行，例如某个 `MutationBuilder` 的执行。对它再次调用 `mutate` 会替换这次执行，`reset()` 让结果回到 `idle`。
- **让执行彼此独立**。同一个变更的两个 `MutationBuilder` 各自保持一个观察者，各自只显示自己的执行。[共享一个观察者](../guides/mutations/#共享一个观察者)介绍多个 widget 需要同一个观察者的情况。
- **找到每次执行**。`MutationStateBuilder`、`MutationStateListener`、`MutationStateSelector` 和 `useMutationState` 按定义的 `mutationKey` 找到它的每次执行，或者找到匹配 `MutationFilters` 的每次执行，无论执行从哪里开始。参见[显示变更的每次执行](../guides/mutations/#显示变更的每次执行)。
- **重试**。只有变更或客户端的变更默认值（`DefaultOptions`、`setMutationDefaults`）设置了 `retry` 时，执行才会重试。
- **离开缓存**。有观察者显示执行时，执行会保留。执行结束且没有观察者显示它之后，Fuery 在 `gcTime`（默认值：5 分钟）过后移除它。从定义开始的执行没有观察者，因此在结束后经过 `gcTime` 就会离开缓存。`client.clear()` 立即移除所有执行。

[变更结果](../reference/mutation-results/)列出 `MutationResult` 和 `MutationState` 的字段。

## 下一步

- [查询](../guides/queries/)：键、新鲜度，以及相互依赖的查询。
- [widget](../guides/widgets/)：保持观察者的 widget。
- [变更](../guides/mutations/)：执行变更，并显示它们的执行。
- [读取和更新缓存](../guides/query-client/)：用客户端读取、写入缓存条目，并使它们失效。
- [查询选项](../reference/query-options/)：每个选项和它的默认值。
