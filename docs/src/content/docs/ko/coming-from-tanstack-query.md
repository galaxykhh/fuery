---
title: TanStack Query에서 넘어왔다면
description: "Flutter 앱에서 TanStack Query(React Query) v5의 개념마다 대응하는 Fuery 이름: 클라이언트, 쿼리 키, useQuery 옵션과 결과, 뮤테이션, 무한 쿼리, 캐시를 기기에 저장하기, 개발자 도구."
sourceHash: 4c2d28d32c2b
head:
  - tag: title
    content: TanStack Query(React Query)에서 Flutter로 넘어왔다면 | Fuery
---

이 페이지는 [TanStack Query](https://tanstack.com/query) v5(이전 이름 React Query)의 개념마다 Fuery에서 부르는 이름을 알려줘요. TanStack Query를 아는 React 개발자가 Flutter 앱에서 같은 캐싱 모델을 사용하려 할 때 읽으면 돼요.

Fuery의 캐싱과 다시 가져오기 모델은 TanStack Query에서 영감을 받았어요. 그래서 알고 있는 내용 대부분이 Fuery에도 그대로 적용돼요.

- 쿼리 키는 캐시 항목의 이름이에요. 그 키를 사용하는 화면은 모두 그 캐시 항목과 요청을 공유해요.
- 데이터는 `staleTime` 동안 fresh 상태이고, 그 뒤에는 stale 상태예요. Fuery가 백그라운드에서 다시 가져오는 동안 stale 데이터는 화면에 남아요.
- 아무 곳에서도 사용하지 않는 데이터는 `gcTime`(가비지 컬렉션 시간)이 지나면 메모리에서 사라져요.
- `invalidateQueries`, `setQueryData`, `onMutate`, `fetchNextPage`와 대부분의 결과 필드는 이름이 같아요.
- 기본값도 같아요. `staleTime`은 0, `gcTime`은 5분이고, 화면에 있는 쿼리는 간격을 늘려가며 3번 재시도해요.

대신 화면에서 쿼리를 사용하는 방식은 Flutter의 관례를 따라요. 이 부분은 [Flutter에서 달라지는 점](#flutter에서-달라지는-점)에 있어요.

## 모든 곳에서 달라지는 이름

이 페이지의 표는 모두 왼쪽에 TanStack Query 이름을, 오른쪽에 Fuery 이름을 적었어요. 모든 표에 공통으로 해당하는 차이가 네 가지 있어요.

- 옵션은 객체가 아니라 `Query(queryKey: ..., queryFn: ...)`처럼 정의의 이름 있는 인수예요.
- 기간은 밀리초가 아니라 `Duration`이에요. `dataUpdatedAt` 같은 타임스탬프는 그대로 epoch 이후 밀리초예요.
- 데이터가 없으면 `undefined`가 아니라 `null`이에요.
- 문자열 값은 enum이에요. `'always'`는 `RefetchMode.always`, `'pending'`은 `QueryStatus.pending`이 돼요.

## 클라이언트 설정하기

| TanStack Query | Fuery |
|---|---|
| `new QueryClient({ defaultOptions })` | `QueryClient(defaultOptions: DefaultOptions(...))`. `queries`에는 `QueryDefaults`, `mutations`에는 `MutationDefaults`를 넘겨요. |
| `<QueryClientProvider client={queryClient}>` | 필요 없어요. `main`에서 `Fuery.client`에 할당하세요. `FueryProvider(client: ..., child: ...)`는 하위 트리에 별도 클라이언트를 줘요. |
| `useQueryClient()` | 모든 위젯에서 `context.queryClient`, 또는 `fuery_hooks`의 `useQueryClient()` |
| `mount()`, `unmount()` | `mount()`, `unmount()`. `Fuery.client`에 할당하거나 `FueryProvider`를 사용하면 Fuery가 대신 호출해요. |
| `setQueryDefaults`, `getQueryDefaults`, `setMutationDefaults`, `getMutationDefaults` | 같은 이름 |

코드 예시는 두 개씩 짝지어 같은 코드를 보여줘요. 먼저 TanStack Query, 그다음 Fuery예요. `api`, `Todo`, 그리고 `TodoList` 같은 위젯은 직접 작성한 코드를 가리켜요.

```tsx title="TanStack Query"
const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30 * 1000 } },
})

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Todos />
    </QueryClientProvider>
  )
}
```

```dart title="Fuery"
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const MaterialApp(home: TodoListScreen()));
}
```

아무것도 설정하지 않아도 앱은 동작해요. 처음 사용할 때 Fuery가 `Fuery.client`를 만들어요. [클라이언트 설정하기](../guides/client-setup/)를 참고하세요.

## 쿼리 정의하고 보여주기

| TanStack Query | Fuery |
|---|---|
| `queryKey: ['todos', id]` | `queryKey: ['todos', id]`. 타입은 `List<Object?>`예요. Fuery는 키를 값으로 비교하고, 필터는 접두사가 일치하는 키를 찾아요. |
| `queryKey: ['todos', { status, page }]` | `queryKey: ['todos', {'status': status, 'page': page}]`. 맵 항목의 순서는 상관없어요. 키에 넣는 객체에는 `toJson()` 메서드가 있어야 해요. |
| `queryFn: ({ queryKey, signal, meta, client }) => ...` | `queryFn: (context) => ...`. `context.queryKey`, `context.signal`, `context.meta`, `context.client`가 있어요. |
| 데이터는 `undefined`가 될 수 없어요. | 쿼리 함수는 `Future<List<Todo>>`처럼 null이 될 수 없는 타입을 반환해요. |
| `fetch(url, { signal })` | `context.signal.onAbort(...)`를 HTTP 클라이언트의 취소 기능에 연결해요. [요청 취소하기](../guides/queries/#요청-취소하기)를 참고하세요. |
| `queryOptions({ ... })` | `Query(...)`. 위젯, 훅, 클라이언트가 모두 받는 정의예요. |
| `useQuery({ ... })` | `QueryBuilder(query: ..., builder: ...)`, 또는 `fuery_hooks`의 `useQuery(query)` |

```tsx title="TanStack Query"
function Todos() {
  const { data, error } = useQuery({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  })

  if (data) return <TodoList todos={data} />
  if (error) return <p>{error.message}</p>
  return <Spinner />
}
```

```dart title="Fuery"
final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);

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

`todosQuery`는 데이터를 담지 않고 아무것도 시작하지 않아요. `QueryBuilder`는 마운트될 때 데이터를 가져오고, 새 결과가 나올 때마다 다시 빌드해요. 키와 옵션은 [쿼리](../guides/queries/)에 있어요.

## 결과 읽기

| TanStack Query | Fuery |
|---|---|
| `status`: `'pending'`, `'error'`, `'success'` | `status`: `QueryStatus.pending`, `.error`, `.success` |
| `fetchStatus`: `'fetching'`, `'paused'`, `'idle'` | `fetchStatus`: `FetchStatus.fetching`, `.paused`, `.idle` |
| `data`, `error` | `data`, `error` |
| `isPending`, `isSuccess`, `isError`, `isLoading`, `isFetching`, `isRefetching`, `isPaused` | 같은 이름 |
| `isLoadingError`, `isRefetchError`, `isPlaceholderData`, `isStale`, `isFetched`, `isFetchedAfterMount`, `isEnabled` | 같은 이름 |
| `dataUpdatedAt`, `errorUpdatedAt`, `errorUpdateCount`, `failureCount`, `failureReason` | 같은 이름 |
| `refetch({ cancelRefetch, throwOnError })` | `refetch(cancelRefetch: ..., throwOnError: ...)`. `Future<QueryResult>`를 반환해요. |

Fuery에는 `hasData`가 더 있어요. `data`가 `null`이 아니면 `true`예요. 모든 필드는 [쿼리 결과](../reference/query-results/)에 있어요.

## fresh 상태, 재시도, 다시 가져오기 설정하기

| TanStack Query | Fuery |
|---|---|
| `staleTime`(기본값: `0`) | `Duration` 타입의 `staleTime`(기본값: 0) |
| `staleTime: Infinity` | `staleTime: infiniteDuration` |
| `staleTime: 'static'` | `staleTime: staticStaleTime` |
| `gcTime`(기본값: 5분) | `Duration` 타입의 `gcTime`(기본값: 5분) |
| `retry: 3`(기본값), `false`, `true` | `retry: RetryPolicy.count(3)`(기본값), `RetryPolicy.never()`, `RetryPolicy.always()` |
| `retry: (failureCount, error) => boolean` | `retry: RetryPolicy.when((failureCount, error) => ...)` |
| `retryDelay: (failureCount, error) => number` | `retryDelay: (failureCount, error) => Duration` |
| `retryOnMount` | `retryOnMount` |
| `refetchOnMount: true`(기본값), `false`, `'always'` | `refetchOnMount: RefetchMode.ifStale`(기본값), `.never`, `.always` |
| `refetchOnWindowFocus` | `RefetchMode` 타입의 `refetchOnFocus`. 포커스는 앱이 포그라운드로 돌아오는 것을 뜻해요. |
| `refetchOnReconnect` | `RefetchMode` 타입의 `refetchOnReconnect` |
| `refetchInterval: 10000` | `refetchInterval: Duration(seconds: 10)` |
| `false`를 반환해 폴링을 멈추는 `refetchInterval: (query) => ...` | `refetchInterval`과 `refetchWhile: (result) => ...`. `refetchWhile`이 `false`를 반환하는 동안 폴링이 멈춰요. |
| `refetchIntervalInBackground` | `refetchIntervalInBackground` |
| `networkMode: 'online'`(기본값), `'always'`, `'offlineFirst'` | `networkMode: NetworkMode.online`(기본값), `.always`, `.offlineFirst` |
| `structuralSharing`, `meta` | `structuralSharing`, `meta` |

Fuery 옵션은 값을 받아요. `staleTime: (query) => ...`처럼 TanStack Query가 쿼리에서 계산하는 옵션은, 옵션이 의존하는 값을 받아 정의를 만드는 함수로 바꾸세요. 모든 옵션과 기본값은 [쿼리 옵션](../reference/query-options/)에 있어요.

## 쿼리를 끄고 데이터를 먼저 보여주기

| TanStack Query | Fuery |
|---|---|
| `enabled: false` | `enabled: false`. `refetch()`는 그래도 데이터를 가져와요. |
| `queryFn: skipToken` | `enabled: false` |
| `placeholderData: keepPreviousData` | `placeholderData: keepPreviousData` |
| `placeholderData: (previousData, previousQuery) => ...` | `placeholderData: (previousData, client) => ...` |
| `initialData`, `initialDataUpdatedAt` | `initialData`, `initialDataUpdatedAt` |
| `select: (data) => ...` | 옵션이 없어요. `QuerySelector`가 결과에서 선택한 값으로 빌드하고, 그 값이 바뀔 때만 다시 빌드해요. |
| `notifyOnChangeProps` | 빌더의 `buildWhen`, 또는 셀렉터 위젯 |

`keepPreviousData`는 쿼리를 만드는 함수의 반환 타입처럼 주변 코드에서 데이터 타입을 얻어요. [이전 페이지를 화면에 유지하기](../guides/queries/#이전-페이지를-화면에-유지하기)를 참고하세요.

## 캐시 읽고 업데이트하기

| TanStack Query | Fuery |
|---|---|
| `getQueryData(['todos'])` | `client.getData(todosQuery)`, 또는 키로 읽는 `client.getQueryData<List<Todo>>(['todos'])` |
| `setQueryData(['todos'], todos)` | `client.setData(todosQuery, todos)`, 또는 키로 쓰는 `setQueryData` |
| `setQueryData(['todos'], (old) => ...)` | `client.updateData(todosQuery, (old) => ...)`, 또는 키로 업데이트하는 `updateQueryData` |
| `getQueriesData(filters)` | `getQueriesData<Todo>(queryKey: ...)` |
| `setQueriesData(filters, updater)` | `updateQueriesData((List<Post> posts) => ..., queryKey: ...)` |
| `getQueryState(queryKey)` | `getQueryState(queryKey)` |
| `invalidateQueries({ queryKey, exact, refetchType })` | `invalidateQueries(queryKey: ..., exact: ..., refetchType: RefetchType.active)` |
| `refetchQueries`, `cancelQueries`, `resetQueries`, `removeQueries`, `isFetching`, `isMutating` | 이름은 같고, 이름 있는 인수를 받아요. |
| 쿼리 필터 `queryKey`, `exact`, `type`, `stale`, `predicate` | 같은 필터. `type`은 `QueryTypeFilter.active`, `.inactive`, `.all`을 받아요. |
| `getQueryCache()`, `getMutationCache()` | `client.queryCache`, `client.mutationCache`. 둘 다 읽기 전용이에요. 캐시는 클라이언트로 바꾸세요. |
| `queryCache.subscribe(...)` | `client.watch((client) => ...)`. 클라이언트에서 계산한 값의 `Stream`이에요. |
| `clear()` | `clear()`. 기기에 저장한 데이터도 삭제해요. |
| `notifyManager.batch(...)` | `notifyManager.batch(...)` |

`getData`, `setData`, `updateData`는 정의에서 키와 데이터 타입을 얻어서 캐스팅할 필요가 없어요. [캐시 읽고 업데이트하기](../guides/query-client/)를 참고하세요.

## 위젯 밖에서 가져오기

| TanStack Query | Fuery |
|---|---|
| `queryClient.query(options)`, `fetchQuery(options)` | `client.query(todosQuery)` |
| `prefetchQuery(options)` | `client.query(todosQuery).ignore()` |
| `ensureQueryData(options)` | 쿼리에 `staleTime: staticStaleTime`을 설정한 `client.query(query)` |
| `queryClient.infiniteQuery(options)`, `fetchInfiniteQuery`, `prefetchInfiniteQuery` | `client.infiniteQuery(postsQuery)` |
| 이 호출에 넘기는 `pages: 3` | `InfiniteQuery`의 `pages: 3` |

`client.query`는 캐시된 데이터가 fresh 상태면 그 데이터를 반환하고, 아니면 데이터를 가져와요. 쿼리나 클라이언트의 기본값이 `retry`를 설정할 때만 재시도해요. [위젯 밖에서 가져오기](../guides/query-client/#위젯-밖에서-가져오기)를 참고하세요.

## 페이지 불러오기

| TanStack Query | Fuery |
|---|---|
| `useInfiniteQuery({ ... })` | `InfiniteQueryBuilder(query: ..., builder: ...)`, 또는 `fuery_hooks`의 `useInfiniteQuery(query)` |
| `infiniteQueryOptions({ ... })` | `InfiniteQuery(...)` |
| `queryFn: ({ pageParam }) => ...` | `queryFn: (context) => ...`. 페이지 파라미터는 `context.pageParam`으로 읽어요. |
| `initialPageParam` | `initialPageParam`. 페이지 파라미터의 타입도 정해요. |
| `getNextPageParam: (lastPage, allPages, lastPageParam, allPageParams) => ...` | `getNextPageParam: (data) => ...`. `data.lastPage`, `data.pages`, `data.lastPageParam`, `data.pageParams`가 있어요. |
| `getPreviousPageParam: (firstPage, allPages, firstPageParam, allPageParams) => ...` | `getPreviousPageParam: (data) => ...`. `data.firstPage`와 `data.firstPageParam`이 있어요. |
| 다음 페이지가 없을 때 `undefined`나 `null` | `null` |
| `maxPages` | `maxPages` |
| `data.pages`, `data.pageParams` | `state.pages`와 `state.data?.pageParams` |
| `fetchNextPage`, `fetchPreviousPage`, `hasNextPage`, `hasPreviousPage` | 같은 이름 |
| `isFetchingNextPage`, `isFetchingPreviousPage`, `isFetchNextPageError`, `isFetchPreviousPageError` | 같은 이름 |
| `setQueryData(key, (data) => ({ ...data, pages: ... }))` | `client.updateData(postsQuery, (data) => data?.mapPages(...))` |

```tsx title="TanStack Query"
function Feed() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey: ['posts'],
      queryFn: ({ pageParam }) => api.getPosts(pageParam),
      initialPageParam: 1,
      getNextPageParam: (lastPage, allPages, lastPageParam) =>
        lastPage.hasMore ? lastPageParam + 1 : undefined,
    })

  return (
    <>
      {data?.pages.map((page) =>
        page.posts.map((post) => <PostRow key={post.id} post={post} />),
      )}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          Load more
        </button>
      )}
    </>
  )
}
```

```dart title="Fuery"
final postsQuery = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);

