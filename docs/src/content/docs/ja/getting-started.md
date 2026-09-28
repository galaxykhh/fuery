---
title: はじめに
description: Flutter アプリに Fuery をインストールし、キャッシュした最初の API リクエストを画面に表示して、テストします。
sourceHash: fa4345dc8bbf
---

このページの 5 つのステップを終えると、画面が API から取得したリストを、読み込み中とエラーの状態付きで表示します。ほかのすべての画面はキャッシュされたリストを再利用し、ウィジェットテストがその動作を確認します。

## 始める前に

- Flutter 3.27 以降と Dart 3.6 以降
- このページのコードは、アプリに次の 2 つの名前があることを前提にしています。
  - `api`：`var api = Api();` のようなトップレベル変数です。`getTodos()` が `Future<List<Todo>>` を返します。テストではフェイクに置き換えます。
  - `TodoList`：各 Todo のタイトルを `Text` で表示するウィジェットです。

## 1. Fuery をインストールする

```bash
flutter pub add fuery
```

`fuery` には `fuery_core` が含まれているので、Flutter アプリに必要なパッケージはこれだけです。サーバーや CLI など、Flutter を使わない Dart コードでは、代わりに `dart pub add fuery_core` を使ってください。

Fuery は Dart と Flutter 以外に依存しません。`fuery` が追加するのは `fuery_core` だけで、`fuery_core` が依存するのは Dart チームの `clock`、`collection`、`meta` だけです。ネイティブコードもプラットフォームごとの設定もないため、Fuery は Web を含め、Flutter が対象とするすべてのプラットフォームで動作します。

## 2. クエリを定義する

クエリには、データに名前を付ける**キー**と、データを取得する**クエリ関数**が必要です。

```dart
import 'package:fuery/fuery.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

`package:fuery/fuery.dart` は `fuery_core` もエクスポートします。そのため、このページに出てくる Fuery の名前は、この 1 つのインポートですべて使えます。

クエリを定義しても、何も始まりません。取得は、ウィジェットがクエリを表示したときに始まります。そのため、定義はこの例のようにトップレベルの値にしても、`build` の中で作ってもかまいません。

## 3. 画面に表示する

クエリを `QueryBuilder` に渡してください。`QueryBuilder` はマウント時に取得し、新しい結果が届くたびにリビルドします。

```dart
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: todosQuery,
      builder: (context, state) => switch (state) {
        QueryResult(:final data?) => TodoList(data),
        QueryResult(:final error?) => Text('$error'),
        _ => const CircularProgressIndicator(),
      },
    );
  }
}
```

データの分岐が先頭にあります。更新が失敗してもリストは画面に残り、エラーは表示するデータがないときだけ表示されます。

フックを使う場合は、独立したパッケージの [`fuery_hooks`](../guides/hooks/) が、`HookWidget` の中で `useQuery(todosQuery)` を使って同じクエリを描画します。

## 4. アプリを実行する

アプリでこの画面を表示して、実行してください。

```dart
void main() => runApp(const MaterialApp(home: TodoListScreen()));
```

最初のフレームには `CircularProgressIndicator` が表示されます。`api.getTodos()` が返ると、`CircularProgressIndicator` の代わりにリストが表示されます。

`todosQuery` を表示する別の画面は、最初のフレームからキャッシュされたリストを表示します。ローディングインジケーターは表示されません。

## 5. テストする

アプリの `Api` を実装する `FakeApi` クラスを書いてください。その `getTodos()` は 300 ミリ秒待ってから、タイトルが「Buy milk」の Todo を 1 つ返します。

次に、`test/` 以下のファイルにこのテストを追加してください。このテストは `api` をフェイクに置き換え、読み込み中の状態とリストを確認します。`api`、`FakeApi`、`TodoListScreen` を宣言しているファイルもインポートしてください。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  testWidgets('shows todos', (tester) async {
    api = FakeApi();

    await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // the fake request
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Fuery.client.clear();
  });
}
```

最後の 2 行で画面をアンマウントし、キャッシュを空にします。これで、ガベージコレクションのタイマーがテストより長く残ってテストを失敗させることはありません。`addTearDown` は `testWidgets` がタイマーを確認した後に実行されるので、この 2 行はテスト本体に書いてください。

テストごとに新しいクライアントを使う方法、再試行をオフにする方法、Cubit と純粋な Dart のコードをテストする方法は、[テスト](../guides/testing/)で紹介しています。

## Fuery が引き受けたこと

- **型は関数から決まります**。`api.getTodos()` が `Future<List<Todo>>` を返すので、`todosQuery` は `Query<List<Todo>>` になり、ビルダーの `state` は `QueryResult<List<Todo>>` になります。型を明示するのは 2 つの場合です。`client.getQueryData<List<Todo>>(['todos'])` のようにキーだけで読み書きする場合と、最初のページパラメーターが `null` の無限クエリです（[カーソルベースのページ](../guides/infinite-queries/#カーソルベースのページ)を参照してください）。
- **null チェックは不要です**。`QueryResult(:final data?)` はデータがあるときだけ一致するので、その分岐では `data` は `List<Todo>` です。
- **画面はキーでデータを共有します**。`['todos']` を使うすべての画面が、同じキャッシュエントリを読み取ります。取得の実行中にマウントされた画面は、そのリクエストを共有します。
- **古いデータは自動で更新されます**。`staleTime` のデフォルトはゼロなので、データは届いた時点で古く（stale）なります。別の画面がデータを使い始めたときと、アプリがフォアグラウンドに戻ったときに、Fuery はバックグラウンドでデータを再取得します。その間も、古いリストは画面に表示されたままです。

[プレイグラウンドで試す](/fuery/demo/#/shared-cache)：3 つのウィジェットが 1 つのクエリを表示し、1 回のリクエストで 3 つともデータを受け取ります。

データがいつ再取得され、いつメモリから削除されるかは、[キャッシュのしくみ](../how-the-cache-works/)で説明しています。

## 次のステップ

- [TanStack Query を使ってきた方へ](../coming-from-tanstack-query/)：TanStack Query の各概念に対応する Fuery の名前
- [Flutter のサーバー状態](../server-state/)：サーバーデータにキャッシュが必要な理由
- [キャッシュのしくみ](../how-the-cache-works/)：定義、オブザーバー、キャッシュされたデータのライフサイクル
- [クエリ](../guides/queries/)：キー、鮮度、ほかのクエリに依存するクエリ
- [ウィジェット](../guides/widgets/)：ビルダー、リスナー、コンシューマー、セレクター
- [ミューテーション](../guides/mutations/)：楽観的更新を含む、サーバーデータの変更
- [Bloc と Cubit](../guides/bloc/)：Cubit と Bloc の中で同じクエリを使う方法
- [Devtools](../guides/devtools/)：実行中のアプリで確認する、すべてのクエリとミューテーション
