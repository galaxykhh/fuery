---
title: 查询结果
description: "Flutter 中 Fuery 的 widget、hook 和 stream 为查询接收的内容：状态、数据、错误、获取标志，以及无限查询的页。"
sourceHash: 6744567777c2
---

每个查询 widget、`useQuery` 和观察者 stream 都接收 `QueryResult`。无限查询报告 `InfiniteQueryResult`，它额外提供页和页操作。读取哪个字段取决于你要回答的问题：

- **显示什么**：`data` 不为 `null` 时显示它，其次是 `error`，再其次是加载指示器。失败的重新获取会保留之前的 `data`。
- **是否有请求在进行**：`isFetching`；数据在屏幕上时的后台重新获取看 `isRefetching`。
- **为什么失败**：获取放弃后看 `error`，仍在重试时看 `failureReason` 和 `failureCount`。

## QueryResult 字段

两个枚举承载状态，其他字段描述数据和最近一次获取：

| 字段 | 类型 | 含义 |
|---|---|---|
| `status` | `QueryStatus` | `pending`、`error` 或 `success`。参见 [QueryStatus 和 FetchStatus](#querystatus-和-fetchstatus)。 |
| `fetchStatus` | `FetchStatus` | `fetching`、`paused` 或 `idle`。 |
| `data` | `TData?` | 最新的数据，第一次拿到数据之前为 `null`。失败的重新获取会保留它。 |
| `error` | `Object?` | 最近一次失败的获取的错误。获取成功后，或没有数据的查询再次获取期间，重新变为 `null`。 |
| `dataUpdatedAt` | `int` | `data` 最后一次变化的时间，以自 Unix 纪元以来的毫秒数表示。从未变化时为 `0`。 |
| `errorUpdatedAt` | `int` | `error` 最后一次设置的时间，以自 Unix 纪元以来的毫秒数表示。从未设置时为 `0`。 |
| `errorUpdateCount` | `int` | 获取失败的次数。 |
| `failureCount` | `int` | 最近一次获取中失败的尝试次数，包括重试。获取开始或成功时回到 `0`。 |
| `failureReason` | `Object?` | 最近一次失败尝试的错误。与 `failureCount` 一起清除。 |
| `isFetched` | `bool` | 查询至少完成过一次获取，或从 `setData` 收到过数据。 |
| `isFetchedAfterMount` | `bool` | 同上，但从这个观察者获得第一个监听器时开始算。 |
| `isPlaceholderData` | `bool` | `data` 来自 `placeholderData`。此时 `status` 为 `success`。 |
| `isStale` | `bool` | 数据超过 `staleTime`、已失效或不存在，因此下一次触发时重新获取。禁用的查询始终为 `false`。 |
| `isEnabled` | `bool` | `enabled` 不为 `false`，因此查询会自动获取。 |
| `observer` | `QueryObserver<TData>?` | 报告这个结果的观察者。用 `QueryResult` 构造函数构建的结果（比如在测试中）为 `null`。 |

其余字段是关于这些字段的判断：

| 判断 | 类型 | 为 true 的条件 |
|---|---|---|
| `isPending`、`isSuccess`、`isError` | `bool` | `status` 为对应的值。 |
| `hasData` | `bool` | `data` 不为 `null`。 |
| `isFetching`、`isPaused` | `bool` | `fetchStatus` 为对应的值。 |
| `isLoading` | `bool` | 首次加载：处于 `pending` 状态并且正在获取。 |
| `isRefetching` | `bool` | 数据在屏幕上时有获取在进行。 |
| `isLoadingError` | `bool` | 获取在任何数据到达之前失败。 |
| `isRefetchError` | `bool` | 获取在数据显示在屏幕上时失败。 |

### QueryStatus 和 FetchStatus

| 值 | 含义 |
|---|---|
| `QueryStatus.pending` | 还没有数据，也没有错误。 |
| `QueryStatus.error` | 最近一次获取失败。`data` 保留之前的数据。 |
| `QueryStatus.success` | 查询有数据，并且最近一次获取没有失败。 |
| `FetchStatus.fetching` | 查询函数正在运行。 |
| `FetchStatus.paused` | 获取在等待网络，或者重试在等待网络或等待应用回到前台。 |
| `FetchStatus.idle` | 没有获取在进行。 |

## QueryResult 操作

`refetch()` 再次运行查询，并返回 `Future<QueryResult<TData>>`。在下拉刷新或重试按钮中调用它：

```dart
RefreshIndicator(
  onRefresh: () => state.refetch(),
  child: TodoList(state.data ?? const []),
)
```

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `cancelRefetch` | `bool` | `true` | 查询有数据时，取消进行中的获取并开始新的获取。为 `false` 或没有数据时，调用会加入进行中的获取。 |
| `throwOnError` | `bool` | `false` | 为 `true` 时，返回的 Future 以获取的错误失败。否则错误只出现在结果中。 |

- 返回的 Future 在获取结束后以结果完成。
- 它重新获取观察者当前的查询。widget 换到另一个键后，就是新键。
- 即使 `enabled` 为 `false`，它也会获取。
- 用构造函数构建的结果没有观察者，因此它的 `refetch()` 抛出 `StateError`。

## InfiniteQueryResult 字段

`InfiniteQueryResult` 具有 [`QueryResult` 的所有字段](#queryresult-字段)，其中 `data` 为 `InfiniteData<TPage, TParam>`。它还增加了：

| 字段 | 类型 | 含义 |
|---|---|---|
| `pages` | `List<TPage>` | 已加载的页，第一页加载前为空列表。`data` 包含同样的页及其页参数。 |
| `hasNextPage` | `bool` | `getNextPageParam` 返回了页参数。第一页加载前为 `false`。 |
| `hasPreviousPage` | `bool` | `getPreviousPageParam` 返回了页参数。没有设置这个选项时为 `false`。 |
| `isFetchingNextPage` | `bool` | `fetchNextPage()` 正在进行。 |
| `isFetchingPreviousPage` | `bool` | `fetchPreviousPage()` 正在进行。 |
| `isFetchNextPageError` | `bool` | 最近一次获取是 `fetchNextPage()`，并且失败了。 |
| `isFetchPreviousPageError` | `bool` | 最近一次获取是 `fetchPreviousPage()`，并且失败了。 |
| `observer` | `InfiniteQueryObserver<TPage, TParam>?` | 报告这个结果的观察者，与 `QueryResult` 相同。 |

`isRefetching` 和 `isRefetchError` 针对所有页的重新获取，因此加载单页或单页失败时，两者都保持 `false`。

## InfiniteQueryResult 操作

`fetchNextPage()` 加载最后一个已加载页之后的一页，`fetchPreviousPage()` 加载第一页之前的一页。两者接受与 [`refetch()`](#queryresult-操作) 相同的参数，并在页加载完成后返回结果：

- 查询有数据后，如果 `hasNextPage`（或 `hasPreviousPage`）为 `false`，调用什么也不做。
- 没有数据时，调用从第一页开始加载查询，或加入已在进行的加载。
- 同一页正在加载时，调用会加入那次获取。
- 使用默认的 `cancelRefetch: true` 时，调用先取消其他任何获取，比如所有页的重新获取。为 `false` 时，它加入那次获取，不加载任何页。

`refetch()` 按顺序重新加载每个已加载的页：参见[重新获取所有已加载的页](../../guides/infinite-queries/#重新获取所有已加载的页)。

## InfiniteData 字段

`InfiniteData<TPage, TParam>` 是无限查询的 `data`，也是 `getNextPageParam` 和 `getPreviousPageParam` 接收的内容。

| 成员 | 类型 | 说明 |
|---|---|---|
| `pages` | `List<TPage>` | 所有已加载的页，按顺序排列。 |
| `pageParams` | `List<TParam>` | 加载每一页时使用的页参数，索引与页相同。 |
| `firstPage`、`lastPage` | `TPage` | 第一个和最后一个已加载的页。 |
| `firstPageParam`、`lastPageParam` | `TParam` | 它们的页参数。 |
| `mapPages(transform)` | `InfiniteData<TPage, TParam>` | 同样的数据，每一页替换为 `transform` 返回的内容，页参数不变。参见[更新缓存页中的列表项](../../guides/infinite-queries/#更新缓存页中的列表项)。 |

没有页时，`firstPage`、`lastPage` 及其页参数抛出 `StateError`。要用 `setData` 或 `initialData` 写入页，用 `InfiniteData(pages: ..., pageParams: ...)` 构建数据，每页一个页参数。
