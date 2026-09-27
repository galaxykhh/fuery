---
title: ミューテーションのオプション
description: Flutter 向け Fuery の Mutation と NoVariablesMutation のすべてのオプションを、型とデフォルトとともにまとめています。ミューテーションを実行するメソッドと、1 回の mutate 呼び出しのコールバックも扱います。
sourceHash: 6b3b19657ff1
---

`Mutation` と `NoVariablesMutation` のすべてのオプションを、型とデフォルトとともに示します。ミューテーションを実行するメソッド、`MutateOptions`、`MutationPersist` も示します。すべてのミューテーション、またはキーの配下にあるミューテーションに `gcTime`、`retry`、`retryDelay`、`networkMode`、`meta` を設定するには、`MutationDefaults`（[デフォルト](../query-client/#デフォルト)）を使ってください。オプションを使う例は[ミューテーション](../../guides/mutations/)にあります。

## オプション

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `mutationFn` | `Future<TData> Function(TVariables variables)` | 必須 | 変更をサーバーに送信します。パラメーターの型が `TVariables` を、戻り値の型が `TData` を決めます。 |
| `mutationKey` | `List<Object?>` | なし | 実行を識別します。MutationState ウィジェット、`useMutationState`、`MutationFilters`、`restore` は、このキーで実行を見つけます。`setMutationDefaults` は、受け取ったキーで始まるキーを持つすべてのミューテーションにデフォルトを適用します。 |
| `gcTime` | `Duration` | 5 分 | 実行が完了し、どのオブザーバーも追跡していないときに、ミューテーションキャッシュに残る時間です。`infiniteDuration` にすると、`clear()` まで残ります。 |
| `retry` | `RetryPolicy` | `RetryPolicy.never()` | 失敗した試行を再試行する回数です。`.count(n)`、`.always()`、`.when((count, error) => ...)` のいずれかを指定します。 |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1 秒、2 秒、4 秒…（最大 30 秒） | 各再試行の前に待つ時間 |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `online` は、各試行の前にネットワークを待ちます。`always` はネットワークを無視します。`offlineFirst` は最初の試行を実行し、再試行の前にネットワークを待ちます。 |
| `scope` | `MutationScope` | なし | スコープの `id` が同じ実行は、開始した順に 1 つずつ実行されます。順番を待っている実行は `isPaused` を報告します。 |
| `persist` | `MutationPersist<TVariables>` | なし | 実行が pending 状態の間、変数を保存します。そのため、再起動後に `restore(mutations:)` で再び実行できます。`mutationKey`（アサートで検査します）と、`storage` を持つクライアントが必要です。[MutationPersist](#mutationpersist) を参照してください。 |
| `meta` | `Map<String, Object?>` | なし | 任意の値です。`MutationCacheConfig` のコールバックと `MutationFilters.predicate` は、`mutation.options.meta` として読み取ります。 |
| `onMutate` | [コールバック](#コールバック)を参照 | なし | `mutationFn` の前に実行されます。戻り値が `TContext` を決め、`context` になります。 |
| `onSuccess` | [コールバック](#コールバック)を参照 | なし | `mutationFn` が成功した後に実行されます。 |
| `onError` | [コールバック](#コールバック)を参照 | なし | 最後の試行が失敗した後に実行されます。 |
| `onSettled` | [コールバック](#コールバック)を参照 | なし | 成功と失敗のどちらの後にも実行されます。 |

## ミューテーションを実行する

定義は、次のメソッドで自身を実行します。`client` は省略可能で、デフォルトは呼び出し時点の `Fuery.client` です。

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `mutate(variables, [client])` | `void` | 実行を開始し、完了を待ちません。エラーは呼び出し元には届かず、実行の状態とコールバックに届きます。 |
| `mutateAsync(variables, [client])` | `Future<TData>` | 実行を開始し、そのデータを返します。実行が失敗すると、エラーをスローします。 |
| `observe({client})` | `MutationObserver<TData, TVariables, TContext>` | ミューテーションを実行し、その最新の実行を報告する新しいオブザーバーを返します。[1 つのオブザーバーを共有する](../../guides/mutations/#1-つのオブザーバーを共有する)を参照してください。 |

- 定義は状態を持ちません。`mutate` や `mutateAsync` で開始した実行は、クライアントのミューテーションキャッシュに属し、どのオブザーバーも保持しません。実行は、完了してから `gcTime` が過ぎるとキャッシュから削除されます。
- MutationState ウィジェット、`useMutationState`、`isMutating` は、`mutationKey` でその実行を見つけます。どの `MutationResult` にも、この実行は現れません。
- オブザーバーから開始した実行と同じく、この実行にもクライアントのデフォルト、`scope`、`persist` が適用されます。
- どちらのメソッドも `MutateOptions` を受け取りません。1 回の呼び出しに対する処理は、`mutateAsync` を await して書いてください。
- 独自のクライアントを持つ `FueryProvider` の下では、`context.queryClient` を渡してください。

## コールバック

| コールバック | 引数 | 戻り値 |
|---|---|---|
| `onMutate` | `TVariables variables, QueryClient client` | `FutureOr<TContext?>`（`context` になる値） |
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |

`client` は、ミューテーションを実行しているクライアントです。Fuery は、各コールバックを次の順序で実行します。

1. クライアントの `MutationCacheConfig` のコールバック（[キャッシュのコールバック](../query-client/#キャッシュのコールバック)）
2. ミューテーション自身のコールバック
3. 両方の `onSettled` が終わった後、実行の状態が success か error に変わります。次に、ウィジェットが新しい状態を知る前に、呼び出しの `MutateOptions` のコールバックが実行されます。

- 手順 1 と 2 で Future が返されると、Fuery はその Future を待ちます。そのため、Future が完了するまで、実行は pending 状態のままです。
- `onMutate`、または成功後の `onSuccess` か `onSettled` がスローしたエラーは、実行を失敗させ、`onError` に届きます。
- 失敗した実行の `onError` か `onSettled` がスローしたエラーは、[`onUncaughtError`](../../guides/client-setup/#コールバックがスローしたエラーをキャッチする) に届きます。
- `restore(mutations:)` が復元した実行は `onMutate` をスキップし、コールバックは `context` として `null` を受け取ります。
- `clear()` が一時停止中の実行を破棄すると、その実行は `CancelledError` で失敗します。`onMutate` より後のコールバックは実行されず、その呼び出しの `MutateOptions` のコールバックも実行されません。

## NoVariablesMutation

`NoVariablesMutation<TData, TContext>` は `Mutation` と同じオプションを受け取ります。ただし、`mutationFn` とコールバックには変数がありません。

| オプション | 引数 | 戻り値 |
|---|---|---|
| `mutationFn` | なし | `Future<TData>` |
| `onMutate` | `QueryClient client` | `FutureOr<TContext?>` |
| `onSuccess` | `TData data, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TContext? context, QueryClient client` | `FutureOr<void>` |

定義は `mutate()` と `mutateAsync()` で実行します。クライアントを渡すには、`mutate(null, client)` のように最初に `null` を渡してください。

`NoVariablesMutation` は `Mutation<TData, void, TContext>` です。そのため、次のようになります。

- ウィジェットとフックは、`mutate(null)` か `mutateAsync(null)` で実行します。
- `MutateOptions` のコールバックには変数の引数が残り、その値は `null` です。
- `observe()` は `NoVariablesMutationObserver` を返します。このオブザーバーは、`mutate()` と `mutateAsync()` で実行します。`MutateOptions` を渡すには、`mutate(null, options)` のように最初に `null` を渡してください。

永続化するには、`MutationPersist.noVariables` を渡してください。

## MutateOptions

`MutateOptions` は、1 回の呼び出しのためのコールバックを持ちます。結果やオブザーバーの `mutate` または `mutateAsync` の 2 番目の引数として渡します。定義の `mutate` は `MutateOptions` を受け取りません。

| フィールド | 引数 | 実行タイミング |
|---|---|---|
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | 呼び出しが成功した後 |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | 呼び出しが失敗した後 |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | 成功または失敗の後 |

- ミューテーション自身のコールバックの後、実行が完了してから実行されます。Fuery は `MutateOptions` のコールバックを待ちません。
- 同じオブザーバーで新しく呼び出すと、コールバックが置き換わります。そのため、最新の呼び出しのコールバックだけが実行されます。
- `reset()` はコールバックを破棄します。オブザーバーを所有するウィジェットをアンマウントしたときや、オブザーバーを所有するフックやスロットを破棄したときも同じです。
- 共有したオブザーバーは、リッスンしているものがあるかどうかに関係なく、`MutateOptions` のコールバックを実行します。コールバックで `BuildContext` を使う前に、`context.mounted` を確認してください。
- コールバックがスローしたエラーは `onUncaughtError` に届きます。

## MutationPersist

`MutationPersist<TVariables>` は、ミューテーションの変数を JSON に変換し、JSON から元に戻します。そのため、`restore(mutations:)` は再起動後に保存された実行を実行できます。設定方法は[ミューテーションを永続化する](../../guides/persistence/#ミューテーションを永続化する)にあります。

| パラメーター | 型 | デフォルト | 説明 |
|---|---|---|---|
| `toJson` | `Object? Function(TVariables variables)` | 必須 | 変数を、`jsonEncode` が受け付ける値に変換します。エンコードできない変数は保存せず、実行はそのまま続きます。 |
| `fromJson` | `TVariables Function(Object? json)` | 必須 | `jsonDecode` が生成した値を変数に戻します。 |
| `version` | `int` | `1` | Fuery は、バージョンが異なる保存済みの実行を、実行せずに削除します。JSON の形式を変えたら、値を上げてください。 |

`MutationPersist.noVariables` は、保存する変数がない `NoVariablesMutation` のための `MutationPersist<void>` です。
