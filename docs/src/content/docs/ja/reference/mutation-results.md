---
title: ミューテーションの結果
description: Flutter 向け Fuery の MutationResult と MutationState のフィールド、それぞれを報告するウィジェットとフック、結果からミューテーションを実行するメソッドをまとめています。
sourceHash: eee94168efc2
---

ウィジェット、フック、スロット、オブザーバーは、ミューテーションの進行状況を次の 2 つの型のどちらかで報告します。

| 報告元 | 型 |
|---|---|
| `MutationBuilder`、`MutationSelector`、`MutationListener`、`MutationConsumer`、`useMutation`、`useOnMutationChange`、`MutationSlot`、オブザーバーの `result` と `stream` | [`MutationResult`](#mutationresult)：オブザーバーの最新の実行の状態と、別の実行を開始するメソッド |
| `MutationStateBuilder`、`MutationStateSelector`、`MutationStateListener`、`useMutationState`、`useOnMutationStateChange`、`MutationStateSlot` | どこで開始したかに関係なく、実行ごとに 1 つの [`MutationState`](#mutationstate-のフィールド) |

1 つのウィジェットやオブザーバーからミューテーションを実行し、そこから開始した最新の実行を表示するときは、`MutationResult` を読み取ってください。[ミューテーションのすべての実行を表示する](../../guides/mutations/#ミューテーションのすべての実行を表示する)のように、ミューテーションのすべての実行を表示するときは、`MutationState` を読み取ってください。`addTodo.mutate('Buy milk')` のように定義から開始した実行は、`MutationState` にだけ現れます。定義の `mutate` と `mutateAsync` は[ミューテーションを実行する](../mutation-options/#ミューテーションを実行する)にあります。

## MutationResult

`MutationResult<TData, TVariables, TContext>` は、オブザーバーの最新の実行の `MutationState` に、次のメンバーを加えたものです。最初の実行の前は idle です。

| メンバー | 型 | 説明 |
|---|---|---|
| `mutate(variables, [options])` | `void` | 実行を開始し、完了を待ちません。エラーは呼び出し元には届かず、状態とコールバックに届きます。 |
| `mutateAsync(variables, [options])` | `Future<TData>` | 実行を開始し、そのデータを返します。実行が失敗すると、エラーをスローします。 |
| `reset()` | `void` | 最新の実行を忘れ、idle に戻ります。実行そのものは続きます。最新の呼び出しの `MutateOptions` のコールバックは破棄されます。 |
| `observer` | `MutationObserver<TData, TVariables, TContext>` | この結果を報告したオブザーバーです。結果だけを受け取ったアダプターは、このオブザーバーをリッスンできます。`==` の比較には含まれません。 |

- `options` は [`MutateOptions`](../mutation-options/#mutateoptions) です。
- 実行はオブザーバーのクライアントを使います。定義の `mutate` と `mutateAsync` は、`options` の代わりにクライアントを受け取ります。
- 新しい実行は最新の実行を置き換えます。そのため、実行が重なると、結果は最も新しい実行だけを追跡します。
- `NoVariablesMutation` では変数が `void` なので、`mutate(null)` を呼び出してください。

## MutationState のフィールド

`MutationState<TData, TVariables, TContext>` は、1 つの実行を表します。

| フィールド | 型 | 内容 |
|---|---|---|
| `status` | `MutationStatus` | `idle`、`pending`、`success`、`error` のいずれか |
| `data` | `TData?` | `mutationFn` が返した値です。実行が成功するまでは `null` です。 |
| `error` | `Object?` | 実行が失敗した理由です。それ以外のステータスでは `null` です。 |
| `variables` | `TVariables?` | 実行の `mutate` 呼び出しが渡した値です。idle の間は `null` です。 |
| `context` | `TContext?` | `onMutate` が返した値です。`restore(mutations:)` が開始した実行では `null` です。 |
| `submittedAt` | `int` | 実行の `mutate` 呼び出しの時刻（エポックからのミリ秒）です。実行がその後、開始まで待った場合も、呼び出しの時刻です。idle の間は `0` です。復元された実行は、その実行を保存した実行の時刻を保持します。 |
| `failureCount` | `int` | 失敗した試行の回数です。実行の開始時と成功時に `0` にリセットされます。 |
| `failureReason` | `Object?` | 最後に失敗した試行のエラーです。`failureCount` と一緒にリセットされます。 |
| `isPaused` | `bool` | 実行が待機しているかどうかを示します。待つ対象は、ネットワーク、`scope` 内の順番、または再試行の前のアプリのフォアグラウンドへの復帰です。 |

`status` は、`MutationStatus` の値のどれかを持ちます。各値には、状態と `MutationStatus` 自体の両方にゲッターがあります。

| 値 | ゲッター | 意味 |
|---|---|---|
| `idle` | `isIdle` | まだ実行がないか、`reset()` が呼び出されました。 |
| `pending` | `isPending` | 実行が待機中、`mutationFn` を実行中、再試行中、またはコールバックを実行中です。 |
| `success` | `isSuccess` | `mutationFn` が値を返し、コールバックが終わりました。 |
| `error` | `isError` | 実行が失敗しました。最後の試行が失敗したか、`onMutate`、`onSuccess`、`onSettled` のいずれかがスローしました。`clear()` が一時停止中の実行を破棄した場合を除き、`onError` と `onSettled` のコールバックは終わっています。 |
