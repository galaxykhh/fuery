# Fuery example

A todo app that shows how the pieces fit together:

- `Query.use` with `QueryBuilder` for the list, and a second `QueryBuilder` with `buildWhen` for a refetch indicator.
- `Mutation.use` to add todos, invalidating the list on success.
- An optimistic delete that removes the todo immediately and rolls back if the request fails.
- `MutationBuilder` for a loading barrier and `MutationListener` for an error snackbar.
- A stats screen whose `Cubit` listens to the same todo query, so completing a todo on the list updates the stats.

The screens are in [`lib/app/screens/`](lib/app/screens/), the shared query is in [`lib/app/data/todo_queries.dart`](lib/app/data/todo_queries.dart), and the tests are in [`test/`](test/).

```bash
flutter run
flutter test
```
