---
title: 流式查询
description: 在 Flutter 中缓存 stream：数据块到达时就显示，结束后保留结果。
sourceHash: 2d8d325d1547
---

`streamedQuery` 把 `Stream` 变成查询函数。数据块陆续到达时，界面显示数据。stream 结束后，缓存保留结果。

它适用于分块到达、随后结束的响应：流式输出的回答、进度日志、正在处理的文件。一直保持打开的连接，例如实时信息流，不是一次获取，不适合用查询。改为用 `setQueryData` 把每条消息写入缓存，参见[读取和写入缓存](../query-client/#读取和写入缓存)。

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

- **收到第一个数据块时，查询就成功了**。widget 随着数据增长而显示数据。
- **在 stream 结束之前，`isFetching` 一直为 true**。
- **`combine` 的用法和 `Stream.fold` 一样**。它从 `initialValue` 开始，把一个数据块加到当前的值上。
- **`initialValue` 决定数据类型**，因此调用时无须类型参数。
- **空的 stream 以 `initialValue` 成功**。
- **stream 或 `combine` 中的错误会让查询失败**。`data` 保留目前已收到的数据块。
- **每次重试都会开始一个新的 stream**，并遵循 `refetchMode`。默认模式会先清空数据。

这个 `Query` 照常接受其他[查询选项](../../reference/query-options/)，例如 `staleTime`。

## 把数据块收集到列表中

从空列表开始，把每个数据块添加进去：

```dart
final log = Query(
  queryKey: ['jobs', id, 'log'],
  queryFn: streamedQuery(
    stream: (context) => api.jobLog(id),
    initialValue: const <LogLine>[],
    combine: (lines, line) => [...lines, line],
  ),
);
```

## 重新获取流式查询

`refetchMode` 决定查询再次获取时缓存的数据如何处理，例如在 `invalidateQueries` 之后：

| 模式 | 新的 stream 运行期间 | 结束时 |
|---|---|---|
| `StreamRefetchMode.reset`（默认） | Fuery 清空数据，查询处于 `pending` 状态，直到第一个数据块到达 | 新数据 |
| `StreamRefetchMode.append` | Fuery 把新的数据块累积到现有数据上 | 合并后的数据 |
| `StreamRefetchMode.replace` | 旧数据留在屏幕上 | 新数据，一次性替换 |

```dart
queryFn: streamedQuery(
  stream: (context) => api.ask(question),
  initialValue: '',
  combine: (text, token) => text + token,
  refetchMode: StreamRefetchMode.replace,
),
```

## 停止 stream

Fuery 取消获取时也会取消 stream：调用 `cancelQueries` 时，或者重新获取替换正在进行的获取时。

默认情况下，没有 widget 使用查询时，stream 继续运行，Fuery 缓存结果。这样用户回来时，流式输出的回答已经完整。要改为停止 stream，在 `stream` 中读取 `context.signal`，这会让获取变为[可取消](../queries/#取消请求)：

```dart
stream: (context) {
  final request = api.startAnswer(question); // a request you can cancel
  context.signal.onAbort(request.cancel);
  return request.tokens;
},
```

## 在示例应用中

示例应用在[帖子界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)中以流式方式输出讨论串摘要。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出每个界面展示了什么。
