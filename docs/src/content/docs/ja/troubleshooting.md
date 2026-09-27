---
title: トラブルシューティング
description: Flutter で Fuery を使うときに起きるエラーや予想外の動作と、その原因と解決方法を説明します。
sourceHash: 9cc86044231d
---

Flutter で Fuery を使うときに起こりうるエラーや予想外の動作の解決方法を、分野ごとにまとめています。各見出しは、実際に目にする症状を表しています。

## 型とコンパイルエラー

### StateError: Query holds X, but was requested as Y

キーを読み書きすると、このエラーがスローされます。キーが保持するデータ型と、コードが使った型が異なります。

```dart
client.setQueryData(['todos'], []); // StateError: the list has no type
```

Dart は空のリストの型を、クエリが保持する `List<Todo>` ではなく `List<dynamic>` と推論します。型を明示してください。

```dart
client.setQueryData<List<Todo>>(['todos'], []);
```

`setData` はクエリから型を受け取るので、`client.setData(todosQuery, [])` と書けばこのエラーは起きません。[クエリを整理する](../guides/organizing-queries/)を参照してください。

### データ型が Object になる

クエリの型が、モデルの型ではなく `Query<Object>` になります。Dart が、`queryFn` ではなく `keepPreviousData` などのジェネリック関数からデータ型を推論したためです。

```dart
final posts = Query(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is Query<Object>
);
```

代わりにクロージャを書いてください。

```dart
placeholderData: (previous, client) => previous,
```

`Query<List<Post>>` を返す関数の中など、型がすでに決まっている場所では、`keepPreviousData` を使ってかまいません。

### FocusManager という名前が 2 つのライブラリで定義されている

Flutter と `package:fuery/fuery.dart` をインポートしたファイルで、`FocusManager.instance.primaryFocus?.unfocus()` のように `FocusManager` を使うと、`ambiguous_import` でコンパイルに失敗します。Flutter には `FocusManager` クラスがあります。`package:fuery/fuery.dart` も、`FueryFocusManager` の非推奨のエイリアス `FocusManager` をエクスポートしています。

Flutter のフォーカスマネージャーには、クラス名を書かずにアクセスしてください。Flutter のトップレベルの `primaryFocus` はフォーカスされているノードなので、次のコードでキーボードを閉じられます。

```dart
primaryFocus?.unfocus();
```

それ以外の用途では、`WidgetsBinding.instance.focusManager` が `FocusManager.instance` と同じオブジェクトです。

または、Fuery 側の名前を隠してください。

```dart
import 'package:fuery/fuery.dart' hide FocusManager;
```

これで `FocusManager` は Flutter のクラスを指します。`FueryFocusManager` とシングルトンの `focusManager` は引き続き使えます。`package:fuery_hooks/fuery_hooks.dart` は、すでに `FocusManager` を隠しています。

## テスト

### A Timer is still pending even after the widget tree was disposed

キャッシュエントリは、ガベージコレクションのタイマーを持っています。タイマーがテストより長く残ると、`testWidgets` はこのメッセージで失敗します。各ウィジェットテストの最後に、ツリーをアンマウントしてキャッシュを空にしてください。

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

手動で購読したオブザーバーは、`clear()` の前に購読を解除してください。`clear()` は、まだ購読中のオブザーバーを新しいクエリに移し、そのクエリは再び読み込みを始めます。

`addTearDown(Fuery.client.clear)` では遅すぎます。`testWidgets` はテスト本体の後にツリーをアンマウントし、そこでタイマーが始まります。その後、ティアダウンが実行される前に、保留中のタイマーを確認します。この 2 行はテスト本体の最後に書いてください。

### 最初に実行したときだけテストが通る

単独では通るテストが、別のテストの後だと失敗します。テストのクライアントが空のままです。オブザーバーは、作成されたときのクライアントを使い続けます。`final todos = todosQuery.observe();` のようにファイルのトップレベルで作ったオブザーバーは、それを最初に使ったテストのクライアントを使い続けます。後続のテストは新しいクライアントを作りますが、そのクライアントはこのオブザーバーを一切認識しません。

