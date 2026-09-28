---
title: 变更
description: 在 Flutter 中创建、更新和删除服务端数据，支持乐观更新和回滚。
sourceHash: 2e5b7c9050c8
head:
  - tag: title
    content: Flutter 中的变更和乐观更新 | Fuery
---

变更把一项更改发送到服务器，例如新增一条待办事项。从按钮执行它，在任何界面显示它的进度，在它失败时告诉用户，并在服务器响应之前更新缓存。

下面这个变更添加一条待办事项：

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

为 `mutationFn` 的参数标注类型（例如上面的 `String title`），Dart 就会据此推断其他类型。`onMutate` 和 `onError` 是例外：它们的变量也要标注类型，例如 `onMutate: (String title, client)`。否则变量可能成为 `Object?`，而且只有构建时才会报错（[onMutate 或 onError 因 Object? 构建失败](../../troubleshooting/#onmutate-或-onerror-因-object-构建失败)）。`mutationKey` 让任何 widget 都能找到这个变更的执行。一次执行（`CachedMutation`）就是一次 `mutate` 调用（[变更的执行](../../how-the-cache-works/#变更的执行)）。[变更选项](../../reference/mutation-options/)列出了所有选项。

## 执行变更

在定义上调用 `mutate`，并传入 `context.queryClient`。任何 widget 都这样执行变更，`StatelessWidget` 也一样：

```dart
class AddTodoButton extends StatelessWidget {
  const AddTodoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => addTodo.mutate('Buy milk', context.queryClient),
      child: const Text('Add'),
    );
  }
}
```

- `mutate` 开始一次执行，并立即返回。执行失败时，错误记入这次执行的状态并传给回调，不会传给调用方。
- 定义不保存状态。执行属于客户端的缓存，而不属于某个 widget，因此按钮离开屏幕后，执行仍会继续。
- `context.queryClient` 是 widget 使用的客户端：最近的 `FueryProvider` 的客户端；没有 `FueryProvider` 时为 `Fuery.client`。传入它，执行就会记入 [MutationState 系列 widget](#显示变更的每次执行) 读取的缓存。
- 不传客户端时，执行使用 `Fuery.client`。没有 `BuildContext` 的代码（例如 [cubit](../bloc/#在-cubit-或-bloc-中执行变更)）就这样执行变更。

## 显示变更的每次执行

MutationState 系列 widget 在任何界面显示变更的执行。它们按定义的 `mutationKey` 找到执行，无论每次执行从哪里开始：定义的 `mutate`、`MutationBuilder`、`useMutation`、cubit 或 [`restore(mutations:)`](../persistence/#持久化变更)。它们可以在 `StatelessWidget` 中使用。

| widget | 构建依据或接收的内容 |
|---|---|
| `MutationStateBuilder` | 每次执行的 `MutationState`，最早的在前 |
| `MutationStateSelector` | 从这些状态中选出的一个值。只在这个值变化时重建。 |
| `MutationStateListener` | 每次执行的每次变化，用于副作用 |

上面的按钮，在添加待办事项期间禁用：

```dart
MutationStateSelector(
  mutation: addTodo,
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, adding) => FilledButton(
    onPressed:
        adding ? null : () => addTodo.mutate('Buy milk', context.queryClient),
    child: Text(adding ? 'Adding…' : 'Add'),
  ),
)
```

正在发往服务器的标题，与定义的变量一样类型为 `String`：

```dart
MutationStateBuilder(
  mutation: addTodo,
  builder: (context, runs) => Column(
    children: [
      for (final run in runs)
        if (run case MutationState(isPending: true, :final variables?))
          ListTile(title: Text(variables)),
    ],
  ),
)
```

### 匹配执行

- 传入 `Mutation` 时，这些 widget 显示 `mutationKey` 与它自己的完全相等的执行，类型与定义相同。
- 键和类型都相同的另一个定义的执行也算在内。
- 这些 widget 排除这个键下类型不同的执行，并向 [`onUncaughtError`](../client-setup/#捕获回调抛出的错误) 报告一次。给每个定义一个独立的键。
- 没有 `mutationKey` 的定义在 debug 构建中会触发断言失败。
- 传入 `MutationFilters` 时，这些 widget 显示任何变更中与之匹配的执行，匹配方式与 `client.mutationCache.findAll` 相同：按键前缀、`exact` 键、`status` 或 `predicate`。它们的状态类型为 `Object?`。
- 没有 `status` 过滤器时，已结束的执行也会匹配。

### 执行顺序和保留时间

- 执行按从旧到新的顺序列出，因此 `runs.lastOrNull` 是最近一次执行。
- 执行结束后会在垃圾回收时间（`gcTime`，默认值：5 分钟）内保留，因此要根据 `isPending` 构建指示器，而不是根据执行的数量。
- 已挂载的 `MutationBuilder` 在显示最近一次执行期间一直保留它。
- `client.clear()` 移除所有执行。

### 客户端和开销

- 只统计 widget 所用客户端的执行：最近的 `FueryProvider` 的客户端，或 `Fuery.client`。
- 这些 widget 只读取。它们从不执行变更，也不应用定义的任何选项，因此在 `build` 中构建定义没有任何开销。

## 告诉用户变更失败

失败的 `mutate` 把错误记入执行的状态，而不是抛出它。`MutationStateListener` 接收这个变更来自任何界面的每次执行，并获得每次执行的新状态：

```dart
MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
  child: const TodoScreen(),
)
```

- Fuery 对每个发生变化的执行调用一次它，因此两次失败的执行会产生两次调用。
- `listenWhen` 比较这次执行的上一个状态和新状态。
- 对于它挂载时各次执行已有的状态，以及缓存移除的执行，都不会调用它。
- 它也接收恢复的执行和来自其他界面的执行，因此只在这条消息所属的地方挂载一次。

`MutationListener` 只接收它拿到的观察者的执行。传入定义时，它会创建一个自己的观察者，而没有任何代码用这个观察者执行变更，因此它什么也接收不到。在 debug 构建中，它还会打印一条警告。参见 [MutationListener 从不运行](../../troubleshooting/#mutationlistener-从不运行)。

## 在一次调用成功后采取行动

`mutateAsync` 在执行成功时返回数据，在失败时抛出错误。要处理某一次调用的副作用（例如关闭刚保存的表单），用 `await` 等待它：

```dart
FilledButton(
  onPressed: () async {
    try {
      await addTodo.mutateAsync('Buy milk', context.queryClient);
    } catch (_) {
      return; // The MutationStateListener above reports the failure.
    }
    if (context.mounted) Navigator.pop(context);
  },
  child: const Text('Add'),
)
```

- 在 `await` 之后检查 `context.mounted`。执行处于 `pending` 状态时，用户可能离开界面。
- 捕获错误。没有代码捕获的错误会作为未捕获的错误传到 zone。

## 只显示 widget 自己开始的执行

`MutationBuilder` 持有自己的观察者，只显示它开始的执行。widget 的状态必须排除在别处开始的执行时（例如多个表单各自的“保存”按钮），使用它：

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => FilledButton(
    onPressed: state.isPending ? null : () => state.mutate('Buy milk'),
    child: Text(state.isPending ? 'Adding…' : 'Add'),
  ),
)
```

- `state.mutate('Buy milk')` 从这个 widget 开始一次执行。`await state.mutateAsync('Buy milk')` 返回数据，出错时抛出异常。
- `state` 显示这个 widget 最近开始的一次执行。用 `addTodo.mutate` 开始的执行，或由其他 widget 开始的执行，不会显示在 `state` 中。
- `state.reset()` 让状态回到 `idle`。
- 这个 widget 使用最近的 `FueryProvider` 的客户端；没有 `FueryProvider` 时使用 `Fuery.client`。
- 在 `HookWidget` 中，`useMutation(addTodo)` 返回同样的结果。参见 [hook](../hooks/#只显示-widget-自己开始的执行)。

[变更结果](../../reference/mutation-results/#mutationresult)列出了 `state` 的所有成员和字段。

要响应这个 widget 的某一次调用，把 `MutateOptions` 传给 `state.mutate`。调用结束后，它的回调在变更自身的回调之后运行：

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

- 在同一个观察者上之后的 `mutate` 调用会替换它们。只有最近一次调用的回调会运行。
- `reset()` 会丢弃它们。卸载 widget 也会丢弃它们。
- 无论是否有 widget 监听，[共享观察者](#共享一个观察者)都会运行它们。在回调中使用 `BuildContext` 之前，检查 `context.mounted`。

## 回调

`onMutate` 在 `mutationFn` 之前运行。`onSuccess`、`onError` 和 `onSettled` 在它之后运行。[回调](../../reference/mutation-options/#回调)列出了它们的参数和顺序。

- 最后一个参数 `client` 是执行这个变更的客户端：传给定义的 `mutate` 的客户端、widget 从 `FueryProvider` 获得的客户端，或传给 `observe(client:)` 的客户端。用它代替 `Fuery.client`，这样回调在测试中也能访问正确的缓存。
- `onMutate`、`onSuccess`、`onError` 或 `onSettled` 返回 `Future` 时，执行在这个 `Future` 完成之前一直处于 `pending` 状态。Fuery 不等待 `MutateOptions` 的回调。上面的 `addTodo` 在 `onSuccess` 中返回 `invalidateQueries` 的 `Future`，因此按钮一直显示 *Adding…*，直到列表重新获取完成。

## 乐观更新

乐观更新在服务器响应之前修改缓存，因此界面立即作出反应：

1. 在 `onMutate` 中取消这个查询的重新获取，避免它们覆盖这次更新。
2. 仍在 `onMutate` 中，写入新数据并返回旧数据。其他回调把它作为 `context` 接收。
3. 在 `onError` 中写回旧数据。
4. 在 `onSettled` 中使这个查询失效，重新获取服务器上的数据。

`todosQuery` 和 `todosKey` 是查询和它的[键](../organizing-queries/)：

```dart
final deleteTodo = Mutation(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (int id, client) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await client.cancelQueries(queryKey: todosKey);
    final previous = client.getData(todosQuery);
    client.updateData(
      todosQuery,
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, int id, previous, client) {
    if (previous != null) client.setData(todosQuery, previous);
  },
  onSettled: (_, __, ___, ____, client) {
    return client.invalidateQueries(queryKey: todosKey);
  },
);
```

[在演练场中试试](/fuery/demo/#/optimistic)：添加待办事项，并让一个请求失败来查看回滚。

## 不带变量的变更

不接收任何参数的变更（例如退出登录）使用 `NoVariablesMutation`。它的 `mutationFn` 和回调省略了变量（[NoVariablesMutation](../../reference/mutation-options/#novariablesmutation)）：

```dart
final logoutMutation = NoVariablesMutation(
  mutationFn: () => api.logout(),
);
```

用 `logoutMutation.mutate()` 执行它，因此按钮可以直接使用 tear-off：`onPressed: logoutMutation.mutate`。`logoutMutation.mutateAsync()` 返回数据。

- 在 `Fuery.client` 以外的客户端上执行时，先为变量传入 `null`：`logoutMutation.mutate(null, context.queryClient)`。
- `MutationBuilder` 或 `useMutation` 的结果的变量类型为 `void`，因此用 `state.mutate(null)` 执行变更。单次调用的回调保留变量参数，它的值为 `null`。
- 它的 `observe()` 返回的观察者是 `NoVariablesMutationObserver`，用 `mutate()` 执行它。

退出登录后，等应用离开使用缓存的界面，再清空缓存。[退出登录时清空所有数据](../query-client/#退出登录时清空所有数据)解释了为什么顺序很重要。

## 重试和顺序

变更只在你设置了 `retry` 时重试，因为重复写入并不总是安全的。`RetryPolicy.count(2)` 允许再尝试 2 次，间隔依次为 1 秒和 2 秒。共享同一个 `scope` 的变更按开始的顺序逐个执行：

```dart
final saveDraft = Mutation(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

在作用域中等待轮到自己的执行会报告 `isPaused`，等待网络的执行也一样。要让等待中的执行在重启后保留，给变更设置 `persist`（[持久化变更](../persistence/#持久化变更)）。

## 共享一个观察者

定义的 `mutate` 和 MutationState 系列 widget 都不需要你自己的观察者。cubit 同样从定义执行变更（[在 cubit 或 bloc 中执行变更](../bloc/#在-cubit-或-bloc-中执行变更)）。只有多个 widget 必须跟踪某一个界面的执行、而不包括其他界面的执行时，才共享一个观察者。

`addTodo.observe()` 返回一个 `MutationObserver`，传入它的每个 widget 都原样使用它。下面的应用栏在这个界面的表单保存期间显示进度条。`MutationStateSelector` 则还会显示其他界面开始的执行：

```dart
class _AddTodoScreenState extends State<AddTodoScreen> {
  late final adding = addTodo.observe(client: context.queryClient);

  @override
  void dispose() {
    adding.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New todo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: MutationSelector(
            mutation: adding,
            selector: (state) => state.isPending,
            builder: (context, saving) => saving
                ? const LinearProgressIndicator()
                : const SizedBox(height: 4),
          ),
        ),
      ),
      body: AddTodoForm(onSubmit: adding.mutate),
    );
  }
}
```

要在界面自己的调用成功后关闭界面，不需要共享观察者。用 `await` 等待 `mutateAsync`（[在一次调用成功后采取行动](#在一次调用成功后采取行动)）。

- 只创建一次观察者，放在 `State` 字段或 cubit 中。在 `build` 中调用 `observe()`，每次重建都会返回一个新的、处于 `idle` 状态的观察者。
- 除非传入 `client:`，否则 `observe()` 使用 `Fuery.client`。在带有自己客户端的 `FueryProvider` 之下，像上面那样传入 `context.queryClient`。
- 在 `dispose` 中调用 `reset()`。它会丢弃最近一次 `mutate` 调用的回调，这些回调属于这个界面。传入定义的 widget 在卸载时会重置它自己的观察者。
- 传入这个观察者的 `MutationListener`、`MutationSelector` 或 `MutationBuilder` 会接收它开始的每次执行，无论在哪里调用。

## 在示例应用中

- [信息流的变更](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)包括一个带回滚的乐观点赞，以及一个在离线时暂停的评论。
- [信息流](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)从定义执行每次点赞，并用 `MutationStateListener` 报告每次失败的点赞。
- [帖子界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)从定义发送评论，并用 `MutationStateBuilder` 列出正在发送的评论。
- [撰写界面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)用 `MutationBuilder` 执行新帖子的发布，它的按钮只显示自己的执行。

示例的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
