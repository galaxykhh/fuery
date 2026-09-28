---
title: 写给 TanStack Query 用户
description: 在 Flutter 应用中，每个 TanStack Query（React Query）v5 概念在 Fuery 中的名称：客户端、查询键、useQuery 的选项和结果、变更、无限查询、持久化和开发者工具。
sourceHash: 5f46e16eded3
head:
  - tag: title
    content: 从 TanStack Query（React Query）转向 Flutter | Fuery
---

本页列出 [TanStack Query](https://tanstack.com/query) v5（原名 React Query）的每个概念在 Fuery 中的名称。它写给熟悉 TanStack Query、想在 Flutter 应用中使用同样缓存模型的 React 开发者。

Fuery 的缓存和重新获取模型受 TanStack Query 启发，因此你已经掌握的大部分知识依然适用：

- 查询键为一个缓存条目（`CachedQuery`）命名。使用这个键的所有界面共享这个缓存条目和它的请求。
- 数据在 `staleTime` 内保持新鲜，之后变为过期。Fuery 在后台重新获取过期数据时，过期数据仍然显示在屏幕上。
- 没有任何地方使用的数据在 `gcTime` 过后从内存中移除。
- `invalidateQueries`、`setQueryData`、`onMutate`、`fetchNextPage` 和大多数结果字段保留原来的名称。
- 默认值保持不变：`staleTime` 为 0，`gcTime` 为 5 分钟，屏幕上的查询以退避方式重试 3 次。

界面使用查询的方式则遵循 Flutter 的惯例。[Flutter 中的不同之处](#flutter-中的不同之处)介绍这一部分。

## 贯穿各处的名称变化

下面每个表格的左侧是 TanStack Query 的名称，右侧是 Fuery 的名称。有四处变化贯穿所有表格：

- 选项是定义的命名参数，例如 `Query(queryKey: ..., queryFn: ...)`，而不是一个对象。
- 时长是 `Duration` 值，而不是毫秒数。时间戳（例如 `dataUpdatedAt`）仍然是自 Unix 纪元以来的毫秒数。
- 缺失的数据是 `null`，而不是 `undefined`。
- 字符串值变为枚举。`'always'` 变为 `RefetchMode.always`，`'pending'` 变为 `QueryStatus.pending`。

## 配置客户端

| TanStack Query | Fuery |
|---|---|
| `new QueryClient({ defaultOptions })` | `QueryClient(defaultOptions: DefaultOptions(...))`，`queries` 用 `QueryDefaults`，`mutations` 用 `MutationDefaults` |
| `<QueryClientProvider client={queryClient}>` | 不需要。在 `main` 中给 `Fuery.client` 赋值。`FueryProvider(client: ..., child: ...)` 为一棵子树提供它自己的客户端。 |
| `useQueryClient()` | 在任何 widget 中用 `context.queryClient`，或者用 `fuery_hooks` 的 `useQueryClient()` |
| `mount()`、`unmount()` | `mount()`、`unmount()`。给 `Fuery.client` 赋值和 `FueryProvider` 都会替你调用它们。 |
| `setQueryDefaults`、`getQueryDefaults`、`setMutationDefaults`、`getMutationDefaults` | 名称相同 |

每组代码片段把同一段代码展示两遍：先是 TanStack Query，然后是 Fuery。`api`、`Todo` 以及 `TodoList` 等 widget 代表你自己的代码。

```tsx title="TanStack Query"
const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30 * 1000 } },
})

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Todos />
    </QueryClientProvider>
  )
}
```

```dart title="Fuery"
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const MaterialApp(home: TodoListScreen()));
}
```

什么都不配置的应用也能正常运行：Fuery 在首次使用时创建 `Fuery.client`。参见[配置客户端](../guides/client-setup/)。

## 定义和显示查询

| TanStack Query | Fuery |
|---|---|
| `queryKey: ['todos', id]` | `queryKey: ['todos', id]`，类型为 `List<Object?>`。Fuery 按值比较键，过滤器按前缀匹配键。 |
| `queryKey: ['todos', { status, page }]` | `queryKey: ['todos', {'status': status, 'page': page}]`。map 中键值对的顺序无关紧要。键中的对象需要有 `toJson()` 方法。 |
| `queryFn: ({ queryKey, signal, meta, client }) => ...` | `queryFn: (context) => ...`，可以使用 `context.queryKey`、`context.signal`、`context.meta` 和 `context.client` |
| 数据不能是 `undefined` | 查询函数返回不可空类型，例如 `Future<List<Todo>>` |
| `fetch(url, { signal })` | `context.signal.onAbort(...)`，连接到你的 HTTP 客户端的取消机制。参见[取消请求](../guides/queries/#取消请求)。 |
| `queryOptions({ ... })` | `Query(...)`，widget、hook 和客户端都接受的定义 |
| `useQuery({ ... })` | `QueryBuilder(query: ..., builder: ...)`，或者 `fuery_hooks` 的 `useQuery(query)` |

```tsx title="TanStack Query"
function Todos() {
  const { data, error } = useQuery({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  })

  if (data) return <TodoList todos={data} />
  if (error) return <p>{error.message}</p>
  return <Spinner />
}
```

```dart title="Fuery"
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

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

`todosQuery` 不保存数据，也不启动任何操作。`QueryBuilder` 在挂载时获取数据，并在每次产生新结果时重建。[查询](../guides/queries/)介绍键和选项。

## 读取结果

| TanStack Query | Fuery |
|---|---|
| `status`：`'pending'`、`'error'`、`'success'` | `status`：`QueryStatus.pending`、`.error`、`.success` |
| `fetchStatus`：`'fetching'`、`'paused'`、`'idle'` | `fetchStatus`：`FetchStatus.fetching`、`.paused`、`.idle` |
| `data`、`error` | `data`、`error` |
| `isPending`、`isSuccess`、`isError`、`isLoading`、`isFetching`、`isRefetching`、`isPaused` | 名称相同 |
| `isLoadingError`、`isRefetchError`、`isPlaceholderData`、`isStale`、`isFetched`、`isFetchedAfterMount`、`isEnabled` | 名称相同 |
| `dataUpdatedAt`、`errorUpdatedAt`、`errorUpdateCount`、`failureCount`、`failureReason` | 名称相同 |
| `refetch({ cancelRefetch, throwOnError })` | `refetch(cancelRefetch: ..., throwOnError: ...)`，返回 `Future<QueryResult>` |

Fuery 另外提供 `hasData`，`data` 不为 `null` 时它为 `true`。[查询结果](../reference/query-results/)列出所有字段。

## 设置新鲜度、重试和重新获取

| TanStack Query | Fuery |
|---|---|
| `staleTime`（默认值：`0`） | `staleTime`，类型为 `Duration`（默认值：0） |
| `staleTime: Infinity` | `staleTime: infiniteDuration` |
| `staleTime: 'static'` | `staleTime: staticStaleTime` |
| `gcTime`（默认值：5 分钟） | `gcTime`，类型为 `Duration`（默认值：5 分钟） |
| `retry: 3`（默认）、`false`、`true` | `retry: RetryPolicy.count(3)`（默认）、`RetryPolicy.never()`、`RetryPolicy.always()` |
| `retry: (failureCount, error) => boolean` | `retry: RetryPolicy.when((failureCount, error) => ...)` |
| `retryDelay: (failureCount, error) => number` | `retryDelay: (failureCount, error) => Duration` |
| `retryOnMount` | `retryOnMount` |
| `refetchOnMount: true`（默认）、`false`、`'always'` | `refetchOnMount: RefetchMode.ifStale`（默认）、`.never`、`.always` |
| `refetchOnWindowFocus` | `refetchOnFocus`，类型为 `RefetchMode`。获得焦点指应用回到前台。 |
| `refetchOnReconnect` | `refetchOnReconnect`，类型为 `RefetchMode` |
| `refetchInterval: 10000` | `refetchInterval: Duration(seconds: 10)` |
| `refetchInterval: (query) => ...`，返回 `false` 时停止轮询 | `refetchInterval`，再加上 `refetchWhile: (result) => ...`。它返回 `false` 期间停止轮询。 |
| `refetchIntervalInBackground` | `refetchIntervalInBackground` |
| `networkMode: 'online'`（默认）、`'always'`、`'offlineFirst'` | `networkMode: NetworkMode.online`（默认）、`.always`、`.offlineFirst` |
| `structuralSharing`、`meta` | `structuralSharing`、`meta` |

Fuery 的选项接受值。对于 TanStack Query 根据查询计算的选项，例如 `staleTime: (query) => ...`，在函数中用它依赖的值构建定义。[查询选项](../reference/query-options/)列出每个选项和它的默认值。

## 禁用查询和提前显示数据

| TanStack Query | Fuery |
|---|---|
| `enabled: false` | `enabled: false`。`refetch()` 仍然会获取数据。 |
| `queryFn: skipToken` | `enabled: false` |
| `placeholderData: keepPreviousData` | `placeholderData: keepPreviousData` |
| `placeholderData: (previousData, previousQuery) => ...` | `placeholderData: (previousData, client) => ...` |
| `initialData`、`initialDataUpdatedAt` | `initialData`、`initialDataUpdatedAt` |
| `select: (data) => ...` | 没有这个选项。`QuerySelector` 根据它从结果中选择的值构建，并且只在这个值变化时重建。 |
| `notifyOnChangeProps` | 构建器上的 `buildWhen`，或者选择器 widget |

`keepPreviousData` 从周围的代码获得数据类型，例如构建查询的函数的返回类型。参见[在屏幕上保留上一页](../guides/queries/#在屏幕上保留上一页)。

## 读取和更新缓存

| TanStack Query | Fuery |
|---|---|
| `getQueryData(['todos'])` | `client.getData(todosQuery)`，或者按键调用 `client.getQueryData<List<Todo>>(['todos'])` |
| `setQueryData(['todos'], todos)` | `client.setData(todosQuery, todos)`，或者按键调用 `setQueryData` |
| `setQueryData(['todos'], (old) => ...)` | `client.updateData(todosQuery, (old) => ...)`，或者按键调用 `updateQueryData` |
| `getQueriesData(filters)` | `getQueriesData<Todo>(queryKey: ...)` |
| `setQueriesData(filters, updater)` | `updateQueriesData((List<Post> posts) => ..., queryKey: ...)` |
| `getQueryState(queryKey)` | `getQueryState(queryKey)` |
| `invalidateQueries({ queryKey, exact, refetchType })` | `invalidateQueries(queryKey: ..., exact: ..., refetchType: RefetchType.active)` |
| `refetchQueries`、`cancelQueries`、`resetQueries`、`removeQueries`、`isFetching`、`isMutating` | 名称相同，使用命名参数 |
| 查询过滤器 `queryKey`、`exact`、`type`、`stale`、`predicate` | 过滤器相同。`type` 接受 `QueryTypeFilter.active`、`.inactive` 或 `.all`。 |
| `getQueryCache()`、`getMutationCache()` | `client.queryCache`、`client.mutationCache`。两者都是只读的：用客户端更改缓存。 |
| `queryCache.subscribe(...)` | `client.watch((client) => ...)`，一个由客户端计算出的值组成的 `Stream` |
| `clear()` | `clear()`，它还会删除持久化数据 |
| `notifyManager.batch(...)` | `notifyManager.batch(...)` |

`getData`、`setData` 和 `updateData` 从定义获得键和数据类型，因此无须类型转换。参见[读取和更新缓存](../guides/query-client/)。

## 在 widget 之外获取

| TanStack Query | Fuery |
|---|---|
| `queryClient.query(options)`、`fetchQuery(options)` | `client.query(todosQuery)` |
| `prefetchQuery(options)` | `client.query(todosQuery).ignore()` |
| `ensureQueryData(options)` | `client.query(query)`，并在查询上设置 `staleTime: staticStaleTime` |
| `queryClient.infiniteQuery(options)`、`fetchInfiniteQuery`、`prefetchInfiniteQuery` | `client.infiniteQuery(postsQuery)` |
| 这些调用中的 `pages: 3` | `InfiniteQuery` 上的 `pages: 3` |

缓存的数据新鲜时，`client.query` 返回缓存的数据，否则获取数据。只有查询或客户端的默认值设置了 `retry` 时，它才会重试。参见[在 widget 之外获取](../guides/query-client/#在-widget-之外获取)。

## 分页加载数据

| TanStack Query | Fuery |
|---|---|
| `useInfiniteQuery({ ... })` | `InfiniteQueryBuilder(query: ..., builder: ...)`，或者 `fuery_hooks` 的 `useInfiniteQuery(query)` |
| `infiniteQueryOptions({ ... })` | `InfiniteQuery(...)` |
| `queryFn: ({ pageParam }) => ...` | `queryFn: (context) => ...`，使用 `context.pageParam` |
| `initialPageParam` | `initialPageParam`，它同时决定页参数的类型 |
| `getNextPageParam: (lastPage, allPages, lastPageParam, allPageParams) => ...` | `getNextPageParam: (data) => ...`，使用 `data.lastPage`、`data.pages`、`data.lastPageParam` 和 `data.pageParams` |
| `getPreviousPageParam: (firstPage, allPages, firstPageParam, allPageParams) => ...` | `getPreviousPageParam: (data) => ...`，使用 `data.firstPage` 和 `data.firstPageParam` |
| 没有下一页时为 `undefined` 或 `null` | `null` |
| `maxPages` | `maxPages` |
| `data.pages`、`data.pageParams` | `state.pages` 和 `state.data?.pageParams` |
| `fetchNextPage`、`fetchPreviousPage`、`hasNextPage`、`hasPreviousPage` | 名称相同 |
| `isFetchingNextPage`、`isFetchingPreviousPage`、`isFetchNextPageError`、`isFetchPreviousPageError` | 名称相同 |
| `setQueryData(key, (data) => ({ ...data, pages: ... }))` | `client.updateData(postsQuery, (data) => data?.mapPages(...))` |

```tsx title="TanStack Query"
function Feed() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey: ['posts'],
      queryFn: ({ pageParam }) => api.getPosts(pageParam),
      initialPageParam: 1,
      getNextPageParam: (lastPage, allPages, lastPageParam) =>
        lastPage.hasMore ? lastPageParam + 1 : undefined,
    })

  return (
    <>
      {data?.pages.map((page) =>
        page.posts.map((post) => <PostRow key={post.id} post={post} />),
      )}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          Load more
        </button>
      )}
    </>
  )
}
```

```dart title="Fuery"
final postsQuery = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);

