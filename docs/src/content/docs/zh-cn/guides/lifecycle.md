---
title: 重新获取和离线
description: Flutter 应用回到前台时重新获取过期数据，离线时暂停，网络重新连接时继续。
sourceHash: 6f8b1b989a7f
---

应用回到前台和网络重新连接时，Fuery 重新获取过期数据，因此界面无须下拉刷新就能更新到最新。Fuery 的 widget、hook 和 `FueryProvider` 会替你接入应用生命周期。网络连接状态则用 `onlineManager.setEventListener` 接入一个来源。

## 应用回到前台时

Fuery 把每个 `AppLifecycleState` 映射为焦点状态：

| 应用状态 | Fuery 把应用视为 |
|---|---|
| `resumed` | 获得焦点 |
| `hidden`、`paused`、`detached` | 未获得焦点 |
| `inactive` | 不变。系统对话框这类短暂中断不算。 |

- 应用重新获得焦点时，Fuery 重新获取每个正在使用的过期查询，比如已挂载的 widget 显示的查询。
- 应用未获得焦点时，重试会等待。
- 在后台时轮询也会停止，除非查询设置了 `refetchIntervalInBackground`。
- `refetchOnFocus` 按查询设置应用重新获得焦点时是否重新获取：`RefetchMode.ifStale`（默认）、`RefetchMode.always` 或 `RefetchMode.never`。

`focusManager`（一个 `FueryFocusManager`）保存焦点状态。它跟踪的是应用是否处于前台，而不是键盘焦点：

| 成员 | 作用 |
|---|---|
| `setFocused(false)` | 报告应用处于后台。测试用它模拟切到后台。 |
| `setFocused(null)` | 丢弃手动设置的状态。在事件源报告变化之前，应用视为获得焦点。 |
| `isFocused` | Fuery 是否把应用视为获得焦点。在有来源报告其他状态之前为 `true`。 |
| `setEventListener(setup)` | 替换焦点来源。在 Flutter 中，先调用 `FueryBinding.ensureInitialized()`，否则第一个 Fuery widget、hook 或 `FueryProvider` 会用应用生命周期替换你的来源。在 Flutter 之外，接入宿主提供的任何事件。`setup` 接收一个回调，这个回调接受 `true` 或 `false`，不传值时再次通知监听器。它返回一个清理函数或 `null`。 |

只在 bloc 中使用查询、没有 `FueryProvider` 的应用，没有任何东西接入生命周期。在启动时调用一次：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## 网络重新连接时

在有来源报告其他状态之前，Fuery 把设备视为在线。要在离线时暂停获取并在重新连接时重新获取，接入一个网络连接状态来源，比如 [`connectivity_plus`](https://pub.dev/packages/connectivity_plus)：

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

设备离线时：

- 需要获取的查询报告 `FetchStatus.paused`，并继续显示它的数据。
- 离线时开始的变更会等待，并在连接恢复后执行。

连接恢复时，Fuery 先继续执行暂停的变更。它在变更完成后再重新获取查询，因此重新获取不会覆盖乐观更新。仍在加载首批数据的查询不会等待，而是立即继续。应用回到前台时，Fuery 按相同的步骤处理。

`onlineManager` 保存网络连接状态：

| 成员 | 作用 |
|---|---|
| `setEventListener(setup)` | 接入一个网络连接状态来源。`setup` 接收 `setOnline`，返回一个清理函数或 `null`。新来源替换之前的来源。 |
| `setOnline(online)` | 手动报告网络连接状态，比如来自调试开关或测试。 |
| `isOnline` | Fuery 是否把设备视为在线。在有来源报告其他状态之前为 `true`。 |

`networkMode` 设置查询或变更如何响应网络连接状态：

| 模式 | 行为 |
|---|---|
| `NetworkMode.online` | 默认值。只在在线时获取和重试。 |
| `NetworkMode.always` | 忽略网络连接状态，比如用于本地数据库。这种模式下的查询只有在设置了 `refetchOnReconnect` 时，才会在重新连接时重新获取。 |
| `NetworkMode.offlineFirst` | 无论是否在线都运行第一次尝试，之后在离线时暂停重试。适合缓存层能在离线时响应的请求。 |

## 继续执行离线时暂停的变更

应用重新获得焦点或网络重新连接时，Fuery 继续执行离线时暂停的变更。要在其他时机继续执行，调用 `resumePausedMutations`：

```dart
await client.resumePausedMutations();
```

- 它继续执行客户端上所有暂停的变更。
- 设备离线时，它什么也不做。
- 除非设置了 `persist`，否则暂停的变更会在应用重启时丢失。参见[持久化变更](../persistence/#持久化变更)。

## 在示例应用中

[主页框架](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)中的 wifi 按钮充当网络连接状态来源：它用 `onlineManager.setOnline` 报告网络连接状态。在[帖子界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)上离线写的评论会暂停，应用恢复在线后再发送。
