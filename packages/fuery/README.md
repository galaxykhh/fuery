<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

Fetch, cache, and keep server data fresh in Flutter.

Fuery fetches, caches, and keeps your server data fresh, with request deduplication, stale-while-revalidate caching, retries, pagination, and optimistic updates. Builder, listener, and consumer widgets, with `buildWhen` and `listenWhen`, turn queries into UI and side effects.

- **Built the Flutter way.** Queries are defined outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`.
- **Nothing beyond Dart and Flutter.** `fuery` depends on Flutter and `fuery_core`, and `fuery_core` only on the Dart team's `clock`, `collection`, and `meta`. Prefer hooks, a style many know from the web? [`fuery_hooks`](https://pub.dev/packages/fuery_hooks) renders the same queries with `useQuery`, in a package of its own, so only apps that choose `flutter_hooks` depend on it.
- **One idea to learn.** A query is a definition. Pass it to a widget, fetch it with the client, or read its cached data, all with the same object.
- **Drops into the app you have.** Start with one screen: a query needs no `BuildContext` and no setup, and it works in a `StatelessWidget`.
- **Runs where your code runs.** The core is pure Dart, so widgets, cubits, services, CLIs, and servers use the same queries.
- **No type arguments, no code generation.** Types come from your query and mutation functions.
- **Built for real networks.** Refetches when the app returns to the foreground, retries failed requests, and pauses while offline once you [report connectivity](#app-lifecycle-and-connectivity).
- **Devtools in the app.** Inspect the cache on a device, with no separate tooling.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)** · **[Try the demo →](https://galaxykhh.github.io/fuery/demo/)**

## Install

```bash
flutter pub add fuery
```

## Quick start

Define a query, and pass it to a widget:

```dart
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

No type arguments are needed: `todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. `QueryResult(:final data?)` matches only when there is data, so `data` is a non-null `List<Todo>` without `!`. Data comes first, so a list that fails to refresh stays on screen, and the error shows only when there is no data yet.

The query fetches when `QueryBuilder` mounts. Every widget that uses the key `['todos']` shares one cache entry and one request.

A query is only a description, so building one in `build` is fine. For a query that depends on the widget, write a function and call it there: `QueryBuilder(query: todoQuery(widget.id))`. The widget keeps one observer for it and follows the new key when `id` changes.

## Queries

```dart
Query<Todo> todoQuery(int id) => Query(
      queryKey: ['todos', id],
      queryFn: (context) => api.getTodo(id),
      staleTime: const Duration(minutes: 1),
    );
