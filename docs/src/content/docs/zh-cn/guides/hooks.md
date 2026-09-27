---
title: hook
description: 用 fuery_hooks 和 flutter_hooks 在 build 中渲染查询和变更。
sourceHash: b017d3f6a0d8
head:
  - tag: title
    content: 适用于 flutter_hooks 的 useQuery 和 useMutation | Fuery
---

`fuery_hooks` 在 `build` 中读取 Fuery 的查询和变更，每个查询一次调用，无须构建器。它在 [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) 的 `HookWidget` 中使用。

Fuery 自己的风格是 [widget](../widgets/)，它们遵循 Flutter 的惯例：构建器负责 UI，监听器负责副作用。hook 适合喜欢在 `build` 中读取数据的开发者。两者使用相同的查询、变更和客户端，因此用 hook 编写的界面和用 widget 编写的界面共享同一个缓存和同一个请求。

除了 Dart 和 Flutter，`fuery` 不依赖任何其他东西。hook 需要 `flutter_hooks`，因此它们放在单独的包中，只有选择使用 hook 的应用才依赖它。

## 安装

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` 重新导出 `fuery`。与 `fuery` 一样，它需要 Flutter 3.27 或更高版本，以及 Dart 3.6 或更高版本。

## 读取查询

把界面改为 `HookWidget`，并用一个查询调用 `useQuery`：

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

class TodoListScreen extends HookWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = useQuery(todosQuery);
    return switch (todos) {
      QueryResult(:final data?) => TodoList(data),
      QueryResult(:final error?) => Text('$error'),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

- `useQuery` 返回当前结果，并在结果变化时重建 widget。
- 这个结果就是 `QueryBuilder` 拿到的那个 `QueryResult`，上面带有 `refetch()`。
- 没有数据的查询在第一次构建时开始获取，这次构建已经显示 `pending` 状态。

查询可以像上面那样是一个顶层值，也可以在 `build` 中构建，例如 `useQuery(todoQuery(id))`。hook 为它保持一个观察者并更新观察者的选项，因此新的键在同一帧中显示。

不要传入 `todosQuery.observe()`。每次构建都创建新的观察者，会重新订阅并再次获取。在 debug 构建中，hook 会为每个键打印一次警告。

## 依赖另一个查询的查询

`useQuery` 从不等待数据。需要另一个查询中的值的查询，在这个值出现之前用 `enabled` 禁用自己：

```dart
Query<List<Post>> postsQuery(int? userId) => Query(
      queryKey: ['posts', userId],
      queryFn: (_) => api.getPosts(userId!),
      enabled: userId != null,
    );

final user = useQuery(userQuery);
final posts = useQuery(postsQuery(user.data?.id));
if (posts.isPending) return const CircularProgressIndicator();
```

| 构建 | `user` | `posts` |
|---|---|---|
| 第一次 | 正在获取，没有数据 | 键为 `['posts', null]`，已禁用，不获取任何数据 |
| 用户数据到达后 | id 为 `7` 的数据 | 键为 `['posts', 7]`，在这次构建中开始获取 |
| 帖子数据到达后 | 数据 | 数据 |

已禁用且没有数据的查询处于 `pending` 状态，因此 `posts.isPending` 涵盖了两段等待。`posts.isLoading` 只在它的请求运行期间为 true。

## 加载更多页

`useInfiniteQuery` 返回一个 `InfiniteQueryResult`，其中包含已加载的页和 `fetchNextPage()`：

```dart
final feed = useInfiniteQuery(feedQuery);

