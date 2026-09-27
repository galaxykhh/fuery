---
title: 测试
description: 用模拟时间和全新的客户端，测试使用缓存的 Flutter widget、bloc 和查询。
sourceHash: 05dd3c02e901
---

测试需要空的缓存，并且需要控制时间。给每个测试一个关闭了重试的全新 `QueryClient`，并在模拟时钟上运行测试。

## 测试 widget

给每个测试一个全新的客户端，并关闭重试，让失败立即显示：

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  Fuery.client = client;
  await tester.pumpWidget(const App());
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  client.clear();
});
```

- **按模拟 API 所需的时间 pump**。立即响应的模拟 API 用 `await tester.pump()` 就够了。
- **每个测试结束时，卸载 widget 并调用 `client.clear()`**。否则，缓存的垃圾回收计时器仍在等待，[测试会失败](../../troubleshooting/#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed)。
- **只有查询需要关闭重试**。除非设置了 `retry`，否则变更不会重试，因此 `QueryDefaults` 就足够了。只有测试需要自己的变更默认值时，才添加 `mutations: MutationDefaults(...)`。
- **`FueryProvider` 也可以**。widget 使用最近的 `FueryProvider` 的客户端，因此可以用 `FueryProvider(client: client, child: const App())` 代替给 `Fuery.client` 赋值。除非你传入客户端，否则 `observe()` 以及定义的 `mutate` 和 `mutateAsync` 仍然使用 `Fuery.client`。这时，测试或 cubit 创建的观察者需要 `observe(client: client)`，从定义执行变更的 widget 要传入 `context.queryClient`。
- **在测试内部创建观察者**。观察者会保留它的客户端，因此在文件顶层创建的观察者会[一直使用第一个测试的客户端](../../troubleshooting/#测试只在最先运行时通过)。

## 脱离 widget 树测试

在纯 Dart 测试中，把 [`fake_async`](https://pub.dev/packages/fake_async) 添加为开发依赖来控制时间：

```dart
test('loads todos', () {
  fakeAsync((async) {
    final client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => ['Buy milk'],
    ).observe(client: client);

    final subscription = todos.stream.listen((_) {});
    async.flushMicrotasks();
    expect(todos.result.data, ['Buy milk']);

    subscription.cancel();
    client.clear();
  });
});
```

监听 `stream` 会订阅观察者并开始获取。对于需要等待的模拟 API，用 `async.elapse(...)` 推进时钟，而不是用 `flushMicrotasks()`。

## 测试 cubit 和 bloc

像上面的测试一样，在 `testWidgets` 或 `fakeAsync` 中测试使用查询的 cubit 或 bloc。

- **在 `close()` 中调用 `subscription.cancel()`，不要 `await`**。在模拟时钟下，`cancel()` 返回的 `Future` 永远不会完成，测试会卡住。
- **在调用 `client.clear()` 之前关闭 cubit**。`clear()` 会把仍在订阅的观察者转到一个新的查询上，这个查询会再次加载。

## 测试处于后台的应用

`focusManager.setFocused(false)` 让 Fuery 把应用视为[处于后台](../lifecycle/#应用回到前台时)：重试会等待；除非设置了 `refetchIntervalInBackground`，否则轮询会暂停。`focusManager.setFocused(null)` 把焦点交还给应用生命周期，Fuery 会重新获取正在使用的过期查询。

同一个文件中的所有测试共享 `focusManager`，因此要在清理回调中重置它。清理回调在 widget 消失后运行，即使测试失败也会运行：

```dart
addTearDown(() => focusManager.setFocused(null));
```

## 在示例应用中

示例的测试用[一个小工具函数](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test/helpers.dart)打开标签页或帖子，它的[测试文件夹](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test)为每个界面准备了一个 widget 测试。
