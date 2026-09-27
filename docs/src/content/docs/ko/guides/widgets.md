---
title: 위젯
description: Flutter에서 빌더, 리스너, 컨슈머, 셀렉터 위젯으로 캐시된 쿼리와 뮤테이션을 보여줘요.
sourceHash: cfe54efd8edf
---

Fuery의 위젯은 위젯 트리 안에서 쿼리와 뮤테이션을 렌더링해요. 그래서 서버 데이터를 보여주는 화면도 `StatelessWidget` 그대로 둘 수 있어요. 위젯은 소스와 하는 일에 따라 고르세요.

| | UI 다시 빌드 | 사이드 이펙트 | 둘 다 | 상태의 일부 |
|---|---|---|---|---|
| 쿼리 | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| 무한 쿼리 | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| 뮤테이션 | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| 여러 쿼리 | `QueriesBuilder` | | | `QueriesSelector` |
| 뮤테이션의 모든 실행 | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

쿼리, 무한 쿼리, 뮤테이션 위젯은 정의를 받아요. 정의는 `Query`, `InfiniteQuery`, `Mutation`이에요. 정의는 `build`를 포함해 어디서든 만들어도 돼요. 위젯은 마운트되어 있는 동안 정의의 [옵저버](../../how-the-cache-works/#옵저버)를 하나 유지해요.

```dart
QueryBuilder(
  query: todoQuery(id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

- 위젯이 마운트되면 옵저버가 구독해요. 쿼리에 데이터가 없으면 데이터를 가져오고, 기본으로 데이터가 stale 상태일 때도 가져와요. `enabled: false`인 쿼리는 마운트될 때 데이터를 가져오지 않아요. 위젯이 언마운트되면 옵저버가 구독을 해제해요.
- 다른 키의 정의로 위젯이 다시 빌드되면 옵저버도 그 키를 따라가요. 새 키의 캐시된 데이터는 같은 프레임에 보여요.
- 옵저버는 가장 가까운 `FueryProvider`의 클라이언트를 사용하고, `FueryProvider`가 없으면 `Fuery.client`를 사용해요.
- 결과에는 액션이 있어요. `state.refetch()`, 무한 쿼리의 `state.fetchNextPage()`와 `state.fetchPreviousPage()`, 뮤테이션의 `state.mutate(...)`, `state.mutateAsync(...)`, `state.reset()`이에요.

`MutationBuilder`는 자기가 시작한 실행(`mutate` 호출 한 번)만 보여줘요. MutationState 위젯은 어디서 시작했든 뮤테이션의 실행을 `mutationKey`로 찾아서 보여줘요. [뮤테이션의 모든 실행 보여주기](../mutations/#뮤테이션의-모든-실행-보여주기)를 참고하세요. `addTodo.mutate('Buy milk', context.queryClient)`처럼 정의에서 뮤테이션을 실행하는 버튼에는 `MutationBuilder`가 필요 없어요. [뮤테이션 실행하기](../mutations/#뮤테이션-실행하기)를 참고하세요.

## 빌더와 리스너가 실행되는 시점

- `buildWhen(previous, current)`은 마지막으로 빌드한 결과와 새 결과를 비교해요.
- `listenWhen(previous, current)`은 이전 결과와 새 결과를 비교해요.
- 리스너는 상태가 바뀐 뒤 마이크로태스크에서 실행돼요. 빌드하는 동안에는 실행되지 않아요.
- 리스너가 마운트될 때 쿼리에 이미 있던 결과로는 리스너를 호출하지 않아요.
- 컨슈머의 리스너는 바뀐 상태를 보여주려고 다시 빌드하기 전에 실행돼요.
- 리스너에서 에러가 발생해도 위젯은 그대로 다시 빌드돼요. Fuery는 그 에러를 [`onUncaughtError`](../client-setup/#콜백에서-발생한-에러-잡기)로 전달해요.

## 바뀐 부분만 다시 빌드하기

`buildWhen`을 사용하면 빌더가 보여주지 않는 변화에는 다시 빌드하지 않아요. 이 빌더는 쿼리가 데이터를 다시 가져오는 동안 진행 표시줄만 보여줘요.

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)
```

## 상태의 일부 선택하기

셀렉터는 결과의 값 하나로 빌드해요. 그 값이 바뀔 때만 다시 빌드해요.

```dart
QuerySelector(
  query: todosQuery,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

- Fuery는 리스트, 맵, 세트를 내용으로 비교하고, 나머지는 `==`로 비교해요. 호출할 때마다 새 리스트를 반환하는 셀렉터도 항목이 바뀔 때만 빌더를 다시 빌드해요.
- 부모 위젯이 다시 빌드되면 셀렉터도 다시 실행돼요. 그래서 셀렉터에서 부모의 값을 읽을 수 있어요.
- 빌더에 결과 전체가 필요하면 `buildWhen`을 사용하세요. 결과에서 계산한 값 하나만 필요하면 셀렉터를 사용하세요.

`MutationStateSelector`는 뮤테이션의 실행에 같은 일을 해요. 이 셀렉터는 어느 화면에서 시작했든 아직 끝나지 않은 저장을 세요.

```dart
MutationStateSelector(
  mutation: saveTodo,
  selector: (runs) => runs.where((run) => run.isPending).length,
  builder: (context, saving) =>
      Text(saving > 0 ? 'Saving $saving…' : 'All changes saved'),
)
```

## 변화에 반응하기

화면 이동, 스낵바처럼 한 번만 일어나는 사이드 이펙트에는 리스너를 사용하세요.

```dart
QueryListener(
  query: todosQuery,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoScreen(),
)
```

뮤테이션의 변화에는 이렇게 반응해요.

- `MutationStateListener`는 어느 화면에서 시작했든 뮤테이션의 모든 실행의 변화를 받아요. [뮤테이션이 실패했다고 사용자에게 알리기](../mutations/#뮤테이션이-실패했다고-사용자에게-알리기)를 참고하세요.
- 화면에서 호출한 뮤테이션이 성공한 뒤 그 화면을 닫으려면 `mutateAsync`를 `await`로 기다린 다음 `context.mounted`를 확인하세요. [호출 한 번이 성공한 뒤 처리하기](../mutations/#호출-한-번이-성공한-뒤-처리하기)를 참고하세요.
- `MutationListener`는 자기가 받은 옵저버의 실행에서만 변화를 받아요. 정의를 받으면 아무 변화도 받지 못하고, 디버그 빌드에서 경고를 출력해요. [MutationListener가 한 번도 실행되지 않아요](../../troubleshooting/#mutationlistener가-한-번도-실행되지-않아요)를 참고하세요.
- 정의를 받은 `MutationConsumer`는 자기 빌더가 시작한 실행의 변화를 받아요.

## 당겨서 새로고침하기

`state.refetch()`는 가져오기가 끝나면 완료되는 `Future<QueryResult>`를 반환해요. `RefreshIndicator`는 그 `Future`를 기다려요.

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => RefreshIndicator(
        onRefresh: () => state.refetch(),
        child: ListView(
          children: [for (final todo in data) TodoTile(todo)],
        ),
      ),
    QueryResult(:final error?) => Center(child: Text('$error')),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `refetch()`는 가져오기에 실패하면 에러를 일으키지 않고 결과로 알려요. 그래서 새로고침 표시가 항상 닫혀요. 에러를 일으키게 하려면 `throwOnError: true`를 넘기세요.
- 쿼리에 데이터가 있을 때 이미 가져오는 중이면, `refetch()`는 그 가져오기를 취소하고 새로 시작해요. 취소하지 않고 기다리려면 `cancelRefetch: false`를 넘기세요. 데이터가 없는 쿼리는 항상 기다려요.
- 데이터 분기만 감싸세요. 당기는 제스처에는 스크롤할 수 있는 위젯이 필요해요. `pending` 분기와 에러 분기에는 그런 위젯이 없어요.

화면의 모든 쿼리를 새로고침하려면 클라이언트의 메서드를 호출하세요.

```dart
RefreshIndicator(
  onRefresh: () => context.queryClient.invalidateQueries(queryKey: ['todos']),
  child: const TodoList(),
)
```

- [`invalidateQueries`](../query-client/#무효화하기)는 `['todos']` 아래의 모든 쿼리를 stale 상태로 표시해요. 그리고 마운트된 위젯처럼 옵저버가 있는 쿼리를 다시 가져와요.
- `refetchQueries`는 stale 상태로 표시하지 않고 다시 가져와요. `type`의 기본값은 `QueryTypeFilter.all`이라서 옵저버가 없는 캐시 항목도 다시 가져와요. 옵저버가 있는 캐시 항목만 다시 가져오려면 `type: QueryTypeFilter.active`를 넘기세요.
- 두 메서드는 조건에 맞는 캐시 항목의 가져오기가 모두 끝나면 완료돼요. 에러는 `throwOnError: true`일 때만 일으켜요. 기기가 오프라인이라 멈춘 가져오기는 두 메서드 모두 기다리지 않아요. 그래서 새로고침 표시가 멈춘 채로 남지 않아요.

두 메서드가 받는 필터는 [쿼리 필터](../../reference/query-client/#쿼리-필터)에 있어요.

## 에러가 발생한 뒤 재시도하기

에러 분기에 `state.refetch()`를 호출하는 버튼을 두세요.

```dart
QueryBuilder(
  query: todosQuery,
  builder: (context, state) => switch (state) {
    QueryResult(:final data?) => TodoList(data),
    QueryResult(:final error?) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            FilledButton(
              onPressed: state.isFetching ? null : () => state.refetch(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    _ => const Center(child: CircularProgressIndicator()),
  },
)
```

- `state.isFetching`인 동안에는 버튼을 비활성화하세요. 그래야 이미 가져오는 중에 버튼을 눌러도 요청이 겹치지 않아요.
- 데이터 분기를 먼저 확인하세요. 다시 가져오다가 실패해도 데이터는 남아요. 그래서 목록은 화면에 그대로 있고 `isRefetchError`는 true예요. 이 실패는 화면을 바꾸지 말고 `QueryListener`와 스낵바로 알리세요.
- 쿼리는 기본으로 에러 분기를 빌드하기 전에 3번 재시도해요. 재시도 사이에는 1초, 2초, 4초를 기다려요. 재시도할 에러를 좁히는 방법은 [재시도할 에러 고르기](../queries/#재시도할-에러-고르기)에 있어요.

## 여러 쿼리 함께 보여주기

`QueriesBuilder`는 데이터 타입이 같은 쿼리 리스트의 결과로 빌드해요. id마다 쿼리를 하나씩 두는 리스트가 그 예예요.

```dart
QueriesBuilder(
  queries: [for (final id in cartIds) productQuery(id)],
  builder: (context, results) {
    if (results.any((result) => !result.hasData)) {
      return const CircularProgressIndicator();
    }
    final total = results.fold(0.0, (sum, result) => sum + result.data!.price);
    return Text('Total: $total');
  },
)
```

- 결과는 쿼리 순서대로 와요.
- 리스트는 `build`에서 만드세요. 키가 리스트에 남아 있는 동안에는 리스트 순서가 바뀌어도 쿼리마다 옵저버를 유지해요.
- 키가 리스트에서 빠지면 그 옵저버도 없어져요.
- 여러 결과가 함께 바뀌면 한 번만 다시 빌드해요.
- `QueriesBuilder`를 만드는 위젯이 다시 빌드되면, id가 그대로여도 `QueriesBuilder`가 리스트의 모든 쿼리를 업데이트해요. 쿼리가 수백 개라면 텍스트 필드의 상태처럼 자주 바뀌는 상태는 다른 위젯에 두세요. 그러면 `QueriesBuilder`를 만드는 위젯은 id가 바뀔 때만 다시 빌드돼요.

`QueriesSelector`는 결과를 합쳐 만든 값 하나로 빌드해요. 그 값이 바뀔 때만 다시 빌드해요.

```dart
QueriesSelector(
  queries: [for (final id in ids) todoQuery(id)],
  selector: (results) =>
      results.where((result) => result.data?.done ?? false).length,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

목록의 항목이 서로 독립적이면 `ListView.builder`에서처럼 항목마다 `QueryBuilder`를 따로 두세요. 그러면 항목은 자기 쿼리가 바뀔 때만 다시 빌드돼요. 데이터 타입이 다른 쿼리는 `QueryBuilder` 안에 다른 `QueryBuilder`를 넣으세요.

## 가져오는 중인 것이 있는지 보여주기

앱의 모든 쿼리를 따라가는 표시줄은 위젯이 아니라 클라이언트를 읽어요. [캐시 지켜보기](../query-client/#캐시-지켜보기)를 참고하세요.

뮤테이션에서는 `MutationFilters`를 넘긴 `MutationStateSelector`가 실행 중인 뮤테이션이 있는지 보여줘요.

```dart
MutationStateSelector(
  mutation: const MutationFilters(),
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, saving) => saving ? const Text('Saving…') : const SizedBox(),
)
```

## 옵저버 넘기기

대부분의 화면은 정의를 넘겨요. 같은 키의 정의를 받은 위젯은 이미 캐시 항목과 요청을 공유해요. [쿼리 사용하기](../queries/#쿼리-사용하기)를 참고하세요.

쿼리, 무한 쿼리, 뮤테이션 위젯과 `QueriesBuilder`, `QueriesSelector`는 `observe()`로 만든 옵저버도 받아요. 위젯은 받은 옵저버를 바꾸지 않고 사용해요. 옵저버의 옵션과, 옵저버를 만들 때 사용한 클라이언트도 그대로예요. 옵저버는 Cubit과 위젯이 핸들 하나를 공유할 때나, 여러 위젯이 뮤테이션 옵저버 하나의 실행만 보여줄 때만 넘기세요.

옵저버는 Cubit이나 `State` 필드처럼 `build` 밖에서 한 번만 만드세요. `observe()`를 호출할 때마다 옵저버가 새로 생겨요. 새 옵저버는 구독하고 데이터를 다시 가져와요. `State` 필드, 클라이언트, `dispose`에서 호출하는 `reset()`은 [옵저버 하나 공유하기](../mutations/#옵저버-하나-공유하기)에 있어요.

## 옵저버 해제하기

쿼리 옵저버는 해제하지 않아도 돼요. 직접 보관하는 뮤테이션 옵저버만 `dispose`에서 할 일이 있어요.

- 쿼리 정의를 받은 위젯은 마운트될 때 옵저버를 만들고, 언마운트될 때 옵저버를 없애요.
- `observe()`로 만든 옵저버는 첫 리스너가 생길 때 쿼리를 구독해요. 옵저버를 사용하던 마지막 위젯처럼 마지막 리스너가 떠나면, 옵저버는 stale 타이머와 다시 가져오기 타이머를 취소하고 쿼리와의 연결을 끊어요.
- 나중에 같은 옵저버로 마운트되는 위젯은 옵저버가 다시 구독하게 해요. 그래서 쿼리 옵저버를 담은 `State` 필드는 `dispose`에서 할 일이 없어요.
- `stream`을 구독하는 Cubit은 `close()`에서 구독을 취소해요. 그러면 옵저버도 같은 방식으로 구독을 해제해요. [Cubit에서](../bloc/#cubit에서)를 참고하세요.

직접 보관하는 뮤테이션 옵저버는 위젯이 사라진 뒤에도 가장 최근 호출의 `MutateOptions` 콜백을 실행해요. `dispose`에서 옵저버의 `reset()`을 호출하거나, `State`나 그 `BuildContext`를 사용하는 콜백에서 `mounted`를 확인하세요. 뮤테이션을 정의로 받은 위젯은 언마운트될 때 자기 옵저버를 초기 상태로 되돌려요.

캐시 항목은 마지막 옵저버가 떠난 뒤에도 `gcTime`(가비지 컬렉션 시간, 기본값: 5분) 동안 남아요. 그래서 다시 돌아온 화면은 데이터를 바로 보여줘요.

`QueryObserver.destroy()`는 모든 리스너를 한 번에 제거해요. 마지막 구독을 해제할 때처럼 옵저버의 타이머를 취소하고 쿼리와의 연결을 끊어요. 위젯 트리에서는 필요 없어요. 수명이 긴 객체가 리스너에 접근할 수 없는 옵저버를 멈춰야 할 때 호출하세요.

## 위젯이나 어댑터 직접 만들기

훅이 필요하면 [`fuery_hooks`](../hooks/)를 사용하세요. 직접 만드는 위젯이나 다른 상태 관리 라이브러리에는 [어댑터 만들기](../adapters/)를 참고하세요. 그 페이지는 `fuery_core`의 공개 API로 쿼리를 렌더링하는 방법을 보여줘요. Fuery의 위젯도 같은 API를 사용해요.

## 예제 앱에서

예제의 [피드](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)에는 다시 가져오기 표시에 사용하는 `buildWhen`, 재시도 버튼이 있는 당겨서 새로고침, 스낵바를 띄우는 `MutationStateListener`가 있어요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
