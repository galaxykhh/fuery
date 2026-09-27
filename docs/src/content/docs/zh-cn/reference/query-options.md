---
title: 查询选项
description: Flutter 中 Query 和 InfiniteQuery 的所有选项，包括类型、默认值和作用。
sourceHash: d451e877320c
---

`Query` 和 `InfiniteQuery` 的所有选项，以及它们的类型和默认值。`InfiniteQuery` 接受全部这些选项，外加 [InfiniteQuery 选项](#infinitequery-选项)中的选项。要为所有查询，或为某个前缀下的所有键更改默认值，在客户端上设置 `QueryDefaults`：参见[默认值](../query-client/#默认值)。

[查询](../../guides/queries/)展示了这些选项的实际用法。

## 获取

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `queryKey` | `List<Object?>` | 必填 | 为缓存条目命名。参见[查询键](../../guides/queries/#查询键)。 |
| `queryFn` | `Future<TData> Function(QueryFunctionContext)` | 必填 | 获取数据。接收一个[查询函数上下文](#查询函数上下文)。 |
| `enabled` | `bool` | `true` | 为 `false` 时，查询不会自动获取。`refetch()` 仍然会获取。 |
| `meta` | `Map<String, Object?>` | 无 | 查询函数以 `context.meta` 读取的值。 |

## 新鲜度和缓存

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `staleTime` | `Duration` | 0 | 数据保持新鲜的时长。`infiniteDuration` 让数据保持新鲜，直到你使它失效。`staticStaleTime` 还会忽略失效。 |
| `gcTime` | `Duration` | 5 分钟 | 垃圾回收时间：无人使用的缓存条目在内存中保留的时长。缓存条目采用所有观察者要求的最长 `gcTime`。 |
| `structuralSharing` | `bool` | `true` | 重新获取返回的对象没有变化时，保留已缓存的对象。参见[只重建发生变化的部分](../../guides/queries/#只重建发生变化的部分)。 |
| `persist` | `QueryPersist<TData>` | 无 | 用客户端的 `storage` 把数据存储在设备上。参见[持久化](../../guides/persistence/)。 |

## 重新获取

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `refetchOnMount` | `RefetchMode` | `RefetchMode.ifStale` | widget 或 stream 开始使用查询时重新获取。`.always` 对新鲜数据也重新获取。`.never` 显示缓存数据，不重新获取。 |
| `refetchOnFocus` | `RefetchMode` | `RefetchMode.ifStale` | 应用回到前台时重新获取。 |
| `refetchOnReconnect` | `RefetchMode` | `RefetchMode.ifStale`，使用 `NetworkMode.always` 时为 `.never` | 网络重新连接时重新获取。 |
| `refetchInterval` | `Duration` | 无 | widget 或 stream 使用查询期间，按这个间隔轮询，从查询最近一次变化开始计时。 |
| `refetchIntervalInBackground` | `bool` | `false` | 应用在后台时继续轮询。 |
| `refetchWhile` | `bool Function(QueryResult<TData>)` | 无 | 只在这个函数对最新结果返回 `true` 时轮询。Fuery 在每次变化时检查它，在第一批数据到达之前也会检查。 |

## 失败处理

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `retry` | `RetryPolicy` | `RetryPolicy.count(3)`，`client.query` 为 `.never()` | 失败的获取重试多少次：`.count(n)`、`.never()`、`.always()` 或 `.when((failureCount, error) => ...)`，其中第一次失败时 `failureCount` 为 0。 |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1 秒、2 秒、4 秒……最长 30 秒 | 每次重试前等待的时长。 |
| `retryOnMount` | `bool` | `true` | 为 `false` 时，没有数据且已失败的查询在 widget 开始使用它时不会再次获取。 |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `.online` 在设备离线时暂停获取。`.always` 忽略网络连接状态。`.offlineFirst` 运行第一次尝试，之后在离线时暂停重试。参见[网络重新连接时](../../guides/lifecycle/#网络重新连接时)。 |

## 获取前显示的数据

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `initialData` | `TData` | 无 | 用这份数据预先填充缓存条目，就像它已经获取过一样。 |
| `initialDataUpdatedAt` | `int` | 当前时间 | `initialData` 的获取时间，以自 Unix 纪元以来的毫秒数表示。决定预先填充的数据是否已经过期。 |
| `placeholderData` | `TData? Function(TData? previousData, QueryClient client)` | 无 | 查询处于 `pending` 状态时显示的数据。Fuery 从不把它写入缓存。接收观察者之前显示的键的数据，以及客户端。`keepPreviousData` 返回那份数据。参见[在屏幕上保留上一页](../../guides/queries/#在屏幕上保留上一页)。 |

## InfiniteQuery 选项

`InfiniteQuery<TPage, TParam>` 接受 `Query` 的所有选项，数据类型为 `InfiniteData<TPage, TParam>`。`TPage` 是一页的类型，`TParam` 是标识一页的页参数的类型。[无限查询](../../guides/infinite-queries/)展示了它们的实际用法。

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `queryFn` | `Future<TPage> Function(InfiniteQueryFunctionContext<TParam>)` | 必填 | 获取一页：`context.pageParam` 指定的那一页。 |
| `initialPageParam` | `TParam` | 必填 | 第一页的页参数。Fuery 从它推断 `TParam`。第一页的页参数为 `null` 时，需要声明类型：参见[基于游标的分页](../../guides/infinite-queries/#基于游标的分页)。 |
| `getNextPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | 必填 | 返回 `data.lastPage` 之后那一页的页参数，没有下一页时返回 `null`。它必须返回 `TParam`：参见[页参数错误](#页参数错误)。 |
| `getPreviousPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | 无 | 返回 `data.firstPage` 之前那一页的页参数，或 `null`。不设置时，`hasPreviousPage` 始终为 `false`，并且查询有数据后，`fetchPreviousPage()` 不加载任何内容。 |
| `maxPages` | `int` | 无 | 最多保留的页数。达到上限时，加载下一页会丢弃第一页，加载上一页会丢弃最后一页。 |
| `pages` | `int` | 1 | 没有缓存时加载的页数，最多 `maxPages` 页。有已缓存的页时，获取所有页会改为重新加载这些页。 |
| `persist` | `InfiniteQueryPersist<TPage, TParam>` | 无 | 把页存储在设备上。参见[持久化无限查询](../../guides/persistence/#持久化无限查询)。 |
| `refetchWhile` | `bool Function(InfiniteQueryResult<TPage, TParam>)` | 无 | 与 `Query` 的 `refetchWhile` 相同，只是接收无限查询的结果。 |

超出 `maxPages` 的已缓存页（比如来自 `setData`）会保留，直到加载下一页或上一页时裁剪到 `maxPages` 页。重新获取只重新加载其中的前 `maxPages` 页。

### 页参数错误

Dart 无法在不丢失类型推断的情况下检查 `getNextPageParam` 和 `getPreviousPageParam` 的返回值，因此 Fuery 在运行时检查页参数：

- Fuery 构建结果、设置 `hasNextPage` 或 `hasPreviousPage` 时，其他类型的页参数视为没有页。函数抛出的错误也是如此，比如对空页调用 `data.lastPage.last`。
- 加载页时（比如重新获取），其他类型的页参数会让加载在那一页结束。函数抛出的错误会让获取失败。

Fuery 把其他类型的页参数，以及构建结果时抛出的错误，报告给 [`onUncaughtError`](../../guides/client-setup/#捕获回调抛出的错误)，每个客户端、函数和键只报告一次。

两个函数收到的数据至少有一页，因此 `data.lastPage` 和 `data.firstPage` 始终存在。

## 查询函数上下文

每个查询函数都接收一个 `QueryFunctionContext`。它不携带 widget 树中的任何东西，因此构建查询的 widget 消失后，函数仍然可以运行。

| 字段 | 类型 | 提供的内容 |
|---|---|---|
| `client` | `QueryClient` | 运行这次获取的客户端，用于读取其他缓存数据。 |
| `queryKey` | `List<Object?>` | 正在获取的键，用于构建请求。 |
| `meta` | `Map<String, Object?>?` | `meta` 选项的值。 |
| `signal` | `AbortSignal` | 获取取消时中止。读取它会让获取变为可取消：参见[取消请求](../../guides/queries/#取消请求)。 |

无限查询的函数接收 `InfiniteQueryFunctionContext<TParam>`，它额外提供 `pageParam`：要加载的那一页的页参数。
