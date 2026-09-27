---
title: 캐시 읽고 업데이트하기
description: Flutter에서 캐시된 데이터를 읽고, 쓰고, 무효화하고, 지켜봐요. 위젯 밖에서 데이터를 가져오고, 로그아웃할 때 캐시를 비워요.
sourceHash: 8b902bc3a7a6
head:
  - tag: title
    content: Flutter에서 캐시된 데이터 무효화하고 업데이트하고 읽기 | Fuery
---

`QueryClient`로 새로 요청하지 않고 모든 화면이 보여주는 데이터를 업데이트해요. 서버에서 데이터가 바뀌면 다시 가져오고, 화면이 열리기 전에 데이터를 가져오기도 해요. 위젯 안에서는 `context.queryClient`가 위젯이 사용하는 클라이언트를 반환해요. 위젯 밖에서는 설정한 클라이언트를 사용하세요. `Fuery.client`나 `FueryProvider`에 넘긴 클라이언트예요. [쿼리가 사용하는 클라이언트](../client-setup/#쿼리가-사용하는-클라이언트)를 참고하세요.

## 캐시 읽고 쓰기

클라이언트는 쿼리 키마다 캐시 항목(`CachedQuery`)을 하나씩 유지해요. 캐시 항목은 그 키의 데이터와 상태를 담아요. 데이터는 쿼리 정의로 읽고 쓰세요.

```dart
final client = Fuery.client;

client.getData(todosQuery);                             // the data, or null
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.getQueryState(['todos'])?.dataUpdatedAt;         // the whole QueryState
```

- `getData`, `setData`, `updateData`는 [쿼리 정의](../organizing-queries/)의 키와 데이터 타입을 사용해요. 그래서 캐스팅하지 않아도 돼요.
- 그 키를 사용하는 위젯이 모두 새 데이터로 다시 빌드돼요.
- 키에 캐시 항목이 없으면 `setData`가 쿼리의 모든 옵션으로 캐시 항목을 만들어요. 그래서 Fuery가 `persist`에 따라 데이터를 기기에 저장하고, 데이터를 다시 가져올 수도 있어요.
- `updateData`의 업데이트 함수가 `null`을 반환하면 캐시가 바뀌지 않아요.

키만 있으면 `getQueryData`, `setQueryData`, `updateQueryData`를 사용하세요. 이때 `client.getQueryData<List<Todo>>(['todos'])`처럼 데이터 타입을 적어야 해요. `setQueryData`가 만든 캐시 항목에는 쿼리 함수가 없어요. 그래서 옵저버나 `client.query`가 그 키의 쿼리를 넘겨주기 전까지는 Fuery가 이 캐시 항목을 다시 가져오지 않아요. 키를 다른 데이터 타입으로 읽으면 [`StateError`](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y)가 발생해요.

`getQueryState`는 키 하나의 `QueryState`를 반환해요. `QueryState`에는 데이터를 마지막으로 업데이트한 시각 같은 값이 있어요. 필드 목록은 [QueryState 필드](../../reference/query-client/#querystate-필드)에 있어요.

여러 키를 한 번에 쓰려면(예: 웹소켓 프레임 하나를 받았을 때) 쓰는 코드를 `notifyManager.batch`로 감싸세요. 그러면 Fuery가 마지막으로 쓴 뒤에 위젯에 한 번만 알려요.

```dart
notifyManager.batch(() {
  for (final todo in frame.todos) {
    client.setQueryData(['todo', todo.id], todo);
  }
});
```

## 여러 쿼리를 한 번에 업데이트하기

`updateQueriesData`는 키 아래의 캐시 항목 가운데 데이터가 업데이트 함수의 타입인 캐시 항목을 모두 업데이트해요. 캐시된 모든 검색 결과에 들어 있는 게시물 하나를 업데이트할 때 사용해요.

```dart
client.updateQueriesData(
  queryKey: ['posts', 'search'],
  (List<Post> posts) => [
    for (final post in posts) post.id == id ? post.copyWith(liked: true) : post,
  ],
);
```

- 키 아래에 데이터 타입이 다른 캐시 항목이 있으면 Fuery가 건너뛰어요. 그래서 접두사 하나 아래에 리스트와 상세 데이터를 함께 둘 수 있어요.
- Fuery는 데이터가 없는 캐시 항목도 건너뛰어요. 업데이트 함수가 `null`을 반환하면 그 캐시 항목은 바뀌지 않아요.
- 업데이트 함수의 매개변수에는 캐시 항목의 데이터 타입을 정확히 적으세요. `Iterable<Post>` 같은 상위 타입은 안 돼요. 타입을 적지 않으면 `updateQueriesData`에서 `ArgumentError`가 발생해요.
- `updatedAt`은 새 데이터를 언제 가져온 것으로 볼지 정해요. `setData`와 같아요.

## 캐시된 데이터 나열하기

`getQueriesData`는 `queryKey`, `exact`, `predicate`에 맞는 모든 캐시 항목의 키와 데이터를 반환해요.

```dart
for (final (key, todo) in client.getQueriesData<Todo>(queryKey: ['todo'])) {
  print('$key holds $todo');
}
```

조건에 맞는 캐시 항목은 모두 넘긴 타입의 데이터를 담고 있어야 해요. Fuery가 데이터를 그 타입으로 캐스팅하기 때문이에요. `['todo', 1]` 같은 상세 키는 `['todos']`에 있는 리스트와 다른 접두사 아래에 두세요.

그 밖의 정보가 필요하면 캐시를 읽으세요. `client.queryCache`와 `client.mutationCache`에는 `getAll`, `find`, `findAll`이 있어요.

```dart
final staleOnScreen = client.queryCache.findAll(
  const QueryFilters(type: QueryTypeFilter.active, stale: true),
);
final saving = client.mutationCache.findAll(
  const MutationFilters(status: MutationStatus.pending),
);
```

쿼리 캐시에서 조건에 맞는 값은 캐시 항목(`CachedQuery`)이에요. 뮤테이션 캐시에서 조건에 맞는 값은 `mutate` 호출 한 번에 해당하는 실행(`CachedMutation`)이에요. 필드 목록은 [캐시](../../reference/query-client/#캐시)에 있어요. 캐시는 읽기 전용이에요. 캐시를 바꾸려면 클라이언트를 사용하세요.

## 무효화하기

서버에서 데이터가 바뀌면, 영향을 받는 캐시 항목을 stale 상태로 표시하세요.

```dart
client.invalidateQueries(queryKey: ['todos']); // ['todos'] and everything under it
client.invalidateQueries(queryKey: ['todos'], exact: true); // only ['todos']
```

Fuery는 조건에 맞는 캐시 항목 가운데 사용 중인 캐시 항목을 바로 다시 가져와요. 사용 중인 캐시 항목은 마운트된 위젯처럼 켜진 [옵저버](../../how-the-cache-works/#옵저버)가 있는 캐시 항목이에요. 나머지는 다음에 무언가가 사용할 때 Fuery가 다시 가져와요. stale 상태로 표시만 하려면 `refetchType: RefetchType.none`을 넘기세요.

## 메서드가 다룰 쿼리 고르기

`invalidateQueries`, `refetchQueries`, `resetQueries`, `cancelQueries`, `removeQueries`, `isFetching`은 같은 필터로 캐시 항목을 골라요. 필터는 `queryKey`, `exact`, `type`, `stale`, `predicate`예요. [조건에 맞는 쿼리를 다루는 메서드](../../reference/query-client/#조건에-맞는-쿼리를-다루는-메서드), [쿼리 필터](../../reference/query-client/#쿼리-필터), [다시 가져오기와 취소 인수](../../reference/query-client/#다시-가져오기와-취소-인수)를 참고하세요.

### 화면에 있는 쿼리만 다시 가져오기

```dart
client.invalidateQueries(
  queryKey: ['todos'],
  type: QueryTypeFilter.active,
);
```

`type`이 없으면 Fuery는 조건에 맞는 캐시 항목을 모두 stale 상태로 표시하고, 그중 사용 중인 캐시 항목을 다시 가져와요. `type: QueryTypeFilter.active`를 넘기면 사용 중인 캐시 항목만 건드려요. 나머지는 데이터를 유지하고, `staleTime`이 지날 때까지 fresh 상태로 남아요.

### 사용자 한 명의 키 제거하기

접두사로 충분하지 않으면 `predicate`로 키 전체를 읽으세요.

```dart
client.removeQueries(
  predicate: (query) => query.queryKey.contains(userId),
);
```

`predicate`는 캐시 항목(`CachedQuery`)을 받아요. 그래서 `query.state`와 `query.options`도 확인할 수 있어요. 예를 들어 가져오다가 실패한 캐시 항목을 모두 제거할 수 있어요.

## 캐시 지켜보기

`client.watch`는 클라이언트에서 계산한 값을 `Stream`으로 바꿔요. 예를 들어 어떤 쿼리든 데이터를 가져오는 동안 로딩 바를 보여줄 때 사용해요.

```dart
client.watch((client) => client.isFetching() > 0);                 // any fetch running
client.watch((client) => client.isMutating(mutationKey: ['todos']) > 0); // saving
client.watch((client) => client.getQueryData<List<Todo>>(['todos'])); // cached data
```

- 리스너는 먼저 현재 값을 받고, 그다음 쿼리 캐시나 뮤테이션 캐시가 바뀔 때마다 새 값을 받아요.
- Fuery는 [셀렉터](../widgets/#상태의-일부-선택하기)와 같은 방식으로 값을 비교해요. 그래서 값이 같으면 아무것도 내보내지 않아요.
- 지켜보는 것만으로는 데이터를 가져오지 않아요.

스트림은 `State` 필드 등에서 한 번만 만들고, `StreamBuilder`로 보여주세요.

```dart
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key});

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar> {
  late final fetching = context.queryClient.watch(
    (client) => client.isFetching() > 0,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: fetching,
      builder: (context, snapshot) => snapshot.data == true
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
```

Bloc에서는 다른 스트림처럼 구독하세요.

뮤테이션이 실행 중인지 보여줄 때는 위젯에 스트림이 필요 없어요. [`MutationStateSelector`](../mutations/#뮤테이션의-모든-실행-보여주기)가 보여주고, `HookWidget`에서는 `useMutationState`가 보여줘요.

## 위젯 밖에서 가져오기

`client.query`는 캐시된 데이터가 fresh 상태면 그 데이터를 반환하고, 아니면 데이터를 가져와요. 라우트 가드, 앱 시작 코드, 미리 가져오기에서 이 메서드를 사용해요.

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore(); // prefetch: ignore the result and errors
```

- 데이터는 쿼리의 `staleTime` 동안 fresh 상태예요. 기본값인 0이면 `client.query`는 매번 데이터를 가져와요.
- 가져와야 할 때 그 키를 이미 가져오는 중이면, 새로 가져오지 않고 그 가져오기가 끝나기를 기다려요.
- 가져오다가 실패하면 에러가 발생해요.
- 쿼리, `defaultOptions`, 그 키에 호출한 `setQueryDefaults` 중 하나가 `retry`를 설정해야만 재시도해요.

캐시된 데이터가 얼마나 오래됐든 그대로 사용하려면 `staleTime: staticStaleTime`을 설정하세요. 그러면 `client.query`는 캐시된 데이터가 없을 때만 가져와요.

## 위젯 밖에서 무한 쿼리 가져오기

[무한 쿼리](../infinite-queries/)에는 `client.infiniteQuery`가 같은 일을 해요.

```dart
InfiniteQuery<TodoPage, int> pagedTodosQuery() => InfiniteQuery(
      queryKey: ['todos', 'paged'],
      queryFn: (context) => api.getPage(context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
      pages: 3,
    );

await client.infiniteQuery(pagedTodosQuery());
```

- `pages`는 캐시된 데이터가 없을 때 몇 페이지를 불러올지 정해요. 기본값은 1이고, `maxPages`를 넘지 않아요.
- `pages`는 정의에 속해요. 그래서 이 쿼리를 보여주는 위젯도 처음에 세 페이지를 불러와요.
- 캐시된 페이지가 있으면 `pages`를 무시하고, 캐시된 페이지를 첫 페이지부터 `maxPages`까지 다시 불러와요.

## 로그아웃할 때 모두 비우기

```dart
Future<void> logout() async {
  await api.logout();
  Fuery.client.clear();
}
```

`clear()`는 모든 캐시 항목과 모든 뮤테이션 실행을 제거하고, [저장된 데이터](../persistence/#저장된-데이터-삭제하기)를 모두 삭제해요. 클라이언트는 그대로 남고, `setQueryDefaults`와 `setMutationDefaults`로 등록한 기본값도 유지돼요.

실행 중인 뮤테이션이 어떻게 되는지는 단계에 따라 달라요.

- 이미 요청을 보내는 중인 뮤테이션은 끝까지 실행돼요.
- 네트워크를 기다리거나 스코프에서 자기 차례를 기다리는 뮤테이션은 `CancelledError`로 실패해요. `mutateAsync`에서 이 에러가 발생하고, 뮤테이션의 상태에도 이 에러가 나타나요. `MutationCacheConfig`의 콜백과 `mutate` 호출의 콜백을 포함해 어떤 콜백도 실행되지 않아요. 그래서 롤백이 이전 세션의 데이터를 다시 쓰지 않아요.

쿼리를 사용하는 화면이 모두 사라진 뒤에 비우세요. `clear()`나 `removeQueries`를 호출할 때 아직 구독 중인 옵저버는 같은 키의 새 캐시 항목으로 옮겨가요. 이 캐시 항목은 새로 만든 캐시 항목처럼 데이터를 불러와요. 그래서 아직 화면에 있는 목록은 로그아웃한 세션으로 바로 데이터를 다시 가져와요. 먼저 로그인 화면으로 이동하고, 직접 구독한 옵저버는 구독을 해제하세요.

## 예제 앱에서

예제는 [피드](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)에서 포인터가 게시물 카드 위에 올라가면 그 게시물을 미리 가져와요. [홈 셸](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)에서는 로딩 표시를 보여주려고 클라이언트를 지켜봐요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
