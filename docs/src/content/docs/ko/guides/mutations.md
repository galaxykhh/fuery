---
title: 뮤테이션
description: Flutter에서 서버 데이터를 만들고, 업데이트하고, 삭제해요. 낙관적 업데이트와 롤백도 할 수 있어요.
sourceHash: 0c544eeebc13
head:
  - tag: title
    content: Flutter의 뮤테이션과 낙관적 업데이트 | Fuery
---

뮤테이션은 새 할 일처럼 바뀐 내용을 서버에 보내요. 버튼에서 뮤테이션을 실행하고, 진행 상태를 어느 화면에서든 보여주세요. 실패하면 사용자에게 알리고, 서버가 응답하기 전에 캐시를 업데이트하세요.

이 뮤테이션은 할 일을 추가해요.

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);
```

`mutationFn`의 매개변수에 위 코드의 `String title`처럼 타입을 적으세요. 그러면 Dart가 그 타입에서 나머지 타입을 추론해요. 어떤 위젯이든 `mutationKey`로 뮤테이션의 실행을 찾을 수 있어요. 실행은 `mutate` 호출 한 번이에요([뮤테이션 실행](../../how-the-cache-works/#뮤테이션-실행)). 모든 옵션은 [뮤테이션 옵션](../../reference/mutation-options/)에 있어요.

## 뮤테이션 실행하기

정의의 `mutate`를 호출하고 `context.queryClient`를 넘기세요. `StatelessWidget`을 포함해 어떤 위젯이든 이렇게 뮤테이션을 실행해요.

```dart
class AddTodoButton extends StatelessWidget {
  const AddTodoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => addTodo.mutate('Buy milk', context.queryClient),
      child: const Text('Add'),
    );
  }
}
```

- `mutate`는 실행을 시작하고 바로 반환해요. 실행이 실패하면 에러는 호출한 쪽이 아니라 실행의 상태와 콜백으로 전달돼요.
- 정의는 상태를 담지 않아요. 실행은 위젯이 아니라 클라이언트의 캐시에 속해요. 그래서 버튼이 화면에서 사라져도 실행은 계속돼요.
- `context.queryClient`는 위젯이 사용하는 클라이언트예요. 가장 가까운 `FueryProvider`의 클라이언트이고, `FueryProvider`가 없으면 `Fuery.client`예요. 이 클라이언트를 넘기면 [MutationState 위젯](#뮤테이션의-모든-실행-보여주기)이 읽는 캐시에 실행이 들어가요.
- 클라이언트를 넘기지 않으면 실행은 `Fuery.client`를 사용해요. [Cubit](../bloc/#cubit이나-bloc에서-뮤테이션-실행하기)처럼 `BuildContext`가 없는 코드는 이렇게 뮤테이션을 실행해요.

## 뮤테이션의 모든 실행 보여주기

MutationState 위젯은 어느 화면에서든 뮤테이션의 실행을 보여줘요. 실행이 정의의 `mutate`, `MutationBuilder`, `useMutation`, Cubit, [`restore(mutations:)`](../persistence/#뮤테이션-저장하기) 중 어디서 시작했든 정의의 `mutationKey`로 찾아요. MutationState 위젯은 `StatelessWidget`에서도 동작해요.

| 위젯 | 빌드에 쓰는 값, 또는 받는 변화 |
|---|---|
| `MutationStateBuilder` | 모든 실행의 `MutationState`, 오래된 실행부터 |
| `MutationStateSelector` | 그 상태에서 선택한 값. 값이 바뀔 때만 다시 빌드해요. |
| `MutationStateListener` | 사이드 이펙트에 사용하는, 실행마다 일어나는 모든 변화 |

할 일을 추가하는 동안에는 위 버튼을 비활성화해요.

```dart
MutationStateSelector(
  mutation: addTodo,
  selector: (runs) => runs.any((run) => run.isPending),
  builder: (context, adding) => FilledButton(
    onPressed:
        adding ? null : () => addTodo.mutate('Buy milk', context.queryClient),
    child: Text(adding ? 'Adding…' : 'Add'),
  ),
)
```

서버로 보내는 중인 제목이에요. 정의의 변수처럼 `String` 타입이에요.

```dart
MutationStateBuilder(
  mutation: addTodo,
  builder: (context, runs) => Column(
    children: [
      for (final run in runs)
        if (run case MutationState(isPending: true, :final variables?))
          ListTile(title: Text(variables)),
    ],
  ),
)
```

### 조건에 맞는 실행

- `Mutation`을 받으면 위젯은 `mutationKey`가 정의의 키와 정확히 같은 실행을 정의와 같은 타입으로 보여줘요.
- 키와 타입이 같은 다른 정의의 실행도 포함해요.
- 그 키에 타입이 다른 실행이 있으면 빼고, [`onUncaughtError`](../client-setup/#콜백에서-발생한-에러-잡기)로 한 번 전달해요. 정의마다 키를 따로 주세요.
- `mutationKey`가 없는 정의는 디버그 빌드에서 assert에 실패해요.
- `MutationFilters`를 받으면 위젯은 필터 조건에 맞는 모든 뮤테이션의 실행을 보여줘요. `client.mutationCache.findAll`처럼 키 접두사, `exact` 키, `status`, `predicate`로 찾아요. 이때 상태의 타입은 `Object?`예요.
- `status` 필터가 없으면 끝난 실행도 조건에 맞아요.

### 실행 순서와 수명

- 실행은 오래된 것부터 나열돼요. 그래서 `runs.lastOrNull`이 가장 최근 실행이에요.
- 실행은 끝난 뒤에도 `gcTime`(가비지 컬렉션 시간, 기본값: 5분) 동안 남아요. 그러니 로딩 표시는 실행 개수가 아니라 `isPending`으로 만드세요.
- 마운트된 `MutationBuilder`는 가장 최근 실행을 보여주는 동안 그 실행을 유지해요.
- `client.clear()`는 모든 실행을 제거해요.

### 클라이언트와 비용

- 위젯의 클라이언트에 있는 실행만 포함해요. 위젯의 클라이언트는 가장 가까운 `FueryProvider`의 클라이언트나 `Fuery.client`예요.
- MutationState 위젯은 읽기만 해요. 뮤테이션을 실행하지 않고 정의의 옵션도 적용하지 않아요. 그래서 `build`에서 정의를 만들어도 비용이 들지 않아요.

## 뮤테이션이 실패했다고 사용자에게 알리기

`mutate`가 실패하면 에러를 일으키지 않고 실행의 상태에 에러를 담아요. `MutationStateListener`는 어느 화면에서 시작했든 뮤테이션의 모든 실행의 변화를 받아요. 리스너는 실행마다 새 상태를 받아요.

```dart
MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
  child: const TodoScreen(),
)
```

- Fuery는 바뀐 실행마다 리스너를 한 번씩 호출해요. 그래서 실행 두 개가 실패하면 두 번 호출해요.
- `listenWhen`은 그 실행의 이전 상태와 새 상태를 비교해요.
- 리스너가 마운트될 때 실행에 이미 있던 상태나, 캐시가 제거한 실행으로는 리스너를 호출하지 않아요.
- 리스너는 복원한 실행과 다른 화면의 실행의 변화도 받아요. 그러니 메시지를 보여줄 곳에 한 번만 마운트하세요.

`MutationListener`는 자기가 받은 옵저버의 실행에서만 변화를 받아요. 정의를 받으면 자기 옵저버를 만들지만, 그 옵저버로 뮤테이션을 실행하는 코드가 없어요. 그래서 아무 변화도 받지 못해요. 디버그 빌드에서는 경고도 출력해요. [MutationListener가 한 번도 실행되지 않아요](../../troubleshooting/#mutationlistener가-한-번도-실행되지-않아요)를 참고하세요.

## 호출 한 번이 성공한 뒤 처리하기

`mutateAsync`는 실행이 성공하면 데이터를 반환하고, 실패하면 에러를 일으켜요. 저장한 폼을 닫는 것처럼 호출 한 번이 끝난 뒤 할 일이 있으면 `mutateAsync`를 `await`로 기다리세요.

```dart
FilledButton(
  onPressed: () async {
    try {
      await addTodo.mutateAsync('Buy milk', context.queryClient);
    } catch (_) {
      return; // The MutationStateListener above reports the failure.
    }
    if (context.mounted) Navigator.pop(context);
  },
  child: const Text('Add'),
)
```

- `await` 뒤에 `context.mounted`를 확인하세요. 실행이 `pending` 상태인 동안 사용자가 화면을 떠날 수 있어요.
- 에러를 잡으세요. 어디서도 잡지 않은 에러는 잡히지 않은 에러로 zone에 전달돼요.

## 위젯이 시작한 실행만 보여주기

`MutationBuilder`는 자기 옵저버를 두고, 자기가 시작한 실행만 보여줘요. 여러 폼에 Save 버튼이 하나씩 있을 때처럼, 위젯의 상태에서 다른 곳에서 시작한 실행을 빼야 하면 `MutationBuilder`를 사용하세요.

```dart
MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => FilledButton(
    onPressed: state.isPending ? null : () => state.mutate('Buy milk'),
    child: Text(state.isPending ? 'Adding…' : 'Add'),
  ),
)
```

- `state.mutate('Buy milk')`는 이 위젯으로 실행을 시작해요. `await state.mutateAsync('Buy milk')`는 데이터를 반환하고, 실패하면 에러를 일으켜요.
- `state`는 이 위젯이 시작한 가장 최근 실행을 보여줘요. `addTodo.mutate`나 다른 위젯이 시작한 실행은 `state`에 나타나지 않아요.
- `state.reset()`은 상태를 `idle`로 되돌려요.
- 위젯은 가장 가까운 `FueryProvider`의 클라이언트를 사용하고, `FueryProvider`가 없으면 `Fuery.client`를 사용해요.
- `HookWidget`에서는 `useMutation(addTodo)`가 같은 결과를 반환해요. [훅](../hooks/#위젯이-시작한-실행만-보여주기)을 참고하세요.

`state`의 모든 멤버와 필드는 [뮤테이션 결과](../../reference/mutation-results/#mutationresult)에 있어요.

이 위젯의 호출 한 번에 반응하려면 `state.mutate`에 `MutateOptions`를 넘기세요. 그 콜백은 호출이 끝나면 뮤테이션 자체의 콜백 다음에 실행돼요.

```dart
state.mutate(
  'Buy milk',
  MutateOptions(onSuccess: (todo, title, _, __) => showAddedSnackBar(todo)),
);
```

- 같은 옵저버에서 `mutate`를 다시 호출하면 콜백이 바뀌어요. 가장 최근 호출의 콜백만 실행돼요.
- `reset()`을 호출하면 콜백을 버려요. 위젯이 언마운트될 때도 버려요.
- [공유하는 옵저버](#옵저버-하나-공유하기)는 위젯이 구독하든 안 하든 콜백을 실행해요. 콜백에서 `BuildContext`를 사용하기 전에 `context.mounted`를 확인하세요.

## 콜백

`onMutate`는 `mutationFn`보다 먼저 실행돼요. `onSuccess`, `onError`, `onSettled`는 `mutationFn` 다음에 실행돼요. 콜백의 인수와 순서는 [콜백](../../reference/mutation-options/#콜백)에 있어요.

- 마지막 인수 `client`는 뮤테이션을 실행하는 클라이언트예요. 정의의 `mutate`에 넘긴 클라이언트, 위젯이 `FueryProvider`에서 받은 클라이언트, `observe(client:)`에 넘긴 클라이언트 중 하나예요. `Fuery.client` 대신 이 `client`를 사용하세요. 그래야 테스트에서도 콜백이 올바른 캐시를 다뤄요.
- `onMutate`, `onSuccess`, `onError`, `onSettled`가 `Future`를 반환하면 그 `Future`가 완료될 때까지 실행은 `pending` 상태로 남아요. Fuery는 `MutateOptions` 콜백은 기다리지 않아요. 앞의 `addTodo`는 `onSuccess`에서 `invalidateQueries`의 `Future`를 반환해요. 그래서 목록을 다시 가져올 때까지 버튼에 *Adding…*이 보여요.

## 낙관적 업데이트

낙관적 업데이트는 서버가 응답하기 전에 캐시를 바꿔요. 그래서 화면이 바로 반응해요.

1. `onMutate`에서 쿼리를 다시 가져오는 중이면 취소하세요. 그래야 다시 가져온 데이터가 업데이트를 덮어쓰지 않아요.
2. 이어서 `onMutate`에서 새 데이터를 쓰고 이전 데이터를 반환하세요. 다른 콜백은 이 값을 `context`로 받아요.
3. `onError`에서 이전 데이터를 다시 쓰세요.
4. `onSettled`에서 쿼리를 무효화해 서버에 있는 데이터를 다시 가져오세요.

`todosQuery`와 `todosKey`는 쿼리와 그 쿼리의 [키](../organizing-queries/)예요.

```dart
final deleteTodo = Mutation(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id, client) async {
    // Keep a refetch in flight from overwriting the optimistic update.
    await client.cancelQueries(queryKey: todosKey);
    final previous = client.getData(todosQuery);
    client.updateData(
      todosQuery,
      (todos) => todos?.where((todo) => todo.id != id).toList(),
    );
    return previous;
  },
  onError: (error, id, previous, client) {
    if (previous != null) client.setData(todosQuery, previous);
  },
  onSettled: (_, __, ___, ____, client) {
    return client.invalidateQueries(queryKey: todosKey);
  },
);
```

[플레이그라운드에서 해보기](/fuery/demo/#/optimistic): 할 일을 추가하고, 요청을 실패하게 해서 롤백을 확인해보세요.

## 변수 없는 뮤테이션

로그아웃처럼 아무것도 받지 않는 뮤테이션에는 `NoVariablesMutation`을 사용하세요. `mutationFn`과 콜백에는 변수가 없어요([NoVariablesMutation](../../reference/mutation-options/#novariablesmutation)).

```dart
final logoutMutation = NoVariablesMutation(
  mutationFn: () => api.logout(),
);
```

`logoutMutation.mutate()`로 실행해요. 그래서 버튼에 tear-off를 넘길 수 있어요. `onPressed: logoutMutation.mutate`처럼요. `logoutMutation.mutateAsync()`는 데이터를 반환해요.

- `Fuery.client`가 아닌 클라이언트에서는 변수 자리에 먼저 `null`을 넘기세요. `logoutMutation.mutate(null, context.queryClient)`처럼요.
- `MutationBuilder`나 `useMutation`의 결과는 변수 타입이 `void`예요. 그래서 `state.mutate(null)`로 뮤테이션을 실행해요. 호출 한 번의 콜백에는 변수 인수가 그대로 있고, 그 값은 `null`이에요.
- `observe()`로 만든 옵저버인 `NoVariablesMutationObserver`는 `mutate()`로 뮤테이션을 실행해요.

로그아웃한 뒤에는 앱이 캐시를 사용하던 화면을 떠난 다음 캐시를 비우세요. 이 순서가 왜 중요한지는 [로그아웃할 때 모두 비우기](../query-client/#로그아웃할-때-모두-비우기)에서 설명해요.

## 재시도와 실행 순서

뮤테이션은 `retry`를 설정했을 때만 재시도해요. 쓰기를 반복해도 항상 안전하지는 않기 때문이에요. `RetryPolicy.count(2)`는 시도를 두 번 더 허용해요. 첫 재시도는 1초 뒤, 두 번째 재시도는 다시 2초 뒤예요. `scope`를 공유하는 뮤테이션은 시작한 순서대로 하나씩 실행돼요.

```dart
final saveDraft = Mutation(
  mutationFn: (Draft draft) => api.saveDraft(draft),
  retry: const RetryPolicy.count(2),
  scope: const MutationScope('drafts'),
);
```

스코프에서 차례를 기다리는 실행은 `isPaused`가 true예요. 네트워크를 기다리는 실행도 마찬가지예요. 앱을 다시 시작해도 기다리는 실행을 유지하려면 뮤테이션에 `persist`를 설정하세요([뮤테이션 저장하기](../persistence/#뮤테이션-저장하기)).

## 옵저버 하나 공유하기

정의의 `mutate`와 MutationState 위젯에는 직접 만든 옵저버가 필요 없어요. Cubit도 정의에서 뮤테이션을 실행해요([Cubit이나 Bloc에서 뮤테이션 실행하기](../bloc/#cubit이나-bloc에서-뮤테이션-실행하기)). 여러 위젯이 한 화면의 실행만 따라가야 할 때만 옵저버 하나를 공유하세요.

`addTodo.observe()`는 `MutationObserver`를 반환해요. 이 옵저버를 받은 위젯은 모두 옵저버를 그대로 사용해요. 여기서는 이 화면의 폼이 저장하는 동안 앱 바에 진행 표시줄을 보여줘요. `MutationStateSelector`를 사용하면 다른 화면이 시작한 실행도 보여줘요.

```dart
class _AddTodoScreenState extends State<AddTodoScreen> {
  late final adding = addTodo.observe(client: context.queryClient);

