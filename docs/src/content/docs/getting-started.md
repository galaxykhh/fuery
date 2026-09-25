---
title: Getting started
description: Install Fuery in a Flutter app and cache your first API request.
---

By the end of this page a screen shows a list from an API, with loading and
error states, and the data cached for every other screen that needs it.

## 1. Install Fuery

```bash
flutter pub add fuery
```

`fuery` includes `fuery_core`, so this is the only package you need in a Flutter app. For Dart code without Flutter, such as a server or CLI, use `dart pub add fuery_core` instead.

It needs Dart 3.6 and Flutter 3.27 or newer. Fuery depends on nothing beyond Dart and Flutter: `fuery` adds only `fuery_core`, which depends only on the Dart team's `clock`, `collection`, and `meta`. There is no native code and no platform setup, so it runs on every platform Flutter targets, the web included.

## 2. Write your first query

A query needs a **key** that identifies the data and a **query function** that fetches it. Define it, and pass it to `QueryBuilder`:

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

`api.getTodos()` is any function that returns a `Future<List<Todo>>`, and `TodoList` is your own widget that takes the list.

The query lives outside `build`, and a widget renders it, the way `StreamBuilder` renders a stream. If you prefer hooks, [`fuery_hooks`](../guides/hooks/) renders the same query with `useQuery(todosQuery)` in a `HookWidget`. It is a package of its own, so only apps that choose `flutter_hooks` depend on it.

## 3. Test it

A widget test pumps the screen, waits for the fake request, and checks the list. End it by unmounting the tree and emptying the cache: a cached query keeps a timer for its garbage collection, and `testWidgets` fails on any timer that outlives the test. `addTearDown` runs too late for that check, so the two lines go at the end of the test body:

```dart
testWidgets('shows todos', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 300)); // the fake request
  expect(find.text('Buy milk'), findsOneWidget);

  await tester.pumpWidget(const SizedBox());
  Fuery.client.clear();
});
```

[Testing](../guides/testing/) has the same for cubits and plain Dart, and how to turn retries off so failures show up at once.

## What Fuery does for you

- **Types come from your functions.** `todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `state` in the builder is a `QueryResult<List<Todo>>`. Mutations, infinite queries, and every widget infer their types the same way. Two cases name the type. A read or write by key alone does, because a key doesn't carry one: `client.getQueryData<List<Todo>>(['todos'])`. So does an infinite query whose first page param is `null`: see [Cursor-based pages](../guides/infinite-queries/#cursor-based-pages).
- **No null checks.** `QueryResult(:final data?)` matches only when there is data, so `data` is a `List<Todo>`. That branch comes first, so a list that fails to refresh stays on screen and the error shows only when there is nothing to show.
- **A query is only a description.** Defining one starts nothing, so it can live at the top level or be built in `build`. The fetch begins when `QueryBuilder` mounts, and the first frame already shows loading.
- **Widgets share data by key.** Another screen that uses `['todos']` gets the cached list immediately and shares the same request.
- **Stale data refreshes itself.** It refetches in the background when another screen starts using it and when the app returns to the foreground. The old data stays on screen while that happens.

## Next steps

- [Server state in Flutter](../server-state/): why server data needs a cache rather than another state class.
- [Queries](../guides/queries/): keys, freshness, and results.
- [Widgets](../guides/widgets/): builders, listeners, and consumers.
- [Mutations](../guides/mutations/): changing server data and optimistic updates.
- [Using with bloc](../guides/bloc/): the same queries inside cubits and blocs.
- [Devtools](../guides/devtools/): see every query and mutation while you develop.
