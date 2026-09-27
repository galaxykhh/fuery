---
title: テスト
description: キャッシュを使う Flutter のウィジェット、Bloc、クエリを、フェイクの時間と新しいクライアントでテストします。
sourceHash: 05dd3c02e901
---

テストには、空のキャッシュと時間の制御が必要です。各テストに、再試行をオフにした新しい `QueryClient` を用意し、フェイククロックで実行してください。

## ウィジェットをテストする

各テストに新しいクライアントを用意し、失敗がすぐにわかるように再試行をオフにしてください。

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  Fuery.client = client;
  await tester.pumpWidget(const App());
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  client.clear();
});
```

- **フェイクの API にかかる時間だけ pump してください**。すぐに応答するフェイクなら、`await tester.pump()` だけで十分です。
- **各テストの最後に、ウィジェットをアンマウントし、`client.clear()` を呼び出してください**。そうしないと、キャッシュのガベージコレクションのタイマーが残ったままになり、[テストが失敗します](../../troubleshooting/#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed)。
- **再試行をオフにする必要があるのはクエリだけです**。ミューテーションは `retry` を設定しない限り再試行しないので、`QueryDefaults` で十分です。`mutations: MutationDefaults(...)` を追加するのは、テストにミューテーション独自のデフォルトが必要な場合だけにしてください。
- **`FueryProvider` も使えます**。ウィジェットは最も近い `FueryProvider` のクライアントを使うので、`Fuery.client` への代入の代わりに `FueryProvider(client: client, child: const App())` を使えます。ただし、`observe()` と、定義の `mutate` と `mutateAsync` は、クライアントを渡さない限り `Fuery.client` を使います。そのため、テストや Cubit が作るオブザーバーには `observe(client: client)` が必要です。定義からミューテーションを実行するウィジェットは、`context.queryClient` を渡します。
- **オブザーバーはテストの中で作ってください**。オブザーバーは自身のクライアントを保持するので、ファイルのトップレベルで作ったオブザーバーは[最初のテストのクライアントを保持し続けます](../../troubleshooting/#最初に実行したときだけテストが通る)。

## ウィジェットツリーを使わずにテストする

通常の Dart のテストで時間を制御するには、[`fake_async`](https://pub.dev/packages/fake_async) を開発用の依存関係に追加してください。

```dart
test('loads todos', () {
  fakeAsync((async) {
    final client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => ['Buy milk'],
    ).observe(client: client);

    final subscription = todos.stream.listen((_) {});
    async.flushMicrotasks();
    expect(todos.result.data, ['Buy milk']);

    subscription.cancel();
    client.clear();
  });
});
```

`stream` をリッスンすると、オブザーバーが購読し、取得を開始します。待機するフェイクの場合は、`flushMicrotasks()` の代わりに `async.elapse(...)` でクロックを進めてください。

## Cubit と Bloc をテストする

クエリを使う Cubit や Bloc は、上のテストと同じく、`testWidgets` か `fakeAsync` の中でテストしてください。

- **`close()` では、`subscription.cancel()` を `await` せずに呼び出してください**。フェイククロックでは、`cancel()` が返す Future が完了せず、テストが止まったままになります。
- **`client.clear()` の前に Cubit を閉じてください**。`clear()` は、まだ購読しているオブザーバーを新しいクエリに移し、そのクエリが再び読み込みます。

## バックグラウンドのアプリをテストする

`focusManager.setFocused(false)` を呼び出すと、Fuery はアプリを[バックグラウンドにある](../lifecycle/#アプリが再開したとき)ものとして扱います。再試行は待機し、`refetchIntervalInBackground` が設定されていない限り、ポーリングは一時停止します。`focusManager.setFocused(null)` は、フォーカスの判断をアプリのライフサイクルに戻します。すると、Fuery は使用中の古いクエリを再取得します。

ファイル内のすべてのテストが `focusManager` を共有するので、ティアダウンでリセットしてください。ティアダウンは、ウィジェットがなくなった後に実行されます。テストが失敗したときも実行されます。

```dart
addTearDown(() => focusManager.setFocused(null));
```

## サンプルアプリでは

サンプルアプリのテストは、[小さなヘルパー](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test/helpers.dart)でタブや投稿を開きます。[テストフォルダー](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test)には、画面ごとのウィジェットテストがあります。
