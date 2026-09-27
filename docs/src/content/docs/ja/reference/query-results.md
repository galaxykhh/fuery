---
title: クエリの結果
description: Flutter で Fuery のウィジェット、フック、ストリームがクエリについて受け取る内容です。ステータス、データ、エラー、取得のフラグ、無限クエリのページを扱います。
sourceHash: 6744567777c2
---

すべてのクエリのウィジェット、`useQuery`、オブザーバーのストリームは `QueryResult` を受け取ります。無限クエリは `InfiniteQueryResult` を報告します。`InfiniteQueryResult` には、ページとページのアクションが加わります。どのフィールドを読み取るかは、知りたいことによって決まります。

- **表示する内容**：`data` が `null` でなければ `data` を表示します。次に `error`、最後にローディングインジケーターです。再取得が失敗しても、前の `data` は残ります。
- **リクエストが実行中かどうか**：`isFetching` を読み取ります。データを表示している間のバックグラウンドの再取得なら、`isRefetching` を読み取ります。
- **失敗した理由**：取得が再試行をやめた後は `error` を読み取ります。まだ再試行している間は、`failureReason` と `failureCount` を読み取ります。

## QueryResult のフィールド

2 つの enum が状態を表し、ほかのフィールドがデータと最新の取得を表します。

| フィールド | 型 | 意味 |
|---|---|---|
| `status` | `QueryStatus` | `pending`、`error`、`success` のいずれかです。[QueryStatus と FetchStatus](#querystatus-と-fetchstatus) を参照してください。 |
| `fetchStatus` | `FetchStatus` | `fetching`、`paused`、`idle` のいずれか |
| `data` | `TData?` | 最新のデータです。最初のデータの前は `null` です。再取得が失敗しても残ります。 |
| `error` | `Object?` | 最後に失敗した取得のエラーです。取得が成功すると `null` に戻ります。データのないクエリが再び取得している間も `null` です。 |
| `dataUpdatedAt` | `int` | `data` が最後に変わった時刻（エポックからのミリ秒）です。一度も変わっていなければ `0` です。 |
| `errorUpdatedAt` | `int` | `error` が最後に設定された時刻（エポックからのミリ秒）です。一度も設定されていなければ `0` です。 |
| `errorUpdateCount` | `int` | 取得が失敗した回数 |
| `failureCount` | `int` | 最新の取得で失敗した試行の数（再試行を含む）です。取得の開始時と成功時に `0` に戻ります。 |
| `failureReason` | `Object?` | 最後に失敗した試行のエラーです。`failureCount` と一緒に消去されます。 |
| `isFetched` | `bool` | クエリが少なくとも 1 回、取得を終えたか、`setData` からデータを受け取ったかどうか |
| `isFetchedAfterMount` | `bool` | `isFetched` と同じです。ただし、このオブザーバーが最初のリスナーを得てからの分だけを数えます。 |
| `isPlaceholderData` | `bool` | `data` が `placeholderData` から来ているかどうかを示します。その間、`status` は `success` です。 |
| `isStale` | `bool` | データが `staleTime` より古いか、無効化されたか、存在しないために、次のきっかけで再取得されるかどうかを示します。オフのクエリでは常に `false` です。 |
| `isEnabled` | `bool` | `enabled` が `false` ではなく、クエリが自動で取得するかどうか |
| `observer` | `QueryObserver<TData>?` | 結果を報告したオブザーバーです。テストなどで `QueryResult` のコンストラクターから作った結果では `null` です。 |

残りのフィールドは、上のフィールドから判定します。

| 判定 | 型 | `true` になる条件 |
|---|---|---|
| `isPending`、`isSuccess`、`isError` | `bool` | `status` がその値であるとき |
| `hasData` | `bool` | `data` が `null` でないとき |
| `isFetching`、`isPaused` | `bool` | `fetchStatus` がその値であるとき |
| `isLoading` | `bool` | 最初の読み込み。つまり pending かつ fetching のとき |
| `isRefetching` | `bool` | データを表示している間に取得が実行されているとき |
| `isLoadingError` | `bool` | データが届く前に取得が失敗したとき |
| `isRefetchError` | `bool` | データを表示している間に取得が失敗したとき |

### QueryStatus と FetchStatus

| 値 | 意味 |
|---|---|
| `QueryStatus.pending` | まだデータもエラーもありません。 |
| `QueryStatus.error` | 最新の取得が失敗しました。`data` には以前のデータが残ります。 |
| `QueryStatus.success` | クエリにデータがあり、最新の取得は失敗していません。 |
| `FetchStatus.fetching` | クエリ関数が実行中です。 |
| `FetchStatus.paused` | 取得がネットワークを待っているか、再試行がネットワークまたはアプリのフォアグラウンドへの復帰を待っています。 |
| `FetchStatus.idle` | 何も取得していません。 |

## QueryResult のアクション

`refetch()` はクエリを再実行し、`Future<QueryResult<TData>>` を返します。引っ張って更新や、再試行ボタンから呼び出してください。

```dart
RefreshIndicator(
  onRefresh: () => state.refetch(),
  child: TodoList(state.data ?? const []),
)
```

| 引数 | 型 | デフォルト | 説明 |
|---|---|---|---|
| `cancelRefetch` | `bool` | `true` | クエリにデータがあるとき、実行中の取得をキャンセルして新しい取得を始めます。`false` の場合、またはデータがない場合は、実行中の取得に合流します。 |
| `throwOnError` | `bool` | `false` | `true` にすると、返される Future が取得のエラーで失敗します。そうでなければ、エラーは結果にだけ入ります。 |

- 返された Future は、取得が完了した後に結果で完了します。
- オブザーバーの現在のクエリを再取得します。ウィジェットが別のキーに移った後なら、新しいキーのクエリです。
- `enabled` が `false` でも取得します。
- コンストラクターで作った結果にはオブザーバーがないので、その `refetch()` は `StateError` をスローします。

## InfiniteQueryResult のフィールド

`InfiniteQueryResult` は、`data` を `InfiniteData<TPage, TParam>` として、[`QueryResult` のすべてのフィールド](#queryresult-のフィールド)を持ちます。さらに、次のフィールドがあります。

| フィールド | 型 | 意味 |
|---|---|---|
| `pages` | `List<TPage>` | 読み込んだページです。最初のページの前は空のリストです。`data` は同じページをパラメーターとともに持っています。 |
| `hasNextPage` | `bool` | `getNextPageParam` がパラメーターを返したかどうかを示します。最初のページを読み込むまでは `false` です。 |
| `hasPreviousPage` | `bool` | `getPreviousPageParam` がパラメーターを返したかどうかを示します。このオプションがなければ `false` です。 |
| `isFetchingNextPage` | `bool` | `fetchNextPage()` が実行中かどうか |
| `isFetchingPreviousPage` | `bool` | `fetchPreviousPage()` が実行中かどうか |
| `isFetchNextPageError` | `bool` | 最新の取得が `fetchNextPage()` で、失敗したかどうか |
| `isFetchPreviousPageError` | `bool` | 最新の取得が `fetchPreviousPage()` で、失敗したかどうか |
| `observer` | `InfiniteQueryObserver<TPage, TParam>?` | `QueryResult` と同じく、結果を報告したオブザーバー |

`isRefetching` と `isRefetchError` は、すべてのページの再取得を対象にします。そのため、1 ページだけを読み込んでいる間や、1 ページの読み込みが失敗したときは、どちらも `false` のままです。

## InfiniteQueryResult のアクション

`fetchNextPage()` は読み込んだ最後のページの次のページを、`fetchPreviousPage()` は最初のページの前のページを読み込みます。どちらも [`refetch()`](#queryresult-のアクション) と同じ引数を受け取り、ページを読み込んだ後に結果を返します。

- クエリにデータがあると、`hasNextPage`（または `hasPreviousPage`）が `false` のときは何もしません。
- データがないときは、クエリを最初のページから読み込むか、すでに実行中の読み込みに合流します。
- 同じページを読み込んでいる間の呼び出しは、その取得に合流します。
- デフォルトの `cancelRefetch: true` では、呼び出しはまず、すべてのページの再取得など、ほかの取得をキャンセルします。`false` では、その取得に合流し、ページを読み込みません。

`refetch()` は、読み込んだすべてのページを順番に読み込み直します。[読み込んだすべてのページを再取得する](../../guides/infinite-queries/#読み込んだすべてのページを再取得する)を参照してください。

## InfiniteData のフィールド

`InfiniteData<TPage, TParam>` は無限クエリの `data` です。`getNextPageParam` と `getPreviousPageParam` も、この型を受け取ります。

| メンバー | 型 | 内容 |
|---|---|---|
| `pages` | `List<TPage>` | 読み込んだすべてのページ（ページ順） |
| `pageParams` | `List<TParam>` | 各ページを読み込んだときのパラメーター。インデックスはページと同じです。 |
| `firstPage`、`lastPage` | `TPage` | 読み込んだ最初のページと最後のページ |
| `firstPageParam`、`lastPageParam` | `TParam` | 最初のページと最後のページのパラメーター |
| `mapPages(transform)` | `InfiniteData<TPage, TParam>` | 各ページを `transform` の戻り値に置き換えた同じデータ。パラメーターは変わりません。[キャッシュされたページの項目を更新する](../../guides/infinite-queries/#キャッシュされたページの項目を更新する)を参照してください。 |

ページがないと、`firstPage`、`lastPage`、`firstPageParam`、`lastPageParam` は `StateError` をスローします。`setData` や `initialData` でページを書き込むには、`InfiniteData(pages: ..., pageParams: ...)` でデータを作成してください。パラメーターはページごとに 1 つです。
