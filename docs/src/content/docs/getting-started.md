---
title: Getting started
description: Install Fuery in a Flutter app, show your first cached API request, and test it.
---

In five steps, a screen shows a list from your API with loading and error states, every other screen reuses the cached list, and a widget test checks it.

## Before you start

- Flutter 3.27 or newer, with Dart 3.6 or newer.
- Two names the code expects from your app:
  - `api`, a top-level variable, such as `var api = Api();`, whose `getTodos()` returns a `Future<List<Todo>>`. A test replaces it with a fake.
  - `TodoList`, a widget that shows each todo's title in a `Text`.

## 1. Install Fuery

```bash
flutter pub add fuery
```

`fuery` includes `fuery_core`, so this is the only package you need in a Flutter app. For Dart code without Flutter, such as a server or CLI, use `dart pub add fuery_core` instead.

Fuery depends on nothing beyond Dart and Flutter. `fuery` adds only `fuery_core`, which depends only on the Dart team's `clock`, `collection`, and `meta`. There is no native code and no platform setup, so Fuery runs on every platform Flutter targets, the web included.

## 2. Define a query

A query needs a **key** that names the data and a **query function** that fetches it:

```dart
import 'package:fuery/fuery.dart';

final todosQuery = Query(
  queryKey: ['todos'],
  queryFn: (_) => api.getTodos(),
);
```

`package:fuery/fuery.dart` also exports `fuery_core`, so this one import covers every Fuery name on this page.

Defining a query starts nothing. The fetch begins when a widget shows the query, so the definition can be a top-level value, as here, or be built in `build`.

## 3. Show it on screen

Pass the query to a `QueryBuilder`. It fetches when it mounts and rebuilds with each new result:

```dart
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

The data branch comes first. When a refresh fails, the list stays on screen, and the error shows only when there is no data to show.

With hooks, [`fuery_hooks`](../guides/hooks/) renders the same query with `useQuery(todosQuery)` in a `HookWidget`, from a package of its own.

## 4. Run the app

Show the screen in your app and run it:

```dart
void main() => runApp(const MaterialApp(home: TodoListScreen()));
```

The first frame shows the `CircularProgressIndicator`. When `api.getTodos()` returns, the list replaces it.

Another screen that shows `todosQuery` displays the cached list on its first frame, with no loading indicator.

## 5. Test it

Write a `FakeApi` class that implements your `Api`. Its `getTodos()` waits 300 milliseconds, then returns one todo titled "Buy milk".

Then add this test in a file under `test/`. It puts the fake in place of `api` and checks the loading state and the list. Also import the files that declare `api`, `FakeApi`, and `TodoListScreen`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  testWidgets('shows todos', (tester) async {
    api = FakeApi();

    await tester.pumpWidget(const MaterialApp(home: TodoListScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // the fake request
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    Fuery.client.clear();
  });
}
```

The last two lines unmount the screen and empty the cache, so no garbage collection timer outlives the test and fails it. Keep them in the test body, because `addTearDown` runs after `testWidgets` checks for timers.

[Testing](../guides/testing/) shows how to give each test a fresh client, turn retries off, and test cubits and plain Dart.

## What Fuery did for you

- **Types come from your functions.** `todosQuery` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `state` in the builder is a `QueryResult<List<Todo>>`. Two cases name the type: a read or write by key alone, as in `client.getQueryData<List<Todo>>(['todos'])`, and an infinite query whose first page param is `null` (see [Cursor-based pages](../guides/infinite-queries/#cursor-based-pages)).
- **No null checks.** `QueryResult(:final data?)` matches only when there is data, so `data` is a `List<Todo>` in that branch.
- **Screens share data by key.** Every screen that uses `['todos']` reads one cache entry, and screens that mount while a fetch runs share that request.
- **Stale data refreshes itself.** Data is stale as soon as it arrives (`staleTime` defaults to zero). Fuery refetches it in the background when another screen starts using it and when the app returns to the foreground, and the old list stays on screen meanwhile.

[How the cache works](../how-the-cache-works/) explains when data refetches and when it leaves memory.

## Next steps

- [Server state in Flutter](../server-state/): why server data needs a cache.
- [How the cache works](../how-the-cache-works/): definitions, observers, and the lifecycle of cached data.
- [Queries](../guides/queries/): keys, freshness, and queries that depend on each other.
- [Widgets](../guides/widgets/): builders, listeners, consumers, and selectors.
- [Mutations](../guides/mutations/): changing server data, with optimistic updates.
- [Bloc and cubits](../guides/bloc/): the same queries inside cubits and blocs.
- [Devtools](../guides/devtools/): every query and mutation, inspected in the running app.
