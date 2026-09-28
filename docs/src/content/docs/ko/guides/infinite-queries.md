---
title: 무한 쿼리
description: 캐시된 페이지로 만드는 Flutter의 페이지네이션 목록과 무한 스크롤 목록
sourceHash: 65b525494abc
head:
  - tag: title
    content: Flutter의 무한 스크롤과 페이지네이션 | Fuery
---

무한 쿼리는 키 하나에 페이지 리스트를 담아요. 요청하면 다음 페이지를 불러와요. 피드나 끝없는 목록에 사용하세요. 번호가 붙은 페이지가 서로를 대신하는 화면에는 [플레이스홀더 데이터](../queries/#이전-페이지를-화면에-유지하기)를 사용하는 일반 쿼리가 더 잘 맞아요.

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);
```

`queryFn`은 `context.pageParam`이 가리키는 페이지를 불러와요. 첫 페이지 파라미터는 `initialPageParam`이에요. `getNextPageParam`은 마지막 페이지 다음 페이지의 파라미터를 반환하고, 페이지가 더 없으면 `null`을 반환해요. 나머지 옵션과, 페이지 파라미터 함수가 실패했을 때 Fuery가 하는 일은 [InfiniteQuery 옵션](../../reference/query-options/#infinitequery-옵션)에 있어요.

[플레이그라운드에서 해보기](/fuery/demo/#/infinite): 페이지를 하나씩 불러오면서 `hasNextPage`와 `isFetchingNextPage`를 확인해보세요.

## 페이지 보여주기

`InfiniteQueryBuilder`는 불러온 페이지와 푸터에 필요한 플래그를 빌더에 넘겨요.

```dart
InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.isFetchingNextPage)
        const Center(child: CircularProgressIndicator())
      else if (state.isFetchNextPageError)
        TextButton(
          onPressed: state.fetchNextPage,
          child: const Text('Loading more failed. Retry'),
        )
      else if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : state.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

