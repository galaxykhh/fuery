---
title: 캐시를 기기에 저장하기
description: Flutter 앱을 다시 시작해도 캐시된 서버 데이터를 유지해요. 어떤 키-값 스토리지든 사용할 수 있어요.
sourceHash: 93eaeb03f82e
head:
  - tag: title
    content: Flutter에서 오프라인 캐시를 기기에 저장하기 | Fuery
---

쿼리 데이터와 아직 끝나지 않은 뮤테이션을 기기에 저장하면, 앱을 다시 시작해도 남아 있어요.

- 저장하는 쿼리는 마지막 데이터를 바로 보여주고, 데이터가 stale 상태면 백그라운드에서 다시 가져와요.
- 앱이 닫힐 때 네트워크를 기다리던 저장하는 뮤테이션은, 다음에 앱을 시작할 때 `restore(mutations:)`를 호출하면 다시 실행돼요.

## 스토리지 연결하기

Fuery는 `QueryStorage`로 문자열을 읽고 써요. 어떤 키-값 스토리지로든 `QueryStorage`를 구현하세요. 이 구현은 [`shared_preferences`](https://pub.dev/packages/shared_preferences)를 사용해요.

```dart
class PreferencesStorage implements QueryStorage {
  PreferencesStorage(this.preferences);

  final SharedPreferencesWithCache preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      preferences.setString(key, value);

  @override
  Future<void> delete(String key) => preferences.remove(key);

  @override
  Map<String, String> readAll() => {
        for (final key in preferences.keys)
          if (key.startsWith(persistKeyPrefix)) key: preferences.getString(key)!,
      };
}
```

Fuery가 쓰는 키는 모두 `persistKeyPrefix` 상수로 시작해요. 위 코드처럼 `readAll`에서 이 접두사로 걸러내세요. 그래야 `readAll`이 스토리지의 다른 값은 빼고 Fuery가 저장한 항목만 반환해요.

스토리지를 클라이언트에 넘기세요.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  Fuery.client = QueryClient(storage: PreferencesStorage(preferences));
  runApp(const App());
}
```

`SharedPreferencesWithCache`는 동기 방식으로 읽어요. 그래서 Fuery가 첫 프레임 전에 저장하는 쿼리를 복원해요. 데이터베이스처럼 스토리지 메서드가 `Future`를 반환해도 돼요. [미리 복원하기](#미리-복원하기)를 참고하세요.

## 쿼리 저장하기

데이터를 JSON으로 바꾸고 다시 되돌리는 함수로 `persist`를 추가하세요. Fuery는 `persist`가 있는 쿼리만 저장해요.

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  persist: QueryPersist(
    toJson: (todos) => [for (final todo in todos) todo.toJson()],
    fromJson: (json) => [
      for (final item in json! as List) Todo.fromJson(item),
    ],
  ),
);
```

- **변환:** `toJson`에서는 `jsonEncode`가 받을 수 있는 값을 반환하세요. 인코딩할 수 없는 값이면 Fuery는 데이터를 저장하지 않고 에러도 알리지 않아요. `fromJson`은 `jsonDecode`가 만든 값을 받아요. 그러니 캐스팅은 `fromJson`에서 한 번만 하세요. 위의 `Todo.fromJson`은 `Object?`를 받아요. 코드 생성으로 만든 `Todo.fromJson(Map<String, dynamic> json)`이라면 `Todo.fromJson(item as Map<String, dynamic>)`처럼 캐스팅하세요.
- **복원:** 쿼리를 처음 사용할 때 Fuery가 저장된 데이터와 그 데이터를 가져온 시각을 복원해요. 그다음 쿼리를 다시 가져올지는 `staleTime`이 정해요. 그래서 fresh 데이터는 다시 가져오지 않아요. 복원할 때는 네트워크가 필요 없어요.
- **저장:** Fuery는 데이터가 바뀔 때마다, 가져오는 중이 아니면 데이터를 저장해요. `setData`로 바꾼 데이터도 마찬가지예요. `client.setData(todosQuery, todos)`는 쿼리를 사용하는 곳이 아직 없어도 데이터를 저장해요. `setData`가 만드는 쿼리가 정의의 `persist`를 받기 때문이에요. [스트림 쿼리](../streaming/)는 스트림이 끝나면 저장해요.
- **enum이 들어간 키:** Fuery는 키에 있는 enum을 타입 없이 이름으로만 저장해요. 난독화하거나 축소한 빌드에서는 앱을 업데이트할 때 타입 이름이 바뀔 수 있어요. 이름만 저장하면 타입 이름이 바뀌어도 여전히 일치해요. 그래서 저장하는 쿼리 두 개의 키가 같은 이름의 enum에서 타입만 다르면, 두 쿼리가 저장된 항목 하나를 공유해요. `['todos', Filter.done]`과 `['todos', Status.done]`은 서로의 데이터를 덮어써요. `['todos', 'filter', Filter.done]`처럼 둘을 구분하는 문자열을 추가하세요.

