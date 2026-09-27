---
title: クエリを整理する
description: Flutter アプリが大きくなっても、クエリキー、クエリ関数、ミューテーションを 1 か所にまとめて管理します。
sourceHash: 65a5f2f56dec
---

クエリごとに定義を 1 つにすると、キーとデータ型がすべての画面、Bloc、サービスで同じになります。定義は、呼び出す API の隣のファイルに置いてください。

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
    );
```

クエリはデータを持たないので、トップレベルの `final` で定義できます。id などの値を受け取るクエリは関数にします。

データを使うすべての場面で、同じ定義を使います。

```dart
QueryBuilder(query: todoQuery(id), builder: ...);     // in a widget
final todo = await client.query(todoQuery(id));        // fetching outside widgets
client.updateData(todoQuery(id), (todo) => todo?.copyWith(done: true));
final todos = todosQuery.observe();                   // in a cubit or a service
```

`todosQuery` のすべてのウィジェットとオブザーバーは、同じキャッシュエントリを共有します。ミューテーションは、キーを書き直さずに `todosKey` を無効化します。`InfiniteQuery` の定義も同じように使えます。

- **型が常にチェックされます**。ウィジェット、`client.query`、`getData`、`setData`、`updateData` はクエリからデータ型を受け取ります。そのため、キャストは不要で、キーに別の型を書き込むこともできません。
- **キーが一貫します**。キーを打ち間違えると、気づかないうちに 2 つ目のキャッシュエントリができます。クエリごとに定義を 1 つにすれば、このミスは起きません。
- **階層が明確になります**。`['todos', ...]` が Todo に関するすべてをまとめるので、`invalidateQueries(queryKey: ['todos'])` でリストとすべての詳細を一度に更新できます。

## クエリ関数に依存関係を渡す

クエリ関数で `BuildContext` をキャプチャしないでください。上のコードの `api` は長く生存するオブジェクトなので、安全です。

Fuery はクエリ関数をキャッシュエントリと一緒に保持し、後で再び実行します。

- アプリがフォアグラウンドに戻ったとき
- ネットワークに再接続したとき
- `refetchInterval` の周期ごと
- 何かがキーを無効化または再取得したとき

このうち一部は、クエリを作ったウィジェットがなくなり、その `BuildContext` がアンマウントされた後に実行されます。キャプチャした `State`、`TickerProvider`、`context` 経由で読み取ったものにも、同じ問題があります。

単純な値は安全です。id や検索語はキーとリクエストに含めるもので、ウィジェットがなくなっても残ります。

依存関係は、クエリのパラメーターとして渡してください。

```dart
Query<List<Todo>> todosQuery(TodoApi api) => Query(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );
```

画面は、クエリを使う場所で依存関係を解決します。

```dart
QueryBuilder(query: todosQuery(locator<TodoApi>()), builder: ...)
```

または、クエリ関数の中で依存関係を探してください。こうするとクエリはパラメーターなしのままです。

```dart
final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => locator<TodoApi>().getTodos(),
);
```

`locator` は、アプリが依存関係の解決に使うものを表します。どちらの形でも、クロージャはウィジェットに結びついたものを含みません。同じキーの 2 つのウィジェットは同じキャッシュエントリを共有するので、キーを使うすべての場所で同じ依存関係を渡してください。

すべてのクエリ関数が受け取る引数 `QueryFunctionContext` は、ウィジェットツリーのものを何も持ちません。[クエリ関数のコンテキスト](../../reference/query-options/#クエリ関数のコンテキスト)を参照してください。

## リポジトリの失敗を報告する

クエリ関数を失敗させるには、スローする必要があります。Fuery がエラー状態にするのは、スローされたエラーだけです。`Result`、`Either`、そのほかのラッパーを返す関数は、ラッパーの中身が何であっても常に成功します。その場合、クエリは次のようになります。

- `status` は `QueryStatus.success`、`error` は `null` のままです。
- `isError`、`isLoadingError`、`isRefetchError` を一度も設定しません。
- 再試行ポリシーはスローされたエラーしか見ないので、再試行しません。

クエリ関数の中で結果を取り出し、失敗をスローしてください。

```dart
Query<List<Todo>> todosQuery(TodoRepository repo) => Query(
      queryKey: todosKey,
      queryFn: (_) async => switch (await repo.getTodos()) {
        Ok(:final value) => value,
        Err(:final error) => throw error,
      },
    );
```

クエリのデータは null にできないので、返す結果がない関数もスローします。[クエリのデータは null にできない](../queries/#クエリのデータは-null-にできない)を参照してください。

## ミューテーションを整理する

ミューテーションは、クエリと同じ方法で定義し、クエリの隣に置いてください。それぞれに、変更するデータのキーから作った `mutationKey` を付けてください。

```dart
// lib/data/todo_mutations.dart
final addTodo = Mutation(
  mutationKey: [...todosKey, 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: todosKey),
);
```

`mutationKey` があると、どのウィジェット、フック、Cubit が開始した実行でも、どの画面からでもミューテーションの実行を見つけられます。`MutationStateBuilder(mutation: addTodo)` は、アプリのどこでも実行を表示します。[ミューテーションのすべての実行を表示する](../mutations/#ミューテーションのすべての実行を表示する)を参照してください。

定義は状態を持たないので、クエリと同じくトップレベルの値にできます。各実行はクライアントのキャッシュに属します。コールバックはミューテーションを実行するクライアントを受け取るので、テストでも `FueryProvider` の下でも、キャッシュの操作は正しいクライアントに届きます。実行とキャッシュエントリの違いは、[ミューテーションの実行](../../how-the-cache-works/#ミューテーションの実行)で説明しています。

無効化やロールバックなどのキャッシュの操作は、定義に書いてください。呼び出しが成功した後に画面を閉じるなど、1 つの画面に関わる処理は、呼び出し側に書いてください。

```dart
onPressed: () async {
  try {
    await addTodo.mutateAsync(title, context.queryClient);
  } catch (_) {
    return; // A MutationStateListener reports the failure.
  }
  if (context.mounted) Navigator.pop(context);
},
```

ボタン全体のコードは、[1 回の呼び出しが成功した後に処理する](../mutations/#1-回の呼び出しが成功した後に処理する)で紹介しています。

`MutationStateListener` は、ミューテーションのどの実行の後でも、どの画面からでも、その画面の `BuildContext` でスナックバーやダイアログを表示します。[ミューテーションの失敗をユーザーに伝える](../mutations/#ミューテーションの失敗をユーザーに伝える)を参照してください。

## サンプルアプリでは

サンプルアプリは、クエリを[フィードのクエリ](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)に、ミューテーションを[フィードのミューテーション](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)に定義しています。[README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) では、各画面とその画面で示している機能を対応づけています。
