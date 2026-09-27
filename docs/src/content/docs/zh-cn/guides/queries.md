---
title: 查询
description: "在 Flutter 中获取和缓存服务端数据：查询键、新鲜度、重试、依赖查询、轮询和取消。"
sourceHash: 064d08f77dd2
head:
  - tag: title
    content: 在 Flutter 中获取和缓存 API 数据 | Fuery
---

查询描述一份服务端数据：缓存它所用的键，以及获取它的函数。显示同一个键的所有 widget 共享一个缓存条目（`CachedQuery`）和一个请求，因此无须沿 widget 树向下传递数据。

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

[查询选项](../../reference/query-options/)列出了所有选项。[缓存的工作原理](../../how-the-cache-works/)说明查询何时获取数据，以及它的数据何时从内存中移除。

## 查询键

键是一个列表，用来命名一个缓存条目。Fuery 按值比较键，因此在两个 widget 中分别构建的 `['todos', 1]` 是同一个缓存条目和同一个请求。

按从一般到具体的顺序排列键的各部分：`['todos']`、`['todos', 1]`、`['todos', 1, 'comments']`。这样，使 `['todos']` 失效时，所有以它开头的键都会刷新。

键可以包含 `null`、`bool`、`num`、`String`、枚举、`DateTime`、列表、Map 和带有 `toJson()` 方法的对象。Fuery 按键的 JSON 形式比较键：

- `DateTime` 转为它的 ISO 8601 字符串。
- 枚举转为它的类型和名称，例如 `'Filter.done'`。
- 对象转为它的 `toJson()` 返回的值。
- Map 的键转为字符串，因此 `{1: 'a'}` 和 `{'1': 'a'}` 是同一个键。
- Map 中键值对的顺序无关紧要。
- `1` 和 `1.0` 在移动端和桌面端是不同的键，在 Web 上是同一个键。键中的数字使用 `int`。

每个键只保存一种数据类型。以另一种类型使用这个键会抛出 `StateError`：解决方法见[问题排查](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y)。

## 使用查询

把查询传给 widget。`Query` 不保存数据，也不启动任何操作，因此在需要它的任何地方构建它，`build` 中也可以：

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