代わりに、トップレベルにはクエリを置き、ウィジェットに渡してください。ウィジェットは現在のクライアントを使います。`observe()` は、Cubit の中など、オブザーバーを使う場所で呼び出してください。そうすれば、各テストが自身のクライアントのオブザーバーを得られます。[クエリが使うクライアント](../guides/client-setup/#クエリが使うクライアント)を参照してください。

### await subscription.cancel() でテストが止まる

`testWidgets` と `fakeAsync` の中では、`cancel()` が返す Future が完了しません。`await` を付けずに呼び出してください。

```dart
@override
Future<void> close() {
  _subscription.cancel(); // no await
  return super.close();
}
```

## クエリと再取得

### エラーが表示されるまで 7 秒かかる

失敗した取得は、デフォルトで 1 秒、2 秒、4 秒と待ちながら 3 回再試行します。404 のように決して成功しないエラーでも、この 7 秒間を再試行に費やします。再試行する価値のあるエラーだけを再試行してください。

```dart
retry: RetryPolicy.when(
  (failureCount, error) => failureCount < 3 && error is! NotFoundException,
),
```

[再試行するエラーを選ぶ](../guides/queries/#再試行するエラーを選ぶ)を参照してください。

### リクエストが失敗したのにクエリが成功する

クエリが失敗するのは、クエリ関数がスローしたときです。`Result` や `Either` などの結果オブジェクトを返すリポジトリは、どちらの場合も正常に戻ります。クエリ関数の中で結果を取り出し、失敗をスローしてください。[リポジトリの失敗を報告する](../guides/organizing-queries/#リポジトリの失敗を報告する)を参照してください。

### フォームに入力した内容が消える

クエリのデータを初期値にしたフォームで、バックグラウンドの再取得が戻ると、ユーザーが入力した内容が置き換わります。コントローラーの初期値は 1 回だけ設定し、フォームが開いている間はクエリを再取得しないようにしてください。

```dart
final todo = Query(
  queryKey: ['todos', 'detail', id],
  queryFn: (_) => api.getTodo(id),
  refetchOnMount: RefetchMode.never,
  refetchOnFocus: RefetchMode.never,
  refetchOnReconnect: RefetchMode.never,
);
```

保存した後にキーを無効化してください。ほかのすべての画面に変更が反映されます。

### クエリの再取得が多すぎる

古いクエリは、ウィジェットが使い始めたとき、アプリがフォアグラウンドに戻ったとき、ネットワークに再接続したときに再取得します。`staleTime` のデフォルトはゼロなので、データは届いた時点で古くなります。データが変わる頻度に合った `staleTime` をクエリに設定してください。

```dart
final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);
```

[クエリのライフサイクル](../how-the-cache-works/#クエリのライフサイクル)を参照してください。

### リビルドのたびにクエリが取得する

`QueryBuilder(query: todosQuery.observe())` のように `build` メソッドの中で `observe()` を呼び出すと、リビルドのたびに新しいオブザーバーができます。新しいオブザーバーはそれぞれ購読し、取得します。代わりに、クエリそのものを渡してください。ウィジェットがそのクエリのオブザーバーを 1 つ保持します。

```dart
QueryBuilder(query: todosQuery, builder: ...)
```

クエリのリストも同じ方法で解決します。新しいオブザーバーではなく、定義を渡してください。

```dart
QueriesBuilder(queries: [for (final id in ids) todoQuery(id)], builder: ...)
```

[フック](../guides/hooks/)では、`useQuery(todosQuery.observe())` ではなく `useQuery(todosQuery)` と書いてください。リストには `useQueries([for (final id in ids) todoQuery(id)])` と書いてください。

`MutationBuilder(mutation: saveTodo.observe())` のように `build` の中で作ったミューテーションのオブザーバーは、リビルドのたびに idle から始まります。そのため、ボタンは自分が開始したミューテーションの pending や error の状態を失います。オブザーバーが必要なときは、`State` のフィールドや Cubit の中で `observe()` を 1 回だけ呼び出し、そのオブザーバーを下に渡してください。[1 つのオブザーバーを共有する](../guides/mutations/#1-つのオブザーバーを共有する)を参照してください。

デバッグビルドでは、Fuery のウィジェットやフック（リストを受け取る形も含む）がリビルド時に同じキーとクライアントの新しいオブザーバーを受け取ると、この項目へのリンク付きの警告を出力します。警告はキーごとに 1 回です。置き換えられたプロバイダーのクライアントに対する新しいオブザーバーは想定どおりなので、何も出力しません。

### fetchNextPage が再取得をキャンセルする

`state.fetchNextPage()` は、すべてのページのバックグラウンド再取得など、すでに実行中の取得をキャンセルします。すでに次のページを読み込んでいるときと、次のページがないときはキャンセルしません。呼び出す前に `isFetching` を確認するか、`cancelRefetch: false` を渡してください。

```dart
state.fetchNextPage(cancelRefetch: false);
```

### アプリが再開しても再取得しない

Fuery のウィジェットとフックが、アプリのライフサイクルを接続します。Bloc からしかクエリを使わないアプリには、どちらもありません。起動時に次のコードを 1 回呼び出してください。

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

[アプリが再開したとき](../guides/lifecycle/#アプリが再開したとき)を参照してください。

### デバイスがオフラインでも一時停止しない

`onlineManager.setEventListener` で接続状態を報告するまで、Fuery はデバイスがオンラインだとみなします。[ネットワークに再接続したとき](../guides/lifecycle/#ネットワークに再接続したとき)を参照してください。

## ミューテーション

### 楽観的更新が元に戻る

すでに実行中だった再取得が変更の後に完了し、変更を上書きしました。`onMutate` の中で、キャッシュを変更する前に実行中の取得をキャンセルしてください。

```dart
onMutate: (id, client) async {
  await client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

### リクエストの後もミューテーションが pending のままになる

Future を返すコールバックは、その Future が完了するまでミューテーションを pending のままにします。`onSuccess: (_, __, ___, client) => client.invalidateQueries(...)` は無効化の Future を返すので、再取得が終わるまでミューテーションは pending のままです。リストの更新を待ってからスピナーを止めたい保存ボタンには、この動作が合っています。画面を待たせたくない場合は、何も返さないブロック本体を使ってください。

```dart
onSuccess: (post, _, __, client) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

[コールバック](../guides/mutations/#コールバック)を参照してください。

### MutationListener が反応しない

`MutationListener` がリスナーを一度も呼び出しません。または、状態を表示するだけの `MutationBuilder` や `MutationSelector` が、ボタンのミューテーションの実行中も idle のままです。`MutationListener`、`MutationBuilder`、`MutationSelector` は、自身のオブザーバーの実行だけを表示します。`MutationListener(mutation: addTodo)` のように定義を渡されたウィジェットは独自のオブザーバーを作りますが、そのオブザーバーで実行するものは何もありません。`addTodo.mutate` や別のウィジェットが開始した実行は、そのウィジェットには届きません。

どこで開始された実行もすべてリッスンするには、定義に `mutationKey` を付けて、`MutationStateListener` を使ってください。

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
);

MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not add: ${run.error}'))),
  child: const AddTodoForm(),
)
```

状態を表示するだけのウィジェットには、`MutationStateBuilder` か `MutationStateSelector` を使ってください。[ミューテーションのすべての実行を表示する](../guides/mutations/#ミューテーションのすべての実行を表示する)を参照してください。

保存したフォームを閉じるなど、1 回の呼び出しに対する処理には、`mutateAsync` を await してください。[1 回の呼び出しが成功した後に処理する](../guides/mutations/#1-回の呼び出しが成功した後に処理する)を参照してください。

1 つのオブザーバーの実行だけをリッスンするには、`State` のフィールドでオブザーバーを 1 回だけ作ってください。そのオブザーバーを、ミューテーションを実行するウィジェットと `MutationListener` の両方に渡してください。

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

`dispose` で必要な `reset()` を含む画面全体のコードは、[1 つのオブザーバーを共有する](../guides/mutations/#1-つのオブザーバーを共有する)で紹介しています。

`HookWidget` では、ミューテーションを実行する `useMutation` の結果を `useOnMutationChange` に渡してください。すべての実行をリッスンするには、`useOnMutationStateChange(addTodo, ...)` を呼び出してください。[変更に反応する](../guides/hooks/#変更に反応する)を参照してください。

`state.mutate` でミューテーションを自分で実行するビルダー、コンシューマー、セレクターには、定義を渡してかまいません。

デバッグビルドでは、定義を渡された `MutationListener` が、この項目へのリンク付きの警告を 1 回出力します。

### MutationStateBuilder に実行が表示されない

MutationState ウィジェットと `useMutationState` は、使っているクライアントのキャッシュから、定義の `mutationKey` で実行を探します。次の原因を確認してください。

- **定義に `mutationKey` がありません**。`mutationKey: const ['todos', 'add']` のように付けてください。デバッグビルドでは、ウィジェットがそのことを伝えるアサートに失敗します。
- **型の異なる別の定義が同じキーを使っています**。Fuery はその実行を除外し、[`onUncaughtError`](../guides/client-setup/#コールバックがスローしたエラーをキャッチする) に 1 回報告します。定義ごとに別のキーを付けてください。
- **実行が別のクライアントにあります**。`client:` なしの `observe()` で作ったオブザーバーと、クライアントを渡さずに定義の `mutate` で開始した実行は、`FueryProvider` のクライアントではなく `Fuery.client` で動きます。[画面が別のクライアントのキャッシュを読んでいる](#画面が別のクライアントのキャッシュを読んでいる)を参照してください。
- **実行がすでに削除されています**。どのオブザーバーも保持していない完了した実行は、`gcTime`（デフォルトは 5 分）の後にキャッシュから削除されます。`client.clear()` はすべての実行を削除します。

## クライアントとエラー報告

### 画面が別のクライアントのキャッシュを読んでいる

ミューテーションのコールバックがクエリを無効化しても、画面が更新されません。オブザーバーは、作成されたときのクライアントを使い続けます。`client:` なしの `observe()` は `Fuery.client` を使います。専用のクライアントを持つ `FueryProvider` の下でも、`final adding = addTodo.observe();` のような `State` のフィールドのオブザーバーは、`Fuery.client` を読み書きします。一方、周りにある、定義を受け取ったウィジェットはプロバイダーのクライアントを使います。そのため、コールバックは別のキャッシュを無効化します。

代わりに定義を渡してください。ウィジェットは自身のクライアントで定義を監視します。共有のオブザーバーが必要な場所では、ウィジェットが使うクライアントでオブザーバーを作ってください。

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

定義の `mutate` と `mutateAsync` も、クライアントを渡さない限り `Fuery.client` を使います。プロバイダーの下では、`addTodo.mutate('Buy milk', context.queryClient)` のように呼び出してください。

`HookWidget` では、`useQueryClient()` がフックの使うクライアントを返します。`observer.client` は、オブザーバーが使うクライアントを返します。

デバッグビルドでは、別のクライアントのオブザーバーを受け取った Fuery のウィジェットやフックが、この項目へのリンク付きの警告を出力します。警告は、ウィジェットまたはフックとキーの組み合わせごとに 1 回です。

### リスナーのエラーがゾーンに届かない

リスナーの中でスローされたエラーは、`runZonedGuarded` にも `PlatformDispatcher.onError` にも届きません。クライアントに `onUncaughtError` があると、Fuery はゾーンではなく `onUncaughtError` にエラーを報告します。

対象は、リスナーウィジェット、コンシューマー、フックの `listener` と、スロットの `listen` または `subscribeToRuns` に渡した関数です。この場合もリビルドは起こり、ほかのリスナーも実行されます。

コールバックがスローするほかのエラーと同じく、`onUncaughtError` からエラーを報告してください。

```dart
Fuery.client = QueryClient(
  // reportError stands for your crash reporter.
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

[コールバックがスローしたエラーをキャッチする](../guides/client-setup/#コールバックがスローしたエラーをキャッチする)を参照してください。

## 永続化と devtools

### 永続化したデータが戻らない

永続化したクエリが、再起動後にネットワークから読み込まれます。次の原因を確認してください。

- **クライアントにストレージがありません**。クエリが使われる前に、`Fuery.client = QueryClient(storage: myStorage)` のように設定してください。
- **クエリに `persist` が設定されていません**。Fuery は `persist` を設定したクエリだけを保存します。
- **保存されたデータが有効ではありません**。Fuery は、`version` がクエリと異なるデータ、デコードできないデータ、クエリの `maxAge` より古いデータを破棄します。`maxAge` のないクエリは、クライアントの `persistMaxAge`（デフォルトは 1 日）を使います。[保存されたデータが破棄される場合](../guides/persistence/#保存されたデータが破棄される場合)を参照してください。

非同期で読み取るストレージでは、データは 1、2 フレーム遅れて届きます。最初のフレームからデータを表示するには、`runApp` の前に `await Fuery.client.restore()` を実行してください。[事前に復元する](../guides/persistence/#事前に復元する)を参照してください。

### devtools のボタンがアプリを覆う

`FueryDevtools` は、右端の上下中央にボタンを置きます。ボタンは、そこにあるコンテンツの上に重なります。`buttonAlignment` でボタンを移動してください。

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerLeft,
  child: child!,
)
```
