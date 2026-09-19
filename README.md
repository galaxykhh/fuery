<img src="assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

Server state for Flutter, with widgets that work like `flutter_bloc`.

```dart
final todos = Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());

QueryBuilder(
  query: todos,
  builder: (context, state) => state.isPending
      ? const CircularProgressIndicator()
      : TodoList(state.data!),
)
```

Fuery caches server data, deduplicates requests, retries failures, paginates, and refetches stale data in the background. Its widgets (`Builder`, `Listener`, and `Consumer`, with `buildWhen` and `listenWhen`) feel like `flutter_bloc`, and queries are plain objects with a `Stream`, so they work inside blocs and cubits as well.

**[Read the documentation →](packages/fuery/README.md)**

## Packages

| Package | |
|---|---|
| [`fuery`](packages/fuery) | Flutter widgets, app lifecycle integration, and `FueryProvider`. Re-exports `fuery_core`. |
| [`fuery_core`](packages/fuery_core) | Pure Dart core: `QueryClient`, queries, infinite queries, mutations, cache, and retries. |

## Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces) and needs Dart 3.6 or later.

```bash
flutter pub get                                  # resolves every package from the root
flutter analyze packages
(cd packages/fuery_core && dart test)
(cd packages/fuery && flutter test)
(cd packages/fuery/example && flutter test)
```

The example app in [`packages/fuery/example`](packages/fuery/example) shows queries, mutations with optimistic updates, and the widgets together.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
