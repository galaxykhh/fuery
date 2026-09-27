---
title: 构建适配器
description: 像 fuery 和 fuery_hooks 一样，用 fuery_core 的 slot 在你自己的 Flutter widget 或其他状态管理库中渲染 Fuery 的查询和变更。
sourceHash: f61aaedad61c
---

适配器只用 `fuery_core` 的公开 API，在你自己的 widget 或其他状态管理库中渲染 Fuery 的查询和变更。`fuery` 的 widget 和 [`fuery_hooks`](../hooks/) 的 hook 都是这样构建的适配器，因此你的适配器能做它们能做的一切。

适配器为每个渲染的查询或变更保留一个 **slot**。slot（`ObserverSlot`）为每次渲染都可能变化的来源持有[观察者](../../how-the-cache-works/#观察者)。

## 用 slot 渲染查询

每次渲染时调用 `update`，读取 `result`，并订阅变化以再次渲染。下面这个只用 `flutter_hooks` 写的 hook 包含了完整的约定：

```dart
QueryResult<TData> useMyQuery<TData extends Object>(QuerySource<TData> query) {
  final client = FueryProvider.of(useContext(), listen: true);
  final slot = useMemoized(() => QuerySlot(query, client));
  final changes = useState(0);
  useEffect(() {
    var active = true;
    final unsubscribe = slot.subscribe(notifyManager.batchCalls((_) {
      if (active) changes.value++;
    }));
    return () {
      active = false;
      unsubscribe();
      slot.dispose();
    };
  }, [slot]);
  slot.update(query, client);
  return slot.result;
}
```

## slot 的约定

`QuerySlot` 接受 `QuerySource`：一个 `Query` 或一个 `QueryObserver`。它有以下成员，`InfiniteQuerySlot` 和 `MutationSlot` 也一样：

| 成员 | 作用 |
|---|---|
| `update(source, client)` | 每次渲染时调用。传入定义时，slot 持有一个观察者并更新它的选项，换了新客户端就换一个新观察者。传入观察者时，slot 按原样使用它，以及创建它时的客户端。 |
| `result` | 要渲染的结果，`update` 返回后立即是最新的。 |
| `subscribe(listener)` | 用之后的每个结果调用 `listener`，`update` 把 slot 转到另一个观察者时仍保持订阅。返回一个移除它的函数。 |
| `listen((previous, current) {...})` | 在之后的每次变化后调用它的监听器，用于导航等副作用。`previous` 是它上次传给监听器的结果，或它开始时的 `result`。返回一个停止它的函数。 |
| `dispose()` | 移除所有监听器。如果观察者是 slot 创建的，它会销毁查询观察者，或重置变更观察者。重置会丢弃最近一次 `mutate` 调用的回调。 |
| `observer` | slot 当前用来渲染的观察者。 |

查询、无限查询和变更的监听器 widget 与消费者 widget，还有 `useOnQueryChange` 和 `useOnMutationChange`，都调用 `listen`，因此遵循它的规则：

- 它在微任务中运行，绝不在渲染期间运行。
- 开始时的 `result`，以及与上一个结果相等的结果，都不会触发调用。
- `update` 把 slot 转到另一个观察者后，它从新的 `result` 重新开始，不触发调用。
- 它会订阅，因此查询会像为已挂载的 widget 那样获取。
- 监听器抛出错误时，Fuery 把错误报告给客户端的 `onUncaughtError`。

## 批量处理监听器调用

`QuerySlot`、`InfiniteQuerySlot` 和 `MutationSlot` 同步调用 `subscribe` 的监听器，有时发生在另一个 widget 构建期间，比如正在挂载的 widget 发起一次获取时。如果框架不能在渲染期间更新，就像上面的 hook 那样做：

1. 把监听器包在 `notifyManager.batchCalls` 中，让变化在微任务中到达。
2. 忽略释放之后到达的变化。

`QueriesSlot` 和 `MutationStateSlot` 已经在微任务中调用监听器，因此这两步都不需要。

## 其他 slot

| slot | 来源 | 结果 |
|---|---|---|
| `InfiniteQuerySlot` | `InfiniteQuerySource`：一个 `InfiniteQuery` 或一个 `InfiniteQueryObserver` | `InfiniteQueryResult` |
| `MutationSlot` | `MutationSource`：一个 `Mutation` 或一个 `MutationObserver` | `MutationResult` |
| `QueriesSlot` | 同一数据类型的 `QuerySource` 列表 | 按顺序排列的 `QueryResult` 列表 |

`QueriesSlot` 用于 `useQueries` 这样的 hook。它在微任务中调用 `subscribe` 的监听器，同时到达的变化只调用一次，因此不需要 `batchCalls`。只要查询的键还在列表中，它就保留自己的观察者，即使列表重新排序也是如此。它的 `observer` 是观察者列表，只有在添加、移除、替换或移动观察者时才是新列表。

## 变更的每次执行

`MutationStateSlot` 提供一个变更每次执行的状态，无论执行从哪里开始。MutationState 系列 widget 和 `useMutationState` 使用它。

- 它接受 `MutationStateSource`：带 `mutationKey` 的 `Mutation`，或 `MutationFilters`。
- 它只读取缓存。它的 `observer` 是客户端的 `MutationCache`。
- 它的 `result` 列出各次执行的状态，最早的在前。在添加或移除匹配的执行，或匹配的执行发生变化之前，它始终是同一个列表。
- 它在微任务中调用 `subscribe` 的监听器，每批只调用一次，并且只在列表变化时调用，因此不需要 `batchCalls`。

`subscribeToRuns((previous, current) {...})` 在每个匹配的执行之后每次变化时调用它的监听器，并传入这次执行之前的状态：对于之后才开始的执行，之前的状态是 `idle`。它从不报告添加它时各次执行已有的状态，也不报告缓存移除的执行。`MutationStateListener` 和 `useOnMutationStateChange` 使用它。

## 只凭结果监听

结果带有报告它的观察者，即 `result.observer`。只拿到结果的适配器在这个观察者上创建自己的 slot 来监听，就像 `useOnQueryChange` 和 `useOnMutationChange` 那样：

```dart
void Function() listenTo<TData extends Object>(
  QueryResult<TData> result,
  void Function(QueryResult<TData> previous, QueryResult<TData> current)
      listener,
) {
  final observer = result.observer;
  if (observer == null) return () {};
  final slot = QuerySlot(observer, observer.client);
  slot.listen(listener);
  return slot.dispose;
}
```

- slot 按原样使用观察者，从不销毁它。
- 用构造函数构建的 `QueryResult`，它的 `observer` 为 null。
- `InfiniteQueryResult` 带有 `InfiniteQueryObserver`，`InfiniteQuerySlot` 接受这种观察者。

## 读取客户端

在 Flutter 中，`FueryProvider.of(context, listen: true)` 返回最近的 `FueryProvider` 提供的客户端，或 `Fuery.client`。`FueryProvider` 提供的客户端替换后，调用方会重建。随后的下一次 `update` 把持有自己观察者的 slot 转到新客户端。

在 Flutter 之外，传入应用使用的客户端。

## 获得焦点和重新连接时重新获取

在 Flutter 中，像 Fuery 的 widget 和 hook 那样，在适配器挂载时调用 `FueryBinding.ensureInitialized()`。它接入应用生命周期，因此应用回到前台时过期的查询会重新获取，应用在后台时重试会等待。第一次之后的调用什么也不做。上层的 `FueryProvider` 也会调用它。参见[应用回到前台时](../lifecycle/#应用回到前台时)。

客户端只有在挂载后，才会在获得焦点和重新连接时重新获取，并继续执行暂停的变更。`Fuery.client` 始终处于挂载状态，`FueryProvider` 会挂载它的客户端。对适配器使用的其他客户端调用 `mount()`，停止使用时调用 `unmount()`。在 Flutter 之外，用 `focusManager.setEventListener` 接入宿主的焦点事件。参见 [QueryClient 参考](../../reference/query-client/)。

## 在 Fuery 源码中

- [`adapter_test.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_core/test/adapter_test.dart) 不依赖 Flutter，用 slot 渲染查询。
- [`hooks.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_hooks/lib/src/hooks.dart) 基于 slot 构建 `fuery_hooks` 的每个 hook。
- [`result_subscriber.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/lib/src/result_subscriber.dart) 基于 slot 构建 `fuery` 的 widget。
