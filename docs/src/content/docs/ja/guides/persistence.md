---
title: 永続化
description: 任意のキーバリューストレージを使って、Flutter アプリを再起動してもキャッシュしたサーバーデータを保持します。
sourceHash: 8e8642971351
head:
  - tag: title
    content: Flutter でのオフラインキャッシュの永続化 | Fuery
---

クエリのデータと保留中のミューテーションをデバイスに保存すると、アプリを再起動しても残ります。

- 永続化したクエリは、最後のデータをすぐに表示します。データが古い（stale）場合は、バックグラウンドで再取得します。
- アプリの終了時にネットワークを待っていた永続化済みのミューテーションは、次回の起動時にアプリが `restore(mutations:)` を呼び出すと、再び実行されます。

## ストレージを接続する

Fuery は `QueryStorage` で文字列を読み書きします。任意のキーバリューストアを使って `QueryStorage` を実装してください。次の例は [`shared_preferences`](https://pub.dev/packages/shared_preferences) を使います。

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

Fuery が書き込むキーは、すべて定数 `persistKeyPrefix` で始まります。上の例のように、`readAll` をこのプレフィックスで絞り込んでください。そうすると、`readAll` はストアから Fuery が書き込んだものだけを返します。

ストレージをクライアントに渡してください。

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

`SharedPreferencesWithCache` は同期的に読み取るので、Fuery は永続化したクエリを最初のフレームより前に復元します。データベースなどでは、ストレージのメソッドが Future を返してもかまいません。[事前に復元する](#事前に復元する)を参照してください。

## クエリを永続化する

データを JSON に変換する関数と JSON から戻す関数を持つ `persist` を追加してください。Fuery は `persist` を持つクエリだけを保存します。

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

- **変換**：`toJson` からは、`jsonEncode` が受け付ける値を返してください。エンコードできない場合、Fuery はデータを保存せず、エラーも報告しません。`fromJson` は `jsonDecode` が生成した値を受け取るので、`fromJson` の中で 1 回だけキャストしてください。上の `Todo.fromJson` は `Object?` を受け取ります。生成された `Todo.fromJson(Map<String, dynamic> json)` を使う場合は、`Todo.fromJson(item as Map<String, dynamic>)` と書いてください。
- **復元**：クエリが初めて使われたとき、Fuery は保存されたデータを取得時刻とともに復元します。その後、クエリが再取得するかどうかは `staleTime` で決まります。そのため、新鮮（fresh）なデータを再び取得することはありません。復元にネットワークは不要です。
- **保存**：データが変わり、取得が実行中でなければ、Fuery はそのたびにデータを保存します。`setData` による変更も含みます。`client.setData(todosQuery, todos)` は、まだ何もそのクエリを使っていなくても保存します。`setData` が作成するクエリが、定義の `persist` を受け継ぐからです。[ストリーミングクエリ](../streaming/)は、ストリームが終わった時点で Fuery が保存します。
- **enum を含むキー**：Fuery は、キーの中の enum を型なしで名前だけで保存します。難読化や minify をしたビルドでは、アプリのアップデートで型の名前が変わることがあります。名前だけなら、その場合も一致します。そのため、同じ名前の enum の型だけが違うキーを持つ 2 つの永続化クエリは、同じ保存先を共有します。`['todos', Filter.done]` と `['todos', Status.done]` は、互いのデータを上書きします。`['todos', 'filter', Filter.done]` のように、区別するための文字列を追加してください。

## 無限クエリを永続化する

1 ページを変換する関数を渡すと、Fuery はページのリストを保存します。

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

Fuery は、読み込んだすべてのページを 1 件のデータにまとめて保存し、ページを読み込むたびに書き直します。長いフィードの保存データが大きくなりすぎないように、`maxPages` を設定してください。

Fuery はページパラメーターをそのまま保存します。そのため、ページパラメーターは数値、文字列、`null` などの JSON の値でなければなりません。それ以外のパラメーターには、`paramToJson` と `paramFromJson` を追加してください。`paramToJson` は各パラメーターを `Object?` として受け取るので、`paramToJson: (date) => (date! as DateTime).toIso8601String()` のようにキャストしてください。

## 保存されたデータが破棄される場合

次のデータは Fuery が破棄します。クエリは、何も保存されていなかったかのように取得します。

- クエリの `maxAge` より古いデータ。`maxAge` を設定していないクエリでは、クライアントの `persistMaxAge`（デフォルトは 1 日）より古いデータ
- クエリとは異なる `version` のデータ。JSON の形式を変えたら、`version` を上げてください。
- デコードできないデータ

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

`restore()` は、期限切れになった保存済みのクエリも削除します。期限は、Fuery が保存した時点で有効だった `maxAge` で判断します。アプリが使わなくなったキーのデータは、ストレージに残りません。

## 事前に復元する

非同期で読み取るストレージでは、Fuery がデータを読み取るまで、クエリは読み込み中の状態を表示します。最初のフレームでデータを表示するには、アプリの起動前に保存されたデータをすべて読み取ってください。

```dart
await Fuery.client.restore();
runApp(const App());
```

## 保存されたデータを削除する

| 呼び出し | 保存されたデータ |
|---|---|
| `removeQueries`、`resetQueries` | 一致するクエリの分を削除します。キーだけで絞り込む呼び出しは、読み込まれていない保存済みのクエリも削除します。 |
| `clear()` | クエリとミューテーションのすべてを削除します。ユーザーのログアウト時に呼び出してください。 |
| ガベージコレクション | 残ります。メモリから削除されたクエリは、次に使われたときに復元されます。 |

## ミューテーションを永続化する

`persist` を持つミューテーションは、各実行の変数を、実行の開始から完了まで保存します。アプリの終了時にオフラインで一時停止していた実行や、まだ進行中だった実行は、次回の起動時にも保存されています。`restore(mutations:)` は、渡した定義でその実行を再び実行します。そのため、画面と `main` で同じ定義を使います。

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

パラメーターの一覧は [MutationPersist](../../reference/mutation-options/#mutationpersist) にあります。`NoVariablesMutation` は、`NoVariablesMutation(mutationKey: ['sync'], mutationFn: () => api.sync(), persist: MutationPersist.noVariables)` のように `MutationPersist.noVariables` で永続化します。

アプリの終了前にサーバーに届いていたリクエストも、再起動後に再び実行されます。永続化するのは、リクエストを繰り返しても安全なミューテーションだけにしてください。または、繰り返されたリクエストを同じ書き込みとしてサーバーが扱うようにしてください。

### 保存された実行を照合する

- `restore` は、保存された実行を `mutationKey` で定義と照合します。そのため、永続化するミューテーションには `mutationKey` が必要です。
- `mutations` は `AnyMutation` のリストです。すべての `Mutation` は `AnyMutation` なので、型の異なる定義を同じリストに入れられます。
- Fuery は `mutationKey` をクエリキーと同じ方法で保存します。そのため、キーに enum や `DateTime` を含められます。
- `toJson()` のないオブジェクトを含むキーなど、保存できないキーは、Fuery が `onUncaughtError` に 1 回だけ報告します。実行は保存されないまま続きます。
- キーの違いが enum の型だけである 2 つの定義があると、`restore` はこの問題を報告し、どちらの定義も復元しません。

### 保存された実行を復元する

- 保存された実行を戻す方法は `restore` だけです。`restore` は、各実行を保存された変数で開始します。オンラインならすぐに、そうでなければネットワークが戻ったときに開始します。
- スコープを共有する実行は、開始順に 1 つずつ実行されます。
- `restore` は、保存された実行をそれぞれ 1 回だけ開始します。クライアントで進行中または一時停止中の実行はスキップします。そのため、2 回呼び出してもリクエストは繰り返されません。
- 復元された実行は `onMutate` をスキップし、コールバックは `context` として `null` を受け取ります。楽観的更新は、その更新をした実行のものです。復元された実行が繰り返すのは、リクエストと、その後のコールバックだけです。
- [MutationState ウィジェット](../mutations/#ミューテーションのすべての実行を表示する)と `useMutationState` は、同じ `mutationKey` で見つけた復元された実行を表示します。`MutationStateBuilder(mutation: addCommentMutation(), ...)` は、再起動後もまだ送信中のコメントを一覧表示します。

### 保存された実行を削除する

- 保存された実行は、成功または失敗した時点で Fuery が削除します。`clear()` はすべてを削除します。
- 定義が `restore` に渡されなかった保存済みの実行は残ります。そのため、後の `restore` で実行できます。
- `MutationPersist` の別の `version` が保存した実行や、読み取れない実行は、Fuery が削除します。

## Fuery が保証すること

- Fuery は、進行中の削除が終わるのを待ってから読み書きします。そのため、削除したクエリが削除済みのデータを復元したり、自身の削除を上書きしたりすることはありません。
- クエリのリセットや削除の時点でまだ進行中の復元は、古いデータを戻しません。
- 削除が `restore()` の読み取りと重なると、`restore()` は削除が終わってから読み取り直します。読み取りは合計で最大 3 回です。そのため、削除済みのデータを復元することはありません。3 回の読み取りすべてに削除が重なった場合、その呼び出しは何も復元しません。クエリは最初に使われたときに復元され、保存されたミューテーションは次の `restore()` を待ちます。
- クエリは、非同期の復元が終わってから、マウント時に取得するかどうかを決めます。そのため、`refetchOnMount` と `staleTime` は、復元されたデータをキャッシュされたデータと同じように扱います。
- ストレージのメソッドは同期でも非同期でもかまいません。Fuery はストレージのエラーを無視します。ストレージが失敗するクエリは、何も保存されていなかったかのように読み込みます。

## サンプルアプリでは

- [preferences のストレージ](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart)は、ストレージのアダプターです。
- [フィードのクエリ](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)は、フィードのページを永続化します。

各画面で何を示しているかは、サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) にまとめています。
