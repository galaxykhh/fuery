---
title: 개발자 도구
description: 앱이 실행되는 동안 기기나 브라우저에서 Flutter 쿼리 캐시를 살펴보세요.
sourceHash: 32877fd7d403
---

`FueryDevtools`는 앱이 실행되는 동안 클라이언트의 캐시에 무엇이 담겼는지 보여줘요. 쿼리마다 상태와 데이터를 보여주고, 쿼리를 다시 가져오거나, 무효화하거나, 초기 상태로 되돌리거나, 제거하는 버튼을 줘요. 뮤테이션 실행(`mutate` 호출 한 번)마다 상태, 변수, 에러를 보여줘요. 앱 위에는 패널을 여는 버튼을 추가해요.

## 개발자 도구 추가하기

`FueryDevtools`를 앱의 `builder`에 넣으세요. 그러면 모든 라우트 위에 떠 있어요.

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

개발자 도구는 디버그 빌드와 프로파일 빌드에서 나타나요. 릴리스 빌드에서는 앱만 보여요.

예제 앱은 [앱 위젯](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/app.dart)에서 개발자 도구를 추가해요.

## Queries 탭

Queries 탭은 캐시에 있는 모든 쿼리를 키마다 한 행씩 보여줘요. 행마다 상태와 [옵저버](../../how-the-cache-works/#옵저버) 수가 있어요. 옵저버 수는 쿼리를 받은 위젯마다 1씩, `observe()`로 만든 옵저버마다 1씩 늘어나요. 키를 찾으려면 필터에 입력하세요.

| 상태 | 의미 |
|---|---|
| `fetching` | 가져오는 중이에요. |
| `paused` | 가져오기가 네트워크를 기다리거나, 재시도하려고 앱이 포그라운드로 돌아오기를 기다려요. |
| `inactive` | 사용하는 옵저버가 없어요. `gcTime`(가비지 컬렉션 시간)이 지나면 Fuery가 제거해요. |
| `disabled` | 모든 옵저버가 `enabled: false`라서 알아서 가져오지 않아요. |
| `stale` | 사용 중이에요. 다음에 위젯이 사용하기 시작하거나, 앱이 포그라운드로 돌아오거나, 네트워크가 다시 연결되면 Fuery가 다시 가져와요. |
| `fresh` | 사용 중이고, `staleTime` 안에 데이터가 업데이트됐고, 무효화되지 않았어요. |

쿼리를 선택하면 상태, 옵저버, 마지막 업데이트 시각, 실패 횟수, 에러, 데이터를 볼 수 있어요. 데이터는 JSON으로 보여줘요. 객체에 `toJson()`이 있으면 `toJson()`을, 없으면 `toString()`을 사용해요.

버튼은 선택한 쿼리에 동작해요.

| 버튼 | 하는 일 |
|---|---|
| Refetch | 쿼리를 다시 가져와요. [`refetchQueries`](../../reference/query-client/#조건에-맞는-쿼리를-다루는-메서드)처럼 꺼진 쿼리, 데이터가 있는 정적 쿼리, `setQueryData`로만 쓴 쿼리는 건너뛰어요. |
| Invalidate | stale 상태로 표시해요. 켜진 옵저버가 사용 중이면 Fuery가 Refetch처럼 다시 가져와요. |
| Reset | 초기 상태로 되돌리고 [기기에 저장한 데이터](../persistence/)를 삭제해요. 켜진 옵저버가 사용 중이면 Fuery가 Refetch처럼 다시 가져와요. |
| Remove | 캐시에서 제거하고 저장된 데이터를 삭제해요. 아직 사용하는 위젯이 있으면 그 위젯이 다시 불러와요. |

## Mutations 탭

Mutations 탭은 모든 [뮤테이션 실행](../../how-the-cache-works/#뮤테이션-실행)을 최신순으로 보여줘요. 실행마다 상태, 키, 변수, 에러가 있어요.

## FueryDevtools 옵션

| 옵션 | 타입 | 기본값 | 하는 일 |
|---|---|---|---|
| `child` | `Widget` | 필수 | 앱 |
| `client` | `QueryClient?` | `context.queryClient` | 살펴볼 클라이언트 |
| `enabled` | `bool` | `!kReleaseMode` | 앱 말고 다른 것도 보여줄지 여부 |
| `buttonAlignment` | `Alignment` | `Alignment.centerRight` | 버튼 위치 |
| `initiallyOpen` | `bool` | `false` | 패널을 열린 상태로 시작할지 여부 |

## 버튼 없는 패널

`FueryDevtoolsPanel`은 버튼이 없는 같은 패널이에요. 디버그 메뉴처럼 직접 만든 화면에 보여주세요.

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const Scaffold(
      body: SafeArea(child: FueryDevtoolsPanel()),
    ),
  ),
);
```

`client`(기본값: `context.queryClient`)와 `onClose` 콜백을 받아요. `onClose`를 넘기면 닫기 버튼이 생겨요.
