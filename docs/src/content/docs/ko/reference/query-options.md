---
title: 쿼리 옵션
description: Flutter에서 Query와 InfiniteQuery의 옵션마다 타입, 기본값, 바꾸는 동작을 알려줘요.
sourceHash: d451e877320c
---

`Query`와 `InfiniteQuery`의 모든 옵션과 타입, 기본값이에요. `InfiniteQuery`는 이 옵션을 모두 받고, [InfiniteQuery 옵션](#infinitequery-옵션)에 있는 옵션도 받아요. 모든 쿼리나 한 접두사 아래의 모든 키에 적용할 기본값을 바꾸려면 클라이언트에 `QueryDefaults`를 설정하세요. [기본값](../query-client/#기본값)을 참고하세요.

옵션을 사용하는 예는 [쿼리](../../guides/queries/)에 있어요.

## 가져오기

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `queryKey` | `List<Object?>` | 필수 | 캐시 항목을 구분하는 이름이에요. [쿼리 키](../../guides/queries/#쿼리-키)를 참고하세요. |
| `queryFn` | `Future<TData> Function(QueryFunctionContext)` | 필수 | 데이터를 가져와요. [쿼리 함수 컨텍스트](#쿼리-함수-컨텍스트)를 받아요. |
| `enabled` | `bool` | `true` | `false`면 쿼리가 스스로 데이터를 가져오지 않아요. `refetch()`로는 여전히 가져와요. |
| `meta` | `Map<String, Object?>` | 없음 | 쿼리 함수가 `context.meta`로 읽는 값 |

## fresh 상태와 캐싱

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `staleTime` | `Duration` | 0 | 데이터가 fresh 상태로 남는 시간이에요. `infiniteDuration`이면 무효화할 때까지 fresh 상태예요. `staticStaleTime`이면 무효화도 무시해요. |
| `gcTime` | `Duration` | 5분 | 가비지 컬렉션 시간이에요. 아무것도 사용하지 않는 캐시 항목이 메모리에 남는 시간이에요. 캐시 항목은 옵저버가 요청한 `gcTime` 중 가장 긴 값을 유지해요. |
| `structuralSharing` | `bool` | `true` | 다시 가져왔을 때 바뀌지 않은 객체는 캐시된 객체를 그대로 유지해요. [바뀐 부분만 다시 빌드하기](../../guides/queries/#바뀐-부분만-다시-빌드하기)를 참고하세요. |
| `persist` | `QueryPersist<TData>` | 없음 | 클라이언트의 `storage`로 데이터를 기기에 저장해요. [캐시를 기기에 저장하기](../../guides/persistence/)를 참고하세요. |

## 다시 가져오기

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `refetchOnMount` | `RefetchMode` | `RefetchMode.ifStale` | 위젯이나 스트림이 쿼리를 사용하기 시작할 때 다시 가져와요. `.always`는 fresh 데이터도 다시 가져와요. `.never`는 캐시된 데이터를 다시 가져오지 않고 보여줘요. |
| `refetchOnFocus` | `RefetchMode` | `RefetchMode.ifStale` | 앱이 포그라운드로 돌아올 때 다시 가져와요. |
| `refetchOnReconnect` | `RefetchMode` | `RefetchMode.ifStale`, `NetworkMode.always`면 `.never` | 네트워크가 다시 연결될 때 다시 가져와요. |
| `refetchInterval` | `Duration` | 없음 | 위젯이나 스트림이 쿼리를 사용하는 동안, 쿼리가 마지막으로 바뀐 때부터 이 간격마다 폴링해요. |
| `refetchIntervalInBackground` | `bool` | `false` | 앱이 백그라운드에 있는 동안에도 폴링해요. |
| `refetchWhile` | `bool Function(QueryResult<TData>)` | 없음 | 최신 결과에 이 함수가 `true`를 반환하는 동안에만 폴링해요. Fuery는 결과가 바뀔 때마다, 그리고 첫 데이터가 도착하기 전에 이 함수를 확인해요. |

## 실패

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `retry` | `RetryPolicy` | `RetryPolicy.count(3)`, `client.query`에서는 `.never()` | 실패한 가져오기를 얼마나 재시도할지 정해요. `.count(n)`, `.never()`, `.always()`, `.when((failureCount, error) => ...)` 중 하나예요. 첫 실패에서 `failureCount`는 0이에요. |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1초, 2초, 4초, … 최대 30초 | 재시도하기 전에 기다리는 시간 |
| `retryOnMount` | `bool` | `true` | `false`면 데이터 없이 실패한 쿼리를 위젯이 사용하기 시작해도 다시 가져오지 않아요. |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `.online`은 기기가 오프라인인 동안 가져오기를 멈춰요. `.always`는 연결 상태를 무시해요. `.offlineFirst`는 첫 시도는 실행하고, 오프라인인 동안 재시도를 멈춰요. [네트워크가 다시 연결될 때](../../guides/lifecycle/#네트워크가-다시-연결될-때)를 참고하세요. |

## 가져오기 전에 보여줄 데이터

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `initialData` | `TData` | 없음 | 이 데이터를 가져온 것처럼 캐시 항목을 미리 채워요. |
| `initialDataUpdatedAt` | `int` | 현재 시각 | `initialData`를 가져온 시각(epoch 이후 밀리초)이에요. 미리 채운 데이터가 이미 stale 상태인지 판단할 때 사용해요. |
| `placeholderData` | `TData? Function(TData? previousData, QueryClient client)` | 없음 | 쿼리가 `pending` 상태인 동안 보여줄 데이터예요. Fuery는 이 데이터를 캐시에 쓰지 않아요. 옵저버가 이전에 보여준 키의 데이터와 클라이언트를 받아요. `keepPreviousData`는 그 데이터를 반환해요. [이전 페이지를 화면에 유지하기](../../guides/queries/#이전-페이지를-화면에-유지하기)를 참고하세요. |

## InfiniteQuery 옵션

`InfiniteQuery<TPage, TParam>`은 `Query`의 모든 옵션을 받고, 데이터 타입은 `InfiniteData<TPage, TParam>`이에요. `TPage`는 페이지 하나의 타입이고, `TParam`은 페이지를 가리키는 파라미터의 타입이에요. 옵션을 사용하는 예는 [무한 쿼리](../../guides/infinite-queries/)에 있어요.

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `queryFn` | `Future<TPage> Function(InfiniteQueryFunctionContext<TParam>)` | 필수 | 페이지 하나를 가져와요. `context.pageParam`이 가리키는 페이지예요. |
| `initialPageParam` | `TParam` | 필수 | 첫 페이지의 파라미터예요. Fuery는 이 값에서 `TParam`을 추론해요. 첫 파라미터가 `null`이면 타입을 직접 선언해야 해요. [커서 기반 페이지](../../guides/infinite-queries/#커서-기반-페이지)를 참고하세요. |
| `getNextPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | 필수 | `data.lastPage` 다음 페이지의 파라미터를 반환하고, 다음 페이지가 없으면 `null`을 반환해요. 반드시 `TParam`을 반환해야 해요. [페이지 파라미터 에러](#페이지-파라미터-에러)를 참고하세요. |
| `getPreviousPageParam` | `Object? Function(InfiniteData<TPage, TParam>)` | 없음 | `data.firstPage` 이전 페이지의 파라미터나 `null`을 반환해요. 이 옵션이 없으면 `hasPreviousPage`는 항상 `false`이고, 쿼리에 데이터가 생긴 뒤에는 `fetchPreviousPage()`가 아무것도 불러오지 않아요. |
| `maxPages` | `int` | 없음 | 유지할 최대 페이지 수예요. 최대치에 이르면 다음 페이지를 불러올 때 첫 페이지를 버리고, 이전 페이지를 불러올 때 마지막 페이지를 버려요. |
| `pages` | `int` | 1 | 캐시된 데이터가 없을 때 불러올 페이지 수예요. `maxPages`를 넘지 않아요. 캐시된 페이지가 있으면, 모든 페이지를 가져올 때 이 값 대신 캐시된 페이지를 다시 불러와요. |
| `persist` | `InfiniteQueryPersist<TPage, TParam>` | 없음 | 페이지를 기기에 저장해요. [무한 쿼리 저장하기](../../guides/persistence/#무한-쿼리-저장하기)를 참고하세요. |
| `refetchWhile` | `bool Function(InfiniteQueryResult<TPage, TParam>)` | 없음 | `Query`의 `refetchWhile`과 같지만, 무한 쿼리의 결과를 받아요. |

`setData`로 쓴 페이지처럼 `maxPages`를 넘는 캐시된 페이지는 다음 페이지나 이전 페이지를 불러올 때까지 남아 있어요. 그때 `maxPages`개로 줄어요. 다시 가져올 때는 그중 앞의 `maxPages`개만 다시 불러와요.

### 페이지 파라미터 에러

Dart는 타입 추론을 잃지 않고는 `getNextPageParam`과 `getPreviousPageParam`의 반환값을 검사할 수 없어요. 그래서 Fuery가 런타임에 파라미터를 검사해요.

- `hasNextPage`나 `hasPreviousPage`를 정하려고 Fuery가 결과를 만드는 동안에는, 다른 타입의 파라미터를 페이지가 없는 것으로 봐요. 빈 페이지에서 `data.lastPage.last`를 읽는 것처럼 함수에서 에러가 발생해도 마찬가지예요.
- 다시 가져올 때처럼 페이지를 불러오는 동안에는, 다른 타입의 파라미터가 나오면 그 페이지에서 불러오기를 멈춰요. 함수에서 에러가 발생하면 가져오기가 실패해요.

Fuery는 다른 타입의 파라미터와 결과를 만드는 동안 발생한 에러를 [`onUncaughtError`](../../guides/client-setup/#콜백에서-발생한-에러-잡기)로 전달해요. 클라이언트, 함수, 키마다 한 번만 전달해요.

두 함수는 항상 페이지를 하나 이상 받아요. 그래서 `data.lastPage`와 `data.firstPage`는 항상 있어요.

## 쿼리 함수 컨텍스트

모든 쿼리 함수는 `QueryFunctionContext`를 받아요. 이 컨텍스트에는 위젯 트리의 값이 들어 있지 않아요. 그래서 쿼리를 만든 위젯이 사라진 뒤에도 쿼리 함수가 실행될 수 있어요.

| 필드 | 타입 | 주는 값 |
|---|---|---|
| `client` | `QueryClient` | 가져오기를 실행하는 클라이언트. 다른 캐시된 데이터를 읽을 때 사용해요. |
| `queryKey` | `List<Object?>` | 가져오는 키. 이 키로 요청을 만들어요. |
| `meta` | `Map<String, Object?>?` | `meta` 옵션의 값 |
| `signal` | `AbortSignal` | 가져오기를 취소하면 중단돼요. 이 값을 읽으면 가져오기를 취소할 수 있게 돼요. [요청 취소하기](../../guides/queries/#요청-취소하기)를 참고하세요. |

무한 쿼리의 함수는 `InfiniteQueryFunctionContext<TParam>`을 받아요. 여기에는 불러올 페이지의 파라미터인 `pageParam`이 더 있어요.
