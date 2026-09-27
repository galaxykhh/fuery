---
title: 훅
description: fuery_hooks와 flutter_hooks로 build 안에서 쿼리와 뮤테이션을 렌더링해요.
sourceHash: b017d3f6a0d8
head:
  - tag: title
    content: flutter_hooks용 useQuery와 useMutation | Fuery
---

`fuery_hooks`는 빌더 없이, 쿼리마다 호출 한 번으로 `build` 안에서 Fuery의 쿼리와 뮤테이션을 읽어요. [`flutter_hooks`](https://pub.dev/packages/flutter_hooks)의 `HookWidget`에서 동작해요.

Fuery 고유의 방식은 Flutter의 관례를 따르는 [위젯](../widgets/)이에요. UI에는 빌더를, 사이드 이펙트에는 리스너를 사용해요. 훅은 `build` 안에서 데이터를 읽는 쪽을 선호하는 개발자를 위한 것이에요. 두 방식 모두 같은 쿼리, 뮤테이션, 클라이언트를 사용해요. 그래서 훅으로 만든 화면과 위젯으로 만든 화면이 캐시 하나와 요청 하나를 공유해요.

`fuery`는 Dart와 Flutter에만 의존해요. 훅에는 `flutter_hooks`가 필요해요. 그래서 훅은 별도 패키지에 있고, 훅을 선택한 앱만 그 패키지에 의존해요.

## 설치하기

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks`는 `fuery`를 다시 내보내요. `fuery`처럼 Flutter 3.27 이상과 Dart 3.6 이상이 필요해요.

## 쿼리 읽기

화면을 `HookWidget`으로 만들고, 쿼리를 넘겨 `useQuery`를 호출하세요.

```dart
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

class TodoListScreen extends HookWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = useQuery(todosQuery);
    return switch (todos) {
      QueryResult(:final data?) => TodoList(data),
      QueryResult(:final error?) => Text('$error'),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

- `useQuery`는 현재 결과를 반환하고, 결과가 바뀌면 위젯을 다시 빌드해요.
- 결과는 `QueryBuilder`가 받는 것과 같은 `QueryResult`이고, `refetch()`도 있어요.
- 데이터가 없는 쿼리는 첫 빌드에서 데이터를 가져오기 시작해요. 그 빌드는 이미 `pending` 상태를 보여줘요.

쿼리는 위 코드처럼 최상위 값이어도 되고, `useQuery(todoQuery(id))`처럼 `build`에서 만들어도 돼요. 훅은 쿼리의 옵저버를 하나 유지하고 옵저버의 옵션을 업데이트해요. 그래서 새 키도 같은 프레임에 보여요.

`todosQuery.observe()`를 넘기지 마세요. 빌드할 때마다 새 옵저버가 생기고, 새 옵저버는 구독하고 데이터를 다시 가져와요. 디버그 빌드에서는 훅이 키마다 한 번 경고를 출력해요.

## 다른 쿼리에 의존하는 쿼리

`useQuery`는 데이터를 기다리지 않아요. 다른 쿼리의 값이 필요한 쿼리는 그 값이 생길 때까지 `enabled`로 꺼 둬요.

```dart
Query<List<Post>> postsQuery(int? userId) => Query(
      queryKey: ['posts', userId],
      queryFn: (_) => api.getPosts(userId!),
      enabled: userId != null,
    );

final user = useQuery(userQuery);
final posts = useQuery(postsQuery(user.data?.id));
if (posts.isPending) return const CircularProgressIndicator();
```

| 빌드 | `user` | `posts` |
|---|---|---|
| 첫 빌드 | 가져오는 중, 데이터 없음 | 키 `['posts', null]`, 꺼짐, 아무것도 가져오지 않음 |
| 사용자 데이터가 도착한 뒤 | id가 `7`인 데이터 | 키 `['posts', 7]`, 이 빌드에서 가져오기 시작 |
| 게시물이 도착한 뒤 | 데이터 | 데이터 |

꺼져 있고 데이터가 없는 쿼리는 `pending` 상태예요. 그래서 `posts.isPending` 하나로 사용자를 기다리는 동안과 게시물을 기다리는 동안을 모두 다뤄요. `posts.isLoading`은 게시물 요청이 실행되는 동안만 true예요.

## 페이지 더 불러오기

`useInfiniteQuery`는 불러온 페이지와 `fetchNextPage()`가 있는 `InfiniteQueryResult`를 반환해요.

```dart
final feed = useInfiniteQuery(feedQuery);

ListView(
  children: [
    for (final post in feed.pages.expand((page) => page.posts)) PostTile(post),
    if (feed.hasNextPage)
      TextButton(onPressed: feed.fetchNextPage, child: const Text('More')),
  ],
)
```

## 쿼리 리스트 읽기

`useQueries`는 id마다 쿼리를 하나씩 두는 것처럼 데이터 타입이 같은 쿼리 리스트를 받아서, 결과를 순서대로 반환해요.

```dart
final posts = useQueries([for (final id in ids) postQuery(id)]);
final loaded = posts.where((post) => post.hasData).length;
```

- 키가 리스트에 남아 있는 동안에는 리스트 순서가 바뀌어도 쿼리마다 옵저버를 유지해요.
- 변화가 함께 도착하면 한 번만 다시 빌드해요.
- `.observe()`가 아니라 정의를 넘기세요. 빌드할 때마다 새 옵저버가 생기면 데이터를 다시 가져와요. 디버그 빌드에서는 훅이 경고를 출력해요.

쿼리가 수백 개라면 `useMemoized`로 리스트를 만드세요. 그러면 같은 키로 다시 빌드할 때 같은 리스트를 넘기고, `useQueries`는 쿼리 업데이트를 건너뛰어요. `useMemoized`의 키에는 id와, `enabled:`에 넘기는 값처럼 정의가 읽는 `build`의 다른 값을 모두 넣으세요. 키에 빠진 값은 리스트를 만들 때의 값으로 남아요.

```dart
final posts = useQueries(
  useMemoized(() => [for (final id in ids) postQuery(id)], ids),
);
```

## 데이터 바꾸기

다른 위젯에서처럼 정의에서 뮤테이션을 실행하고, `useQueryClient()`가 반환한 클라이언트를 넘기세요. 뮤테이션의 실행(`mutate` 호출 한 번)은 [`useMutationState`](#뮤테이션의-모든-실행-보여주기)로 읽어요.

```dart
final client = useQueryClient();
final adding = useMutationState(addTodoMutation).any((run) => run.isPending);

ElevatedButton(
  onPressed: adding ? null : () => addTodoMutation.mutate('Buy milk', client),
  child: const Text('Add'),
)
```

- 실행은 위젯이 아니라 클라이언트의 캐시에 속해요.
- [`useQueryClient()`](#클라이언트-읽기)는 훅이 사용하는 클라이언트를 반환해요. 가장 가까운 `FueryProvider`의 클라이언트이고, `FueryProvider`가 없으면 `Fuery.client`예요. 이 클라이언트를 넘기면 `useMutationState`가 읽는 캐시에 실행이 들어가요. 클라이언트를 넘기지 않으면 실행은 `Fuery.client`를 사용해요.
- `NoVariablesMutation`은 클라이언트 앞의 변수 자리에 `null`을 받아요. `logoutMutation.mutate(null, client)`처럼요. [변수 없는 뮤테이션](../mutations/#변수-없는-뮤테이션)을 참고하세요.

### 위젯이 시작한 실행만 보여주기

`useMutation`은 `MutationBuilder`처럼 위젯의 옵저버를 하나 유지해요. 결과는 그 옵저버로 시작한 실행만 보여주고, 결과에 `mutate`가 있어요.

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

`NoVariablesMutation`의 결과는 `mutate(null)`로 뮤테이션을 실행해요.

```dart
final logout = useMutation(logoutMutation);

TextButton(
  onPressed: () => logout.mutate(null),
  child: const Text('Log out'),
)
```

결과의 `mutate`를 한 번 호출할 때 스낵바 같은 사이드 이펙트를 실행하려면 `mutate`에 `MutateOptions`를 넘기세요.

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(
    onError: (error, _, __, ___) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error'))),
  ),
);
```

위젯이 사라져도 요청은 끝까지 실행돼요.

- `useMutation`이 정의를 받았으면, 결과의 `mutate`에 넘긴 `MutateOptions`를 훅이 버려요.
- [공유하는 옵저버](../mutations/#옵저버-하나-공유하기)는 훅이 건드리지 않아서 콜백을 계속 실행해요. 콜백에서 `context.mounted`를 확인하거나, 옵저버를 만든 화면의 `dispose`에서 옵저버의 `reset()`을 호출하세요.

## 뮤테이션의 모든 실행 보여주기

`useMutationState`는 뮤테이션의 모든 실행의 상태를 오래된 것부터 반환해요. 실행이 정의의 `mutate`, 다른 위젯의 `useMutation`, `MutationBuilder`, Cubit 중 어디서 시작했든 상관없어요. [`MutationStateBuilder`](../mutations/#뮤테이션의-모든-실행-보여주기)처럼 정의의 `mutationKey`로 실행을 찾고, 뮤테이션을 실행하지는 않아요.

```dart
final runs = useMutationState(addTodoMutation);

if (runs.any((run) => run.isPending)) return const LinearProgressIndicator();
```

실행마다 반응하려면 그 대신 [`useOnMutationStateChange`](#변화에-반응하기)를 사용하세요.

## 변화에 반응하기

앞의 훅은 읽기만 해요. 화면 이동, 스낵바처럼 한 번만 일어나는 사이드 이펙트에는 이 훅이 반환한 값을 변화 훅에 넘기세요.

| 훅 | 리스너를 호출하는 시점 |
|---|---|
| `useOnQueryChange(result, ...)` | `useQuery`나 `useInfiniteQuery`의 결과가 바뀔 때마다 |
| `useOnMutationChange(result, ...)` | `useMutation`의 결과, 곧 그 결과로 시작한 실행이 바뀔 때마다 |
| `useOnMutationStateChange(mutation, ...)` | 어느 위젯에서 시작했든, `mutationKey`로 찾은 뮤테이션의 각 실행이 바뀔 때마다 |

```dart
final todos = useQuery(todosQuery);
useOnQueryChange(
  todos,
  listenWhen: (previous, current) =>
      !previous.isRefetchError && current.isRefetchError,
  listener: (context, result) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not refresh: ${result.error}')),
  ),
);
```

- 리스너는 변화가 생긴 뒤, 그 변화를 보여주려고 다시 빌드하기 전에 실행돼요. 빌드하는 동안에는 실행되지 않아요. 리스너는 위젯 자신의 `context`를 받아요.
- 훅이 처음 받은 결과로는 리스너를 호출하지 않아요.
- `listenWhen`은 [`QueryListener`](../widgets/#변화에-반응하기)에서처럼 이전에 받은 결과와 새 결과를 비교해요.
- 훅은 가장 최근 빌드의 `listener`와 `listenWhen`을 사용해요.
- `useInfiniteQuery`의 결과를 넘기면 클로저는 페이지가 담긴 `InfiniteQueryResult`를 받아요.
- 위젯 테스트에서 임의로 만든 데이터처럼 `QueryResult` 생성자로 만든 결과를 넘기면 훅은 아무것도 호출하지 않아요.

리스너는 가져오기가 시작하거나 끝나는 것, `setData`로 쓴 데이터처럼 결과의 모든 변화를 받아요. 상태가 바뀌는 순간에만 반응하려면 위 코드처럼 `listenWhen`에서 두 결과를 비교하세요. 그러면 새로고침이 실패할 때마다 스낵바를 하나만 띄워요. 에러가 남아 있는 동안 이어지는 변화마다 띄우지 않아요.

같은 쿼리에 반응하는 위젯이 두 개면 위젯마다 자기 리스너를 실행해요. 그래서 변화 훅의 사이드 이펙트는 위젯마다 한 번씩 실행돼요. 실패한 가져오기를 모두 보고하는 것처럼 앱 전체에서 한 번만 필요한 사이드 이펙트에는 그 대신 [`QueryCacheConfig.onError`](../client-setup/#모든-실패를-한곳에서-보고하기)를 사용하세요.

변화 훅은 옵저버를 더하지 않고 위젯을 다시 빌드하지도 않아요. 하나뿐인 예외는 `useOnMutationStateChange`예요. 이 훅은 `FueryProvider`가 제공하는 클라이언트를 읽어요. 그래서 그 클라이언트가 다른 클라이언트로 바뀌면 위젯을 다시 빌드해요. `useQuery` 같은 읽기 훅은 결과가 바뀌면 위젯을 다시 빌드해요. 위젯을 다시 빌드하지 않고 쿼리에 반응하려면 하위 트리를 `QueryListener`나 `InfiniteQueryListener`로 감싸세요. 두 위젯은 `fuery_hooks`가 다시 내보내요.

`useOnMutationChange`는 자기가 받은 결과로 시작한 실행의 변화를 받아요.

```dart
final addTodo = useMutation(addTodoMutation);
useOnMutationChange(
  addTodo,
  listenWhen: (previous, current) => current.isSuccess,
  listener: (context, result) => Navigator.pop(context),
);

FilledButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate(title.text),
  child: const Text('Add'),
)
```

- 그 결과에서 뮤테이션을 실행하거나, 뮤테이션을 실행하는 자식 위젯에 결과를 넘기세요.
- 다른 `useMutation(addTodoMutation)`에는 자기 옵저버가 따로 있어요. 이 리스너는 그 옵저버의 실행에서 변화를 받지 않아요.
- 결과는 가장 최근 실행을 보여줘요. 그래서 실행이 겹치면 리스너는 가장 최근 실행의 변화를 받아요. 실행마다 반응하려면 `useOnMutationStateChange`를 사용하거나 `mutateAsync`를 `await`로 기다리세요.
- [공유하는 옵저버](../mutations/#옵저버-하나-공유하기)를 받으면 `useMutation`은 그 옵저버의 결과를 반환하고, 리스너는 그 옵저버의 모든 실행의 변화를 받아요.

`useOnMutationStateChange`는 `MutationStateListener`처럼 어디서 시작했든 뮤테이션의 모든 실행의 변화를 받아요. `useMutation`은 필요 없어요. 리스너는 바뀐 실행마다 한 번씩 그 실행의 새 상태를 받아요. `listenWhen`은 그 실행의 이전 상태와 새 상태를 비교해요.

```dart
useOnMutationStateChange(
  addTodoMutation,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
);
```

| 사이드 이펙트 | 두는 곳 |
|---|---|
| 어떤 실행이든 끝나면 `['todos']`를 무효화하는 것 같은 캐시 작업 | `Mutation`의 콜백 |
| 화면 닫기처럼, 화면의 `useMutation`으로 시작한 실행에 화면이 하는 반응 | `useOnMutationChange` |
| 실패할 때마다 띄우는 스낵바처럼, 어느 위젯에서 시작했든 모든 실행에 하는 반응 | `useOnMutationStateChange` |
| 그 호출의 변수가 필요한, 호출 한 번의 사이드 이펙트 | `useMutation` 결과의 `mutate`에 넘기는 `MutateOptions` |
| 호출 한 번이 끝난 뒤, 그 호출을 실행하는 코드에서 하는 사이드 이펙트 | `try` 안에서 `await addTodoMutation.mutateAsync(...)`, 그다음 `context.mounted` 확인 |

호출을 `await`로 기다리면 사이드 이펙트를 호출하는 코드 바로 옆에 둘 수 있어요.

```dart
final client = useQueryClient();

FilledButton(
  onPressed: () async {
    try {
      await addTodoMutation.mutateAsync(title.text, client);
    } catch (_) {
      return; // useOnMutationStateChange above reports the failure.
    }
    if (context.mounted) Navigator.pop(context);
  },
  child: const Text('Add'),
)
```

`try`가 있어서 실패가 잡히지 않은 에러로 zone에 전달되지 않아요.

로그인하지 않은 사용자처럼 위젯이 마운트될 때의 결과로 이미 보여줄 것이 정해진다면, 훅이 반환한 결과로 `build`에서 정하세요. 그 결과로는 변화 훅이 호출되지 않아요.

### useEffect에서 스낵바와 화면 이동

스낵바를 보여주거나 화면을 이동할 때는 변화 훅을 사용하세요. 변화 훅은 빌드 밖에서, 이후의 변화에만 실행돼요. `useEffect`와 `useValueChanged`는 빌드하는 동안 실행돼요. 빌드하는 동안에는 스낵바를 띄우거나 화면을 이동하면 실패해요. 트리를 빌드하는 동안 위젯 트리를 바꾸기 때문이에요. `useEffect` 콜백은 첫 빌드에서 위젯이 마운트될 때의 값으로 실행돼요. 그 뒤에는 키가 바뀐 빌드마다 실행되고, 키가 없으면 모든 빌드마다 실행돼요. 디버그 빌드에서는 이 호출이 이런 에러로 실패해요.

- `showSnackBar`는 `The showSnackBar() method cannot be called during build.` 에러를 알려요.
- `Navigator.pop`은 `setState() or markNeedsBuild() called during build.` 에러를 알려요.
- 첫 빌드나 키가 바뀐 뒤에는 `ScaffoldMessenger.of(context)`가 먼저 `Cannot listen to inherited widgets inside HookState.initState.` 에러로 실패해요.

## 위젯에 대응하는 훅

| 위젯 | 훅 |
|---|---|
| `QueryBuilder` | `useQuery(query)` |
| `QueryListener` | `useOnQueryChange(result, listener: ...)` |
| `QueryConsumer` | `useQuery(query)`와 `useOnQueryChange` |
| `InfiniteQueryBuilder` | `useInfiniteQuery(query)` |
| `InfiniteQueryListener` | `useOnQueryChange(result, listener: ...)` |
| `InfiniteQueryConsumer` | `useInfiniteQuery(query)`와 `useOnQueryChange` |
| `MutationBuilder` | `useMutation(mutation)` |
| `MutationListener` | `useOnMutationChange(result, listener: ...)` |
| `MutationConsumer` | `useMutation(mutation)`과 `useOnMutationChange` |
| `QueriesBuilder` | `useQueries(queries)` |
| `MutationStateBuilder`, `MutationStateSelector` | `useMutationState(mutation)` |
| `MutationStateListener` | `useOnMutationStateChange(mutation, listener: ...)` |

`result`는 `useQuery(query)` 같은 읽기 훅이 반환한 값이에요.

## 클라이언트 읽기

`useQueryClient()`는 훅이 사용하는 클라이언트를 반환해요. 위쪽의 `FueryProvider`가 제공하는 클라이언트이거나 `Fuery.client`예요. `FueryProvider`가 제공하는 클라이언트가 다른 클라이언트로 바뀌면 위젯을 다시 빌드해요.

```dart
final client = useQueryClient();

RefreshIndicator(
  onRefresh: () => client.invalidateQueries(queryKey: ['todos']),
  child: TodoList(todos.data ?? []),
)
```

`observe()`로 만든 옵저버는 자기 클라이언트를 유지해요. `client:`를 넘기지 않으면 그 클라이언트는 `Fuery.client`예요. 자기 클라이언트가 있는 `FueryProvider` 아래에서는 정의를 넘기거나, `useQueryClient()`가 반환한 클라이언트로 옵저버를 만드세요. 정의의 `mutate`도 클라이언트를 넘기지 않으면 `Fuery.client`를 사용해요. `addTodoMutation.mutate('Buy milk', client)`처럼 클라이언트를 넘기세요. 디버그 빌드에서는 다른 클라이언트의 옵저버를 받은 훅이 경고를 출력해요. [화면이 다른 클라이언트의 캐시를 읽어요](../../troubleshooting/#화면이-다른-클라이언트의-캐시를-읽어요)를 참고하세요.

## 캐시 지켜보기

`useStream`은 가져오는 중인 쿼리가 있는지처럼 `client.watch`에서 나온 값을 렌더링해요. 스트림은 `useMemoized`로 한 번만 만드세요.

```dart
final client = useQueryClient();
final fetching = useStream(
  useMemoized(
    () => client.watch((client) => client.isFetching() > 0),
    [client],
  ),
);

if (fetching.data ?? false) return const LinearProgressIndicator();
```

- [`watch`](../query-client/#캐시-지켜보기)를 호출할 때마다 새 스트림을 반환해요. 리스너는 저마다 현재 값을 먼저 받아요.
- `useStream`은 새 스트림을 받을 때마다 구독해요. 그래서 빌드할 때마다 스트림을 만들면 프레임마다 위젯을 다시 빌드해요.
- `useMemoized`의 키에 클라이언트와, 셀렉터가 읽는 `build`의 값을 모두 넣으세요. 그래야 스트림이 그 값을 따라가요.

뮤테이션에는 스트림이 필요 없어요. [`useMutationState`](#뮤테이션의-모든-실행-보여주기)가 뮤테이션의 실행을 반환하고, `useMutationState(const MutationFilters())`는 모든 뮤테이션의 실행을 반환해요.

## 테스트

훅을 사용하는 화면도 다른 위젯처럼 테스트하세요. [테스트](../testing/)의 내용이 그대로 적용돼요. 테스트마다 끝에 트리를 언마운트하고 클라이언트를 비우세요.
