---
title: 组织查询
description: 在 Flutter 应用不断增长时，把查询键、查询函数和变更集中放在一处。
sourceHash: 65a5f2f56dec
---

每个查询只写一个定义，它的键和数据类型就能在每个界面、每个 bloc 和每个服务中保持一致。把定义放在它所调用的 API 旁边的文件中：

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
    );
```

查询不保存数据，因此可以用顶层 `final`。接收某个值（例如 id）的查询写成函数。

同一个定义适用于数据的每一种用法：

```dart
QueryBuilder(query: todoQuery(id), builder: ...);     // in a widget
final todo = await client.query(todoQuery(id));        // fetching outside widgets
client.updateData(todoQuery(id), (todo) => todo?.copyWith(done: true));
final todos = todosQuery.observe();                   // in a cubit or a service
```

`todosQuery` 的每个 widget 和观察者共享一个缓存条目（`CachedQuery`），变更使 `todosKey` 失效时也无须重复写出这个键。`InfiniteQuery` 定义的用法相同。

- **类型始终经过检查**。widget、`client.query`、`getData`、`setData` 和 `updateData` 从查询获得数据类型，因此无须类型转换，也无法向这个键写入另一种类型。
- **键保持一致**。键中的拼写错误会悄悄创建第二个缓存条目。每个查询只写一个定义，就排除了这种可能。
- **层级一目了然**。`['todos', ...]` 把与待办事项相关的一切归为一组，因此 `invalidateQueries(queryKey: ['todos'])` 会同时刷新列表和每个详情。

## 向查询函数传递依赖

查询函数绝不能捕获 `BuildContext`。上面代码片段中的 `api` 是一个长期存在的对象，因此这些代码片段是安全的。

Fuery 把查询函数和缓存条目保存在一起，并在之后再次运行它：

- 应用回到前台时，
- 网络重新连接时，
- `refetchInterval` 每次触发时，
- 任何代码使这个键失效或重新获取这个键时。

其中一些运行发生在构建查询的 widget 已经消失之后，这时它的 `BuildContext` 已经卸载。捕获的 `State`、`TickerProvider` 或任何从 `context` 读取的东西都有同样的问题。

普通值是安全的。id 或搜索词属于键和请求的一部分，生命周期比 widget 更长。

把依赖作为参数传给查询：

```dart
Query<List<Todo>> todosQuery(TodoApi api) => Query(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );
```

界面在使用查询的地方解析依赖：

```dart
QueryBuilder(query: todosQuery(locator<TodoApi>()), builder: ...)
```

或者在查询函数内部查找依赖，这样查询就不需要参数：

```dart
final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => locator<TodoApi>().getTodos(),
);
```

`locator` 代表你的应用用来解析依赖的任何工具。两种写法都让闭包不包含任何与 widget 绑定的东西。使用同一个键的两个 widget 共享一个缓存条目，因此每次使用这个键时都要提供同一个依赖。

每个查询函数接收的参数 `QueryFunctionContext` 不携带 widget 树中的任何东西：参见[查询函数上下文](../../reference/query-options/#查询函数上下文)。

## 报告仓库返回的失败

查询函数必须抛出错误才会失败。Fuery 只根据抛出的错误设置错误状态。返回 `Result`、`Either` 或任何其他包装类型的函数总是成功，无论包装里装的是什么。这时查询：

- `status` 保持为 `QueryStatus.success`，`error` 保持为 `null`，
- 永远不会设置 `isError`、`isLoadingError` 或 `isRefetchError`，
- 永远不会重试，因为重试策略只看得到抛出的错误。

在查询函数中解开结果，并抛出失败：

```dart
Query<List<Todo>> todosQuery(TodoRepository repo) => Query(
      queryKey: todosKey,
      queryFn: (_) async => switch (await repo.getTodos()) {
        Ok(:final value) => value,
        Err(:final error) => throw error,
      },
    );
```

没有结果可返回的函数也要抛出错误，因为查询数据不能为 null。参见[查询数据不能为 null](../queries/#查询数据不能为-null)。

## 组织变更

把变更放在对应查询的旁边，用同样的方式定义。给每个变更设置一个 `mutationKey`，它由所更改数据的键构成：

```dart
// lib/data/todo_mutations.dart
final addTodo = Mutation(
  mutationKey: [...todosKey, 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: todosKey),
);
```

有了 `mutationKey`，任何界面都能找到这个变更的执行，无论执行由哪个 widget、hook 或 cubit 开始。`MutationStateBuilder(mutation: addTodo)` 可以在应用的任何位置显示这些执行：参见[显示变更的每次执行](../mutations/#显示变更的每次执行)。

定义不保存状态，因此它可以像查询一样作为顶层值。每次执行都属于客户端的缓存。回调接收执行这个变更的客户端，因此在测试中和 `FueryProvider` 下，缓存操作都会作用于正确的客户端。[变更的执行](../../how-the-cache-works/#变更的执行)解释执行与缓存条目有什么不同。

把缓存操作（例如使查询失效和回滚）放在定义中。只属于某个界面的操作放在调用处，例如在调用成功后关闭界面：

```dart
onPressed: () async {
  try {
    await addTodo.mutateAsync(title, context.queryClient);
  } catch (_) {
    return; // A MutationStateListener reports the failure.
  }
  if (context.mounted) Navigator.pop(context);
},
```

[在一次调用成功后执行操作](../mutations/#在一次调用成功后执行操作)展示了完整的按钮。

`MutationStateListener` 在这个变更的任何一次执行之后，用当前界面的 `BuildContext` 显示 snackbar 或对话框，无论执行来自哪个界面。参见[告诉用户变更失败](../mutations/#告诉用户变更失败)。

## 在示例应用中

示例应用在[信息流查询](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)中定义查询，在[信息流变更](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)中定义变更。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出每个界面展示了什么。
