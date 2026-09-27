---
title: 再取得とオフライン
description: Flutter アプリが再開したときに古いデータを再取得し、オフラインの間は一時停止し、ネットワークに再接続したら再開します。
sourceHash: 6f8b1b989a7f
---

アプリがフォアグラウンドに戻ったときと、ネットワークに再接続したときに、Fuery は古い（stale）データを再取得します。そのため、引っ張って更新しなくても、画面が最新の状態に追いつきます。Fuery のウィジェット、フック、`FueryProvider` が、アプリのライフサイクルを自動で接続します。接続状態については、`onlineManager.setEventListener` でソースを接続してください。

## アプリが再開したとき

Fuery は、各 `AppLifecycleState` を次のようにフォーカスに対応づけます。

| アプリの状態 | Fuery の扱い |
|---|---|
| `resumed` | フォーカスあり |
| `hidden`、`paused`、`detached` | フォーカスなし |
| `inactive` | 変わりません。システムダイアログのような短い中断は数に入りません。 |

- アプリが再びフォーカスされると、Fuery は使用中の古いクエリをすべて再取得します。使用中のクエリとは、マウントされたウィジェットが表示しているクエリなどです。
- アプリがフォーカスされていない間、再試行は待機します。
- クエリが `refetchIntervalInBackground` を設定していない限り、ポーリングもバックグラウンドでは止まります。
- `refetchOnFocus` は、アプリが再びフォーカスされたときに再取得するかどうかをクエリごとに設定します。値は `RefetchMode.ifStale`（デフォルト）、`RefetchMode.always`、`RefetchMode.never` です。

`FueryFocusManager` である `focusManager` が、フォーカスの状態を保持します。追跡するのはアプリがフォアグラウンドにあるかどうかで、キーボードのフォーカスではありません。

| メンバー | 説明 |
|---|---|
| `setFocused(false)` | アプリがバックグラウンドにあると報告します。テストでは、バックグラウンドへの移行をシミュレートするのに使います。 |
| `setFocused(null)` | 手動で設定した状態を破棄します。イベントソースが変化を報告するまで、アプリはフォーカスありとみなされます。 |
| `isFocused` | Fuery がアプリをフォーカスありとして扱っているかどうかを示します。何かが別の状態を報告するまでは `true` です。 |
| `setEventListener(setup)` | フォーカスのソースを置き換えます。Flutter では、先に `FueryBinding.ensureInitialized()` を呼び出してください。呼び出さないと、最初の Fuery ウィジェット、フック、または `FueryProvider` が、設定したソースをアプリのライフサイクルで置き換えます。Flutter 以外では、ホストが提供するものを接続してください。`setup` は、`true` か `false`、またはリスナーに再び通知するための値なしで呼び出すコールバックを受け取ります。`setup` はクリーンアップ関数か `null` を返します。 |

`FueryProvider` を使わず、Bloc からだけクエリを使うアプリには、ライフサイクルを接続するものがありません。起動時に次を 1 回呼び出してください。

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## ネットワークに再接続したとき

ソースが別の状態を報告するまで、Fuery はデバイスをオンラインとして扱います。オフラインの間は取得を一時停止し、再接続時に再取得するには、[`connectivity_plus`](https://pub.dev/packages/connectivity_plus) などの接続状態のソースを接続してください。

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

デバイスがオフラインの間は、次のように動作します。

- 取得が必要なクエリは `FetchStatus.paused` を報告し、データを表示し続けます。
- オフラインで開始したミューテーションは待機し、接続が戻ると実行されます。

接続が戻ると、Fuery はまず一時停止中のミューテーションを再開します。ミューテーションが終わってから、Fuery はクエリを再取得します。そのため、再取得が楽観的更新を上書きすることはありません。最初のデータをまだ読み込んでいるクエリは待たず、すぐに再開します。アプリがフォアグラウンドに戻ったときも、Fuery は同じ手順を実行します。

`onlineManager` が接続状態を保持します。

| メンバー | 説明 |
|---|---|
| `setEventListener(setup)` | 接続状態のソースを接続します。`setup` は `setOnline` を受け取り、クリーンアップ関数か `null` を返します。新しいソースは前のソースを置き換えます。 |
| `setOnline(online)` | 接続状態を手動で報告します。たとえば、デバッグ用のスイッチやテストから使います。 |
| `isOnline` | Fuery がデバイスをオンラインとして扱っているかどうかを示します。ソースが別の状態を報告するまでは `true` です。 |

`networkMode` は、クエリやミューテーションが接続状態にどう反応するかを設定します。

| モード | 動作 |
|---|---|
| `NetworkMode.online` | デフォルトです。オンラインの間だけ取得し、再試行します。 |
| `NetworkMode.always` | 接続状態を無視します。たとえば、ローカルデータベースに使います。このモードのクエリは、`refetchOnReconnect` が設定されている場合にだけ、再接続時に再取得します。 |
| `NetworkMode.offlineFirst` | 最初の試行は接続状態に関係なく実行し、オフラインの間は再試行を一時停止します。キャッシュ層がオフラインでも応答できるリクエストに向いています。 |

## オフラインで一時停止したミューテーションを再開する

オフラインで一時停止したミューテーションは、アプリが再びフォーカスされたときか、ネットワークに再接続したときに Fuery が再開します。別のタイミングで再開するには、`resumePausedMutations` を呼び出してください。

```dart
await client.resumePausedMutations();
```

- クライアントの一時停止中のミューテーションをすべて再開します。
- デバイスがオフラインの間は何もしません。
- 一時停止中のミューテーションは、`persist` を持っていない限り、アプリの再起動で失われます。[ミューテーションを永続化する](../persistence/#ミューテーションを永続化する)を参照してください。

## サンプルアプリでは

[ホームシェル](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)の Wi-Fi ボタンが、接続状態のソースの代わりになります。このボタンは `onlineManager.setOnline` で接続状態を報告します。[投稿画面](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)でオフライン中に書いたコメントは一時停止し、アプリがオンラインに戻ると送信されます。
