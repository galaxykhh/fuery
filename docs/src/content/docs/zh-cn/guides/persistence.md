---
title: 持久化
description: 在 Flutter 中用任意键值存储，让缓存的服务端数据在应用重启后仍然保留。
sourceHash: 8e8642971351
head:
  - tag: title
    content: Flutter 离线缓存持久化 | Fuery
---

把查询数据和未完成的变更存储在设备上，它们就能在应用重启后保留下来：

- 持久化的查询立即显示上次的数据，如果数据已过期，再在后台重新获取。
- 应用关闭时正在等待网络的持久化变更，会在下次启动、应用调用 `restore(mutations:)` 后再次执行。

## 连接存储

Fuery 用 `QueryStorage` 读写字符串。基于任意键值存储实现它。下面这个实现使用 [`shared_preferences`](https://pub.dev/packages/shared_preferences)：

```dart
class PreferencesStorage implements QueryStorage {
  PreferencesStorage(this.preferences);

  final SharedPreferencesWithCache preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<void> delete(String key) => preferences.remove(key);

  @override
  Map<String, String> readAll() => {
        for (final key in preferences.keys)
          if (key.startsWith(persistKeyPrefix)) key: preferences.getString(key)!,
      };
}
```

Fuery 写入的每个键都以常量 `persistKeyPrefix` 开头。像上面这样在 `readAll` 中按它过滤，让 `readAll` 只返回 Fuery 的存储条目，不返回存储中的其他内容。

把存储交给客户端：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  Fuery.client = QueryClient(storage: PreferencesStorage(preferences));
  runApp(const App());
}
```

`SharedPreferencesWithCache` 同步读取，因此 Fuery 在第一帧之前恢复持久化的查询。存储方法也可以返回 Future，比如对接数据库时。参见[提前恢复](#提前恢复)。

## 持久化查询

添加 `persist`，并提供在数据和 JSON 之间相互转换的函数。Fuery 只存储设置了 `persist` 的查询：

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  persist: QueryPersist(
    toJson: (todos) => [for (final todo in todos) todo.toJson()],
    fromJson: (json) => [
      for (final item in json! as List) Todo.fromJson(item),
    ],
  ),
);
```

- **转换**：从 `toJson` 返回 `jsonEncode` 接受的值。如果无法编码，Fuery 不存储数据，也不报告错误。`fromJson` 接收 `jsonDecode` 的结果，因此在这里做一次类型转换。上面的 `Todo.fromJson` 接受 `Object?`。如果是生成的 `Todo.fromJson(Map<String, dynamic> json)`，写成 `Todo.fromJson(item as Map<String, dynamic>)`。
- **恢复**：首次使用查询时，Fuery 恢复它存储的数据以及数据的获取时间。然后由 `staleTime` 决定查询是否重新获取，因此新鲜的数据不会再次获取。恢复不需要网络。
- **存储**：每当数据变化且没有获取在进行时，Fuery 存储数据，包括用 `setData` 做的更改。即使还没有任何东西使用这个查询，`client.setData(todosQuery, todos)` 也会存储，因为它创建的查询带有定义的 `persist`。Fuery 在[流式查询](../streaming/)的 stream 结束后存储它。
- **包含枚举的键**：Fuery 按名称存储键中的枚举，不包含它的类型。混淆和压缩的构建可能在应用更新时重命名类型，而只看名称仍然能匹配。因此，如果两个持久化查询的键只在同名枚举的类型上不同，它们会共用一个存储条目：`['todos', Filter.done]` 和 `['todos', Status.done]` 会互相覆盖数据。添加一个字符串来区分它们：`['todos', 'filter', Filter.done]`。

## 持久化无限查询

转换一页，Fuery 就会存储页列表：

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  persist: InfiniteQueryPersist(
    pageToJson: (page) => page.toJson(),
    pageFromJson: (json) => PostPage.fromJson(json! as Map<String, Object?>),
  ),
);
```

Fuery 把所有已加载的页存储在一个存储条目中，并在每页加载后重新写入。设置 `maxPages`，避免很长的信息流变成一个很大的存储条目。

Fuery 按原样存储页参数，因此它们必须是 JSON 值，比如数字、字符串或 `null`。对于其他页参数，添加 `paramToJson` 和 `paramFromJson`。`paramToJson` 以 `Object?` 接收每个页参数，因此需要转换类型：`paramToJson: (date) => (date! as DateTime).toIso8601String()`。

## 何时丢弃存储的数据

在以下情况下，Fuery 丢弃存储的数据，查询像没有存储任何数据一样获取：

- 数据超过查询的 `maxAge`，或者在查询没有设置 `maxAge` 时，超过客户端的 `persistMaxAge`（默认值：1 天）。
- 数据的 `version` 与查询的不同。JSON 格式变化时，增大 `version`。
- 数据无法解码。

```dart
persist: QueryPersist(
  version: 2,
  maxAge: const Duration(hours: 6),
  toJson: (todos) => [for (final todo in todos) todo.toJson()],
  fromJson: (json) => [
    for (final item in json! as List) Todo.fromJson(item),
  ],
),
```

`restore()` 还会删除已超过 `maxAge` 的存储查询，以 Fuery 存储它们时生效的 `maxAge` 为准。应用不再使用的键的数据不会留在存储中。

## 提前恢复

如果存储异步读取，在 Fuery 读到数据之前，查询显示加载状态。要在第一帧就显示数据，在应用启动前读取所有存储条目：

```dart
await Fuery.client.restore();
runApp(const App());
```

## 删除存储的数据

| 调用 | 存储的数据 |
|---|---|
| `removeQueries`、`resetQueries` | 删除匹配查询的存储数据。只按键过滤的调用还会删除尚未加载的存储查询。 |
| `clear()` | 全部删除，包括查询和变更。在用户退出登录时调用。 |
| 垃圾回收 | 保留。从内存中移除的查询在下次使用时恢复。 |

## 持久化变更

设置了 `persist` 的变更从每次执行开始到结束，一直存储这次执行的变量。应用关闭时离线暂停或仍在进行的执行，在下次启动时仍然存储着。`restore(mutations:)` 用你传入的定义再次执行它，因此界面和 `main` 使用同一个定义：

```dart
Mutation<Comment, NewComment, void> addCommentMutation() {
  return Mutation(
    mutationKey: ['comments', 'add'],
    mutationFn: (NewComment comment) => api.addComment(comment),
    scope: const MutationScope('comments'),
    persist: MutationPersist(
      toJson: (comment) => {'postId': comment.postId, 'body': comment.body},
      fromJson: (json) {
        final map = json! as Map<String, Object?>;
        return (postId: map['postId']! as int, body: map['body']! as String);
      },
    ),
    onSuccess: (_, comment, __, client) {
      client.invalidateQueries(queryKey: ['comments', comment.postId]);
    },
  );
}

