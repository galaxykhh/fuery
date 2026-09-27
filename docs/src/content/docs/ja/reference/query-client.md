---
title: QueryClient
description: Flutter 向け Fuery の QueryClient のすべてのオプション、メソッド、フィルター、デフォルト、キャッシュのフィールドを、型とデフォルトとともにまとめています。
sourceHash: 0f608d9305c6
---

`QueryClient` は、クエリキャッシュとミューテーションキャッシュを所有します。キャッシュされたデータの読み取り、書き込み、再取得は、すべて `QueryClient` を経由します。クエリキャッシュは、クエリキーごとに 1 つのキャッシュエントリ（`CachedQuery`）を保持します。キャッシュエントリは、そのキーのデータと状態です。ミューテーションキャッシュは、`mutate` 呼び出しごとに 1 つの実行（`CachedMutation`）を保持します。作業ごとの手順は、[キャッシュの読み取りと更新](../../guides/query-client/)と[クライアントを設定する](../../guides/client-setup/)を参照してください。

## コンストラクターのオプション

| 名前 | 型 | デフォルト | 説明 |
|---|---|---|---|
| `queryCache` | `QueryCache` | `QueryCache()` | キャッシュエントリを保持します。[`QueryCacheConfig`](#キャッシュのコールバック) を指定するときは、この引数に `QueryCache` を渡してください。 |
| `mutationCache` | `MutationCache` | `MutationCache()` | ミューテーションの実行を保持します。[`MutationCacheConfig`](#キャッシュのコールバック) を指定するときは、この引数に `MutationCache` を渡してください。 |
| `defaultOptions` | `DefaultOptions` | `DefaultOptions()` | すべてのクエリとミューテーションのデフォルトです。[デフォルト](#デフォルト)を参照してください。 |
| `storage` | `QueryStorage?` | `null` | `persist` を持つクエリとミューテーションが、データを保存する場所です。ストレージがないと、`persist` は何もしません。 |
| `persistMaxAge` | `Duration` | 1 日 | 保存されたデータを復元できる最大の古さです。クエリの `QueryPersist` が `maxAge` を設定していない場合に使います。 |
| `onUncaughtError` | `void Function(Object error, StackTrace stackTrace)?` | `null` | どの呼び出し元もキャッチできないエラーを受け取ります。設定しないと、これらのエラーは現在のゾーンに届きます。[コールバックがスローしたエラーをキャッチする](../../guides/client-setup/#コールバックがスローしたエラーをキャッチする)を参照してください。 |

各オプションは、クライアントのフィールドでもあります。

クライアントがフォーカス時と再接続時に再取得し、一時停止中のミューテーションを再開するのは、マウントされている間だけです。`Fuery.client` への代入と `FueryProvider` は、そのクライアントをマウントします。それ以外のクライアントでは、`mount()` と `unmount()` を自分で呼び出してください。

## データの読み書き

`TData` はクエリのデータ型です。`updatedAt` は、データを取得したとみなす時刻を、エポックからのミリ秒で設定します。デフォルトは現在時刻です。

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `getData(query)` | `TData?` | クエリのキャッシュされたデータ、または `null` |
| `setData(query, data, {updatedAt})` | `TData` | データを書き込みます。`setData` が作成したキャッシュエントリは、`persist` を含むクエリのすべてのオプションを持ちます。 |
| `updateData(query, updater, {updatedAt})` | `TData?` | 現在のデータに対して `updater` が返した値を書き込みます。何もキャッシュされていなければ、現在のデータは `null` です。`null` を返すと、キャッシュは変わりません。 |
| `getQueryData<TData>(queryKey)` | `TData?` | キーのキャッシュされたデータ、または `null` です。キーが別のデータ型を持っていると、`StateError` をスローします。 |
| `setQueryData<TData>(queryKey, data, {updatedAt})` | `TData` | キーを指定してデータを書き込みます。`setQueryData` が作成したキャッシュエントリにはクエリ関数がありません。そのため、オブザーバーか `client.query` がそのキーのクエリを提供するまで、再取得はこのキャッシュエントリをスキップします。 |
| `updateQueryData<TData>(queryKey, updater, {updatedAt})` | `TData?` | キーを指定する `updateData` |
| `getQueriesData<TData>({queryKey, exact, predicate})` | `List<(List<Object?>, TData?)>` | 一致するすべてのキャッシュエントリのキーとデータです。一致するキャッシュエントリは、すべて `TData` を持っている必要があります。 |
| `updateQueriesData<TData>(updater, {queryKey, exact, predicate, updatedAt})` | `void` | 一致するキャッシュエントリのうち、データの型がちょうど `TData` のものをすべて更新します。`TData` は `updater` のパラメーターから決まります。パラメーターに型がないと、`ArgumentError` をスローします。 |
| `getQueryState(queryKey)` | `QueryState<Object>?` | キーのキャッシュエントリの状態、または `null` です。[QueryState のフィールド](#querystate-のフィールド)を参照してください。 |
| `watch<T>(selector)` | `Stream<T>` | `selector(client)` のブロードキャストストリーム |

`watch` は、各リスナーにまず現在の値を渡します。その後、クエリキャッシュかミューテーションキャッシュが変わり、新しい値が前と異なるときに、再び値を流します。リスト、マップ、セットは内容で比較し、それ以外の値は `==` で比較します。セレクターがスローしたエラーは、ストリームに流れます。監視するだけでは何も取得しません。

## 取得

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `query(query)` | `Future<TData>` | クエリの `staleTime` の間、キャッシュされたデータが新鮮（fresh）ならそのデータを返し、そうでなければ取得します。 |
| `infiniteQuery(query)` | `Future<InfiniteData<TPage, TParam>>` | `InfiniteQuery` 用の `query` です。何もキャッシュされていなければ、取得はクエリの `pages`（デフォルトは 1、最大 `maxPages`）を読み込みます。ページがキャッシュされていれば、最初のページから `maxPages` まで読み込み直します。 |

どちらのメソッドも、次の規則に従います。

- 取得が必要な呼び出しは、そのキーの取得がすでに実行中なら、新しく取得を始めずにその取得を待ちます。
- 取得が失敗すると、Future も失敗します。
- Fuery が失敗した取得を再試行するのは、クエリ、`defaultOptions`、またはそのキーに対する `setQueryDefaults` の呼び出しが `retry` を設定している場合だけです。

## 一致するクエリへの操作

各メソッドは、[クエリフィルター](#クエリフィルター)と、その行にある引数を受け取ります。

| メソッド | 戻り値 | 説明 | 固有の引数 |
|---|---|---|---|
| `invalidateQueries` | `Future<void>` | 一致するキャッシュエントリを古い（stale）状態にし、アクティブなものを再取得します。 | `refetchType`、`cancelRefetch`、`throwOnError` |
| `refetchQueries` | `Future<void>` | 一致するキャッシュエントリを再取得します。 | `cancelRefetch`、`throwOnError` |
| `resetQueries` | `Future<void>` | 一致するキャッシュエントリを初期状態に戻し、永続化されたデータを削除し、アクティブなものを再取得します。 | `cancelRefetch`、`throwOnError` |
| `cancelQueries` | `Future<void>` | 実行中の取得をキャンセルします。 | `revert`、`silent` |
| `removeQueries` | `void` | 一致するキャッシュエントリを、永続化されたデータとともにキャッシュから削除します。 | なし |
| `isFetching` | `int` | 一致するキャッシュエントリのうち、取得中のものを数えます。 | なし |

`invalidateQueries`、`refetchQueries`、`resetQueries` は、次のキャッシュエントリを再取得しません。

- オフのもの（`isDisabled` が `true`）
- 静的で、データがあるもの（オブザーバーが `staleTime: staticStaleTime` を使っている）
- `setQueryData` だけが書き込み、まだクエリ関数がないもの

3 つのメソッドが返す Future は、再取得が終わると完了します。ネットワークを待っている取得など、一時停止中の取得は待ちません。

`removeQueries` と `clear()` は、まだ購読しているオブザーバーを止めません。Fuery はそのオブザーバーを同じキーの新しいキャッシュエントリに移し、そのキャッシュエントリは再び読み込みます。

```dart
// Refetch the stale cache entries under ['todos'] now,
// and fail if a refetch fails.
await client.refetchQueries(
  queryKey: ['todos'],
  stale: true,
  throwOnError: true,
);

// Stop the list's fetch and put back the state it had before.
await client.cancelQueries(queryKey: ['todos'], exact: true);
```

## クエリフィルター

設定したすべてのフィルターが、キャッシュエントリに一致する必要があります。

| フィルター | 型 | デフォルト | 対象 |
|---|---|---|---|
| `queryKey` | `List<Object?>?` | すべてのキャッシュエントリ | キーがこのキーで始まるキャッシュエントリ。`['todos']` は `['todos', 1]` に一致します。 |
| `exact` | `bool` | `false` | `true` にすると、キーが `queryKey` と等しいキャッシュエントリだけ |
| `type` | `QueryTypeFilter` | `QueryTypeFilter.all` | `.active`：有効なオブザーバーが少なくとも 1 つ使っているキャッシュエントリ。`.inactive`：そのようなオブザーバーがないキャッシュエントリ |
| `stale` | `bool?` | `null` | `true` は古いキャッシュエントリを、`false` は新鮮なキャッシュエントリを選びます。 |
| `predicate` | `bool Function(CachedQuery<Object> query)?` | `null` | この関数が `true` を返すキャッシュエントリ |

`invalidateQueries` は、`type` を `QueryTypeFilter?` として受け取り、デフォルトは `null` です。未設定のときは、`.all` と同じく一致するすべてのキャッシュエントリを古い状態にしますが、再取得するのはアクティブなものだけです。`.all` を指定すると、非アクティブなものも再取得します。

`queryCache.find` と `findAll` が受け取る `QueryFilters` には、上のフィールドに加えて `fetchStatus` があります。`fetchStatus` は `FetchStatus?` で、その取得ステータスのキャッシュエントリを選びます。`matches(query)` は、1 つのキャッシュエントリを判定します。

## 再取得とキャンセルの引数

| 引数 | 型 | デフォルト | 説明 |
|---|---|---|---|
| `refetchType` | `RefetchType?` | `null` | `invalidateQueries` が再取得する対象です。`RefetchType.active`、`.inactive`、`.all`、または古い状態にするだけの `.none` を指定します。 |
| `cancelRefetch` | `bool` | `true` | データを持つキャッシュエントリの実行中の取得をキャンセルし、新しい取得を始めます。`false` にすると、実行中の取得を待ちます。最初のデータを読み込んでいるキャッシュエントリは、常に取得を続けます。 |
| `throwOnError` | `bool` | `false` | `true` にすると、再取得が失敗したときに、返された Future が失敗します。 |
| `revert` | `bool` | `true` | キャンセルしたキャッシュエントリを、取得前の状態に戻します。`false` にすると、`CancelledError` をエラーとして記録します。 |
| `silent` | `bool` | `false` | `true` かつ `revert: false` のとき、エラーを記録しません。キャッシュエントリは状態を保ち、idle に戻ります。 |

`refetchType` がないと、`invalidateQueries` は `type` が選んだキャッシュエントリを再取得します。`type` も未設定なら、アクティブなものを再取得します。

```dart
// Mark every cache entry under ['todos'] stale, refetch the ones
// nothing shows too, and let fetches in flight finish instead of
// restarting them.
await client.invalidateQueries(
  queryKey: ['todos'],
  refetchType: RefetchType.all,
  cancelRefetch: false,
);
```

## ミューテーション

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `isMutating({mutationKey, exact, predicate})` | `int` | 一致する pending 状態のミューテーションの実行を数えます。 |
| `resumePausedMutations()` | `Future<void>` | 一時停止中のミューテーションの実行をすべて再開します。デバイスがオフラインの間は何もしません。 |

`MutationFilters` は、ミューテーションの実行を選びます。`isMutating` は `MutationFilters` を作成し、`mutationCache.find` と `findAll` は `MutationFilters` を受け取ります。

| フィルター | 型 | デフォルト | 対象 |
|---|---|---|---|
| `mutationKey` | `List<Object?>?` | すべての実行 | `mutationKey` がこのキーで始まる実行。キーのない実行は一致しません。 |
| `exact` | `bool` | `false` | `true` にすると、キーが `mutationKey` と等しい実行だけ |
| `status` | `MutationStatus?` | `null` | このステータスの実行。`isMutating` は `MutationStatus.pending` を設定します。 |
| `predicate` | `bool Function(AnyCachedMutation mutation)?` | `null` | この関数が `true` を返す実行 |

`matches(mutation)` は、1 つの実行を判定します。

```dart
final savingTodos = client.isMutating(
  mutationKey: ['todos'],
  exact: true,
  predicate: (mutation) => !mutation.state.isPaused,
);
```

## デフォルト

`DefaultOptions` は、クライアントのデフォルトを保持します。

| フィールド | 型 | デフォルト |
|---|---|---|
| `queries` | `QueryDefaults` | `QueryDefaults()` |
| `mutations` | `MutationDefaults` | `MutationDefaults()` |

`QueryDefaults` は、特定のクエリに固有でない[クエリのオプション](../query-options/)を受け取ります。`enabled`、`staleTime`、`gcTime`（ガベージコレクション時間）、`refetchInterval`、`refetchIntervalInBackground`、`refetchOnMount`、`refetchOnFocus`、`refetchOnReconnect`、`retryOnMount`、`retry`、`retryDelay`、`networkMode`、`structuralSharing`、`meta` です。

`MutationDefaults` は、[ミューテーションのオプション](../mutation-options/#オプション)のうち `gcTime`、`retry`、`retryDelay`、`networkMode`、`meta` を受け取ります。

すべてのフィールドは null 許容です。設定しないフィールドは、オプション自体のデフォルトのままです。

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `setQueryDefaults(queryKey, defaults)` | `void` | キーが `queryKey` で始まるすべてのクエリのデフォルトを設定します。同じキーで再び設定すると、前のデフォルトを置き換えます。 |
| `getQueryDefaults(queryKey)` | `QueryDefaults` | このキーの、キーごとのデフォルトです。一致するすべてのプレフィックスのデフォルトをマージしたものです。 |
| `setMutationDefaults(mutationKey, defaults)` | `void` | `mutationKey` がこの `mutationKey` で始まるすべてのミューテーションのデフォルトを設定します。 |
| `getMutationDefaults(mutationKey)` | `MutationDefaults` | このキーの、キーごとのデフォルトです。一致するすべてのプレフィックスのデフォルトをマージしたものです。 |

優先順位は、強いものから順に次のとおりです。

1. クエリまたはミューテーションに設定したオプション
2. キーごとのデフォルト。複数のプレフィックスが一致する場合は、プレフィックスが最初に登録された順にマージし、後のものが優先されます。
3. `defaultOptions`

`mutationKey` のないミューテーションには、`defaultOptions.mutations` だけが適用されます。`meta` は全体が置き換わり、マージされることはありません。

## キャッシュのコールバック

キャッシュは、コンストラクターで設定を受け取り、存在する間ずっと `config` として保持します。

`QueryCacheConfig` は、クエリキャッシュのすべての取得に対してコールバックを実行します。各コールバックは `void` を返し、最後の引数としてキャッシュエントリ（`CachedQuery<Object>`）を受け取ります。

| コールバック | 実行タイミング |
|---|---|
| `onSuccess(data, query)` | 取得が成功した後 |
| `onError(error, query)` | 取得が失敗し、再試行を使い切った後 |
| `onSettled(data, error, query)` | 成功または失敗の後 |

キャンセルされた取得は、どのコールバックにも届きません。コールバックがスローしたエラーは `onUncaughtError` に届きます。

`MutationCacheConfig` は、キャッシュ内のミューテーションのすべての実行に対してコールバックを実行します。各コールバックは Future を返してもかまいません。最後の引数としては `AnyCachedMutation` を受け取ります。`error` は `Object`、`data`、`variables`、`context` は `Object?` です。

| コールバック | 実行タイミング |
|---|---|
| `onMutate(variables, mutation)` | `mutationFn` の前 |
| `onSuccess(data, variables, context, mutation)` | 成功の後 |
| `onError(error, variables, context, mutation)` | 失敗の後 |
| `onSettled(data, error, variables, context, mutation)` | 成功または失敗の後 |

- 各コールバックは、対応する[ミューテーションのコールバック](../mutation-options/#コールバック)より先に実行されます。コールバックが Future を返すと、Fuery はその Future を待ちます。
- `restore` が再開した実行は、両方の `onMutate` をスキップします。
- `onMutate`、または成功後の `onSuccess` か `onSettled` がスローしたエラーは、ミューテーションを失敗させます。
- 失敗後の `onError` か `onSettled` がスローしたエラーは、`onUncaughtError` に届きます。

## キャッシュ

`client.queryCache` と `client.mutationCache` は、キャッシュを読み取ります。キャッシュを変更するときは、クライアントを使ってください。

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `queryCache.getAll()` | `List<CachedQuery<Object>>` | すべてのキャッシュエントリ |
| `queryCache.find(filters)` | `CachedQuery<Object>?` | 最初に一致するキャッシュエントリです。`queryKey` は完全一致で比較します。 |
| `queryCache.findAll([filters])` | `List<CachedQuery<Object>>` | 一致するすべてのキャッシュエントリです。フィルターがなければ、すべてのキャッシュエントリを返します。 |
| `queryCache.get(queryHash)` | `CachedQuery<Object>?` | この `queryHash` を持つキャッシュエントリ |
| `mutationCache.getAll()` | `List<AnyCachedMutation>` | ミューテーションのすべての実行 |
| `mutationCache.find(filters)` | `AnyCachedMutation?` | 最初に一致する実行です。`mutationKey` は完全一致で比較します。 |
| `mutationCache.findAll([filters])` | `List<AnyCachedMutation>` | 一致するすべての実行です。フィルターがなければ、すべての実行を返します。 |

`CachedQuery<TData>` は、1 つのキーのキャッシュエントリです。

| フィールド | 型 | 説明 |
|---|---|---|
| `queryKey` | `List<Object?>` | キー |
| `queryHash` | `String` | キーのハッシュです。キャッシュ内でキャッシュエントリを識別します。 |
| `state` | `QueryState<TData>` | [QueryState のフィールド](#querystate-のフィールド)を参照してください。 |
| `options` | `Query<TData>` | キャッシュエントリが取得に使うオプション（デフォルトを適用済み） |
| `meta` | `Map<String, Object?>?` | `options.meta` |
| `observers` | `List<QueryObserver<TData>>` | キャッシュエントリを使っているオブザーバー（購読した順） |
| `observersCount` | `int` | キャッシュエントリを使っているオブザーバーの数 |
| `isActive` | `bool` | 有効なオブザーバーが少なくとも 1 つあるかどうか |
| `isDisabled` | `bool` | キャッシュエントリが自動で取得しないかどうかを示します。すべてのオブザーバーがオフの場合か、何も監視しておらず `isFetched` が `false` の場合です。 |
| `isStale` | `bool` | 少なくとも 1 つのオブザーバーにとって古いかどうかを示します。オブザーバーがない場合は、データがないか無効化されていれば `true` です。 |
| `isStatic` | `bool` | オブザーバーが `staticStaleTime` を使っているために、キャッシュエントリが古くならないかどうか |
| `isFetched` | `bool` | 取得、または `setData` などの書き込みで、キャッシュエントリが少なくとも 1 回データかエラーを受け取ったかどうかを示します。ストレージから復元したデータは数えません。 |
| `isStaleByTime([staleTime])` | `bool` | データがない、無効化されている、または `staleTime` より古いかどうかを示します。`staticStaleTime` では、データがあれば常に `false` です。 |
| `future` | `Future<TData>?` | 実行中の取得（あれば） |

`CachedMutation<TData, TVariables, TContext>` は、ミューテーションの 1 つの実行です。

| フィールド | 型 | 説明 |
|---|---|---|
| `mutationId` | `int` | キャッシュ内の実行に、作成された順に付く番号 |
| `options` | `Mutation<TData, TVariables, TContext>` | 実行が使うオプション（デフォルトを適用済み） |
| `state` | `MutationState<TData, TVariables, TContext>` | [MutationState のフィールド](../mutation-results/#mutationstate-のフィールド)を参照してください。 |
| `meta` | `Map<String, Object?>?` | `options.meta` |

`AnyCachedMutation` は `CachedMutation<Object?, Object?, Object?>` で、呼び出し元が型を知らない実行です。フィルターとキャッシュのコールバックは、実行をこの型で受け取ります。`AnyMutation` は `Mutation<Object?, Object?, Object?>` で、`restore(mutations:)` が受け取る各定義の型です。

## QueryState のフィールド

`QueryState<TData>` は、キャッシュエントリが保持する状態です。オブザーバーは、`QueryState` から各 `QueryResult` を作ります。

| フィールド | 型 | 説明 |
|---|---|---|
| `data` | `TData?` | キャッシュエントリが最後に受け取ったデータです。`null` はデータがないことを意味します。 |
| `status` | `QueryStatus` | `pending`、`error`、`success` のいずれか |
| `fetchStatus` | `FetchStatus` | `fetching`、`paused`、`idle` のいずれか |
| `error` | `Object?` | 最後の試行が失敗した場合の、そのエラー |
| `dataUpdatedAt` | `int` | `data` が最後に書き込まれた時刻（エポックからのミリ秒）です。一度もなければ `0` です。 |
| `errorUpdatedAt` | `int` | `error` が最後に設定された時刻（エポックからのミリ秒）です。一度もなければ `0` です。 |
| `dataUpdateCount` | `int` | 取得、または `setData` などの書き込みで、キャッシュエントリがデータを受け取った回数です。ストレージから復元したデータは数えません。 |
| `errorUpdateCount` | `int` | 取得がエラーで終わった回数です。`revert: false` でのキャンセルも含みます。 |
| `fetchFailureCount` | `int` | 最新の取得の失敗数（再試行を含む）です。取得の開始時にリセットされます。`QueryResult` は、この値を `failureCount` として示します。 |
| `fetchFailureReason` | `Object?` | 最新の取得での最後の失敗です。`QueryResult` は、この値を `failureReason` として示します。 |
| `isInvalidated` | `bool` | `invalidateQueries` の後や、取得が失敗した後は `true` です。新しいデータでリセットされます。 |

`copyWith` は、渡したフィールドを置き換えたコピーを返します。

## 永続化と消去

| メンバー | 型 | 説明 |
|---|---|---|
| `storage` | `QueryStorage?` | コンストラクターに渡したストレージ |
| `restore({mutations})` | `Future<void>` | 永続化されたすべてのクエリを事前に読み取り、渡したミューテーションの保存された実行を再開します。ストレージがなければ何もしません。[事前に復元する](../../guides/persistence/#事前に復元する)を参照してください。 |
| `clear()` | `void` | すべてのキャッシュエントリとミューテーションの実行を削除し、永続化されたすべてのデータを削除します。クライアントと、そのキーごとのデフォルトは残ります。[ログアウト時にすべてを消去する](../../guides/query-client/#ログアウト時にすべてを消去する)を参照してください。 |
