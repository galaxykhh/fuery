---
title: 문제 해결
description: Flutter에서 Fuery를 사용할 때 만나는 에러와 예상 밖의 동작, 그 원인과 해결 방법.
sourceHash: 9cc86044231d
---

Flutter에서 Fuery를 사용하다 만날 수 있는 에러와 예상 밖의 동작을 해결하는 방법을 영역별로 모았어요. 제목에는 겪는 증상을 그대로 적었어요.

## 타입과 컴파일 에러

### StateError: Query holds X, but was requested as Y

키를 읽거나 쓸 때 이 에러가 발생해요. 키는 데이터 타입 하나를 담는데, 코드가 다른 타입을 사용했어요.

```dart
client.setQueryData(['todos'], []); // StateError: the list has no type
```

Dart는 빈 리스트를 쿼리가 담는 `List<Todo>`가 아니라 `List<dynamic>`으로 추론해요. 타입을 적으세요.

```dart
client.setQueryData<List<Todo>>(['todos'], []);
```

`setData`는 쿼리에서 타입을 얻어요. 그래서 `client.setData(todosQuery, [])`로는 이 에러가 생기지 않아요. [쿼리 정리하기](../guides/organizing-queries/)를 참고하세요.

### 데이터 타입이 Object예요

쿼리 타입이 모델이 아니라 `Query<Object>`예요. Dart가 데이터 타입을 `queryFn`이 아니라 `keepPreviousData` 같은 제네릭 함수에서 추론했어요.

```dart
final posts = Query(
  queryKey: ['posts', 1],
  queryFn: (_) => api.getPosts(1),
  placeholderData: keepPreviousData, // posts is Query<Object>
);
```

대신 클로저를 작성하세요.

```dart
placeholderData: (previous, client) => previous,
```

`Query<List<Post>>`를 반환하는 함수처럼 타입이 이미 정해진 곳에서는 `keepPreviousData`를 사용해도 괜찮아요.

### FocusManager가 두 라이브러리에 정의돼 있어요

Flutter와 `package:fuery/fuery.dart`를 함께 임포트한 파일에서 `FocusManager.instance.primaryFocus?.unfocus()`처럼 `FocusManager`라는 이름을 쓰면 `ambiguous_import`로 컴파일에 실패해요. Flutter에는 `FocusManager` 클래스가 있어요. `package:fuery/fuery.dart`도 `FueryFocusManager`의 지원 중단된 별칭인 `FocusManager`를 내보내요.

클래스 이름을 쓰지 않고 Flutter의 포커스 매니저에 접근하세요. Flutter의 최상위 `primaryFocus`가 포커스된 노드라서, 이 코드는 키보드를 닫아요.

```dart
primaryFocus?.unfocus();
```

그 밖의 용도라면 `WidgetsBinding.instance.focusManager`가 `FocusManager.instance`와 같은 객체예요.

또는 Fuery의 이름을 숨기세요.

```dart
import 'package:fuery/fuery.dart' hide FocusManager;
```

그러면 `FocusManager`는 Flutter의 클래스를 가리켜요. `FueryFocusManager`와 `focusManager` 싱글턴은 그대로 사용할 수 있어요. `package:fuery_hooks/fuery_hooks.dart`는 이미 `FocusManager`를 숨겨요.

## 테스트

### A Timer is still pending even after the widget tree was disposed

캐시 항목에는 가비지 컬렉션 타이머가 있어요. 타이머가 테스트보다 오래 남으면 `testWidgets`가 이 메시지로 실패해요. 위젯 테스트마다 마지막에 트리를 언마운트하고 캐시를 비우세요.

```dart
await tester.pumpWidget(const SizedBox());
client.clear();
```

직접 구독한 옵저버는 `clear()` 전에 구독을 해제하세요. `clear()`는 아직 구독 중인 옵저버를 새 쿼리로 옮기고, 새 쿼리는 다시 로딩을 시작해요.

`addTearDown(Fuery.client.clear)`는 너무 늦게 실행돼요. 테스트 본문이 끝나면 `testWidgets`가 트리를 언마운트하고, 이때 타이머가 시작돼요. 그다음 정리 함수가 실행되기 전에 남은 타이머를 확인해요. 두 줄을 테스트 본문 끝에 두세요.

