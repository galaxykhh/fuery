---
title: 쿼리 결과
description: Flutter에서 Fuery의 위젯, 훅, 스트림이 쿼리마다 받는 상태, 데이터, 에러, 가져오기 플래그, 무한 쿼리의 페이지
sourceHash: 6744567777c2
---

모든 쿼리 위젯, `useQuery`, 옵저버 스트림은 `QueryResult`를 받아요. 무한 쿼리는 `InfiniteQueryResult`를 알려요. `InfiniteQueryResult`에는 페이지와 페이지 액션이 더 있어요. 어떤 필드를 읽을지는 알고 싶은 것에 따라 달라요.

- **무엇을 보여줄지:** `data`가 `null`이 아니면 `data`를, 그다음은 `error`를, 둘 다 없으면 로딩 표시를 보여주세요. 다시 가져오다가 실패해도 이전 `data`는 남아 있어요.
- **요청이 실행 중인지:** `isFetching`을 읽으세요. 데이터가 화면에 있는 동안 백그라운드에서 다시 가져오는지는 `isRefetching`으로 알 수 있어요.
- **왜 실패했는지:** 가져오기를 포기한 뒤에는 `error`를, 아직 재시도하는 중이면 `failureReason`과 `failureCount`를 읽으세요.

## QueryResult 필드

enum 두 개가 상태를 담고, 나머지 필드는 데이터와 마지막 가져오기를 설명해요.

