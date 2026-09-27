---
title: 开发者工具
description: 在应用运行时检查 Flutter 查询缓存，在设备上或浏览器中都可以。
sourceHash: 32877fd7d403
---

`FueryDevtools` 在应用运行时显示客户端缓存中的内容。对每个查询，它显示状态和数据，并提供重新获取、使查询失效、重置或移除查询的按钮。对每次变更执行，它显示状态、变量和错误。它在你的应用上方添加一个按钮，用来打开面板。

## 添加开发者工具

把 `FueryDevtools` 放在应用的 `builder` 中，让它始终位于所有路由之上：

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

它在 debug 构建和 profile 构建中显示。release 构建只显示你的应用。

示例应用在[它的应用 widget](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/app.dart) 中添加了它。

## Queries 标签页

Queries 标签页列出缓存中的每个查询，每个键一行，显示它的状态和[观察者](../../how-the-cache-works/#观察者)数量。每个接收了这个查询的 widget 计为一个，每个来自 `observe()` 的观察者也计为一个。在过滤框中输入文字来查找键。

| 状态 | 含义 |
|---|---|
| `fetching` | 正在进行一次获取 |
| `paused` | 一次获取正在等待网络，或者等待应用回到前台后重试 |
| `inactive` | 没有观察者使用它。Fuery 在 `gcTime` 过后移除它 |
| `disabled` | 每个观察者都设置了 `enabled: false`，因此它不会自行获取 |
| `stale` | 正在使用，下次有 widget 开始使用它、应用回到前台或网络重新连接时，Fuery 重新获取它 |
| `fresh` | 正在使用，它的数据在 `staleTime` 内更新过，并且没有失效 |

选中一个查询，可以查看它的状态、观察者、最后更新时间、失败次数、错误和数据。数据以 JSON 显示：对象有 `toJson()` 时用 `toJson()`，否则用 `toString()`。

这些按钮作用于选中的查询：

| 按钮 | 作用 |
|---|---|
| Refetch | 再次获取它，和 [`refetchQueries`](../../reference/query-client/#对匹配查询的操作) 一样，会跳过已禁用的查询、已有数据的静态查询，以及只由 `setQueryData` 写入的查询 |
| Invalidate | 把它标记为过期。如果有已启用的观察者使用它，Fuery 像 Refetch 一样重新获取它 |
| Reset | 把它恢复到初始状态，并删除它的[持久化数据](../persistence/)。如果有已启用的观察者使用它，Fuery 像 Refetch 一样重新获取它 |
| Remove | 从缓存中移除它，并删除它的持久化数据。仍在使用它的 widget 会重新加载它 |

## Mutations 标签页

Mutations 标签页列出每次[变更的执行](../../how-the-cache-works/#变更的执行)，最新的在前，显示它的状态、键、变量和错误。

## FueryDevtools 选项

| 选项 | 类型 | 默认值 | 作用 |
|---|---|---|---|
| `child` | `Widget` | 必填 | 你的应用 |
| `client` | `QueryClient?` | `context.queryClient` | 要检查的客户端 |
| `enabled` | `bool` | `!kReleaseMode` | 除了你的应用之外，是否还显示其他内容 |
| `buttonAlignment` | `Alignment` | `Alignment.centerRight` | 按钮的位置 |
| `initiallyOpen` | `bool` | `false` | 面板是否一开始就打开 |

## 不带按钮使用面板

`FueryDevtoolsPanel` 是不带按钮的同一个面板。把它显示在你自己的界面上，例如调试菜单中：

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const Scaffold(
      body: SafeArea(child: FueryDevtoolsPanel()),
    ),
  ),
);
```

它接受一个默认值为 `context.queryClient` 的 `client`，以及一个 `onClose` 回调，传入这个回调会添加一个关闭按钮。