ListView(
  children: [
    for (final post in feed.pages.expand((page) => page.posts)) PostTile(post),
    if (feed.hasNextPage)
      TextButton(onPressed: feed.fetchNextPage, child: const Text('More')),
  ],
)
```

## 读取一组查询

`useQueries` 接收一组同一数据类型的查询（例如每个 id 一个查询），并按顺序返回它们的结果：

```dart
final posts = useQueries([for (final id in ids) postQuery(id)]);
final loaded = posts.where((post) => post.hasData).length;
```

- 只要查询的键还在列表中，这个查询就保留它的观察者，即使列表重新排序也是如此。
- 同时到达的变化只引起一次重建。
- 传入定义，而不是 `.observe()`。每次构建都创建新的观察者会再次获取，并且在 debug 构建中 hook 会打印警告。

查询有数百个时，用 `useMemoized` 构建这个列表。这样，keys 相同的重建会传入同一个列表，`useQueries` 就跳过更新这些查询。列表的 keys 要包含 id，以及定义从 `build` 中读取的所有其他值，例如传给 `enabled:` 的值。keys 中缺少的值会保持构建列表时的值：

```dart
final posts = useQueries(
  useMemoized(() => [for (final id in ids) postQuery(id)], ids),
);
```

## 更改数据

与在任何 widget 中一样，从定义执行变更，并传入 `useQueryClient()` 返回的客户端。[`useMutationState`](#显示变更的每次执行) 读取它的执行：

```dart
final client = useQueryClient();
final adding = useMutationState(addTodoMutation).any((run) => run.isPending);

ElevatedButton(
  onPressed: adding ? null : () => addTodoMutation.mutate('Buy milk', client),
  child: const Text('Add'),
)
```

- 执行属于客户端的缓存，而不属于 widget。
- [`useQueryClient()`](#读取客户端) 返回 hook 使用的客户端：最近的 `FueryProvider` 的客户端；没有 `FueryProvider` 时为 `Fuery.client`。传入它，执行就会记入 `useMutationState` 读取的缓存。不传客户端时，执行使用 `Fuery.client`。
- `NoVariablesMutation` 在客户端之前为变量接收 `null`：`logoutMutation.mutate(null, client)`。参见[不带变量的变更](../mutations/#不带变量的变更)。

### 只显示 widget 自己开始的执行

`useMutation` 像 `MutationBuilder` 一样为 widget 保持一个观察者。它的结果只显示用它开始的执行，结果上带有 `mutate`：

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

`NoVariablesMutation` 的结果用 `mutate(null)` 执行它：

```dart
final logout = useMutation(logoutMutation);

TextButton(
  onPressed: () => logout.mutate(null),
  child: const Text('Log out'),
)
```

对于用结果发起的某一次调用的副作用（例如 snackbar），把 `MutateOptions` 传给 `mutate`：

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(
    onError: (error, _, __, ___) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error'))),
  ),
);
```

widget 消失后，请求仍会完成。