widget 挂载期间，会为这个查询保持一个[观察者](../../how-the-cache-works/#观察者)，由它获取数据并报告每次变化。widget 以另一个键（例如新的 `id`）重建时，观察者会跟随新的键。[查询结果](../../reference/query-results/#queryresult-字段)列出了 `state` 包含的内容。

在 widget 之外，例如在 cubit、服务或 `State` 字段中，调用一次 `observe()` 并保留这个观察者：

```dart
final todo = todoQuery(1).observe();
todo.stream.listen((result) => print(result.data));
```

不要在 `build` 中调用 `observe()`。每次调用都会创建一个观察者，它会重新订阅并再次获取。[组织查询](../organizing-queries/)介绍了应用规模变大时把查询放在哪里。

## 查询数据不能为 null

Fuery 用 `null` 表示“尚无数据”，因此查询函数返回不可空类型，例如 `Future<User>`。没有内容可显示时，返回一个空值（例如空列表），或者抛出异常。

## staleTime 和新鲜度

数据在 `staleTime`（默认值：0）内保持新鲜，之后变为过期。过期数据仍然显示在屏幕上。某个 widget 或 stream 开始使用这个查询、应用回到前台、网络重新连接或你使这个查询失效时，Fuery 会在后台重新获取它。[查询生命周期](../../how-the-cache-works/#查询生命周期)列出了每个阶段。

把 `staleTime` 设为数据无须再次询问服务器即可显示的时长：

- `Duration(minutes: 1)` 让数据在每次获取后的 1 分钟内保持新鲜。在这 1 分钟内，某个 widget 或 stream 开始使用这个查询、应用回到前台或网络重新连接时，Fuery 都不会重新获取它。使这个查询失效仍会重新获取它。
- `infiniteDuration` 让数据一直保持新鲜，直到你使它失效。
- `staticStaleTime` 用于永不变化的数据。这些数据永远不会过期，也永远不会自行重新获取，即使你使它失效也不会。

两个界面可以用不同的 `staleTime` 值显示同一个键，每个界面按自己的值判断新鲜度。数据在 30 秒前获取时，查询把 `staleTime` 设为 10 秒的界面会在打开时重新获取。查询把它设为 1 分钟的界面则显示缓存的数据，不重新获取。

没有 widget 或 stream 使用的数据，会在垃圾回收时间（`gcTime`，默认值：5 分钟）内留在内存中。在这段时间内再次打开的界面会立即显示数据。

## 重试哪些错误

获取失败时，默认重试 3 次，依次等待 1 秒、2 秒、4 秒。因此，一个永远不会成功的请求大约要 7 秒才会进入错误分支。只重试值得重试的错误：

```dart
Fuery.client = QueryClient(
  defaultOptions: DefaultOptions(
    queries: QueryDefaults(
      retry: RetryPolicy.when(
        (failureCount, error) => failureCount < 3 && error is! NotFoundException,
      ),
    ),
  ),
);
```

在 `RetryPolicy.when` 中，第一次失败时 `failureCount` 为 0，因此 `failureCount < 3` 允许重试 3 次。`QueryResult.failureCount` 则是失败的尝试次数，因此第一次失败后它为 1。

默认值是 `RetryPolicy.count(3)`，另外两个简写是 `RetryPolicy.never()` 和 `RetryPolicy.always()`。单个查询可以设置自己的 `retry`。`client.query` 和变更只在设置了 `retry` 时重试，无论设置在定义上还是默认值中。

## 更改查询要获取的内容

搜索框或筛选条件会随着用户输入改变键。把搜索词保存在状态中，并用它构建查询：

```dart
Query<List<Todo>> searchQuery(String term) => Query(
      queryKey: ['todos', 'search', term],
      queryFn: (_) => api.searchTodos(term),
      enabled: term.isNotEmpty,
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: searchQuery(_term),
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

- `enabled: false` 让查询不会自行获取，因此空的搜索词不会发送请求。`state.refetch()` 仍然会获取。
- 下一个搜索词加载期间，`placeholderData` 让上一次的结果留在屏幕上：见[在屏幕上保留上一页](#在屏幕上保留上一页)。
- 每个搜索词都有自己的缓存条目，因此回到之前的搜索词时，会立即显示它的结果。

在 widget 中调用 `setState` 之前，用 `Timer` 做防抖。在 widget 之外，把下一个查询传给观察者的 `setOptions`。

## 依赖另一个查询的查询

根据查询所需的值设置 `enabled`：

```dart
Query<List<Project>> projectsQuery(String? userId) => Query(
      queryKey: ['projects', userId],
      queryFn: (_) => api.getProjects(userId!),
      enabled: userId != null,
    );
```

或者等值出现后，在第一个查询的构建器中构建第二个查询：

```dart
QueryBuilder(
  query: userQuery,
  builder: (context, state) => switch (state.data?.id) {
    final userId? => QueryBuilder(
        query: projectsQuery(userId),
        builder: (context, projects) => ProjectList(projects.data),
      ),
    null => const CircularProgressIndicator(),
  },
)
```

## 在屏幕上保留上一页

新的键在数据到达之前显示 `pending` 状态。`placeholderData` 改为显示上一个键的数据：

```dart
Query<List<Post>> postsQuery(int page) => Query(
      queryKey: ['posts', page],
      queryFn: (_) => api.getPosts(page),
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: postsQuery(_page),
  builder: (context, state) => PostList(state.data ?? const []),
)
```

`_page` 变化时，widget 保留它的观察者，因此观察者仍有上一页可以显示。为每一页单独创建的观察者则没有上一页。

下一页加载期间，`state.isPlaceholderData` 为 `true`。用它把列表调暗，或者禁用下一页按钮。无限滚动请改用[无限查询](../infinite-queries/)。

`keepPreviousData` 需要从上下文获得数据类型，例如 `postsQuery` 的返回类型。在由 Dart 推断类型的 `Query(...)` 中，改写为 `(previous, client) => previous`。在那里，`keepPreviousData` 会让 Dart 把数据类型推断为 `Object`，而不是取自 `queryFn`。

## 打开详情界面时不显示加载指示器

列表界面已经持有详情界面要获取的列表项。把它作为占位数据返回：

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
      placeholderData: (previous, client) {
        if (previous != null) return previous;
        final todos = client.getData(todosQuery);
        return todos?.firstWhereOrNull((todo) => todo.id == id);
      },
    );
```

`placeholderData` 接收运行这个查询的客户端，因此在测试中和 `FueryProvider` 之下都能读取正确的缓存。Fuery 从不缓存占位数据：获取照常运行，完整的列表项会替换它。如果一个值应当作为已获取的数据写入缓存，请改用 `initialData`。

## 轮询直到任务完成

`refetchInterval` 在有 widget 或 stream 使用这个查询时轮询，并在应用处于后台时暂停：

```dart
final prices = Query(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

添加 `refetchWhile`，在任务完成后停止轮询。Fuery 在每次变化时检查它：它返回 `false` 时轮询停止，返回 `true` 时轮询重新开始，例如在你使这个查询失效之后。

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` 在第一份数据到达之前也会运行，因此要处理 `state.data` 为 `null` 的情况。

## 只重建发生变化的部分

Fuery 深度比较重新获取的数据和缓存的数据，并保留没有变化的缓存对象：

- 相等的数据保持为同一个对象。
- 在发生变化的列表中，与相同索引处的列表项相等的每一项都保持为之前的对象。列表项用 `==` 比较。

这样，用 `==` 比较数据的代码（例如 `buildWhen`）在没有变化的地方就看不到变化。重新获取返回相同的待办事项时，这个构建器会跳过重建，尽管 `List` 按引用比较：

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.data != current.data,
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

结构共享默认开启。对于数据比较开销较大的查询，设置 `structuralSharing: false`。

## 取消请求

在查询函数中读取 `context.signal`，让请求可以取消。这样，没有 widget 或 stream 再使用这个查询时，Fuery 会中止这次获取，而不是让它在后台完成：

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

不读取信号时，请求会完成，Fuery 缓存它的结果供下次使用。

`context.signal` 是一个 `AbortSignal`。分步骤工作的查询函数可以在步骤之间检查 `signal.aborted`，调用 `signal.throwIfAborted()` 以这次取消的 `CancelledError` 停止，或者让 `signal.whenAborted` 与自己的工作竞速。Fuery 总是用这个 `CancelledError` 中止信号，从不使用 `AbortedException`。

Fuery 不把取消视为失败：

- 默认情况下，[`cancelQueries`](../../reference/query-client/#重新获取和取消的参数) 让查询回到获取之前的状态。
- `CancelledError` 永远不会传到 `QueryCacheConfig.onError`。
- 已取消但较晚完成的获取，永远不会覆盖在它之后获取或写入的数据。

只有忽略中止并返回值的查询函数，才会把过时的数据放进缓存。

查询函数自己抛出的 `CancelledError` 与其他失败一样。例如，在 `userQuery` 加载期间移除它，或在它有数据之前取消它，等待 `context.client.query(userQuery)` 的查询函数就会抛出 `CancelledError`。函数抛出这个错误的查询，Fuery 会在它的 `retry` 允许的范围内重试。所有尝试都失败时，这个查询进入 `error` 状态，`QueryCacheConfig.onError` 收到这个 `CancelledError`。

## 在示例应用中

示例在[搜索界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search/search_screen.dart)中搜索时保留上一次的结果，并在[撰写界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)中轮询新帖子，直到它发布。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