[플레이그라운드에서 해보기](/fuery/demo/#/persistence): 앱을 다시 시작하면 저장된 데이터가 가져온 시각과 함께 바로 돌아와요.

## 무한 쿼리 저장하기

페이지 하나를 변환하는 함수를 넘기면 Fuery가 페이지 리스트를 저장해요.

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  persist: InfiniteQueryPersist(
    pageToJson: (page) => page.toJson(),
    pageFromJson: (json) => PostPage.fromJson(json! as Map<String, Object?>),
  ),
);
```

Fuery는 불러온 페이지를 모두 저장된 항목 하나에 저장하고, 페이지를 불러올 때마다 이 항목을 다시 써요. 긴 피드의 저장된 항목이 너무 커지지 않도록 `maxPages`를 설정하세요.

Fuery는 페이지 파라미터를 그대로 저장해요. 그래서 페이지 파라미터는 숫자, 문자열, `null` 같은 JSON 값이어야 해요. 다른 파라미터에는 `paramToJson`과 `paramFromJson`을 추가하세요. `paramToJson`은 파라미터를 `Object?`로 받아요. 그러니 `paramToJson: (date) => (date! as DateTime).toIso8601String()`처럼 캐스팅하세요.

## 저장된 데이터를 버릴 때

저장된 데이터가 다음 중 하나면 Fuery가 그 데이터를 버려요. 그러면 쿼리는 저장된 데이터가 없는 것처럼 데이터를 가져와요.

- 쿼리의 `maxAge`보다 오래된 데이터. 쿼리에 `maxAge`가 없으면 클라이언트의 `persistMaxAge`(기본값: 1일)로 판단해요.
- `version`이 쿼리의 `version`과 다른 데이터. JSON 형식이 바뀌면 `version`을 올리세요.
- 디코딩할 수 없는 데이터

```dart
persist: QueryPersist(
  version: 2,
  maxAge: const Duration(hours: 6),
  toJson: (todos) => [for (final todo in todos) todo.toJson()],
  fromJson: (json) => [
    for (final item in json! as List) Todo.fromJson(item),
  ],
),
```

`restore()`는 저장된 쿼리 중 만료된 것도 삭제해요. 만료 기준은 Fuery가 저장할 때 적용된 `maxAge`예요. 그래서 앱이 더 이상 사용하지 않는 키의 데이터가 스토리지에 남지 않아요.

## 미리 복원하기

비동기로 읽는 스토리지를 사용하면, Fuery가 데이터를 읽을 때까지 쿼리가 로딩 상태를 보여줘요. 첫 프레임부터 데이터를 보여주려면, 앱을 시작하기 전에 저장된 항목을 모두 읽으세요.

```dart
await Fuery.client.restore();
runApp(const App());
```

## 저장된 데이터 삭제하기

| 호출 | 저장된 데이터 |
|---|---|
| `removeQueries`, `resetQueries` | 조건에 맞는 쿼리의 데이터를 삭제해요. 키로만 거르는 호출은 아직 불러오지 않은 저장된 쿼리도 삭제해요. |
| `clear()` | 쿼리와 뮤테이션의 데이터를 모두 삭제해요. 사용자가 로그아웃할 때 호출하세요. |
| 가비지 컬렉션 | 남겨 둬요. 메모리에서 사라진 쿼리는 다음에 사용할 때 복원해요. |

## 뮤테이션 저장하기

`persist`가 있는 뮤테이션은 실행(`mutate` 호출 한 번)이 시작될 때부터 끝날 때까지 그 실행의 변수를 저장해요. 앱이 닫힐 때 오프라인이라 멈춰 있었거나 아직 끝나지 않은 실행은 다음에 앱을 시작할 때도 저장돼 있어요. `restore(mutations:)`는 넘긴 정의로 그 실행을 다시 시작해요. 그래서 화면과 `main`에서 같은 정의를 사용해요.

```dart
Mutation<Comment, NewComment, void> addCommentMutation() {
  return Mutation(
    mutationKey: ['comments', 'add'],
    mutationFn: (NewComment comment) => api.addComment(comment),
    scope: const MutationScope('comments'),
    persist: MutationPersist(
      toJson: (comment) => {'postId': comment.postId, 'body': comment.body},
      fromJson: (json) {
        final map = json! as Map<String, Object?>;
        return (postId: map['postId']! as int, body: map['body']! as String);
      },
    ),
    onSuccess: (_, comment, __, client) {
      client.invalidateQueries(queryKey: ['comments', comment.postId]);
    },
  );
}

// In a screen:
addCommentMutation().mutate(
  (postId: post.id, body: 'Nice post'),
  context.queryClient,
);

