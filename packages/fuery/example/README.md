# Fuery example

A todo app with one screen per case, so each pattern can be read on its own.
The home screen lists them; the mock API adds the delays a real one would have.

**[Try it in a browser →](https://galaxykhh.github.io/fuery/demo/)**

```bash
flutter run
flutter test
```

The demo is this app built for the web, with the devtools turned on through `--dart-define=fuery.demo=true`.

## Cases

| Screen | What it shows |
|---|---|
| [List, refresh, and optimistic delete](lib/app/screens/todo_list/todo_list.dart) | `QueryBuilder`, pull-to-refresh and a retry button through `refetch`, a refetch indicator with `buildWhen`, an optimistic delete that rolls back, `MutationBuilder` for a barrier and `MutationListener` for an error snackbar |
| [Todo detail](lib/app/screens/todo_detail/todo_detail.dart) | A key per todo, opening with the list's copy as `placeholderData` instead of a spinner |
| [Stats in a cubit](lib/app/screens/todo_stats/todo_stats_cubit.dart) | The same query read from a `Cubit` through its stream, so completing a todo on the list updates the stats |
| [Paged archive](lib/app/screens/infinite_todos/infinite_todos.dart) | `InfiniteQuery.use` with `fetchNextPage` and `hasNextPage` |
| [Search as you type](lib/app/screens/search_todos/search_todos.dart) | One observer following every term with `setOptions`, keeping the previous results on screen, and `enabled: false` for an empty term |
| [Poll a job](lib/app/screens/job_status/job_status.dart) | `refetchInterval` with `refetchWhile`, so polling stops when the job finishes |
| [Streamed answer](lib/app/screens/streaming_answer/streaming_answer.dart) | `streamedQuery` folding chunks into the cached data |
| [Prefetch before navigating](lib/app/screens/prefetch/prefetch.dart) | `client.infiniteQuery` outside widgets, so the next screen opens with data |
| [The case list itself](lib/app/screens/cases/cases_screen.dart) | `client.watch` for an activity indicator, and `QuerySelector` for a count that rebuilds on its own |

## How the app is organized

- [`data/todo_queries.dart`](lib/app/data/todo_queries.dart): every key and query function in one place, so screens and cubits share cache entries. The list query also sets `persist`.
- [`data/todo_mutations.dart`](lib/app/data/todo_mutations.dart): the same for mutations. The cache work is written once; each screen gets its own pending and error state.
- [`data/preferences_storage.dart`](lib/app/data/preferences_storage.dart): a `QueryStorage` on shared preferences. [`main.dart`](lib/main.dart) gives it to the client, so the todo list is on screen before the first request finishes.
- [`test/`](test/): widget tests for each case, and `helpers.dart` to open one from the home screen.
