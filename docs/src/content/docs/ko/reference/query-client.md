---
title: QueryClient
description: Flutter용 Fuery에서 QueryClient의 모든 옵션, 메서드, 필터, 기본값, 캐시 필드와 그 타입, 기본값
sourceHash: 0f608d9305c6
---

`QueryClient`는 쿼리 캐시와 뮤테이션 캐시를 소유해요. 캐시된 데이터를 읽고, 쓰고, 다시 가져오는 일은 모두 `QueryClient`를 거쳐요. 쿼리 캐시는 쿼리 키마다 캐시 항목(`CachedQuery`)을 하나씩 유지해요. 캐시 항목은 그 키의 데이터와 상태를 담아요. 뮤테이션 캐시는 `mutate` 호출마다 실행(`CachedMutation`)을 하나씩 유지해요. 작업별 안내는 [캐시 읽고 업데이트하기](../../guides/query-client/)와 [클라이언트 설정하기](../../guides/client-setup/)를 참고하세요.

## 생성자 옵션

| 이름 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `queryCache` | `QueryCache` | `QueryCache()` | 캐시 항목을 담아요. [`QueryCacheConfig`](#캐시-콜백)를 주려면 직접 만들어 넘기세요. |
| `mutationCache` | `MutationCache` | `MutationCache()` | 뮤테이션 실행을 담아요. [`MutationCacheConfig`](#캐시-콜백)를 주려면 직접 만들어 넘기세요. |
| `defaultOptions` | `DefaultOptions` | `DefaultOptions()` | 모든 쿼리와 뮤테이션의 기본값. [기본값](#기본값)을 참고하세요. |
| `storage` | `QueryStorage?` | `null` | `persist`가 있는 쿼리와 뮤테이션이 데이터를 기기에 저장하는 곳. 스토리지가 없으면 `persist`는 아무것도 하지 않아요. |
| `persistMaxAge` | `Duration` | 1일 | 저장된 데이터를 복원할 수 있는 최대 기간이에요. 쿼리의 `QueryPersist`가 `maxAge`를 설정하면 `maxAge`를 따라요. |
| `onUncaughtError` | `void Function(Object error, StackTrace stackTrace)?` | `null` | 호출한 쪽에서 잡을 수 없는 에러를 받아요. 이 옵션이 없으면 에러는 현재 zone으로 전달돼요. [콜백에서 발생한 에러 잡기](../../guides/client-setup/#콜백에서-발생한-에러-잡기)를 참고하세요. |

옵션은 모두 클라이언트의 필드이기도 해요.

마운트된 클라이언트만 앱이 포그라운드로 돌아오거나 네트워크가 다시 연결될 때 데이터를 다시 가져와요. 멈춘 뮤테이션을 이어서 실행하는 것도 마운트된 클라이언트뿐이에요. `Fuery.client`에 할당하거나 `FueryProvider`에 넘긴 클라이언트는 마운트돼요. 그 밖의 클라이언트는 `mount()`와 `unmount()`를 직접 호출하세요.

## 데이터 읽고 쓰기

`TData`는 쿼리의 데이터 타입이에요. `updatedAt`은 데이터를 언제 가져온 것으로 볼지 정해요. 단위는 epoch 이후 밀리초이고, 기본값은 현재 시각이에요.

| 메서드 | 반환 타입 | 설명 |
|---|---|---|
| `getData(query)` | `TData?` | 쿼리의 캐시된 데이터. 없으면 `null`이에요. |
| `setData(query, data, {updatedAt})` | `TData` | 데이터를 써요. 이 메서드가 만든 캐시 항목은 `persist`를 포함해 쿼리의 모든 옵션을 받아요. |
| `updateData(query, updater, {updatedAt})` | `TData?` | 현재 데이터로 `updater`를 호출하고, 반환값을 써요. 캐시된 데이터가 없으면 현재 데이터는 `null`이에요. `updater`가 `null`을 반환하면 캐시가 바뀌지 않아요. |
| `getQueryData<TData>(queryKey)` | `TData?` | 키의 캐시된 데이터. 없으면 `null`이에요. 키에 다른 데이터 타입이 담겨 있으면 `StateError`가 발생해요. |
| `setQueryData<TData>(queryKey, data, {updatedAt})` | `TData` | 키로 데이터를 써요. 이 메서드가 만든 캐시 항목에는 쿼리 함수가 없어요. 그래서 옵저버나 `client.query`가 그 키의 쿼리를 넘겨주기 전까지는 다시 가져오지 않아요. |
| `updateQueryData<TData>(queryKey, updater, {updatedAt})` | `TData?` | 키로 호출하는 `updateData` |
| `getQueriesData<TData>({queryKey, exact, predicate})` | `List<(List<Object?>, TData?)>` | 조건에 맞는 모든 캐시 항목의 키와 데이터. 조건에 맞는 캐시 항목에는 모두 `TData`가 담겨 있어야 해요. |
| `updateQueriesData<TData>(updater, {queryKey, exact, predicate, updatedAt})` | `void` | 조건에 맞는 캐시 항목 가운데 데이터 타입이 정확히 `TData`인 캐시 항목을 모두 업데이트해요. `TData`는 `updater`의 매개변수 타입에서 알아내요. 매개변수에 타입이 없으면 `ArgumentError`가 발생해요. |
| `getQueryState(queryKey)` | `QueryState<Object>?` | 키의 캐시 항목의 상태. 없으면 `null`이에요. [QueryState 필드](#querystate-필드)를 참고하세요. |
| `watch<T>(selector)` | `Stream<T>` | `selector(client)`의 값을 내보내는 브로드캐스트 스트림 |

`watch`는 리스너마다 현재 값을 먼저 줘요. 그 뒤 쿼리 캐시나 뮤테이션 캐시가 바뀌었을 때 새 값이 다르면 다시 내보내요. 리스트, 맵, 세트는 내용으로 비교하고, 다른 값은 `==`로 비교해요. `selector`에서 발생한 에러는 스트림으로 전달돼요. 지켜보는 것만으로는 데이터를 가져오지 않아요.

## 가져오기

| 메서드 | 반환 타입 | 설명 |
|---|---|---|
| `query(query)` | `Future<TData>` | 캐시된 데이터가 쿼리의 `staleTime` 동안 fresh 상태면 그 데이터를 반환하고, 아니면 데이터를 가져와요. |
| `infiniteQuery(query)` | `Future<InfiniteData<TPage, TParam>>` | `InfiniteQuery`용 `query`예요. 캐시된 데이터가 없으면 쿼리의 `pages`만큼 불러와요(기본값 1, 최대 `maxPages`). 캐시된 페이지가 있으면 첫 페이지부터 `maxPages`까지 다시 불러와요. |

두 메서드는 이 규칙을 따라요.

- 가져와야 할 때 그 키를 이미 가져오는 중이면, 새로 가져오지 않고 그 가져오기가 끝나기를 기다려요.
- 가져오다가 실패하면 `Future`도 실패해요.
- 쿼리, `defaultOptions`, 그 키에 호출한 `setQueryDefaults` 중 하나가 `retry`를 설정해야만 Fuery가 실패한 가져오기를 재시도해요.

## 조건에 맞는 쿼리를 다루는 메서드

메서드마다 [쿼리 필터](#쿼리-필터)와, 표의 같은 행에 있는 인수를 받아요.

| 메서드 | 반환 타입 | 하는 일 | 추가 인수 |
|---|---|---|---|
| `invalidateQueries` | `Future<void>` | 조건에 맞는 캐시 항목을 stale 상태로 표시하고, 그중 활성 캐시 항목을 다시 가져와요. | `refetchType`, `cancelRefetch`, `throwOnError` |
| `refetchQueries` | `Future<void>` | 조건에 맞는 캐시 항목을 다시 가져와요. | `cancelRefetch`, `throwOnError` |
| `resetQueries` | `Future<void>` | 조건에 맞는 캐시 항목을 초기 상태로 되돌리고, 저장된 데이터를 삭제하고, 그중 활성 캐시 항목을 다시 가져와요. | `cancelRefetch`, `throwOnError` |
| `cancelQueries` | `Future<void>` | 조건에 맞는 캐시 항목을 이미 가져오는 중이면 취소해요. | `revert`, `silent` |
| `removeQueries` | `void` | 조건에 맞는 캐시 항목을 캐시에서 제거하고, 저장된 데이터도 삭제해요. | 없음 |
| `isFetching` | `int` | 조건에 맞는 캐시 항목 가운데 가져오는 중인 캐시 항목의 수를 반환해요. | 없음 |

`invalidateQueries`, `refetchQueries`, `resetQueries`는 이런 캐시 항목을 다시 가져오지 않아요.

- 꺼진 캐시 항목: `isDisabled`가 `true`예요.
- 정적이고 데이터가 있는 캐시 항목: 옵저버가 `staleTime: staticStaleTime`을 사용해요.
- `setQueryData`로만 쓴 캐시 항목: 아직 쿼리 함수가 없어요.

세 메서드의 `Future`는 다시 가져오기가 끝나면 완료돼요. 네트워크를 기다리는 가져오기처럼 멈춘 가져오기는 기다리지 않아요.

`removeQueries`와 `clear()`는 아직 구독 중인 옵저버를 멈추지 않아요. Fuery는 그 옵저버를 같은 키의 새 캐시 항목으로 옮기고, 새 캐시 항목은 데이터를 다시 불러와요.

```dart
// Refetch the stale cache entries under ['todos'] now,
// and fail if a refetch fails.
await client.refetchQueries(
  queryKey: ['todos'],
  stale: true,
  throwOnError: true,
);

// Stop the list's fetch and put back the state it had before.
await client.cancelQueries(queryKey: ['todos'], exact: true);
```

## 쿼리 필터

캐시 항목은 설정한 필터에 모두 맞아야 해요.

| 필터 | 타입 | 기본값 | 선택 대상 |
|---|---|---|---|
| `queryKey` | `List<Object?>?` | 모든 캐시 항목 | 키가 이 키로 시작하는 캐시 항목. `['todos']`는 `['todos', 1]`과 일치해요. |
| `exact` | `bool` | `false` | `true`면 키가 `queryKey`와 같은 캐시 항목만 |
| `type` | `QueryTypeFilter` | `QueryTypeFilter.all` | `.active`: 켜진 옵저버가 하나 이상 사용하는 캐시 항목. `.inactive`: 그런 옵저버가 없는 캐시 항목 |
| `stale` | `bool?` | `null` | `true`면 stale 상태인 캐시 항목, `false`면 fresh 상태인 캐시 항목 |
| `predicate` | `bool Function(CachedQuery<Object> query)?` | `null` | 이 함수가 `true`를 반환하는 캐시 항목 |

`invalidateQueries`는 `type`을 `QueryTypeFilter?`로 받고, 기본값은 `null`이에요. `type`을 설정하지 않으면 `.all`처럼 조건에 맞는 캐시 항목을 모두 stale 상태로 표시하지만, 다시 가져오는 것은 활성 캐시 항목뿐이에요. `.all`이면 비활성 캐시 항목도 다시 가져와요.

`queryCache.find`와 `findAll`이 받는 `QueryFilters`에는 이 필드에 더해 `fetchStatus`도 있어요. `fetchStatus`는 `FetchStatus?` 타입이고, 그 가져오기 상태인 캐시 항목을 골라요. `matches(query)`는 캐시 항목 하나가 조건에 맞는지 확인해요.

## 다시 가져오기와 취소 인수

| 인수 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `refetchType` | `RefetchType?` | `null` | `invalidateQueries`가 조건에 맞는 캐시 항목 가운데 무엇을 다시 가져올지 정해요. `RefetchType.active`, `.inactive`, `.all` 중 하나이고, `.none`은 stale 상태로 표시만 해요. |
| `cancelRefetch` | `bool` | `true` | 데이터가 있는 캐시 항목을 이미 가져오는 중이면 취소하고 새로 가져와요. `false`면 이미 시작된 가져오기를 기다려요. 첫 데이터를 불러오는 캐시 항목은 항상 하던 가져오기를 유지해요. |
| `throwOnError` | `bool` | `false` | `true`면 다시 가져오다가 실패할 때 반환된 `Future`도 실패해요. |
| `revert` | `bool` | `true` | 취소한 캐시 항목을 가져오기 전 상태로 되돌려요. `false`면 `CancelledError`를 에러로 기록해요. |
| `silent` | `bool` | `false` | `true`이고 `revert: false`면 에러를 기록하지 않아요. 캐시 항목은 상태를 유지하고 `idle`로 돌아가요. |

`refetchType`이 없으면 `invalidateQueries`는 `type`이 고른 캐시 항목을 다시 가져와요. `type`도 설정하지 않았으면 활성 캐시 항목을 다시 가져와요.

```dart
// Mark every cache entry under ['todos'] stale, refetch the ones
// nothing shows too, and let fetches in flight finish instead of
// restarting them.
await client.invalidateQueries(
  queryKey: ['todos'],
  refetchType: RefetchType.all,
  cancelRefetch: false,
);
```

## 뮤테이션

| 메서드 | 반환 타입 | 설명 |
|---|---|---|
| `isMutating({mutationKey, exact, predicate})` | `int` | 조건에 맞는 뮤테이션 실행 가운데 `pending` 상태인 실행의 수를 반환해요. |
| `resumePausedMutations()` | `Future<void>` | 멈춘 뮤테이션을 모두 이어서 실행해요. 기기가 오프라인이면 아무것도 하지 않아요. |

`MutationFilters`는 뮤테이션 실행을 골라요. `isMutating`은 `MutationFilters`를 만들어 사용하고, `mutationCache.find`와 `findAll`은 `MutationFilters`를 받아요.

| 필터 | 타입 | 기본값 | 선택 대상 |
|---|---|---|---|
| `mutationKey` | `List<Object?>?` | 모든 실행 | `mutationKey`가 이 키로 시작하는 실행. 키가 없는 실행은 절대 일치하지 않아요. |
| `exact` | `bool` | `false` | `true`면 키가 `mutationKey`와 같은 실행만 |
| `status` | `MutationStatus?` | `null` | 이 상태인 실행. `isMutating`은 `MutationStatus.pending`으로 설정해요. |
| `predicate` | `bool Function(AnyCachedMutation mutation)?` | `null` | 이 함수가 `true`를 반환하는 실행 |

`matches(mutation)`은 실행 하나가 조건에 맞는지 확인해요.

```dart
final savingTodos = client.isMutating(
  mutationKey: ['todos'],
  exact: true,
  predicate: (mutation) => !mutation.state.isPaused,
);
```

## 기본값

`DefaultOptions`는 클라이언트의 기본값을 담아요.

| 필드 | 타입 | 기본값 |
|---|---|---|
| `queries` | `QueryDefaults` | `QueryDefaults()` |
| `mutations` | `MutationDefaults` | `MutationDefaults()` |

`QueryDefaults`는 쿼리 하나에만 해당하지 않는 [쿼리 옵션](../query-options/)을 받아요. `enabled`, `staleTime`, `gcTime`(가비지 컬렉션 시간), `refetchInterval`, `refetchIntervalInBackground`, `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect`, `retryOnMount`, `retry`, `retryDelay`, `networkMode`, `structuralSharing`, `meta`예요.

`MutationDefaults`는 [뮤테이션 옵션](../mutation-options/#옵션) 중 `gcTime`, `retry`, `retryDelay`, `networkMode`, `meta`를 받아요.

모든 필드는 null이 될 수 있어요. 설정하지 않은 필드는 옵션 자체의 기본값을 그대로 둬요.

| 메서드 | 반환 타입 | 설명 |
|---|---|---|
| `setQueryDefaults(queryKey, defaults)` | `void` | 키가 `queryKey`로 시작하는 모든 쿼리의 기본값을 설정해요. 같은 키로 다시 설정하면 새 기본값으로 바꿔요. |
| `getQueryDefaults(queryKey)` | `QueryDefaults` | 이 키에 일치하는 모든 접두사의 기본값을 합친 키별 기본값 |
| `setMutationDefaults(mutationKey, defaults)` | `void` | `mutationKey`가 이 `mutationKey`로 시작하는 모든 뮤테이션의 기본값을 설정해요. |
| `getMutationDefaults(mutationKey)` | `MutationDefaults` | 이 키에 일치하는 모든 접두사의 기본값을 합친 키별 기본값 |

우선순위는 높은 것부터 이 순서예요.

1. 쿼리나 뮤테이션에 설정한 옵션
2. 키별 기본값. 여러 접두사가 일치하면 접두사를 처음 등록한 순서대로 합치고, 나중에 등록한 것이 우선해요.
3. `defaultOptions`

`mutationKey`가 없는 뮤테이션은 `defaultOptions.mutations`만 받아요. `meta`는 합치지 않고 통째로 바꿔요.

## 캐시 콜백

캐시는 생성자에서 설정을 받고, 없어질 때까지 `config`로 유지해요.

`QueryCacheConfig`는 쿼리 캐시에서 가져올 때마다 콜백을 실행해요. 콜백은 모두 `void`를 반환하고, 마지막 인수로 캐시 항목(`CachedQuery<Object>`)을 받아요.

| 콜백 | 실행 시점 |
|---|---|
| `onSuccess(data, query)` | 가져오기가 성공한 뒤 |
| `onError(error, query)` | 가져오기가 실패하고 재시도도 모두 끝난 뒤 |
| `onSettled(data, error, query)` | 성공이나 실패 뒤 |

취소된 가져오기에서는 어떤 콜백도 실행되지 않아요. 콜백에서 발생한 에러는 `onUncaughtError`로 전달돼요.

`MutationCacheConfig`는 캐시의 모든 뮤테이션 실행마다 콜백을 실행해요. 콜백은 `Future`를 반환할 수 있고, 마지막 인수로 `AnyCachedMutation`을 받아요. `error`는 `Object`이고, `data`, `variables`, `context`는 `Object?`예요.

| 콜백 | 실행 시점 |
|---|---|
| `onMutate(variables, mutation)` | `mutationFn` 전 |
| `onSuccess(data, variables, context, mutation)` | 성공한 뒤 |
| `onError(error, variables, context, mutation)` | 실패한 뒤 |
| `onSettled(data, error, variables, context, mutation)` | 성공이나 실패 뒤 |

- 각 콜백은 같은 이름의 [뮤테이션 콜백](../mutation-options/#콜백)보다 먼저 실행돼요. 콜백이 `Future`를 반환하면 Fuery가 `await`로 기다려요.
- `restore`가 다시 시작한 실행은 두 `onMutate` 콜백을 모두 건너뛰어요.
- `onMutate`에서, 또는 성공한 뒤 `onSuccess`나 `onSettled`에서 에러가 발생하면 뮤테이션이 실패해요.
- 실패한 뒤 `onError`나 `onSettled`에서 발생한 에러는 `onUncaughtError`로 전달돼요.

## 캐시

`client.queryCache`와 `client.mutationCache`로 캐시를 읽어요. 캐시를 바꾸려면 클라이언트를 사용하세요.

| 메서드 | 반환 타입 | 설명 |
|---|---|---|
| `queryCache.getAll()` | `List<CachedQuery<Object>>` | 모든 캐시 항목 |
| `queryCache.find(filters)` | `CachedQuery<Object>?` | 조건에 맞는 첫 캐시 항목. `queryKey`는 정확히 일치하는지 비교해요. |
| `queryCache.findAll([filters])` | `List<CachedQuery<Object>>` | 조건에 맞는 모든 캐시 항목. 필터가 없으면 모든 캐시 항목이에요. |
| `queryCache.get(queryHash)` | `CachedQuery<Object>?` | `queryHash`가 이 값인 캐시 항목 |
| `mutationCache.getAll()` | `List<AnyCachedMutation>` | 모든 뮤테이션 실행 |
| `mutationCache.find(filters)` | `AnyCachedMutation?` | 조건에 맞는 첫 실행. `mutationKey`는 정확히 일치하는지 비교해요. |
| `mutationCache.findAll([filters])` | `List<AnyCachedMutation>` | 조건에 맞는 모든 실행. 필터가 없으면 모든 실행이에요. |

`CachedQuery<TData>`는 키 하나의 캐시 항목이에요.

| 필드 | 타입 | 설명 |
|---|---|---|
| `queryKey` | `List<Object?>` | 키 |
| `queryHash` | `String` | 키의 해시. 캐시 안에서 캐시 항목을 구분해요. |
| `state` | `QueryState<TData>` | [QueryState 필드](#querystate-필드)를 참고하세요. |
| `options` | `Query<TData>` | 캐시 항목이 가져올 때 사용하는 옵션. 기본값이 적용돼 있어요. |
| `meta` | `Map<String, Object?>?` | `options.meta` |
| `observers` | `List<QueryObserver<TData>>` | 캐시 항목을 사용하는 옵저버를 구독한 순서대로 담은 리스트 |
| `observersCount` | `int` | 캐시 항목을 사용하는 옵저버 수 |
| `isActive` | `bool` | 켜진 옵저버가 하나 이상 있어요. |
| `isDisabled` | `bool` | 캐시 항목을 알아서 가져오지 않아요. 모든 옵저버가 꺼져 있거나, 관찰하는 옵저버가 없고 `isFetched`가 `false`인 경우예요. |
| `isStale` | `bool` | 옵저버 하나 이상에게 stale 상태예요. 옵저버가 없으면 데이터가 없거나 무효화됐을 때 `true`예요. |
| `isStatic` | `bool` | 옵저버가 `staticStaleTime`을 사용해요. 그래서 캐시 항목이 절대 stale 상태가 되지 않아요. |
| `isFetched` | `bool` | 캐시 항목이 가져오기나 `setData` 같은 쓰기로 데이터나 에러를 한 번 이상 받았어요. 스토리지에서 복원한 데이터는 치지 않아요. |
| `isStaleByTime([staleTime])` | `bool` | 데이터가 없거나, 무효화됐거나, `staleTime`보다 오래됐어요. `staticStaleTime`이면 데이터가 있을 때 항상 `false`예요. |
| `future` | `Future<TData>?` | 이미 가져오는 중이면 그 가져오기 |

`CachedMutation<TData, TVariables, TContext>`는 뮤테이션 실행 하나예요.

| 필드 | 타입 | 설명 |
|---|---|---|
| `mutationId` | `int` | 캐시 안의 실행에 만든 순서대로 매긴 번호 |
| `options` | `Mutation<TData, TVariables, TContext>` | 실행이 사용하는 옵션. 기본값이 적용돼 있어요. |
| `state` | `MutationState<TData, TVariables, TContext>` | [MutationState 필드](../mutation-results/#mutationstate-필드)를 참고하세요. |
| `meta` | `Map<String, Object?>?` | `options.meta` |

`AnyCachedMutation`은 `CachedMutation<Object?, Object?, Object?>`예요. 호출하는 쪽이 타입을 모르는 실행이에요. 필터와 캐시 콜백은 실행을 이 타입으로 받아요. `AnyMutation`은 `restore(mutations:)`가 받는 정의의 타입으로, `Mutation<Object?, Object?, Object?>`예요.

## QueryState 필드

`QueryState<TData>`는 캐시 항목이 담는 상태예요. 옵저버는 이 상태로 `QueryResult`를 만들어요.

| 필드 | 타입 | 설명 |
|---|---|---|
| `data` | `TData?` | 캐시 항목이 마지막으로 받은 데이터. `null`이면 데이터가 없어요. |
| `status` | `QueryStatus` | `pending`, `error`, `success` 중 하나 |
| `fetchStatus` | `FetchStatus` | `fetching`, `paused`, `idle` 중 하나 |
| `error` | `Object?` | 마지막 시도가 실패했다면 그 에러 |
| `dataUpdatedAt` | `int` | `data`를 마지막으로 쓴 시각(epoch 이후 밀리초). 쓴 적이 없으면 `0`이에요. |
| `errorUpdatedAt` | `int` | `error`가 마지막으로 설정된 시각(epoch 이후 밀리초). 설정된 적이 없으면 `0`이에요. |
| `dataUpdateCount` | `int` | 캐시 항목이 가져오기나 `setData` 같은 쓰기로 데이터를 받은 횟수. 스토리지에서 복원한 데이터는 치지 않아요. |
| `errorUpdateCount` | `int` | 가져오기가 에러로 끝난 횟수. `revert: false`로 취소한 경우도 포함해요. |
| `fetchFailureCount` | `int` | 마지막 가져오기의 실패 횟수. 재시도도 포함해요. 가져오기가 시작되면 초기화돼요. `QueryResult`에서는 `failureCount`로 보여요. |
| `fetchFailureReason` | `Object?` | 그 실패 가운데 마지막 실패의 에러. `QueryResult`에서는 `failureReason`으로 보여요. |
| `isInvalidated` | `bool` | `invalidateQueries`를 호출하거나 가져오기가 실패하면 `true`예요. 새 데이터를 받으면 초기화돼요. |

`copyWith`는 넘긴 필드를 바꾼 복사본을 반환해요.

## 저장과 정리

| 멤버 | 타입 | 설명 |
|---|---|---|
| `storage` | `QueryStorage?` | 생성자에 넘긴 스토리지 |
| `restore({mutations})` | `Future<void>` | 저장된 쿼리를 모두 미리 읽고, 넘긴 뮤테이션의 저장된 실행을 다시 시작해요. 스토리지가 없으면 아무것도 하지 않아요. [미리 복원하기](../../guides/persistence/#미리-복원하기)를 참고하세요. |
| `clear()` | `void` | 모든 캐시 항목과 뮤테이션 실행을 제거하고, 저장된 데이터를 모두 삭제해요. 클라이언트와 키별 기본값은 유지해요. [로그아웃할 때 모두 비우기](../../guides/query-client/#로그아웃할-때-모두-비우기)를 참고하세요. |
