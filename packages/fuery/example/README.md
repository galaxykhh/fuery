# Fuery example

A todo app that shows how the pieces fit together:

- `Query.use` with `QueryBuilder` for the list, and a second `QueryBuilder` with `buildWhen` for a refetch indicator.
- `Mutation.use` to add todos, invalidating the list on success.
- An optimistic delete that removes the todo immediately and rolls back if the request fails.
- `MutationBuilder` for a loading barrier and `MutationListener` for an error snackbar.

The screen is in [`lib/app/screens/todo_list/todo_list.dart`](lib/app/screens/todo_list/todo_list.dart), and [`test/todo_list_test.dart`](test/todo_list_test.dart) exercises it.

```bash
flutter run
flutter test
```