푸터는 `isFetching` 대신 `isFetchingNextPage`를 읽어요. 그래서 목록 전체를 백그라운드에서 다시 가져올 때 버튼이 스피너로 바뀌지 않아요. 빌더가 읽을 수 있는 모든 플래그는 [InfiniteQueryResult 필드](../../reference/query-results/#infinitequeryresult-필드)에 있어요.

스크롤 리스너는 `state.fetchNextPage()`를 원하는 만큼 자주 호출해도 돼요.

- 쿼리에 데이터가 생긴 뒤에는 `hasNextPage`가 false이면 호출해도 아무 일도 일어나지 않아요.
- 다음 페이지를 불러오는 중에 호출하면 그 페이지를 다시 가져오지 않고 불러오기가 끝나기를 기다려요.
- 호출하면 이미 시작된 다른 가져오기를 모두 취소해요. 모든 페이지를 백그라운드에서 다시 가져오는 중이어도 취소해요. 그 가져오기가 끝나게 두려면 앞의 푸터처럼 `isFetching`이 true인 동안 버튼을 비활성화하세요. `cancelRefetch: false`를 넘겨도 그 가져오기가 끝나게 둘 수 있지만, 이때는 호출해도 페이지를 불러오지 않아요.

`fetchPreviousPage()`는 `hasPreviousPage`를 기준으로 같은 방식으로 동작해요. 두 메서드의 인수는 [InfiniteQueryResult 액션](../../reference/query-results/#infinitequeryresult-액션)에 있어요.

## 캐시된 페이지의 항목 업데이트하기

`mapPages`는 모든 페이지를 바꾸고 페이지 파라미터는 그대로 둬요. 낙관적 업데이트처럼 페이지를 다시 불러오지 않고 항목 하나를 바꿀 때 사용하세요.

```dart
client.updateData(
  posts,
  (data) => data?.mapPages((page) => page.withPost(updatedPost)),
);
```

Fuery는 `fetchNextPage()`나 `fetchPreviousPage()`가 페이지를 불러오는 동안 캐시에 쓴 내용을 유지해요. 그 쓰기가 불러온 페이지 구성을 바꾸지 않았다면, 새 페이지가 도착할 때 그 시점의 페이지에 새 페이지를 더해요.

모든 페이지를 다시 가져오면 불러온 내용으로 페이지를 바꿔요. 그래서 낙관적 업데이트는 [먼저 다시 가져오기를 취소해요](../mutations/#낙관적-업데이트).

## 무한 쿼리를 함수에 두기

`InfiniteQuery<TPage, TParam>`에는 첫 번째 자리에 페이지 타입을, 두 번째 자리에 페이지 파라미터 타입을 적어요. Fuery는 페이지 타입을 `queryFn`에서, 페이지 파라미터 타입을 `initialPageParam`에서 추론해요. [쿼리 정리하기](../organizing-queries/)에서 권하는 것처럼 쿼리를 함수로 옮길 때는 두 타입을 모두 반환 타입에 적으세요.

```dart
// lib/data/post_queries.dart
InfiniteQuery<PostPage, int> postsQuery() => InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) => api.getPosts(page: context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    );
```

위젯 밖에서 `postsQuery().observe()`는 `InfiniteQueryObserver<PostPage, int>`를 반환해요. 이 옵저버에도 `fetchNextPage()`가 있어요.

## 커서 기반 페이지

다음 페이지의 커서를 반환하는 API도 같은 방식으로 동작해요. 첫 요청에 커서가 없으면 `initialPageParam`은 `null`이에요. 이 값으로는 커서의 타입을 알 수 없어요. 그 대신 타입을 선언하세요. 첫 번째 자리에 페이지 타입, 두 번째 자리에 커서 타입을 적은 `InfiniteQuery<ItemPage, String?>`을 반환하는 함수에 쿼리를 두세요.

```dart
InfiniteQuery<ItemPage, String?> itemsQuery() => InfiniteQuery(
      queryKey: ['items'],
      queryFn: (context) => api.getItems(cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
    );
```

그러면 `context.pageParam`은 `String?`이고, `data.lastPage`는 `ItemPage`예요.

## 이전 페이지 가져오기

최근 메시지에서 열리는 채팅처럼 중간에서 열리는 목록에는 `getPreviousPageParam`을 추가하고 `state.fetchPreviousPage()`를 호출하세요. `hasPreviousPage`와 `isFetchingPreviousPage`로 헤더를 만들어요. 다음 페이지용 플래그로 푸터를 만드는 것과 같아요.

## 메모리에 남는 페이지 수 제한하기

`maxPages`는 캐시하는 페이지 수의 상한을 정해요. 상한에 이르면 다음 페이지를 불러올 때 첫 페이지를 버리고, 이전 페이지를 불러올 때 마지막 페이지를 버려요.

```dart
InfiniteQuery<MessagePage, String?> messagesQuery(String roomId) =>
    InfiniteQuery(
      queryKey: ['messages', roomId],
      queryFn: (context) => api.getMessages(roomId, cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
      getPreviousPageParam: (data) => data.firstPage.previousCursor,
      maxPages: 5,
    );
```

`getPreviousPageParam`도 함께 주세요. 없으면 `fetchPreviousPage()`가 요청할 페이지 파라미터가 없어요. 그래서 앞에서 버린 페이지가 다시 돌아오지 않아요.

## 불러온 페이지 모두 다시 가져오기

무한 쿼리를 다시 가져오면 불러온 페이지를 모두 순서대로 다시 불러와요. Fuery는 첫 페이지의 파라미터에서 시작하고, 다음 페이지마다 `getNextPageParam`에 파라미터를 물어요. 그래서 항목이 페이지 사이에서 옮겨 갔어도 페이지가 서로 어긋나지 않아요. `getNextPageParam`이 `null`을 반환하면 다시 가져오기를 일찍 멈춰요.

## 예제 앱에서

예제의 [피드](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)는 목록을 끝 가까이까지 스크롤하면 피드를 한 페이지씩 불러와요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
