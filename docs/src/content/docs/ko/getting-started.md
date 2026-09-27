---
title: 시작하기
description: Flutter 앱에 Fuery를 설치하고, 첫 API 요청을 캐시해 화면에 보여주고, 테스트해요.
sourceHash: 325411dab737
---

다섯 단계를 마치면 화면 하나가 API의 목록을 로딩 상태와 에러 상태까지 포함해 보여줘요. 다른 화면은 모두 캐시된 목록을 다시 사용하고, 위젯 테스트가 이 동작을 확인해요.

## 시작하기 전에

- Flutter 3.27 이상과 Dart 3.6 이상이 필요해요.
- 이 페이지의 코드는 앱에 이름 두 개가 있다고 가정해요.
  - `api`: `var api = Api();` 같은 최상위 변수예요. 이 변수의 `getTodos()`는 `Future<List<Todo>>`를 반환해요. 테스트에서는 가짜로 바꿔요.
  - `TodoList`: 할 일마다 제목을 `Text`로 보여주는 위젯이에요.

## 1. Fuery 설치하기

```bash
flutter pub add fuery
```

`fuery`는 `fuery_core`를 포함해요. 그래서 Flutter 앱에는 이 패키지 하나만 있으면 돼요. 서버나 CLI(Command-Line Interface)처럼 Flutter 없이 실행하는 Dart 코드에는 대신 `dart pub add fuery_core`를 실행하세요.

Fuery는 Dart와 Flutter에만 의존해요. `fuery`가 추가하는 패키지는 `fuery_core` 하나예요. `fuery_core`는 Dart 팀의 `clock`, `collection`, `meta`에만 의존해요. 네이티브 코드도, 플랫폼 설정도 없어요. 그래서 Fuery는 웹을 포함해 Flutter가 지원하는 모든 플랫폼에서 실행돼요.

## 2. 쿼리 정의하기

쿼리에는 데이터에 이름을 붙이는 **키**와 데이터를 가져오는 **쿼리 함수**가 필요해요.

```dart
import 'package:fuery/fuery.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

`package:fuery/fuery.dart`는 `fuery_core`도 내보내요. 그래서 이 임포트 하나로 이 페이지에 나오는 Fuery 이름을 모두 사용할 수 있어요.

쿼리를 정의해도 아무것도 시작하지 않아요. Fuery는 위젯이 쿼리를 보여줄 때 데이터를 가져오기 시작해요. 그래서 정의는 여기처럼 최상위 값으로 둬도 되고, `build`에서 만들어도 돼요.

## 3. 화면에 보여주기

쿼리를 `QueryBuilder`에 넘기세요. `QueryBuilder`는 마운트될 때 데이터를 가져오고, 새 결과가 나올 때마다 다시 빌드해요.

```dart
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      query: todosQuery,
      builder: (context, state) => switch (state) {
        QueryResult(:final data?) => TodoList(data),
        QueryResult(:final error?) => Text('$error'),
        _ => const CircularProgressIndicator(),
      },
    );
  }
}
```

데이터 분기가 먼저 와요. 그래서 다시 가져오다가 실패해도 목록은 화면에 남아요. 에러는 보여줄 데이터가 없을 때만 보여요.

훅을 사용한다면 별도 패키지인 [`fuery_hooks`](../guides/hooks/)가 `HookWidget`에서 `useQuery(todosQuery)`로 같은 쿼리를 렌더링해요.

## 4. 앱 실행하기

앱에 이 화면을 넣고 실행하세요.

```dart
void main() => runApp(const MaterialApp(home: TodoListScreen()));
```

첫 프레임에는 `CircularProgressIndicator`가 보여요. `api.getTodos()`가 반환하면 그 자리에 목록이 나타나요.

`todosQuery`를 보여주는 다른 화면은 로딩 표시 없이 첫 프레임부터 캐시된 목록을 보여줘요.

## 5. 테스트하기

`Api`를 구현하는 `FakeApi` 클래스를 작성하세요. 이 클래스의 `getTodos()`는 300밀리초를 기다린 뒤 제목이 "Buy milk"인 할 일 하나를 반환해요.

그다음 `test/` 아래 파일에 이 테스트를 추가하세요. 테스트는 `api`를 가짜로 바꾸고, 로딩 상태와 목록을 확인해요. `api`, `FakeApi`, `TodoListScreen`을 선언한 파일도 임포트하세요.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  testWidgets('shows todos', (tester) async {
    api = FakeApi();

    await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // the fake request
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Fuery.client.clear();
  });
}
```

마지막 두 줄은 화면을 언마운트하고 캐시를 비워요. 그래서 가비지 컬렉션 타이머가 테스트보다 오래 남아 테스트를 실패시키지 않아요. 이 두 줄은 테스트 본문에 두세요. `addTearDown`은 `testWidgets`가 타이머를 확인한 뒤에 실행돼요.

테스트마다 새 클라이언트를 주는 방법, 재시도를 끄는 방법, Cubit과 순수 Dart 코드를 테스트하는 방법은 [테스트](../guides/testing/)에 있어요.

## Fuery가 해준 일

- **타입은 함수가 정해요.** `api.getTodos()`가 `Future<List<Todo>>`를 반환하므로 `todosQuery`는 `Query<List<Todo>>`예요. 빌더의 `state`는 `QueryResult<List<Todo>>`예요. 타입을 직접 적는 경우는 두 가지예요. `client.getQueryData<List<Todo>>(['todos'])`처럼 키만으로 읽거나 쓸 때, 그리고 첫 페이지 파라미터가 `null`인 무한 쿼리예요([커서 기반 페이지](../guides/infinite-queries/#커서-기반-페이지) 참고).
- **null을 검사하지 않아도 돼요.** `QueryResult(:final data?)`는 데이터가 있을 때만 일치해요. 그래서 그 분기에서 `data`는 `List<Todo>`예요.
- **화면은 키로 데이터를 공유해요.** `['todos']`를 사용하는 화면은 모두 캐시 항목 하나를 읽어요. 데이터를 가져오는 동안 마운트된 화면은 그 요청을 공유해요.
- **stale 데이터는 Fuery가 알아서 다시 가져와요.** 데이터는 도착하자마자 stale 상태예요(`staleTime` 기본값: 0). 다른 화면이 데이터를 사용하기 시작하거나 앱이 포그라운드로 돌아오면 Fuery가 백그라운드에서 다시 가져와요. 그동안 이전 목록은 화면에 그대로 있어요.

데이터를 언제 다시 가져오고 언제 메모리에서 지우는지는 [캐시가 동작하는 방식](../how-the-cache-works/)에 있어요.

## 다음 단계

- [TanStack Query에서 넘어왔다면](../coming-from-tanstack-query/): TanStack Query의 개념마다 Fuery에서 부르는 이름
- [Flutter의 서버 상태](../server-state/): 서버 데이터에 캐시가 필요한 이유
- [캐시가 동작하는 방식](../how-the-cache-works/): 정의, 옵저버, 캐시된 데이터의 생명주기
- [쿼리](../guides/queries/): 키, fresh 상태, 서로 의존하는 쿼리
- [위젯](../guides/widgets/): 빌더, 리스너, 컨슈머, 셀렉터
- [뮤테이션](../guides/mutations/): 서버 데이터를 바꾸는 방법과 낙관적 업데이트
- [Bloc과 Cubit](../guides/bloc/): 같은 쿼리를 Cubit과 Bloc 안에서 사용하기
- [개발자 도구](../guides/devtools/): 실행 중인 앱에서 모든 쿼리와 뮤테이션 살펴보기