  @override
  void dispose() {
    adding.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New todo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: MutationSelector(
            mutation: adding,
            selector: (state) => state.isPending,
            builder: (context, saving) => saving
                ? const LinearProgressIndicator()
                : const SizedBox(height: 4),
          ),
        ),
      ),
      body: AddTodoForm(onSubmit: adding.mutate),
    );
  }
}
```

화면에서 호출한 뮤테이션이 성공한 뒤 화면을 닫을 때는 공유하는 옵저버가 필요 없어요. `mutateAsync`를 `await`로 기다리세요([호출 한 번이 성공한 뒤 처리하기](#호출-한-번이-성공한-뒤-처리하기)).

- 옵저버는 `State` 필드나 Cubit에서 한 번만 만드세요. `build`에서 `observe()`를 호출하면 다시 빌드할 때마다 `idle` 상태의 새 옵저버를 반환해요.
- `observe()`는 `client:`를 넘기지 않으면 `Fuery.client`를 사용해요. 자기 클라이언트가 있는 `FueryProvider` 아래에서는 위 코드처럼 `context.queryClient`를 넘기세요.
- `dispose`에서 `reset()`을 호출하세요. `reset()`은 이 화면에 속한 가장 최근 `mutate` 호출의 콜백을 버려요. 정의를 받은 위젯은 언마운트될 때 자기 옵저버를 초기 상태로 되돌려요.
- 이 옵저버를 받은 `MutationListener`, `MutationSelector`, `MutationBuilder`는 어디서 호출했든 옵저버가 시작한 모든 실행의 변화를 받아요.

## 예제 앱에서

- [피드 뮤테이션](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/data/feed_mutations.dart)에는 롤백하는 낙관적 좋아요와, 오프라인일 때 멈추는 댓글이 있어요.
- [피드](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart)는 좋아요를 정의에서 실행하고, 실패한 좋아요를 모두 `MutationStateListener`로 알려요.
- [게시물 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart)은 정의에서 댓글을 보내고, 보내는 중인 댓글을 `MutationStateBuilder`로 보여줘요.
- [글쓰기 화면](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/compose/compose_screen.dart)은 `MutationBuilder`로 새 게시물을 올려요. 그 버튼은 자기 실행만 보여줘요.

화면마다 보여주는 기능은 예제의 [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example)에 있어요.