- `useMutation` 接收的是定义时，hook 会丢弃传给结果的 `mutate` 的 `MutateOptions`。
- [共享观察者](../mutations/#共享一个观察者)不受影响，仍会运行它们。在这些回调中检查 `context.mounted`，或者在创建这个观察者的界面的 `dispose` 中调用观察者的 `reset()`。

## 显示变更的每次执行

`useMutationState` 返回变更每次执行的状态，最早的在前，无论执行从哪里开始：定义的 `mutate`、另一个 widget 中的 `useMutation`、`MutationBuilder` 或 cubit。它与 [`MutationStateBuilder`](../mutations/#显示变更的每次执行) 一样，按定义的 `mutationKey` 找到执行，并且从不执行变更：

```dart
final runs = useMutationState(addTodoMutation);

if (runs.any((run) => run.isPending)) return const LinearProgressIndicator();
```

要改为响应每次执行，使用 [`useOnMutationStateChange`](#响应变化)。

## 响应变化

上面的 hook 只读取。对于导航、snackbar 和其他一次性副作用，把它们的返回值传给变化 hook：

| hook | 在以下变化之后调用监听器 |
|---|---|
| `useOnQueryChange(result, ...)` | `useQuery` 或 `useInfiniteQuery` 的结果的每次变化 |
| `useOnMutationChange(result, ...)` | `useMutation` 的结果的每次变化：即用它开始的执行 |
| `useOnMutationStateChange(mutation, ...)` | 变更每次执行的每次变化，按 `mutationKey` 查找，来自任何 widget |

```dart
final todos = useQuery(todosQuery);
useOnQueryChange(
  todos,
  listenWhen: (previous, current) =>
      !previous.isRefetchError && current.isRefetchError,
  listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not refresh: ${result.error}')),
  ),
);
```

- 监听器在变化之后、显示这次变化的重建之前运行，从不在构建期间运行。它拿到的是 widget 自己的 `context`。
- 对于 hook 最初的结果，不会调用监听器。
- `listenWhen` 比较上一次收到的结果和新结果，与 [`QueryListener`](../widgets/#响应变化) 上的一样。
- hook 使用最近一次构建中的 `listener` 和 `listenWhen`。
- 传入 `useInfiniteQuery` 的结果时，闭包拿到的是带有页的 `InfiniteQueryResult`。
- 传入用 `QueryResult` 构造函数创建的结果（例如 widget 测试中编造的数据）时，hook 不调用任何东西。

监听器接收结果的每次变化，例如获取开始或结束，或者用 `setData` 写入数据。要响应状态的转变，像上面那样在 `listenWhen` 中比较两个结果。这样每次刷新失败只显示一个 snackbar，而不是在错误持续期间对之后的每次变化都显示一个。

响应同一个查询的两个 widget 各自运行自己的监听器，因此变化 hook 中的副作用对每个 widget 运行一次。对于整个应用只需要一次的副作用（例如报告每次失败的获取），改用 [`QueryCacheConfig.onError`](../client-setup/#在一处报告所有失败)。

变化 hook 不添加观察者，也从不重建 widget。唯一的例外是 `useOnMutationStateChange`。它读取 `FueryProvider` 提供的客户端，因此替换这个客户端时，它会重建 widget。读取 hook（例如 `useQuery`）在结果变化时重建 widget。要在不重建 widget 的情况下响应查询，用 `QueryListener` 或 `InfiniteQueryListener` 包裹子树，`fuery_hooks` 重新导出了这两个 widget。

`useOnMutationChange` 接收用它拿到的结果开始的执行：

```dart
final addTodo = useMutation(addTodoMutation);
useOnMutationChange(
  addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);

FilledButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate(title.text),
  child: const Text('Add'),
)
```

- 从这个结果执行变更，或者把结果传给执行变更的子 widget。
- 另一个 `useMutation(addTodoMutation)` 有自己的观察者。这个监听器接收不到它的执行。
- 结果显示的是最近一次执行，因此多次执行重叠时，监听器接收的是最近的那一次。要响应每次执行，使用 `useOnMutationStateChange`，或者用 `await` 等待 `mutateAsync`。
- 传入[共享观察者](../mutations/#共享一个观察者)时，`useMutation` 返回它的结果，监听器接收这个观察者的每次执行。

`useOnMutationStateChange` 与 `MutationStateListener` 一样，接收变更的每次执行，无论它从哪里开始。它不需要 `useMutation`。监听器获得每个发生变化的执行的新状态，每次执行一次。`listenWhen` 比较这次执行的上一个状态和新状态：

```dart
useOnMutationStateChange(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

| 副作用 | 放在哪里 |
|---|---|
| 缓存操作，例如任何执行之后使 `['todos']` 失效 | `Mutation` 的回调 |
| 界面对自己的 `useMutation` 的执行作出的反应，例如关闭界面 | `useOnMutationChange` |
| 对来自任何 widget 的每次执行作出的反应，例如每次失败显示一个 snackbar | `useOnMutationStateChange` |
| 某一次调用的副作用，需要这次调用的变量 | 传给 `useMutation` 结果的 `mutate` 的 `MutateOptions` |
| 某一次调用之后的副作用，写在执行它的代码中 | 在 `try` 中 `await addTodoMutation.mutateAsync(...)`，然后检查 `context.mounted` |

用 `await` 等待调用，副作用就留在执行它的代码旁边：

```dart
final client = useQueryClient();

FilledButton(
  onPressed: () async {
    try {
      await addTodoMutation.mutateAsync(title.text, client);
    } catch (_) {
      return; // useOnMutationStateChange above reports the failure.
    }
    if (context.mounted) Navigator.pop(context);
  },
  child: const Text('Add'),
)
```

`try` 防止失败作为未捕获的错误传到 zone。

widget 挂载时的结果已经决定了要显示什么时（例如用户已退出登录），在 `build` 中根据 hook 返回的结果来决定。不会为这个结果调用任何变化 hook。

### useEffect 中的 snackbar 和导航

在变化 hook 中显示 snackbar 和导航。变化 hook 在构建之外运行，并且只响应之后的变化。`useEffect` 和 `useValueChanged` 在构建期间运行，在那里显示 snackbar 或导航会失败：它们在 widget 树构建期间修改 widget 树。`useEffect` 回调在第一次构建时针对 widget 挂载时的值运行，之后在 keys 变化的每次构建中运行；没有 keys 时，则在每次构建中运行。在 debug 构建中，这些调用会以下面的错误失败：

- `showSnackBar` 报告 `The showSnackBar() method cannot be called during build.`。
- `Navigator.pop` 报告 `setState() or markNeedsBuild() called during build.`。
- 在第一次构建时，或者 keys 变化之后，`ScaffoldMessenger.of(context)` 会先失败，报告 `Cannot listen to inherited widgets inside HookState.initState.`。

## 每个 widget 对应的 hook

| widget | hook |
|---|---|
| `QueryBuilder` | `useQuery(query)` |
| `QueryListener` | `useOnQueryChange(result, listener: ...)` |
| `QueryConsumer` | `useQuery(query)` 和 `useOnQueryChange` |
| `InfiniteQueryBuilder` | `useInfiniteQuery(query)` |
| `InfiniteQueryListener` | `useOnQueryChange(result, listener: ...)` |
| `InfiniteQueryConsumer` | `useInfiniteQuery(query)` 和 `useOnQueryChange` |
| `MutationBuilder` | `useMutation(mutation)` |
| `MutationListener` | `useOnMutationChange(result, listener: ...)` |
| `MutationConsumer` | `useMutation(mutation)` 和 `useOnMutationChange` |
| `QueriesBuilder` | `useQueries(queries)` |
| `MutationStateBuilder`、`MutationStateSelector` | `useMutationState(mutation)` |
| `MutationStateListener` | `useOnMutationStateChange(mutation, listener: ...)` |

`result` 是读取 hook 的返回值，例如 `useQuery(query)` 的返回值。

## 读取客户端

`useQueryClient()` 返回 hook 使用的客户端：上层 `FueryProvider` 提供的客户端，或 `Fuery.client`。替换 `FueryProvider` 提供的客户端时，widget 会重建。

```dart
final client = useQueryClient();

RefreshIndicator(
  onRefresh: () => client.invalidateQueries(queryKey: ['todos']),
  child: TodoList(todos.data ?? []),
)
```

`observe()` 返回的观察者保留自己的客户端：除非传入 `client:`，否则为 `Fuery.client`。在带有自己客户端的 `FueryProvider` 之下，传入定义，或者用 `useQueryClient()` 返回的客户端创建观察者。定义的 `mutate` 同样使用 `Fuery.client`，除非你传入客户端：`addTodoMutation.mutate('Buy milk', client)`。在 debug 构建中，传入另一个客户端的观察者的 hook 会打印警告。参见[界面读取了另一个客户端的缓存](../../troubleshooting/#界面读取了另一个客户端的缓存)。

## 观察缓存

`useStream` 渲染来自 `client.watch` 的值，例如是否有获取正在进行。用 `useMemoized` 只创建一次 stream：

```dart
final client = useQueryClient();
final fetching = useStream(
  useMemoized(
    () => client.watch((client) => client.isFetching() > 0),
    [client],
  ),
);

if (fetching.data ?? false) return const LinearProgressIndicator();
```

- 每次调用 [`watch`](../query-client/#观察缓存) 都返回一个新的 stream，每个监听器首先拿到当前值。
- `useStream` 会订阅它拿到的每个新 stream，因此每次构建都创建的 stream 会让 widget 每一帧都重建。
- 把客户端以及选择器从 `build` 中读取的所有值列入 `useMemoized` 的 keys，这样 stream 会跟随它们变化。

变更不需要 stream。[`useMutationState`](#显示变更的每次执行) 返回它的执行，`useMutationState(const MutationFilters())` 返回所有变更的执行。

## 测试

像测试任何 widget 一样测试使用 hook 的界面。[测试](../testing/)中的内容完全适用：每个测试结束时，卸载 widget 树并清空客户端。
