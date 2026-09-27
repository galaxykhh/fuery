---
title: 뮤테이션 옵션
description: Flutter용 Fuery에서 Mutation과 NoVariablesMutation의 모든 옵션과 타입, 기본값, 뮤테이션을 실행하는 메서드, mutate 호출 한 번의 콜백
sourceHash: 6b3b19657ff1
---

`Mutation`과 `NoVariablesMutation`의 모든 옵션과 타입, 기본값, 뮤테이션을 실행하는 메서드, 그리고 `MutateOptions`와 `MutationPersist`예요. 모든 뮤테이션이나 한 키 아래의 뮤테이션에 `gcTime`(가비지 컬렉션 시간), `retry`, `retryDelay`, `networkMode`, `meta`를 설정하려면 `MutationDefaults`([기본값](../query-client/#기본값))를 사용하세요. 옵션을 사용하는 예는 [뮤테이션](../../guides/mutations/)에 있어요.

## 옵션

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `mutationFn` | `Future<TData> Function(TVariables variables)` | 필수 | 바꿀 내용을 서버에 보내요. 매개변수 타입이 `TVariables`가 되고, 반환 타입이 `TData`가 돼요. |
| `mutationKey` | `List<Object?>` | 없음 | 실행(`mutate` 호출 한 번)을 구분해요. MutationState 위젯, `useMutationState`, `MutationFilters`, `restore`는 이 키로 실행을 찾아요. `setMutationDefaults`는 키가 받은 키로 시작하는 모든 뮤테이션에 기본값을 적용해요. |
| `gcTime` | `Duration` | 5분 | 실행이 끝나고 따라가는 옵저버가 없을 때, 실행이 뮤테이션 캐시에 남는 시간이에요. `infiniteDuration`이면 `clear()`까지 남아요. |
| `retry` | `RetryPolicy` | `RetryPolicy.never()` | 실패한 시도를 얼마나 재시도할지 정해요. `.count(n)`, `.always()`, `.when((count, error) => ...)` 중 하나예요. |
| `retryDelay` | `Duration Function(int failureCount, Object error)` | 1초, 2초, 4초, … 최대 30초 | 재시도하기 전에 기다리는 시간 |
| `networkMode` | `NetworkMode` | `NetworkMode.online` | `online`은 시도할 때마다 먼저 네트워크를 기다려요. `always`는 네트워크를 무시해요. `offlineFirst`는 첫 시도는 실행하고, 재시도 전에는 네트워크를 기다려요. |
| `scope` | `MutationScope` | 없음 | 스코프의 `id`가 같은 실행은 시작한 순서대로 하나씩 실행돼요. 차례를 기다리는 동안 실행의 `isPaused`는 `true`예요. |
| `persist` | `MutationPersist<TVariables>` | 없음 | 실행이 `pending` 상태인 동안 변수를 기기에 저장해요. 그래서 앱을 다시 시작한 뒤 `restore(mutations:)`가 그 실행을 다시 시작해요. `mutationKey`와 `storage`가 있는 클라이언트가 필요해요. `mutationKey`는 assert로 확인해요. [MutationPersist](#mutationpersist)를 참고하세요. |
| `meta` | `Map<String, Object?>` | 없음 | 아무 값이나 담아요. `MutationCacheConfig` 콜백과 `MutationFilters.predicate`는 이 값을 `mutation.options.meta`로 읽어요. |
| `onMutate` | [콜백](#콜백) 참고 | 없음 | `mutationFn`보다 먼저 실행돼요. 반환값이 `TContext`를 정하고 `context`가 돼요. |
| `onSuccess` | [콜백](#콜백) 참고 | 없음 | `mutationFn`이 성공한 뒤 실행돼요. |
| `onError` | [콜백](#콜백) 참고 | 없음 | 마지막 시도가 실패한 뒤 실행돼요. |
| `onSettled` | [콜백](#콜백) 참고 | 없음 | 성공이나 실패 뒤에 실행돼요. |

## 뮤테이션 실행하기

정의는 이 메서드로 뮤테이션을 직접 실행해요. `client`는 생략할 수 있고, 생략하면 호출하는 시점의 `Fuery.client`를 사용해요.

| 메서드 | 반환 타입 | 하는 일 |
|---|---|---|
| `mutate(variables, [client])` | `void` | 실행을 시작하고 기다리지 않아요. 에러는 호출한 쪽이 아니라 실행의 상태와 콜백으로 전달돼요. |
| `mutateAsync(variables, [client])` | `Future<TData>` | 실행을 시작하고 그 데이터를 반환해요. 실행이 실패하면 에러가 발생해요. |
| `observe({client})` | `MutationObserver<TData, TVariables, TContext>` | 뮤테이션을 실행하고 마지막 실행을 알리는 새 옵저버를 반환해요. [옵저버 하나 공유하기](../../guides/mutations/#옵저버-하나-공유하기)를 참고하세요. |

- 정의는 상태를 담지 않아요. `mutate`나 `mutateAsync`로 시작한 실행은 클라이언트의 뮤테이션 캐시에 속하고, 어떤 옵저버도 그 실행을 담지 않아요. 실행은 끝나고 `gcTime`이 지나면 캐시에서 사라져요.
- MutationState 위젯, `useMutationState`, `isMutating`은 `mutationKey`로 그 실행을 찾아요. `MutationResult`에는 나타나지 않아요.
- 이 실행도 옵저버에서 시작한 실행처럼 클라이언트의 기본값, `scope`, `persist`를 받아요.
- 두 메서드 모두 `MutateOptions`를 받지 않아요. 호출 한 번에만 필요한 처리는 `mutateAsync`를 `await`로 기다린 뒤에 하세요.
- 클라이언트를 따로 둔 `FueryProvider` 아래에서는 `context.queryClient`를 넘기세요.

## 콜백

| 콜백 | 인수 | 반환 타입 |
|---|---|---|
| `onMutate` | `TVariables variables, QueryClient client` | `FutureOr<TContext?>`. 반환값이 `context`가 돼요. |
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | `FutureOr<void>` |

`client`는 뮤테이션을 실행하는 클라이언트예요. Fuery는 콜백을 이 순서로 실행해요.

1. 클라이언트의 `MutationCacheConfig`에 있는 콜백([캐시 콜백](../query-client/#캐시-콜백))
2. 뮤테이션 자체의 콜백
3. 두 `onSettled` 콜백이 끝나면 실행의 상태가 `success`나 `error`로 바뀌어요. 그다음 그 호출의 `MutateOptions` 콜백이 실행되고, 그 뒤에 위젯이 새 상태를 받아요.

- 1단계와 2단계에서 `Future`를 반환하면 Fuery가 `await`로 기다려요. 그래서 `Future`가 완료될 때까지 실행은 `pending` 상태로 남아요.
- `onMutate`에서, 또는 성공한 뒤 `onSuccess`나 `onSettled`에서 에러가 발생하면 실행이 실패하고 그 에러가 `onError`로 전달돼요.
- 실패한 실행의 `onError`나 `onSettled`에서 발생한 에러는 [`onUncaughtError`](../../guides/client-setup/#콜백에서-발생한-에러-잡기)로 전달돼요.
- `restore(mutations:)`로 복원한 실행은 `onMutate`를 건너뛰고, 콜백은 `context`로 `null`을 받아요.
- `clear()`가 멈춘 실행을 버리면 그 실행은 `CancelledError`로 실패해요. `onMutate` 뒤의 콜백은 하나도 실행되지 않고, 그 호출의 `MutateOptions` 콜백도 실행되지 않아요.

## NoVariablesMutation

`NoVariablesMutation<TData, TContext>`는 `Mutation`과 같은 옵션을 받아요. 다만 `mutationFn`과 콜백에는 변수가 없어요.

| 옵션 | 인수 | 반환 타입 |
|---|---|---|
| `mutationFn` | 없음 | `Future<TData>` |
| `onMutate` | `QueryClient client` | `FutureOr<TContext?>` |
| `onSuccess` | `TData data, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onError` | `Object error, TContext? context, QueryClient client` | `FutureOr<void>` |
| `onSettled` | `TData? data, Object? error, TContext? context, QueryClient client` | `FutureOr<void>` |

정의는 `mutate()`와 `mutateAsync()`로 뮤테이션을 실행해요. 클라이언트를 넘기려면 첫 인수로 `null`을 넘기세요. `mutate(null, client)`처럼 호출해요.

`NoVariablesMutation`은 `Mutation<TData, void, TContext>`예요. 그래서 이렇게 동작해요.

- 위젯과 훅은 `mutate(null)`이나 `mutateAsync(null)`로 실행해요.
- `MutateOptions` 콜백에는 변수 인수가 그대로 있고, 그 값은 `null`이에요.
- `observe()`는 `NoVariablesMutationObserver`를 반환하고, 이 옵저버는 `mutate()`와 `mutateAsync()`로 뮤테이션을 실행해요. `MutateOptions`를 넘기려면 첫 인수로 `null`을 넘기세요. `mutate(null, options)`처럼 호출해요.

저장하려면 `MutationPersist.noVariables`를 넘기세요.

## MutateOptions

`MutateOptions`는 호출 한 번의 콜백을 담아요. 결과나 옵저버의 `mutate`, `mutateAsync`에 두 번째 인수로 넘겨요. 정의의 `mutate`는 `MutateOptions`를 받지 않아요.

| 필드 | 인수 | 실행 시점 |
|---|---|---|
| `onSuccess` | `TData data, TVariables variables, TContext? context, QueryClient client` | 호출이 성공한 뒤 |
| `onError` | `Object error, TVariables variables, TContext? context, QueryClient client` | 호출이 실패한 뒤 |
| `onSettled` | `TData? data, Object? error, TVariables variables, TContext? context, QueryClient client` | 성공이나 실패 뒤 |

- 실행이 끝나면 뮤테이션 자체의 콜백 뒤에 실행돼요. Fuery는 이 콜백을 기다리지 않아요.
- 같은 옵저버에서 다시 호출하면 콜백이 바뀌어요. 그래서 마지막 호출의 콜백만 실행돼요.
- `reset()`을 호출하면 콜백을 버려요. 옵저버를 소유한 위젯이 언마운트되거나, 훅이나 슬롯이 해제될 때도 버려요.
- 공유한 옵저버는 구독하는 것이 있든 없든 이 콜백을 실행해요. 콜백에서 `BuildContext`를 사용하기 전에 `context.mounted`를 확인하세요.
- 이 콜백에서 발생한 에러는 `onUncaughtError`로 전달돼요.

## MutationPersist

`MutationPersist<TVariables>`는 뮤테이션의 변수를 JSON으로 바꾸고 다시 되돌려요. 그래서 앱을 다시 시작한 뒤 `restore(mutations:)`가 저장된 실행을 다시 시작할 수 있어요. 설정 방법은 [뮤테이션 저장하기](../../guides/persistence/#뮤테이션-저장하기)에 있어요.

| 매개변수 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `toJson` | `Object? Function(TVariables variables)` | 필수 | 변수를 `jsonEncode`가 받을 수 있는 값으로 바꿔요. 인코딩할 수 없는 변수는 저장하지 않고, 실행은 계속돼요. |
| `fromJson` | `TVariables Function(Object? json)` | 필수 | `jsonDecode`가 만든 값을 다시 변수로 바꿔요. |
| `version` | `int` | `1` | 버전이 다른 저장된 실행은 Fuery가 실행하지 않고 삭제해요. JSON 형식이 바뀌면 값을 올리세요. |

`MutationPersist.noVariables`는 저장할 변수가 없는 `NoVariablesMutation`용 `MutationPersist<void>`예요.