class Feed extends StatelessWidget {
  const Feed({super.key});

  @override
  Widget build(BuildContext context) {
    return InfiniteQueryBuilder(
      query: postsQuery,
      builder: (context, state) => ListView(
        children: [
          for (final page in state.pages) ...page.posts.map(PostTile.new),
          if (state.hasNextPage)
            TextButton(
              onPressed: state.isFetchingNextPage ? null : state.fetchNextPage,
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}
```

第一个页参数为 `null` 时（例如使用游标时），需要声明类型。参见[基于游标的分页](../guides/infinite-queries/#基于游标的分页)。

## 更改数据

| TanStack Query | Fuery |
|---|---|
| `useMutation({ ... })`、`mutationOptions({ ... })` | `Mutation(...)`，一个定义。为 `mutationFn`、`onMutate` 和 `onError` 的变量写明类型，Dart 会推断其他类型。 |
| `mutationFn: (variables, context) => ...` | `mutationFn: (int id) => ...`。不接收变量的变更是 `NoVariablesMutation`。 |
| `mutation.mutate(variables)` | 在任何 widget 中调用 `deleteTodo.mutate(id, context.queryClient)`，或者在 `MutationBuilder` 或 `useMutation` 的结果上调用 `state.mutate(id)` |
| `mutate(variables, { onSuccess, onError, onSettled })` | 在 `MutationBuilder` 或 `useMutation` 的结果上调用 `state.mutate(variables, MutateOptions(onSuccess: ...))` |
| `mutateAsync(variables)` | `mutateAsync(variables)`，在定义或结果上调用 |
| `reset()` | `reset()` |
| `onMutate: (variables, context) => ...` | `onMutate: (variables, client) => ...` |
| `onSuccess: (data, variables, onMutateResult, context) => ...` | `onSuccess: (data, variables, context, client) => ...` |
| `onError: (error, variables, onMutateResult, context) => ...` | `onError: (error, variables, context, client) => ...` |
| `onSettled: (data, error, variables, onMutateResult, context) => ...` | `onSettled: (data, error, variables, context, client) => ...` |
| `retry`（默认值：`0`） | `retry`（默认值：`RetryPolicy.never()`） |
| `scope: { id: 'drafts' }` | `scope: MutationScope('drafts')` |
| `mutationKey`、`gcTime`、`retryDelay`、`networkMode`、`meta` | 名称相同 |
| `status`、`isIdle`、`isPending`、`isSuccess`、`isError`、`isPaused` | 名称相同。`status` 是 `MutationStatus`。 |
| `data`、`error`、`variables`、`context`、`submittedAt`、`failureCount`、`failureReason` | 名称相同 |

有两个回调参数的名称不同。Fuery 的 `context` 是 `onMutate` 返回的值。TanStack Query v5 把它叫作 `onMutateResult`，较早的 v5 版本叫作 `context`。客户端作为 `client` 放在最后，而 TanStack Query 传的是 `context.client`。

乐观更新的步骤不变：取消重新获取，写入新数据，返回旧数据，出错时回滚，变更结束时使查询失效。

```tsx title="TanStack Query"
function DeleteTodoButton({ todo }: { todo: Todo }) {
  const deleteTodo = useMutation({
    mutationKey: ['todos', 'delete'],
    mutationFn: (id: number) => api.deleteTodo(id),
    onMutate: async (id, context) => {
      await context.client.cancelQueries({ queryKey: ['todos'] })
      const previous = context.client.getQueryData<Todo[]>(['todos'])
      context.client.setQueryData<Todo[]>(['todos'], (todos) =>
        todos?.filter((item) => item.id !== id),
      )
      return previous
    },
    onError: (error, id, previous, context) => {
      if (previous) context.client.setQueryData(['todos'], previous)
    },
    onSettled: (data, error, id, previous, context) =>
      context.client.invalidateQueries({ queryKey: ['todos'] }),
  })

  return <button onClick={() => deleteTodo.mutate(todo.id)}>Delete</button>
}
```

```dart title="Fuery"
final deleteTodo = Mutation(
  mutationKey: const ['todos', 'delete'],
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (int id, client) async {
    await client.cancelQueries(queryKey: ['todos']);
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
  onSettled: (data, error, id, previous, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);

class DeleteTodoButton extends StatelessWidget {
  const DeleteTodoButton(this.todo, {super.key});

  final Todo todo;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => deleteTodo.mutate(todo.id, context.queryClient),
      child: const Text('Delete'),
    );
  }
}
```

[变更](../guides/mutations/)介绍如何执行、显示和重试变更。

## 在任意界面跟踪变更和获取

| TanStack Query | Fuery |
|---|---|
| `useMutationState({ filters: { mutationKey } })` | `MutationStateBuilder(mutation: deleteTodo, builder: (context, runs) => ...)`，或者 `fuery_hooks` 的 `useMutationState(deleteTodo)`。两者都按定义的 `mutationKey` 查找执行。 |
| `useMutationState({ filters: { status: 'pending' } })` | `MutationStateBuilder(mutation: const MutationFilters(status: MutationStatus.pending), ...)` |
| `useMutationState` 的 `select` | `MutationStateSelector(mutation: ..., selector: (runs) => ..., builder: ...)`，只在根据执行计算出的值变化时重建 |
| `useIsMutating()` | `MutationStateSelector(mutation: const MutationFilters(), selector: (runs) => runs.any((run) => run.isPending), ...)` |
| `useIsFetching()` | `client.watch((client) => client.isFetching() > 0)`，用 `StreamBuilder` 显示 |

`MutationStateListener` 为每次发生变化的执行运行副作用，例如每次失败时显示 snackbar。参见[显示变更的每次执行](../guides/mutations/#显示变更的每次执行)。

## 显示多个查询

| TanStack Query | Fuery |
|---|---|
| `useQueries({ queries: [...] })` | `QueriesBuilder(queries: [...], builder: (context, results) => ...)`，或者 `fuery_hooks` 的 `useQueries([...])` |
| `useQueries({ queries, combine })` | `QueriesSelector(queries: [...], selector: (results) => ..., builder: ...)` |

同一个列表中的查询共享一种数据类型，例如每个 id 一个查询。对于不同类型的查询，把一个 `QueryBuilder` 嵌套在另一个里面，或者为每个查询调用一次 `useQuery`。参见[同时显示多个查询](../guides/widgets/#同时显示多个查询)。

## 在一处报告所有失败

| TanStack Query | Fuery |
|---|---|
| `new QueryCache({ onSuccess, onError, onSettled })` | `QueryCache(config: QueryCacheConfig(onSuccess: ..., onError: ..., onSettled: ...))` |
| `new MutationCache({ onMutate, onSuccess, onError, onSettled })` | `MutationCache(config: MutationCacheConfig(...))` |
| `query` 参数 | `query`，即缓存条目（`CachedQuery`） |
| `mutation` 参数 | `mutation`，即执行（`AnyCachedMutation`），它放在最后 |
| `isCancelledError(error)` | `error is CancelledError`。已取消的获取不会到达任何 `QueryCacheConfig` 回调。 |

把两个缓存都传给 `QueryClient` 构造函数。参见[在一处报告所有失败](../guides/client-setup/#在一处报告所有失败)。

## 在应用重启后保留数据

| TanStack Query | Fuery |
|---|---|
| `PersistQueryClientProvider` 搭配 `createSyncStoragePersister` 或 `createAsyncStoragePersister` | `QueryClient(storage: ...)`，搭配你为任意键值存储编写的 `QueryStorage` |
| `experimental_createQueryPersister` 和 `persister` 选项 | 在查询上设置 `persist: QueryPersist(toJson: ..., fromJson: ...)`，在无限查询上使用 `InfiniteQueryPersist` |
| `maxAge`（默认值：24 小时） | 客户端上的 `persistMaxAge`（默认值：1 天），或者 `QueryPersist` 上的 `maxAge` |
| `buster` | `QueryPersist` 上的 `version` |
| 暂停的变更：带 `mutationFn` 的 `setMutationDefaults`，然后调用 `resumePausedMutations()` | 在变更上设置 `persist: MutationPersist(...)`，然后在启动时调用 `client.restore(mutations: [...])` |
| `useIsRestoring()` | 没有对应的 hook。在 `runApp` 之前 `await client.restore()`，第一帧就会显示存储的数据。 |

Fuery 只存储设置了 `persist` 的查询和变更。参见[持久化](../guides/persistence/)。

## 检查缓存

| TanStack Query | Fuery |
|---|---|
| `@tanstack/react-query-devtools` 中的 `ReactQueryDevtools` | `fuery` 中的 `FueryDevtools(child: ...)`，放在 `MaterialApp` 的 `builder` 中 |
| `initialIsOpen` | `initiallyOpen` |
| `buttonPosition` | `buttonAlignment`，类型为 `Alignment` |
| `client` | `client` |
| 带 `onClose` 的 `ReactQueryDevtoolsPanel` | `FueryDevtoolsPanel(onClose: ...)` |
| 只在 `process.env.NODE_ENV === 'development'` 时包含 | 在 debug 构建和 profile 构建中显示。`enabled` 默认为 `!kReleaseMode`。 |

面板在应用内部运行，因此在设备上也能使用。参见[开发者工具](../guides/devtools/)。

## 以流式方式接收响应

| TanStack Query | Fuery |
|---|---|
| `experimental_streamedQuery({ streamFn, reducer, initialValue })` | `streamedQuery(stream: ..., combine: ..., initialValue: ...)`。`combine` 和 `initialValue` 为必填。 |
| `refetchMode: 'reset'`、`'append'`、`'replace'` | `refetchMode: StreamRefetchMode.reset`、`.append`、`.replace` |

`stream` 返回 Dart 的 `Stream`。参见[流式查询](../guides/streaming/)。

## 没有对应项的功能

| TanStack Query | 在 Fuery 中 |
|---|---|
| `useSuspenseQuery`、`useSuspenseInfiniteQuery`、`useSuspenseQueries` | 没有 Suspense。构建器根据结果显示 `pending` 状态。 |
| `throwOnError` 选项、`QueryErrorResetBoundary`、`useQueryErrorResetBoundary` | 没有错误边界。构建器根据结果显示错误，`refetch()` 会再试一次。 |
| `dehydrate`、`hydrate`、`HydrationBoundary` | 没有服务端渲染把数据交给应用。用 `initialData`、`setData` 或[持久化](../guides/persistence/)提供初始数据。 |
| `broadcastQueryClient` | 没有对应项。 |
| `queryKeyHashFn` | 没有这个选项。Fuery 按键的 JSON 形式比较键。 |
| 根据查询计算的选项值，例如 `enabled: (query) => ...` | 只接受值。用定义依赖的值构建定义。 |

## Flutter 中的不同之处

模型保持不变。界面使用模型的方式遵循 Flutter 的惯例。

### 定义放在 build 之外，由 widget 渲染

`Query` 或 `Mutation` 是一个定义：它的键、函数和选项。它不保存数据，也不启动任何操作。像上面的 `todosQuery` 和 `deleteTodo` 那样把它作为顶层值，或者放在接收 id 的函数中。

widget 像 `StreamBuilder` 渲染 stream 那样渲染定义：

- 构建器（例如 `QueryBuilder`）根据结果重建 UI。
- 监听器（例如 `QueryListener` 或 `MutationStateListener`）运行副作用，例如显示 snackbar 或导航。它在变化之后运行，从不在构建期间运行。
- 选择器（例如 `QuerySelector`）只在它选择的值变化时重建。

每个 widget 在挂载期间保持一个观察者，因此显示服务端数据的界面仍然是 `StatelessWidget`。[widget](../guides/widgets/) 列出所有 widget。

### 从定义执行变更

任何 widget 都可以从定义执行变更，使用 `context.queryClient` 提供的客户端：`deleteTodo.mutate(todo.id, context.queryClient)`。`StatelessWidget` 执行变更时不需要 hook，也不需要构建器。

- 执行属于客户端的缓存，不属于 widget，因此 widget 卸载后执行仍会继续。
- `MutationStateSelector` 和 `MutationStateBuilder` 在任何界面上显示它的进度。它们按 `mutationKey` 查找执行。
- 要响应一次调用，例如关闭表单，在 `try` 中用 `await` 等待 `mutateAsync`，然后检查 `context.mounted`。参见[在一次调用成功后采取行动](../guides/mutations/#在一次调用成功后采取行动)。
- `MutationBuilder` 保持自己的观察者。widget 只显示自己开始的执行时，使用它。

### 独立包中的 hook

除了 Dart 和 Flutter，`fuery` 不依赖任何其他东西。要使用 hook，添加 [`fuery_hooks`](../guides/hooks/) 和 `flutter_hooks`。它的 `useQuery`、`useInfiniteQuery`、`useMutation`、`useQueries`、`useMutationState` 和 `useQueryClient` 在 `HookWidget` 中读取同样的定义。每个 hook 接收一个定义，例如 `useQuery(todosQuery)`，而不是选项对象。

副作用放在变化 hook 中：`useOnQueryChange`、`useOnMutationChange` 和 `useOnMutationStateChange`。

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

变化 hook 在变化之后、构建之外运行它的监听器。`flutter_hooks` 在构建期间运行 `useEffect` 回调，这时显示 snackbar 或导航会失败。参见 [useEffect 中的 snackbar 和导航](../guides/hooks/#useeffect-中的-snackbar-和导航)。

### 获得焦点和重新连接时重新获取

- 获得焦点指应用处于前台（`AppLifecycleState.resumed`）。Fuery 的 widget、hook 和 `FueryProvider` 会接入应用生命周期，因此 `refetchOnFocus` 无须配置。只在 bloc 中使用查询的应用调用一次 `FueryBinding.ensureInitialized()`。
- 在来源报告设备离线之前，Fuery 一直把设备视为在线。用 `onlineManager.setEventListener` 接入一个来源，例如 `connectivity_plus`。之后查询会在离线时暂停，在重新连接时重新获取。
- 应用在后台时轮询停止，除非查询设置了 `refetchIntervalInBackground`。

[重新获取和离线](../guides/lifecycle/)展示网络连接状态的配置。

### 无须代码生成，类型来自你的函数

- 上面的 `todosQuery` 是 `Query<List<Todo>>`，因为 `api.getTodos()` 返回 `Future<List<Todo>>`。widget、结果和回调无须类型参数就带有这个类型。
- 变更从 `mutationFn` 的参数（例如 `(int id) => api.deleteTodo(id)`）以及 `onMutate` 的返回值获得类型。
- 有两种情况需要写明类型：只按键读取或写入，例如 `getQueryData<List<Todo>>(['todos'])`；以及第一个页参数为 `null` 的无限查询。
- 不生成任何代码。没有 `build_runner` 步骤，也没有注解。
