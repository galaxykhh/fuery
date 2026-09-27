---
title: 쿼리
description: "Flutter에서 서버 데이터를 가져오고 캐시해요. 쿼리 키, fresh 상태, 재시도, 다른 쿼리에 의존하는 쿼리, 폴링, 취소를 다뤄요."
sourceHash: 064d08f77dd2
head:
  - tag: title
    content: Flutter에서 API 데이터 가져오고 캐시하기 | Fuery
---

쿼리는 서버 데이터 하나를 나타내요. 쿼리에는 데이터를 캐시할 키와 데이터를 가져오는 함수가 있어요. 같은 키를 보여주는 위젯은 모두 캐시 항목 하나와 요청 하나를 공유해요. 그래서 데이터를 위젯 트리 아래로 넘기지 않아도 돼요.

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

모든 옵션은 [쿼리 옵션](../../reference/query-options/)에 있어요. 쿼리가 언제 데이터를 가져오고 데이터가 언제 메모리에서 사라지는지는 [캐시가 동작하는 방식](../../how-the-cache-works/)에서 설명해요.

## 쿼리 키

키는 캐시 항목의 이름을 정하는 리스트예요. Fuery는 키를 값으로 비교해요. 그래서 두 위젯에서 `['todos', 1]`을 따로 만들어도 캐시 항목은 하나이고 요청도 하나예요.

키의 요소는 일반적인 것부터 구체적인 것 순서로 놓으세요. `['todos']`, `['todos', 1]`, `['todos', 1, 'comments']`처럼요. 그러면 `['todos']`를 무효화할 때 Fuery가 `['todos']`로 시작하는 키를 모두 새로고침해요.

키에는 `null`, `bool`, `num`, `String`, enum, `DateTime`, 리스트, 맵, `toJson()` 메서드가 있는 객체를 넣을 수 있어요. Fuery는 키를 JSON 형태로 비교해요.

- `DateTime`은 ISO 8601 문자열이 돼요.
- enum은 `'Filter.done'`처럼 타입과 이름이 돼요.
- 객체는 `toJson()`이 반환하는 값이 돼요.
- 맵의 키는 문자열이 돼요. 그래서 `{1: 'a'}`와 `{'1': 'a'}`는 같은 키예요.
- 맵 항목의 순서는 상관없어요.
- `1`과 `1.0`은 모바일과 데스크톱에서는 다른 키이고, 웹에서는 같은 키예요. 키에 넣는 숫자는 `int`로 쓰세요.

