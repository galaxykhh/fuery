---
title: ストリーミングクエリ
description: Flutter でストリームをキャッシュします。届いたチャンクを順に表示し、最後に結果を保持します。
sourceHash: 2d8d325d1547
---

`streamedQuery` は `Stream` をクエリ関数に変えます。チャンクが届いている間、画面はデータを表示します。ストリームが終わると、キャッシュが結果を保持します。

ストリーミングで返る回答、進捗ログ、処理中のファイルなど、チャンクで届いて最後に終わるレスポンスに使ってください。ライブフィードのように開いたままの接続は取得ではないので、クエリには向きません。その場合は、[キャッシュを読み書きする](../query-client/#キャッシュを読み書きする)のように、各メッセージを `setQueryData` でキャッシュに書き込んでください。

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

- **最初のチャンクでクエリが成功します**。データが増えるにつれて、ウィジェットがそのデータを表示します。
- **ストリームが終わるまで `isFetching` は true のままです**。
- **`combine` は `Stream.fold` と同じように動きます**。`initialValue` から始めて、それまでの値にチャンクを 1 つずつ加えます。
- **`initialValue` がデータ型を決める**ので、呼び出しに型引数は不要です。
- **空のストリームは `initialValue` で成功します**。
- **ストリームや `combine` でエラーが起きると、クエリは失敗します**。`data` には、それまでに受け取ったチャンクが残ります。
- **再試行のたびに新しいストリームを開始し**、`refetchMode` に従います。デフォルトのモードでは、最初にデータを消去します。

`Query` は、`staleTime` などのほかの[クエリのオプション](../../reference/query-options/)も通常どおり受け取ります。

## チャンクをリストに集める

空のリストから始めて、各チャンクを追加してください。

```dart
final log = Query(
  queryKey: ['jobs', id, 'log'],
  queryFn: streamedQuery(
    stream: (context) => api.jobLog(id),
    initialValue: const <LogLine>[],
    combine: (lines, line) => [...lines, line],
  ),
);
```

## ストリーミングクエリを再取得する

`refetchMode` は、`invalidateQueries` の後などにクエリがもう一度取得するとき、キャッシュされたデータをどう扱うかを決めます。

| モード | 新しいストリームの実行中 | 完了時 |
|---|---|---|
| `StreamRefetchMode.reset`（デフォルト） | Fuery がデータを消去し、最初のチャンクが届くまでクエリは pending になります。 | 新しいデータ |
| `StreamRefetchMode.append` | Fuery が新しいチャンクを既存のデータに畳み込みます。 | 結合されたデータ |
| `StreamRefetchMode.replace` | 古いデータが画面に残ります。 | 新しいデータ（一度にまとめて） |

```dart
queryFn: streamedQuery(
  stream: (context) => api.ask(question),
  initialValue: '',
  combine: (text, token) => text + token,
  refetchMode: StreamRefetchMode.replace,
),
```

## ストリームを止める

Fuery は、取得をキャンセルするときにストリームもキャンセルします。`cancelQueries` のときと、再取得が実行中の取得を置き換えるときです。

デフォルトでは、どのウィジェットもクエリを使っていなくてもストリームは動き続け、Fuery が結果をキャッシュします。そのため、ユーザーが戻ってきたときには、ストリーミングの回答は完成しています。代わりにストリームを止めるには、`stream` の中で `context.signal` を読んでください。すると、取得が[キャンセル可能](../queries/#リクエストをキャンセルする)になります。

```dart
stream: (context) {
  final request = api.startAnswer(question); // a request you can cancel
  context.signal.onAbort(request.cancel);
  return request.tokens;
},
```

## サンプルアプリでは

サンプルアプリは、[投稿画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)でスレッドの要約をストリーミングしています。[README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) では、各画面とその画面で示している機能を対応づけています。
