---
title: Bloc과 Cubit
description: Flutter 앱의 Cubit과 Bloc에서 캐시된 쿼리를 읽고 뮤테이션을 실행해요. Fuery의 위젯과 캐시 하나를 공유하고, 쓰던 상태 관리는 그대로 유지해요.
sourceHash: 5acfa82783c1
head:
  - tag: title
    content: Flutter의 Bloc이나 Cubit에서 API 데이터 캐시하기 | Fuery
---

Cubit과 Bloc은 Fuery의 위젯과 같은 쿼리, 뮤테이션, 캐시를 사용해요. 그래서 쓰던 상태 관리를 바꾸지 않아도 돼요. 옵저버의 `stream`은 현재 결과를 먼저 내보내고, 그다음 모든 변화를 내보내요. `stream`을 구독하면 옵저버가 쿼리를 구독하고, 마운트된 위젯처럼 데이터를 가져와요. 구독을 취소하면 옵저버도 구독을 해제해요.

## 어떤 빌더를 쓸지 고르기

화면마다 빌더를 고르세요.

| 화면 | 빌드에 쓸 것 |
|---|---|
| 서버 데이터를 거의 받은 그대로 보여줘요 | `QueryBuilder`. 중간에 Cubit을 두면 `QueryResult`에 이미 있는 로딩 플래그와 에러 플래그를 다시 만들어야 해요. |
| 서버 데이터와 앱 상태를 섞어요. 선택한 항목, 필터, 폼, 여러 쿼리를 합친 값이 그 예예요 | 쿼리를 구독하는 Cubit과 `BlocBuilder` |
| Bloc으로 만든 앱에서 이미 이벤트로 동작해요 | 쿼리를 구독하는 Bloc과 `BlocBuilder` |

한 화면에서 둘 다 쓸 수도 있어요. 앱 상태에는 `BlocBuilder`를, 서버 데이터에는 `QueryBuilder`를 쓰세요. 어느 쪽이든 같은 키를 사용하는 두 화면은 캐시 항목 하나와 요청 하나를 공유해요. 그러니 데이터가 아니라 화면을 기준으로 고르세요.

쿼리는 리포지토리를 거치지 말고 Cubit에서 바로 구독하세요. 쿼리가 이미 캐싱 계층이에요.

## Cubit에서

위젯 밖에서는 `observe()`가 쿼리를 `stream`이 있는 옵저버로 바꿔요. `todosQuery`는 [쿼리 정리하기](../organizing-queries/)에 나오는 쿼리예요.

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

`close()`에서 `cancel()`을 호출하되 `await`로 기다리지 마세요. `testWidgets`와 `fakeAsync`에서는 `cancel()`이 반환한 `Future`가 완료되지 않아요. [Cubit과 Bloc 테스트하기](../testing/#cubit과-bloc-테스트하기)를 참고하세요.

## Bloc에서

`emit.forEach`는 핸들러가 실행되는 동안 구독을 유지해요.

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

## Cubit이나 Bloc에서 뮤테이션 실행하기

Cubit은 자기 옵저버 없이 정의에서 뮤테이션을 실행해요. `mutateAsync`는 데이터를 반환하거나 에러를 일으켜요. 그래서 Cubit의 메서드에 잘 맞아요.

```dart
Future<void> add(String title) async {
  try {
    await addTodo.mutateAsync(title);
  } catch (error) {
    emit(state.copyWith(error: error));
  }
}
```

Bloc의 이벤트 핸들러도 똑같이 해요. `await addTodo.mutateAsync(event.title)`처럼요.

- 실행(`mutate` 호출 한 번)은 `Fuery.client`를 사용해요. 테스트의 클라이언트처럼 다른 클라이언트를 받은 Cubit은 그 클라이언트를 넘겨요. `addTodo.mutateAsync(title, client)`처럼요.
- 실행은 Cubit이 아니라 클라이언트의 캐시에 속해요. 그래서 모든 화면에서 실행을 보여줄 수 있어요. [위젯과 공유하기](#위젯과-공유하기)를 참고하세요.
- Cubit이 옵저버의 `result`나 `stream`으로 자기 실행의 상태를 따라가야 할 때만 `final _addTodo = addTodo.observe();`처럼 옵저버를 두세요.

## 위젯과 공유하기

같은 키를 사용하는 Cubit과 `QueryBuilder`는 캐시 항목 하나를 공유해요. 알림을 읽음으로 표시하는 것처럼 한 화면에서 바꾼 내용은 Cubit과 모든 위젯에 보여요.

`addTodo`에 `mutationKey`를 주세요. 그러면 Cubit이나 Bloc이 시작한 실행이 어느 화면에서든 `MutationStateBuilder(mutation: addTodo)`에 보여요. [뮤테이션의 모든 실행 보여주기](../mutations/#뮤테이션의-모든-실행-보여주기)를 참고하세요.

어디서 시작했든 뮤테이션의 모든 실행에 반응하는 Cubit은 `MutationStateSlot`을 둬요. `subscribeToRuns`는 이후 각 실행이 바뀔 때마다 리스너를 호출하고, `result`에는 현재 실행이 담겨 있어요. [뮤테이션의 모든 실행](../adapters/#뮤테이션의-모든-실행)을 참고하세요.

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

## 앱 생명주기

Fuery의 위젯, 훅, `FueryProvider`는 앱 생명주기를 연결해요. 그래서 앱이 포그라운드로 돌아오면 stale 상태인 쿼리를 다시 가져와요. `FueryProvider` 없이 Bloc에서만 쿼리를 사용하는 앱은 그 대신 `main`에서 `FueryBinding.ensureInitialized()`를 한 번 호출하세요. [앱이 포그라운드로 돌아올 때](../lifecycle/#앱이-포그라운드로-돌아올-때)를 참고하세요.

## 예제 앱에서

[알림 Cubit](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/notifications/notifications_cubit.dart)은 배지에 표시할 읽지 않은 알림 수를 세요. 알림 화면은 같은 쿼리를 Fuery의 위젯으로 보여줘요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