키 하나는 데이터 타입 하나를 담아요. 같은 키를 다른 타입으로 사용하면 `StateError`가 발생해요. 해결 방법은 [문제 해결](../../troubleshooting/#stateerror-query-holds-x-but-was-requested-as-y)에 있어요.

## 쿼리 사용하기

쿼리를 위젯에 넘기세요. `Query`는 데이터를 담지 않고 아무것도 시작하지 않아요. 그래서 `build`를 포함해 필요한 곳 어디서든 만들어도 돼요.

```dart
QueryBuilder(
  query: todoQuery(widget.id),
  builder: (context, state) => Text(state.data?.title ?? '…'),
)
```

위젯은 마운트되어 있는 동안 쿼리의 [옵저버](../../how-the-cache-works/#옵저버)를 하나 유지해요. 옵저버는 데이터를 가져오고, 상태가 바뀔 때마다 알려요. 새 `id`처럼 다른 키로 위젯이 다시 빌드되면 옵저버도 그 키를 따라가요. `state`에 담긴 값은 [쿼리 결과](../../reference/query-results/#queryresult-필드)에 있어요.

위젯 밖에서는 Cubit, 서비스, `State` 필드에서 `observe()`를 한 번 호출하고 옵저버를 유지하세요.

```dart
final todo = todoQuery(1).observe();
todo.stream.listen((result) => print(result.data));
```

`build`에서 `observe()`를 호출하지 마세요. 호출할 때마다 옵저버가 새로 생겨요. 새 옵저버는 구독하고 데이터를 다시 가져와요. 앱이 커질 때 쿼리를 어디에 둘지는 [쿼리 정리하기](../organizing-queries/)에 있어요.

## null이 될 수 없는 쿼리 데이터

Fuery는 `null`로 "아직 데이터 없음"을 나타내요. 그래서 쿼리 함수는 `Future<User>`처럼 null이 될 수 없는 타입을 반환해요. 보여줄 것이 없으면 빈 리스트 같은 빈 값을 반환하거나 에러를 일으키세요.

## `staleTime`과 fresh 상태

데이터는 `staleTime`(기본값: 0) 동안 fresh 상태예요. 그 뒤에는 stale 상태가 돼요. stale 데이터도 화면에 그대로 남아요. 위젯이나 스트림이 쿼리를 사용하기 시작할 때, 앱이 포그라운드로 돌아올 때, 네트워크가 다시 연결될 때, 쿼리를 무효화할 때 Fuery가 stale 데이터를 백그라운드에서 다시 가져와요. 모든 단계는 [쿼리 생명주기](../../how-the-cache-works/#쿼리-생명주기)에 있어요.

`staleTime`은 서버에 다시 묻지 않고 데이터를 보여줘도 되는 시간으로 설정하세요.

- `Duration(minutes: 1)`은 데이터를 가져올 때마다 1분 동안 fresh 상태로 유지해요. 그 1분 안에는 위젯이나 스트림이 쿼리를 사용하기 시작하거나, 앱이 포그라운드로 돌아오거나, 네트워크가 다시 연결돼도 Fuery가 데이터를 다시 가져오지 않아요. 쿼리를 무효화하면 그 1분 안에도 다시 가져와요.
- `infiniteDuration`은 쿼리를 무효화할 때까지 데이터를 fresh 상태로 유지해요.
- `staticStaleTime`은 바뀌지 않는 데이터에 사용해요. 데이터가 stale 상태가 되지 않고, Fuery가 알아서 다시 가져오지도 않아요. 쿼리를 무효화해도 다시 가져오지 않아요.

두 화면이 같은 키를 서로 다른 `staleTime`으로 보여줄 수 있어요. 화면마다 자기 `staleTime`으로 fresh 상태인지 판단해요. 30초 전에 가져온 데이터라면, 쿼리의 `staleTime`이 10초인 화면은 열릴 때 데이터를 다시 가져와요. `staleTime`이 1분인 화면은 다시 가져오지 않고 캐시된 데이터를 보여줘요.

어떤 위젯이나 스트림도 사용하지 않는 데이터는 `gcTime`(가비지 컬렉션 시간, 기본값: 5분) 동안 메모리에 남아요. 그 안에 화면을 다시 열면 데이터를 바로 보여줘요.

## 재시도할 에러 고르기

데이터를 가져오다 실패하면 Fuery가 기본으로 3번 재시도해요. 재시도 사이에는 1초, 2초, 4초를 기다려요. 그래서 절대 성공할 수 없는 요청도 에러 분기에 이르기까지 7초쯤 걸려요. 재시도할 만한 에러만 재시도하세요.

```dart
Fuery.client = QueryClient(
  defaultOptions: DefaultOptions(
    queries: QueryDefaults(
      retry: RetryPolicy.when(
        (failureCount, error) => failureCount < 3 && error is! NotFoundException,
      ),
    ),
  ),
);
```

`RetryPolicy.when`에서 `failureCount`는 첫 실패일 때 0이에요. 그래서 `failureCount < 3`은 재시도를 3번 허용해요. 반면 `QueryResult.failureCount`는 실패한 시도의 횟수라서 첫 실패 뒤에 1이에요.

기본값은 `RetryPolicy.count(3)`이에요. 그 밖의 단축 표현은 `RetryPolicy.never()`와 `RetryPolicy.always()`예요. 쿼리 하나에 `retry`를 따로 설정할 수도 있어요. `client.query`와 뮤테이션은 정의나 기본값에 `retry`를 설정했을 때만 재시도해요.

## 쿼리가 요청하는 데이터 바꾸기

검색창이나 필터는 사용자가 입력할 때마다 키를 바꿔요. 검색어를 상태에 두고, 그 검색어로 쿼리를 만드세요.

```dart
Query<List<Todo>> searchQuery(String term) => Query(
      queryKey: ['todos', 'search', term],
      queryFn: (_) => api.searchTodos(term),
      enabled: term.isNotEmpty,
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: searchQuery(_term),
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

- `enabled: false`이면 쿼리가 알아서 데이터를 가져오지 않아요. 그래서 검색어가 비어 있으면 요청을 보내지 않아요. `state.refetch()`를 호출하면 이때도 데이터를 가져와요.
- `placeholderData`는 다음 검색어의 결과를 불러오는 동안 이전 결과를 화면에 유지해요. [이전 페이지를 화면에 유지하기](#이전-페이지를-화면에-유지하기)를 참고하세요.
- 검색어마다 캐시 항목이 따로 생겨요. 그래서 이전 검색어로 돌아가면 그 결과를 바로 보여줘요.

위젯에서 `setState`를 호출하기 전에 `Timer`로 디바운스하세요. 위젯 밖에서는 다음 쿼리를 옵저버의 `setOptions`에 넘기세요.

## 다른 쿼리에 의존하는 쿼리

쿼리에 필요한 값으로 `enabled`를 설정하세요.

```dart
Query<List<Project>> projectsQuery(String? userId) => Query(
      queryKey: ['projects', userId],
      queryFn: (_) => api.getProjects(userId!),
      enabled: userId != null,
    );
```

또는 값이 생긴 뒤 첫 번째 쿼리의 빌더 안에서 두 번째 쿼리를 만드세요.

```dart
QueryBuilder(
  query: userQuery,
  builder: (context, state) => switch (state.data?.id) {
    final userId? => QueryBuilder(
        query: projectsQuery(userId),
        builder: (context, projects) => ProjectList(projects.data),
      ),
    null => const CircularProgressIndicator(),
  },
)
```

## 이전 페이지를 화면에 유지하기

키가 바뀌면 새 키의 데이터가 도착할 때까지 `pending` 상태를 보여줘요. `placeholderData`는 그 대신 이전 키의 데이터를 보여줘요.

```dart
Query<List<Post>> postsQuery(int page) => Query(
      queryKey: ['posts', page],
      queryFn: (_) => api.getPosts(page),
      placeholderData: keepPreviousData,
    );

QueryBuilder(
  query: postsQuery(_page),
  builder: (context, state) => PostList(state.data ?? const []),
)
```

`_page`가 바뀌어도 위젯은 옵저버를 그대로 유지해요. 그래서 옵저버에는 보여줄 이전 페이지가 남아 있어요. 페이지마다 새로 만든 옵저버에는 이전 페이지가 없어요.

다음 페이지를 불러오는 동안 `state.isPlaceholderData`는 `true`예요. 이 값으로 목록을 흐리게 하거나 다음 버튼을 비활성화하세요. 끝없이 스크롤하는 목록에는 [무한 쿼리](../infinite-queries/)를 사용하세요.

`keepPreviousData`는 `postsQuery`의 반환 타입처럼 주변 코드에서 데이터 타입을 알아내야 해요. Dart가 타입을 추론하는 `Query(...)`에서는 그 대신 `(previous, client) => previous`를 쓰세요. 이런 곳에 `keepPreviousData`를 사용하면 Dart가 데이터 타입을 `queryFn`에서 추론하지 않고 `Object`로 추론해요.

## 스피너 없이 상세 화면 열기

상세 화면이 가져오는 항목은 목록 화면에 이미 있어요. 그 항목을 플레이스홀더 데이터로 반환하세요.

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', 'detail', id],
      queryFn: (_) => api.getTodo(id),
      placeholderData: (previous, client) {
        if (previous != null) return previous;
        final todos = client.getData(todosQuery);
        return todos?.firstWhereOrNull((todo) => todo.id == id);
      },
    );
```

`placeholderData`는 쿼리를 실행하는 클라이언트를 받아요. 그래서 테스트에서도, `FueryProvider` 아래에서도 올바른 캐시를 읽어요. Fuery는 플레이스홀더 데이터를 캐시하지 않아요. 데이터는 그대로 가져오고, 가져온 전체 항목이 플레이스홀더 데이터를 대신해요. 가져온 데이터처럼 캐시에 넣어야 하는 값에는 그 대신 `initialData`를 사용하세요.

## 작업이 끝날 때까지 폴링하기

`refetchInterval`은 위젯이나 스트림이 쿼리를 사용하는 동안 폴링해요. 앱이 백그라운드에 있는 동안에는 폴링을 멈춰요.

```dart
final prices = Query(
  queryKey: ['prices'],
  queryFn: (_) => api.getPrices(),
  refetchInterval: const Duration(seconds: 10),
);
```

작업이 끝났을 때 폴링을 멈추려면 `refetchWhile`을 추가하세요. Fuery는 상태가 바뀔 때마다 `refetchWhile`을 확인해요. `false`를 반환하면 폴링을 멈춰요. 쿼리를 무효화한 뒤처럼 `true`를 반환하면 폴링을 다시 시작해요.

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

`refetchWhile`은 첫 데이터가 도착하기 전에도 실행돼요. 그러니 `state.data`가 `null`인 경우도 처리하세요.

## 바뀐 부분만 다시 빌드하기

Fuery는 다시 가져온 데이터를 캐시된 데이터와 깊이 비교해요. 그리고 바뀌지 않은 캐시 객체를 그대로 유지해요.

- 같은 데이터는 같은 객체로 남아요.
- 바뀐 리스트 안에서도, 같은 인덱스에 있던 항목과 같은 항목은 이전 객체로 남아요. 항목은 `==`로 비교해요.

그래서 `buildWhen`처럼 데이터를 `==`로 비교하는 코드는 실제로 바뀐 것이 없을 때 변화가 없다고 판단해요. `List`는 같은 객체인지로 비교하지만, 다시 가져온 할 일이 같으면 이 빌더는 다시 빌드하지 않아요.

```dart
QueryBuilder(
  query: todosQuery,
  buildWhen: (previous, current) => previous.data != current.data,
  builder: (context, state) => TodoList(state.data ?? const []),
)
```

구조적 공유는 기본으로 켜져 있어요. 데이터를 비교하는 비용이 큰 쿼리에는 `structuralSharing: false`를 설정하세요.

## 요청 취소하기

요청을 취소할 수 있게 하려면 쿼리 함수에서 `context.signal`을 읽으세요. 그러면 쿼리를 사용하는 위젯이나 스트림이 더는 없을 때, Fuery가 가져오기를 백그라운드에서 끝나게 두지 않고 중단해요.

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

`signal`을 읽지 않으면 요청은 끝까지 실행돼요. Fuery는 그 결과를 캐시해 뒀다가 다음에 사용해요.

`context.signal`은 `AbortSignal`이에요. 여러 단계로 나눠 동작하는 쿼리 함수는 단계 사이에 `signal.aborted`를 확인할 수 있어요. `signal.throwIfAborted()`를 호출해 취소를 나타내는 `CancelledError`로 멈추거나, 자기 작업과 `signal.whenAborted` 중 먼저 끝나는 쪽을 기다릴 수도 있어요. Fuery는 `signal`을 항상 그 `CancelledError`로 중단해요. `AbortedException`으로 중단하지 않아요.

Fuery는 취소를 실패로 다루지 않아요.

- [`cancelQueries`](../../reference/query-client/#다시-가져오기와-취소-인수)는 기본으로 쿼리를 가져오기 전의 상태로 되돌려요.
- `CancelledError`는 `QueryCacheConfig.onError`에 전달되지 않아요.
- 가져오다가 취소된 요청이 늦게 끝나도, 그 뒤에 가져오거나 쓴 데이터를 덮어쓰지 않아요.

중단을 무시하고 값을 반환하는 쿼리 함수만 오래된 데이터를 캐시에 넣을 수 있어요.

쿼리 함수에서 직접 발생한 `CancelledError`는 다른 에러와 같은 실패예요. 예를 들어 `context.client.query(userQuery)`를 `await`로 기다리는 쿼리 함수가 있어요. `userQuery`가 데이터를 불러오는 도중에 제거되거나 데이터가 생기기 전에 취소되면, 이 쿼리 함수에서 `CancelledError`가 발생해요. Fuery는 그 에러가 발생한 쿼리를 `retry`가 허용하는 만큼 재시도해요. 모든 시도가 실패하면 그 쿼리는 `error` 상태가 되고, `QueryCacheConfig.onError`가 `CancelledError`를 받아요.

## 예제 앱에서

예제의 [검색 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/search/search_screen.dart)은 검색하는 동안 이전 결과를 유지해요. [글쓰기 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)은 새 게시물이 게시될 때까지 폴링해요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