// In main, before runApp:
await Fuery.client.restore(mutations: [addCommentMutation()]);
```

매개변수는 [MutationPersist](../../reference/mutation-options/#mutationpersist)에 있어요. `NoVariablesMutation`은 `MutationPersist.noVariables`로 저장해요. `NoVariablesMutation(mutationKey: ['sync'], mutationFn: () => api.sync(), persist: MutationPersist.noVariables)`처럼 설정해요.

앱이 닫히기 전에 서버에 도착한 요청도 앱을 다시 시작하면 다시 실행돼요. 반복해도 안전한 요청을 보내는 뮤테이션만 저장하거나, 서버가 반복된 요청을 같은 쓰기로 처리하게 만드세요.

### 저장된 실행을 정의와 연결하기

- `restore`는 `mutationKey`로 저장된 실행과 정의를 연결해요. 그래서 저장하는 뮤테이션에는 `mutationKey`가 있어야 해요.
- `mutations`는 `AnyMutation`의 리스트예요. 모든 `Mutation`은 `AnyMutation`이에요. 그래서 타입이 다른 정의를 한 리스트에 넣을 수 있어요.
- Fuery는 `mutationKey`를 쿼리 키와 같은 방식으로 저장해요. 그래서 키에 enum과 `DateTime`을 넣을 수 있어요.
- `toJson()`이 없는 객체를 담은 키처럼 저장할 수 없는 키는 Fuery가 `onUncaughtError`로 한 번 전달해요. 실행은 저장되지 않은 채 계속돼요.
- 키에서 enum 타입만 다른 정의 두 개가 있으면, `restore`는 이 문제를 알리고, 두 정의 모두 복원하지 않아요.

### 저장된 실행 복원하기

- 저장된 실행은 `restore`로만 돌아와요. `restore`는 실행마다 저장된 변수로 실행을 시작해요. 온라인이면 바로 시작하고, 오프라인이면 네트워크가 다시 연결될 때 시작해요.
- 스코프가 같은 실행은 오래된 것부터 하나씩 실행돼요.
- `restore`는 저장된 실행을 한 번씩만 시작해요. 클라이언트가 이미 실행 중이거나 멈춰 둔 실행은 건너뛰어요. 그래서 두 번 호출해도 요청을 반복하지 않아요.
- 복원한 실행은 `onMutate`를 건너뛰고, 콜백은 `context`로 `null`을 받아요. 낙관적 업데이트는 그 업데이트를 한 원래 실행에 속해요. 복원한 실행은 요청과 그 뒤의 콜백만 반복해요.
- [MutationState 위젯](../mutations/#뮤테이션의-모든-실행-보여주기)과 `useMutationState`는 같은 `mutationKey`로 복원한 실행을 찾아서 보여줘요. `MutationStateBuilder(mutation: addCommentMutation(), ...)`는 앱을 다시 시작한 뒤 아직 전송 중인 댓글을 목록으로 보여줘요.

### 저장된 실행 삭제하기

- Fuery는 저장된 실행이 성공하거나 실패하면 삭제해요. `clear()`는 저장된 실행을 모두 삭제해요.
- 정의를 `restore`에 넘기지 않은 저장된 실행은 남아 있어요. 그래서 나중에 `restore`를 다시 호출하면 그 실행을 시작할 수 있어요.
- Fuery는 다른 `version`의 `MutationPersist`가 저장한 실행과, 읽을 수 없는 실행을 삭제해요.

## Fuery가 보장하는 것

- Fuery는 삭제하는 중이면 삭제가 끝난 뒤에 읽거나 써요. 그래서 제거된 쿼리가 삭제된 데이터를 복원하거나, 자기 삭제를 덮어쓰는 일이 없어요.
- 쿼리를 초기 상태로 되돌리거나 제거할 때 아직 복원하는 중이어도, 예전 데이터가 돌아오지 않아요.
- `restore()`가 읽는 동안 삭제가 겹치면, `restore()`는 삭제가 끝난 뒤 다시 읽어요. 모두 합쳐 최대 3번 읽어요. 그래서 삭제된 데이터를 복원하지 않아요. 3번 모두 삭제와 겹치면 그 호출은 아무것도 복원하지 않아요. 쿼리는 처음 사용할 때 복원하고, 저장된 뮤테이션은 다음 `restore()`를 기다려요.
- 쿼리는 비동기 복원이 끝난 뒤에 마운트할 때 가져올지 정해요. 그래서 `refetchOnMount`와 `staleTime`은 복원한 데이터를 캐시된 데이터처럼 다뤄요.
- 스토리지 메서드는 동기든 비동기든 괜찮아요. Fuery는 스토리지 메서드의 에러를 무시해요. 스토리지가 실패하면 쿼리는 저장된 데이터가 없는 것처럼 데이터를 불러와요.

## 예제 앱에서

- [preferences 스토리지](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/preferences_storage.dart)가 스토리지 어댑터예요.
- [피드 쿼리](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_queries.dart)는 피드의 페이지를 저장해요.

화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
