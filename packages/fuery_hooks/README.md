<img src="https://raw.githubusercontent.com/galaxykhh/fuery/main/assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

Hooks for [Fuery](https://pub.dev/packages/fuery): render cached server data from inside `build`, in a [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) `HookWidget`.

Fuery is built the Flutter way. Queries are defined outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`. And `fuery` depends on nothing beyond Dart and Flutter.

`fuery_hooks` is for developers who prefer hooks, a style many know from web development. It is a package of its own because it depends on `flutter_hooks`, so only apps that choose hooks get that dependency. It renders the same queries with one call per query, and no builders:

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

The queries, mutations, and client are Fuery's own, so a screen written with hooks and a screen written with widgets share one cache and one request.

**[Read the hooks guide →](https://galaxykhh.github.io/fuery/guides/hooks/)** · **[Fuery documentation →](https://galaxykhh.github.io/fuery/)**

## Install

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` re-exports `fuery`, so `package:fuery_hooks/fuery_hooks.dart` and `package:flutter_hooks/flutter_hooks.dart` are the only imports you need.

## Hooks

| Hook | Returns |
|---|---|
| `useQuery(query)` | The latest `QueryResult`. `refetch()` is on the result. |
| `useInfiniteQuery(query)` | The latest `InfiniteQueryResult`. `fetchNextPage()` is on the result. |
| `useMutation(mutation)` | The latest `MutationResult`. `mutate(...)` is on the result. |
| `useQueries(queries)` | The results of a list of queries of one data type, in order. |
| `useQueryClient()` | The client the hooks use, for `invalidateQueries` and `setData`. |

Each rebuilds the widget when its result changes, and needs no type arguments: `todos` above is a `QueryResult<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`.

## One query that needs another

Hooks return the result of this moment; they don't wait. A query that needs a value from another one turns itself off until the value exists:

```dart
Query<List<Post>> postsQuery(int? userId) => Query(
      queryKey: ['posts', userId],
      queryFn: (_) => api.getPosts(userId!),
      enabled: userId != null,
    );

final user = useQuery(userQuery);
final posts = useQuery(postsQuery(user.data?.id));
```

The first build has no user, so `posts` is pending and fetches nothing. When the user arrives, the widget rebuilds, `posts` gets the key `['posts', 7]`, and it fetches in that same build.

## Changing data

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

For a side effect of one call, such as a snackbar, pass `MutateOptions` to `mutate`. The callbacks of a call are dropped when the widget goes away, and the request itself still finishes.

## Rules

- **Pass a definition.** A `Query` or a `Mutation` can be a top-level value or be built in `build`: the hook keeps one observer for it and updates its options, so a new key shows in the same frame.
- **Don't call `.observe()` in `build`.** A new observer every build subscribes and fetches again. In debug builds the hook prints a warning once per key.
- **The client** is the one a `FueryProvider` above provides, or `Fuery.client`.

Everything else, from keys and freshness to persistence and devtools, is Fuery's. See the [documentation](https://galaxykhh.github.io/fuery/).