```

**Keys** identify cached data. They are lists compared by value, so `['todos', 1]` from two widgets is the same query. Maps inside keys are compared regardless of key order. A key can contain `null`, `bool`, `num`, `String`, enums, `DateTime`, lists, maps, and objects with a `toJson()` method.

Query data can't be `null`, because `null` means "no data yet". Use a non-nullable type like `Future<User>`, and throw or return an empty value when there's nothing.

Each key holds one data type. Write to it with `client.setData(todosQuery, todos)`, which takes the type from the query (see [QueryClient](#queryclient)).

**Freshness.** Data is *fresh* for `staleTime` (default: zero) and *stale* afterwards. Stale data is still shown, and it's refetched in the background when:

- a widget using it mounts (every widget, not only the first), or an observer from `observe()` gets its first listener,
- the app returns to the foreground,
- the network reconnects,
- it is invalidated.

Unused queries stay cached for `gcTime` (default: 5 minutes), so going back to a screen shows data instantly.

**Result.** The builder receives a `QueryResult`:

| Field | Meaning |
|---|---|
| `status` | `pending` (no data yet), `error`, or `success` |
| `fetchStatus` | `fetching`, `paused` (waiting for the network, or for the app to return to the foreground to retry), or `idle` |
| `data`, `error` | The latest data and error. `data` is kept when a refetch fails. |
| `isLoading` | First load: pending and fetching |
| `isRefetching` | Fetching while data is shown |
| `isLoadingError` / `isRefetchError` | Failed with no data / failed with data still shown |
| `isStale`, `isPlaceholderData`, `failureCount`, `dataUpdatedAt` | See the API docs |

**Options.**

| Option | Default | |
|---|---|---|
| `enabled` | `true` | `false` stops automatic fetching |
| `staleTime` | zero | `infiniteDuration`: fresh until invalidated. `staticStaleTime`: never stale or refetched automatically, even when invalidated. |
| `gcTime` | 5 minutes | How long unused data stays cached |
| `retry` | `RetryPolicy.count(3)` | Also `.never()`, `.always()`, `.when((count, error) => ...)` |
| `retryDelay` | 1s, 2s, 4s, … up to 30s | |
| `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect` | `RefetchMode.ifStale` | `.never` or `.always`. `refetchOnReconnect` defaults to `.never` with `NetworkMode.always`. |
| `refetchInterval` | none | Polls while a widget uses the query, counting from its latest change |
| `refetchWhile` | none | Polls only while this returns true for the latest result |
| `initialData` | none | Seeds the cache |
| `placeholderData` | none | Shown while pending, not cached. `keepPreviousData` keeps the previous key's data while a new key loads. The function also gets the client, to read other cached data. |
| `networkMode` | `NetworkMode.online` | `.always` ignores connectivity. `.offlineFirst` runs the first attempt anyway and pauses retries while offline. |
| `structuralSharing` | `true` | Keeps unchanged data identical across refetches: the whole value if nothing changed, otherwise the unchanged list items |
| `persist` | none | Stores the data on the device, see [Persistence](#persistence) |

**Polling until done.** `refetchWhile` is checked on every change, so polling stops when it returns false and resumes when it returns true again:

```dart
final job = Query(
  queryKey: ['jobs', id],
  queryFn: (_) => api.getJob(id),
  refetchInterval: const Duration(seconds: 2),
  refetchWhile: (state) => state.data?.isDone != true,
);
```

**Cancellation.** Read `context.signal` in the query function to make it cancellable. When the last widget leaves, the fetch is aborted instead of finishing in the background:

```dart
queryFn: (context) {
  final cancelToken = CancelToken();
  context.signal.onAbort(cancelToken.cancel);
  return dio
      .get('/todos', cancelToken: cancelToken)
      .then((response) => Todo.listFromJson(response.data));
},
```

## Widgets

Queries, infinite queries, and mutations each have a builder, a listener, a consumer, and a selector, a list of queries has a builder and a selector, and the runs of a mutation have a builder, a listener, and a selector:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| Several queries | `QueriesBuilder` | | | `QueriesSelector` |
| Every run of a mutation | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

Each takes a query (or a mutation) and keeps one observer for it. Pass the same definition from several widgets, and they share one cache entry and one request. The result has the actions, too: `state.refetch()`, `state.fetchNextPage()`, and `state.mutate(...)`.

How they update:

- `buildWhen(previous, current)` compares with the last built result.
- `listenWhen(previous, current)` compares with the previous result.
- Listeners are not called for the result the query already had when they mounted.

```dart
QueryBuilder(
  query: todos,
  buildWhen: (previous, current) => previous.isRefetching != current.isRefetching,
  builder: (context, state) =>
      state.isRefetching ? const LinearProgressIndicator() : const SizedBox(),
)

QueryListener(
  query: todos,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: ...,
)
```

`QueriesBuilder` builds from a list of queries of one type at once, with the results in order:

```dart
QueriesBuilder(
  queries: [for (final id in ids) todoQuery(id)],
  builder: (context, results) => Text(
    '${results.where((result) => result.hasData).length} of ${ids.length} loaded',
  ),
)
```

A selector builds from one value of the state and rebuilds only when that value changes. Lists, maps, and sets are compared by content:

```dart
QuerySelector(
  query: todos,
  selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
  builder: (context, doneCount) => Text('$doneCount done'),
)
```

## Mutations

Mutations create, update, or delete server data. Define one, and run it from a `MutationBuilder`:

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);

MutationBuilder(
  mutation: addTodo,
  builder: (context, state) => FilledButton(
    onPressed: state.isPending ? null : () => state.mutate('Buy milk'),
    child: const Text('Add'),
  ),
)
```

Every callback receives the client that runs the mutation. Returning the `invalidateQueries` future from `onSuccess` keeps the mutation pending until the list has refetched. `state.mutateAsync(title)` returns the data, and throws on error.

Anywhere else, `MutationStateBuilder`, `MutationStateSelector`, and `MutationStateListener` show and hear every run of the mutation, wherever it started, found by its `mutationKey`:

