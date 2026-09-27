---
title: 쿼리 정리하기
description: Flutter 앱이 커져도 쿼리 키, 쿼리 함수, 뮤테이션을 한곳에 모아 두세요.
sourceHash: 65a5f2f56dec
---

쿼리마다 정의를 하나만 두면 모든 화면, 모든 Bloc, 모든 서비스에서 키와 데이터 타입이 같아요. 정의는 호출하는 API 옆 파일에 두세요.

```dart
// lib/data/todo_queries.dart
const todosKey = ['todos', 'list'];

final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => api.getTodos(),
);

Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
    );
```

쿼리는 데이터를 담지 않으므로 최상위 `final`로 둬도 돼요. id처럼 값을 받는 쿼리는 함수로 만들어요.

같은 정의를 데이터가 필요한 모든 곳에서 사용해요.

```dart
QueryBuilder(query: todoQuery(id), builder: ...);     // in a widget
final todo = await client.query(todoQuery(id));        // fetching outside widgets
client.updateData(todoQuery(id), (todo) => todo?.copyWith(done: true));
final todos = todosQuery.observe();                   // in a cubit or a service
```

`todosQuery`의 위젯과 옵저버는 모두 캐시 항목 하나를 공유해요. 뮤테이션은 키를 다시 적지 않고 `todosKey`로 무효화해요. `InfiniteQuery` 정의도 똑같이 동작해요.

- **타입 검사가 유지돼요.** 위젯, `client.query`, `getData`, `setData`, `updateData`는 쿼리에서 데이터 타입을 얻어요. 그래서 캐스팅할 필요가 없고, 키에 다른 타입을 쓸 방법도 없어요.
- **키가 일관되게 유지돼요.** 키에 오타가 있으면 아무 경고 없이 캐시 항목이 하나 더 생겨요. 쿼리마다 정의를 하나만 두면 이런 일이 생기지 않아요.
- **계층이 드러나요.** `['todos', ...]`는 할 일에 관한 모든 것을 묶어요. 그래서 `invalidateQueries(queryKey: ['todos'])`가 목록과 모든 상세 데이터를 한 번에 새로 가져와요.

## 쿼리 함수에 의존성 넘기기

쿼리 함수에서 절대 `BuildContext`를 캡처하지 마세요. 위 코드의 `api`는 수명이 긴 객체라서 안전해요.

Fuery는 쿼리 함수를 캐시 항목에 담아 두고, 이럴 때 다시 실행해요.

- 앱이 포그라운드로 돌아올 때
- 네트워크가 다시 연결될 때
- `refetchInterval` 간격마다
- 어디서든 그 키를 무효화하거나 다시 가져올 때

이 중 일부는 쿼리를 만든 위젯이 사라지고 `BuildContext`가 언마운트된 뒤에 실행돼요. 캡처한 `State`, `TickerProvider`, `context`로 읽은 모든 값도 같은 문제가 있어요.

일반 값은 안전해요. id나 검색어는 키와 요청에 들어가고, 위젯보다 오래 남아요.

의존성을 쿼리의 매개변수로 넘기세요.

```dart
Query<List<Todo>> todosQuery(TodoApi api) => Query(
      queryKey: todosKey,
      queryFn: (_) => api.getTodos(),
    );
```

화면은 쿼리를 사용하는 곳에서 의존성을 얻어요.

```dart
QueryBuilder(query: todosQuery(locator<TodoApi>()), builder: ...)
```

또는 쿼리 함수 안에서 의존성을 찾으세요. 그러면 쿼리에 매개변수가 필요 없어요.

```dart
final todosQuery = Query(
  queryKey: todosKey,
  queryFn: (_) => locator<TodoApi>().getTodos(),
);
```

`locator`는 앱이 의존성을 얻을 때 사용하는 도구를 가리켜요. 어느 형태든 클로저에 위젯에 묶인 것이 들어가지 않아요. 키가 같은 두 위젯은 캐시 항목 하나를 공유하므로, 한 키를 사용하는 곳에는 모두 같은 의존성을 주세요.

