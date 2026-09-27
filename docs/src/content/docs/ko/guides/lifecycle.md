---
title: 다시 가져오기와 오프라인
description: Flutter 앱이 포그라운드로 돌아오면 stale 데이터를 다시 가져와요. 오프라인이면 멈추고, 네트워크가 다시 연결되면 이어서 실행해요.
sourceHash: 6f8b1b989a7f
---

앱이 포그라운드로 돌아오거나 네트워크가 다시 연결되면 Fuery가 stale 데이터를 다시 가져와요. 그래서 당겨서 새로고침하지 않아도 화면이 바뀐 데이터를 보여줘요. Fuery 위젯, 훅, `FueryProvider`가 앱 생명주기를 대신 연결해요. 네트워크 연결 상태를 반영하려면 `onlineManager.setEventListener`로 연결 상태 소스를 연결하세요.

## 앱이 포그라운드로 돌아올 때

Fuery는 `AppLifecycleState` 값을 포커스 상태로 바꿔요.

| 앱 상태 | Fuery가 보는 상태 |
|---|---|
| `resumed` | 포커스 있음 |
| `hidden`, `paused`, `detached` | 포커스 없음 |
| `inactive` | 이전 상태 유지. 시스템 다이얼로그처럼 잠깐 끼어드는 일은 포커스 변화로 치지 않아요. |

- 앱이 다시 포커스를 얻으면, Fuery는 마운트된 위젯이 보여주는 쿼리처럼 사용 중인 쿼리 가운데 stale 상태인 쿼리를 모두 다시 가져와요.
- 앱에 포커스가 없는 동안에는 Fuery가 재시도를 미뤄요.
- 쿼리에 `refetchIntervalInBackground`를 설정하지 않았다면 백그라운드에서는 폴링도 멈춰요.
- `refetchOnFocus`는 앱이 다시 포커스를 얻을 때 쿼리마다 다시 가져올지 정해요. 값은 `RefetchMode.ifStale`(기본값), `RefetchMode.always`, `RefetchMode.never`예요.

포커스 상태는 `FueryFocusManager`인 `focusManager`가 담고 있어요. `focusManager`는 키보드 포커스가 아니라 앱이 포그라운드에 있는지를 추적해요.

| 멤버 | 하는 일 |
|---|---|
| `setFocused(false)` | 앱이 백그라운드에 있다고 알려요. 테스트에서 앱이 백그라운드로 가는 상황을 흉내 낼 때 사용해요. |
| `setFocused(null)` | 직접 설정한 상태를 버려요. 이벤트 소스가 바뀐 상태를 알릴 때까지 앱은 포커스가 있는 것으로 봐요. |
| `isFocused` | Fuery가 앱에 포커스가 있다고 보는지 나타내요. 다른 상태를 알리기 전까지는 `true`예요. |
| `setEventListener(setup)` | 포커스 소스를 바꿔요. Flutter에서는 먼저 `FueryBinding.ensureInitialized()`를 호출하세요. 그러지 않으면 처음 만들어지는 Fuery 위젯, 훅, `FueryProvider`가 직접 연결한 소스를 앱 생명주기로 바꿔요. Flutter 밖에서는 호스트가 제공하는 이벤트를 연결하세요. `setup`은 콜백을 받아요. 콜백에 `true`나 `false`를 넘기거나, 리스너에게 다시 알리려면 값 없이 호출하세요. `setup`은 정리 함수나 `null`을 반환해요. |

`FueryProvider` 없이 Bloc에서만 쿼리를 사용하는 앱에는 생명주기를 연결하는 것이 없어요. 앱을 시작할 때 이 코드를 한 번 호출하세요.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## 네트워크가 다시 연결될 때

Fuery는 소스가 다르게 알리기 전까지 기기가 온라인이라고 봐요. 오프라인일 때 가져오기를 멈추고 네트워크가 다시 연결되면 다시 가져오려면, [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) 같은 연결 상태 소스를 연결하세요.

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

기기가 오프라인인 동안에는 이렇게 동작해요.

- 가져와야 하는 쿼리는 `FetchStatus.paused`를 알리고, 기존 데이터를 계속 보여줘요.
- 오프라인에서 시작한 뮤테이션은 기다렸다가 네트워크가 다시 연결되면 실행돼요.

네트워크가 다시 연결되면 Fuery는 멈춘 뮤테이션을 먼저 이어서 실행해요. 쿼리는 뮤테이션이 끝난 뒤에 다시 가져와요. 그래서 다시 가져온 데이터가 낙관적 업데이트를 덮어쓸 수 없어요. 첫 데이터를 아직 불러오는 쿼리는 기다리지 않고 바로 이어서 가져와요. 앱이 포그라운드로 돌아올 때도 Fuery는 같은 순서로 동작해요.

네트워크 연결 상태는 `onlineManager`가 담고 있어요.

| 멤버 | 하는 일 |
|---|---|
| `setEventListener(setup)` | 연결 상태 소스를 연결해요. `setup`은 `setOnline`을 받고, 정리 함수나 `null`을 반환해요. 새 소스는 이전 소스를 대신해요. |
| `setOnline(online)` | 연결 상태를 직접 알려요. 디버그용 스위치나 테스트에서 사용해요. |
| `isOnline` | Fuery가 기기를 온라인으로 보는지 나타내요. 소스가 다르게 알리기 전까지는 `true`예요. |

`networkMode`는 쿼리나 뮤테이션이 연결 상태에 어떻게 반응할지 정해요.

| 모드 | 동작 |
|---|---|
| `NetworkMode.online` | 기본값. 온라인일 때만 가져오고 재시도해요. |
| `NetworkMode.always` | 연결 상태를 무시해요. 로컬 데이터베이스 같은 곳에 사용해요. 이 모드의 쿼리는 `refetchOnReconnect`를 설정했을 때만 네트워크가 다시 연결되면 다시 가져와요. |
| `NetworkMode.offlineFirst` | 첫 시도는 연결 상태와 상관없이 실행하고, 오프라인이면 재시도를 멈춰요. 오프라인에서도 캐시 계층이 응답할 수 있는 요청에 알맞아요. |

## 오프라인에서 멈춘 뮤테이션 이어서 실행하기

오프라인에서 멈춘 뮤테이션은 앱이 다시 포커스를 얻거나 네트워크가 다시 연결되면 Fuery가 이어서 실행해요. 다른 시점에 이어서 실행하려면 `resumePausedMutations`를 호출하세요.

```dart
await client.resumePausedMutations();
```

- 클라이언트에서 멈춘 뮤테이션을 모두 이어서 실행해요.
- 기기가 오프라인이면 아무것도 하지 않아요.
- 멈춘 뮤테이션은 `persist`가 없으면 앱을 다시 시작할 때 사라져요. [뮤테이션 저장하기](../persistence/#뮤테이션-저장하기)를 참고하세요.

## 예제 앱에서

[홈 셸](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart)의 와이파이 버튼이 연결 상태 소스를 대신해요. 이 버튼은 `onlineManager.setOnline`으로 연결 상태를 알려요. [게시물 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)에서 오프라인일 때 쓴 댓글은 멈췄다가, 앱이 다시 온라인이 되면 전송돼요.
