---
title: 无限查询
description: Flutter 中的分页列表和无限滚动列表，已加载的页都会缓存。
sourceHash: fa6d6ed43171
head:
  - tag: title
    content: Flutter 中的无限滚动和分页 | Fuery
---

无限查询在一个键下保存一组页，并按需加载下一页。它适用于信息流和无尽列表。对于相互替换的编号页，带[占位数据](../queries/#在屏幕上保留上一页)的普通查询更合适。

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);
```

`queryFn` 加载 `context.pageParam` 指定的页，从 `initialPageParam` 开始。`getNextPageParam` 返回最后一页之后那一页的页参数；没有更多页时返回 `null`。[InfiniteQuery 选项](../../reference/query-options/#infinitequery-选项)列出了其他选项，以及页参数函数失败时 Fuery 的处理方式。

## 显示各页

`InfiniteQueryBuilder` 把已加载的页和列表底部所需的标志传给它的构建器：

```dart
InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.isFetchingNextPage)
        const Center(child: CircularProgressIndicator())
      else if (state.isFetchNextPageError)
        TextButton(
          onPressed: state.fetchNextPage,
          child: const Text('Loading more failed. Retry'),
        )
      else if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : state.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

列表底部读取的是 `isFetchingNextPage` 而不是 `isFetching`，因此整个列表的后台重新获取不会把按钮替换成加载指示器。[InfiniteQueryResult 字段](../../reference/query-results/#infinitequeryresult-字段)列出了构建器可以读取的所有标志。

滚动监听器可以随意多次调用 `state.fetchNextPage()`：

- 查询有数据后，`hasNextPage` 为 false 时，这个调用什么也不做。
- 在下一页加载期间调用，会等待这一页，而不是再次获取它。
- 这个调用会取消正在运行的其他获取，例如所有页的后台重新获取。要让那次获取完成，就像列表底部那样，在 `isFetching` 为 true 时禁用按钮。`cancelRefetch: false` 也能让它完成，但这次调用就不会加载任何页。

`fetchPreviousPage()` 与 `hasPreviousPage` 配合，工作方式相同。[InfiniteQueryResult 操作](../../reference/query-results/#infinitequeryresult-操作)列出了它们的参数。

## 更新缓存页中的列表项

`mapPages` 替换每一页，并保留页参数。用它修改某一个列表项（例如在乐观更新中），而无须重新加载任何页：

```dart
client.updateData(
  posts,
  (data) => data?.mapPages((page) => page.withPost(updatedPost)),
);
```

`fetchNextPage()` 或 `fetchPreviousPage()` 加载页期间发生的写入，Fuery 会保留。新页到达时，Fuery 把它添加到当时的各页中，除非这次写入改变了已加载的是哪些页。

重新获取所有页时，会用加载到的内容替换这些页。因此，乐观更新会[先取消重新获取](../mutations/#乐观更新)。

## 把无限查询放进函数

`InfiniteQuery<TPage, TParam>` 先写页类型，再写页参数类型。Fuery 从 `queryFn` 推断页类型，从 `initialPageParam` 推断页参数类型。按照[组织查询](../organizing-queries/)的建议把查询移到函数中时，在返回类型中写出这两个类型：

```dart
// lib/data/post_queries.dart
InfiniteQuery<PostPage, int> postsQuery() => InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) => api.getPosts(page: context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    );
```

在 widget 之外，`postsQuery().observe()` 返回一个 `InfiniteQueryObserver<PostPage, int>`，它同样有 `fetchNextPage()`。

## 基于游标的分页

为下一页返回游标的 API 用法相同。第一次请求没有游标时，`initialPageParam` 为 `null`，无法说明游标的类型。因此要声明类型：把查询放在返回 `InfiniteQuery<ItemPage, String?>` 的函数中，页类型在前，游标类型在后：

```dart
InfiniteQuery<ItemPage, String?> itemsQuery() => InfiniteQuery(
      queryKey: ['items'],
      queryFn: (context) => api.getItems(cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
    );
```

这样，`context.pageParam` 的类型是 `String?`，`data.lastPage` 的类型是 `ItemPage`。

## 获取上一页

对于从中间打开的列表（例如打开时停在最新消息处的聊天），添加 `getPreviousPageParam`，并调用 `state.fetchPreviousPage()`。`hasPreviousPage` 和 `isFetchingPreviousPage` 驱动列表顶部，就像对应的下一页标志驱动列表底部一样。

## 限制内存中保留的页数

`maxPages` 限制缓存的页数。达到上限时，加载下一页会丢弃第一页，加载上一页会丢弃最后一页：

```dart
InfiniteQuery<MessagePage, String?> messagesQuery(String roomId) =>
    InfiniteQuery(
      queryKey: ['messages', roomId],
      queryFn: (context) => api.getMessages(roomId, cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
      getPreviousPageParam: (data) => data.firstPage.previousCursor,
      maxPages: 5,
    );
```

同时提供 `getPreviousPageParam`。没有它，`fetchPreviousPage()` 就没有可请求的页参数，因此从前面丢弃的页永远不会回来。

## 重新获取所有已加载的页

无限查询的重新获取会按顺序重新加载每个已加载的页。Fuery 从第一页的页参数开始，并向 `getNextPageParam` 询问每个下一页的页参数，因此即使列表项在页之间移动，各页也能保持一致。`getNextPageParam` 返回 `null` 时，重新获取会提前停止。

## 在示例应用中

示例在[信息流](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)中，每当列表滚动到接近末尾时加载一页。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
