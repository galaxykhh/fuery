---
title: 테스트
description: 가짜 시간과 새 클라이언트로 캐시를 사용하는 Flutter 위젯, Bloc, 쿼리를 테스트해요.
sourceHash: 05dd3c02e901
---

테스트에는 빈 캐시와 시간을 제어하는 방법이 필요해요. 테스트마다 재시도를 끈 새 `QueryClient`를 주고, 가짜 시계에서 실행하세요.

## 위젯 테스트하기

테스트마다 새 클라이언트를 주고, 실패가 바로 드러나도록 재시도를 끄세요.

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  Fuery.client = client;
  await tester.pumpWidget(const App());
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  client.clear();
});
```

- **가짜 API가 응답하는 데 걸리는 시간만큼 `pump`하세요.** 바로 응답하는 가짜 API에는 `await tester.pump()`만 있으면 돼요.
- **테스트마다 마지막에 위젯을 언마운트하고 `client.clear()`를 호출하세요.** 그러지 않으면 캐시의 가비지 컬렉션 타이머가 남아 있어서 [테스트가 실패해요](../../troubleshooting/#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed).
- **재시도는 쿼리만 끄면 돼요.** 뮤테이션은 `retry`를 설정하지 않으면 재시도하지 않아요. 그래서 `QueryDefaults`로 충분해요. 테스트에 뮤테이션 기본값이 따로 필요할 때만 `mutations: MutationDefaults(...)`를 추가하세요.
- **`FueryProvider`를 써도 돼요.** 위젯은 가장 가까운 `FueryProvider`의 클라이언트를 사용해요. 그래서 `Fuery.client`에 할당하는 대신 `FueryProvider(client: client, child: const App())`을 쓸 수 있어요. 하지만 `observe()`와 정의의 `mutate`, `mutateAsync`는 클라이언트를 넘기지 않으면 여전히 `Fuery.client`를 사용해요. 그러니 테스트나 Cubit이 만드는 옵저버에는 `observe(client: client)`가 필요하고, 정의에서 뮤테이션을 실행하는 위젯은 `context.queryClient`를 넘겨야 해요.
- **옵저버는 테스트 안에서 만드세요.** 옵저버는 자기 클라이언트를 유지해요. 그래서 파일의 최상위에서 만든 옵저버는 [첫 테스트의 클라이언트를 계속 유지해요](../../troubleshooting/#테스트가-맨-처음-실행될-때만-통과해요).

## 위젯 트리 없이 테스트하기

일반 Dart 테스트에서 시간을 제어하려면 [`fake_async`](https://pub.dev/packages/fake_async)를 개발 의존성으로 추가하세요.

```dart
test('loads todos', () {
  fakeAsync((async) {
    final client = QueryClient(
      defaultOptions: const DefaultOptions(
        queries: QueryDefaults(retry: RetryPolicy.never()),
      ),
    );
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => ['Buy milk'],
    ).observe(client: client);

    final subscription = todos.stream.listen((_) {});
    async.flushMicrotasks();
    expect(todos.result.data, ['Buy milk']);

    subscription.cancel();
    client.clear();
  });
});
```

`stream`을 구독하면 옵저버가 쿼리를 구독하고 데이터를 가져오기 시작해요. 시간을 들여 응답하는 가짜 API라면 `flushMicrotasks()` 대신 `async.elapse(...)`로 시계를 앞으로 돌리세요.

## Cubit과 Bloc 테스트하기

쿼리를 사용하는 Cubit이나 Bloc은 앞의 테스트처럼 `testWidgets`나 `fakeAsync`에서 테스트하세요.

- **`close()`에서 `subscription.cancel()`을 `await` 없이 호출하세요.** 가짜 시계에서는 `cancel()`이 반환한 `Future`가 완료되지 않아서 테스트가 멈춰요.
- **`client.clear()`보다 먼저 Cubit을 닫으세요.** `clear()`는 아직 구독 중인 옵저버를 새 쿼리로 옮기고, 새 쿼리는 데이터를 다시 불러와요.

## 백그라운드에 있는 앱 테스트하기

`focusManager.setFocused(false)`를 호출하면 Fuery는 앱이 [백그라운드에 있다고](../lifecycle/#앱이-포그라운드로-돌아올-때) 여겨요. 재시도는 기다리고, `refetchIntervalInBackground`를 설정하지 않았으면 폴링도 멈춰요. `focusManager.setFocused(null)`을 호출하면 포커스 판단을 다시 앱 생명주기에 맡겨요. 그러면 Fuery가 사용 중인 stale 상태의 쿼리를 다시 가져와요.

한 파일의 모든 테스트가 `focusManager`를 공유해요. 그래서 정리 함수에서 `focusManager`를 초기 상태로 되돌리세요. 정리 함수는 위젯이 사라진 뒤에 실행되고, 테스트가 실패해도 실행돼요.

```dart
addTearDown(() => focusManager.setFocused(null));
```

## 예제 앱에서

예제의 테스트는 [작은 헬퍼 함수](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test/helpers.dart)로 탭이나 게시물을 열어요. 예제의 [테스트 폴더](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/test)에는 화면마다 위젯 테스트가 있어요.
