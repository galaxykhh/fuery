---
title: widget
description: 在 Flutter 中用构建器、监听器、消费者和选择器 widget 显示缓存的查询和变更。
sourceHash: cfe54efd8edf
---

Fuery 的 widget 在 widget 树中渲染查询和变更，因此显示服务端数据的界面可以保持为 `StatelessWidget`。按来源和用途选择 widget：

| | 重建 UI | 副作用 | 两者兼有 | 状态的一部分 |
|---|---|---|---|---|
| 查询 | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| 无限查询 | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| 变更 | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| 多个查询 | `QueriesBuilder` | | | `QueriesSelector` |
| 变更的每次执行 | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

查询、无限查询和变更 widget 接收一个定义：`Query`、`InfiniteQuery` 或 `Mutation`。在任何地方构建它，`build` 中也可以。widget 挂载期间，会为它保持一个[观察者](../../how-the-cache-works/#观察者)：

```dart
QueryBuilder(
  query: todoQuery(id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

- 挂载时订阅。查询没有数据时会获取；默认情况下，数据过期时也会获取。设置了 `enabled: false` 的查询在挂载时不获取。卸载时取消订阅。
- widget 用另一个键的定义重建时，观察者会跟随它。新键的缓存数据在同一帧中显示。
- 观察者使用最近的 `FueryProvider` 的客户端；没有 `FueryProvider` 时使用 `Fuery.client`。
- 结果带有各种操作：`state.refetch()`；无限查询的 `state.fetchNextPage()` 和 `state.fetchPreviousPage()`；变更的 `state.mutate(...)`、`state.mutateAsync(...)` 和 `state.reset()`。

`MutationBuilder` 只显示它自己开始的执行。MutationState 系列 widget 按 `mutationKey` 找到变更的执行，显示来自任何地方的执行。见[显示变更的每次执行](../mutations/#显示变更的每次执行)。用 `addTodo.mutate('Buy milk', context.queryClient)` 从定义执行变更的按钮不需要 `MutationBuilder`。见[执行变更](../mutations/#执行变更)。

## 构建器和监听器何时运行

- `buildWhen(previous, current)` 比较上次构建所用的结果和新结果。
- `listenWhen(previous, current)` 比较上一个结果和新结果。
- 监听器在变化之后的一个微任务中运行，从不在构建期间运行。
- 对于监听器挂载时查询已有的结果，不会调用监听器。
- 消费者的监听器在显示这次变化的重建之前运行。
- 抛出异常的监听器不会阻止重建。Fuery 把它的错误报告给 [`onUncaughtError`](../client-setup/#捕获回调抛出的错误)。

## 只重建发生变化的部分

`buildWhen` 跳过构建器不显示的那些变化引起的重建。这个构建器只在查询重新获取时显示一个进度条：

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## 选择状态的一部分

选择器根据结果中的一个值构建，并且只在这个值变化时重建：

```dart
QuerySelector(
  query: todosQuery,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Fuery 按内容比较列表、Map 和 Set，其他值都用 `==` 比较。每次调用都返回新列表的选择器，只在列表项变化时才让构建器重建。
- 父 widget 重建时，选择器会再次运行，因此它可以读取父 widget 中的值。
- 构建器需要整个结果时，使用 `buildWhen`。构建器需要从结果派生出的一个值时，使用选择器。

`MutationStateSelector` 对变更的执行做同样的事。这个示例统计来自任何界面、正在进行中的保存：

```dart
MutationStateSelector(
  mutation: saveTodo,
  selector: (runs) => runs.where((run) => run.isPending).length,
  builder: (context, saving) =>
      Text(saving > 0 ? 'Saving $saving…' : 'All changes saved'),
)
```

## 响应变化

用监听器处理导航、snackbar 和其他一次性副作用：

```dart
QueryListener(
  query: todosQuery,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoScreen(),
)
```

对于变更：

- `MutationStateListener` 接收变更的每次执行，无论它来自哪个界面。见[告诉用户变更失败](../mutations/#告诉用户变更失败)。
- 要在界面自己的调用成功后关闭界面，用 `await` 等待 `mutateAsync`，然后检查 `context.mounted`。见[在一次调用成功后采取行动](../mutations/#在一次调用成功后采取行动)。
- `MutationListener` 只接收它拿到的观察者的执行。传入定义时，它什么也接收不到，并在 debug 构建中打印一条警告。见 [MutationListener 从不运行](../../troubleshooting/#mutationlistener-从不运行)。
- 传入定义的 `MutationConsumer` 接收它自己的构建器开始的执行。

## 下拉刷新

`state.refetch()` 返回一个 `Future<QueryResult>`，它在获取结束时完成。`RefreshIndicator` 等待这个 `Future`：

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => RefreshIndicator(
        onRefresh: () => state.refetch(),
        child: ListView(
          children: [for (final todo in data) TodoTile(todo)],
        ),
      ),
    QueryResult(:final error?) => Center(child: Text('$error')),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `refetch()` 在结果中报告失败的获取，而不是抛出异常，因此指示器总会关闭。传入 `throwOnError: true` 可以让它抛出异常。
- 查询已有数据时，`refetch()` 会取消进行中的获取，并开始一次新的获取。传入 `cancelRefetch: false` 则改为等待进行中的获取。没有数据的查询总是等待它。
- 只包裹数据分支。这个手势需要可滚动的 widget，而 `pending` 分支和错误分支中没有。

要刷新一个界面的所有查询，调用客户端：

```dart
RefreshIndicator(
  onRefresh: () => context.queryClient.invalidateQueries(queryKey: ['todos']),
  child: const TodoList(),
)
```

- [`invalidateQueries`](../query-client/#使查询失效) 把 `['todos']` 下的所有查询标记为过期，并重新获取有观察者（例如已挂载的 widget）的查询。
- `refetchQueries` 重新获取，但不把任何查询标记为过期。它的 `type` 默认为 `QueryTypeFilter.all`，没有观察者的缓存条目也会重新获取。传入 `type: QueryTypeFilter.active`，只重新获取有观察者的查询。
- 两者都在所有匹配的获取结束时完成，并且只在 `throwOnError: true` 时抛出异常。两者都不等待设备离线时暂停的获取，因此指示器不会卡住。

[查询过滤器](../../reference/query-client/#查询过滤器)列出了两者接受的过滤器。

## 出错后重试

给错误分支加一个调用 `state.refetch()` 的按钮：

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => TodoList(data),
    QueryResult(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            FilledButton(
              onPressed: state.isFetching ? null : () => state.refetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `state.isFetching` 为 true 时禁用按钮，避免点击叠加在正在运行的获取上。
- 先匹配数据分支。重新获取失败时会保留数据，因此列表仍留在屏幕上，并且 `isRefetchError` 为 true。用 `QueryListener` 和 snackbar 报告这次失败，而不是替换整个界面。
- 默认情况下，查询在构建错误分支之前重试 3 次，依次等待 1 秒、2 秒和 4 秒。[重试哪些错误](../queries/#重试哪些错误)介绍如何缩小重试范围。

## 同时显示多个查询

`QueriesBuilder` 根据一组同一数据类型的查询的结果构建，例如每个 id 一个查询：

```dart
QueriesBuilder(
  queries: [for (final id in cartIds) productQuery(id)],
  builder: (context, results) {
    if (results.any((result) => !result.hasData)) {
      return const CircularProgressIndicator();
    }
    final total = results.fold(0.0, (sum, result) => sum + result.data!.price);
    return Text('Total: $total');
  },
)
```

- 结果的顺序与查询的顺序一致。
- 在 `build` 中构建这个列表。只要查询的键还在列表中，这个查询就保留它的观察者，即使列表重新排序也是如此。
- 离开列表的键会丢弃它的观察者。
- 同时变化的多个结果只引起一次重建。
- 构建 `QueriesBuilder` 的 widget 每次重建，都会更新列表中的每个查询，即使 id 没有变化。查询有数百个时，把经常变化的状态（例如文本框的状态）放到另一个 widget 中。这样，构建 `QueriesBuilder` 的 widget 只在 id 变化时重建。

`QueriesSelector` 根据由这些结果合成的一个值构建，并且只在这个值变化时重建：

```dart
QueriesSelector(
  queries: [for (final id in ids) todoQuery(id)],
  selector: (results) =>
      results.where((result) => result.data?.done ?? false).length,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

列表的每一项相互独立时，给每一项单独的 `QueryBuilder`，例如在 `ListView.builder` 中。这样，每个列表项只因自己的查询而重建。对于数据类型不同的查询，把一个 `QueryBuilder` 嵌套在另一个里面。

## 显示是否有获取正在进行

跟随应用中每个查询的进度条读取的是客户端，而不是 widget。见[观察缓存](../query-client/#观察缓存)。

对于变更，带 `MutationFilters` 的 `MutationStateSelector` 显示是否有变更正在执行：

```dart
MutationStateSelector(
  mutation: const MutationFilters(),
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, saving) => saving ? const Text('Saving…') : const SizedBox(),
)
```

## 传入观察者

大多数界面传入定义。传入相同键的定义的 widget 已经共享缓存条目（`CachedQuery`）和请求。见[使用查询](../queries/#使用查询)。

查询、无限查询和变更 widget，以及 `QueriesBuilder` 和 `QueriesSelector`，也接收 `observe()` 返回的观察者。它们原样使用这个观察者，包括它的选项和创建它时使用的客户端。只在以下情况传入观察者：cubit 和 widget 共享同一个句柄，或者多个 widget 只显示一个变更观察者的执行。

在 `build` 之外只创建一次观察者，例如在 cubit 或 `State` 字段中。每次调用 `observe()` 都会创建一个新的观察者，它会重新订阅并再次获取。[共享一个观察者](../mutations/#共享一个观察者)展示了 `State` 字段、客户端，以及 `dispose` 中的 `reset()`。

## 释放观察者

查询观察者无须释放。只有你持有的变更观察者需要在 `dispose` 中处理。

- 传入查询定义的 widget 在挂载时创建观察者，在卸载时销毁它。
- `observe()` 返回的观察者在有了第一个监听器时订阅它的查询。最后一个监听器（例如使用它的最后一个 widget）离开时，观察者取消它的过期计时器和重新获取计时器，并与查询分离。
- 之后用同一个观察者挂载的 widget 会再次订阅它，因此持有查询观察者的 `State` 字段无须在 `dispose` 中做任何事。
- 监听 `stream` 的 cubit 在 `close()` 中取消它的订阅，这同样会取消观察者的订阅。见[在 cubit 中](../bloc/#在-cubit-中)。

widget 消失后，你持有的变更观察者仍会运行它最近一次调用的 `MutateOptions` 回调。在 `dispose` 中对它调用 `reset()`，或者在使用 `State` 或它的 `BuildContext` 的回调中检查 `mounted`。以定义形式传入变更的 widget 在卸载时会重置它自己的观察者。

最后一个观察者离开后，缓存条目会在垃圾回收时间（`gcTime`，默认值：5 分钟）内保留，因此回到的界面会立即显示它的数据。

`QueryObserver.destroy()` 一次移除所有监听器。与最后一次取消订阅一样，它取消观察者的计时器，并让观察者与查询分离。widget 树中没有任何东西需要它。长期存在的对象必须停止某个观察者，却无法访问它的监听器时，调用它。

## 构建自己的 widget 或适配器

要使用 hook，请用 [`fuery_hooks`](../hooks/)。要编写自己的 widget，或者为其他状态管理库编写适配器，见[构建适配器](../adapters/)。它展示了如何用 `fuery_core` 的公共 API 渲染查询，这些 widget 使用的也是同一套 API。

## 在示例应用中

示例在[信息流](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)中用 `buildWhen` 显示重新获取指示器，实现了带重试按钮的下拉刷新，并用 `MutationStateListener` 显示 snackbar。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
