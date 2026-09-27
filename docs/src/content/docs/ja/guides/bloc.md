---
title: Bloc と Cubit
description: Flutter アプリの Cubit と Bloc から、キャッシュにあるクエリを読み取り、ミューテーションを実行します。Fuery のウィジェットとキャッシュを共有し、今の状態管理はそのまま使えます。
sourceHash: 5acfa82783c1
head:
  - tag: title
    content: Flutter の Bloc や Cubit で API データをキャッシュする | Fuery
---

Cubit と Bloc は、Fuery のウィジェットと同じクエリ、ミューテーション、キャッシュを使います。そのため、今の状態管理をそのまま使い続けられます。オブザーバーの `stream` は、まず現在の結果を流し、その後は変更のたびに流します。リッスンするとオブザーバーが購読し、マウントされたウィジェットと同じように取得します。購読をキャンセルすると、オブザーバーの購読が解除されます。

## 使うビルダーを選ぶ

ビルダーは画面ごとに選んでください。

| 画面 | 作り方 |
|---|---|
| サーバーデータをほぼ届いたまま表示する | `QueryBuilder`。間に Cubit を挟むと、`QueryResult` がすでに持っている読み込み中とエラーのフラグを作り直すことになります。 |
| サーバーデータとアプリの状態（選択、フィルター、フォーム、複数のクエリの組み合わせ）を混ぜる | クエリをリッスンする Cubit と `BlocBuilder` |
| Bloc で作ったアプリで、すでにイベントで動いている | クエリをリッスンする Bloc と `BlocBuilder` |

1 つの画面で両方を使うこともできます。アプリの状態には `BlocBuilder`、サーバーデータには `QueryBuilder` を使います。どちらの方法でも、同じキーを使う 2 つの画面は、同じキャッシュエントリとリクエストを共有します。そのため、データではなく画面で選んでください。

クエリは、リポジトリ経由ではなく Cubit からリッスンしてください。クエリ自体が、すでにキャッシュの層です。

## Cubit で使う

ウィジェットの外では、`observe()` がクエリを、`stream` を持つオブザーバーに変えます。`todosQuery` は、[クエリを整理する](../organizing-queries/)と同じクエリです。

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState()) {
    _subscription = _todos.stream.listen((result) {
      emit(state.copyWith(todos: result.data, loading: result.isLoading));
    });
  }

  final _todos = todosQuery.observe();
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

`close()` では、`cancel()` を await せずに呼び出してください。`testWidgets` と `fakeAsync` の中では、`cancel()` の Future が完了しません。[Cubit と Bloc をテストする](../testing/#cubit-と-bloc-をテストする)を参照してください。

## Bloc で使う

`emit.forEach` は、ハンドラーが実行されている間、購読します。

```dart
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(const TodoState()) {
    on<TodosSubscribed>((event, emit) {
      return emit.forEach(
        todosQuery.observe().stream,
        onData: (result) =>
            state.copyWith(todos: result.data, loading: result.isLoading),
      );
    });
  }
}
```

## Cubit や Bloc からのミューテーション

Cubit は、独自のオブザーバーを持たずに、定義からミューテーションを実行します。`mutateAsync` はデータを返すかエラーをスローするので、Cubit のメソッドに向いています。

```dart
Future<void> add(String title) async {
  try {
    await addTodo.mutateAsync(title);
  } catch (error) {
    emit(state.copyWith(error: error));
  }
}
```

Bloc のイベントハンドラーでも同じです（`await addTodo.mutateAsync(event.title)`）。

- 実行は `Fuery.client` を使います。テストのクライアントなど、別のクライアントを受け取った Cubit は、そのクライアントを渡します（`addTodo.mutateAsync(title, client)`）。
- 実行は Cubit ではなく、クライアントのキャッシュに属します。そのため、どの画面でも実行を表示できます。[ウィジェットと共有する](#ウィジェットと共有する)を参照してください。
- オブザーバー（`final _addTodo = addTodo.observe();`）を保持するのは、Cubit が自身の実行の状態を、オブザーバーの `result` や `stream` で追う場合だけにしてください。

## ウィジェットと共有する

同じキーを使う Cubit と `QueryBuilder` は、同じキャッシュエントリを共有します。通知を既読にするなど、ある画面での変更は、Cubit にもすべてのウィジェットにも反映されます。

`addTodo` に `mutationKey` を付けると、Cubit や Bloc が開始した実行が、どの画面の `MutationStateBuilder(mutation: addTodo)` にも表示されます。[ミューテーションのすべての実行を表示する](../mutations/#ミューテーションのすべての実行を表示する)を参照してください。

どこで開始されたかにかかわらず、ミューテーションのすべての実行に反応する Cubit は、`MutationStateSlot` を保持します。`subscribeToRuns` は、各実行の後続の変更ごとにリスナーを呼び出します。`result` は、現在の実行の一覧です。[ミューテーションのすべての実行](../adapters/#ミューテーションのすべての実行)を参照してください。

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit(QueryClient client)
      : _adding = MutationStateSlot(addTodo, client),
        super(const TodoState()) {
    _adding.subscribeToRuns((previous, current) {
      if (current.isError) emit(state.copyWith(error: current.error));
    });
  }

  final MutationStateSlot<Todo, String, Object?> _adding;

  @override
  Future<void> close() {
    _adding.dispose();
    return super.close();
  }
}
```

## アプリのライフサイクル

Fuery のウィジェット、フック、`FueryProvider` は、アプリのライフサイクルを接続します。そのため、アプリが再開すると、Fuery が古いクエリを再取得します。`FueryProvider` を使わずに Bloc からだけクエリを使うアプリでは、代わりに `main` で `FueryBinding.ensureInitialized()` を 1 回呼び出してください。[アプリが再開したとき](../lifecycle/#アプリが再開したとき)を参照してください。

## サンプルアプリでは

[通知の Cubit](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/notifications/notifications_cubit.dart) は、バッジ用に未読の通知を数えます。一方、通知画面は、同じクエリを Fuery のウィジェットで表示します。サンプルアプリの [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) に、各画面で示している内容の一覧があります。
