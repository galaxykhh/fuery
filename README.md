<p align="center">
  <img src="https://github.com/galaxykhh/fuery/assets/79380337/15ad2527-a059-44ce-a8d2-51920c02596f"/>
  <h1 align="center">Fuery</h1>
</p>

Server state caching for Flutter, with a widget API that feels like `flutter_bloc`.

## Packages

| Package | Description |
|---|---|
| [`fuery_core`](packages/fuery_core) | Pure Dart core: queries, infinite queries, mutations, cache and garbage collection. |
| [`fuery`](packages/fuery) | Flutter bindings: `QueryBuilder`, `QueryListener`, `InfiniteQueryBuilder`, `MutationBuilder`. |

## Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces) (Dart 3.6+).

```bash
flutter pub get                       # resolve all packages from the root
flutter analyze packages
(cd packages/fuery_core && dart test)
```
