---
title: 어댑터 만들기
description: fuery_core의 슬롯으로 Fuery 쿼리와 뮤테이션을 직접 만든 Flutter 위젯이나 다른 상태 관리 라이브러리에서 렌더링해요. fuery와 fuery_hooks가 하는 방식 그대로예요.
sourceHash: f61aaedad61c
---

어댑터는 `fuery_core`의 공개 API만으로 Fuery의 쿼리와 뮤테이션을 직접 만든 위젯이나 다른 상태 관리 라이브러리에서 렌더링해요. `fuery`의 위젯과 [`fuery_hooks`](../hooks/)의 훅도 이렇게 만든 어댑터예요. 그래서 직접 만든 어댑터도 이 위젯과 훅이 하는 일을 모두 할 수 있어요.

어댑터는 렌더링하는 쿼리나 뮤테이션마다 **슬롯**을 하나씩 유지해요. 슬롯(`ObserverSlot`)은 렌더링할 때마다 바뀔 수 있는 소스의 [옵저버](../../how-the-cache-works/#옵저버)를 담아요.

## 슬롯으로 쿼리 렌더링하기

렌더링할 때마다 `update`를 호출하고, `result`를 읽고, 바뀌면 다시 렌더링하도록 구독하세요. `flutter_hooks`만으로 작성한 이 훅에 슬롯의 규칙이 모두 들어 있어요.

```dart
QueryResult<TData> useMyQuery<TData extends Object>(QuerySource<TData> query) {
  final client = FueryProvider.of(useContext(), listen: true);
  final slot = useMemoized(() => QuerySlot(query, client));
  final changes = useState(0);
  useEffect(() {
    var active = true;
    final unsubscribe = slot.subscribe(notifyManager.batchCalls((_) {
      if (active) changes.value++;
    }));
    return () {
      active = false;
      unsubscribe();
      slot.dispose();
    };
  }, [slot]);
  slot.update(query, client);
  return slot.result;
}
```

## 슬롯의 규칙

`QuerySlot`은 `QuerySource`를 받아요. `QuerySource`는 `Query`나 `QueryObserver`예요. `QuerySlot`에는 이런 멤버가 있고, `InfiniteQuerySlot`과 `MutationSlot`에도 같은 멤버가 있어요.

| 멤버 | 하는 일 |
|---|---|
| `update(source, client)` | 렌더링할 때마다 호출하세요. 정의를 받으면 슬롯이 옵저버를 직접 소유하고 옵저버의 옵션을 업데이트해요. 클라이언트가 바뀌면 새 옵저버를 만들어요. 옵저버를 받으면 슬롯은 그 옵저버를 그대로 사용하고, 클라이언트도 옵저버를 만들 때의 클라이언트를 사용해요. |
| `result` | 렌더링할 결과예요. `update`가 반환하면 바로 최신 결과가 돼요. |
| `subscribe(listener)` | 이후의 모든 결과로 `listener`를 호출해요. `update`가 슬롯을 다른 옵저버로 옮겨도 구독을 유지해요. 리스너를 제거하는 함수를 반환해요. |
| `listen((previous, current) {...})` | 이후 결과가 바뀔 때마다 리스너를 호출해요. 화면 이동 같은 사이드 이펙트에 사용해요. `previous`는 리스너에 마지막으로 넘긴 결과이고, 처음에는 시작할 때의 `result`예요. 리스너를 멈추는 함수를 반환해요. |
| `dispose()` | 모든 리스너를 제거해요. 슬롯이 옵저버를 만들었다면 쿼리 옵저버는 없애고, 뮤테이션 옵저버는 초기 상태로 되돌려요. 이때 가장 최근 `mutate` 호출의 콜백도 버려요. |
| `observer` | 슬롯이 지금 렌더링에 사용하는 옵저버예요. |

쿼리, 무한 쿼리, 뮤테이션의 리스너 위젯과 컨슈머 위젯, `useOnQueryChange`, `useOnMutationChange`는 `listen`을 호출해요. 그래서 이 규칙을 따라요.

- 리스너는 마이크로태스크에서 실행되고, 렌더링하는 동안에는 실행되지 않아요.
- 시작할 때의 `result`나, 이전 결과와 같은 결과로는 호출되지 않아요.
- `update`가 슬롯을 다른 옵저버로 옮기면, 호출 없이 새 `result`에서 다시 시작해요.
- `listen`도 구독해요. 그래서 마운트된 위젯이 있을 때처럼 쿼리가 데이터를 가져와요.
- 리스너에서 에러가 발생하면 Fuery가 그 에러를 클라이언트의 `onUncaughtError`로 전달해요.

## 리스너 호출 묶기

`QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`은 `subscribe` 리스너를 동기로 호출해요. 호출 시점이 다른 위젯이 빌드하는 중일 때도 있어요. 마운트되는 위젯이 데이터를 가져오기 시작할 때가 그 예예요. 렌더링 중에 업데이트할 수 없는 프레임워크에서는 위 훅처럼 하세요.

1. 리스너를 `notifyManager.batchCalls`로 감싸세요. 그러면 변화가 마이크로태스크에서 전달돼요.
2. 해제한 뒤에 도착한 변화는 무시하세요.

`QueriesSlot`과 `MutationStateSlot`은 이미 리스너를 마이크로태스크에서 호출해요. 그래서 두 단계 모두 필요 없어요.

## 다른 슬롯

| 슬롯 | 소스 | 결과 |
|---|---|---|
| `InfiniteQuerySlot` | `InfiniteQuerySource`: `InfiniteQuery`나 `InfiniteQueryObserver` | `InfiniteQueryResult` |
| `MutationSlot` | `MutationSource`: `Mutation`이나 `MutationObserver` | `MutationResult` |
| `QueriesSlot` | 데이터 타입이 같은 `QuerySource`의 리스트 | 같은 순서의 `QueryResult` 리스트 |

`QueriesSlot`은 `useQueries` 같은 훅에 사용해요. `subscribe` 리스너를 마이크로태스크에서 호출하고, 함께 도착한 변화에는 한 번만 호출해요. 그래서 `batchCalls`가 필요 없어요. 키가 리스트에 남아 있는 동안에는 리스트 순서가 바뀌어도 쿼리마다 옵저버를 유지해요. `observer`는 옵저버의 리스트예요. 옵저버를 추가하거나, 제거하거나, 바꾸거나, 옮길 때만 새 리스트가 돼요.

## 뮤테이션의 모든 실행

`MutationStateSlot`은 뮤테이션의 모든 실행(`mutate` 호출 한 번)의 상태를 알려줘요. 실행을 어디서 시작했든 상관없어요. MutationState 위젯과 `useMutationState`가 이 슬롯을 사용해요.

- `MutationStateSource`를 받아요. `MutationStateSource`는 `mutationKey`가 있는 `Mutation`이나 `MutationFilters`예요.
- 캐시를 읽기만 해요. `observer`는 클라이언트의 `MutationCache`예요.
- `result`는 실행의 상태를 오래된 것부터 담은 리스트예요. 조건에 맞는 실행이 추가되거나, 제거되거나, 바뀌기 전까지는 같은 리스트를 유지해요.
- `subscribe` 리스너를 마이크로태스크에서 묶음마다 한 번, 리스트가 바뀌었을 때만 호출해요. 그래서 `batchCalls`가 필요 없어요.

`subscribeToRuns((previous, current) {...})`는 조건에 맞는 실행이 바뀔 때마다 리스너를 호출하고, 그 실행의 이전 상태를 `previous`로 넘겨요. 나중에 시작한 실행이면 `previous`는 `idle` 상태예요. 리스너를 추가한 시점의 실행 상태나, 캐시가 제거한 실행은 알리지 않아요. `MutationStateListener`와 `useOnMutationStateChange`가 이 메서드를 사용해요.

## 결과만으로 변화 구독하기

결과에는 자신을 알린 옵저버가 `result.observer`로 들어 있어요. 결과만 받은 어댑터는 `useOnQueryChange`와 `useOnMutationChange`처럼 그 옵저버로 자기 슬롯을 만들어 변화를 구독해요.

```dart
void Function() listenTo<TData extends Object>(
  QueryResult<TData> result,
  void Function(QueryResult<TData> previous, QueryResult<TData> current)
      listener,
) {
  final observer = result.observer;
  if (observer == null) return () {};
  final slot = QuerySlot(observer, observer.client);
  slot.listen(listener);
  return slot.dispose;
}
```

- 슬롯은 옵저버를 그대로 사용하고, 절대 없애지 않아요.
- 생성자로 만든 `QueryResult`에서는 `observer`가 `null`이에요.
- `InfiniteQueryResult`에는 `InfiniteQueryObserver`가 있고, `InfiniteQuerySlot`이 이 옵저버를 받아요.

## 클라이언트 읽기

Flutter에서는 `FueryProvider.of(context, listen: true)`가 가장 가까운 `FueryProvider`가 제공하는 클라이언트를 반환하고, 없으면 `Fuery.client`를 반환해요. 제공하는 클라이언트가 바뀌면 호출한 쪽이 다시 빌드돼요. 그러면 다음 `update`가 옵저버를 소유한 슬롯을 새 클라이언트로 옮겨요.

Flutter 밖에서는 앱이 사용하는 클라이언트를 넘기세요.

## 포커스와 재연결 때 다시 가져오기

Flutter에서는 Fuery의 위젯과 훅처럼, 어댑터가 마운트될 때 `FueryBinding.ensureInitialized()`를 호출하세요. 이 메서드가 앱 생명주기를 연결해요. 그래서 앱이 포그라운드로 돌아오면 Fuery가 stale 상태인 쿼리를 다시 가져오고, 앱이 백그라운드에 있는 동안에는 재시도를 미뤄요. 두 번째 호출부터는 아무것도 하지 않아요. 위에 `FueryProvider`가 있으면 프로바이더도 이 메서드를 호출해요. [앱이 포그라운드로 돌아올 때](../lifecycle/#앱이-포그라운드로-돌아올-때)를 참고하세요.

마운트된 클라이언트만 앱이 포그라운드로 돌아오거나 네트워크가 다시 연결될 때 데이터를 다시 가져와요. 멈춘 뮤테이션을 이어서 실행하는 것도 마운트된 클라이언트뿐이에요. `Fuery.client`는 항상 마운트돼 있고, `FueryProvider`는 자신의 클라이언트를 마운트해요. 어댑터가 그 밖의 클라이언트를 사용하면 `mount()`를 호출하고, 사용을 멈출 때 `unmount()`를 호출하세요. Flutter 밖에서는 `focusManager.setEventListener`로 호스트의 포커스 이벤트를 연결하세요. [QueryClient 레퍼런스](../../reference/query-client/)를 참고하세요.

## Fuery 소스 코드에서

- [`adapter_test.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_core/test/adapter_test.dart)는 Flutter 없이 슬롯으로 쿼리를 렌더링해요.
- [`hooks.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_hooks/lib/src/hooks.dart)는 `fuery_hooks`의 모든 훅을 슬롯으로 만들어요.
- [`result_subscriber.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/lib/src/result_subscriber.dart)는 `fuery`의 위젯을 슬롯으로 만들어요.
