---
title: 快速开始
description: 在 Flutter 应用中安装 Fuery，显示第一个带缓存的 API 请求，并测试它。
sourceHash: fa4345dc8bbf
---

完成 5 个步骤后，一个界面会显示来自 API 的列表，并带有加载状态和错误状态；其他界面都复用缓存的列表；一个 widget 测试检查这些行为。

## 开始之前

- Flutter 3.27 或更高版本，以及 Dart 3.6 或更高版本。
- 代码需要你的应用提供两个名称：
  - `api`：一个顶层变量，例如 `var api = Api();`，它的 `getTodos()` 返回 `Future<List<Todo>>`。测试会把它替换为模拟对象。
  - `TodoList`：一个 widget，用 `Text` 显示每个待办事项的标题。

## 1. 安装 Fuery

```bash
flutter pub add fuery
```

`fuery` 包含 `fuery_core`，因此 Flutter 应用只需要这一个包。对于不使用 Flutter 的 Dart 代码，例如服务器或 CLI，改用 `dart pub add fuery_core`。

除了 Dart 和 Flutter，Fuery 不依赖任何其他东西。`fuery` 只额外引入 `fuery_core`，而 `fuery_core` 只依赖 Dart 团队的 `clock`、`collection` 和 `meta`。Fuery 没有原生代码，也没有平台配置，因此能在 Flutter 支持的所有平台上运行，包括 Web。

## 2. 定义查询

查询需要一个为数据命名的**键**，以及一个获取数据的**查询函数**：

```dart
import 'package:fuery/fuery.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

`package:fuery/fuery.dart` 同时导出 `fuery_core`，因此这一条 import 就涵盖本页用到的所有 Fuery 名称。

定义查询不会启动任何操作。widget 显示查询时才开始获取，因此定义可以像这里一样作为顶层值，也可以在 `build` 中构建。

## 3. 在屏幕上显示查询

把查询传给 `QueryBuilder`。它在挂载时获取数据，并在每次产生新结果时重建：

```dart
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: todosQuery,
      builder: (context, state) => switch (state) {
        QueryResult(:final data?) => TodoList(data),
        QueryResult(:final error?) => Text('$error'),
        _ => const CircularProgressIndicator(),
      },
    );
  }
}
```

数据分支放在最前面。刷新失败时，列表仍然留在屏幕上。只有在没有数据可显示时，才会显示错误。

使用 hook 时，独立的包 [`fuery_hooks`](../guides/hooks/) 在 `HookWidget` 中用 `useQuery(todosQuery)` 渲染同一个查询。

## 4. 运行应用

在应用中显示这个界面，然后运行应用：

```dart
void main() => runApp(const MaterialApp(home: TodoListScreen()));
```

第一帧显示 `CircularProgressIndicator`。`api.getTodos()` 返回后，列表取代它。

另一个显示 `todosQuery` 的界面在第一帧就显示缓存的列表，不显示加载指示器。

## 5. 测试

编写一个实现 `Api` 的 `FakeApi` 类。它的 `getTodos()` 等待 300 毫秒，然后返回一个标题为“Buy milk”的待办事项。

然后在 `test/` 下的文件中添加这个测试。它用模拟对象替换 `api`，并检查加载状态和列表。同时导入声明 `api`、`FakeApi` 和 `TodoListScreen` 的文件：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  testWidgets('shows todos', (tester) async {
    api = FakeApi();

    await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // the fake request
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Fuery.client.clear();
  });
}
```

最后两行卸载界面并清空缓存，这样就不会有垃圾回收计时器在测试结束后继续存在并让测试失败。把这两行留在测试主体中，因为 `addTearDown` 在 `testWidgets` 检查计时器之后才运行。

[测试](../guides/testing/)介绍如何为每个测试提供新的客户端、关闭重试，以及测试 cubit 和纯 Dart 代码。

## Fuery 替你做了什么

- **类型来自你的函数**。因为 `api.getTodos()` 返回 `Future<List<Todo>>`，所以 `todosQuery` 是 `Query<List<Todo>>`，构建器中的 `state` 是 `QueryResult<List<Todo>>`。有两种情况需要写明类型：只按键读取或写入，例如 `client.getQueryData<List<Todo>>(['todos'])`；以及第一个页参数为 `null` 的无限查询（参见[基于游标的分页](../guides/infinite-queries/#基于游标的分页)）。
- **无须检查 null**。`QueryResult(:final data?)` 只在有数据时匹配，因此在这个分支中 `data` 是 `List<Todo>`。
- **界面按键共享数据**。使用 `['todos']` 的所有界面读取同一个缓存条目（`CachedQuery`），在获取进行中挂载的界面共享这个请求。
- **过期数据自动刷新**。数据一到达就已过期（`staleTime` 默认为 0）。另一个界面开始使用数据时，以及应用回到前台时，Fuery 在后台重新获取数据，同时旧列表仍然留在屏幕上。

[在演练场中试试](/fuery/demo/#/shared-cache)：三个 widget 显示同一个查询，一次请求为三者提供数据。

[缓存的工作原理](../how-the-cache-works/)解释数据何时重新获取、何时从内存中移除。

## 下一步

- [写给 TanStack Query 用户](../coming-from-tanstack-query/)：每个 TanStack Query 概念在 Fuery 中的名称。
- [Flutter 中的服务端状态](../server-state/)：服务端数据为什么需要缓存。
- [缓存的工作原理](../how-the-cache-works/)：定义、观察者和缓存数据的生命周期。
- [查询](../guides/queries/)：键、新鲜度，以及相互依赖的查询。
- [widget](../guides/widgets/)：构建器、监听器、消费者和选择器。
- [变更](../guides/mutations/)：更改服务端数据，并使用乐观更新。
- [Bloc 和 cubit](../guides/bloc/)：在 cubit 和 bloc 中使用同样的查询。
- [开发者工具](../guides/devtools/)：在运行中的应用里检查每个查询和变更。
