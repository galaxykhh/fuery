---
title: キャッシュの読み取りと更新
description: Flutter でキャッシュされたデータを読み書きし、無効化し、監視する方法を説明します。ウィジェットの外での取得と、ログアウト時のキャッシュの消去も扱います。
head:
  - tag: title
    content: Flutter でキャッシュされたデータを無効化、更新、読み取りする | Fuery
sourceHash: 8b902bc3a7a6
---

`QueryClient` を使うと、新しいリクエストなしですべての画面の表示を更新したり、サーバーでの変更後にデータを再取得したり、画面を開く前に取得したりできます。ウィジェット内では、`context.queryClient` がウィジェットの使うクライアントを返します。それ以外の場所では、設定したクライアントを使ってください。`Fuery.client`、または `FueryProvider` に渡したクライアントです。[クエリが使うクライアント](../client-setup/#クエリが使うクライアント)を参照してください。

## キャッシュを読み書きする

クライアントは、クエリキーごとに 1 つのキャッシュエントリ（`CachedQuery`）を保持します。キャッシュエントリは、そのキーのデータと状態です。データは、クエリの定義を使って読み書きします。

```dart
final client = Fuery.client;

client.getData(todosQuery);                             // the data, or null
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.getQueryState(['todos'])?.dataUpdatedAt;         // the whole QueryState
```

- `getData`、`setData`、`updateData` は、キーとデータ型を[クエリの定義](../organizing-queries/)から受け取ります。そのため、キャストは不要です。
- そのキーを使うすべてのウィジェットが、新しいデータでリビルドします。
- キーにキャッシュエントリがない場合、`setData` はクエリのすべてのオプションを持つキャッシュエントリを作成します。そのため、Fuery はデータを `persist` で保存し、再取得もできます。
- `updateData` の更新関数が `null` を返すと、キャッシュは変わりません。

キーしかない場合は、`getQueryData`、`setQueryData`、`updateQueryData` を使い、`client.getQueryData<List<Todo>>(['todos'])` のようにデータ型を指定してください。`setQueryData` が作成したキャッシュエントリにはクエリ関数がありません。そのため、オブザーバーか `client.query` がそのキーのクエリを提供するまで、再取得はこのキャッシュエントリをスキップします。キーを別のデータ型として読み取ると、メソッドは [`StateError`](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y) をスローします。

`getQueryState` は、データの最終更新時刻など、1 つのキーの `QueryState` を返します。フィールドの一覧は [QueryState のフィールド](../../reference/query-client/#querystate-のフィールド)にあります。

WebSocket の 1 フレームから書き込む場合など、多くのキーを一度に書き込むときは、書き込みを `notifyManager.batch` で囲んでください。こうすると、Fuery は最後の書き込みの後に 1 回だけウィジェットに通知します。

```dart
notifyManager.batch(() {
  for (final todo in frame.todos) {
    client.setQueryData(['todo', todo.id], todo);
  }
});
```

## 複数のクエリをまとめて更新する

`updateQueriesData` は、キーの配下にあるキャッシュエントリのうち、データが更新関数の型に一致するものをすべて更新します。たとえば、キャッシュされたすべての検索結果の中の投稿を更新できます。

```dart
client.updateQueriesData(
  queryKey: ['posts', 'search'],
  (List<Post> posts) => [
    for (final post in posts) post.id == id ? post.copyWith(liked: true) : post,
  ],
);
```

- Fuery は、キーの配下にある別のデータ型のキャッシュエントリをスキップします。そのため、同じプレフィックスの下にリストと詳細を置けます。
- Fuery は、データのないキャッシュエントリをスキップします。`null` を返すと、キャッシュエントリは変わりません。
- 更新関数のパラメーターには、`Iterable<Post>` のようなスーパータイプではなく、キャッシュエントリのデータ型そのものを指定してください。型がないと、`updateQueriesData` は `ArgumentError` をスローします。
- `setData` と同じく、`updatedAt` は新しいデータを取得したとみなす時刻を設定します。

## キャッシュの内容を列挙する

`getQueriesData` は、`queryKey`、`exact`、`predicate` に一致するすべてのキャッシュエントリについて、キーとデータを返します。

```dart
for (final (key, todo) in client.getQueriesData<Todo>(queryKey: ['todo'])) {
  print('$key holds $todo');
}
```

Fuery はデータを渡された型にキャストします。そのため、一致するキャッシュエントリは、すべてその型のデータを持っている必要があります。`['todo', 1]` のような詳細のキーは、`['todos']` のリストとは別のプレフィックスに置いてください。

そのほかの情報は、キャッシュから読み取ってください。`client.queryCache` と `client.mutationCache` には `getAll`、`find`、`findAll` があります。

```dart
final staleOnScreen = client.queryCache.findAll(
  const QueryFilters(type: QueryTypeFilter.active, stale: true),
);
final saving = client.mutationCache.findAll(
  const MutationFilters(status: MutationStatus.pending),
);
```

クエリキャッシュで一致するものは、キャッシュエントリ（`CachedQuery`）です。ミューテーションキャッシュで一致するものは、1 回の `mutate` 呼び出しの実行（`CachedMutation`）です。フィールドの一覧は[キャッシュ](../../reference/query-client/#キャッシュ)にあります。キャッシュは読み取り専用です。キャッシュを変更するときは、クライアントを使ってください。

## 無効化する

サーバーでデータが変わったら、影響を受けるキャッシュエントリを古い（stale）状態にしてください。

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

一致するキャッシュエントリのうち、使用中のものを Fuery はすぐに再取得します。使用中とは、マウントされたウィジェットなど、有効な[オブザーバー](../../how-the-cache-works/#オブザーバー)があることです。それ以外のキャッシュエントリは、次に使われたときに Fuery が再取得します。古い状態にするだけなら、`refetchType: RefetchType.none` を渡してください。

## 操作の対象にするクエリを選ぶ

`invalidateQueries`、`refetchQueries`、`resetQueries`、`cancelQueries`、`removeQueries`、`isFetching` は、同じフィルターでキャッシュエントリを選びます。フィルターは `queryKey`、`exact`、`type`、`stale`、`predicate` です。[一致するクエリへの操作](../../reference/query-client/#一致するクエリへの操作)、[クエリフィルター](../../reference/query-client/#クエリフィルター)、[再取得とキャンセルの引数](../../reference/query-client/#再取得とキャンセルの引数)を参照してください。

### 画面に表示中のものだけを更新する

```dart
client.invalidateQueries(
  queryKey: ['todos'],
  type: QueryTypeFilter.active,
);
```

`type` を指定しないと、Fuery は一致するすべてのキャッシュエントリを古い状態にし、使用中のものを再取得します。`type: QueryTypeFilter.active` を指定すると、使用中のキャッシュエントリだけを対象にします。それ以外のキャッシュエントリはデータを保持し、`staleTime` が過ぎるまで新鮮（fresh）なままです。

### 1 人のユーザーのキーを消去する

プレフィックスだけでは足りない場合は、`predicate` がキー全体を読み取ります。

```dart
client.removeQueries(
  predicate: (query) => query.queryKey.contains(userId),
);
```

`predicate` はキャッシュエントリ（`CachedQuery`）を受け取ります。そのため、`query.state` や `query.options` も判定できます。たとえば、取得に失敗したすべてのキャッシュエントリを削除できます。

## キャッシュを監視する

`client.watch` は、クライアントから計算した任意の値を `Stream` に変換します。たとえば、取得中のクエリがある間、ローディングバーを表示できます。

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos']) > 0); // saving
client.watch((client) => client.getQueryData<List<Todo>>(['todos'])); // cached data
```

- 各リスナーは、まず現在の値を受け取ります。その後、クエリキャッシュかミューテーションキャッシュが変わるたびに、新しい値を受け取ります。
- Fuery は[セレクター](../widgets/#状態の一部を選択する)と同じ方法で値を比較します。そのため、値が前と等しいときは何も流しません。
- 監視するだけでは何も取得しません。

ストリームは `State` のフィールドなどで 1 回だけ作成し、`StreamBuilder` で表示してください。

```dart
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key});

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar> {
  late final fetching = context.queryClient.watch(
    (client) => client.isFetching() > 0,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: fetching,
      builder: (context, snapshot) => snapshot.data == true
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
```

Bloc では、ほかのストリームと同じようにリッスンしてください。

ミューテーションが実行中かどうかを表示するのに、ウィジェットではストリームは不要です。[`MutationStateSelector`](../mutations/#ミューテーションのすべての実行を表示する) で表示でき、`HookWidget` では `useMutationState` でも表示できます。

## ウィジェットの外で取得する

`client.query` は、キャッシュされたデータが新鮮な間はそのデータを返し、そうでなければ取得します。ルートガード、起動時のコード、事前取得で使います。

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

- データは、クエリの `staleTime` の間は新鮮です。デフォルトのゼロのままだと、`client.query` は毎回取得します。
- 取得が必要な呼び出しは、そのキーの取得がすでに実行中なら、新しく取得を始めずにその取得を待ちます。
- 取得が失敗すると、`client.query` はエラーをスローします。
- 再試行するのは、クエリ、`defaultOptions`、またはそのキーに対する `setQueryDefaults` の呼び出しが `retry` を設定している場合だけです。

どれほど古くても、キャッシュされているデータを使うには、`staleTime: staticStaleTime` を設定してください。すると、`client.query` は何もキャッシュされていないときだけ取得します。

## ウィジェットの外で無限クエリを取得する

`client.infiniteQuery` は、[無限クエリ](../infinite-queries/)に対して同じことをします。

```dart
InfiniteQuery<TodoPage, int> pagedTodosQuery() => InfiniteQuery(
      queryKey: ['todos', 'paged'],
      queryFn: (context) => api.getPage(context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
      pages: 3,
    );

await client.infiniteQuery(pagedTodosQuery());
```

- `pages` は、何もキャッシュされていないときに 1 回の取得で読み込むページ数を設定します。デフォルトは 1 ページで、`maxPages` を超えることはありません。
- `pages` は定義に属します。そのため、このクエリを表示するウィジェットも、最初に 3 ページを読み込みます。
- ページがキャッシュされている場合、取得はキャッシュされたページを最初から `maxPages` まで読み込み直し、`pages` を無視します。

## ログアウト時にすべてを消去する

```dart
Future<void> logout() async {
  await api.logout();
  Fuery.client.clear();
}
```

`clear()` は、すべてのキャッシュエントリとミューテーションのすべての実行を削除し、[永続化されたデータ](../persistence/#保存されたデータを削除する)もすべて削除します。クライアントは残り、`setQueryDefaults` と `setMutationDefaults` で登録したデフォルトもそのまま残ります。

実行中のミューテーションがどうなるかは、その段階によって異なります。

- すでにリクエストを送信しているミューテーションは、そのまま完了します。
- ネットワークやスコープ内の順番をまだ待っているミューテーションは、`CancelledError` で失敗します。`mutateAsync` はこのエラーをスローし、ミューテーションの状態もこのエラーを示します。Fuery はそのコールバックを 1 つも実行しません。`MutationCacheConfig` のコールバックと、`mutate` 呼び出しのコールバックも実行しません。そのため、ロールバックが古いセッションのデータを書き戻すことはありません。

クエリを使う画面がなくなってから消去してください。`clear()` や `removeQueries` の実行時にまだ購読しているオブザーバーは、同じキーの新しいキャッシュエントリに移ります。このキャッシュエントリは、新しく作られたものと同じように読み込みます。そのため、まだ画面に表示されているリストは、ログアウトしたセッションですぐに再取得します。先にログイン画面に遷移し、手動で購読したオブザーバーの購読を解除してください。

## サンプルアプリでは

サンプルアプリは、[フィード](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)でポインターが投稿のカードにホバーしたときに、その投稿を事前取得します。また、[ホームシェル](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)でクライアントを監視し、アクティビティインジケーターを表示します。各画面で何を示しているかは、サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) にまとめています。
