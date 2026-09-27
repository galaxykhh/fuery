---
title: フック
description: fuery_hooks と flutter_hooks で、build の中からクエリとミューテーションを描画します。
sourceHash: b017d3f6a0d8
head:
  - tag: title
    content: flutter_hooks 向けの useQuery と useMutation | Fuery
---

`fuery_hooks` は、Fuery のクエリとミューテーションを `build` の中で読み取ります。クエリ 1 つにつき呼び出しは 1 回で、ビルダーは使いません。[`flutter_hooks`](https://pub.dev/packages/flutter_hooks) の `HookWidget` の中で動作します。

Fuery 本来のスタイルは[ウィジェット](../widgets/)です。ウィジェットは Flutter の慣習に従い、UI にはビルダー、副作用にはリスナーを使います。フックは、`build` の中でデータを読み取りたい開発者向けです。どちらも同じクエリ、ミューテーション、クライアントを使います。そのため、フックで書いた画面とウィジェットで書いた画面は、同じキャッシュとリクエストを共有します。

`fuery` は Dart と Flutter 以外に依存しません。フックには `flutter_hooks` が必要なので、フックは独立したパッケージにあります。そのパッケージに依存するのは、フックを選んだアプリだけです。

## インストール

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` は `fuery` を再エクスポートします。`fuery` と同じく、Flutter 3.27 以降と Dart 3.6 以降が必要です。

## クエリを読み取る

画面を `HookWidget` にし、クエリを渡して `useQuery` を呼び出してください。

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

class TodoListScreen extends HookWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = useQuery(todosQuery);
    return switch (todos) {
      QueryResult(:final data?) => TodoList(data),
      QueryResult(:final error?) => Text('$error'),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

- `useQuery` は現在の結果を返し、結果が変わるとウィジェットをリビルドします。
- 結果は、`QueryBuilder` が受け取るものと同じ `QueryResult` で、`refetch()` も備えています。
- データのないクエリは最初のビルドで取得を始め、そのビルドですでに pending 状態を表示します。

クエリは、上の例のようなトップレベルの値でも、`useQuery(todoQuery(id))` のように `build` の中で作ったものでもかまいません。フックはクエリのオブザーバーを 1 つ保持し、そのオプションを更新します。そのため、新しいキーは同じフレームで表示されます。

`todosQuery.observe()` を渡さないでください。ビルドのたびに新しいオブザーバーができ、改めて購読して取得します。デバッグビルドでは、フックがキーごとに 1 回警告を出力します。

## ほかのクエリに依存するクエリ

`useQuery` はデータを待ちません。ほかのクエリの値が必要なクエリは、値が得られるまで `enabled` で自身をオフにします。

```dart
Query<List<Post>> postsQuery(int? userId) => Query(
      queryKey: ['posts', userId],
      queryFn: (_) => api.getPosts(userId!),
      enabled: userId != null,
    );

final user = useQuery(userQuery);
final posts = useQuery(postsQuery(user.data?.id));
if (posts.isPending) return const CircularProgressIndicator();
```

| ビルド | `user` | `posts` |
|---|---|---|
| 最初 | 取得中、データなし | キー `['posts', null]`、オフのため何も取得しない |
| ユーザーの到着後 | ID が `7` のデータ | キー `['posts', 7]`、このビルドで取得を開始 |
| 投稿の到着後 | データ | データ |

オフでデータのないクエリは pending です。そのため、`posts.isPending` で両方の待ち状態を扱えます。`posts.isLoading` が true になるのは、リクエストの実行中だけです。

## さらにページを読み込む

`useInfiniteQuery` は、読み込んだページと `fetchNextPage()` を持つ `InfiniteQueryResult` を返します。

```dart
final feed = useInfiniteQuery(feedQuery);

ListView(
  children: [
    for (final post in feed.pages.expand((page) => page.posts)) PostTile(post),
    if (feed.hasNextPage)
      TextButton(onPressed: feed.fetchNextPage, child: const Text('More')),
  ],
)
```

## クエリのリストを読み取る

`useQueries` は、ID ごとのクエリなど、同じデータ型のクエリのリストを受け取り、その結果を順に返します。

```dart
final posts = useQueries([for (final id in ids) postQuery(id)]);
final loaded = posts.where((post) => post.hasData).length;
```

- 各クエリは、キーがリストにある間、リストが並べ替えられてもオブザーバーを保持します。
- 同時に届いた変更は、1 回のリビルドにまとまります。
- `.observe()` ではなく、定義を渡してください。ビルドのたびに新しいオブザーバーができて取得をやり直し、デバッグビルドではフックが警告を出力します。

クエリが数百ある場合は、`useMemoized` でリストを作ってください。そうすれば、同じキーでのリビルドでは同じリストが渡され、`useQueries` はクエリの更新をスキップします。`useMemoized` のキーには、ID と、定義が読み取る `build` 内のほかのすべての値を指定してください。たとえば、`enabled:` に渡す値です。キーに含めなかった値は、リストを作ったときの値のままになります。

```dart
final posts = useQueries(
  useMemoized(() => [for (final id in ids) postQuery(id)], ids),
);
```

## データを変更する

ほかのウィジェットと同じく、ミューテーションは定義から実行し、`useQueryClient()` で得たクライアントを渡してください。実行は [`useMutationState`](#ミューテーションのすべての実行を表示する) で読み取ります。

```dart
final client = useQueryClient();
final adding = useMutationState(addTodoMutation).any((run) => run.isPending);

ElevatedButton(
  onPressed: adding ? null : () => addTodoMutation.mutate('Buy milk', client),
  child: const Text('Add'),
)
```

- 実行はウィジェットではなく、クライアントのキャッシュに属します。
- [`useQueryClient()`](#クライアントを参照する) は、フックが使うクライアントを返します。最も近い `FueryProvider` のクライアント、`FueryProvider` がなければ `Fuery.client` です。このクライアントを渡すと、`useMutationState` が読み取るキャッシュに実行が入ります。クライアントを渡さない場合、実行は `Fuery.client` を使います。
- `NoVariablesMutation` には、クライアントの前に変数として `null` を渡します（`logoutMutation.mutate(null, client)`）。[変数のないミューテーション](../mutations/#変数のないミューテーション)を参照してください。

### ウィジェットが開始した実行だけを表示する

`useMutation` は、`MutationBuilder` と同じく、ウィジェット用のオブザーバーを保持します。その結果は `mutate` を備え、結果経由で開始した実行だけを表示します。

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

`NoVariablesMutation` の結果では、`mutate(null)` で実行します。

```dart
final logout = useMutation(logoutMutation);

TextButton(
  onPressed: () => logout.mutate(null),
  child: const Text('Log out'),
)
```

スナックバーなど、結果経由の 1 回の呼び出しに対する副作用には、`mutate` に `MutateOptions` を渡してください。

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(
    onError: (error, _, __, ___) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error'))),
  ),
);
```

ウィジェットがなくなっても、リクエストは最後まで実行されます。

- `useMutation` に定義を渡した場合、フックは結果の `mutate` に渡された `MutateOptions` を破棄します。
- [共有したオブザーバー](../mutations/#1-つのオブザーバーを共有する)はそのまま残り、`MutateOptions` のコールバックを実行します。コールバックの中で `context.mounted` を確認するか、オブザーバーを作った画面の `dispose` で、オブザーバーの `reset()` を呼び出してください。

## ミューテーションのすべての実行を表示する

`useMutationState` は、ミューテーションのすべての実行の状態を開始順に返します。開始元は、定義の `mutate`、ほかのウィジェットの `useMutation`、`MutationBuilder`、Cubit のどれでもかまいません。[`MutationStateBuilder`](../mutations/#ミューテーションのすべての実行を表示する) と同じく定義の `mutationKey` で実行を見つけ、ミューテーションを実行することはありません。

```dart
final runs = useMutationState(addTodoMutation);

if (runs.any((run) => run.isPending)) return const LinearProgressIndicator();
```

代わりに各実行に反応するには、[`useOnMutationStateChange`](#変更に反応する) を使ってください。

## 変更に反応する

ここまでのフックは読み取るだけです。画面遷移、スナックバー、そのほかの 1 回きりの処理には、読み取り用のフックの戻り値を変更に反応するフックに渡してください。

| フック | リスナーを呼び出すタイミング |
|---|---|
| `useOnQueryChange(result, ...)` | `useQuery` または `useInfiniteQuery` の結果が変わるたび |
| `useOnMutationChange(result, ...)` | `useMutation` の結果、つまりその結果で開始した実行が変わるたび |
| `useOnMutationStateChange(mutation, ...)` | `mutationKey` で見つけたミューテーションの各実行が変わるたび（どのウィジェットからの実行でも） |

```dart
final todos = useQuery(todosQuery);
useOnQueryChange(
  todos,
  listenWhen: (previous, current) =>
      !previous.isRefetchError && current.isRefetchError,
  listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not refresh: ${result.error}')),
  ),
);
```

- リスナーは、変更の後、変更を表示するリビルドの前に実行されます。ビルド中に実行されることはありません。リスナーは、ウィジェット自身の `context` を受け取ります。
- フックの最初の結果については、リスナーは呼び出されません。
- `listenWhen` は、[`QueryListener`](../widgets/#変更に反応する) と同じく、前に受け取った結果と新しい結果を比較します。
- フックは、最新のビルドの `listener` と `listenWhen` を使います。
- `useInfiniteQuery` の結果を渡すと、クロージャはページを含む `InfiniteQueryResult` を受け取ります。
- ウィジェットテストの作り物のデータなど、`QueryResult` コンストラクターで作った結果を渡すと、フックは何も呼び出しません。

リスナーは、取得の開始や終了、`setData` によるデータの書き込みなど、結果のすべての変更をリッスンします。状態の遷移に反応するには、上の例のように、`listenWhen` で両方の結果を比較してください。そうすれば、エラーが続く間の後続の変更ごとではなく、更新の失敗 1 回につき 1 つのスナックバーを表示します。

同じクエリに反応する 2 つのウィジェットは、それぞれ自身のリスナーを実行します。そのため、変更に反応するフックの処理はウィジェットごとに 1 回実行されます。失敗したすべての取得の報告など、アプリ全体で 1 回だけ必要な処理には、代わりに [`QueryCacheConfig.onError`](../client-setup/#すべての失敗を-1-か所で報告する) を使ってください。

変更に反応するフックはオブザーバーを追加せず、ウィジェットをリビルドしません。唯一の例外は `useOnMutationStateChange` です。このフックは提供されたクライアントを読み取るので、そのクライアントが置き換わるとウィジェットをリビルドします。`useQuery` などの読み取り用のフックは、結果が変わるとウィジェットをリビルドします。ウィジェットをリビルドせずにクエリに反応するには、サブツリーを `QueryListener` または `InfiniteQueryListener` で包んでください。どちらも `fuery_hooks` が再エクスポートしています。

`useOnMutationChange` は、受け取った結果で開始した実行をリッスンします。

```dart
final addTodo = useMutation(addTodoMutation);
useOnMutationChange(
  addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);

FilledButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate(title.text),
  child: const Text('Add'),
)
```

- ミューテーションは、その結果から実行してください。または、ミューテーションを実行する子ウィジェットに結果を渡してください。
- 別の `useMutation(addTodoMutation)` は、独自のオブザーバーを持ちます。このリスナーは、そのオブザーバーの実行をリッスンしません。
- 結果は最新の実行を表すので、実行が重なった場合、リスナーがリッスンするのは最新の実行です。各実行に反応するには、`useOnMutationStateChange` を使うか、`mutateAsync` を await してください。
- [共有したオブザーバー](../mutations/#1-つのオブザーバーを共有する)を渡すと、`useMutation` はそのオブザーバーの結果を返し、リスナーはそのオブザーバーのすべての実行をリッスンします。

`useOnMutationStateChange` は、`MutationStateListener` と同じく、どこで開始されたかにかかわらず、ミューテーションのすべての実行をリッスンします。`useMutation` は必要ありません。リスナーは、変わった実行ごとに 1 回、その実行の新しい状態を受け取ります。`listenWhen` は、その実行の前の状態と新しい状態を比較します。

```dart
useOnMutationStateChange(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

| 処理 | 置き場所 |
|---|---|
| 任意の実行の後に `['todos']` を無効化するなど、キャッシュの操作 | `Mutation` のコールバック |
| 画面を閉じるなど、画面自身の `useMutation` の実行に対する画面の反応 | `useOnMutationChange` |
| 失敗ごとのスナックバーなど、どのウィジェットからの実行にも反応する処理 | `useOnMutationStateChange` |
| 1 回の呼び出しに対する処理で、その呼び出しの変数が必要なもの | `useMutation` の結果の `mutate` に渡す `MutateOptions` |
| 1 回の呼び出しの後の処理で、呼び出すコードの中に書くもの | `try` の中で `await addTodoMutation.mutateAsync(...)` し、その後 `context.mounted` を確認 |

呼び出しを await すると、処理を呼び出し側のコードのすぐそばに書けます。

```dart
final client = useQueryClient();

FilledButton(
  onPressed: () async {
    try {
      await addTodoMutation.mutateAsync(title.text, client);
    } catch (_) {
      return; // useOnMutationStateChange above reports the failure.
    }
    if (context.mounted) Navigator.pop(context);
  },
  child: const Text('Add'),
)
```

`try` があるので、失敗がキャッチされないエラーとしてゾーンに届くことはありません。

サインアウトしたユーザーなど、マウント時の結果だけで表示内容が決まる場合は、フックが返す結果をもとに `build` の中で決めてください。その結果については、変更に反応するフックは呼び出されません。

### useEffect でのスナックバーと画面遷移

スナックバーの表示と画面遷移には、変更に反応するフックを使ってください。変更に反応するフックは、ビルドの外で、後続の変更に対してだけ実行されます。`useEffect` と `useValueChanged` はビルド中に実行されますが、ビルド中のスナックバーや画面遷移は失敗します。ツリーのビルド中に、ウィジェットツリーを変更するからです。`useEffect` のコールバックは、まず最初のビルドで、ウィジェットがマウントされたときの値に対して実行されます。その後は、キーが変わったビルドのたびに実行されます。キーがなければ、すべてのビルドで実行されます。デバッグビルドでは、呼び出しが次のエラーで失敗します。

- `showSnackBar` は `The showSnackBar() method cannot be called during build.` を報告します。
- `Navigator.pop` は `setState() or markNeedsBuild() called during build.` を報告します。
- 最初のビルド、またはキーが変わった後は、`ScaffoldMessenger.of(context)` が先に `Cannot listen to inherited widgets inside HookState.initState.` で失敗します。

## 各ウィジェットに対応するフック

| ウィジェット | フック |
|---|---|
| `QueryBuilder` | `useQuery(query)` |
| `QueryListener` | `useOnQueryChange(result, listener: ...)` |
| `QueryConsumer` | `useQuery(query)` と `useOnQueryChange` |
| `InfiniteQueryBuilder` | `useInfiniteQuery(query)` |
| `InfiniteQueryListener` | `useOnQueryChange(result, listener: ...)` |
| `InfiniteQueryConsumer` | `useInfiniteQuery(query)` と `useOnQueryChange` |
| `MutationBuilder` | `useMutation(mutation)` |
| `MutationListener` | `useOnMutationChange(result, listener: ...)` |
| `MutationConsumer` | `useMutation(mutation)` と `useOnMutationChange` |
| `QueriesBuilder` | `useQueries(queries)` |
| `MutationStateBuilder`、`MutationStateSelector` | `useMutationState(mutation)` |
| `MutationStateListener` | `useOnMutationStateChange(mutation, listener: ...)` |

`result` は、`useQuery(query)` などの読み取り用のフックが返す値です。

## クライアントを参照する

`useQueryClient()` は、フックが使うクライアントを返します。上位の `FueryProvider` が提供するクライアント、または `Fuery.client` です。提供されたクライアントが置き換わると、ウィジェットはリビルドします。

```dart
final client = useQueryClient();

RefreshIndicator(
  onRefresh: () => client.invalidateQueries(queryKey: ['todos']),
  child: TodoList(todos.data ?? []),
)
```

`observe()` で作ったオブザーバーは、自身のクライアントを保持します。`client:` を渡さない限り、そのクライアントは `Fuery.client` です。独自のクライアントを持つ `FueryProvider` の下では、定義を渡すか、`useQueryClient()` が返すクライアントでオブザーバーを作ってください。定義の `mutate` も、クライアントを渡さない限り `Fuery.client` を使います。クライアントは `addTodoMutation.mutate('Buy milk', client)` のように渡します。デバッグビルドでは、別のクライアントのオブザーバーを渡されたフックが警告を出力します。[画面が別のクライアントのキャッシュを読んでいる](../../troubleshooting/#画面が別のクライアントのキャッシュを読んでいる)を参照してください。

## キャッシュを監視する

`useStream` は、何かが取得中かどうかなど、`client.watch` の値を描画します。ストリームは、`useMemoized` で 1 回だけ作ってください。

```dart
final client = useQueryClient();
final fetching = useStream(
  useMemoized(
    () => client.watch((client) => client.isFetching() > 0),
    [client],
  ),
);

if (fetching.data ?? false) return const LinearProgressIndicator();
```

- [`watch`](../query-client/#キャッシュを監視する) は呼び出すたびに新しいストリームを返し、各リスナーはまず現在の値を受け取ります。
- `useStream` は、受け取った新しいストリームをすべて購読します。そのため、ビルドのたびにストリームを作ると、フレームごとにウィジェットがリビルドされます。
- `useMemoized` のキーには、クライアントと、セレクターが読み取る `build` 内のすべての値を指定してください。そうすれば、ストリームがクライアントや値の変化に追従します。

ミューテーションには、ストリームは必要ありません。[`useMutationState`](#ミューテーションのすべての実行を表示する) が実行を返し、`useMutationState(const MutationFilters())` はすべてのミューテーションの実行を返します。

## テスト

フックを使う画面は、ほかのウィジェットと同じようにテストしてください。[テスト](../testing/)の内容がそのまま当てはまります。各テストの最後に、ツリーをアンマウントし、クライアントを消去してください。
