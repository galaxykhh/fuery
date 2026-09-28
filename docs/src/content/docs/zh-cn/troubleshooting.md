---
title: 问题排查
description: 在 Flutter 中使用 Fuery 时遇到的错误和意外行为、它们的原因，以及修复方法。
sourceHash: 40cf8f7390a7
---

本页按领域分组，列出在 Flutter 中使用 Fuery 时可能遇到的错误和意外行为的修复方法。每个标题写的是你看到的现象。

## 类型和编译错误

### StateError: Query holds X, but was requested as Y

读取或写入某个键时抛出这个错误。一个键只保存一种数据类型，而代码用了另一种类型：

```dart
client.setQueryData(['todos'], []); // StateError: the list has no type
```

Dart 为空列表推断出 `List<dynamic>`，而不是查询保存的 `List<Todo>`。写明类型：

```dart
client.setQueryData<List<Todo>>(['todos'], []);
```

`setData` 从查询获得类型，因此不会导致这个错误：`client.setData(todosQuery, [])`。参见[组织查询](../guides/organizing-queries/)。

### 数据类型是 Object

查询的类型是 `Query<Object>`，而不是你的模型。Dart 从 `keepPreviousData` 这类泛型函数推断数据类型，而不是从 `queryFn` 推断：

```dart
final posts = Query(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is Query<Object>
);
```

改写成闭包：

```dart
placeholderData: (previous, client) => previous,
```

类型已经确定时，例如在返回 `Query<List<Post>>` 的函数中，用 `keepPreviousData` 没有问题。

### FocusManager 这个名称在两个库中都有定义

同时导入 Flutter 和 `package:fuery/fuery.dart` 的文件在用到 `FocusManager` 的地方编译失败，报 `ambiguous_import`，例如 `FocusManager.instance.primaryFocus?.unfocus()`。Flutter 有一个 `FocusManager` 类。`package:fuery/fuery.dart` 导出的 `FocusManager` 是 `FueryFocusManager` 的已弃用别名。

不写类名也能访问 Flutter 的焦点管理器。Flutter 的顶层 `primaryFocus` 就是当前获得焦点的节点，因此这样可以收起键盘：

```dart
primaryFocus?.unfocus();
```

其他用途中，`WidgetsBinding.instance.focusManager` 和 `FocusManager.instance` 是同一个对象。

也可以隐藏 Fuery 的名称：

```dart
import 'package:fuery/fuery.dart' hide FocusManager;
```

这样 `FocusManager` 就指 Flutter 的类。`FueryFocusManager` 和 `focusManager` 单例仍然可用。`package:fuery_hooks/fuery_hooks.dart` 已经隐藏了 `FocusManager`。

## 测试

### A Timer is still pending even after the widget tree was disposed

缓存条目（`CachedQuery`）持有一个垃圾回收计时器。计时器在测试结束后仍然存在时，`testWidgets` 以这条消息失败。在每个 widget 测试的最后卸载 widget 树并清空缓存：

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

在 `clear()` 之前，取消你手动订阅的所有观察者的订阅。`clear()` 会把仍处于订阅状态的观察者转到一个新的查询，这个查询会重新开始加载。

`addTearDown(Fuery.client.clear)` 运行得太晚。测试主体结束后，`testWidgets` 卸载 widget 树，这会启动计时器。接着它在清理回调运行之前检查待处理的计时器。把这两行放在测试主体的末尾。

### 测试只在最先运行时通过

某个测试单独运行时通过，在另一个测试之后运行就失败：它的客户端一直是空的。观察者会保留创建它时的客户端。在文件顶层创建的观察者，例如 `final todos = todosQuery.observe();`，保留的是第一个使用它的测试的客户端。之后的测试创建新的客户端，这些客户端看不到它。

