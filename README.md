<img src="assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

Fetch, cache, and keep server data fresh in Flutter.

```dart
final todos = Query.use(queryKey: ['todos'], queryFn: (_) => api.getTodos());

QueryBuilder(
  query: todos,
  builder: (context, state) => state.isPending
      ? const CircularProgressIndicator()
      : TodoList(state.data!),
)
```

Fuery caches server data, deduplicates requests, retries failures, paginates, and refetches stale data in the background. Builder, listener, and consumer widgets turn queries into UI and side effects, and queries are plain objects with a `Stream`, so blocs, cubits, and services can use them as well.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)**

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

The documentation site lives in [`docs/`](docs) and is built with Astro Starlight.

The example app in [`packages/fuery/example`](packages/fuery/example) shows queries, mutations with optimistic updates, and the widgets together.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
