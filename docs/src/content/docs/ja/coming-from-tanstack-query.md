---
title: TanStack Query を使ってきた方へ
description: TanStack Query（React Query）v5 の各概念に対応する、Flutter アプリでの Fuery の名前を紹介します。クライアント、クエリキー、useQuery のオプションと結果、ミューテーション、無限クエリ、永続化、devtools を扱います。
sourceHash: 4c2d28d32c2b
head:
  - tag: title
    content: TanStack Query（React Query）から Flutter に移る方へ | Fuery
---

このページでは、[TanStack Query](https://tanstack.com/query) v5（旧 React Query）の各概念に対応する Fuery の名前を紹介します。TanStack Query を知っていて、Flutter アプリでも同じキャッシュモデルを使いたい React 開発者向けです。

Fuery のキャッシュと再取得のモデルは TanStack Query から着想を得ているので、知っていることの多くがそのまま役立ちます。

- クエリキーは、キャッシュエントリを識別する名前です。そのキーを使うすべての画面が、そのキャッシュエントリとリクエストを共有します。
- データは `staleTime` の間は新鮮（fresh）で、その後古く（stale）なります。Fuery がバックグラウンドで再取得している間も、古いデータは画面に表示されたままです。
- 何も使っていないデータは、`gcTime` の後に Fuery がメモリから削除します。
- `invalidateQueries`、`setQueryData`、`onMutate`、`fetchNextPage`、結果のほとんどのフィールドは、名前がそのままです。
- デフォルトも同じです。`staleTime` はゼロ、`gcTime` は 5 分で、画面に表示中のクエリはバックオフ付きで 3 回再試行します。

一方、画面でのクエリの使い方は Flutter の慣習に従います。その部分は [Flutter で異なる点](#flutter-で異なる点)で説明しています。

## 全体を通して変わる名前

以下の各表では、左に TanStack Query の名前、右に Fuery の名前を示します。すべての表に共通する変更が 4 つあります。

- オプションはオブジェクトではなく、`Query(queryKey: ..., queryFn: ...)` のような定義の名前付き引数です。
- 時間の長さはミリ秒ではなく `Duration` です。`dataUpdatedAt` などのタイムスタンプは、エポックからのミリ秒のままです。
- データがないときは、`undefined` ではなく `null` です。
- 文字列の値は enum です。`'always'` は `RefetchMode.always` に、`'pending'` は `QueryStatus.pending` になります。

## クライアントを設定する

| TanStack Query | Fuery |
|---|---|
| `new QueryClient({ defaultOptions })` | `QueryClient(defaultOptions: DefaultOptions(...))`。`queries` には `QueryDefaults`、`mutations` には `MutationDefaults` を使います。 |
| `<QueryClientProvider client={queryClient}>` | 不要です。`main` で `Fuery.client` に代入してください。`FueryProvider(client: ..., child: ...)` は、サブツリーに専用のクライアントを渡します。 |
| `useQueryClient()` | 任意のウィジェットで `context.queryClient`、または `fuery_hooks` の `useQueryClient()` |
| `mount()`、`unmount()` | `mount()`、`unmount()`。`Fuery.client` への代入と `FueryProvider` が、この 2 つを自動で呼び出します。 |
| `setQueryDefaults`、`getQueryDefaults`、`setMutationDefaults`、`getMutationDefaults` | 同じ名前 |

各コード例のペアは、同じコードを 2 通りで示します。先が TanStack Query、後が Fuery です。`api`、`Todo`、`TodoList` などのウィジェットは、アプリ独自のコードを表します。

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

何も設定しないアプリでも動きます。最初に使うときに、Fuery が `Fuery.client` を作成します。[クライアントを設定する](../guides/client-setup/)を参照してください。

## クエリを定義して表示する

| TanStack Query | Fuery |
|---|---|
| `queryKey: ['todos', id]` | `queryKey: ['todos', id]`（`List<Object?>`）。Fuery はキーを値で比較し、フィルターはキーのプレフィックスで一致を判定します。 |
| `queryKey: ['todos', { status, page }]` | `queryKey: ['todos', {'status': status, 'page': page}]`。マップの要素の順序は関係ありません。キーに入れるオブジェクトには `toJson()` メソッドが必要です。 |
| `queryFn: ({ queryKey, signal, meta, client }) => ...` | `queryFn: (context) => ...`。`context.queryKey`、`context.signal`、`context.meta`、`context.client` を使います。 |
| データを `undefined` にできない | クエリ関数は、`Future<List<Todo>>` のような非 null 許容の型を返します。 |
| `fetch(url, { signal })` | `context.signal.onAbort(...)` を、HTTP クライアントのキャンセル処理につなぎます。[リクエストをキャンセルする](../guides/queries/#リクエストをキャンセルする)を参照してください。 |
| `queryOptions({ ... })` | `Query(...)`。ウィジェット、フック、クライアントのすべてが受け取る定義です。 |
| `useQuery({ ... })` | `QueryBuilder(query: ..., builder: ...)`、または `fuery_hooks` の `useQuery(query)` |

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

`todosQuery` はデータを持たず、何も開始しません。`QueryBuilder` はマウント時に取得し、新しい結果が届くたびにリビルドします。キーとオプションについては、[クエリ](../guides/queries/)で説明しています。

## 結果を読み取る

| TanStack Query | Fuery |
|---|---|
| `status`：`'pending'`、`'error'`、`'success'` | `status`：`QueryStatus.pending`、`.error`、`.success` |
| `fetchStatus`：`'fetching'`、`'paused'`、`'idle'` | `fetchStatus`：`FetchStatus.fetching`、`.paused`、`.idle` |
| `data`、`error` | `data`、`error` |
| `isPending`、`isSuccess`、`isError`、`isLoading`、`isFetching`、`isRefetching`、`isPaused` | 同じ名前 |
| `isLoadingError`、`isRefetchError`、`isPlaceholderData`、`isStale`、`isFetched`、`isFetchedAfterMount`、`isEnabled` | 同じ名前 |
| `dataUpdatedAt`、`errorUpdatedAt`、`errorUpdateCount`、`failureCount`、`failureReason` | 同じ名前 |
| `refetch({ cancelRefetch, throwOnError })` | `refetch(cancelRefetch: ..., throwOnError: ...)`。`Future<QueryResult>` を返します。 |

Fuery には `hasData` もあります。`data` が `null` でないときに `true` になります。すべてのフィールドの一覧は[クエリの結果](../reference/query-results/)にあります。

## 鮮度、再試行、再取得を設定する

| TanStack Query | Fuery |
|---|---|
| `staleTime`（デフォルトは `0`） | `Duration` 型の `staleTime`（デフォルトはゼロ） |
| `staleTime: Infinity` | `staleTime: infiniteDuration` |
| `staleTime: 'static'` | `staleTime: staticStaleTime` |
| `gcTime`（デフォルトは 5 分） | `Duration` 型の `gcTime`（デフォルトは 5 分） |
| `retry: 3`（デフォルト）、`false`、`true` | `retry: RetryPolicy.count(3)`（デフォルト）、`RetryPolicy.never()`、`RetryPolicy.always()` |
| `retry: (failureCount, error) => boolean` | `retry: RetryPolicy.when((failureCount, error) => ...)` |
| `retryDelay: (failureCount, error) => number` | `retryDelay: (failureCount, error) => Duration` |
| `retryOnMount` | `retryOnMount` |
| `refetchOnMount: true`（デフォルト）、`false`、`'always'` | `refetchOnMount: RefetchMode.ifStale`（デフォルト）、`.never`、`.always` |
| `refetchOnWindowFocus` | `RefetchMode` 型の `refetchOnFocus`。フォーカスとは、アプリがフォアグラウンドに戻ることです。 |
| `refetchOnReconnect` | `RefetchMode` 型の `refetchOnReconnect` |
| `refetchInterval: 10000` | `refetchInterval: Duration(seconds: 10)` |
| `refetchInterval: (query) => ...`（ポーリングを止めるには `false` を返す） | `refetchInterval` と `refetchWhile: (result) => ...`。`refetchWhile` が `false` を返している間、ポーリングは止まります。 |
| `refetchIntervalInBackground` | `refetchIntervalInBackground` |
| `networkMode: 'online'`（デフォルト）、`'always'`、`'offlineFirst'` | `networkMode: NetworkMode.online`（デフォルト）、`.always`、`.offlineFirst` |
| `structuralSharing`、`meta` | `structuralSharing`、`meta` |

Fuery のオプションは値を受け取ります。`staleTime: (query) => ...` のように TanStack Query がクエリから計算するオプションは、依存する値から定義を作る関数で表してください。すべてのオプションとそのデフォルトの一覧は[クエリのオプション](../reference/query-options/)にあります。

## クエリをオフにし、データを早めに表示する

| TanStack Query | Fuery |
|---|---|
| `enabled: false` | `enabled: false`。`refetch()` を呼び出せば取得します。 |
| `queryFn: skipToken` | `enabled: false` |
| `placeholderData: keepPreviousData` | `placeholderData: keepPreviousData` |
| `placeholderData: (previousData, previousQuery) => ...` | `placeholderData: (previousData, client) => ...` |
| `initialData`、`initialDataUpdatedAt` | `initialData`、`initialDataUpdatedAt` |
| `select: (data) => ...` | オプションはありません。`QuerySelector` は結果から選択した値でビルドし、その値が変わったときだけリビルドします。 |
| `notifyOnChangeProps` | ビルダーの `buildWhen`、またはセレクターウィジェット |

`keepPreviousData` は、クエリを作る関数の戻り値の型など、周りのコードからデータ型を受け取ります。[前のページを表示したままにする](../guides/queries/#前のページを表示したままにする)を参照してください。

## キャッシュの読み取りと更新

| TanStack Query | Fuery |
|---|---|
| `getQueryData(['todos'])` | `client.getData(todosQuery)`、またはキーで読み取る `client.getQueryData<List<Todo>>(['todos'])` |
| `setQueryData(['todos'], todos)` | `client.setData(todosQuery, todos)`、またはキーで書き込む `setQueryData` |
| `setQueryData(['todos'], (old) => ...)` | `client.updateData(todosQuery, (old) => ...)`、またはキーで更新する `updateQueryData` |
| `getQueriesData(filters)` | `getQueriesData<Todo>(queryKey: ...)` |
| `setQueriesData(filters, updater)` | `updateQueriesData((List<Post> posts) => ..., queryKey: ...)` |
| `getQueryState(queryKey)` | `getQueryState(queryKey)` |
| `invalidateQueries({ queryKey, exact, refetchType })` | `invalidateQueries(queryKey: ..., exact: ..., refetchType: RefetchType.active)` |
| `refetchQueries`、`cancelQueries`、`resetQueries`、`removeQueries`、`isFetching`、`isMutating` | 同じ名前で、引数は名前付き引数です。 |
| クエリフィルターの `queryKey`、`exact`、`type`、`stale`、`predicate` | 同じフィルターです。`type` には `QueryTypeFilter.active`、`.inactive`、`.all` を渡します。 |
| `getQueryCache()`、`getMutationCache()` | `client.queryCache`、`client.mutationCache`。どちらも読み取り専用です。キャッシュはクライアント経由で変更してください。 |
| `queryCache.subscribe(...)` | `client.watch((client) => ...)`。クライアントから計算した値の `Stream` です。 |
| `clear()` | `clear()`。永続化されたデータも削除します。 |
| `notifyManager.batch(...)` | `notifyManager.batch(...)` |

`getData`、`setData`、`updateData` は定義からキーとデータ型を受け取るので、キャストは不要です。[キャッシュの読み取りと更新](../guides/query-client/)を参照してください。

## ウィジェットの外で取得する

| TanStack Query | Fuery |
|---|---|
| `queryClient.query(options)`、`fetchQuery(options)` | `client.query(todosQuery)` |
| `prefetchQuery(options)` | `client.query(todosQuery).ignore()` |
| `ensureQueryData(options)` | `client.query(query)`。クエリには `staleTime: staticStaleTime` を指定します。 |
| `queryClient.infiniteQuery(options)`、`fetchInfiniteQuery`、`prefetchInfiniteQuery` | `client.infiniteQuery(postsQuery)` |
| 上記の呼び出しでの `pages: 3` | `InfiniteQuery` の `pages: 3` |

`client.query` は、キャッシュされたデータが新鮮な間はそのデータを返し、そうでなければ取得します。再試行するのは、クエリまたはクライアントのデフォルトが `retry` を設定している場合だけです。[ウィジェットの外で取得する](../guides/query-client/#ウィジェットの外で取得する)を参照してください。

## ページを読み込む

| TanStack Query | Fuery |
|---|---|
| `useInfiniteQuery({ ... })` | `InfiniteQueryBuilder(query: ..., builder: ...)`、または `fuery_hooks` の `useInfiniteQuery(query)` |
| `infiniteQueryOptions({ ... })` | `InfiniteQuery(...)` |
| `queryFn: ({ pageParam }) => ...` | `queryFn: (context) => ...`。`context.pageParam` を使います。 |
| `initialPageParam` | `initialPageParam`。ページパラメーターの型も決めます。 |
| `getNextPageParam: (lastPage, allPages, lastPageParam, allPageParams) => ...` | `getNextPageParam: (data) => ...`。`data.lastPage`、`data.pages`、`data.lastPageParam`、`data.pageParams` を使います。 |
| `getPreviousPageParam: (firstPage, allPages, firstPageParam, allPageParams) => ...` | `getPreviousPageParam: (data) => ...`。`data.firstPage` と `data.firstPageParam` を使います。 |
| 次のページがないときは `undefined` または `null` | `null` |
| `maxPages` | `maxPages` |
| `data.pages`、`data.pageParams` | `state.pages` と `state.data?.pageParams` |
| `fetchNextPage`、`fetchPreviousPage`、`hasNextPage`、`hasPreviousPage` | 同じ名前 |
| `isFetchingNextPage`、`isFetchingPreviousPage`、`isFetchNextPageError`、`isFetchPreviousPageError` | 同じ名前 |
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

カーソルを使う場合のように最初のページパラメーターが `null` のときは、型を宣言する必要があります。[カーソルベースのページ](../guides/infinite-queries/#カーソルベースのページ)を参照してください。

## データを変更する

| TanStack Query | Fuery |
|---|---|
| `useMutation({ ... })`、`mutationOptions({ ... })` | `Mutation(...)`（定義）。`mutationFn` のパラメーターに型を付けると、ほかの型は Dart が推論します。 |
| `mutationFn: (variables, context) => ...` | `mutationFn: (int id) => ...`。何も受け取らないミューテーションは `NoVariablesMutation` です。 |
| `mutation.mutate(variables)` | 任意のウィジェットから `deleteTodo.mutate(id, context.queryClient)`、または `MutationBuilder` や `useMutation` の結果で `state.mutate(id)` |
| `mutate(variables, { onSuccess, onError, onSettled })` | `MutationBuilder` や `useMutation` の結果で `state.mutate(variables, MutateOptions(onSuccess: ...))` |
| `mutateAsync(variables)` | 定義または結果の `mutateAsync(variables)` |
| `reset()` | `reset()` |
| `onMutate: (variables, context) => ...` | `onMutate: (variables, client) => ...` |
| `onSuccess: (data, variables, onMutateResult, context) => ...` | `onSuccess: (data, variables, context, client) => ...` |
| `onError: (error, variables, onMutateResult, context) => ...` | `onError: (error, variables, context, client) => ...` |
| `onSettled: (data, error, variables, onMutateResult, context) => ...` | `onSettled: (data, error, variables, context, client) => ...` |
| `retry`（デフォルトは `0`） | `retry`（デフォルトは `RetryPolicy.never()`） |
| `scope: { id: 'drafts' }` | `scope: MutationScope('drafts')` |
| `mutationKey`、`gcTime`、`retryDelay`、`networkMode`、`meta` | 同じ名前 |
| `status`、`isIdle`、`isPending`、`isSuccess`、`isError`、`isPaused` | 同じ名前です。`status` は `MutationStatus` です。 |
| `data`、`error`、`variables`、`context`、`submittedAt`、`failureCount`、`failureReason` | 同じ名前 |

コールバックの引数のうち 2 つは名前が異なります。Fuery の `context` は、`onMutate` が返した値です。TanStack Query v5 ではこれを `onMutateResult` と呼び、v5 の初期のリリースでは `context` と呼びます。TanStack Query が `context.client` で渡すクライアントは、Fuery では最後の引数 `client` です。

楽観的更新の手順は変わりません。再取得をキャンセルし、新しいデータを書き込み、以前のデータを返し、エラー時にロールバックし、ミューテーションが完了したら無効化します。

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
  onMutate: (id, client) async {
    await client.cancelQueries(queryKey: ['todos']);
    final previous = client.getData(todosQuery);
    client.updateData(
      todosQuery,
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, id, previous, client) {
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

ミューテーションの実行、表示、再試行については、[ミューテーション](../guides/mutations/)で説明しています。

## どの画面からでもミューテーションと取得を追跡する

| TanStack Query | Fuery |
|---|---|
| `useMutationState({ filters: { mutationKey } })` | `MutationStateBuilder(mutation: deleteTodo, builder: (context, runs) => ...)`、または `fuery_hooks` の `useMutationState(deleteTodo)`。どちらも定義の `mutationKey` で実行を見つけます。 |
| `useMutationState({ filters: { status: 'pending' } })` | `MutationStateBuilder(mutation: const MutationFilters(status: MutationStatus.pending), ...)` |
| `useMutationState` の `select` | `MutationStateSelector(mutation: ..., selector: (runs) => ..., builder: ...)`。実行から計算した値が変わったときだけリビルドします。 |
| `useIsMutating()` | `MutationStateSelector(mutation: const MutationFilters(), selector: (runs) => runs.any((run) => run.isPending), ...)` |
| `useIsFetching()` | `client.watch((client) => client.isFetching() > 0)` を `StreamBuilder` で表示 |

`MutationStateListener` は、変化した実行ごとに副作用を実行します。たとえば、失敗ごとにスナックバーを表示します。[ミューテーションのすべての実行を表示する](../guides/mutations/#ミューテーションのすべての実行を表示する)を参照してください。

## 複数のクエリを表示する

| TanStack Query | Fuery |
|---|---|
| `useQueries({ queries: [...] })` | `QueriesBuilder(queries: [...], builder: (context, results) => ...)`、または `fuery_hooks` の `useQueries([...])` |
| `useQueries({ queries, combine })` | `QueriesSelector(queries: [...], selector: (results) => ..., builder: ...)` |

1 つのリストに入れるクエリは、id ごとのクエリのように、同じデータ型を共有します。型の異なるクエリには、`QueryBuilder` を入れ子にするか、クエリごとに `useQuery` を 1 回ずつ呼び出してください。[複数のクエリをまとめて表示する](../guides/widgets/#複数のクエリをまとめて表示する)を参照してください。

## すべての失敗を 1 か所で報告する

| TanStack Query | Fuery |
|---|---|
| `new QueryCache({ onSuccess, onError, onSettled })` | `QueryCache(config: QueryCacheConfig(onSuccess: ..., onError: ..., onSettled: ...))` |
| `new MutationCache({ onMutate, onSuccess, onError, onSettled })` | `MutationCache(config: MutationCacheConfig(...))` |
| `query` 引数 | `query`。キャッシュエントリ（`CachedQuery`）です。 |
| `mutation` 引数 | `mutation`。実行（`AnyCachedMutation`）で、最後の引数です。 |
| `isCancelledError(error)` | `error is CancelledError`。キャンセルされた取得は、`QueryCacheConfig` のどのコールバックにも届きません。 |

両方のキャッシュを `QueryClient` のコンストラクターに渡してください。[すべての失敗を 1 か所で報告する](../guides/client-setup/#すべての失敗を-1-か所で報告する)を参照してください。

## 再起動後もデータを保持する

| TanStack Query | Fuery |
|---|---|
| `createSyncStoragePersister` または `createAsyncStoragePersister` を使う `PersistQueryClientProvider` | `QueryClient(storage: ...)`。任意のキーバリューストア向けに自分で書いた `QueryStorage` を使います。 |
| `experimental_createQueryPersister` と `persister` オプション | クエリの `persist: QueryPersist(toJson: ..., fromJson: ...)`、無限クエリの `InfiniteQueryPersist` |
| `maxAge`（デフォルトは 24 時間） | クライアントの `persistMaxAge`（デフォルトは 1 日）、または `QueryPersist` の `maxAge` |
| `buster` | `QueryPersist` の `version` |
| 一時停止中のミューテーション：`mutationFn` を指定した `setMutationDefaults` の後に `resumePausedMutations()` | ミューテーションに `persist: MutationPersist(...)` を指定し、起動時に `client.restore(mutations: [...])` |
| `useIsRestoring()` | フックはありません。`runApp` の前に `await client.restore()` を実行すると、最初のフレームから保存されたデータを表示します。 |

Fuery が保存するのは、`persist` を持つクエリとミューテーションだけです。[永続化](../guides/persistence/)を参照してください。

## キャッシュを確認する

| TanStack Query | Fuery |
|---|---|
| `@tanstack/react-query-devtools` の `ReactQueryDevtools` | `fuery` の `FueryDevtools(child: ...)` を `MaterialApp` の `builder` に置く |
| `initialIsOpen` | `initiallyOpen` |
| `buttonPosition` | `Alignment` 型の `buttonAlignment` |
| `client` | `client` |
| `onClose` を指定した `ReactQueryDevtoolsPanel` | `FueryDevtoolsPanel(onClose: ...)` |
| `process.env.NODE_ENV === 'development'` のときだけ含まれる | デバッグビルドとプロファイルビルドで表示されます。`enabled` のデフォルトは `!kReleaseMode` です。 |

パネルはアプリの中で動くので、デバイス上でも使えます。[Devtools](../guides/devtools/) を参照してください。

## レスポンスをストリーミングする

| TanStack Query | Fuery |
|---|---|
| `experimental_streamedQuery({ streamFn, reducer, initialValue })` | `streamedQuery(stream: ..., combine: ..., initialValue: ...)`。`combine` と `initialValue` は必須です。 |
| `refetchMode: 'reset'`、`'append'`、`'replace'` | `refetchMode: StreamRefetchMode.reset`、`.append`、`.replace` |

`stream` は Dart の `Stream` を返します。[ストリーミングクエリ](../guides/streaming/)を参照してください。

## 対応するものがない機能

| TanStack Query | Fuery では |
|---|---|
| `useSuspenseQuery`、`useSuspenseInfiniteQuery`、`useSuspenseQueries` | Suspense はありません。ビルダーが結果から pending 状態を表示します。 |
| `throwOnError` オプション、`QueryErrorResetBoundary`、`useQueryErrorResetBoundary` | エラーバウンダリーはありません。ビルダーが結果からエラーを表示し、`refetch()` でもう一度取得します。 |
| `dehydrate`、`hydrate`、`HydrationBoundary` | サーバーレンダリングがアプリにデータを渡すことはありません。`initialData`、`setData`、[永続化](../guides/persistence/)のデータから始めてください。 |
| `broadcastQueryClient` | 対応するものはありません。 |
| `queryKeyHashFn` | オプションはありません。Fuery はキーを JSON 形式で比較します。 |
| `enabled: (query) => ...` のように、クエリから計算するオプションの値 | 値だけを受け取ります。依存する値から定義を作ってください。 |

## Flutter で異なる点

モデルはそのまま使えます。画面での使い方は Flutter の慣習に従います。

### build の外で定義し、ウィジェットで描画する

`Query` や `Mutation` は定義です。キー、関数、オプションを持ちます。データは持たず、何も開始しません。上の `todosQuery` や `deleteTodo` のようにトップレベルの値にするか、id を受け取る関数にしてください。

ウィジェットは、`StreamBuilder` がストリームを描画するのと同じように定義を描画します。

- `QueryBuilder` などのビルダーは、結果から UI をリビルドします。
- `QueryListener` や `MutationStateListener` などのリスナーは、スナックバーや画面遷移などの副作用を実行します。リスナーは変更の後に実行され、ビルド中には実行されません。
- `QuerySelector` などのセレクターは、選択した値が変わったときだけリビルドします。

各ウィジェットはマウントされている間オブザーバーを保持するので、サーバーデータを表示する画面は `StatelessWidget` のままです。すべてのウィジェットの一覧は[ウィジェット](../guides/widgets/)にあります。

### 定義からミューテーションを実行する

どのウィジェットも、`deleteTodo.mutate(todo.id, context.queryClient)` のように、`context.queryClient` のクライアントで定義からミューテーションを実行できます。`StatelessWidget` でも、フックやビルダーは不要です。

- 実行はウィジェットではなくクライアントのキャッシュに属するので、ウィジェットがアンマウントされた後も続きます。
- `MutationStateSelector` と `MutationStateBuilder` は、どの画面でも実行の進行状況を表示します。2 つのウィジェットは `mutationKey` で実行を見つけます。
- フォームを閉じるなど、1 回の呼び出しに反応するには、`try` の中で `mutateAsync` を await し、その後 `context.mounted` を確認してください。[1 回の呼び出しが成功した後に処理する](../guides/mutations/#1-回の呼び出しが成功した後に処理する)を参照してください。
- `MutationBuilder` は独自のオブザーバーを保持します。自身が開始した実行だけを表示するウィジェットに使ってください。

### フックは独立したパッケージで

`fuery` は Dart と Flutter 以外に依存しません。フックを使うには、`flutter_hooks` と一緒に [`fuery_hooks`](../guides/hooks/) を追加してください。`fuery_hooks` の `useQuery`、`useInfiniteQuery`、`useMutation`、`useQueries`、`useMutationState`、`useQueryClient` は、`HookWidget` の中で同じ定義を読み取ります。各フックは、オプションのオブジェクトではなく、`useQuery(todosQuery)` のように定義を受け取ります。

副作用は、変更に反応するフックの `useOnQueryChange`、`useOnMutationChange`、`useOnMutationStateChange` に書いてください。

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

変更に反応するフックは、変更の後、ビルドの外でリスナーを実行します。`flutter_hooks` は `useEffect` のコールバックをビルド中に実行するので、そこではスナックバーの表示や画面遷移が失敗します。[useEffect でのスナックバーと画面遷移](../guides/hooks/#useeffect-でのスナックバーと画面遷移)を参照してください。

### フォーカス時と再接続時の再取得

- フォーカスとは、アプリがフォアグラウンドにある状態（`AppLifecycleState.resumed`）です。Fuery のウィジェット、フック、`FueryProvider` がアプリのライフサイクルを接続するので、`refetchOnFocus` に設定は不要です。Bloc からしかクエリを使わないアプリでは、`FueryBinding.ensureInitialized()` を 1 回呼び出します。
- ソースがオフラインを報告するまで、Fuery はデバイスをオンラインとして扱います。`connectivity_plus` などのソースを `onlineManager.setEventListener` で接続してください。すると、クエリはオフラインの間は一時停止し、再接続すると再取得します。
- クエリが `refetchIntervalInBackground` を設定していない限り、アプリがバックグラウンドにある間はポーリングが止まります。

接続状態の設定は、[再取得とオフライン](../guides/lifecycle/)で紹介しています。

### コード生成なし、型は関数から

- 上の `todosQuery` は、`api.getTodos()` が `Future<List<Todo>>` を返すので `Query<List<Todo>>` です。ウィジェット、結果、コールバックは、型引数なしでその型を引き継ぎます。
- ミューテーションは、`(int id) => api.deleteTodo(id)` のような `mutationFn` のパラメーターと、`onMutate` の戻り値から型を受け取ります。
- 型を明示するのは 2 つの場合です。`getQueryData<List<Todo>>(['todos'])` のようにキーだけで読み書きする場合と、最初のページパラメーターが `null` の無限クエリです。
- 何も生成しません。`build_runner` の手順もアノテーションもありません。
