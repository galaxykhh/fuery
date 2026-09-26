<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery.svg)](https://pub.dev/packages/fuery)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

Fetch, cache, and keep server data fresh in Flutter.

Screens that use the same key share one request, and cached data stays on screen while Fuery refetches it. Retries, pagination, optimistic updates, and persistence are built in.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)** · **[Try the demo →](https://galaxykhh.github.io/fuery/demo/)**

## Why Fuery

- **Built the Flutter way.** A screen that shows a query stays a `StatelessWidget`. Queries keep their data outside `build` and need no `BuildContext` or setup. Widgets render them in the shape of `StreamBuilder`: builders for UI, listeners for side effects.
- **Nothing beyond Dart and Flutter.** `fuery` depends on Flutter and `fuery_core`, and `fuery_core` only on the Dart team's `clock`, `collection`, and `meta`. Fuery needs no code generation.
- **One key, one cache entry, one request.** Every screen that uses the key `['todos']` shows the same data and shares one request for it.
- **Stale data refreshes in the background.** The cached data stays on screen while Fuery refetches it, when another screen starts using it or the app returns to the foreground.
- **Works with bloc and your services.** The core is pure Dart, so cubits, blocs, and services observe the same queries as a `Stream`.
- **Hooks in a package of their own.** [`fuery_hooks`](https://pub.dev/packages/fuery_hooks) renders the same queries with `useQuery`, so only apps that choose `flutter_hooks` depend on it.

## Install

```bash
flutter pub add fuery
```

## Quick start

Define a query and pass it to a widget:

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

The query fetches when `QueryBuilder` mounts. `QueryResult(:final data?)` matches only when there is data, and it comes before the error case. So a list that fails to refresh stays on screen, and the error shows only while there is no data.

`todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, so `data` is a `List<Todo>`. Mutations, infinite queries, widgets, results, and callbacks infer their types the same way. You name a type in two cases:

- A read or write by key alone, as a key carries no type: `client.getQueryData<List<Todo>>(['todos'])`.
- An [infinite query whose first page param is `null`](https://galaxykhh.github.io/fuery/guides/infinite-queries/#cursor-based-pages).

## Widgets

Pick the row for what the widget watches and the column for what it does:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| Several queries | `QueriesBuilder` | | | `QueriesSelector` |
| Every run of a mutation | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

A listener runs side effects, such as a snackbar. `listenWhen` picks the changes it reacts to, and `buildWhen` does the same for a builder:

```dart
QueryListener(
  query: todosQuery,
  listenWhen: (previous, current) => current.isRefetchError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not refresh: ${state.error}'))),
  child: const TodoListScreen(),
)
```

## Mutations

A mutation creates, updates, or deletes server data. Define one, and run it from any widget with `mutate` and the widget's client:

```dart
final addTodo = Mutation(
  mutationKey: const ['todos', 'add'],
  mutationFn: (String title) => api.addTodo(title),
  onSuccess: (todo, title, context, client) {
    return client.invalidateQueries(queryKey: ['todos']);
  },
);

FilledButton(
  onPressed: () => addTodo.mutate('Buy milk', context.queryClient),
  child: const Text('Add'),
)
```

The definition holds no state. The run belongs to the cache of the client you pass, not to the button. `context.queryClient` is the client of the nearest `FueryProvider`, or `Fuery.client` without one. Without a client, the run uses `Fuery.client`. Returning the `invalidateQueries` future from `onSuccess` keeps the run pending until the list has refetched.

`MutationStateBuilder`, `MutationStateSelector`, and `MutationStateListener` show or hear every run on any screen. They find the runs by `mutationKey`, wherever each run started:

```dart
MutationStateListener(
  mutation: addTodo,
  listenWhen: (previous, current) => current.isError,
  listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not add "${run.variables}"')),
  ),
  child: const TodoListScreen(),
)
```

For an effect after one call, such as closing the screen, `await addTodo.mutateAsync('Buy milk', context.queryClient)` returns the data or throws. A `MutationBuilder` runs the mutation with `state.mutate`, and shows only the runs it starts.

## Bloc and cubits

Outside widgets, `observe()` returns an observer whose `stream` emits the current result first, then every change. Listening to the stream makes the query fetch. The cubit shares the cache entry with every widget that uses the key:

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

An app that uses no Fuery widgets calls `FueryBinding.ensureInitialized()` once, so queries refetch when the app resumes.

## Learn more

- [How the cache works](https://galaxykhh.github.io/fuery/how-the-cache-works/): when data is shared, refetched, and removed.
- [Queries](https://galaxykhh.github.io/fuery/guides/queries/): keys, stale time, polling, and cancelling a request.
- [Widgets](https://galaxykhh.github.io/fuery/guides/widgets/): builders, listeners, consumers, selectors, and pull to refresh.
- [Mutations](https://galaxykhh.github.io/fuery/guides/mutations/): changing server data, optimistic updates, and rollback.
- [Infinite queries](https://galaxykhh.github.io/fuery/guides/infinite-queries/): paginated lists, cursors, and previous pages.
- [Streamed queries](https://galaxykhh.github.io/fuery/guides/streaming/): a `Stream` folded into the cache as it arrives.
- [Persistence](https://galaxykhh.github.io/fuery/guides/persistence/): queries and mutations kept across app restarts.
- [Setting up the client](https://galaxykhh.github.io/fuery/guides/client-setup/): defaults, error reporting, and a client for a subtree.
- [Reading and updating the cache](https://galaxykhh.github.io/fuery/guides/query-client/): invalidating, watching, and fetching outside widgets.
- [Refetching and going offline](https://galaxykhh.github.io/fuery/guides/lifecycle/): on resume and reconnect, and pausing while offline.
- [Bloc and cubits](https://galaxykhh.github.io/fuery/guides/bloc/): queries and mutations in cubits and blocs.
- [Testing](https://galaxykhh.github.io/fuery/guides/testing/): widget, cubit, and Dart tests with a fresh client.
- [Devtools](https://galaxykhh.github.io/fuery/guides/devtools/): every query and mutation, inspected in the running app.
- [Hooks](https://galaxykhh.github.io/fuery/guides/hooks/): `useQuery`, `useMutation`, and the other hooks of `fuery_hooks`.

Reference: [Query options](https://galaxykhh.github.io/fuery/reference/query-options/), [Query results](https://galaxykhh.github.io/fuery/reference/query-results/), [Mutation options](https://galaxykhh.github.io/fuery/reference/mutation-options/), [Mutation results](https://galaxykhh.github.io/fuery/reference/mutation-results/), and [QueryClient](https://galaxykhh.github.io/fuery/reference/query-client/).

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