class Feed extends StatelessWidget {
  const Feed({super.key});

  @override
  Widget build(BuildContext context) {
    return InfiniteQueryBuilder(
      query: postsQuery,
      builder: (context, state) => ListView(
        children: [
          for (final page in state.pages) ...page.posts.map(PostTile.new),
          if (state.hasNextPage)
            TextButton(
              onPressed: state.isFetchingNextPage ? null : state.fetchNextPage,
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}
```

커서처럼 첫 페이지 파라미터가 `null`이면 타입을 선언해야 해요. [커서 기반 페이지](../guides/infinite-queries/#커서-기반-페이지)를 참고하세요.

## 데이터 바꾸기

| TanStack Query | Fuery |
|---|---|
| `useMutation({ ... })`, `mutationOptions({ ... })` | `Mutation(...)` 정의. `mutationFn`의 매개변수에 타입을 적으면 나머지 타입은 Dart가 추론해요. |
| `mutationFn: (variables, context) => ...` | `mutationFn: (int id) => ...`. 아무것도 받지 않는 뮤테이션은 `NoVariablesMutation`이에요. |
| `mutation.mutate(variables)` | 모든 위젯에서 `deleteTodo.mutate(id, context.queryClient)`, 또는 `MutationBuilder`나 `useMutation`의 결과에서 `state.mutate(id)` |
| `mutate(variables, { onSuccess, onError, onSettled })` | `MutationBuilder`나 `useMutation`의 결과에서 `state.mutate(variables, MutateOptions(onSuccess: ...))` |
| `mutateAsync(variables)` | 정의나 결과에서 `mutateAsync(variables)` |
| `reset()` | `reset()` |
| `onMutate: (variables, context) => ...` | `onMutate: (variables, client) => ...` |
| `onSuccess: (data, variables, onMutateResult, context) => ...` | `onSuccess: (data, variables, context, client) => ...` |
| `onError: (error, variables, onMutateResult, context) => ...` | `onError: (error, variables, context, client) => ...` |
| `onSettled: (data, error, variables, onMutateResult, context) => ...` | `onSettled: (data, error, variables, context, client) => ...` |
| `retry`(기본값: `0`) | `retry`(기본값: `RetryPolicy.never()`) |
| `scope: { id: 'drafts' }` | `scope: MutationScope('drafts')` |
| `mutationKey`, `gcTime`, `retryDelay`, `networkMode`, `meta` | 같은 이름 |
| `status`, `isIdle`, `isPending`, `isSuccess`, `isError`, `isPaused` | 같은 이름. `status`는 `MutationStatus`예요. |
| `data`, `error`, `variables`, `context`, `submittedAt`, `failureCount`, `failureReason` | 같은 이름 |

콜백 인수 두 개는 이름이 달라요. Fuery의 `context`는 `onMutate`가 반환한 값이에요. TanStack Query v5는 이 값을 `onMutateResult`라고 부르고, 이전 v5 릴리스는 `context`라고 불러요. TanStack Query가 `context.client`로 넘기는 클라이언트는 Fuery에서 마지막 인수 `client`로 와요.

낙관적 업데이트의 단계는 같아요. 다시 가져오기를 취소하고, 새 데이터를 쓰고, 이전 데이터를 반환하고, 에러가 나면 롤백하고, 뮤테이션이 끝나면 무효화해요.

```tsx title="TanStack Query"
function DeleteTodoButton({ todo }: { todo: Todo }) {
  const deleteTodo = useMutation({
    mutationKey: ['todos', 'delete'],
    mutationFn: (id: number) => api.deleteTodo(id),
    onMutate: async (id, context) => {
      await context.client.cancelQueries({ queryKey: ['todos'] })
      const previous = context.client.getQueryData<Todo[]>(['todos'])
      context.client.setQueryData<Todo[]>(['todos'], (todos) =>
        todos?.filter((item) => item.id !== id),
      )
      return previous
    },
    onError: (error, id, previous, context) => {
      if (previous) context.client.setQueryData(['todos'], previous)
    },
    onSettled: (data, error, id, previous, context) =>
      context.client.invalidateQueries({ queryKey: ['todos'] }),
  })

  return <button onClick={() => deleteTodo.mutate(todo.id)}>Delete</button>
}
```

```dart title="Fuery"
final deleteTodo = Mutation(
  mutationKey: const ['todos', 'delete'],
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id, client) async {
    await client.cancelQueries(queryKey: ['todos']);
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
  onSettled: (data, error, id, previous, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);

class DeleteTodoButton extends StatelessWidget {
  const DeleteTodoButton(this.todo, {super.key});

  final Todo todo;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => deleteTodo.mutate(todo.id, context.queryClient),
      child: const Text('Delete'),
    );
  }
}
```

뮤테이션을 실행하고, 보여주고, 재시도하는 방법은 [뮤테이션](../guides/mutations/)에 있어요.

## 어느 화면에서나 뮤테이션과 가져오기 지켜보기

| TanStack Query | Fuery |
|---|---|
| `useMutationState({ filters: { mutationKey } })` | `MutationStateBuilder(mutation: deleteTodo, builder: (context, runs) => ...)`, 또는 `fuery_hooks`의 `useMutationState(deleteTodo)`. 둘 다 정의의 `mutationKey`로 실행(`mutate` 호출 한 번)을 찾아요. |
| `useMutationState({ filters: { status: 'pending' } })` | `MutationStateBuilder(mutation: const MutationFilters(status: MutationStatus.pending), ...)` |
| `useMutationState`의 `select` | `MutationStateSelector(mutation: ..., selector: (runs) => ..., builder: ...)`. 실행에서 계산한 값이 바뀔 때만 다시 빌드해요. |
| `useIsMutating()` | `MutationStateSelector(mutation: const MutationFilters(), selector: (runs) => runs.any((run) => run.isPending), ...)` |
| `useIsFetching()` | `StreamBuilder`로 보여주는 `client.watch((client) => client.isFetching() > 0)` |

`MutationStateListener`는 실패할 때마다 스낵바를 띄우는 것처럼, 바뀌는 실행마다 사이드 이펙트를 실행해요. [뮤테이션의 모든 실행 보여주기](../guides/mutations/#뮤테이션의-모든-실행-보여주기)를 참고하세요.

## 여러 쿼리 보여주기

| TanStack Query | Fuery |
|---|---|
| `useQueries({ queries: [...] })` | `QueriesBuilder(queries: [...], builder: (context, results) => ...)`, 또는 `fuery_hooks`의 `useQueries([...])` |
| `useQueries({ queries, combine })` | `QueriesSelector(queries: [...], selector: (results) => ..., builder: ...)` |

id마다 쿼리가 하나씩 있는 경우처럼, 한 리스트에 담긴 쿼리는 데이터 타입이 같아요. 타입이 다른 쿼리는 `QueryBuilder`를 중첩하거나 쿼리마다 `useQuery`를 한 번씩 호출하세요. [여러 쿼리 함께 보여주기](../guides/widgets/#여러-쿼리-함께-보여주기)를 참고하세요.

## 모든 실패를 한곳에서 보고하기

| TanStack Query | Fuery |
|---|---|
| `new QueryCache({ onSuccess, onError, onSettled })` | `QueryCache(config: QueryCacheConfig(onSuccess: ..., onError: ..., onSettled: ...))` |
| `new MutationCache({ onMutate, onSuccess, onError, onSettled })` | `MutationCache(config: MutationCacheConfig(...))` |
| `query` 인수 | `query`, 캐시 항목(`CachedQuery`) |
| `mutation` 인수 | `mutation`, 실행(`AnyCachedMutation`). 마지막 인수로 와요. |
| `isCancelledError(error)` | `error is CancelledError`. 가져오기가 취소되면 `QueryCacheConfig`의 콜백은 하나도 호출되지 않아요. |

두 캐시를 `QueryClient` 생성자에 넘기세요. [모든 실패를 한곳에서 보고하기](../guides/client-setup/#모든-실패를-한곳에서-보고하기)를 참고하세요.

## 앱을 다시 시작해도 데이터 유지하기

| TanStack Query | Fuery |
|---|---|
| `createSyncStoragePersister`나 `createAsyncStoragePersister`를 사용하는 `PersistQueryClientProvider` | `QueryClient(storage: ...)`와, 원하는 키-값 스토리지에 맞춰 직접 작성한 `QueryStorage` |
| `experimental_createQueryPersister`와 `persister` 옵션 | 쿼리의 `persist: QueryPersist(toJson: ..., fromJson: ...)`, 무한 쿼리의 `InfiniteQueryPersist` |
| `maxAge`(기본값: 24시간) | 클라이언트의 `persistMaxAge`(기본값: 1일), 또는 `QueryPersist`의 `maxAge` |
| `buster` | `QueryPersist`의 `version` |
| 멈춘 뮤테이션: `mutationFn`을 담은 `setMutationDefaults`, 그다음 `resumePausedMutations()` | 뮤테이션의 `persist: MutationPersist(...)`, 그리고 앱을 시작할 때 `client.restore(mutations: [...])` |
| `useIsRestoring()` | 훅이 없어요. `runApp` 전에 `await client.restore()`를 호출하면 첫 프레임에 저장된 데이터를 보여줘요. |

Fuery는 `persist`를 설정한 쿼리와 뮤테이션만 저장해요. [캐시를 기기에 저장하기](../guides/persistence/)를 참고하세요.

## 캐시 살펴보기

| TanStack Query | Fuery |
|---|---|
| `@tanstack/react-query-devtools`의 `ReactQueryDevtools` | `fuery`의 `FueryDevtools(child: ...)`. `MaterialApp`의 `builder`에 넣어요. |
| `initialIsOpen` | `initiallyOpen` |
| `buttonPosition` | `Alignment` 타입의 `buttonAlignment` |
| `client` | `client` |
| `onClose`를 받는 `ReactQueryDevtoolsPanel` | `FueryDevtoolsPanel(onClose: ...)` |
| `process.env.NODE_ENV === 'development'`일 때만 포함돼요. | 디버그 빌드와 프로파일 빌드에서 보여요. `enabled`의 기본값은 `!kReleaseMode`예요. |

패널은 앱 안에서 실행돼요. 그래서 기기에서도 동작해요. [개발자 도구](../guides/devtools/)를 참고하세요.

## 응답 스트리밍하기

| TanStack Query | Fuery |
|---|---|
| `experimental_streamedQuery({ streamFn, reducer, initialValue })` | `streamedQuery(stream: ..., combine: ..., initialValue: ...)`. `combine`과 `initialValue`는 필수예요. |
| `refetchMode: 'reset'`, `'append'`, `'replace'` | `refetchMode: StreamRefetchMode.reset`, `.append`, `.replace` |

`stream`은 Dart의 `Stream`을 반환해요. [스트림 쿼리](../guides/streaming/)를 참고하세요.

## 대응하는 기능이 없는 것

| TanStack Query | Fuery에서는 |
|---|---|
| `useSuspenseQuery`, `useSuspenseInfiniteQuery`, `useSuspenseQueries` | Suspense가 없어요. 빌더가 결과의 `pending` 상태를 보여줘요. |
| `throwOnError` 옵션, `QueryErrorResetBoundary`, `useQueryErrorResetBoundary` | 에러 바운더리가 없어요. 빌더가 결과의 에러를 보여주고, `refetch()`로 다시 시도해요. |
| `dehydrate`, `hydrate`, `HydrationBoundary` | 앱에 데이터를 넘겨주는 서버 렌더링이 없어요. `initialData`, `setData`, [기기에 저장한 데이터](../guides/persistence/)로 데이터를 채워서 시작하세요. |
| `broadcastQueryClient` | 대응하는 기능이 없어요. |
| `queryKeyHashFn` | 옵션이 없어요. Fuery는 키를 JSON 형태로 비교해요. |
| `enabled: (query) => ...`처럼 쿼리에서 계산하는 옵션 값 | 값만 받아요. 정의가 의존하는 값으로 정의를 만드세요. |

## Flutter에서 달라지는 점

모델은 그대로예요. 화면에서 모델을 사용하는 방식은 Flutter의 관례를 따라요.

### 정의는 build 밖에, 렌더링은 위젯이

`Query`와 `Mutation`은 정의예요. 키, 함수, 옵션으로 이뤄져요. 데이터를 담지 않고 아무것도 시작하지 않아요. 위의 `todosQuery`, `deleteTodo`처럼 최상위 값으로 두거나, id를 받는 함수 안에 두세요.

위젯은 `StreamBuilder`가 스트림을 렌더링하듯 정의를 렌더링해요.

- `QueryBuilder` 같은 빌더는 결과로 UI를 다시 빌드해요.
- `QueryListener`나 `MutationStateListener` 같은 리스너는 스낵바나 화면 이동 같은 사이드 이펙트를 실행해요. 리스너는 빌드하는 동안이 아니라 항상 상태가 바뀐 뒤에 실행돼요.
- `QuerySelector` 같은 셀렉터는 선택한 값이 바뀔 때만 다시 빌드해요.

위젯마다 마운트된 동안 옵저버를 유지해요. 그래서 서버 데이터를 보여주는 화면도 `StatelessWidget` 그대로예요. 모든 위젯은 [위젯](../guides/widgets/)에 있어요.

### 정의에서 뮤테이션 실행하기

어느 위젯에서든 `deleteTodo.mutate(todo.id, context.queryClient)`처럼 정의에서 뮤테이션을 실행해요. 클라이언트는 `context.queryClient`로 넘겨요. `StatelessWidget`에는 이를 위한 훅도 빌더도 필요 없어요.

- 실행은 위젯이 아니라 클라이언트의 캐시에 속해요. 그래서 위젯이 언마운트된 뒤에도 계속돼요.
- `MutationStateSelector`와 `MutationStateBuilder`는 어느 화면에서나 실행의 진행 상황을 보여줘요. 두 위젯은 `mutationKey`로 실행을 찾아요.
- 폼을 닫는 것처럼 호출 한 번에 반응하려면 `try` 안에서 `mutateAsync`를 `await`로 기다린 뒤 `context.mounted`를 확인하세요. [호출 한 번이 성공한 뒤 처리하기](../guides/mutations/#호출-한-번이-성공한-뒤-처리하기)를 참고하세요.
- `MutationBuilder`는 자기 옵저버를 따로 유지해요. 자기가 시작한 실행만 보여주는 위젯에 사용하세요.

### 별도 패키지로 제공하는 훅

`fuery`는 Dart와 Flutter에만 의존해요. 훅을 사용하려면 `flutter_hooks`와 [`fuery_hooks`](../guides/hooks/)를 추가하세요. `fuery_hooks`의 `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, `useMutationState`, `useQueryClient`는 `HookWidget`에서 같은 정의를 읽어요. 훅은 모두 옵션 객체가 아니라 `useQuery(todosQuery)`처럼 정의를 받아요.

사이드 이펙트는 변화 훅에 두세요. `useOnQueryChange`, `useOnMutationChange`, `useOnMutationStateChange`가 변화 훅이에요.

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

변화 훅은 빌드 밖에서, 상태가 바뀐 뒤에 리스너를 실행해요. `flutter_hooks`는 `useEffect` 콜백을 빌드하는 동안 실행해요. 빌드하는 동안에는 스낵바를 띄우거나 화면을 이동하면 실패해요. [useEffect에서 스낵바와 화면 이동](../guides/hooks/#useeffect에서-스낵바와-화면-이동)을 참고하세요.

### 포커스와 재연결 때 다시 가져오기

- 포커스는 앱이 포그라운드에 있다는 뜻이에요(`AppLifecycleState.resumed`). Fuery 위젯, 훅, `FueryProvider`가 앱 생명주기를 연결해서 `refetchOnFocus`는 따로 설정하지 않아도 돼요. 쿼리를 Bloc에서만 사용하는 앱은 `FueryBinding.ensureInitialized()`를 한 번 호출해요.
- Fuery는 소스가 다르게 알리기 전까지 기기를 온라인으로 봐요. `connectivity_plus` 같은 소스를 `onlineManager.setEventListener`로 연결하세요. 그러면 쿼리는 오프라인인 동안 멈추고, 네트워크가 다시 연결되면 다시 가져와요.
- 쿼리에 `refetchIntervalInBackground`를 설정하지 않으면, 앱이 백그라운드에 있는 동안 폴링이 멈춰요.

연결 상태 소스를 설정하는 방법은 [다시 가져오기와 오프라인](../guides/lifecycle/)에 있어요.

### 코드 생성 없이, 타입은 함수가 정해요

- `api.getTodos()`가 `Future<List<Todo>>`를 반환해서 위의 `todosQuery`는 `Query<List<Todo>>`예요. 타입 인수를 적지 않아도 위젯, 결과, 콜백까지 그 타입이 이어져요.
- 뮤테이션은 `(int id) => api.deleteTodo(id)`처럼 `mutationFn`의 매개변수와 `onMutate`의 반환값에서 타입을 얻어요.
- 타입을 적어야 하는 경우는 두 가지예요. `getQueryData<List<Todo>>(['todos'])`처럼 키만으로 읽거나 쓸 때, 그리고 첫 페이지 파라미터가 `null`인 무한 쿼리예요.
- 생성되는 코드가 없어요. `build_runner` 단계도, 어노테이션도 없어요.