모든 쿼리 함수가 받는 인수인 `QueryFunctionContext`에는 위젯 트리에서 온 것이 하나도 없어요. [쿼리 함수 컨텍스트](../../reference/query-options/#쿼리-함수-컨텍스트)를 참고하세요.

## 리포지토리의 실패를 쿼리에 전달하기

쿼리 함수가 실패하려면 에러가 발생해야 해요. Fuery는 발생한 에러로만 에러 상태를 설정해요. `Result`, `Either` 같은 래퍼를 반환하는 함수는 래퍼에 무엇이 담겼든 항상 성공해요. 그러면 쿼리는 이렇게 동작해요.

- `status`를 `QueryStatus.success`로, `error`를 `null`로 유지해요.
- `isError`, `isLoadingError`, `isRefetchError`를 설정하지 않아요.
- 재시도하지 않아요. 재시도 정책은 발생한 에러만 보기 때문이에요.

쿼리 함수에서 결과를 풀고, 실패는 에러로 일으키세요.

```dart
Query<List<Todo>> todosQuery(TodoRepository repo) => Query(
      queryKey: todosKey,
      queryFn: (_) async => switch (await repo.getTodos()) {
        Ok(:final value) => value,
        Err(:final error) => throw error,
      },
    );
```

쿼리 데이터는 null이 될 수 없으므로, 돌려줄 결과가 없는 함수도 에러를 일으켜요. [null이 될 수 없는 쿼리 데이터](../queries/#null이-될-수-없는-쿼리-데이터)를 참고하세요.

## 뮤테이션 정리하기

뮤테이션은 쿼리 옆에 같은 방식으로 정의하세요. 뮤테이션마다 바꾸는 데이터의 키로 만든 `mutationKey`를 주세요.

```dart
// lib/data/todo_mutations.dart
final addTodo = Mutation(
  mutationKey: [...todosKey, 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) =>
      client.invalidateQueries(queryKey: todosKey),
);
```

`mutationKey`가 있으면 어떤 위젯, 훅, Cubit이 시작했든 어느 화면에서나 뮤테이션의 실행(`mutate` 호출 한 번)을 찾을 수 있어요. `MutationStateBuilder(mutation: addTodo)`는 앱 어디서든 실행을 보여줘요. [뮤테이션의 모든 실행 보여주기](../mutations/#뮤테이션의-모든-실행-보여주기)를 참고하세요.

정의는 상태를 담지 않으므로 쿼리처럼 최상위 값으로 둬도 돼요. 실행은 모두 클라이언트의 캐시에 속해요. 콜백은 뮤테이션을 실행하는 클라이언트를 받아요. 그래서 테스트에서도, `FueryProvider` 아래에서도 캐시 작업이 올바른 클라이언트에 닿아요. 실행이 캐시 항목과 어떻게 다른지는 [뮤테이션 실행](../../how-the-cache-works/#뮤테이션-실행)에 있어요.

무효화나 롤백 같은 캐시 작업은 정의에 두세요. 호출이 성공한 뒤 화면을 닫는 것처럼 한 화면에만 해당하는 일은 호출하는 곳에 두세요.

```dart
onPressed: () async {
  try {
    await addTodo.mutateAsync(title, context.queryClient);
  } catch (_) {
    return; // A MutationStateListener reports the failure.
  }
  if (context.mounted) Navigator.pop(context);
},
```

버튼 전체 코드는 [호출 한 번이 성공한 뒤 처리하기](../mutations/#호출-한-번이-성공한-뒤-처리하기)에 있어요.

`MutationStateListener`는 뮤테이션의 어떤 실행이 끝나든 스낵바나 다이얼로그를 보여줘요. 어느 화면에 두든 그 화면의 `BuildContext`를 사용해요. [뮤테이션이 실패했다고 사용자에게 알리기](../mutations/#뮤테이션이-실패했다고-사용자에게-알리기)를 참고하세요.

## 예제 앱에서

예제는 쿼리를 [피드 쿼리](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)에, 뮤테이션을 [피드 뮤테이션](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)에 정의해요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
