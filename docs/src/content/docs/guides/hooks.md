---
title: Hooks
description: Render queries and mutations from inside build with fuery_hooks and flutter_hooks.
---

`fuery_hooks` renders Fuery's queries and mutations from inside `build`, in a [`flutter_hooks`](https://pub.dev/packages/flutter_hooks) `HookWidget`, with one call per query and no builders.

Fuery's own style is [the widgets](../widgets/), which follow Flutter's conventions: queries are defined outside `build`, builders turn them into UI, and listeners run side effects. Hooks are for developers who prefer the style many know from web development. The queries, mutations, and client stay the same, so a screen written with hooks and one written with widgets share one cache and one request.

`fuery` depends on nothing beyond Dart and Flutter. Hooks need `flutter_hooks`, so they live in a package of their own, and only apps that choose hooks depend on it.

## Installing

```bash
flutter pub add fuery_hooks flutter_hooks
```

`fuery_hooks` re-exports `fuery`. It needs the same Dart and Flutter versions as `fuery`.

## Reading a query

Make the screen a `HookWidget`, and call `useQuery` with a query:

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

`useQuery` returns the result of this moment and rebuilds the widget when it changes. The result is the same `QueryResult` a `QueryBuilder` gets, with `refetch()` on it. The first build already shows the pending state, and the fetch starts when the widget mounts.

The query can be a top-level value, as above, or be built in `build`, such as `useQuery(todoQuery(id))`. The hook keeps one observer for it and updates its options, so a new key shows in the same frame. Don't pass `todosQuery.observe()`: a new observer on every build subscribes and fetches again, and in debug builds the hook prints a warning once per key.

## One query that needs another

Hooks don't wait for data. A query that needs a value from another one turns itself off with `enabled` until the value exists:

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

| Build | `user` | `posts` |
|---|---|---|
| First | Fetching, no data | Key `['posts', null]`, turned off, fetches nothing |
| After the user arrives | Data with id `7` | Key `['posts', 7]`, starts fetching in this build |
| After the posts arrive | Data | Data |

A query that is turned off and has no data is pending, so `posts.isPending` covers both waits. `posts.isLoading` is true only while its request runs.

## Changing data

`useMutation` returns the mutation's result, with `mutate` on it:

```dart
final addTodo = useMutation(addTodoMutation);

ElevatedButton(
  onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
  child: const Text('Add'),
)
```

For a side effect of one call, such as a snackbar, pass `MutateOptions` to `mutate`:

```dart
addTodo.mutate(
  'Buy milk',
  MutateOptions(
    onError: (error, _, __, ___) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error'))),
  ),
);
```

When the widget goes away, the request still finishes, and the callbacks passed to its `mutate` calls are dropped.

## Loading more pages

`useInfiniteQuery` returns an `InfiniteQueryResult`, with the loaded pages and `fetchNextPage()`:

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

## A list of queries

`useQueries` takes a list of queries of one data type and returns their results in order, such as one query per id:

```dart
final posts = useQueries([for (final id in ids) postQuery(id)]);
final loaded = posts.where((post) => post.hasData).length;
```

Each query keeps its observer while its key stays in the list, even when the list is reordered. Changes that arrive together rebuild once.

## The client

`useQueryClient()` returns the client the hooks use: the one a `FueryProvider` above provides, or `Fuery.client`. The widget rebuilds when the provided client is replaced.

```dart
final client = useQueryClient();

RefreshIndicator(
  onRefresh: () => client.invalidateQueries(queryKey: ['todos']),
  child: TodoList(todos.data ?? []),
)
```

## Testing

Test a hook screen like any widget. [Testing](../testing/) applies as it is: end each test by unmounting the tree and clearing the client.
