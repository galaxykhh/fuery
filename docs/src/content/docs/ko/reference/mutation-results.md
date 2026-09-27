---
title: 뮤테이션 결과
description: Flutter용 Fuery에서 MutationResult와 MutationState의 필드, 각 타입을 알리는 위젯과 훅, 결과에서 뮤테이션을 실행하는 메서드
sourceHash: eee94168efc2
---

위젯, 훅, 슬롯, 옵저버는 뮤테이션의 진행 상황을 두 타입 중 하나로 알려요.

| 알리는 쪽 | 타입 |
|---|---|
| `MutationBuilder`, `MutationSelector`, `MutationListener`, `MutationConsumer`, `useMutation`, `useOnMutationChange`, `MutationSlot`, 옵저버의 `result`와 `stream` | [`MutationResult`](#mutationresult): 옵저버의 마지막 실행(`mutate` 호출 한 번)의 상태와, 새 실행을 시작하는 메서드 |
| `MutationStateBuilder`, `MutationStateSelector`, `MutationStateListener`, `useMutationState`, `useOnMutationStateChange`, `MutationStateSlot` | 실행마다 하나씩 있는 [`MutationState`](#mutationstate-필드). 실행을 어디서 시작했든 포함해요. |

위젯이나 옵저버 하나로 뮤테이션을 실행하고, 그 위젯이나 옵저버가 시작한 마지막 실행을 보여주려면 `MutationResult`를 읽으세요. [뮤테이션의 모든 실행 보여주기](../../guides/mutations/#뮤테이션의-모든-실행-보여주기)처럼 뮤테이션의 모든 실행을 보여주려면 `MutationState`를 읽으세요. `addTodo.mutate('Buy milk')`처럼 정의에서 시작한 실행은 `MutationState`에만 나타나요. 정의의 `mutate`와 `mutateAsync`는 [뮤테이션 실행하기](../mutation-options/#뮤테이션-실행하기)에 있어요.

## MutationResult

`MutationResult<TData, TVariables, TContext>`는 옵저버의 마지막 실행의 `MutationState`이고, 첫 실행 전에는 `idle` 상태예요. 여기에 이런 멤버가 더 있어요.

| 멤버 | 타입 | 하는 일 |
|---|---|---|
| `mutate(variables, [options])` | `void` | 실행을 시작하고 기다리지 않아요. 에러는 호출한 쪽이 아니라 상태와 콜백으로 전달돼요. |
| `mutateAsync(variables, [options])` | `Future<TData>` | 실행을 시작하고 그 데이터를 반환해요. 실행이 실패하면 에러가 발생해요. |
| `reset()` | `void` | 마지막 실행을 잊고 `idle` 상태로 돌아가요. 실행 자체는 계속돼요. 마지막 호출의 `MutateOptions` 콜백은 버려요. |
| `observer` | `MutationObserver<TData, TVariables, TContext>` | 이 결과를 알린 옵저버예요. 결과만 받은 어댑터가 이 옵저버를 구독할 수 있어요. `==`는 이 필드를 비교하지 않아요. |

- `options`는 [`MutateOptions`](../mutation-options/#mutateoptions)예요.
- 실행은 옵저버의 클라이언트를 사용해요. 정의의 `mutate`와 `mutateAsync`는 `options` 대신 클라이언트를 받아요.
- 새 실행이 마지막 실행을 대신해요. 그래서 실행이 겹치면 결과는 가장 새로운 실행만 따라가요.
- `NoVariablesMutation`에서는 변수가 `void`예요. `mutate(null)`을 호출하세요.

## MutationState 필드

`MutationState<TData, TVariables, TContext>`는 실행 하나를 나타내요.

| 필드 | 타입 | 담는 값 |
|---|---|---|
| `status` | `MutationStatus` | `idle`, `pending`, `success`, `error` 중 하나 |
| `data` | `TData?` | `mutationFn`이 반환한 값. 실행이 성공하기 전에는 `null`이에요. |
| `error` | `Object?` | 실행이 실패한 이유. 다른 상태에서는 항상 `null`이에요. |
| `variables` | `TVariables?` | 실행의 `mutate` 호출이 넘긴 값. `idle` 상태에서는 `null`이에요. |
| `context` | `TContext?` | `onMutate`가 반환한 값. `restore(mutations:)`가 시작한 실행에서는 `null`이에요. |
| `submittedAt` | `int` | 실행의 `mutate`를 호출한 시각(epoch 이후 밀리초). 실행이 시작되기 전에 기다렸어도 호출한 시각이에요. `idle` 상태에서는 `0`이에요. 복원한 실행은 자신을 저장한 실행의 시각을 유지해요. |
| `failureCount` | `int` | 실패한 시도 수. 실행이 시작될 때와 성공할 때 `0`으로 돌아가요. |
| `failureReason` | `Object?` | 마지막으로 실패한 시도의 에러. `failureCount`가 초기화될 때 함께 초기화돼요. |
| `isPaused` | `bool` | 실행이 기다리는 중인지 나타내요. 네트워크를 기다리거나, `scope`에서 차례를 기다리거나, 재시도 전에 앱이 포그라운드로 돌아오기를 기다리는 경우예요. |

`status`에는 `MutationStatus` 값 중 하나가 담겨요. 값마다 상태와 `MutationStatus` 자체에 getter가 있어요.

| 값 | getter | 의미 |
|---|---|---|
| `idle` | `isIdle` | 아직 실행이 없거나, `reset()`을 호출했어요. |
| `pending` | `isPending` | 실행이 기다리는 중이거나, `mutationFn`을 실행하는 중이거나, 재시도하는 중이거나, 콜백을 실행하는 중이에요. |
| `success` | `isSuccess` | `mutationFn`이 반환했고, 콜백도 끝났어요. |
| `error` | `isError` | 실행이 실패했어요. 마지막 시도가 실패했거나, `onMutate`, `onSuccess`, `onSettled`에서 에러가 발생한 경우예요. 멈춘 동안 `clear()`가 실행을 버린 경우가 아니면 `onError`와 `onSettled` 콜백도 끝났어요. |