| 필드 | 타입 | 의미 |
|---|---|---|
| `status` | `QueryStatus` | `pending`, `error`, `success` 중 하나. [QueryStatus와 FetchStatus](#querystatus와-fetchstatus)를 참고하세요. |
| `fetchStatus` | `FetchStatus` | `fetching`, `paused`, `idle` 중 하나 |
| `data` | `TData?` | 최신 데이터. 첫 데이터를 받기 전에는 `null`이에요. 다시 가져오다가 실패해도 유지돼요. |
| `error` | `Object?` | 마지막으로 실패한 가져오기의 에러. 가져오기가 성공하거나, 데이터가 없는 쿼리가 다시 가져오는 동안에는 다시 `null`이 돼요. |
| `dataUpdatedAt` | `int` | `data`가 마지막으로 바뀐 시각(epoch 이후 밀리초). 바뀐 적이 없으면 `0`이에요. |
| `errorUpdatedAt` | `int` | `error`가 마지막으로 설정된 시각(epoch 이후 밀리초). 설정된 적이 없으면 `0`이에요. |
| `errorUpdateCount` | `int` | 가져오기가 실패한 횟수 |
| `failureCount` | `int` | 마지막 가져오기에서 실패한 시도 수. 재시도도 포함해요. 가져오기가 시작되거나 성공하면 `0`으로 돌아가요. |
| `failureReason` | `Object?` | 마지막으로 실패한 시도의 에러. `failureCount`가 초기화될 때 함께 비워져요. |
| `isFetched` | `bool` | 쿼리가 한 번 이상 가져오기를 끝냈거나 `setData`로 데이터를 받았어요. |
| `isFetchedAfterMount` | `bool` | 위와 같지만, 이 옵저버에 첫 리스너가 생긴 뒤부터 따져요. |
| `isPlaceholderData` | `bool` | `data`가 `placeholderData`에서 왔어요. 그동안 `status`는 `success`예요. |
| `isStale` | `bool` | 데이터가 `staleTime`보다 오래됐거나, 무효화됐거나, 없어요. 그래서 다음 트리거에서 다시 가져와요. 꺼진 쿼리에서는 항상 `false`예요. |
| `isEnabled` | `bool` | `enabled`가 `false`가 아니에요. 그래서 쿼리가 알아서 데이터를 가져와요. |
| `observer` | `QueryObserver<TData>?` | 이 결과를 알린 옵저버. 테스트에서처럼 `QueryResult` 생성자로 만든 결과에서는 `null`이에요. |

나머지 멤버는 이 필드를 바탕으로 한 질문이에요.

| 질문 | 타입 | `true`인 경우 |
|---|---|---|
| `isPending`, `isSuccess`, `isError` | `bool` | `status`가 그 값일 때 |
| `hasData` | `bool` | `data`가 `null`이 아닐 때 |
| `isFetching`, `isPaused` | `bool` | `fetchStatus`가 그 값일 때 |
| `isLoading` | `bool` | 처음 불러올 때. `pending` 상태이면서 가져오는 중일 때 |
| `isRefetching` | `bool` | 데이터가 화면에 있는 동안 가져올 때 |
| `isLoadingError` | `bool` | 데이터가 도착하기 전에 가져오기가 실패했을 때 |
| `isRefetchError` | `bool` | 데이터가 화면에 있는 동안 가져오기가 실패했을 때 |

### QueryStatus와 FetchStatus

| 값 | 의미 |
|---|---|
| `QueryStatus.pending` | 아직 데이터도 에러도 없어요. |
| `QueryStatus.error` | 마지막 가져오기가 실패했어요. `data`에는 이전 데이터가 남아 있어요. |
| `QueryStatus.success` | 쿼리에 데이터가 있고, 마지막 가져오기가 실패하지 않았어요. |
| `FetchStatus.fetching` | 쿼리 함수가 실행 중이에요. |
| `FetchStatus.paused` | 가져오기가 네트워크를 기다리거나, 재시도가 네트워크나 앱이 포그라운드로 돌아오기를 기다려요. |
| `FetchStatus.idle` | 아무것도 가져오고 있지 않아요. |

## QueryResult 액션

`refetch()`는 쿼리를 다시 실행하고 `Future<QueryResult<TData>>`를 반환해요. 당겨서 새로고침이나 재시도 버튼에서 호출하세요.

```dart
RefreshIndicator(
  onRefresh: () => state.refetch(),
  child: TodoList(state.data ?? const []),
)
```

| 인수 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `cancelRefetch` | `bool` | `true` | 쿼리에 데이터가 있을 때 이미 가져오는 중이면 취소하고 새로 가져와요. `false`거나 데이터가 없으면 이미 시작된 가져오기에 합류해요. |
| `throwOnError` | `bool` | `false` | `true`면 반환된 `Future`가 가져오기의 에러로 실패해요. 그렇지 않으면 에러는 결과에만 담겨요. |

- 반환된 `Future`는 가져오기가 끝난 뒤 결과로 완료돼요.
- 옵저버의 현재 쿼리를 다시 가져와요. 위젯이 다른 키로 바뀌었다면 새 키를 다시 가져와요.
- `enabled`가 `false`여도 가져와요.
- 생성자로 만든 결과에는 옵저버가 없어요. 그래서 이 결과의 `refetch()`를 호출하면 `StateError`가 발생해요.

## InfiniteQueryResult 필드

`InfiniteQueryResult`에는 모든 [`QueryResult` 필드](#queryresult-필드)가 있고, `data`의 타입은 `InfiniteData<TPage, TParam>`이에요. 여기에 이런 필드가 더 있어요.

| 필드 | 타입 | 의미 |
|---|---|---|
| `pages` | `List<TPage>` | 불러온 페이지. 첫 페이지를 불러오기 전에는 빈 리스트예요. `data`에는 같은 페이지와 각 페이지의 파라미터가 담겨 있어요. |
| `hasNextPage` | `bool` | `getNextPageParam`이 파라미터를 반환했어요. 첫 페이지를 불러오기 전에는 `false`예요. |
| `hasPreviousPage` | `bool` | `getPreviousPageParam`이 파라미터를 반환했어요. 이 옵션이 없으면 `false`예요. |
| `isFetchingNextPage` | `bool` | `fetchNextPage()`가 실행 중이에요. |
| `isFetchingPreviousPage` | `bool` | `fetchPreviousPage()`가 실행 중이에요. |
| `isFetchNextPageError` | `bool` | 마지막 가져오기가 `fetchNextPage()`였고, 실패했어요. |
| `isFetchPreviousPageError` | `bool` | 마지막 가져오기가 `fetchPreviousPage()`였고, 실패했어요. |
| `observer` | `InfiniteQueryObserver<TPage, TParam>?` | `QueryResult`와 마찬가지로 이 결과를 알린 옵저버 |

`isRefetching`과 `isRefetchError`는 모든 페이지를 다시 가져올 때만 해당해요. 그래서 페이지 하나를 불러오거나 불러오다가 실패하는 동안에는 둘 다 `false`로 남아요.

## InfiniteQueryResult 액션

`fetchNextPage()`는 마지막으로 불러온 페이지의 다음 페이지를, `fetchPreviousPage()`는 첫 페이지의 이전 페이지를 불러와요. 두 메서드는 [`refetch()`](#queryresult-액션)와 같은 인수를 받고, 페이지를 불러온 뒤 결과를 반환해요.

- 쿼리에 데이터가 있으면, `hasNextPage`나 `hasPreviousPage`가 `false`일 때 호출해도 아무것도 하지 않아요.
- 데이터가 없으면 쿼리를 첫 페이지부터 불러오거나, 이미 시작된 불러오기에 합류해요.
- 같은 페이지를 불러오는 중에 호출하면 그 가져오기에 합류해요.
- 기본값인 `cancelRefetch: true`면, 모든 페이지를 다시 가져오는 것처럼 다른 가져오기가 있을 때 먼저 취소해요. `false`면 그 가져오기에 합류하고 페이지를 불러오지 않아요.

`refetch()`는 불러온 페이지를 모두 순서대로 다시 불러와요. [불러온 페이지 모두 다시 가져오기](../../guides/infinite-queries/#불러온-페이지-모두-다시-가져오기)를 참고하세요.

## InfiniteData 필드

`InfiniteData<TPage, TParam>`은 무한 쿼리의 `data`이고, `getNextPageParam`과 `getPreviousPageParam`이 받는 값이에요.

| 멤버 | 타입 | 설명 |
|---|---|---|
| `pages` | `List<TPage>` | 불러온 모든 페이지를 순서대로 담은 리스트 |
| `pageParams` | `List<TParam>` | 페이지마다 불러올 때 사용한 파라미터. 인덱스가 페이지와 같아요. |
| `firstPage`, `lastPage` | `TPage` | 불러온 첫 페이지와 마지막 페이지 |
| `firstPageParam`, `lastPageParam` | `TParam` | 그 두 페이지의 파라미터 |
| `mapPages(transform)` | `InfiniteData<TPage, TParam>` | 페이지마다 `transform`이 반환한 값으로 바꾸고 파라미터는 그대로 둔 같은 데이터. [캐시된 페이지의 항목 업데이트하기](../../guides/infinite-queries/#캐시된-페이지의-항목-업데이트하기)를 참고하세요. |

페이지가 없으면 `firstPage`, `lastPage`와 그 파라미터를 읽을 때 `StateError`가 발생해요. `setData`나 `initialData`로 페이지를 쓰려면 `InfiniteData(pages: ..., pageParams: ...)`로 데이터를 만드세요. 파라미터는 페이지마다 하나씩 넣으세요.