改为把查询放在顶层，并把查询传给 widget，widget 使用当前的客户端。在使用观察者的地方调用 `observe()`，例如在 cubit 中，这样每个测试都会得到一个使用自己客户端的观察者。参见[查询使用哪个客户端](../guides/client-setup/#查询使用哪个客户端)。

### 测试卡在 await subscription.cancel()

在 `testWidgets` 和 `fakeAsync` 中，`cancel()` 返回的 `Future` 永远不会完成。调用它时不要 `await`：

```dart
@override
Future<void> close() {
  _subscription.cancel(); // no await
  return super.close();
}
```

## 查询和重新获取

### 错误要 7 秒才出现

获取失败时，默认重试 3 次，依次等待 1 秒、2 秒和 4 秒。永远不会成功的错误，例如 404，会把这 7 秒花在重试上。只重试值得重试的错误：

```dart
retry: RetryPolicy.when(
  (failureCount, error) => failureCount < 3 && error is! NotFoundException,
),
```

参见[重试哪些错误](../guides/queries/#重试哪些错误)。

### 请求失败了，查询却成功了

查询函数抛出错误时，查询才会失败。返回结果对象（例如 `Result` 或 `Either`）的仓库无论成功还是失败都会正常返回。在查询函数中解开结果，并抛出失败。参见[报告仓库返回的失败](../guides/organizing-queries/#报告仓库返回的失败)。

### 表单丢失了用户输入的内容

表单的初始值来自一个查询，后台重新获取返回后，替换了用户在表单中输入的内容。只为控制器设置一次初始值，并在表单打开期间让查询停止重新获取：

```dart
final todo = Query(
  queryKey: ['todos', 'detail', id],
  queryFn: (_) => api.getTodo(id),
  refetchOnMount: RefetchMode.never,
  refetchOnFocus: RefetchMode.never,
  refetchOnReconnect: RefetchMode.never,
);
```

保存后，使这个键失效，让其他所有界面都显示这次更改。

### 查询重新获取得太频繁

过期的查询会在 widget 开始使用它时、应用回到前台时，以及网络重新连接时重新获取。默认的 `staleTime` 为 0，因此数据一到达就过期。为查询设置一个与数据变化速度相符的 `staleTime`：

```dart
final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);
```

参见[查询生命周期](../how-the-cache-works/#查询生命周期)。

### 查询在每次重建时都获取数据

在 `build` 方法中调用 `observe()`，例如 `QueryBuilder(query: todosQuery.observe())`，会在每次重建时创建一个新的观察者，而每个新观察者都会订阅并获取数据。改为直接传入查询本身。widget 会为它保持一个观察者：

```dart
QueryBuilder(query: todosQuery, builder: ...)
```

查询列表的修复方法相同。传入定义，而不是新的观察者：

```dart
QueriesBuilder(queries: [for (final id in ids) todoQuery(id)], builder: ...)
```

使用 [hook](../guides/hooks/) 时，写 `useQuery(todosQuery)`，而不是 `useQuery(todosQuery.observe())`；写 `useQueries([for (final id in ids) todoQuery(id)])`。

在 `build` 中创建的变更观察者，例如 `MutationBuilder(mutation: saveTodo.observe())`，每次重建时都从 `idle` 开始。按钮就会丢失它所开始的变更的 `pending` 或 `error` 状态。需要观察者时，只调用一次 `observe()`，放在 `State` 字段或 cubit 中，再把它传下去。参见[共享一个观察者](../guides/mutations/#共享一个观察者)。

在 debug 构建中，Fuery 的 widget 或 hook（包括列表形式）在重建时如果为同一个键和客户端得到一个新的观察者，就会打印一条带有本页链接的警告。每个键只警告一次。`FueryProvider` 替换客户端后得到新的观察者是预期行为，因此不会打印任何内容。

### fetchNextPage 取消了重新获取

`state.fetchNextPage()` 会取消已经在进行的获取，例如对所有页的后台重新获取。如果它已经在加载下一页，或者没有下一页，就不会取消。调用前检查 `isFetching`，或者传入 `cancelRefetch: false`：

```dart
state.fetchNextPage(cancelRefetch: false);
```

### 应用回到前台时没有重新获取

Fuery 的 widget 和 hook 会接入应用生命周期。只在 bloc 中使用查询的应用两者都没有。在启动时调用一次：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

参见[应用回到前台时](../guides/lifecycle/#应用回到前台时)。

### 设备离线时没有暂停

在你用 `onlineManager.setEventListener` 报告网络连接状态之前，Fuery 假定设备一直在线。参见[网络重新连接时](../guides/lifecycle/#网络重新连接时)。

## 变更

### onMutate 或 onError 因 Object? 构建失败

`flutter analyze` 没有报告问题，但构建时在 `onMutate` 或 `onError` 中报错，例如 `The method 'trim' isn't defined for the type 'Object?'`。

这些回调中的变量没有标注类型。Dart 可能在读取 `mutationFn` 的参数类型之前就推断这些变量的类型，于是它们成了 `Object?`。`onSuccess` 和 `onSettled` 会等待 `mutationFn` 的数据，因此能得到这个类型。分析器推断这些类型的方式与编译器不同，所以 `flutter analyze` 不会报错。

像 `mutationFn` 一样，为变量标注类型：

```dart
final addTodo = Mutation(
  mutationFn: (String title) => api.addTodo(title),
  onMutate: (String title, client) {
    debugPrint('Adding ${title.trim()}');
  },
  onError: (error, String title, context, client) {
    debugPrint('Could not add ${title.trim()}: $error');
  },
);
```

### 乐观更新消失了

一个已经在进行的重新获取在你更改之后才结束，覆盖了你的更改。在 `onMutate` 中，更改缓存之前，先取消正在进行的获取：

```dart
onMutate: (int id, client) async {
  await client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

### 请求结束后变更仍处于 `pending` 状态

返回 `Future` 的回调会让变更保持 `pending`，直到这个 `Future` 完成。`onSuccess: (_, __, ___, client) => client.invalidateQueries(...)` 返回失效操作，因此变更会一直处于 `pending`，直到重新获取完成。这适合保存按钮，它的加载指示器应该等列表刷新完。界面不需要等待时，使用块函数体，它不返回任何值：

```dart
onSuccess: (post, _, __, client) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

参见[回调](../guides/mutations/#回调)。

### MutationListener 从不运行

`MutationListener` 从不调用它的监听器，或者只显示状态的 `MutationBuilder` 或 `MutationSelector` 在按钮执行变更期间一直处于 `idle`。这些 widget 只显示它们自己的观察者的执行。接收定义的 widget，例如 `MutationListener(mutation: addTodo)`，会创建自己的观察者，而没有任何东西用这个观察者执行变更。用 `addTodo.mutate` 或由另一个 widget 开始的执行永远到不了它这里。

要接收这个变更的每次执行，无论执行从哪里开始，给定义设置 `mutationKey`，并使用 `MutationStateListener`：

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
);

MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not add: ${run.error}'))),
  child: const AddTodoForm(),
)
```

对于只显示状态的 widget，使用 `MutationStateBuilder` 或 `MutationStateSelector`。参见[显示变更的每次执行](../guides/mutations/#显示变更的每次执行)。

对于一次调用的副作用，例如关闭完成保存的表单，用 `await` 等待 `mutateAsync`。参见[在一次调用成功后采取行动](../guides/mutations/#在一次调用成功后采取行动)。

只接收一个观察者的执行时，在 `State` 字段中只创建一次这个观察者。把它同时传给执行变更的 widget 和 `MutationListener`：

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

[共享一个观察者](../guides/mutations/#共享一个观察者)展示了完整的界面，包括需要在 `dispose` 中调用的 `reset()`。

在 `HookWidget` 中，把执行变更的那个 `useMutation` 的结果传给 `useOnMutationChange`。要接收每次执行，调用 `useOnMutationStateChange(addTodo, ...)`。参见[响应变化](../guides/hooks/#响应变化)。

自己用 `state.mutate` 执行变更的构建器、消费者或选择器可以接收定义。

在 debug 构建中，接收定义的 `MutationListener` 会打印一次带有本页链接的警告。

### MutationStateBuilder 不显示任何执行

MutationState 系列 widget 和 `useMutationState` 在它们所用客户端的缓存中，按定义的 `mutationKey` 查找执行。检查以下原因：

- **定义没有 `mutationKey`**。给它设置一个，例如 `mutationKey: const ['todos', 'add']`。在 debug 构建中，widget 会触发一个说明这一点的断言失败。
- **另一个类型不同的定义使用了这个键**。Fuery 会排除它的执行，并向 [`onUncaughtError`](../guides/client-setup/#捕获回调抛出的错误) 报告一次。为每个定义设置自己的键。
- **执行在另一个客户端上**。不带 `client:` 用 `observe()` 创建的观察者，以及不传客户端、用定义的 `mutate` 开始的执行，都在 `Fuery.client` 上运行，而不在 `FueryProvider` 的客户端上。参见[界面读取了另一个客户端的缓存](#界面读取了另一个客户端的缓存)。
- **执行已经不在了**。没有观察者持有的已结束执行会在它的 `gcTime`（默认值：5 分钟）过后离开缓存。`client.clear()` 移除所有执行。

## 客户端和错误报告

### 界面读取了另一个客户端的缓存

变更的回调使查询失效，但界面没有更新。观察者会保留创建它时的客户端。不带 `client:` 的 `observe()` 使用 `Fuery.client`。在拥有自己客户端的 `FueryProvider` 下，`State` 字段中的观察者，例如 `final adding = addTodo.observe();`，读取和写入的是 `Fuery.client`。它周围接收定义的 widget 使用 `FueryProvider` 提供的客户端，因此回调使错误的缓存失效。

改为传入定义，widget 会用自己的客户端观察它。代码需要共享观察者时，用 widget 所用的客户端创建它：

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

除非传入客户端，否则定义的 `mutate` 和 `mutateAsync` 也使用 `Fuery.client`。在 `FueryProvider` 下，调用 `addTodo.mutate('Buy milk', context.queryClient)`。

在 `HookWidget` 中，`useQueryClient()` 返回 hook 使用的客户端。`observer.client` 返回观察者使用的客户端。

在 debug 构建中，Fuery 的 widget 或 hook 得到另一个客户端的观察者时，会打印一条带有本页链接的警告。每个 widget 或 hook 和键的组合只警告一次。

### 监听器的错误没有到达 zone

监听器中抛出的错误不会到达 `runZonedGuarded` 或 `PlatformDispatcher.onError`。客户端设置了 `onUncaughtError` 时，Fuery 把错误报告到那里，而不是报告给 zone。

这适用于监听器 widget、消费者或 hook 的 `listener`，以及传给 slot 的 `listen` 或 `subscribeToRuns` 的函数。重建照常进行，其他监听器也照常运行。

和回调抛出的其他错误一样，在你的 `onUncaughtError` 中报告这个错误：

```dart
Fuery.client = QueryClient(
  // reportError stands for your crash reporter.
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

参见[捕获回调抛出的错误](../guides/client-setup/#捕获回调抛出的错误)。

## 持久化和开发者工具

### 持久化的数据没有恢复

应用重启后，持久化的查询从网络加载数据。检查以下原因：

- **客户端没有存储**。在任何地方使用查询之前设置它：`Fuery.client = QueryClient(storage: myStorage)`。
- **查询没有设置 `persist`**。Fuery 只存储设置了它的查询。
- **存储条目已经无效**。Fuery 会丢弃 `version` 与查询不同的存储条目、无法解码的存储条目，以及超过查询的 `maxAge` 的存储条目。没有 `maxAge` 的查询使用客户端的 `persistMaxAge`（默认值：1 天）。参见[何时丢弃存储的数据](../guides/persistence/#何时丢弃存储的数据)。

使用异步读取的存储时，数据会晚一两帧到达。要在第一帧就有数据，在 `runApp` 之前 `await Fuery.client.restore()`。参见[提前恢复](../guides/persistence/#提前恢复)。

### 开发者工具按钮挡住了应用

`FueryDevtools` 把按钮放在右边缘的中间，盖住那里的所有内容。用 `buttonAlignment` 移动它：

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerLeft,
  child: child!,
)
```