### 테스트가 맨 처음 실행될 때만 통과해요

테스트를 혼자 실행하면 통과하는데, 다른 테스트 뒤에 실행하면 실패해요. 테스트의 클라이언트가 비어 있어요. 옵저버는 만들어질 때 받은 클라이언트를 유지해요. `final todos = todosQuery.observe();`처럼 파일의 최상위에서 만든 옵저버는 그 옵저버를 처음 사용한 테스트의 클라이언트를 유지해요. 이후 테스트는 새 클라이언트를 만들지만, 그 클라이언트는 이 옵저버를 보지 못해요.

대신 쿼리를 최상위에 두고 위젯에 넘기세요. 위젯은 현재 클라이언트를 사용해요. `observe()`는 Cubit 안처럼 옵저버를 사용하는 곳에서 호출하세요. 그러면 테스트마다 자기 클라이언트의 옵저버를 받아요. [쿼리가 사용하는 클라이언트](../guides/client-setup/#쿼리가-사용하는-클라이언트)를 참고하세요.

### await subscription.cancel()에서 멈춰요

`testWidgets`와 `fakeAsync` 안에서는 `cancel()`이 반환하는 future가 끝내 완료되지 않아요. `await` 없이 호출하세요.

```dart
@override
Future<void> close() {
  _subscription.cancel(); // no await
  return super.close();
}
```

## 쿼리와 다시 가져오기

### 에러가 7초 뒤에야 나타나요

가져오기가 실패하면 기본으로 1초, 2초, 4초를 기다리며 3번 재시도해요. 404처럼 재시도해도 성공할 수 없는 에러도 그 7초를 재시도하며 보내요. 재시도할 가치가 있는 에러만 재시도하세요.

```dart
retry: RetryPolicy.when(
  (failureCount, error) => failureCount < 3 && error is! NotFoundException,
),
```

[재시도할 에러 고르기](../guides/queries/#재시도할-에러-고르기)를 참고하세요.

### 요청이 실패했는데 쿼리는 성공해요

쿼리는 쿼리 함수에서 에러가 발생해야 실패해요. `Result`나 `Either` 같은 결과 객체를 반환하는 리포지토리는 성공하든 실패하든 정상적으로 반환해요. 쿼리 함수에서 결과를 풀고, 실패는 에러로 일으키세요. [리포지토리의 실패를 쿼리에 전달하기](../guides/organizing-queries/#리포지토리의-실패를-쿼리에-전달하기)를 참고하세요.

### 폼에 입력한 내용이 사라져요

쿼리 데이터로 미리 채운 폼에서, 백그라운드에서 다시 가져온 데이터가 사용자가 입력한 내용을 덮어써요. 컨트롤러는 한 번만 채우고, 폼이 열려 있는 동안에는 쿼리가 다시 가져오지 않게 하세요.

```dart
final todo = Query(
  queryKey: ['todos', 'detail', id],
  queryFn: (_) => api.getTodo(id),
  refetchOnMount: RefetchMode.never,
  refetchOnFocus: RefetchMode.never,
  refetchOnReconnect: RefetchMode.never,
);
```

저장한 뒤에는 키를 무효화하세요. 그러면 다른 화면도 모두 바뀐 내용을 보여줘요.

### 쿼리가 데이터를 너무 자주 다시 가져와요

stale 상태인 쿼리는 위젯이 사용하기 시작할 때, 앱이 포그라운드로 돌아올 때, 네트워크가 다시 연결될 때 다시 가져와요. `staleTime` 기본값이 0이라서 데이터는 도착하자마자 stale 상태가 돼요. 데이터가 얼마나 자주 바뀌는지에 맞춰 쿼리에 `staleTime`을 설정하세요.

```dart
final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  staleTime: const Duration(minutes: 1),
);
```

[쿼리 생명주기](../how-the-cache-works/#쿼리-생명주기)를 참고하세요.

### 다시 빌드할 때마다 쿼리가 데이터를 가져와요

`QueryBuilder(query: todosQuery.observe())`처럼 `build` 메서드에서 `observe()`를 호출하면 다시 빌드할 때마다 새 옵저버가 생겨요. 새 옵저버는 저마다 구독하고 데이터를 가져와요. 대신 쿼리 자체를 넘기세요. 위젯이 그 쿼리의 옵저버를 하나만 유지해요.

```dart
QueryBuilder(query: todosQuery, builder: ...)
```

쿼리 리스트도 같은 방법으로 고쳐요. 새 옵저버가 아니라 정의를 넘기세요.

```dart
QueriesBuilder(queries: [for (final id in ids) todoQuery(id)], builder: ...)
```

[훅](../guides/hooks/)에서는 `useQuery(todosQuery.observe())`가 아니라 `useQuery(todosQuery)`로 쓰고, `useQueries([for (final id in ids) todoQuery(id)])`로 쓰세요.

`MutationBuilder(mutation: saveTodo.observe())`처럼 `build`에서 만든 뮤테이션 옵저버는 다시 빌드할 때마다 `idle` 상태에서 시작해요. 그러면 버튼이 자기가 시작한 뮤테이션의 `pending` 상태나 `error` 상태를 잃어요. 옵저버가 필요하면 `State` 필드나 Cubit에서 `observe()`를 한 번만 호출하고, 그 옵저버를 아래로 넘기세요. [옵저버 하나 공유하기](../guides/mutations/#옵저버-하나-공유하기)를 참고하세요.

디버그 빌드에서 Fuery 위젯이나 훅이 다시 빌드하며 같은 키와 클라이언트의 새 옵저버를 받으면, 이 항목의 링크가 담긴 경고를 출력해요. 리스트를 받는 위젯과 훅도 마찬가지예요. 경고는 키마다 한 번 출력해요. 프로바이더의 클라이언트가 바뀌어서 받은 새 옵저버는 예상된 동작이라 아무것도 출력하지 않아요.

### fetchNextPage가 다시 가져오기를 취소해요

`state.fetchNextPage()`는 모든 페이지를 백그라운드에서 다시 가져오는 중일 때처럼 이미 실행 중인 가져오기를 취소해요. 이미 다음 페이지를 불러오는 중이거나 다음 페이지가 없으면 취소하지 않아요. 호출하기 전에 `isFetching`을 확인하거나 `cancelRefetch: false`를 넘기세요.

```dart
state.fetchNextPage(cancelRefetch: false);
```

### 앱이 포그라운드로 돌아와도 다시 가져오지 않아요

Fuery 위젯과 훅이 앱 생명주기를 연결해요. 쿼리를 Bloc에서만 사용하는 앱에는 위젯도 훅도 없어요. 앱을 시작할 때 이 코드를 한 번 호출하세요.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

[앱이 포그라운드로 돌아올 때](../guides/lifecycle/#앱이-포그라운드로-돌아올-때)를 참고하세요.

### 기기가 오프라인이어도 멈추지 않아요

`onlineManager.setEventListener`로 네트워크 연결 상태를 알려주기 전까지 Fuery는 기기가 온라인이라고 가정해요. [네트워크가 다시 연결될 때](../guides/lifecycle/#네트워크가-다시-연결될-때)를 참고하세요.

## 뮤테이션

### 낙관적 업데이트가 되돌려져요

이미 실행 중이던 다시 가져오기가 캐시를 바꾼 뒤에 끝나서, 바꾼 내용을 덮어썼어요. `onMutate`에서 캐시를 바꾸기 전에 실행 중인 가져오기를 취소하세요.

```dart
onMutate: (id, client) async {
  await client.cancelQueries(queryKey: ['todos']);
  // ... snapshot and update the cache
},
```

### 요청 뒤에도 뮤테이션이 pending 상태로 남아요

콜백이 future를 반환하면 그 future가 완료될 때까지 뮤테이션은 `pending` 상태예요. `onSuccess: (_, __, ___, client) => client.invalidateQueries(...)`는 무효화의 future를 반환해요. 그래서 다시 가져오기가 끝날 때까지 뮤테이션이 `pending` 상태로 남아요. 목록을 다시 가져올 때까지 스피너를 보여줘야 하는 저장 버튼에는 이 동작이 맞아요. 화면이 기다리지 않아야 하면 아무것도 반환하지 않는 블록 본문을 사용하세요.

```dart
onSuccess: (post, _, __, client) {
  client.invalidateQueries(queryKey: ['posts']);
},
```

[콜백](../guides/mutations/#콜백)을 참고하세요.

### MutationListener가 한 번도 실행되지 않아요

`MutationListener`가 리스너를 한 번도 호출하지 않아요. 또는 상태만 보여주는 `MutationBuilder`나 `MutationSelector`가, 버튼의 뮤테이션이 실행되는 동안에도 `idle` 상태에 머물러요. 이 위젯은 자기 옵저버의 실행(`mutate` 호출 한 번)만 보여줘요. `MutationListener(mutation: addTodo)`처럼 정의를 받은 위젯은 자기 옵저버를 따로 만들어요. 그 옵저버로 뮤테이션을 실행하는 코드는 없어요. `addTodo.mutate`로 시작했거나 다른 위젯이 시작한 실행은 이 옵저버에 닿지 않아요.

어디서 시작했든 뮤테이션의 모든 실행의 변화를 받으려면 정의에 `mutationKey`를 주고 `MutationStateListener`를 사용하세요.

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
);

MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not add: ${run.error}'))),
  child: const AddTodoForm(),
)
```

상태만 보여주는 위젯에는 `MutationStateBuilder`나 `MutationStateSelector`를 사용하세요. [뮤테이션의 모든 실행 보여주기](../guides/mutations/#뮤테이션의-모든-실행-보여주기)를 참고하세요.

저장한 폼을 닫는 것처럼 호출 한 번에 따르는 사이드 이펙트는 `mutateAsync`를 `await`로 기다려서 처리하세요. [호출 한 번이 성공한 뒤 처리하기](../guides/mutations/#호출-한-번이-성공한-뒤-처리하기)를 참고하세요.

옵저버 하나의 실행만 받으려면 `State` 필드에서 옵저버를 한 번만 만드세요. 그 옵저버를 뮤테이션을 실행하는 위젯과 `MutationListener`에 모두 넘기세요.

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

`dispose`에서 필요한 `reset()`까지 담은 전체 화면은 [옵저버 하나 공유하기](../guides/mutations/#옵저버-하나-공유하기)에 있어요.

`HookWidget`에서는 뮤테이션을 실행하는 `useMutation`의 결과를 `useOnMutationChange`에 넘기세요. 모든 실행의 변화를 받으려면 `useOnMutationStateChange(addTodo, ...)`를 호출하세요. [변화에 반응하기](../guides/hooks/#변화에-반응하기)를 참고하세요.

`state.mutate`로 뮤테이션을 직접 실행하는 빌더, 컨슈머, 셀렉터에는 정의를 넘겨도 돼요.

디버그 빌드에서는 정의를 받은 `MutationListener`가 이 항목의 링크가 담긴 경고를 한 번 출력해요.

### MutationStateBuilder에 실행이 안 보여요

MutationState 위젯과 `useMutationState`는 자기가 사용하는 클라이언트의 캐시에서 정의의 `mutationKey`로 실행을 찾아요. 이런 원인을 확인하세요.

- **정의에 `mutationKey`가 없어요.** `mutationKey: const ['todos', 'add']`처럼 키를 주세요. 디버그 빌드에서는 위젯의 assert가 실패하며 이 원인을 알려줘요.
- **타입이 다른 정의가 같은 키를 사용해요.** Fuery는 그 정의의 실행을 빼고, [`onUncaughtError`](../guides/client-setup/#콜백에서-발생한-에러-잡기)로 한 번 전달해요. 정의마다 다른 키를 주세요.
- **실행이 다른 클라이언트에 있어요.** `client:` 없이 `observe()`로 만든 옵저버와, 클라이언트 없이 정의의 `mutate`로 시작한 실행은 `FueryProvider`의 클라이언트가 아니라 `Fuery.client`에서 실행돼요. [화면이 다른 클라이언트의 캐시를 읽어요](#화면이-다른-클라이언트의-캐시를-읽어요)를 참고하세요.
- **실행이 사라졌어요.** 옵저버가 담고 있지 않은 끝난 실행은 `gcTime`(기본값: 5분)이 지나면 캐시에서 사라져요. `client.clear()`는 모든 실행을 제거해요.

## 클라이언트와 에러 보고

### 화면이 다른 클라이언트의 캐시를 읽어요

뮤테이션의 콜백이 쿼리를 무효화하는데도 화면이 업데이트되지 않아요. 옵저버는 만들어질 때 받은 클라이언트를 유지해요. `client:` 없이 호출한 `observe()`는 `Fuery.client`를 사용해요. 별도 클라이언트가 있는 `FueryProvider` 아래에서, `final adding = addTodo.observe();`처럼 `State` 필드에 둔 옵저버는 `Fuery.client`를 읽고 써요. 그 주변에서 정의를 받은 위젯은 프로바이더의 클라이언트를 사용하므로, 콜백이 엉뚱한 캐시를 무효화해요.

대신 정의를 넘기세요. 그러면 위젯이 자기 클라이언트로 정의를 관찰해요. 코드에서 공유하는 옵저버가 필요하면 위젯이 사용하는 클라이언트로 옵저버를 만드세요.

```dart
late final adding = addTodo.observe(client: context.queryClient);
```

정의의 `mutate`와 `mutateAsync`도 클라이언트를 넘기지 않으면 `Fuery.client`를 사용해요. 프로바이더 아래에서는 `addTodo.mutate('Buy milk', context.queryClient)`처럼 호출하세요.

`HookWidget`에서는 `useQueryClient()`가 훅이 사용하는 클라이언트를 반환해요. `observer.client`는 옵저버가 사용하는 클라이언트를 반환해요.

디버그 빌드에서는 다른 클라이언트의 옵저버를 받은 Fuery 위젯이나 훅이 이 항목의 링크가 담긴 경고를 출력해요. 경고는 위젯이나 훅과 키의 조합마다 한 번 출력해요.

### 리스너의 에러가 zone에 닿지 않아요

리스너에서 발생한 에러가 `runZonedGuarded`나 `PlatformDispatcher.onError`에 닿지 않아요. 클라이언트에 `onUncaughtError`가 있으면 Fuery는 에러를 zone 대신 `onUncaughtError`로 전달해요.

리스너 위젯, 컨슈머, 훅의 `listener`와 슬롯의 `listen`이나 `subscribeToRuns`에 넘긴 함수가 여기에 해당해요. 위젯은 그대로 다시 빌드하고, 다른 리스너도 그대로 실행돼요.

콜백에서 발생한 다른 에러처럼, 이 에러도 `onUncaughtError`에서 보고하세요.

```dart
Fuery.client = QueryClient(
  // reportError stands for your crash reporter.
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

[콜백에서 발생한 에러 잡기](../guides/client-setup/#콜백에서-발생한-에러-잡기)를 참고하세요.

## 캐시 저장과 개발자 도구

### 기기에 저장한 데이터가 돌아오지 않아요

기기에 저장하는 쿼리가 앱을 다시 시작한 뒤 네트워크에서 데이터를 불러와요. 이런 원인을 확인하세요.

- **클라이언트에 스토리지가 없어요.** 쿼리를 사용하기 전에 `Fuery.client = QueryClient(storage: myStorage)`로 설정하세요.
- **쿼리에 `persist`를 설정하지 않았어요.** Fuery는 `persist`를 설정한 쿼리만 저장해요.
- **저장된 항목이 더 이상 유효하지 않아요.** Fuery는 `version`이 쿼리와 다른 항목, 디코딩할 수 없는 항목, 쿼리의 `maxAge`보다 오래된 항목을 버려요. `maxAge`가 없는 쿼리는 클라이언트의 `persistMaxAge`(기본값: 1일)를 사용해요. [저장된 데이터를 버릴 때](../guides/persistence/#저장된-데이터를-버릴-때)를 참고하세요.

비동기로 읽는 스토리지라면 데이터가 한두 프레임 늦게 도착해요. 첫 프레임부터 데이터를 보여주려면 `runApp` 전에 `await Fuery.client.restore()`를 호출하세요. [미리 복원하기](../guides/persistence/#미리-복원하기)를 참고하세요.

### 개발자 도구 버튼이 앱을 가려요

`FueryDevtools`는 버튼을 오른쪽 가장자리의 가운데 높이에 두고, 그 자리의 콘텐츠를 덮어요. `buttonAlignment`로 버튼을 옮기세요.

```dart
FueryDevtools(
  buttonAlignment: Alignment.centerLeft,
  child: child!,
)
```
