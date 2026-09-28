---
title: クエリ
description: Flutter でサーバーデータを取得し、キャッシュします。クエリキー、鮮度、再試行、依存するクエリ、ポーリング、キャンセルを扱います。
sourceHash: 24ea69d0d7f9
head:
  - tag: title
    content: Flutter で API データを取得してキャッシュする | Fuery
---

クエリは、1 つのサーバーデータを記述します。記述するのは、キャッシュに使うキーと、データを取得する関数です。同じキーを表示するウィジェットはすべて、同じキャッシュエントリとリクエストを共有します。そのため、データをウィジェットツリーの下へ渡す必要はありません。

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

すべてのオプションの一覧は[クエリのオプション](../../reference/query-options/)にあります。クエリがいつ取得し、データがいつメモリから削除されるかは、[キャッシュのしくみ](../../how-the-cache-works/)で説明しています。

## クエリキー

キーは、キャッシュエントリを指すリストです。Fuery はキーを値で比較します。そのため、2 つのウィジェットでそれぞれ作った `['todos', 1]` は、1 つのキャッシュエントリと 1 つのリクエストにまとまります。

キーの要素は、一般的なものから具体的なものへ順に並べてください。たとえば `['todos']`、`['todos', 1]`、`['todos', 1, 'comments']` の順です。こうすると、`['todos']` を無効化したときに、`['todos']` で始まるすべてのキーが更新されます。

キーには `null`、`bool`、`num`、`String`、enum、`DateTime`、リスト、マップ、`toJson()` メソッドを持つオブジェクトを含められます。Fuery はキーを JSON 形式で比較します。

- `DateTime` は ISO 8601 文字列になります。
- enum は、`'Filter.done'` のように型と名前になります。
- オブジェクトは、`toJson()` が返す値になります。
- マップのキーは文字列になります。そのため、`{1: 'a'}` と `{'1': 'a'}` は同じキーです。
- マップの要素の順序は関係ありません。
- `1` と `1.0` は、モバイルとデスクトップでは別のキー、Web では同じキーです。キーの数値には `int` を使ってください。

各キーが保持するデータ型は 1 つです。キーを別の型で使うと、Fuery は `StateError` をスローします。対処法は[トラブルシューティング](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y)を参照してください。

## クエリを使う

クエリをウィジェットに渡してください。`Query` はデータを持たず、何も開始しません。そのため、`build` の中も含め、必要な場所ならどこで作ってもかまいません。

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

