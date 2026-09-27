---
title: クライアントを設定する
description: Flutter の QueryClient を main で 1 回だけ設定します。デフォルト、失敗の報告、必要に応じてサブツリーごとのクライアントも設定します。
sourceHash: 046de5bf4e5b
---

アプリ全体に 1 つの `QueryClient` を設定してください。デフォルトを設定し、すべての失敗を 1 か所で報告し、コールバックがスローしたエラーをキャッチします。何かが[オブザーバー](../../how-the-cache-works/#オブザーバー)を作成する前に、`main` で 1 回だけ設定してください。ウィジェットテストなどでは、アプリの一部を専用のクライアントで動かせます。コンストラクターのすべてのオプションは [QueryClient のリファレンス](../../reference/query-client/#コンストラクターのオプション)にあります。

## クライアントを作成する

`Fuery.client` は、`FueryProvider` がないときにウィジェットが使うクライアントです。クライアントを渡さなければ、`observe()` と定義の `mutate` もこのクライアントを使います。Fuery は最初に使われたときに `Fuery.client` を作成します。そのため、何も設定しないアプリでも動作します。

設定するには、`main` で新しいクライアントを代入してください。

```dart
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const App());
}
```

- `Fuery.client` への代入は、新しいクライアントをマウントし、前のクライアントをアンマウントします。
- マウントされたクライアントは、フォーカス時と再接続時に再取得し、一時停止中のミューテーションを再開します。
- 何かがオブザーバーを作成する前に代入してください。オブザーバーは、作成時のクライアントを使い続けます。
- デフォルトも、オブザーバーができる前に登録してください。オブザーバーはオプションを受け取った時点でデフォルトを適用し、その後は適用しません。

## デフォルトを設定する

クライアントのすべてのクエリとミューテーションに対して、またはキーのプレフィックスに対してデフォルトを設定します。

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    mutations: MutationDefaults(retry: RetryPolicy.count(2)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);

Fuery.client.setMutationDefaults(
  ['todos'],
  const MutationDefaults(networkMode: NetworkMode.offlineFirst),
);
```

- クエリやミューテーションに設定したオプションは、キーごとのデフォルトより優先されます。
- キーごとのデフォルトは、クライアントの `defaultOptions` より優先されます。
- ミューテーションにキーごとのデフォルトが適用されるのは、`mutationKey` がある場合だけです。
- `getQueryDefaults(['settings'])` と `getMutationDefaults(['todos'])` は、一致するすべてのプレフィックスのデフォルトをマージした、キーごとのデフォルトを返します。`defaultOptions` は含みません。

`QueryDefaults` と `MutationDefaults` のフィールドの一覧は[デフォルト](../../reference/query-client/#デフォルト)にあります。

## すべての失敗を 1 か所で報告する

キャッシュに設定を渡すと、すべてのクエリとすべてのミューテーションに対してコールバックを実行できます。たとえば、失敗をクラッシュレポートやログのサービスに報告できます。

```dart
Fuery.client = QueryClient(
  queryCache: QueryCache(
    config: QueryCacheConfig(
      onError: (error, query) => reportError(error, query.queryKey),
    ),
  ),
  mutationCache: MutationCache(
    config: MutationCacheConfig(
      onError: (error, variables, context, mutation) =>
          reportError(error, mutation.options.mutationKey),
    ),
  ),
);
```

- キャッシュは、存在する間ずっと同じ設定を使います。そのため、設定はクライアントの作成時に渡してください。
- `QueryCacheConfig` のコールバックは、取得の後に実行されます。キャンセルされた取得は失敗ではないので、どのコールバックにも届きません。
- `MutationCacheConfig` のコールバックは、[ミューテーション自体のコールバック](../../reference/mutation-options/#コールバック)より先に実行されます。コールバックが Future を返すと、Fuery はその Future を待ちます。
- コールバックは、ミューテーションの各実行を `AnyCachedMutation` として受け取ります。`AnyCachedMutation` の `data`、`variables`、`context` は `Object?` です。ミューテーションは `mutation.options.mutationKey` か `mutation.options.meta` で区別してください。

すべてのコールバックとその実行タイミングは[キャッシュのコールバック](../../reference/query-client/#キャッシュのコールバック)にあります。

## コールバックがスローしたエラーをキャッチする

`onUncaughtError` は、どの呼び出し元もキャッチできない次のエラーを受け取ります。そのため、これらのエラーの記録方法を決められます。

- `QueryCacheConfig` または `MutateOptions` のコールバックがスローしたエラー
- ミューテーションの失敗後に、ミューテーション自体またはその `MutationCacheConfig` の `onError` か `onSettled` がスローしたエラー
- クエリの変更後に Fuery がオブザーバーを更新している間に、`refetchWhile` か `placeholderData` がスローしたエラー
- リスナー（リスナーウィジェット、コンシューマー、フックの `listener`、またはスロットの `listen` か `subscribeToRuns` に渡した関数）がスローしたエラー
- Fuery が実行中に見つけた誤り（誤った型のパラメーターを返すか、結果の構築中にスローする `getNextPageParam`、保存できない永続化の `mutationKey` など）

```dart
Fuery.client = QueryClient(
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

- クエリやミューテーションは、コールバックがスローしなかったかのように続行します。
- Fuery は、同じ誤りをクライアントごとに 1 回だけ報告します。コードが実行されるたびには報告しません。
- `onUncaughtError` がスローすると、そのエラーと受け取ったエラーの両方が現在のゾーンに届きます。

`onUncaughtError` がないと、これらのエラーは現在のゾーンに届き、Flutter が `PlatformDispatcher.onError` に渡します。`PlatformDispatcher.onError` に届いたものをすべて致命的なエラーとして記録するクラッシュレポーターは、これらのエラーをクラッシュとして数えます。実際には、アプリは動き続けています。

`Mutation` と `MutationCacheConfig` のそれ以外のコールバックは、ミューテーションの一部です。`onMutate`、または成功後の `onSuccess` か `onSettled` がスローしたエラーは、ミューテーションを失敗させ、その `onError` に届きます。

## クエリが使うクライアント

`Query` はクライアントを保持しません。そのため、同じ定義がどのクライアントでも動作します。Fuery は、クエリを使う場所でクライアントを選びます。

- 定義を受け取ったウィジェットやフックは、最も近い `FueryProvider` のクライアントを使います。`FueryProvider` がなければ `Fuery.client` を使います。プロバイダーのクライアントが置き換わると、新しいクライアントに追従します。
- `observe()` は、`client:` として渡したクライアントか、その時点の `Fuery.client` を使います。オブザーバーは存在する間ずっとそのクライアントを使い、`observer.client` がそのクライアントを返します。
- 定義の `mutate` と `mutateAsync` は、渡したクライアントか、その時点の `Fuery.client` を使います。ウィジェット内では `context.queryClient` を渡してください。そうすると、実行がウィジェットの読み取るキャッシュに届きます。
- オブザーバーを受け取ったウィジェットやフックは、オブザーバーのクライアントを使います。デバッグビルドでは、そのクライアントがウィジェットやフック自身のクライアントでない場合に警告を出力します。[画面が別のクライアントのキャッシュを読んでいる](../../troubleshooting/#画面が別のクライアントのキャッシュを読んでいる)を参照してください。
- クエリ関数、`placeholderData`、ミューテーションのコールバックは、自身を実行するクライアントを受け取ります。

そのため、クエリはトップレベルの値にできます。`Fuery.client` か `FueryProvider` でテストごとに新しいクライアントを用意するウィジェットテストでは、ほかに何も必要ありません。

## サブツリーに専用のクライアントを持たせる

ウィジェットテストなどでアプリの一部を別のクライアントで動かすには、その部分を `FueryProvider` で囲んでください。クライアントは `State` のフィールドに保持してください。そうすると、サブツリーはマウントされている間、同じクライアントを使い続けます。

```dart
class _SettingsPageState extends State<SettingsPage> {
  final client = QueryClient();

  @override
  Widget build(BuildContext context) {
    return FueryProvider(client: client, child: const SettingsView());
  }
}
```

- クライアントは 1 回だけ作成してください。作成する場所は `main`、`State` のフィールド、またはテストの `setUp` です。
- `build` 内では作成しないでください。`build` で作成した `QueryClient` は、リビルドやホットリロードのたびに新しい空のキャッシュになります。そのため、下のウィジェットは読み込み中に戻り、再び取得します。
- `FueryProvider` はクライアントをマウントし、プロバイダーがなくなるとアンマウントします。そのため、`State` に `dispose` は不要です。

プロバイダーの下のウィジェットは、プロバイダーのクライアントを使います。`context.queryClient` はそのクライアントを返し、プロバイダーがないときは `Fuery.client` を返します。独自のオブザーバーを作るときは、`observe` にこのクライアントを渡してください。

```dart
late final todos = todosQuery.observe(client: context.queryClient);
```

定義の `mutate` にも、`addTodo.mutate('Buy milk', context.queryClient)` のように渡してください。

ほかの状態管理ライブラリ向けの[アダプター](../adapters/)は、`FueryProvider.of(context, listen: true)` でクライアントを参照します。この呼び出しを使うと、プロバイダーのクライアントが置き換わったときにリビルドします。

## サンプルアプリでは

サンプルアプリは、[`main`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/main.dart) でストレージ付きのクライアントを `Fuery.client` に代入し、`runApp` の前に保存されたミューテーションを復元します。各画面で何を示しているかは、サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) にまとめています。