```dart
MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
  child: MutationStateSelector(
    mutation: addTodo,
    selector: (runs) => runs.any((run) => run.isPending),
    builder: (context, adding) =>
        adding ? const LinearProgressIndicator() : const SizedBox.shrink(),
  ),
)
```

To share one observer's state instead, create it with `addTodo.observe()` in a `State` field, pass it to the widgets, and call its `reset()` in `dispose`.

**Optimistic updates.** Cancel refetches of the data first, then update the cache in `onMutate` and return what you need to roll back. The returned value is passed to the other callbacks as `context`:

```dart
final deleteTodo = Mutation(
  mutationFn: (int id) => api.deleteTodo(id),
  onMutate: (id, client) async {
    // Keep a refetch in flight from overwriting the optimistic update.
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
);
```

**Without variables**, use `NoVariablesMutation`. Its observer runs it with `mutate()`:

```dart
final logout = NoVariablesMutation(mutationFn: () => api.logout()).observe();
logout.mutate();
```

Mutations don't retry unless you set `retry`. With a `scope`, mutations that share the scope id run one after another.

## Infinite queries

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);

InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : state.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

`getNextPageParam` returns `null` when there are no more pages. Its `data` argument has `pages`, `pageParams`, `lastPage`, `lastPageParam`, `firstPage`, and `firstPageParam`. Add `getPreviousPageParam` for bidirectional lists, and `maxPages` to limit how many pages are kept.

Refetching an infinite query reloads every loaded page in order.

If the first page has no param, give `null` its type so Dart can infer it:

```dart
initialPageParam: null as String?,
getNextPageParam: (data) => data.lastPage.nextCursor,
```

## Streaming

`streamedQuery` builds a query function from a `Stream` that ends, such as a streamed answer. The query succeeds with the first chunk and keeps fetching until the stream is done, and `combine` folds each chunk into the data:

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

When it fetches again, `refetchMode` decides what happens to the data it has: `StreamRefetchMode.reset` (default) starts over, `.append` folds the new stream onto it, and `.replace` keeps it until the new stream is done.

## Using with bloc

Queries and mutations don't depend on widgets. Outside widgets, `observe()` returns an observer with a `stream` that emits the current result first, then every change. Listening to it is what makes the query fetch.

```dart
class TodoCubit extends Cubit<TodoState> {
  TodoCubit() : super(const TodoState()) {
    _subscription = _todos.stream.listen((result) {
      emit(state.copyWith(todos: result.data, loading: result.isLoading));
    });
  }

  final _todos = todosQuery.observe();
  late final StreamSubscription<QueryResult<List<Todo>>> _subscription;

  Future<void> refresh() => _todos.refetch();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
```

In a `Bloc`, use `emit.forEach(todos.stream, onData: ...)`. The example app's [notifications cubit](example/lib/app/screens/notifications/notifications_cubit.dart) and notifications screen share one query. If you don't use any Fuery widgets, call `FueryBinding.ensureInitialized()` once so queries refetch when the app resumes.

## QueryClient

`Fuery.client` is the default client. Use it to read, write, and invalidate cached data:

```dart
final client = context.queryClient; // or Fuery.client

client.getData(todosQuery);                              // List<Todo>?
client.setData(todoQuery(1), todo);
client.updateData(todosQuery, (todos) => [...?todos, todo]);
client.invalidateQueries(queryKey: ['todos']);          // prefix match
client.invalidateQueries(queryKey: ['todos'], exact: true);
client.cancelQueries(queryKey: ['todos']);
client.removeQueries(queryKey: ['todos']);
```

`getData`, `setData`, and `updateData` take the key and the data type from the query. `updateQueriesData(queryKey: ['posts'], (List<Post> posts) => ...)` updates every query under a key that holds the updater's type. A query that `setData` creates gets all of its options, so it stores its data with `persist` and can refetch. With only a key, `getQueryData`, `setQueryData`, and `updateQueryData` do the same with the type named: `getQueryData<List<Todo>>(['todos'])`.

`invalidateQueries` marks matching queries stale and refetches the ones in use. The others refetch the next time they're used.

**Watching the cache.** `client.watch` turns any value computed from the client into a `Stream`. It emits the current value, then a new value whenever queries or mutations change it. Watching doesn't fetch anything:

