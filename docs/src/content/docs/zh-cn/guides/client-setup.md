---
title: 配置客户端
description: 在 main 中一次性配置 Flutter 的 QueryClient，包括默认值、失败报告，以及按需为子树提供单独的客户端。
sourceHash: 046de5bf4e5b
---

为整个应用配置一个 `QueryClient`：设置默认值，在一处报告所有失败，并捕获回调抛出的错误。在 `main` 中配置一次，并在任何东西创建[观察者](../../how-the-cache-works/#观察者)之前完成。应用的一部分可以运行在自己的客户端上，比如在 widget 测试中。[QueryClient 参考](../../reference/query-client/#构造函数选项)列出了所有构造函数选项。

## 创建客户端

`Fuery.client` 是没有 `FueryProvider` 时 widget 使用的客户端。`observe()` 和定义的 `mutate` 也使用它，除非你传入一个客户端。Fuery 在首次使用时创建它，因此不做任何配置的应用也能运行。

要配置它，在 `main` 中把一个新客户端赋给它：

```dart
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const App());
}
```

- 给 `Fuery.client` 赋值会挂载新客户端，并卸载之前的客户端。
- 已挂载的客户端在获得焦点和重新连接时重新获取，并继续执行暂停的变更。
- 在任何东西创建观察者之前赋值。观察者一直使用创建它时的客户端。
- 默认值也要在观察者出现之前注册。观察者在接收选项时应用默认值，之后不再应用。

## 设置默认值

为客户端的所有查询和变更设置默认值，或为某个键前缀设置默认值：

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    mutations: MutationDefaults(retry: RetryPolicy.count(2)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);

Fuery.client.setMutationDefaults(
  ['todos'],
  const MutationDefaults(networkMode: NetworkMode.offlineFirst),
);
```

- 在查询或变更上设置的选项优先于按键设置的默认值。
- 按键设置的默认值优先于客户端的 `defaultOptions`。
- 变更只有在有 `mutationKey` 时才会获得按键设置的默认值。
- `getQueryDefaults(['settings'])` 和 `getMutationDefaults(['todos'])` 返回一个键的按键设置的默认值，由所有匹配的前缀合并而来。它们不包含 `defaultOptions`。

[默认值](../../reference/query-client/#默认值)列出了 `QueryDefaults` 和 `MutationDefaults` 的字段。

## 在一处报告所有失败

给缓存传入配置，为每个查询和每个变更运行回调，比如把失败报告给崩溃上报或日志服务：

```dart
Fuery.client = QueryClient(
  queryCache: QueryCache(
    config: QueryCacheConfig(
      onError: (error, query) => reportError(error, query.queryKey),
    ),
  ),
  mutationCache: MutationCache(
    config: MutationCacheConfig(
      onError: (error, variables, context, mutation) =>
          reportError(error, mutation.options.mutationKey),
    ),
  ),
);
```

- 缓存在整个生命周期中保留它的配置，因此在构造客户端时传入配置。
- `QueryCacheConfig` 的回调在获取之后运行。取消的获取不算失败，不会到达任何回调。
- `MutationCacheConfig` 的回调在[变更自身的回调](../../reference/mutation-options/#回调)之前运行，Fuery 会等待它们返回的 `Future`。
- 回调以 `AnyCachedMutation` 的形式接收变更的每次执行，它的 `data`、`variables` 和 `context` 都是 `Object?`。用 `mutation.options.mutationKey` 或 `mutation.options.meta` 区分不同的变更。

[缓存回调](../../reference/query-client/#缓存回调)列出了每个回调及其运行时机。

## 捕获回调抛出的错误

`onUncaughtError` 接收任何调用方都无法捕获的错误，由你决定如何记录它们：

- `QueryCacheConfig` 或 `MutateOptions` 回调抛出的错误。
- 变更失败后，变更或它的 `MutationCacheConfig` 中的 `onError` 或 `onSettled` 抛出的错误。
- 查询变化后 Fuery 更新观察者时，`refetchWhile` 或 `placeholderData` 抛出的错误。
- 监听器抛出的错误：监听器 widget、消费者或 hook 的 `listener`，或传给 slot 的 `listen` 或 `subscribeToRuns` 的函数。
- Fuery 运行时发现的错误用法，比如 `getNextPageParam` 返回了错误类型的页参数，或在构建结果时抛出错误，又或者持久化的 `mutationKey` 无法存储。

```dart
Fuery.client = QueryClient(
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

- 查询或变更继续运行，就像回调没有抛出错误一样。
- 同一个错误用法，Fuery 在每个客户端上只报告一次，而不是代码每次运行时都报告。
- `onUncaughtError` 抛出错误时，它的错误和它接收到的错误都进入当前 zone。

没有 `onUncaughtError` 时，这些错误进入当前 zone，Flutter 再把它们传给 `PlatformDispatcher.onError`。如果崩溃上报工具把那里的所有错误都记录为致命错误，它就会把这些错误算作崩溃，尽管应用仍在运行。

`Mutation` 和 `MutationCacheConfig` 的其他回调属于变更的一部分。`onMutate` 抛出的错误，或成功后 `onSuccess` 或 `onSettled` 抛出的错误，会让变更失败，并到达它的 `onError`。

## 查询使用哪个客户端

`Query` 不持有客户端，因此一个定义可以用于任何客户端。Fuery 在使用查询的地方选择客户端：

- 接收定义的 widget 或 hook 使用最近的 `FueryProvider` 的客户端，没有 `FueryProvider` 时使用 `Fuery.client`。`FueryProvider` 替换客户端时，它随之切换到新客户端。
- `observe()` 使用你以 `client:` 传入的客户端，或当时的 `Fuery.client`。观察者在整个生命周期中都使用这个客户端，`observer.client` 返回它。
- 定义的 `mutate` 和 `mutateAsync` 使用你传给它们的客户端，或当时的 `Fuery.client`。在 widget 中传入 `context.queryClient`，让这次执行进入 widget 读取的缓存。
- 接收观察者的 widget 或 hook 使用观察者的客户端。在 debug 构建中，如果那不是它自己的客户端，它会打印一条警告。参见[界面读取了另一个客户端的缓存](../../troubleshooting/#界面读取了另一个客户端的缓存)。
- 查询函数、`placeholderData` 和变更回调接收运行它们的客户端。

因此查询可以是顶层值。如果每个 widget 测试都用 `Fuery.client` 或 `FueryProvider` 获得一个新客户端，就不需要做其他任何事。

## 为子树提供单独的客户端

把应用的一部分包在 `FueryProvider` 中，让它运行在另一个客户端上，比如在 widget 测试中。把客户端放在 `State` 字段中，让子树在挂载期间始终使用同一个客户端：

```dart
class _SettingsPageState extends State<SettingsPage> {
  final client = QueryClient();

  @override
  Widget build(BuildContext context) {
    return FueryProvider(client: client, child: const SettingsView());
  }
}
```

- 只创建一次客户端：在 `main` 中、`State` 字段中，或测试的 `setUp` 中。
- 不要在 `build` 中创建。在那里创建的 `QueryClient` 在每次重建和每次热重载时都是一个新的空缓存，因此下面的 widget 会回到加载状态并重新获取。
- `FueryProvider` 挂载客户端，并在自己移除时卸载它，因此 `State` 不需要 `dispose`。

`FueryProvider` 下面的 widget 使用它的客户端。`context.queryClient` 返回这个客户端，没有 `FueryProvider` 时返回 `Fuery.client`。把它传给 `observe`，创建你自己的观察者：

```dart
late final todos = todosQuery.observe(client: context.queryClient);
```

也把它传给定义的 `mutate`：`addTodo.mutate('Buy milk', context.queryClient)`。

面向其他状态管理库的[适配器](../adapters/)用 `FueryProvider.of(context, listen: true)` 读取客户端，`FueryProvider` 替换客户端时，调用方会重建。

## 在示例应用中

示例在 [`main`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/main.dart) 中把一个带存储的客户端赋给 `Fuery.client`，并在 `runApp` 之前恢复存储的变更。它的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
