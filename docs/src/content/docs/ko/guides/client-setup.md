---
title: 클라이언트 설정하기
description: Flutter 앱의 QueryClient를 main에서 한 번 설정해요. 기본값과 실패 보고를 설정하고, 필요하면 하위 트리마다 클라이언트를 따로 둬요.
sourceHash: 046de5bf4e5b
---

앱 전체에서 사용할 `QueryClient`를 하나 설정하세요. 이 클라이언트에서 기본값을 정하고, 모든 실패를 한곳에서 보고하고, 콜백에서 발생한 에러를 잡아요. 설정은 `main`에서 한 번만 하세요. [옵저버](../../how-the-cache-works/#옵저버)가 하나라도 생기기 전에 해야 해요. 위젯 테스트처럼 앱의 일부만 다른 클라이언트로 실행할 수도 있어요. 생성자 옵션은 모두 [QueryClient 레퍼런스](../../reference/query-client/#생성자-옵션)에 있어요.

## 클라이언트 만들기

`Fuery.client`는 `FueryProvider`가 없을 때 위젯이 사용하는 클라이언트예요. 클라이언트를 넘기지 않으면 `observe()`와 정의의 `mutate`도 이 클라이언트를 사용해요. Fuery는 처음 사용할 때 이 클라이언트를 만들어요. 그래서 아무것도 설정하지 않은 앱도 동작해요.

설정하려면 `main`에서 새 클라이언트를 할당하세요.

```dart
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const App());
}
```

- `Fuery.client`에 할당하면 Fuery가 새 클라이언트를 마운트하고 이전 클라이언트를 언마운트해요.
- 마운트된 클라이언트는 앱이 포그라운드로 돌아오거나 네트워크가 다시 연결되면 데이터를 다시 가져와요. 멈춘 뮤테이션도 이어서 실행해요.
- 옵저버가 하나라도 생기기 전에 할당하세요. 옵저버는 만들어질 때 받은 클라이언트를 유지해요.
- 기본값도 옵저버가 생기기 전에 등록하세요. 옵저버는 옵션을 받을 때 기본값을 적용하고, 그 뒤에는 적용하지 않아요.

## 기본값 설정하기

클라이언트의 모든 쿼리와 뮤테이션에, 또는 키 접두사에 기본값을 설정하세요.

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    mutations: MutationDefaults(retry: RetryPolicy.count(2)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);

Fuery.client.setMutationDefaults(
  ['todos'],
  const MutationDefaults(networkMode: NetworkMode.offlineFirst),
);
```

- 쿼리나 뮤테이션에 설정한 옵션이 키별 기본값보다 우선해요.
- 키별 기본값은 클라이언트의 `defaultOptions`보다 우선해요.
- 뮤테이션은 `mutationKey`가 있을 때만 키별 기본값을 받아요.
- `getQueryDefaults(['settings'])`와 `getMutationDefaults(['todos'])`는 키에 일치하는 모든 접두사의 기본값을 합친 키별 기본값을 반환해요. `defaultOptions`는 포함하지 않아요.

`QueryDefaults`와 `MutationDefaults`의 필드는 [기본값](../../reference/query-client/#기본값)에 있어요.

## 모든 실패를 한곳에서 보고하기

모든 쿼리와 뮤테이션에서 콜백이 실행되도록 캐시에 설정을 넘기세요. 예를 들어 실패를 크래시 리포팅 서비스나 로깅 서비스로 전달할 때 사용해요.

```dart
Fuery.client = QueryClient(
  queryCache: QueryCache(
    config: QueryCacheConfig(
      onError: (error, query) => reportError(error, query.queryKey),
    ),
  ),
  mutationCache: MutationCache(
    config: MutationCacheConfig(
      onError: (error, variables, context, mutation) =>
          reportError(error, mutation.options.mutationKey),
    ),
  ),
);
```

- 캐시는 수명이 다할 때까지 받은 설정을 유지해요. 그래서 클라이언트를 만들 때 설정을 넘기세요.
- `QueryCacheConfig` 콜백은 데이터를 가져온 뒤 실행돼요. 취소된 가져오기는 실패가 아니에요. 그래서 어떤 콜백도 실행되지 않아요.
- `MutationCacheConfig` 콜백은 [뮤테이션 자체의 콜백](../../reference/mutation-options/#콜백)보다 먼저 실행돼요. 콜백이 `Future`를 반환하면 Fuery가 `await`로 기다려요.
- 콜백은 뮤테이션의 실행(`mutate` 호출 한 번)을 `AnyCachedMutation`으로 받아요. `AnyCachedMutation`의 `data`, `variables`, `context`는 `Object?`예요. 뮤테이션은 `mutation.options.mutationKey`나 `mutation.options.meta`로 구분하세요.

콜백 목록과 실행 시점은 [캐시 콜백](../../reference/query-client/#캐시-콜백)에 있어요.

## 콜백에서 발생한 에러 잡기

`onUncaughtError`는 호출한 쪽에서 잡을 수 없는 에러를 받아요. 그래서 이런 에러를 어떻게 기록할지 직접 정할 수 있어요.

- `QueryCacheConfig`나 `MutateOptions` 콜백에서 발생한 에러
- 뮤테이션이 실패한 뒤 뮤테이션이나 `MutationCacheConfig`의 `onError`, `onSettled`에서 발생한 에러
- 쿼리가 바뀐 뒤 Fuery가 옵저버를 업데이트하는 동안 `refetchWhile`이나 `placeholderData`에서 발생한 에러
- 리스너 위젯, 컨슈머, 훅의 `listener`나, 슬롯의 `listen`, `subscribeToRuns`에 넘긴 함수 같은 리스너에서 발생한 에러
- 결과를 만드는 동안 `getNextPageParam`이 잘못된 타입의 페이지 파라미터를 반환하거나 에러를 일으키는 경우, 기기에 저장하는 뮤테이션의 `mutationKey`를 저장할 수 없는 경우처럼 Fuery가 실행 중에 찾은 실수

```dart
Fuery.client = QueryClient(
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

- 쿼리나 뮤테이션은 콜백에서 에러가 발생하지 않은 것처럼 계속 동작해요.
- Fuery는 같은 실수를 클라이언트마다 한 번만 전달해요. 코드가 실행될 때마다 전달하지 않아요.
- `onUncaughtError`에서 에러가 발생하면, 그 에러와 `onUncaughtError`가 받은 에러가 모두 현재 zone으로 전달돼요.

`onUncaughtError`가 없으면 이 에러는 현재 zone으로 전달돼요. Flutter는 이 에러를 `PlatformDispatcher.onError`로 넘겨요. 그곳에 들어온 에러를 모두 치명적인 에러로 기록하는 크래시 리포터는, 앱이 계속 실행되는데도 이 에러를 크래시로 기록해요.

`Mutation`과 `MutationCacheConfig`의 나머지 콜백은 뮤테이션의 일부예요. `onMutate`에서, 또는 성공한 뒤 `onSuccess`나 `onSettled`에서 에러가 발생하면 뮤테이션이 실패하고 그 에러가 `onError`로 전달돼요.

## 쿼리가 사용하는 클라이언트

`Query`는 클라이언트를 담지 않아요. 그래서 정의 하나를 모든 클라이언트에서 사용할 수 있어요. Fuery는 쿼리를 사용하는 곳에서 클라이언트를 골라요.

- 정의를 받은 위젯이나 훅은 가장 가까운 `FueryProvider`의 클라이언트를 사용하고, 프로바이더가 없으면 `Fuery.client`를 사용해요. 프로바이더의 클라이언트가 바뀌면 새 클라이언트를 따라가요.
- `observe()`는 `client:`로 넘긴 클라이언트를 사용하고, 넘기지 않으면 그 시점의 `Fuery.client`를 사용해요. 옵저버는 없어질 때까지 그 클라이언트를 유지하고, `observer.client`가 그 클라이언트를 반환해요.
- 정의의 `mutate`와 `mutateAsync`는 넘긴 클라이언트를 사용하고, 넘기지 않으면 그 시점의 `Fuery.client`를 사용해요. 위젯에서는 `context.queryClient`를 넘기세요. 그래야 실행이 위젯이 읽는 캐시에 들어가요.
- 옵저버를 받은 위젯이나 훅은 옵저버의 클라이언트를 사용해요. 디버그 빌드에서는 그 클라이언트가 위젯이나 훅 자신의 클라이언트가 아니면 경고를 출력해요. [화면이 다른 클라이언트의 캐시를 읽어요](../../troubleshooting/#화면이-다른-클라이언트의-캐시를-읽어요)를 참고하세요.
- 쿼리 함수, `placeholderData`, 뮤테이션 콜백은 자신을 실행하는 클라이언트를 받아요.

그래서 쿼리를 최상위 값으로 둘 수 있어요. 위젯 테스트마다 `Fuery.client`나 `FueryProvider`로 새 클라이언트를 받으면 다른 준비는 필요 없어요.

## 하위 트리에 클라이언트 따로 두기

위젯 테스트처럼 앱의 일부를 다른 클라이언트로 실행하려면 그 부분을 `FueryProvider`로 감싸세요. 클라이언트는 `State` 필드에 두세요. 그래야 하위 트리가 마운트된 동안 같은 클라이언트를 유지해요.

```dart
class _SettingsPageState extends State<SettingsPage> {
  final client = QueryClient();

  @override
  Widget build(BuildContext context) {
    return FueryProvider(client: client, child: const SettingsView());
  }
}
```

- 클라이언트는 한 번만 만드세요. `main`, `State` 필드, 테스트의 `setUp`에서 만들면 돼요.
- `build`에서 만들지 마세요. `build`에서 만든 `QueryClient`는 다시 빌드할 때마다, 핫 리로드할 때마다 비어 있는 새 캐시가 돼요. 그러면 아래 위젯이 다시 로딩 상태가 되고 데이터를 다시 가져와요.
- `FueryProvider`는 클라이언트를 마운트하고, 프로바이더가 사라지면 언마운트해요. 그래서 `State`에 `dispose`가 필요 없어요.

프로바이더 아래의 위젯은 프로바이더의 클라이언트를 사용해요. `context.queryClient`가 이 클라이언트를 반환하고, 프로바이더가 없으면 `Fuery.client`를 반환해요. 옵저버를 직접 만들 때는 이 클라이언트를 `observe`에 넘기세요.

```dart
late final todos = todosQuery.observe(client: context.queryClient);
```

정의의 `mutate`에도 넘기세요. `addTodo.mutate('Buy milk', context.queryClient)`처럼 넘겨요.

다른 상태 관리 라이브러리용 [어댑터](../adapters/)는 `FueryProvider.of(context, listen: true)`로 클라이언트를 읽어요. 이 메서드를 호출한 위젯은 프로바이더의 클라이언트가 바뀌면 다시 빌드돼요.

## 예제 앱에서

예제는 [`main`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/main.dart)에서 스토리지를 넣은 `Fuery.client`를 할당하고, `runApp` 전에 저장된 뮤테이션을 복원해요. 화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