ウィジェットは、マウントされている間、クエリの[オブザーバー](../../how-the-cache-works/#オブザーバー)を 1 つ保持します。オブザーバーはデータを取得し、変更があるたびに結果を報告します。新しい `id` など、別のキーでウィジェットがリビルドされると、オブザーバーもそのキーに切り替わります。`state` の内容の一覧は[クエリの結果](../../reference/query-results/#queryresult-のフィールド)にあります。

ウィジェットの外、つまり Cubit、サービス、`State` のフィールドでは、`observe()` を 1 回だけ呼び出し、オブザーバーを保持してください。

```dart
final todo = todoQuery(1).observe();
todo.stream.listen((result) => print(result.data));
```

`build` の中で `observe()` を呼び出さないでください。`observe()` は呼び出すたびにオブザーバーを作り、そのオブザーバーが改めて購読して取得します。アプリが大きくなったときのクエリの置き場所は[クエリを整理する](../organizing-queries/)で紹介しています。

## クエリのデータは null にできない

Fuery は「まだデータがない」ことを `null` で表します。そのため、クエリ関数は `Future<User>` のような非 null 許容型を返します。表示するものがない場合は、空のリストなどの空の値を返すか、エラーをスローしてください。

## staleTime と鮮度

データは `staleTime`（デフォルトはゼロ）の間は新鮮（fresh）で、その後は古く（stale）なります。古いデータも画面に表示されたままです。ウィジェットやストリームがクエリを使い始めたとき、アプリがフォアグラウンドに戻ったとき、ネットワークに再接続したとき、クエリを無効化したときに、Fuery はバックグラウンドでデータを再取得します。すべての段階の一覧は[クエリのライフサイクル](../../how-the-cache-works/#クエリのライフサイクル)にあります。

`staleTime` には、サーバーに問い合わせ直さずにデータを表示してよい時間を設定してください。

- `Duration(minutes: 1)` は、取得のたびにデータを 1 分間新鮮に保ちます。その 1 分の間は、ウィジェットやストリームがクエリを使い始めても、アプリがフォアグラウンドに戻っても、ネットワークに再接続しても、Fuery は再取得しません。ただし、クエリを無効化すると再取得します。
- `infiniteDuration` は、無効化するまでデータを新鮮に保ちます。
- `staticStaleTime` は、変わることのないデータ向けです。データは古くならず、Fuery が自動で再取得することもありません。無効化した後も同じです。

2 つの画面が、異なる `staleTime` で同じキーを表示することもできます。その場合、各画面は自身の `staleTime` で鮮度を判断します。30 秒前に取得したデータがあるとき、クエリの `staleTime` が 10 秒の画面は、開いたときに再取得します。`staleTime` が 1 分の画面は、再取得せずにキャッシュされたデータを表示します。

どのウィジェットもストリームも使っていないデータは、`gcTime`（ガベージコレクション時間、デフォルトは 5 分）の間メモリに残ります。その間にもう一度開いた画面は、データをすぐに表示します。

[プレイグラウンドで試す](/fuery/demo/#/lifecycle)：`staleTime` を設定して、データが古くなり、再取得される様子を確認してください。

## 再試行するエラーを選ぶ

取得が失敗すると、デフォルトでは 1 秒、2 秒、4 秒と待ちながら 3 回再試行します。そのため、決して成功しないリクエストは、エラーの分岐にたどり着くまで約 7 秒かかります。再試行する価値のあるエラーだけを再試行してください。

```dart
Fuery.client = QueryClient(
  defaultOptions: DefaultOptions(
    queries: QueryDefaults(
      retry: RetryPolicy.when(
        (failureCount, error) => failureCount < 3 && error is! NotFoundException,
      ),
    ),
  ),
);
```

`RetryPolicy.when` では、最初の失敗の `failureCount` が 0 です。そのため、`failureCount < 3` で 3 回再試行します。一方、`QueryResult.failureCount` は失敗した試行の回数なので、最初の失敗の後は 1 です。

デフォルトは `RetryPolicy.count(3)` です。ほかの省略形として `RetryPolicy.never()` と `RetryPolicy.always()` があります。クエリごとに独自の `retry` も設定できます。`client.query` とミューテーションは、定義かデフォルトで `retry` が設定されている場合にだけ再試行します。

[プレイグラウンドで試す](/fuery/demo/#/retries)：いくつかのリクエストを失敗させ、クエリが成功するか諦めるまで `failureCount` が増えていく様子を確認してください。

## クエリが取得する内容を変える

検索フィールドやフィルターでは、ユーザーの入力に合わせてキーが変わります。検索語を状態に保持し、その検索語からクエリを作ってください。

```dart
Query<List<Todo>> searchQuery(String term) => Query(
      queryKey: ['todos', 'search', term],
      queryFn: (_) => api.searchTodos(term),
      enabled: term.isNotEmpty,
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: searchQuery(_term),
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

- `enabled: false` にすると、クエリは自動で取得しなくなります。そのため、検索語が空のときはリクエストを送りません。それでも `state.refetch()` は取得します。
- `placeholderData` は、次の検索語の結果を読み込む間、前の結果を画面に表示したままにします。[前のページを表示したままにする](#前のページを表示したままにする)を参照してください。
- 検索語ごとにキャッシュエントリがあります。そのため、前の検索語に戻ると、その結果がすぐに表示されます。

`setState` を呼び出す前に、ウィジェットの中で `Timer` を使ってデバウンスしてください。ウィジェットの外では、次のクエリをオブザーバーの `setOptions` に渡してください。

## ほかのクエリに依存するクエリ

クエリが必要とする値をもとに `enabled` を設定してください。

```dart
Query<List<Project>> projectsQuery(String? userId) => Query(
      queryKey: ['projects', userId],
      queryFn: (_) => api.getProjects(userId!),
      enabled: userId != null,
    );
```

または、1 つ目のクエリのビルダーの中で、値が得られてから 2 つ目のクエリを作ってください。

```dart
QueryBuilder(
  query: userQuery,
  builder: (context, state) => switch (state.data?.id) {
    final userId? => QueryBuilder(
        query: projectsQuery(userId),
        builder: (context, projects) => ProjectList(projects.data),
      ),
    null => const CircularProgressIndicator(),
  },
)
```

## 前のページを表示したままにする

キーが新しくなると、データが届くまで pending 状態を表示します。`placeholderData` を設定すると、代わりに前のキーのデータを表示します。

```dart
Query<List<Post>> postsQuery(int page) => Query(
      queryKey: ['posts', page],
      queryFn: (_) => api.getPosts(page),
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: postsQuery(_page),
  builder: (context, state) => PostList(state.data ?? const []),
)
```

`_page` が変わってもウィジェットは同じオブザーバーを保持するので、オブザーバーには表示できる前のページが残っています。ページごとに作ったオブザーバーには、前のページがありません。

次のページを読み込む間、`state.isPlaceholderData` は `true` です。この値を使って、リストを薄く表示したり、次へボタンを無効にしたりしてください。無限スクロールには、代わりに[無限クエリ](../infinite-queries/)を使ってください。

`keepPreviousData` には、`postsQuery` の戻り値の型など、周囲からデータ型が与えられている必要があります。Dart が型を推論する `Query(...)` では、代わりに `(previous, client) => previous` と書いてください。そこで `keepPreviousData` を使うと、Dart はデータ型を `queryFn` から取らずに `Object` と推論します。

[プレイグラウンドで試す](/fuery/demo/#/pagination)：`keepPreviousData` を使う場合と使わない場合で、リストのページを切り替えてみてください。

## スピナーなしで詳細画面を開く

詳細画面が取得する項目は、一覧画面がすでに持っています。その項目をプレースホルダーデータとして返してください。

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
      placeholderData: (previous, client) {
        if (previous != null) return previous;
        final todos = client.getData(todosQuery);
        return todos?.firstWhereOrNull((todo) => todo.id == id);
      },
    );
```

`placeholderData` はクエリを実行するクライアントを受け取るので、テストや `FueryProvider` の下でも正しいキャッシュを読み取ります。Fuery はプレースホルダーデータをキャッシュしません。取得は通常どおり実行され、完全な項目がプレースホルダーデータを置き換えます。取得したデータとしてキャッシュに入れるべき値には、代わりに `initialData` を使ってください。

## 処理が終わるまでポーリングする

`refetchInterval` は、ウィジェットやストリームがクエリを使っている間ポーリングし、アプリがバックグラウンドにある間は一時停止します。

```dart
final prices = Query(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

ジョブが終わったらポーリングを止めるには、`refetchWhile` を追加してください。Fuery は変更のたびに `refetchWhile` を確認します。`false` を返すとポーリングは止まります。クエリを無効化した後などに `true` を返すと、ポーリングが再び始まります。

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile` は最初のデータが届く前にも実行されます。そのため、`state.data` が `null` の場合も処理してください。

## 変わった部分だけをリビルドする

Fuery は、再取得したデータとキャッシュされたデータを深く比較し、変わっていないキャッシュ済みのオブジェクトをそのまま残します。

- 等しいデータは同じオブジェクトのままです。
- 変更があったリストでは、同じインデックスの項目と等しい項目が、以前のオブジェクトのままになります。項目は `==` で比較します。

そのため、`buildWhen` のようにデータを `==` で比較するコードは、何も変わっていなければ変更なしと判断します。`List` は同一性で比較しますが、次のビルダーは、再取得が同じ Todo を返したときにリビルドをスキップします。

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.data != current.data,
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

構造共有はデフォルトでオンです。データの比較にコストがかかるクエリでは、`structuralSharing: false` を設定してください。

## リクエストをキャンセルする

リクエストをキャンセルできるようにするには、クエリ関数で `context.signal` を読み取ってください。すると、どのウィジェットもストリームもクエリを使わなくなったとき、Fuery は取得をバックグラウンドで完了させずに中止します。

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

シグナルを使わない場合、リクエストは最後まで実行され、Fuery は次回のためにその結果をキャッシュします。

`context.signal` は `AbortSignal` です。複数の段階で処理するクエリ関数は、段階の間で `signal.aborted` を確認できます。`signal.throwIfAborted()` を呼び出して、キャンセルの `CancelledError` で止めることもできます。`signal.whenAborted` と自身の処理を競わせることもできます。Fuery がシグナルを中止するときは、必ずその `CancelledError` を使い、`AbortedException` は使いません。

Fuery はキャンセルを失敗として扱いません。

- デフォルトでは、[`cancelQueries`](../../reference/query-client/#再取得とキャンセルの引数) はクエリを取得前の状態に戻します。
- `CancelledError` が `QueryCacheConfig.onError` に届くことはありません。
- キャンセルされた取得が遅れて完了しても、その後に取得または書き込まれたデータを上書きすることはありません。

最新でないデータをキャッシュに入れてしまうのは、中止を無視して値を返すクエリ関数だけです。

クエリ関数自身がスローした `CancelledError` は、ほかのエラーと同じ失敗です。たとえば、`context.client.query(userQuery)` を await するクエリ関数は、`userQuery` が読み込み中に削除されたり、データを持つ前にキャンセルされたりすると、`CancelledError` をスローします。Fuery は、`CancelledError` をスローした関数のクエリを、その `retry` が許す範囲で再試行します。すべての試行が失敗すると、そのクエリは error 状態になり、`QueryCacheConfig.onError` が `CancelledError` を受け取ります。

## サンプルアプリでは

サンプルアプリは、[検索画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search/search_screen.dart)で検索中に前の結果を表示したままにします。また、[投稿作成画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)で、新しい投稿が公開されるまでポーリングします。サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) に、各画面で示している内容の一覧があります。
