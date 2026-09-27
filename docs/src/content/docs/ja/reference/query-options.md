---
title: クエリのオプション
description: Flutter の Query と InfiniteQuery のすべてのオプションについて、型、デフォルト、変わる動作をまとめています。
sourceHash: d451e877320c
---

`Query` と `InfiniteQuery` のすべてのオプションを、型とデフォルトとともに示します。`InfiniteQuery` はこれらすべてに加えて、[InfiniteQuery のオプション](#infinitequery-のオプション)にあるオプションも受け取ります。すべてのクエリ、またはプレフィックスの配下にあるすべてのキーのデフォルトを変えるには、クライアントに `QueryDefaults` を設定してください。[デフォルト](../query-client/#デフォルト)を参照してください。

オプションを使う例は[クエリ](../../guides/queries/)にあります。

## 取得

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `queryKey` | `List<Object?>` | 必須 | キャッシュエントリの名前を決めます。[クエリキー](../../guides/queries/#クエリキー)を参照してください。 |
| `queryFn` | `Future<TData> Function(QueryFunctionContext)` | 必須 | データを取得します。[クエリ関数のコンテキスト](#クエリ関数のコンテキスト)を受け取ります。 |
| `enabled` | `bool` | `true` | `false` にすると、クエリは自動では取得しなくなります。`refetch()` では取得します。 |
| `meta` | `Map<String, Object?>` | なし | クエリ関数が `context.meta` として読み取る値 |

## 鮮度とキャッシュ

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `staleTime` | `Duration` | ゼロ | データが新鮮（fresh）な状態を保つ時間です。`infiniteDuration` にすると、無効化するまで新鮮なままです。`staticStaleTime` は無効化も無視します。 |
| `gcTime` | `Duration` | 5 分 | ガベージコレクション時間です。何も使っていないキャッシュエントリがメモリに残る時間を表します。キャッシュエントリは、オブザーバーが求める中で最も長い `gcTime` を使います。 |
| `structuralSharing` | `bool` | `true` | 再取得の結果が変わっていないオブジェクトは、キャッシュ済みのものをそのまま使います。[変わった部分だけをリビルドする](../../guides/queries/#変わった部分だけをリビルドする)を参照してください。 |
| `persist` | `QueryPersist<TData>` | なし | クライアントの `storage` でデータをデバイスに保存します。[永続化](../../guides/persistence/)を参照してください。 |

## 再取得

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `refetchOnMount` | `RefetchMode` | `RefetchMode.ifStale` | ウィジェットやストリームがクエリを使い始めたときに再取得します。`.always` は新鮮なデータも再取得します。`.never` は、キャッシュされたデータを再取得せずに表示します。 |
| `refetchOnFocus` | `RefetchMode` | `RefetchMode.ifStale` | アプリがフォアグラウンドに戻ったときに再取得します。 |
| `refetchOnReconnect` | `RefetchMode` | `RefetchMode.ifStale`（`NetworkMode.always` では `.never`） | ネットワークに再接続したときに再取得します。 |
| `refetchInterval` | `Duration` | なし | ウィジェットやストリームがクエリを使っている間、この間隔でポーリングします。間隔は、クエリの最新の変更から数えます。 |
| `refetchIntervalInBackground` | `bool` | `false` | アプリがバックグラウンドにある間もポーリングを続けます。 |
| `refetchWhile` | `bool Function(QueryResult<TData>)` | なし | 最新の結果に対してこの関数が `true` を返す間だけポーリングします。Fuery は、変更のたびと、最初のデータが届く前にこの関数を確認します。 |

## 失敗

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `retry` | `RetryPolicy` | `RetryPolicy.count(3)`（`client.query` では `.never()`） | 失敗した取得を再試行する回数です。`.count(n)`、`.never()`、`.always()`、`.when((failureCount, error) => ...)` のいずれかを指定します。`failureCount` は最初の失敗で 0 です。 |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1 秒、2 秒、4 秒…（最大 30 秒） | 各再試行の前に待つ時間 |
| `retryOnMount` | `bool` | `true` | `false` にすると、データがないまま失敗したクエリは、ウィジェットが使い始めても再び取得しません。 |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `.online` は、デバイスがオフラインの間は取得を一時停止します。`.always` は接続状態を無視します。`.offlineFirst` は最初の試行を実行し、オフラインの間は再試行を一時停止します。[ネットワークに再接続したとき](../../guides/lifecycle/#ネットワークに再接続したとき)を参照してください。 |

## 取得前に表示するデータ

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `initialData` | `TData` | なし | このデータを取得したかのように、キャッシュエントリに初期値として入れます。 |
| `initialDataUpdatedAt` | `int` | 現在時刻 | `initialData` を取得した時刻（エポックからのミリ秒）です。初期データがすでに古い（stale）かどうかを決めます。 |
| `placeholderData` | `TData? Function(TData? previousData, QueryClient client)` | なし | クエリが pending 状態の間に表示するデータです。Fuery はこのデータをキャッシュに書き込みません。オブザーバーが前に表示していたキーのデータと、クライアントを受け取ります。`keepPreviousData` はそのデータを返します。[前のページを表示したままにする](../../guides/queries/#前のページを表示したままにする)を参照してください。 |

## InfiniteQuery のオプション

`InfiniteQuery<TPage, TParam>` は、データ型を `InfiniteData<TPage, TParam>` として、`Query` のすべてのオプションを受け取ります。`TPage` は 1 ページの型、`TParam` はページを指定するパラメーターの型です。オプションを使う例は[無限クエリ](../../guides/infinite-queries/)にあります。

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `queryFn` | `Future<TPage> Function(InfiniteQueryFunctionContext<TParam>)` | 必須 | 1 ページを取得します。取得するのは、`context.pageParam` が指定するページです。 |
| `initialPageParam` | `TParam` | 必須 | 最初のページのパラメーターです。Fuery はこの値から `TParam` を推論します。最初のパラメーターが `null` の場合は、型の宣言が必要です。[カーソルベースのページ](../../guides/infinite-queries/#カーソルベースのページ)を参照してください。 |
| `getNextPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | 必須 | `data.lastPage` の次のページのパラメーターを返します。次のページがなければ `null` を返します。戻り値は `TParam` でなければなりません。[ページパラメーターのエラー](#ページパラメーターのエラー)を参照してください。 |
| `getPreviousPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | なし | `data.firstPage` の前のページのパラメーターか、`null` を返します。このオプションがないと、`hasPreviousPage` は常に `false` です。また、クエリにデータがあると、`fetchPreviousPage()` は何も読み込みません。 |
| `maxPages` | `int` | なし | 保持するページの最大数です。上限に達すると、次のページを読み込むときは最初のページを、前のページを読み込むときは最後のページを破棄します。 |
| `pages` | `int` | 1 | 何もキャッシュされていないときに読み込むページ数です（最大 `maxPages`）。ページがキャッシュされている場合、すべてのページの取得では、代わりにキャッシュされたページを読み込み直します。 |
| `persist` | `InfiniteQueryPersist<TPage, TParam>` | なし | ページをデバイスに保存します。[無限クエリを永続化する](../../guides/persistence/#無限クエリを永続化する)を参照してください。 |
| `refetchWhile` | `bool Function(InfiniteQueryResult<TPage, TParam>)` | なし | `Query` の `refetchWhile` と同じです。ただし、無限クエリの結果を受け取ります。 |

`setData` などで `maxPages` を超えてキャッシュされたページは、次のページか前のページを読み込むまで残ります。読み込むと、ページは `maxPages` まで切り詰められます。再取得では、そのうち最初の `maxPages` ページだけを読み込み直します。

### ページパラメーターのエラー

Dart では、型推論を失わずに `getNextPageParam` と `getPreviousPageParam` の戻り値を検査できません。そのため、Fuery は実行時にパラメーターを検査します。

- Fuery が `hasNextPage` や `hasPreviousPage` を設定するために結果を構築しているときは、別の型のパラメーターをページなしとみなします。空のページでの `data.lastPage.last` など、関数がスローしたエラーも同じです。
- 再取得などでページを読み込んでいるときは、別の型のパラメーターがあると、そのページで読み込みを終えます。関数がスローしたエラーは、取得を失敗させます。

別の型のパラメーターと、結果の構築中にスローされたエラーは、クライアント、関数、キーごとに 1 回、Fuery が [`onUncaughtError`](../../guides/client-setup/#コールバックがスローしたエラーをキャッチする) に報告します。

どちらの関数も、少なくとも 1 ページを受け取ります。そのため、`data.lastPage` と `data.firstPage` は常に存在します。

## クエリ関数のコンテキスト

すべてのクエリ関数は `QueryFunctionContext` を受け取ります。`QueryFunctionContext` はウィジェットツリーのものを何も持ちません。そのため、クエリを作ったウィジェットがなくなった後でも、クエリ関数は実行できます。

| フィールド | 型 | 内容 |
|---|---|---|
| `client` | `QueryClient` | 取得を実行しているクライアント。ほかのキャッシュされたデータを読み取るのに使います。 |
| `queryKey` | `List<Object?>` | 取得しているキー。リクエストの組み立てに使います。 |
| `meta` | `Map<String, Object?>?` | `meta` オプションの値 |
| `signal` | `AbortSignal` | 取得がキャンセルされると中止されます。このシグナルを読み取ると、取得をキャンセルできるようになります。[リクエストをキャンセルする](../../guides/queries/#リクエストをキャンセルする)を参照してください。 |

無限クエリの関数は `InfiniteQueryFunctionContext<TParam>` を受け取ります。`InfiniteQueryFunctionContext` には、読み込むページのパラメーターである `pageParam` が加わります。
