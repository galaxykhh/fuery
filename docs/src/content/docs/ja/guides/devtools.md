---
title: Devtools
description: アプリの実行中に、デバイスやブラウザーで Flutter のクエリキャッシュを確認します。
sourceHash: 32877fd7d403
---

`FueryDevtools` は、アプリの実行中にクライアントのキャッシュの中身を表示します。クエリごとにステータスとデータを表示し、クエリを再取得、無効化、リセット、削除するボタンも表示します。ミューテーションの実行ごとに、ステータス、変数、エラーを表示します。アプリの上には、パネルを開くボタンを追加します。

## devtools を追加する

`FueryDevtools` をアプリの `builder` に入れてください。こうすると、すべてのルートの上に表示され続けます。

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

devtools はデバッグビルドとプロファイルビルドで表示されます。リリースビルドでは、アプリだけが表示されます。

サンプルアプリは、[アプリのウィジェット](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/app.dart)で devtools を追加しています。

## Queries タブ

Queries タブは、キャッシュにあるすべてのクエリを、キーごとに 1 行で一覧表示します。各行には、ステータスと[オブザーバー](../../how-the-cache-works/#オブザーバー)の数が表示されます。クエリを受け取った各ウィジェットと、`observe()` で作った各オブザーバーが、それぞれ 1 つと数えられます。キーを探すには、フィルターに入力してください。

| ステータス | 意味 |
|---|---|
| `fetching` | 取得を実行中です。 |
| `paused` | 取得がネットワークを待っているか、再試行のためにアプリがフォアグラウンドに戻るのを待っています。 |
| `inactive` | どのオブザーバーも使っていません。Fuery は `gcTime` の後に削除します。 |
| `disabled` | すべてのオブザーバーが `enabled: false` なので、自動では取得しません。 |
| `stale` | 使用中です。次にウィジェットが使い始めたとき、アプリがフォアグラウンドに戻ったとき、またはネットワークに再接続したときに、Fuery が再取得します。 |
| `fresh` | 使用中で、データが `staleTime` 以内に更新され、無効化されていません。 |

クエリを選択すると、ステータス、オブザーバー、最終更新、失敗回数、エラー、データが表示されます。データは JSON で表示されます。オブジェクトに `toJson()` があればそれを使い、なければ `toString()` を使います。

ボタンは、選択したクエリに対して動作します。

| ボタン | 説明 |
|---|---|
| Refetch | [`refetchQueries`](../../reference/query-client/#一致するクエリへの操作) と同じように、もう一度取得します。`refetchQueries` は、オフのクエリ、データのある静的なクエリ、`setQueryData` だけが書き込んだクエリをスキップします。 |
| Invalidate | 古い状態にします。有効なオブザーバーが使っている場合は、Refetch と同じように Fuery が再取得します。 |
| Reset | 初期状態に戻し、[永続化されたデータ](../persistence/)を削除します。有効なオブザーバーが使っている場合は、Refetch と同じように Fuery が再取得します。 |
| Remove | キャッシュから削除し、永続化されたデータも削除します。まだ使っているウィジェットは、もう一度読み込みます。 |

## Mutations タブ

Mutations タブは、すべての[ミューテーションの実行](../../how-the-cache-works/#ミューテーションの実行)を新しい順に一覧表示します。各実行のステータス、キー、変数、エラーも表示します。

## FueryDevtools のオプション

| オプション | 型 | デフォルト | 説明 |
|---|---|---|---|
| `child` | `Widget` | 必須 | アプリ |
| `client` | `QueryClient?` | `context.queryClient` | 確認するクライアント |
| `enabled` | `bool` | `!kReleaseMode` | アプリ以外に何かを表示するかどうか |
| `buttonAlignment` | `Alignment` | `Alignment.centerRight` | ボタンの位置 |
| `initiallyOpen` | `bool` | `false` | パネルを開いた状態で始めるかどうか |

## ボタンなしのパネル

`FueryDevtoolsPanel` は、ボタンのない同じパネルです。デバッグメニューなど、独自の画面に表示してください。

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const Scaffold(
      body: SafeArea(child: FueryDevtoolsPanel()),
    ),
  ),
);
```

`FueryDevtoolsPanel` は、`client`（デフォルトは `context.queryClient`）と `onClose` コールバックを受け取ります。`onClose` を渡すと、閉じるボタンが追加されます。
