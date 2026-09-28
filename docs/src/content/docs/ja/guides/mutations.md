---
title: ミューテーション
description: Flutter でサーバーデータを作成、更新、削除します。楽観的更新とロールバックも扱います。
sourceHash: 0c544eeebc13
head:
  - tag: title
    content: Flutter のミューテーションと楽観的更新 | Fuery
---

ミューテーションは、新しい Todo など、変更をサーバーに送ります。ミューテーションはボタンから実行できます。進行状況はどの画面にも表示でき、失敗したときはユーザーに伝えられます。サーバーが応答する前に、キャッシュを更新することもできます。

次のミューテーションは Todo を追加します。

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

上の `String title` のように `mutationFn` のパラメーターに型を付けると、Dart はほかの型をそこから推論します。`mutationKey` があれば、どのウィジェットでもミューテーションの実行を見つけられます。1 回の `mutate` 呼び出しが 1 つの実行です（[ミューテーションの実行](../../how-the-cache-works/#ミューテーションの実行)）。すべてのオプションの一覧は[ミューテーションのオプション](../../reference/mutation-options/)にあります。

## ミューテーションを実行する

定義の `mutate` を呼び出し、`context.queryClient` を渡してください。この方法なら、`StatelessWidget` も含め、どのウィジェットでもミューテーションを実行できます。

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

- `mutate` は実行を開始し、すぐに戻ります。実行が失敗すると、エラーは呼び出し元には届かず、実行の状態とコールバックに届きます。
- 定義は状態を持ちません。実行はウィジェットではなく、クライアントのキャッシュに属します。そのため、ボタンが画面からなくなっても実行は続きます。
- `context.queryClient` は、ウィジェットが使うクライアントです。最も近い `FueryProvider` のクライアント、`FueryProvider` がなければ `Fuery.client` です。このクライアントを渡すと、[MutationState ウィジェット](#ミューテーションのすべての実行を表示する)が読み取るキャッシュに実行が入ります。
- クライアントを渡さない場合、実行は `Fuery.client` を使います。[Cubit](../bloc/#cubit-や-bloc-からのミューテーション) など、`BuildContext` のないコードは、この方法でミューテーションを実行します。

## ミューテーションのすべての実行を表示する

MutationState ウィジェットは、ミューテーションの実行をどの画面にでも表示します。定義の `mutationKey` で実行を見つけるので、各実行がどこで開始されたかは問いません。開始元は、定義の `mutate`、`MutationBuilder`、`useMutation`、Cubit、[`restore(mutations:)`](../persistence/#ミューテーションを永続化する) のどれでもかまいません。`StatelessWidget` の中でも動作します。

| ウィジェット | ビルド元、またはリッスンする対象 |
|---|---|
| `MutationStateBuilder` | すべての実行の `MutationState`（開始順） |
| `MutationStateSelector` | それらの状態から選択した値。値が変わったときだけリビルドします。 |
| `MutationStateListener` | 各実行の各変更（副作用のため） |

先ほどのボタンを、Todo の追加中は無効にした例です。

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

サーバーへ送信中のタイトルを表示する例です。タイトルは、定義の変数と同じく `String` 型です。

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

### 一致する実行

- `Mutation` を渡すと、ウィジェットは `mutationKey` が完全に一致する実行を、定義と同じ型で表示します。
- 同じキーと型を持つ別の定義の実行も対象になります。
- 同じキーで型が異なる実行は除外され、[`onUncaughtError`](../client-setup/#コールバックがスローしたエラーをキャッチする) に 1 回だけ報告されます。定義ごとに固有のキーを付けてください。
- `mutationKey` のない定義は、デバッグビルドでアサートに失敗します。
- `MutationFilters` を渡すと、ウィジェットは、フィルターに一致するすべてのミューテーションの実行を表示します。一致の判定は `client.mutationCache.findAll` と同じで、キーのプレフィックス、`exact` による完全一致、`status`、`predicate` で絞り込みます。状態の型は `Object?` です。
- `status` フィルターがない場合、完了した実行も一致します。

### 実行の順序と保持期間

- 実行は開始順に並ぶので、`runs.lastOrNull` が最新の実行です。
- 実行は、完了後も `gcTime`（デフォルトは 5 分）の間残ります。そのため、インジケーターは実行の数ではなく `isPending` からビルドしてください。
- マウントされた `MutationBuilder` は、最新の実行を表示している間、その実行を保持します。
- `client.clear()` は、すべての実行を削除します。

### クライアントとコスト

- 対象になるのは、ウィジェットのクライアントの実行だけです。ウィジェットのクライアントは、最も近い `FueryProvider` のクライアント、または `Fuery.client` です。
- これらのウィジェットは読み取るだけです。ミューテーションを実行することはなく、定義のオプションも適用しません。そのため、`build` の中で定義を作ってもコストはかかりません。

## ミューテーションの失敗をユーザーに伝える

失敗した `mutate` は、エラーをスローせずに実行の状態に入れます。`MutationStateListener` は、どの画面からのものでも、ミューテーションのすべての実行をリッスンし、各実行の新しい状態を受け取ります。

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

- Fuery は、変わった実行ごとにリスナーを 1 回呼び出します。そのため、2 つの実行が失敗すると、2 回呼び出します。
- `listenWhen` は、その実行の前の状態と新しい状態を比較します。
- マウントした時点で実行がすでに持っていた状態や、キャッシュが削除した実行については、リスナーは呼び出されません。
- 復元された実行や、ほかの画面からの実行もリッスンします。そのため、メッセージを表示すべき場所に 1 つだけマウントしてください。

`MutationListener` は、受け取ったオブザーバーの実行だけをリッスンします。定義を渡すと、どこからも実行されない独自のオブザーバーを作るので、何もリッスンしません。デバッグビルドでは、警告も出力します。[MutationListener が反応しない](../../troubleshooting/#mutationlistener-が反応しない)を参照してください。

## 1 回の呼び出しが成功した後に処理する

`mutateAsync` は、実行が成功するとデータを返し、失敗するとエラーをスローします。保存したフォームを閉じるなど、1 回の呼び出しに対する処理には、`mutateAsync` を await してください。

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

- `await` の後で `context.mounted` を確認してください。実行が pending の間に、ユーザーが画面を離れることがあります。
- エラーはキャッチしてください。どこでもキャッチしないエラーは、キャッチされないエラーとしてゾーンに届きます。

## ウィジェットが開始した実行だけを表示する

`MutationBuilder` は独自のオブザーバーを保持し、自身が開始した実行だけを表示します。複数のフォームそれぞれにある保存ボタンなど、ウィジェットの状態から、ほかの場所で開始された実行を除く必要がある場合に使ってください。

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => FilledButton(
    onPressed: state.isPending ? null : () => state.mutate('Buy milk'),
    child: Text(state.isPending ? 'Adding…' : 'Add'),
  ),
)
```

- `state.mutate('Buy milk')` は、このウィジェット経由で実行を開始します。`await state.mutateAsync('Buy milk')` はデータを返し、エラーのときはスローします。
- `state` は、このウィジェットが開始した最新の実行を表します。`addTodo.mutate` やほかのウィジェットで開始した実行は、`state` に表れません。
- `state.reset()` は、状態を idle に戻します。
- ウィジェットは、最も近い `FueryProvider` のクライアントを使います。`FueryProvider` がなければ `Fuery.client` を使います。
- `HookWidget` では、`useMutation(addTodo)` が同じ結果を返します。[フック](../hooks/#ウィジェットが開始した実行だけを表示する)を参照してください。

`state` のすべてのメンバーとフィールドの一覧は[ミューテーションの結果](../../reference/mutation-results/#mutationresult)にあります。

このウィジェットの 1 回の呼び出しに反応するには、`state.mutate` に `MutateOptions` を渡してください。`MutateOptions` のコールバックは、呼び出しが完了した後、ミューテーション自身のコールバックの次に実行されます。

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

- 同じオブザーバーで後から `mutate` を呼び出すと、コールバックは置き換わります。実行されるのは、最新の呼び出しのコールバックだけです。
- `reset()` は、コールバックを破棄します。ウィジェットをアンマウントしたときも破棄します。
- [共有したオブザーバー](#1-つのオブザーバーを共有する)は、ウィジェットがリッスンしているかどうかにかかわらず、コールバックを実行します。コールバックで `BuildContext` を使う前に、`context.mounted` を確認してください。

## コールバック

`onMutate` は `mutationFn` の前に実行されます。`onSuccess`、`onError`、`onSettled` は `mutationFn` の後に実行されます。引数と実行順の一覧は[コールバック](../../reference/mutation-options/#コールバック)にあります。

- 最後の引数 `client` は、ミューテーションを実行しているクライアントです。定義の `mutate` に渡したクライアント、ウィジェットが `FueryProvider` から受け取ったクライアント、または `observe(client:)` に渡したクライアントです。`Fuery.client` の代わりにこの `client` を使ってください。そうすれば、テストでもコールバックが正しいキャッシュに届きます。
- `onMutate`、`onSuccess`、`onError`、`onSettled` が Future を返すと、その Future が完了するまで実行は pending のままです。Fuery は `MutateOptions` のコールバックを await しません。上の `addTodo` は `onSuccess` から `invalidateQueries` の Future を返します。そのため、リストの再取得が終わるまで、ボタンは *Adding…* と表示します。

## 楽観的更新

楽観的更新は、サーバーが応答する前にキャッシュを変更します。そのため、画面がすぐに反応します。

1. `onMutate` で、クエリの再取得をキャンセルします。そうすれば、どの再取得も更新を上書きしません。
2. 同じ `onMutate` で新しいデータを書き込み、以前のデータを返します。ほかのコールバックは、以前のデータを `context` として受け取ります。
3. `onError` で、以前のデータを書き戻します。
4. `onSettled` でクエリを無効化し、サーバーにあるデータを再取得します。

`todosQuery` と `todosKey` は、クエリとその[キー](../organizing-queries/)です。

```dart
final deleteTodo = Mutation(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id, client) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await client.cancelQueries(queryKey: todosKey);
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
  onSettled: (_, __, ___, ____, client) {
    return client.invalidateQueries(queryKey: todosKey);
  },
);
```

[プレイグラウンドで試す](/fuery/demo/#/optimistic)：Todo を追加し、リクエストを失敗させてロールバックを確認してください。

## 変数のないミューテーション

ログアウトなど、何も受け取らないミューテーションには、`NoVariablesMutation` を使ってください。`mutationFn` とコールバックは変数を受け取りません（[NoVariablesMutation](../../reference/mutation-options/#novariablesmutation)）。

```dart
final logoutMutation = NoVariablesMutation(
  mutationFn: () => api.logout(),
);
```

`logoutMutation.mutate()` で実行するので、ボタンには tear-off を渡せます（`onPressed: logoutMutation.mutate`）。`logoutMutation.mutateAsync()` はデータを返します。

- `Fuery.client` 以外のクライアントで実行するときは、最初に変数として `null` を渡してください（`logoutMutation.mutate(null, context.queryClient)`）。
- `MutationBuilder` や `useMutation` の結果は変数が `void` なので、`state.mutate(null)` でミューテーションを実行します。1 回の呼び出しのコールバックには変数の引数が残り、その値は `null` です。
- `observe()` で作ったオブザーバー（`NoVariablesMutationObserver`）は、`mutate()` で実行します。

ログアウトした後は、キャッシュを使っていた画面からアプリが離れてから、キャッシュを空にしてください。この順序が重要な理由は、[ログアウト時にすべてを消去する](../query-client/#ログアウト時にすべてを消去する)で説明しています。

## 再試行と実行の順序

書き込みを繰り返すのは常に安全とは限りません。そのため、ミューテーションは `retry` を設定したときだけ再試行します。`RetryPolicy.count(2)` は、1 秒、2 秒の間隔で、あと 2 回の試行を許可します。同じ `scope` を共有するミューテーションは、開始した順に 1 つずつ実行されます。

```dart
final saveDraft = Mutation(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

スコープで順番を待っている実行は、`isPaused` を示します。ネットワークを待っている実行も同じです。待っている実行を再起動の後も残すには、ミューテーションに `persist` を指定してください（[ミューテーションを永続化する](../persistence/#ミューテーションを永続化する)）。

## 1 つのオブザーバーを共有する

定義の `mutate` と MutationState ウィジェットには、独自のオブザーバーは必要ありません。Cubit も、定義からミューテーションを実行します（[Cubit や Bloc からのミューテーション](../bloc/#cubit-や-bloc-からのミューテーション)）。オブザーバーを共有するのは、複数のウィジェットが 1 つの画面の実行だけを追う必要がある場合に限ってください。

`addTodo.observe()` は `MutationObserver` を返します。そのオブザーバーを渡したウィジェットはすべて、オブザーバーをそのまま使います。次の例では、この画面のフォームが保存している間、アプリバーにプログレスバーを表示します。`MutationStateSelector` を使うと、ほかの画面が開始した実行も表示されます。

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

画面自身の呼び出しが成功した後に画面を閉じるには、共有したオブザーバーは必要ありません。`mutateAsync` を await してください（[1 回の呼び出しが成功した後に処理する](#1-回の呼び出しが成功した後に処理する)）。

- オブザーバーは、`State` のフィールドか Cubit で 1 回だけ作ってください。`build` の中の `observe()` は、リビルドのたびに idle の新しいオブザーバーを返します。
- `observe()` は、`client:` を渡さない限り `Fuery.client` を使います。独自のクライアントを持つ `FueryProvider` の下では、上の例のように `context.queryClient` を渡してください。
- `dispose` で `reset()` を呼び出してください。`reset()` は、最新の `mutate` 呼び出しのコールバックを破棄します。そのコールバックは、この画面に属するものです。定義を渡したウィジェットは、アンマウント時に自身のオブザーバーをリセットします。
- オブザーバーを渡した `MutationListener`、`MutationSelector`、`MutationBuilder` は、そのオブザーバーが開始するすべての実行をリッスンします。どこから呼び出されたかは問いません。

## サンプルアプリでは

- [フィードのミューテーション](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)には、ロールバック付きの楽観的な「いいね」と、オフラインの間は一時停止するコメントがあります。
- [フィード](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)は、各「いいね」を定義から実行し、失敗したすべての「いいね」を `MutationStateListener` で報告します。
- [投稿画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)は、定義からコメントを送信し、送信中のコメントを `MutationStateBuilder` で一覧表示します。
- [投稿作成画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)は、`MutationBuilder` から新しい投稿を実行します。そのボタンは、自身の実行だけを表示します。

サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) に、各画面で示している内容の一覧があります。
