---
title: 读取和更新缓存
description: 在 Flutter 中读取、写入、观察缓存数据并使它失效，在 widget 之外获取数据，并在退出登录时清空缓存。
sourceHash: 8b902bc3a7a6
head:
  - tag: title
    content: Flutter 缓存数据的失效、更新和读取 | Fuery
---

用 `QueryClient` 无须发送新请求即可更新每个界面显示的内容，在服务器上的数据改变后重新获取数据，并在界面打开之前获取数据。在 widget 中，`context.queryClient` 返回 widget 使用的客户端。在其他地方，使用你配置的客户端：`Fuery.client`，或者传给 `FueryProvider` 的客户端。参见[查询使用哪个客户端](../client-setup/#查询使用哪个客户端)。

## 读取和写入缓存

客户端为每个查询键保存一个缓存条目（`CachedQuery`），也就是这个键的数据和状态。用查询定义读取和写入数据：

```dart
final client = Fuery.client;

client.getData(todosQuery);                             // the data, or null
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.getQueryState(['todos'])?.dataUpdatedAt;         // the whole QueryState
```

- `getData`、`setData` 和 `updateData` 从[查询定义](../organizing-queries/)中取得键和数据类型，因此无须类型转换。
- 使用这个键的每个 widget 都会用新数据重建。
- 键没有缓存条目时，`setData` 用查询的所有选项创建一个，因此 Fuery 能用 `persist` 存储它的数据，也能重新获取它。
- `updateData` 的更新函数返回 `null` 时，缓存保持不变。

只有键时，使用 `getQueryData`、`setQueryData` 和 `updateQueryData`，并写明数据类型：`client.getQueryData<List<Todo>>(['todos'])`。`setQueryData` 创建的缓存条目没有查询函数，因此重新获取会跳过它，直到某个观察者或 `client.query` 为它的键带来一个查询。以另一种数据类型读取一个键会抛出 [`StateError`](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y)。

`getQueryState` 返回一个键的 `QueryState`，比如它的数据最后一次更新的时间。[QueryState 字段](../../reference/query-client/#querystate-字段)列出了它的字段。

要一次写入多个键，比如写入来自一个 websocket 帧的数据，把这些写入包在 `notifyManager.batch` 中。这样 Fuery 只在最后一次写入之后通知 widget 一次：

```dart
notifyManager.batch(() {
  for (final todo in frame.todos) {
    client.setQueryData(['todo', todo.id], todo);
  }
});
```

## 一次更新多个查询

`updateQueriesData` 更新一个键下数据类型与更新函数相符的每个缓存条目，比如每个已缓存搜索结果中的某篇帖子：

```dart
client.updateQueriesData(
  queryKey: ['posts', 'search'],
  (List<Post> posts) => [
    for (final post in posts) post.id == id ? post.copyWith(liked: true) : post,
  ],
);
```

- Fuery 跳过这个键下其他数据类型的缓存条目，因此一个前缀下可以同时放列表和详情。
- Fuery 跳过没有数据的缓存条目。返回 `null` 时，缓存条目保持不变。
- 为更新函数的参数写明缓存条目的确切数据类型，而不是 `Iterable<Post>` 这样的父类型。参数没有类型时，`updateQueriesData` 抛出 `ArgumentError`。
- `updatedAt` 设置新数据算作获取完成的时间，与 `setData` 相同。

## 列出缓存的内容

`getQueriesData` 返回与 `queryKey`、`exact` 和 `predicate` 匹配的每个缓存条目的键和数据：

```dart
for (final (key, todo) in client.getQueriesData<Todo>(queryKey: ['todo'])) {
  print('$key holds $todo');
}
```

每个匹配项都必须持有你传入的类型的数据，因为 Fuery 会把数据转换为这个类型。把 `['todo', 1]` 这样的详情键放在与 `['todos']` 列表不同的前缀下。

其他情况下，读取缓存。`client.queryCache` 和 `client.mutationCache` 提供 `getAll`、`find` 和 `findAll`：

```dart
final staleOnScreen = client.queryCache.findAll(
  const QueryFilters(type: QueryTypeFilter.active, stale: true),
);
final saving = client.mutationCache.findAll(
  const MutationFilters(status: MutationStatus.pending),
);
```

查询缓存中的匹配项是一个缓存条目（`CachedQuery`）。变更缓存中的匹配项是一次 `mutate` 调用的执行（`CachedMutation`）。[缓存](../../reference/query-client/#缓存)列出了它们的字段。缓存是只读的：用客户端更改缓存。

## 使查询失效

服务器上的数据改变后，把受影响的缓存条目标记为过期：

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

Fuery 立即重新获取正在使用的匹配缓存条目，也就是有启用的[观察者](../../how-the-cache-works/#观察者)的缓存条目，比如已挂载的 widget。其他缓存条目等下次有东西使用它们时再重新获取。传入 `refetchType: RefetchType.none`，只把它们标记为过期。

## 选择操作影响的查询

`invalidateQueries`、`refetchQueries`、`resetQueries`、`cancelQueries`、`removeQueries` 和 `isFetching` 用同一组过滤器选择缓存条目：`queryKey`、`exact`、`type`、`stale` 和 `predicate`。参见[对匹配查询的操作](../../reference/query-client/#对匹配查询的操作)、[查询过滤器](../../reference/query-client/#查询过滤器)和[重新获取和取消的参数](../../reference/query-client/#重新获取和取消的参数)。

### 只刷新屏幕上的查询

```dart
client.invalidateQueries(
  queryKey: ['todos'],
  type: QueryTypeFilter.active,
);
```

不传 `type` 时，Fuery 把每个匹配项标记为过期，并重新获取正在使用的匹配项。传入 `type: QueryTypeFilter.active` 时，它只处理正在使用的匹配项。其他匹配项保留数据，并在 `staleTime` 过去之前保持新鲜。

### 移除某个用户的键

前缀不够用时，用 `predicate` 读取整个键：

```dart
client.removeQueries(
  predicate: (query) => query.queryKey.contains(userId),
);
```

谓词函数接收缓存条目（`CachedQuery`），因此也可以检查 `query.state` 和 `query.options`，比如移除所有获取失败的缓存条目。

## 观察缓存

`client.watch` 把从客户端计算出的任何值转换为 `Stream`，比如在有任何获取进行时显示加载条：

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos']) > 0); // saving
client.watch((client) => client.getQueryData<List<Todo>>(['todos'])); // cached data
```

- 每个监听器先收到当前值，之后在查询缓存或变更缓存发生变化时收到每个新值。
- Fuery 像[选择器](../widgets/#选择状态的一部分)一样比较值，因此值相等时不发出任何内容。
- 观察不会获取任何数据。

只创建一次 stream，比如放在 `State` 字段中，然后用 `StreamBuilder` 显示它：

```dart
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key});

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar> {
  late final fetching = context.queryClient.watch(
    (client) => client.isFetching() > 0,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: fetching,
      builder: (context, snapshot) => snapshot.data == true
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
```

在 bloc 中，像监听其他 stream 一样监听它。

要显示变更是否正在执行，widget 不需要 stream：[`MutationStateSelector`](../mutations/#显示变更的每次执行) 可以显示，`HookWidget` 中的 `useMutationState` 也可以。

## 在 widget 之外获取

`client.query` 在缓存数据新鲜时返回它，否则发起获取。路由守卫、启动代码和预取都用它：

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

- 数据在查询的 `staleTime` 内保持新鲜。默认值为 0 时，`client.query` 每次都会获取。
- 需要获取的调用会等待这个键上已在进行的获取，而不是再发起一次。
- 获取失败时，它抛出错误。
- 只有查询、`defaultOptions` 或针对它的键的 `setQueryDefaults` 调用设置了 `retry` 时，它才会重试。

要使用已缓存的数据，无论多旧，设置 `staleTime: staticStaleTime`。这样 `client.query` 只在没有缓存时获取。

## 在 widget 之外获取无限查询

`client.infiniteQuery` 对[无限查询](../infinite-queries/)做同样的事：

```dart
InfiniteQuery<TodoPage, int> pagedTodosQuery() => InfiniteQuery(
      queryKey: ['todos', 'paged'],
      queryFn: (context) => api.getPage(context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
      pages: 3,
    );

await client.infiniteQuery(pagedTodosQuery());
```

- `pages` 设置没有缓存时一次获取加载多少页：默认 1 页，并且不超过 `maxPages`。
- `pages` 属于定义，因此显示这个查询的 widget 首次也会加载 3 页。
- 有已缓存的页时，获取会从第一页开始重新加载它们，最多 `maxPages` 页，并忽略 `pages`。

## 退出登录时清空所有数据

```dart
Future<void> logout() async {
  await api.logout();
  Fuery.client.clear();
}
```

`clear()` 移除所有缓存条目和所有变更执行，并删除所有[持久化数据](../persistence/#删除存储的数据)。客户端保留下来，用 `setQueryDefaults` 和 `setMutationDefaults` 注册的默认值也保留。

正在执行的变更会怎样，取决于它所处的阶段：

- 已经在发送请求的变更会完成。
- 仍在等待（等待网络，或等待在作用域中轮到它）的变更以 `CancelledError` 失败。`mutateAsync` 抛出这个错误，变更的状态也会显示它。它的回调都不会运行，包括 `MutationCacheConfig` 的回调和它的 `mutate` 调用的回调，因此不会有回滚把旧会话的数据写回去。

在使用查询的界面都消失后再清空。`clear()` 或 `removeQueries` 运行时仍在订阅的观察者会转到同一个键的新缓存条目上，这个缓存条目会像新的一样加载。因此仍在屏幕上的列表会立即以已退出登录的会话重新获取。先导航到登录界面，并取消你手动订阅的所有观察者的订阅。

## 在示例应用中

示例在[信息流](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)中，当指针悬停在帖子卡片上时预取这篇帖子；在[主页框架](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)中观察客户端，用来显示活动指示器。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
