---
title: 無限クエリ
description: Flutter で、ページをキャッシュしながら、ページネーションと無限スクロールのリストを作ります。
sourceHash: 65b525494abc
head:
  - tag: title
    content: Flutter の無限スクロールとページネーション | Fuery
---

無限クエリは、1 つのキーでページのリストを保持し、要求に応じて次のページを読み込みます。フィードや終わりのないリストに使ってください。番号付きのページが互いに入れ替わる場合は、[プレースホルダーデータ](../queries/#前のページを表示したままにする)を使う通常のクエリのほうが適しています。

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);
```

`queryFn` は、`context.pageParam` が指すページを読み込みます。最初のページパラメーターは `initialPageParam` です。`getNextPageParam` は、最後のページの次のページのパラメーターを返します。それ以上ページがない場合は `null` を返します。ほかのオプションと、ページパラメーターの関数が失敗したときの Fuery の動作は、[InfiniteQuery のオプション](../../reference/query-options/#infinitequery-のオプション)にあります。

[プレイグラウンドで試す](/fuery/demo/#/infinite)：ページを 1 つずつ読み込み、`hasNextPage` と `isFetchingNextPage` を確認してください。

## ページを表示する

`InfiniteQueryBuilder` は、読み込んだページと、フッターに必要なフラグをビルダーに渡します。

```dart
InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.isFetchingNextPage)
        const Center(child: CircularProgressIndicator())
      else if (state.isFetchNextPageError)
        TextButton(
          onPressed: state.fetchNextPage,
          child: const Text('Loading more failed. Retry'),
        )
      else if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : state.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

フッターは、`isFetching` ではなく `isFetchingNextPage` を読み取ります。そのため、リスト全体をバックグラウンドで再取得しても、ボタンがスピナーに置き換わることはありません。ビルダーが読み取れるすべてのフラグの一覧は [InfiniteQueryResult のフィールド](../../reference/query-results/#infinitequeryresult-のフィールド)にあります。

スクロールのリスナーは、`state.fetchNextPage()` を何度呼び出してもかまいません。

- クエリにデータがあり、`hasNextPage` が false の場合、呼び出しは何もしません。
- 次のページの読み込み中に呼び出すと、そのページを再び取得せずに、読み込みの完了を待ちます。
- 呼び出しは、すべてのページのバックグラウンド再取得など、実行中のほかの取得をキャンセルします。その取得を完了させるには、上のフッターのように、`isFetching` が true の間はボタンを無効にしてください。`cancelRefetch: false` でも取得は完了しますが、その場合、呼び出しはページを読み込みません。

`fetchPreviousPage()` は、`hasPreviousPage` を使って同じように動作します。引数の一覧は [InfiniteQueryResult のアクション](../../reference/query-results/#infinitequeryresult-のアクション)にあります。

## キャッシュされたページの項目を更新する

`mapPages` は、パラメーターを保ったまま、すべてのページを置き換えます。楽観的更新などで、ページを読み込み直さずに 1 つの項目を変更するときに使ってください。

```dart
client.updateData(
  posts,
  (data) => data?.mapPages((page) => page.withPost(updatedPost)),
);
```

`fetchNextPage()` や `fetchPreviousPage()` がページを読み込んでいる間に書き込んだ内容を、Fuery は保持します。書き込みが、読み込まれているページの構成を変えていない限り、Fuery はページが届いた時点のページに新しいページを追加します。

すべてのページの再取得は、読み込んだ内容でページを置き換えます。そのため、楽観的更新では[最初に再取得をキャンセルします](../mutations/#楽観的更新)。

## 無限クエリを関数にまとめる

`InfiniteQuery<TPage, TParam>` は、1 つ目にページの型、2 つ目にページパラメーターの型を指定します。Fuery は、ページの型を `queryFn` から、パラメーターの型を `initialPageParam` から推論します。[クエリを整理する](../organizing-queries/)で勧めているようにクエリを関数に移すときは、戻り値の型に両方を書いてください。

```dart
// lib/data/post_queries.dart
InfiniteQuery<PostPage, int> postsQuery() => InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) => api.getPosts(page: context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    );
```

ウィジェットの外では、`postsQuery().observe()` が `InfiniteQueryObserver<PostPage, int>` を返します。このオブザーバーにも `fetchNextPage()` があります。

## カーソルベースのページ

次のページのカーソルを返す API も、同じように扱えます。最初のリクエストにカーソルがない場合、`initialPageParam` は `null` です。しかし、`null` からはカーソルの型がわかりません。代わりに型を宣言してください。1 つ目にページの型、2 つ目にカーソルの型を指定した `InfiniteQuery<ItemPage, String?>` を返す関数に、クエリをまとめます。

```dart
InfiniteQuery<ItemPage, String?> itemsQuery() => InfiniteQuery(
      queryKey: ['items'],
      queryFn: (context) => api.getItems(cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
    );
```

すると、`context.pageParam` は `String?`、`data.lastPage` は `ItemPage` になります。

## 前のページを取得する

最新のメッセージから開くチャットのように、途中から開くリストでは、`getPreviousPageParam` を追加し、`state.fetchPreviousPage()` を呼び出してください。次のページ用のフラグがフッターを制御するのと同じように、`hasPreviousPage` と `isFetchingPreviousPage` がヘッダーを制御します。

## メモリに残すページの数を制限する

`maxPages` は、キャッシュするページの数の上限です。上限に達しているとき、次のページを読み込むと最初のページが削除され、前のページを読み込むと最後のページが削除されます。

```dart
InfiniteQuery<MessagePage, String?> messagesQuery(String roomId) =>
    InfiniteQuery(
      queryKey: ['messages', roomId],
      queryFn: (context) => api.getMessages(roomId, cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
      getPreviousPageParam: (data) => data.firstPage.previousCursor,
      maxPages: 5,
    );
```

`getPreviousPageParam` も指定してください。指定しないと、`fetchPreviousPage()` が要求するパラメーターがありません。そのため、先頭から削除されたページは二度と戻りません。

## 読み込んだすべてのページを再取得する

無限クエリの再取得は、読み込んだすべてのページを順に読み込み直します。Fuery は最初のページのパラメーターから始め、次のページごとに `getNextPageParam` にパラメーターを求めます。そのため、項目がページ間で移動していても、ページの内容に食い違いは生じません。`getNextPageParam` が `null` を返すと、再取得は途中で止まります。

## サンプルアプリでは

サンプルアプリの[フィード](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)は、リストが終わり近くまでスクロールされると、フィードを 1 ページずつ読み込みます。サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) に、各画面で示している内容の一覧があります。
