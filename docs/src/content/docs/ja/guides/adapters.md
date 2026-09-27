---
title: アダプターを作る
description: fuery と fuery_hooks と同じように fuery_core のスロットを使って、Fuery のクエリとミューテーションを独自の Flutter ウィジェットやほかの状態管理ライブラリで描画します。
sourceHash: f61aaedad61c
---

アダプターは、`fuery_core` の公開 API だけを使って、Fuery のクエリとミューテーションを独自のウィジェットやほかの状態管理ライブラリで描画します。`fuery` のウィジェットと [`fuery_hooks`](../hooks/) のフックも、この方法で作ったアダプターです。そのため、独自のアダプターでも、`fuery` や `fuery_hooks` と同じことがすべてできます。

アダプターは、描画するクエリやミューテーションごとに 1 つの**スロット**を保持します。スロット（`ObserverSlot`）は、描画のたびに変わりうるソースの[オブザーバー](../../how-the-cache-works/#オブザーバー)を保持します。

## スロットでクエリを描画する

描画のたびに `update` を呼び出し、`result` を読み取り、再描画のために購読します。次のフックは `flutter_hooks` だけで書かれていて、スロットの仕様をすべて含んでいます。

```dart
QueryResult<TData> useMyQuery<TData extends Object>(QuerySource<TData> query) {
  final client = FueryProvider.of(useContext(), listen: true);
  final slot = useMemoized(() => QuerySlot(query, client));
  final changes = useState(0);
  useEffect(() {
    var active = true;
    final unsubscribe = slot.subscribe(notifyManager.batchCalls((_) {
      if (active) changes.value++;
    }));
    return () {
      active = false;
      unsubscribe();
      slot.dispose();
    };
  }, [slot]);
  slot.update(query, client);
  return slot.result;
}
```

## スロットの仕様

`QuerySlot` は `QuerySource`（`Query` または `QueryObserver`）を受け取ります。`QuerySlot` には次のメンバーがあり、`InfiniteQuerySlot` と `MutationSlot` にも同じメンバーがあります。

| メンバー | 説明 |
|---|---|
| `update(source, client)` | 描画のたびに呼び出してください。定義を渡した場合、スロットはオブザーバーを所有し、そのオプションを更新します。クライアントが変わると、新しいオブザーバーを使います。オブザーバーを渡した場合、スロットはそのオブザーバーを、作成時のクライアントのまま使います。 |
| `result` | 描画する結果です。`update` から戻った時点で最新になっています。 |
| `subscribe(listener)` | 以降のすべての結果で `listener` を呼び出します。`update` でスロットが別のオブザーバーに移っても、購読は続きます。リスナーを削除する関数を返します。 |
| `listen((previous, current) {...})` | 以降の変更のたびにリスナーを呼び出します。画面遷移などの副作用に使います。`previous` は、最後にリスナーに渡した結果か、開始時の `result` です。リッスンを止める関数を返します。 |
| `dispose()` | すべてのリスナーを削除します。スロットがオブザーバーを作成した場合は、クエリのオブザーバーを破棄するか、ミューテーションのオブザーバーをリセットします。リセットすると、最新の `mutate` 呼び出しのコールバックはなくなります。 |
| `observer` | スロットが現在描画に使っているオブザーバー |

クエリ、無限クエリ、ミューテーションのリスナーウィジェットとコンシューマーウィジェット、`useOnQueryChange`、`useOnMutationChange` は `listen` を呼び出します。そのため、次の規則に従います。

- リスナーはマイクロタスクで実行され、描画中には実行されません。
- 開始時の `result` や、前の結果と等しい結果では、リスナーは呼び出されません。
- `update` でスロットが別のオブザーバーに移ると、リスナーを呼び出さずに、新しい `result` から開始し直します。
- `listen` は購読します。そのため、マウントされたウィジェットの場合と同じように、クエリは取得します。
- リスナーがスローすると、Fuery はクライアントの `onUncaughtError` に報告します。

## リスナーの呼び出しをバッチにまとめる

`QuerySlot`、`InfiniteQuerySlot`、`MutationSlot` は、`subscribe` のリスナーを同期的に呼び出します。マウントしたウィジェットが取得を始めたときなど、別のウィジェットのビルド中に呼び出すこともあります。描画中に更新できないフレームワークでは、上のフックと同じようにしてください。

1. リスナーを `notifyManager.batchCalls` で包み、変更がマイクロタスクで届くようにします。
2. 破棄の後に届いた変更は無視します。

`QueriesSlot` と `MutationStateSlot` は、すでにマイクロタスクでリスナーを呼び出します。そのため、どちらの手順も必要ありません。

## そのほかのスロット

| スロット | ソース | 結果 |
|---|---|---|
| `InfiniteQuerySlot` | `InfiniteQuerySource`（`InfiniteQuery` または `InfiniteQueryObserver`） | `InfiniteQueryResult` |
| `MutationSlot` | `MutationSource`（`Mutation` または `MutationObserver`） | `MutationResult` |
| `QueriesSlot` | 同じデータ型の `QuerySource` のリスト | `QueryResult` のリスト（同じ順序） |

`QueriesSlot` は、`useQueries` のようなフックに使います。`subscribe` のリスナーは、同時に届いた変更に対して 1 回だけ、マイクロタスクで呼び出します。そのため、`batchCalls` は不要です。各クエリは、リストの並び順が変わっても、キーがリストにある間は同じオブザーバーを使い続けます。`observer` はオブザーバーのリストです。オブザーバーの追加、削除、置き換え、移動があったときだけ、新しいリストになります。

## ミューテーションのすべての実行

`MutationStateSlot` は、どこで開始したかに関係なく、ミューテーションのすべての実行の状態を提供します。MutationState ウィジェットと `useMutationState` は、`MutationStateSlot` を使います。

- `MutationStateSource`（`mutationKey` を持つ `Mutation`、または `MutationFilters`）を受け取ります。
- キャッシュを読み取るだけです。`observer` はクライアントの `MutationCache` です。
- `result` は、各実行の状態を開始順に並べたリストです。一致する実行が追加、削除、または変更されるまで、同じリストのままです。
- `subscribe` のリスナーは、リストが変わったときだけ、バッチごとに 1 回、マイクロタスクで呼び出します。そのため、`batchCalls` は不要です。

`subscribeToRuns((previous, current) {...})` は、一致する各実行の以降の変更ごとに、その実行の前の状態とともにリスナーを呼び出します。後から開始した実行の前の状態は idle です。リスナーを追加した時点での各実行の状態や、キャッシュが削除した実行は報告しません。`MutationStateListener` と `useOnMutationStateChange` は `subscribeToRuns` を使います。

## 結果だけからリッスンする

結果は、その結果を報告したオブザーバーを `result.observer` として持っています。結果だけを受け取ったアダプターは、`useOnQueryChange` や `useOnMutationChange` と同じように、そのオブザーバーに対して独自のスロットを作ってリッスンします。

```dart
void Function() listenTo<TData extends Object>(
  QueryResult<TData> result,
  void Function(QueryResult<TData> previous, QueryResult<TData> current)
      listener,
) {
  final observer = result.observer;
  if (observer == null) return () {};
  final slot = QuerySlot(observer, observer.client);
  slot.listen(listener);
  return slot.dispose;
}
```

- スロットはオブザーバーをそのまま使い、破棄しません。
- コンストラクターで作った `QueryResult` では、`observer` は null です。
- `InfiniteQueryResult` が持つ `InfiniteQueryObserver` は、`InfiniteQuerySlot` に渡します。

## クライアントを参照する

Flutter では、`FueryProvider.of(context, listen: true)` が最も近いプロバイダーのクライアント、または `Fuery.client` を返します。プロバイダーのクライアントが置き換わると、呼び出し元がリビルドします。すると、次の `update` で、オブザーバーを所有するスロットが新しいクライアントに移ります。

Flutter 以外では、アプリが使うクライアントを渡してください。

## フォーカスと再接続での再取得

Flutter では、Fuery のウィジェットやフックと同じように、アダプターのマウント時に `FueryBinding.ensureInitialized()` を呼び出してください。この呼び出しがアプリのライフサイクルを接続します。そのため、アプリが再開したときに Fuery が古い（stale）クエリを再取得し、アプリがバックグラウンドにある間は再試行が待機します。2 回目以降の呼び出しは何もしません。上位の `FueryProvider` も `FueryBinding.ensureInitialized()` を呼び出します。[アプリが再開したとき](../lifecycle/#アプリが再開したとき)を参照してください。

クライアントがフォーカス時と再接続時に再取得し、一時停止中のミューテーションを再開するのは、マウントされている間だけです。`Fuery.client` は常にマウントされていて、`FueryProvider` は自身のクライアントをマウントします。アダプターが使うそれ以外のクライアントでは、`mount()` を呼び出し、使い終わったら `unmount()` を呼び出してください。Flutter 以外では、ホストのフォーカスイベントを `focusManager.setEventListener` で接続してください。[QueryClient のリファレンス](../../reference/query-client/)を参照してください。

## Fuery のソースでは

- [`adapter_test.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_core/test/adapter_test.dart) は、Flutter なしでスロットを使ってクエリを描画します。
- [`hooks.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_hooks/lib/src/hooks.dart) は、`fuery_hooks` のすべてのフックをスロットの上に構築します。
- [`result_subscriber.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/lib/src/result_subscriber.dart) は、`fuery` のウィジェットをスロットの上に構築します。
