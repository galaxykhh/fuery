---
title: ウィジェット
description: Flutter で、キャッシュにあるクエリとミューテーションを、ビルダー、リスナー、コンシューマー、セレクターの各ウィジェットで表示します。
sourceHash: cfe54efd8edf
---

Fuery のウィジェットは、クエリとミューテーションをウィジェットツリーの中で描画します。そのため、サーバーデータを表示する画面も `StatelessWidget` のままです。ウィジェットは、ソースと役割で選んでください。

| | UI をリビルド | 副作用 | 両方 | 状態の一部 |
|---|---|---|---|---|
| クエリ | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| 無限クエリ | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| ミューテーション | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| 複数のクエリ | `QueriesBuilder` | | | `QueriesSelector` |
| ミューテーションのすべての実行 | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

クエリ、無限クエリ、ミューテーションのウィジェットは、定義（`Query`、`InfiniteQuery`、`Mutation`）を受け取ります。定義は、`build` の中も含め、どこで作ってもかまいません。ウィジェットは、マウントされている間、定義の[オブザーバー](../../how-the-cache-works/#オブザーバー)を 1 つ保持します。

```dart
QueryBuilder(
  query: todoQuery(id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

- マウントすると購読します。クエリはデータがなければ取得し、デフォルトではデータが古い場合も取得します。`enabled: false` のクエリは、マウント時に取得しません。アンマウントすると購読を解除します。
- 別のキーの定義でウィジェットがリビルドされると、オブザーバーもそのキーに切り替わります。新しいキーのキャッシュされたデータは、同じフレームで表示されます。
- オブザーバーは、最も近い `FueryProvider` のクライアントを使います。`FueryProvider` がなければ `Fuery.client` を使います。
- 結果にはアクションが含まれます。`state.refetch()`、無限クエリの `state.fetchNextPage()` と `state.fetchPreviousPage()`、ミューテーションの `state.mutate(...)`、`state.mutateAsync(...)`、`state.reset()` です。

`MutationBuilder` は、自身が開始した実行だけを表示します。MutationState ウィジェットは、`mutationKey` で見つけたミューテーションの実行を、どこで開始されたものでも表示します。[ミューテーションのすべての実行を表示する](../mutations/#ミューテーションのすべての実行を表示する)を参照してください。`addTodo.mutate('Buy milk', context.queryClient)` のように定義からミューテーションを実行するボタンには、`MutationBuilder` は必要ありません。[ミューテーションを実行する](../mutations/#ミューテーションを実行する)を参照してください。

## ビルダーとリスナーが実行されるタイミング

- `buildWhen(previous, current)` は、最後にビルドした結果と新しい結果を比較します。
- `listenWhen(previous, current)` は、前の結果と新しい結果を比較します。
- リスナーは、変更の後のマイクロタスクで実行されます。ビルド中に実行されることはありません。
- リスナーがマウントされた時点でクエリがすでに持っている結果については、リスナーは呼び出されません。
- コンシューマーのリスナーは、変更を表示するリビルドの前に実行されます。
- リスナーがエラーをスローしても、リビルドは止まりません。Fuery はそのエラーを [`onUncaughtError`](../client-setup/#コールバックがスローしたエラーをキャッチする) に報告します。

## 変わった部分だけをリビルドする

`buildWhen` は、ビルダーが表示しない変更によるリビルドをスキップします。次のビルダーは、クエリの再取得中にプログレスバーだけを表示します。

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## 状態の一部を選択する

セレクターは、結果の 1 つの値からビルドし、その値が変わったときだけリビルドします。

```dart
QuerySelector(
  query: todosQuery,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Fuery は、リスト、マップ、セットを内容で比較し、それ以外を `==` で比較します。呼び出すたびに新しいリストを返すセレクターでも、ビルダーをリビルドするのは項目が変わったときだけです。
- セレクターは親がリビルドすると再び実行されるので、親の値を読み取れます。
- ビルダーが結果全体を必要とする場合は、`buildWhen` を使ってください。結果から導いた 1 つの値だけが必要な場合は、セレクターを使ってください。

`MutationStateSelector` は、ミューテーションの実行について同じことをします。次の例は、どの画面から開始されたかにかかわらず、進行中の保存を数えます。

```dart
MutationStateSelector(
  mutation: saveTodo,
  selector: (runs) => runs.where((run) => run.isPending).length,
  builder: (context, saving) =>
      Text(saving > 0 ? 'Saving $saving…' : 'All changes saved'),
)
```

## 変更に反応する

画面遷移、スナックバー、そのほかの 1 回きりの処理には、リスナーを使ってください。

```dart
QueryListener(
  query: todosQuery,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoScreen(),
)
```

ミューテーションの場合は次のとおりです。

- `MutationStateListener` は、どの画面からのものでも、ミューテーションのすべての実行をリッスンします。[ミューテーションの失敗をユーザーに伝える](../mutations/#ミューテーションの失敗をユーザーに伝える)を参照してください。
- 画面自身の呼び出しが成功した後に画面を閉じるには、`mutateAsync` を await してから `context.mounted` を確認してください。[1 回の呼び出しが成功した後に処理する](../mutations/#1-回の呼び出しが成功した後に処理する)を参照してください。
- `MutationListener` は、受け取ったオブザーバーの実行だけをリッスンします。定義を渡すと何もリッスンせず、デバッグビルドでは警告を出力します。[MutationListener が反応しない](../../troubleshooting/#mutationlistener-が反応しない)を参照してください。
- 定義を渡した `MutationConsumer` は、自身のビルダーが開始した実行をリッスンします。

## 引っ張って更新

`state.refetch()` は `Future<QueryResult>` を返します。この Future は、取得が完了した時点で完了します。`RefreshIndicator` は、その Future を待ちます。

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => RefreshIndicator(
        onRefresh: () => state.refetch(),
        child: ListView(
          children: [for (final todo in data) TodoTile(todo)],
        ),
      ),
    QueryResult(:final error?) => Center(child: Text('$error')),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `refetch()` は、取得が失敗してもスローせず、失敗を結果で知らせます。そのため、インジケーターは必ず閉じます。スローさせるには、`throwOnError: true` を渡してください。
- クエリにデータがある場合、`refetch()` は実行中の取得をキャンセルし、新しい取得を開始します。代わりに実行中の取得を待つには、`cancelRefetch: false` を渡してください。データのないクエリは、常に実行中の取得を待ちます。
- データの分岐だけを包んでください。このジェスチャーにはスクロール可能なウィジェットが必要ですが、pending の分岐とエラーの分岐にはありません。

画面のすべてのクエリを更新するには、クライアントを呼び出してください。

```dart
RefreshIndicator(
  onRefresh: () => context.queryClient.invalidateQueries(queryKey: ['todos']),
  child: const TodoList(),
)
```

- [`invalidateQueries`](../query-client/#無効化する) は、`['todos']` の配下にあるすべてのクエリを古い状態にします。そのうえで、マウントされたウィジェットなど、オブザーバーがあるクエリを再取得します。
- `refetchQueries` は、何も古い状態にせずに再取得します。`type` のデフォルトは `QueryTypeFilter.all` で、オブザーバーのないキャッシュエントリも再取得します。オブザーバーがあるキャッシュエントリだけを再取得するには、`type: QueryTypeFilter.active` を渡してください。
- どちらも、一致するすべての取得が完了した時点で完了し、`throwOnError: true` のときだけスローします。どちらも、デバイスがオフラインの間に一時停止した取得は待ちません。そのため、インジケーターが止まったままになることはありません。

どちらも受け取るフィルターの一覧は[クエリフィルター](../../reference/query-client/#クエリフィルター)にあります。

## エラーの後に再試行する

エラーの分岐に、`state.refetch()` を呼び出すボタンを置いてください。

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => TodoList(data),
    QueryResult(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            FilledButton(
              onPressed: state.isFetching ? null : () => state.refetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `state.isFetching` の間は、ボタンを無効にしてください。そうすれば、実行中の取得にタップが重なりません。
- データの分岐を先頭に置いてください。再取得が失敗してもデータは残るので、リストは画面に表示されたままで、`isRefetchError` は true です。その失敗は、画面を置き換えずに、`QueryListener` とスナックバーで知らせてください。
- デフォルトでは、エラーの分岐がビルドされる前に、クエリは 1 秒、2 秒、4 秒と待ちながら 3 回再試行します。[再試行するエラーを選ぶ](../queries/#再試行するエラーを選ぶ)で、再試行するエラーを絞り込めます。

## 複数のクエリをまとめて表示する

`QueriesBuilder` は、ID ごとのクエリなど、同じデータ型のクエリのリストの結果からビルドします。

```dart
QueriesBuilder(
  queries: [for (final id in cartIds) productQuery(id)],
  builder: (context, results) {
    if (results.any((result) => !result.hasData)) {
      return const CircularProgressIndicator();
    }
    final total = results.fold(0.0, (sum, result) => sum + result.data!.price);
    return Text('Total: $total');
  },
)
```

- 結果は、クエリの順に並びます。
- リストは `build` の中で作ってください。各クエリは、キーがリストにある間、リストが並べ替えられてもオブザーバーを保持します。
- リストから外れたキーは、オブザーバーを手放します。
- 同時に変わった結果は、1 回のリビルドにまとまります。
- `QueriesBuilder` をビルドするウィジェットがリビルドするたびに、ID が変わっていなくても、リストのすべてのクエリが更新されます。クエリが数百ある場合は、テキストフィールドの状態など、頻繁に変わる状態を別のウィジェットに置いてください。そうすれば、`QueriesBuilder` をビルドするウィジェットは、ID が変わったときだけリビルドします。

`QueriesSelector` は、結果を組み合わせた 1 つの値からビルドし、その値が変わったときだけリビルドします。

```dart
QueriesSelector(
  queries: [for (final id in ids) todoQuery(id)],
  selector: (results) =>
      results.where((result) => result.data?.done ?? false).length,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

リストの各項目が独立している場合は、`ListView.builder` のように、項目ごとに `QueryBuilder` を用意してください。そうすれば、各項目は自身のクエリが変わったときだけリビルドします。データ型の異なるクエリには、`QueryBuilder` を入れ子にしてください。

## 何かを取得中であることを表示する

アプリのすべてのクエリを追うバーは、ウィジェットではなくクライアントを読み取ります。[キャッシュを監視する](../query-client/#キャッシュを監視する)を参照してください。

ミューテーションの場合は、`MutationFilters` を渡した `MutationStateSelector` で、実行中のミューテーションがあるかどうかを表示します。

```dart
MutationStateSelector(
  mutation: const MutationFilters(),
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, saving) => saving ? const Text('Saving…') : const SizedBox(),
)
```

## オブザーバーを渡す

ほとんどの画面は定義を渡します。同じキーの定義を渡したウィジェットは、すでにキャッシュエントリとリクエストを共有しています。[クエリを使う](../queries/#クエリを使う)を参照してください。

クエリ、無限クエリ、ミューテーションのウィジェットと、`QueriesBuilder`、`QueriesSelector` は、`observe()` で作ったオブザーバーも受け取ります。これらのウィジェットは、オブザーバーのオプションと作成時のクライアントをそのまま使います。オブザーバーを渡すのは、Cubit とウィジェットが同じハンドルを共有する場合か、複数のウィジェットが 1 つのミューテーションのオブザーバーの実行だけを表示する場合に限ってください。

オブザーバーは、Cubit や `State` のフィールドなど、`build` の外で 1 回だけ作ってください。`observe()` は呼び出すたびに新しいオブザーバーを作り、そのオブザーバーが改めて購読して取得します。`State` のフィールド、クライアント、`dispose` での `reset()` は、[1 つのオブザーバーを共有する](../mutations/#1-つのオブザーバーを共有する)で紹介しています。

## オブザーバーを破棄する

クエリのオブザーバーは、破棄する必要がありません。`dispose` で処理が必要なのは、保持しているミューテーションのオブザーバーだけです。

- クエリの定義を渡したウィジェットは、マウント時にオブザーバーを作り、アンマウント時に破棄します。
- `observe()` で作ったオブザーバーは、最初のリスナーが付いたときにクエリを購読します。そのオブザーバーを使う最後のウィジェットなど、最後のリスナーが離れると、オブザーバーは古くなるまでのタイマーと再取得のタイマーをキャンセルし、クエリから離れます。
- 同じオブザーバーで後からマウントしたウィジェットは、オブザーバーに再び購読させます。そのため、クエリのオブザーバーを保持する `State` のフィールドは、`dispose` で何もする必要がありません。
- `stream` をリッスンする Cubit は、`close()` で購読をキャンセルします。購読をキャンセルすると、同じように購読が解除されます。[Cubit で使う](../bloc/#cubit-で使う)を参照してください。

保持しているミューテーションのオブザーバーは、ウィジェットがなくなった後も、最新の呼び出しの `MutateOptions` のコールバックを実行します。`dispose` でオブザーバーの `reset()` を呼び出すか、`State` やその `BuildContext` を使うコールバックで `mounted` を確認してください。ミューテーションを定義として渡したウィジェットは、アンマウント時に自身のオブザーバーをリセットします。

最後のオブザーバーが離れた後も、キャッシュエントリは `gcTime`（デフォルトは 5 分）の間残ります。そのため、戻ってきた画面はデータをすぐに表示します。

`QueryObserver.destroy()` は、すべてのリスナーを一度に削除します。最後の購読解除と同じく、オブザーバーのタイマーをキャンセルし、オブザーバーをクエリから切り離します。ウィジェットツリーの中では必要ありません。長く存在するオブジェクトが、リスナーに手の届かないオブザーバーを止める必要がある場合に呼び出してください。

## 独自のウィジェットやアダプターを作る

フックには [`fuery_hooks`](../hooks/) を使ってください。独自のウィジェットやほかの状態管理ライブラリについては、[アダプターを作る](../adapters/)を参照してください。このページでは、これらのウィジェットと同じ `fuery_core` の公開 API で、クエリを描画する方法を紹介しています。

## サンプルアプリでは

サンプルアプリの[フィード](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)には、再取得インジケーターのための `buildWhen`、再試行ボタン付きの引っ張って更新、スナックバーのための `MutationStateListener` があります。サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) に、各画面で示している内容の一覧があります。
