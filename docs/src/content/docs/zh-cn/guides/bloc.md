---
title: Bloc 和 cubit
description: 在 Flutter 应用的 cubit 和 bloc 中读取缓存的查询并执行变更，与 Fuery 的 widget 共享同一个缓存，同时保留你现有的状态管理方式。
sourceHash: 5acfa82783c1
head:
  - tag: title
    content: 在 Flutter 的 bloc 或 cubit 中缓存 API 数据 | Fuery
---

cubit 和 bloc 使用与 Fuery 的 widget 相同的查询、变更和缓存，因此现有的状态管理方式保持不变。观察者的 `stream` 先发出当前结果，然后发出每次变化。监听会订阅观察者，观察者像已挂载的 widget 一样获取数据。取消监听会取消观察者的订阅。

## 使用哪种构建器

为每个界面选择一种构建器：

| 界面 | 用什么构建 |
|---|---|
| 基本按原样显示到达的服务端数据 | `QueryBuilder`。中间再加一个 cubit，就要重新实现 `QueryResult` 已经带有的加载标志和错误标志。 |
| 把服务端数据与应用状态混合：选中项、筛选条件、表单、多个查询的组合 | 监听查询的 cubit，以及 `BlocBuilder` |
| 在用 bloc 构建的应用中，已经由事件驱动 | 监听查询的 bloc，以及 `BlocBuilder` |

一个界面可以两者兼用：`BlocBuilder` 负责应用状态，`QueryBuilder` 负责服务端数据。无论哪种方式，使用同一个键的两个界面都共享一个缓存条目（`CachedQuery`）和一个请求，因此按界面来选择，而不是按数据。

在 cubit 中直接监听查询，而不是经由仓库。查询本身就是缓存层。

## 在 cubit 中

在 widget 之外，`observe()` 把查询变成一个带有 `stream` 的观察者。`todosQuery` 是查询，与[组织查询](../organizing-queries/)中的一样：

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState()) {
    _subscription = _todos.stream.listen((result) {
      emit(state.copyWith(todos: result.data, loading: result.isLoading));
    });
  }

  final _todos = todosQuery.observe();
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

在 `close()` 中调用 `cancel()`，但不要用 `await` 等待它。在 `testWidgets` 和 `fakeAsync` 下，它返回的 `Future` 永远不会完成。参见[测试 cubit 和 bloc](../testing/#测试-cubit-和-bloc)。

## 在 bloc 中

`emit.forEach` 在处理函数运行期间一直保持订阅：

```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(const TodoState()) {
    on<TodosSubscribed>((event, emit) {
      return emit.forEach(
        todosQuery.observe().stream,
        onData: (result) =>
            state.copyWith(todos: result.data, loading: result.isLoading),
      );
    });
  }
}
```

## 在 cubit 或 bloc 中执行变更

cubit 从定义执行变更，无须自己的观察者。`mutateAsync` 返回数据或抛出异常，这很适合 cubit 的方法：

```dart
Future<void> add(String title) async {
  try {
    await addTodo.mutateAsync(title);
  } catch (error) {
    emit(state.copyWith(error: error));
  }
}
```

bloc 的事件处理函数也一样：`await addTodo.mutateAsync(event.title)`。

- 执行使用 `Fuery.client`。拿到另一个客户端（例如测试的客户端）的 cubit 要传入它：`addTodo.mutateAsync(title, client)`。
- 执行属于客户端的缓存，而不属于 cubit，因此每个界面都能显示它。参见[与 widget 共享](#与-widget-共享)。
- 只有 cubit 要用观察者的 `result` 或 `stream` 跟踪自己执行的状态时，才保留一个观察者：`final _addTodo = addTodo.observe();`。

## 与 widget 共享

使用同一个键的 cubit 和 `QueryBuilder` 共享一个缓存条目。在一个界面上做出的更改（例如把通知标记为已读）会显示在 cubit 和每个 widget 中。

给 `addTodo` 设置 `mutationKey`，cubit 或 bloc 开始的执行就会显示在任何界面的 `MutationStateBuilder(mutation: addTodo)` 中。参见[显示变更的每次执行](../mutations/#显示变更的每次执行)。

cubit 要响应变更的每次执行（无论从哪里开始）时，持有一个 `MutationStateSlot`。`subscribeToRuns` 对每次执行的每次后续变化调用它的监听器，`result` 列出当前的执行。参见[变更的每次执行](../adapters/#变更的每次执行)。

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit(QueryClient client)
      : _adding = MutationStateSlot(addTodo, client),
        super(const TodoState()) {
    _adding.subscribeToRuns((previous, current) {
      if (current.isError) emit(state.copyWith(error: current.error));
    });
  }

  final MutationStateSlot<Todo, String, Object?> _adding;

  @override
  Future<void> close() {
    _adding.dispose();
    return super.close();
  }
}
```

## 应用生命周期

Fuery 的 widget、hook 和 `FueryProvider` 会接入应用生命周期，因此应用回到前台时，过期的查询会重新获取。只在 bloc 中使用查询、没有 `FueryProvider` 的应用，改为在 `main` 中调用一次 `FueryBinding.ensureInitialized()`。参见[应用回到前台时](../lifecycle/#应用回到前台时)。

## 在示例应用中

[通知 cubit](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/notifications/notifications_cubit.dart) 为徽标统计未读通知的数量，而通知界面用 Fuery 的 widget 显示同一个查询。示例的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