```dart
late final fetching = Fuery.client.watch((client) => client.isFetching() > 0);

StreamBuilder(
  stream: fetching,
  builder: (context, snapshot) =>
      snapshot.data == true ? const LinearProgressIndicator() : const SizedBox(),
)
```

**Fetching outside widgets.** `client.query` returns cached data if it's fresh, and fetches otherwise. It throws on failure and doesn't retry unless you set `retry`:

```dart
final todos = await client.query(todosQuery); // fetch, or use fresh cache
client.query(todosQuery).ignore();            // prefetch: ignore result and errors
final cached = await client.query(Query(      // use any cached data
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  staleTime: staticStaleTime,
));
```

`client.infiniteQuery(InfiniteQuery(...))` does the same for infinite queries. With nothing cached it loads `pages` pages (default: one); otherwise it reloads the pages already cached.

**Defaults.** Configure every query, or every query under a key prefix:

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);
```

**FueryProvider.** To give a subtree its own client, for example in widget tests, wrap it in `FueryProvider`. Widgets below it that get a query or a mutation use that client:

```dart
runApp(FueryProvider(client: QueryClient(), child: const App()));
```

Create the client once, in `main`, in a `State` field, or in a test's `setUp`. A `QueryClient` created in `build` is a new, empty cache on every rebuild, including every hot reload, so the widgets below go back to loading and fetch again. [Giving a subtree its own client](https://galaxykhh.github.io/fuery/guides/query-client/#giving-a-subtree-its-own-client) keeps one in a `State` field.

`context.queryClient` returns it, or `Fuery.client` when there is no provider. An observer from `observe()` keeps the client it is given: `todosQuery.observe(client: context.queryClient)`.

## Persistence

Give the client a `QueryStorage`, and add `persist` to the queries worth keeping. When the app starts again, they show the stored data and refetch it if it's stale. A synchronous storage shows it on the first frame; with an asynchronous one, call `await Fuery.client.restore()` before `runApp` for the same result:

```dart
Fuery.client = QueryClient(storage: PreferencesStorage(preferences));

final todos = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
  persist: QueryPersist(
    toJson: (todos) => [for (final todo in todos) todo.toJson()],
    fromJson: (json) => [
      for (final item in json! as List) Todo.fromJson(item),
    ],
  ),
);
```

`QueryStorage` has `read`, `write`, `delete`, and `readAll`, and can be synchronous or asynchronous. Stored data expires after the client's `persistMaxAge` (default: one day), and `version` discards data in an old format. `clear()` deletes all stored data, for example on logout.

A mutation with `persist: MutationPersist(...)` and a `mutationKey` stores its variables while it runs, so a comment written offline is still sent after the app is closed and opened again. `await Fuery.client.restore(mutations: [addComment])` in `main` runs what was stored. The [persistence guide](https://galaxykhh.github.io/fuery/guides/persistence/) has a `shared_preferences` storage, infinite queries, `restore()`, and persisted mutations.

## Devtools

`FueryDevtools` adds a button over your app that opens a panel with every query and mutation: their status and data, and buttons to refetch, invalidate, reset, or remove a query. It only appears in debug and profile builds.

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

`FueryDevtoolsPanel` is the panel on its own, for a debug screen of your own.

## App lifecycle and connectivity

Fuery widgets connect the app lifecycle automatically:

- When the app returns to the foreground, stale queries refetch.
- While the app is in the background, retries and polling pause.

Fuery assumes the device is online. To pause fetches while offline and refetch on reconnect, connect a connectivity source, for example [`connectivity_plus`](https://pub.dev/packages/connectivity_plus):

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

## Testing

Give each test a fresh client, and turn off retries so failures show up immediately:

```dart
testWidgets('shows todos', (tester) async {
  final client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(retry: RetryPolicy.never()),
    ),
  );
  Fuery.client = client;
  await tester.pumpWidget(const App());
  // ...
  await tester.pumpWidget(const SizedBox());
  client.clear(); // cancels cache timers so the test can end
});
```

Widgets that get a query or a mutation use the client of the nearest `FueryProvider`, so `FueryProvider(client: client, child: const App())` works too. Observers created with `observe()` use `Fuery.client` unless they are given another.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
