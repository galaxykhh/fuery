---
title: Coming from TanStack Query
description: "The Fuery name for each TanStack Query (React Query) v5 concept in a Flutter app: the client, query keys, useQuery options and results, mutations, infinite queries, persistence, and devtools."
head:
  - tag: title
    content: Coming from TanStack Query (React Query) to Flutter | Fuery
---

This page gives the Fuery name for each concept of [TanStack Query](https://tanstack.com/query) v5, formerly React Query. It is for React developers who know TanStack Query and want the same caching model in a Flutter app.

Fuery's caching and refetching model is inspired by TanStack Query, so most of what you know carries over:

- A query key names a cache entry. Every screen that uses the key shares that cache entry and its request.
- Data is fresh for `staleTime`, then stale. Stale data stays on screen while Fuery refetches it in the background.
- Data that nothing uses leaves memory after `gcTime`.
- `invalidateQueries`, `setQueryData`, `onMutate`, `fetchNextPage`, and most result fields keep their names.
- The defaults carry over: `staleTime` zero, `gcTime` 5 minutes, and 3 retries with backoff for a query on screen.

How a screen uses a query follows Flutter's conventions instead. [What's different in Flutter](#whats-different-in-flutter) covers that part.

## Names that change everywhere

Each table below puts the TanStack Query name on the left and the Fuery name on the right. Four changes run through every table:

- Options are named arguments of a definition, such as `Query(queryKey: ..., queryFn: ...)`, not an object.
- Durations are `Duration`s, not milliseconds. Timestamps, such as `dataUpdatedAt`, stay milliseconds since epoch.
- Missing data is `null`, not `undefined`.
- String values are enums. `'always'` becomes `RefetchMode.always`, and `'pending'` becomes `QueryStatus.pending`.

## Setting up the client

| TanStack Query | Fuery |
|---|---|
| `new QueryClient({ defaultOptions })` | `QueryClient(defaultOptions: DefaultOptions(...))`, with `QueryDefaults` for `queries` and `MutationDefaults` for `mutations` |
| `<QueryClientProvider client={queryClient}>` | Not needed. Assign `Fuery.client` in `main`. `FueryProvider(client: ..., child: ...)` gives a subtree a client of its own. |
| `useQueryClient()` | `context.queryClient` in any widget, or `useQueryClient()` from `fuery_hooks` |
| `mount()`, `unmount()` | `mount()`, `unmount()`. Assigning `Fuery.client` and `FueryProvider` call them for you. |
| `setQueryDefaults`, `getQueryDefaults`, `setMutationDefaults`, `getMutationDefaults` | The same names |

Each pair of snippets shows the same code twice: TanStack Query first, then Fuery. `api`, `Todo`, and widgets such as `TodoList` stand for your own code.

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

An app that configures nothing still works: Fuery creates `Fuery.client` on first use. See [Setting up the client](../guides/client-setup/).

## Defining and showing a query

| TanStack Query | Fuery |
|---|---|
| `queryKey: ['todos', id]` | `queryKey: ['todos', id]`, a `List<Object?>`. Fuery compares keys by value, and filters match keys by prefix. |
| `queryKey: ['todos', { status, page }]` | `queryKey: ['todos', {'status': status, 'page': page}]`. The order of map entries doesn't matter. An object in a key needs a `toJson()` method. |
| `queryFn: ({ queryKey, signal, meta, client }) => ...` | `queryFn: (context) => ...`, with `context.queryKey`, `context.signal`, `context.meta`, and `context.client` |
| The data can't be `undefined` | A query function returns a non-nullable type, such as `Future<List<Todo>>` |
| `fetch(url, { signal })` | `context.signal.onAbort(...)`, connected to your HTTP client's cancellation. See [Cancelling a request](../guides/queries/#cancelling-a-request). |
| `queryOptions({ ... })` | `Query(...)`, a definition that widgets, hooks, and the client all take |
| `useQuery({ ... })` | `QueryBuilder(query: ..., builder: ...)`, or `useQuery(query)` from `fuery_hooks` |

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

`todosQuery` holds no data and starts nothing. `QueryBuilder` fetches when it mounts, and rebuilds with each new result. [Queries](../guides/queries/) covers keys and options.

## Reading the result

| TanStack Query | Fuery |
|---|---|
| `status`: `'pending'`, `'error'`, `'success'` | `status`: `QueryStatus.pending`, `.error`, `.success` |
| `fetchStatus`: `'fetching'`, `'paused'`, `'idle'` | `fetchStatus`: `FetchStatus.fetching`, `.paused`, `.idle` |
| `data`, `error` | `data`, `error` |
| `isPending`, `isSuccess`, `isError`, `isLoading`, `isFetching`, `isRefetching`, `isPaused` | The same names |
| `isLoadingError`, `isRefetchError`, `isPlaceholderData`, `isStale`, `isFetched`, `isFetchedAfterMount`, `isEnabled` | The same names |
| `dataUpdatedAt`, `errorUpdatedAt`, `errorUpdateCount`, `failureCount`, `failureReason` | The same names |
| `refetch({ cancelRefetch, throwOnError })` | `refetch(cancelRefetch: ..., throwOnError: ...)`, which returns a `Future<QueryResult>` |

Fuery adds `hasData`, which is `true` when `data` isn't `null`. [Query results](../reference/query-results/) lists every field.

## Setting freshness, retries, and refetches

| TanStack Query | Fuery |
|---|---|
| `staleTime` (default: `0`) | `staleTime`, a `Duration` (default: zero) |
| `staleTime: Infinity` | `staleTime: infiniteDuration` |
| `staleTime: 'static'` | `staleTime: staticStaleTime` |
| `gcTime` (default: 5 minutes) | `gcTime`, a `Duration` (default: 5 minutes) |
| `retry: 3` (default), `false`, `true` | `retry: RetryPolicy.count(3)` (default), `RetryPolicy.never()`, `RetryPolicy.always()` |
| `retry: (failureCount, error) => boolean` | `retry: RetryPolicy.when((failureCount, error) => ...)` |
| `retryDelay: (failureCount, error) => number` | `retryDelay: (failureCount, error) => Duration` |
| `retryOnMount` | `retryOnMount` |
| `refetchOnMount: true` (default), `false`, `'always'` | `refetchOnMount: RefetchMode.ifStale` (default), `.never`, `.always` |
| `refetchOnWindowFocus` | `refetchOnFocus`, a `RefetchMode`. Focus means the app returns to the foreground. |
| `refetchOnReconnect` | `refetchOnReconnect`, a `RefetchMode` |
| `refetchInterval: 10000` | `refetchInterval: Duration(seconds: 10)` |
| `refetchInterval: (query) => ...`, returning `false` to stop polling | `refetchInterval`, plus `refetchWhile: (result) => ...`. Polling stops while it returns `false`. |
| `refetchIntervalInBackground` | `refetchIntervalInBackground` |
| `networkMode: 'online'` (default), `'always'`, `'offlineFirst'` | `networkMode: NetworkMode.online` (default), `.always`, `.offlineFirst` |
| `structuralSharing`, `meta` | `structuralSharing`, `meta` |

Fuery options take values. For an option that TanStack Query computes from the query, such as `staleTime: (query) => ...`, build the definition in a function from the values it depends on. [Query options](../reference/query-options/) lists every option with its default.

## Turning a query off and showing data early

| TanStack Query | Fuery |
|---|---|
| `enabled: false` | `enabled: false`. `refetch()` still fetches. |
| `queryFn: skipToken` | `enabled: false` |
| `placeholderData: keepPreviousData` | `placeholderData: keepPreviousData` |
| `placeholderData: (previousData, previousQuery) => ...` | `placeholderData: (previousData, client) => ...` |
| `initialData`, `initialDataUpdatedAt` | `initialData`, `initialDataUpdatedAt` |
| `select: (data) => ...` | No option. `QuerySelector` builds from a value it selects from the result, and rebuilds only when that value changes. |
| `notifyOnChangeProps` | `buildWhen` on a builder, or a selector widget |

`keepPreviousData` takes the data type from its surroundings, such as the return type of a function that builds the query. See [Keeping the previous page on screen](../guides/queries/#keeping-the-previous-page-on-screen).

## Reading and updating the cache

| TanStack Query | Fuery |
|---|---|
| `getQueryData(['todos'])` | `client.getData(todosQuery)`, or `client.getQueryData<List<Todo>>(['todos'])` by key |
| `setQueryData(['todos'], todos)` | `client.setData(todosQuery, todos)`, or `setQueryData` by key |
| `setQueryData(['todos'], (old) => ...)` | `client.updateData(todosQuery, (old) => ...)`, or `updateQueryData` by key |
| `getQueriesData(filters)` | `getQueriesData<Todo>(queryKey: ...)` |
| `setQueriesData(filters, updater)` | `updateQueriesData((List<Post> posts) => ..., queryKey: ...)` |
| `getQueryState(queryKey)` | `getQueryState(queryKey)` |
| `invalidateQueries({ queryKey, exact, refetchType })` | `invalidateQueries(queryKey: ..., exact: ..., refetchType: RefetchType.active)` |
| `refetchQueries`, `cancelQueries`, `resetQueries`, `removeQueries`, `isFetching`, `isMutating` | The same names, with named arguments |
| Query filters `queryKey`, `exact`, `type`, `stale`, `predicate` | The same filters. `type` takes `QueryTypeFilter.active`, `.inactive`, or `.all`. |
| `getQueryCache()`, `getMutationCache()` | `client.queryCache`, `client.mutationCache`. Both are read-only: change the cache through the client. |
| `queryCache.subscribe(...)` | `client.watch((client) => ...)`, a `Stream` of a value computed from the client |
| `clear()` | `clear()`, which also deletes persisted data |
| `notifyManager.batch(...)` | `notifyManager.batch(...)` |

`getData`, `setData`, and `updateData` take the key and the data type from the definition, so nothing needs a cast. See [Reading and updating the cache](../guides/query-client/).

## Fetching outside widgets

| TanStack Query | Fuery |
|---|---|
| `queryClient.query(options)`, `fetchQuery(options)` | `client.query(todosQuery)` |
| `prefetchQuery(options)` | `client.query(todosQuery).ignore()` |
| `ensureQueryData(options)` | `client.query(query)`, with `staleTime: staticStaleTime` on the query |
| `queryClient.infiniteQuery(options)`, `fetchInfiniteQuery`, `prefetchInfiniteQuery` | `client.infiniteQuery(postsQuery)` |
| `pages: 3` in those calls | `pages: 3` on the `InfiniteQuery` |

`client.query` returns the cached data while it is fresh, and fetches otherwise. It retries only when the query or the client's defaults set `retry`. See [Fetching outside widgets](../guides/query-client/#fetching-outside-widgets).

## Loading pages

| TanStack Query | Fuery |
|---|---|
| `useInfiniteQuery({ ... })` | `InfiniteQueryBuilder(query: ..., builder: ...)`, or `useInfiniteQuery(query)` from `fuery_hooks` |
| `infiniteQueryOptions({ ... })` | `InfiniteQuery(...)` |
| `queryFn: ({ pageParam }) => ...` | `queryFn: (context) => ...`, with `context.pageParam` |
| `initialPageParam` | `initialPageParam`, which also sets the param type |
| `getNextPageParam: (lastPage, allPages, lastPageParam, allPageParams) => ...` | `getNextPageParam: (data) => ...`, with `data.lastPage`, `data.pages`, `data.lastPageParam`, and `data.pageParams` |
| `getPreviousPageParam: (firstPage, allPages, firstPageParam, allPageParams) => ...` | `getPreviousPageParam: (data) => ...`, with `data.firstPage` and `data.firstPageParam` |
| `undefined` or `null` when there is no next page | `null` |
| `maxPages` | `maxPages` |
| `data.pages`, `data.pageParams` | `state.pages`, and `state.data?.pageParams` |
| `fetchNextPage`, `fetchPreviousPage`, `hasNextPage`, `hasPreviousPage` | The same names |
| `isFetchingNextPage`, `isFetchingPreviousPage`, `isFetchNextPageError`, `isFetchPreviousPageError` | The same names |
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

A first page param of `null`, as with cursors, needs a declared type. See [Cursor-based pages](../guides/infinite-queries/#cursor-based-pages).

## Changing data

| TanStack Query | Fuery |
|---|---|
| `useMutation({ ... })`, `mutationOptions({ ... })` | `Mutation(...)`, a definition. Type the parameter of `mutationFn`, and Dart infers the other types. |
| `mutationFn: (variables, context) => ...` | `mutationFn: (int id) => ...`. A mutation that takes nothing is a `NoVariablesMutation`. |
| `mutation.mutate(variables)` | `deleteTodo.mutate(id, context.queryClient)` from any widget, or `state.mutate(id)` on the result of a `MutationBuilder` or `useMutation` |
| `mutate(variables, { onSuccess, onError, onSettled })` | `state.mutate(variables, MutateOptions(onSuccess: ...))` on the result of a `MutationBuilder` or `useMutation` |
| `mutateAsync(variables)` | `mutateAsync(variables)`, on the definition or on a result |
| `reset()` | `reset()` |
| `onMutate: (variables, context) => ...` | `onMutate: (variables, client) => ...` |
| `onSuccess: (data, variables, onMutateResult, context) => ...` | `onSuccess: (data, variables, context, client) => ...` |
| `onError: (error, variables, onMutateResult, context) => ...` | `onError: (error, variables, context, client) => ...` |
| `onSettled: (data, error, variables, onMutateResult, context) => ...` | `onSettled: (data, error, variables, context, client) => ...` |
| `retry` (default: `0`) | `retry` (default: `RetryPolicy.never()`) |
| `scope: { id: 'drafts' }` | `scope: MutationScope('drafts')` |
| `mutationKey`, `gcTime`, `retryDelay`, `networkMode`, `meta` | The same names |
| `status`, `isIdle`, `isPending`, `isSuccess`, `isError`, `isPaused` | The same names. `status` is a `MutationStatus`. |
| `data`, `error`, `variables`, `context`, `submittedAt`, `failureCount`, `failureReason` | The same names |

Two callback arguments have other names. Fuery's `context` is the value that `onMutate` returned. TanStack Query v5 calls it `onMutateResult`, and earlier v5 releases call it `context`. The client comes last, as `client`, where TanStack Query passes `context.client`.

An optimistic update keeps its steps: cancel refetches, write the new data, return the old data, roll back on error, and invalidate when the mutation settles.

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

[Mutations](../guides/mutations/) covers running, showing, and retrying mutations.

## Following mutations and fetches from any screen

| TanStack Query | Fuery |
|---|---|
| `useMutationState({ filters: { mutationKey } })` | `MutationStateBuilder(mutation: deleteTodo, builder: (context, runs) => ...)`, or `useMutationState(deleteTodo)` from `fuery_hooks`. Both find the runs by the definition's `mutationKey`. |
| `useMutationState({ filters: { status: 'pending' } })` | `MutationStateBuilder(mutation: const MutationFilters(status: MutationStatus.pending), ...)` |
| `select` of `useMutationState` | `MutationStateSelector(mutation: ..., selector: (runs) => ..., builder: ...)`, which rebuilds only when the value computed from the runs changes |
| `useIsMutating()` | `MutationStateSelector(mutation: const MutationFilters(), selector: (runs) => runs.any((run) => run.isPending), ...)` |
| `useIsFetching()` | `client.watch((client) => client.isFetching() > 0)`, shown with a `StreamBuilder` |

`MutationStateListener` runs a side effect for each run that changes, such as a snackbar for each failure. See [Showing every run of a mutation](../guides/mutations/#showing-every-run-of-a-mutation).

## Showing several queries

| TanStack Query | Fuery |
|---|---|
| `useQueries({ queries: [...] })` | `QueriesBuilder(queries: [...], builder: (context, results) => ...)`, or `useQueries([...])` from `fuery_hooks` |
| `useQueries({ queries, combine })` | `QueriesSelector(queries: [...], selector: (results) => ..., builder: ...)` |

The queries in one list share a data type, such as one query per id. For queries of different types, nest one `QueryBuilder` in another, or call `useQuery` once for each. See [Showing several queries together](../guides/widgets/#showing-several-queries-together).

## Reporting every failure in one place

| TanStack Query | Fuery |
|---|---|
| `new QueryCache({ onSuccess, onError, onSettled })` | `QueryCache(config: QueryCacheConfig(onSuccess: ..., onError: ..., onSettled: ...))` |
| `new MutationCache({ onMutate, onSuccess, onError, onSettled })` | `MutationCache(config: MutationCacheConfig(...))` |
| The `query` argument | `query`, the cache entry (`CachedQuery`) |
| The `mutation` argument | `mutation`, the run (`AnyCachedMutation`), which comes last |
| `isCancelledError(error)` | `error is CancelledError`. A cancelled fetch reaches none of the `QueryCacheConfig` callbacks. |

Pass both caches to the `QueryClient` constructor. See [Reporting every failure in one place](../guides/client-setup/#reporting-every-failure-in-one-place).

## Keeping data across restarts

| TanStack Query | Fuery |
|---|---|
| `PersistQueryClientProvider` with `createSyncStoragePersister` or `createAsyncStoragePersister` | `QueryClient(storage: ...)`, with a `QueryStorage` you write for any key-value store |
| `experimental_createQueryPersister` and the `persister` option | `persist: QueryPersist(toJson: ..., fromJson: ...)` on a query, and `InfiniteQueryPersist` on an infinite query |
| `maxAge` (default: 24 hours) | `persistMaxAge` on the client (default: 1 day), or `maxAge` on `QueryPersist` |
| `buster` | `version` on `QueryPersist` |
| Paused mutations: `setMutationDefaults` with a `mutationFn`, then `resumePausedMutations()` | `persist: MutationPersist(...)` on the mutation, then `client.restore(mutations: [...])` at startup |
| `useIsRestoring()` | No hook. `await client.restore()` before `runApp` shows the stored data on the first frame. |

Fuery stores only the queries and mutations that have `persist`. See [Persistence](../guides/persistence/).

## Inspecting the cache

| TanStack Query | Fuery |
|---|---|
| `ReactQueryDevtools` from `@tanstack/react-query-devtools` | `FueryDevtools(child: ...)` from `fuery`, in the `builder` of `MaterialApp` |
| `initialIsOpen` | `initiallyOpen` |
| `buttonPosition` | `buttonAlignment`, an `Alignment` |
| `client` | `client` |
| `ReactQueryDevtoolsPanel` with `onClose` | `FueryDevtoolsPanel(onClose: ...)` |
| Included only when `process.env.NODE_ENV === 'development'` | Shown in debug and profile builds. `enabled` defaults to `!kReleaseMode`. |

The panel runs inside the app, so it works on a device. See [Devtools](../guides/devtools/).

## Streaming a response

| TanStack Query | Fuery |
|---|---|
| `experimental_streamedQuery({ streamFn, reducer, initialValue })` | `streamedQuery(stream: ..., combine: ..., initialValue: ...)`. `combine` and `initialValue` are required. |
| `refetchMode: 'reset'`, `'append'`, `'replace'` | `refetchMode: StreamRefetchMode.reset`, `.append`, `.replace` |

`stream` returns a Dart `Stream`. See [Streamed queries](../guides/streaming/).

## What has no equivalent

| TanStack Query | In Fuery |
|---|---|
| `useSuspenseQuery`, `useSuspenseInfiniteQuery`, `useSuspenseQueries` | No Suspense. The builder shows the pending state from the result. |
| The `throwOnError` option, `QueryErrorResetBoundary`, `useQueryErrorResetBoundary` | No error boundaries. The builder shows the error from the result, and `refetch()` tries again. |
| `dehydrate`, `hydrate`, `HydrationBoundary` | No server render hands data to the app. Start with data from `initialData`, `setData`, or [persistence](../guides/persistence/). |
| `broadcastQueryClient` | No equivalent. |
| `queryKeyHashFn` | No option. Fuery compares keys by their JSON form. |
| Option values computed from the query, such as `enabled: (query) => ...` | Values only. Build the definition from the values it depends on. |

## What's different in Flutter

The model carries over. How a screen uses it follows Flutter's conventions.

### Definitions outside build, rendered by widgets

A `Query` or a `Mutation` is a definition: its key, its function, and its options. It holds no data and starts nothing. Keep it as a top-level value, as `todosQuery` and `deleteTodo` above are, or in a function that takes an id.

Widgets render definitions the way `StreamBuilder` renders a stream:

- A builder, such as `QueryBuilder`, rebuilds the UI from the result.
- A listener, such as `QueryListener` or `MutationStateListener`, runs a side effect, such as a snackbar or a navigation. It runs after the change, never during a build.
- A selector, such as `QuerySelector`, rebuilds only when a value it selects changes.

Each widget keeps an observer while it is mounted, so a screen that shows server data stays a `StatelessWidget`. [Widgets](../guides/widgets/) lists every widget.

### Running a mutation from its definition

Any widget runs a mutation from its definition, with the client from `context.queryClient`: `deleteTodo.mutate(todo.id, context.queryClient)`. A `StatelessWidget` needs no hook and no builder for it.

- The run belongs to the client's cache, not to the widget, so it goes on after the widget unmounts.
- `MutationStateSelector` and `MutationStateBuilder` show its progress on any screen. They find the run by `mutationKey`.
- To react to one call, such as closing a form, await `mutateAsync` in a `try`, then check `context.mounted`. See [Acting after one call succeeds](../guides/mutations/#acting-after-one-call-succeeds).
- `MutationBuilder` keeps an observer of its own. Use it for a widget that shows only the runs it starts.

### Hooks in a package of their own

`fuery` depends on nothing beyond Dart and Flutter. For hooks, add [`fuery_hooks`](../guides/hooks/) with `flutter_hooks`. Its `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, `useMutationState`, and `useQueryClient` read the same definitions in a `HookWidget`. Each hook takes a definition, such as `useQuery(todosQuery)`, not an options object.

Side effects go in the change hooks: `useOnQueryChange`, `useOnMutationChange`, and `useOnMutationStateChange`.

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

A change hook runs its listener after the change, outside the build. `flutter_hooks` runs a `useEffect` callback during the build, where a snackbar or a navigation fails. See [Snackbars and navigation in useEffect](../guides/hooks/#snackbars-and-navigation-in-useeffect).

### Refetching on focus and reconnect

- Focus means the app is in the foreground (`AppLifecycleState.resumed`). Fuery widgets, hooks, and `FueryProvider` connect the app lifecycle, so `refetchOnFocus` needs no setup. An app that uses queries only from blocs calls `FueryBinding.ensureInitialized()` once.
- Fuery treats the device as online until a source reports otherwise. Connect one, such as `connectivity_plus`, with `onlineManager.setEventListener`. Queries then pause while offline and refetch on reconnect.
- Polling stops while the app is in the background, unless the query sets `refetchIntervalInBackground`.

[Refetching and going offline](../guides/lifecycle/) shows the connectivity setup.

### No code generation, and types from your functions

- `todosQuery` above is a `Query<List<Todo>>`, because `api.getTodos()` returns a `Future<List<Todo>>`. Widgets, results, and callbacks carry that type without type arguments.
- A mutation takes its types from the parameter of `mutationFn`, such as `(int id) => api.deleteTodo(id)`, and from what `onMutate` returns.
- Name a type in two cases: a read or write by key alone, as in `getQueryData<List<Todo>>(['todos'])`, and an infinite query whose first page param is `null`.
- Nothing is generated. There is no `build_runner` step and no annotation.
