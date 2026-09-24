<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery.svg)](https://pub.dev/packages/fuery)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

Fetch, cache, and keep server data fresh in Flutter.

Request deduplication, stale-while-revalidate caching, retries, pagination, optimistic updates, and persistence.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)** · **[Try the demo →](https://galaxykhh.github.io/fuery/demo/)**

## Why Fuery

- **Built the Flutter way.** Queries are defined outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`. A query needs no `BuildContext` and no setup, so a screen that shows one stays a `StatelessWidget`.
- **Nothing beyond Dart and Flutter.** `fuery` depends on Flutter and `fuery_core`, and `fuery_core` only on the Dart team's `clock`, `collection`, and `meta`. There is no code generation.
- **One key, one cache entry, one request.** Every screen that uses the key `['todos']` shows the same data and shares one request for it.
- **Stale data refreshes in the background.** The cached data stays on screen while Fuery refetches it, when another screen starts using it or the app returns to the foreground.
- **Works with bloc and your services.** The core is pure Dart, so cubits, blocs, and services observe the same queries as a `Stream`.
- **Hooks in a package of their own.** [`fuery_hooks`](https://pub.dev/packages/fuery_hooks) renders the same queries with `useQuery`, so only apps that choose `flutter_hooks` depend on it.

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

The query fetches when `QueryBuilder` mounts. `QueryResult(:final data?)` matches only when there is data, so a list that fails to refresh stays on screen, and the error shows only when there is no data yet.

`todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `data` is a `List<Todo>`. Mutations, infinite queries, widgets, results, and callbacks infer their types the same way. Two cases name the type. A read or write by key alone does, because a key doesn't carry one: `client.getQueryData<List<Todo>>(['todos'])`. So does an infinite query whose first page param is `null`: see [Cursor-based pages](https://galaxykhh.github.io/fuery/guides/infinite-queries/#cursor-based-pages).

## Widgets

Queries, infinite queries, and mutations each have a builder, a listener, a consumer, and a selector, a list of queries has a builder and a selector, and the runs of a mutation have a builder, a listener, and a selector:

| | Rebuild UI | Side effects | Both | Part of the state |
|---|---|---|---|---|
| Query | `QueryBuilder` | `QueryListener` | `QueryConsumer` | `QuerySelector` |
| Infinite query | `InfiniteQueryBuilder` | `InfiniteQueryListener` | `InfiniteQueryConsumer` | `InfiniteQuerySelector` |
| Mutation | `MutationBuilder` | `MutationListener` | `MutationConsumer` | `MutationSelector` |
| Several queries | `QueriesBuilder` | | | `QueriesSelector` |
| Every run of a mutation | `MutationStateBuilder` | `MutationStateListener` | | `MutationStateSelector` |

A listener runs side effects, such as a snackbar, and `listenWhen` picks the changes it reacts to. `buildWhen` does the same for a builder:

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

A mutation creates, updates, or deletes server data. Define one, and run it from a `MutationBuilder`:

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

Returning the `invalidateQueries` future from `onSuccess` keeps the mutation pending until the list has refetched.

Anywhere else, `MutationStateBuilder`, `MutationStateSelector`, and `MutationStateListener` show and hear every run of the mutation, wherever it started, found by its `mutationKey`:

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

## Using with bloc

Outside widgets, `observe()` returns an observer whose `stream` emits the current result first, then every change. Listening to it makes the query fetch, and the cubit shares the cache entry with every widget that uses the key:

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

- [Queries](https://galaxykhh.github.io/fuery/guides/queries/): keys, stale time, results, polling, and cancelling a request.
- [Widgets](https://galaxykhh.github.io/fuery/guides/widgets/): builders, listeners, consumers, selectors, and pull to refresh.
- [Mutations](https://galaxykhh.github.io/fuery/guides/mutations/): changing server data, optimistic updates, and rollback.
- [Infinite queries](https://galaxykhh.github.io/fuery/guides/infinite-queries/): paginated lists, cursors, and previous pages.
- [Streamed queries](https://galaxykhh.github.io/fuery/guides/streaming/): a `Stream` folded into the cache as it arrives.
- [Persistence](https://galaxykhh.github.io/fuery/guides/persistence/): queries and mutations kept across app restarts.
- [QueryClient](https://galaxykhh.github.io/fuery/guides/query-client/): reading, writing, and invalidating the cache, defaults, and fetching outside widgets.
- [Refetching automatically](https://galaxykhh.github.io/fuery/guides/lifecycle/): the app lifecycle, and pausing while offline.
- [Using with bloc](https://galaxykhh.github.io/fuery/guides/bloc/): cubits, blocs, and mutations run from them.
- [Testing](https://galaxykhh.github.io/fuery/guides/testing/): widget, cubit, and plain Dart tests with a fresh client.
- [Devtools](https://galaxykhh.github.io/fuery/guides/devtools/): every query and mutation, inspected inside the running app.
- [Hooks](https://galaxykhh.github.io/fuery/guides/hooks/): `useQuery`, `useMutation`, and the other hooks of `fuery_hooks`.
- [Query options](https://galaxykhh.github.io/fuery/reference/query-options/): every option, with its default.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
