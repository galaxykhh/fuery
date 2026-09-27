---
title: 스트림 쿼리
description: Flutter에서 스트림을 캐시해요. 청크는 도착하는 대로 보여주고, 스트림이 끝나면 결과를 유지해요.
sourceHash: 2d8d325d1547
---

`streamedQuery`는 `Stream`을 쿼리 함수로 바꿔요. 청크가 도착하는 동안 화면이 데이터를 보여줘요. 스트림이 끝나면 캐시가 결과를 유지해요.

청크로 나눠 도착하고 끝나는 응답에 사용하세요. 스트림으로 받는 답변, 진행 로그, 처리 중인 파일이 그래요. 실시간 피드처럼 계속 열려 있는 연결은 가져오기가 아니라서 쿼리에 맞지 않아요. 이런 연결은 [캐시 읽고 쓰기](../query-client/#캐시-읽고-쓰기)처럼 메시지마다 `setQueryData`로 캐시에 쓰세요.

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

- **첫 청크가 오면 쿼리가 성공해요.** 위젯은 데이터가 늘어나는 대로 보여줘요.
- **스트림이 끝날 때까지 `isFetching`은 true예요.**
- **`combine`은 `Stream.fold`처럼 동작해요.** `initialValue`에서 시작해, 지금까지 쌓인 값에 청크를 하나씩 더해요.
- **`initialValue`가 데이터 타입을 정해서** 호출에 타입 인수가 필요 없어요.
- **빈 스트림은 `initialValue`로 성공해요.**
- **스트림이나 `combine`에서 에러가 발생하면 쿼리가 실패해요.** `data`에는 그때까지 받은 청크가 남아요.
- **재시도할 때마다 새 스트림을 시작하고** `refetchMode`를 따라요. 기본 모드는 먼저 데이터를 비워요.

`Query`는 `staleTime` 같은 다른 [쿼리 옵션](../../reference/query-options/)도 평소처럼 받아요.

## 청크를 리스트로 모으기

빈 리스트에서 시작해 청크를 하나씩 추가하세요.

```dart
final log = Query(
  queryKey: ['jobs', id, 'log'],
  queryFn: streamedQuery(
    stream: (context) => api.jobLog(id),
    initialValue: const <LogLine>[],
    combine: (lines, line) => [...lines, line],
  ),
);
```

## 스트림 쿼리 다시 가져오기

`refetchMode`는 `invalidateQueries` 뒤처럼 쿼리가 데이터를 다시 가져올 때 캐시된 데이터를 어떻게 할지 정해요.

| 모드 | 새 스트림이 실행되는 동안 | 스트림이 끝나면 |
|---|---|---|
| `StreamRefetchMode.reset`(기본값) | Fuery가 데이터를 비우고, 첫 청크가 올 때까지 쿼리는 `pending` 상태예요. | 새 데이터 |
| `StreamRefetchMode.append` | Fuery가 새 청크를 기존 데이터에 쌓아요. | 합친 데이터 |
| `StreamRefetchMode.replace` | 이전 데이터가 화면에 남아요. | 새 데이터를 한 번에 |

```dart
queryFn: streamedQuery(
  stream: (context) => api.ask(question),
  initialValue: '',
  combine: (text, token) => text + token,
  refetchMode: StreamRefetchMode.replace,
),
```

## 스트림 멈추기

Fuery는 가져오기를 취소할 때 스트림도 취소해요. `cancelQueries`를 호출하거나, 다시 가져오기가 실행 중인 가져오기를 대신할 때예요.

기본으로는 쿼리를 사용하는 위젯이 없어도 스트림은 계속 실행되고, Fuery가 결과를 캐시해요. 그래서 사용자가 돌아오면 스트림으로 받은 답변이 완성돼 있어요. 대신 스트림을 멈추려면 `stream`에서 `context.signal`을 읽으세요. 그러면 가져오기를 [취소할 수 있어요](../queries/#요청-취소하기).

```dart
stream: (context) {
  final request = api.startAnswer(question); // a request you can cancel
  context.signal.onAbort(request.cancel);
  return request.tokens;
},
```

## 예제 앱에서

예제는 [게시물 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)에서 스레드 요약을 스트림으로 받아요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