// In a screen:
addCommentMutation().mutate(
  (postId: post.id, body: 'Nice post'),
  context.queryClient,
);

// In main, before runApp:
await Fuery.client.restore(mutations: [addCommentMutation()]);
```

[MutationPersist](../../reference/mutation-options/#mutationpersist) 列出了它的参数。`NoVariablesMutation` 用 `MutationPersist.noVariables` 持久化：`NoVariablesMutation(mutationKey: ['sync'], mutationFn: () => api.sync(), persist: MutationPersist.noVariables)`。

应用关闭前已经到达服务器的请求，会在重启后再次发送。只持久化请求可以安全重复的变更，或者让服务器把重复的请求视为同一次写入。

### 匹配存储的执行

- `restore` 按 `mutationKey` 把存储的执行与它的定义匹配，因此持久化的变更需要一个 `mutationKey`。
- `mutations` 是一个 `AnyMutation` 列表。每个 `Mutation` 都是 `AnyMutation`，因此类型不同的定义可以放在同一个列表中。
- Fuery 像存储查询键一样存储 `mutationKey`，因此键中可以包含枚举和 `DateTime` 值。
- 无法存储的键，比如包含没有 `toJson()` 的对象的键，Fuery 会向 `onUncaughtError` 报告一次。这次执行照常进行，只是不存储。
- 如果两个定义的键只在枚举类型上不同，`restore` 会报告它们，并且两个都不恢复。

### 恢复存储的执行

- `restore` 是恢复存储的执行的唯一方式。它用存储的变量开始每次执行：在线时立即开始，离线时等网络恢复后开始。
- 共享同一作用域的执行逐个进行，最早的先开始。
- `restore` 对每个存储的执行只启动一次。它跳过客户端已经在进行或已暂停的执行，因此调用两次也不会重复发送请求。
- 恢复的执行跳过 `onMutate`，它的回调收到的 `context` 为 `null`。乐观更新属于做出它的那次执行。恢复的执行只重复请求以及请求之后的回调。
- [MutationState 系列 widget](../mutations/#显示变更的每次执行) 和 `useMutationState` 按同一个 `mutationKey` 找到恢复的执行并显示它们。`MutationStateBuilder(mutation: addCommentMutation(), ...)` 列出重启后仍在发送途中的评论。

### 删除存储的执行

- 存储的执行成功或失败后，Fuery 删除它。`clear()` 删除所有存储的执行。
- 如果存储的执行的定义没有传给 `restore`，它会保留下来，之后的 `restore` 可以执行它。
- 如果存储的执行来自 `MutationPersist` 的另一个 `version`，或者 Fuery 无法读取它，Fuery 删除它。

## Fuery 保证的行为

- Fuery 在读取或写入之前等待进行中的删除完成，因此移除的查询不会恢复已删除的数据，也不会用写入覆盖自己的删除。
- 查询重置或移除时仍在进行的恢复，不会带回旧数据。
- 删除与 `restore()` 的读取重叠时，`restore()` 在删除完成后重新读取，总共最多读取 3 次，因此它不会恢复已删除的数据。如果 3 次读取都与删除重叠，这次调用什么也不恢复：查询在首次使用时恢复，存储的变更等待下一次 `restore()`。
- 查询在异步恢复完成后才决定挂载时是否获取，因此 `refetchOnMount` 和 `staleTime` 像对待缓存数据一样对待恢复的数据。
- 存储方法可以是同步的，也可以是异步的。Fuery 忽略它们的错误：存储出错的查询像没有存储任何数据一样加载。

## 在示例应用中

- [preferences 存储](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart)是一个存储适配器。
- [信息流查询](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)持久化信息流的页。

示例的 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) 列出了每个界面展示的内容。
