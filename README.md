<img src="assets/brand/banner.png" alt="Fuery: server state for Flutter" width="100%">

[![pub package](https://img.shields.io/pub/v/fuery.svg)](https://pub.dev/packages/fuery)
[![pub points](https://img.shields.io/pub/points/fuery)](https://pub.dev/packages/fuery/score)
[![CI](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml/badge.svg)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/galaxykhh/fuery/actions/workflows/ci.yml)

Fetch, cache, and keep server data fresh in Flutter.

```dart
final todos = Query(queryKey: ['todos'], queryFn: (_) => api.getTodos());

QueryBuilder(
  query: todos,
  builder: (context, state) => switch (state.data) {
    final data? => TodoList(data),
    null => const CircularProgressIndicator(),
  },
)
```

Nothing here names a type: `todos` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`, and `data` in the builder is a `List<Todo>`.

- **Built the Flutter way.** Queries are defined outside `build`, and widgets render them: builders for UI and listeners for side effects, in the shape of `StreamBuilder`.
- **Nothing beyond Dart and Flutter.** `fuery` depends on Flutter and `fuery_core`, and `fuery_core` only on the Dart team's `clock`, `collection`, and `meta`. Prefer hooks, a style many know from the web? [`fuery_hooks`](packages/fuery_hooks) renders the same queries with `useQuery`, in a package of its own, so only apps that choose `flutter_hooks` depend on it.
- **One idea to learn.** A query is a definition: pass it to a widget, fetch it with the client, or read its cached data, all with the same object.
- **Drops into the app you have.** Start with one screen: a query needs no `BuildContext` and no setup, and it works in a `StatelessWidget`.
- **Runs where your code runs.** The core is pure Dart, so widgets, cubits, services, CLIs, and servers use the same queries.
- **Types come from your functions, with no code generation.** Queries, mutations, widgets, results, and callbacks infer them. Only reads and writes by key alone name the type, as in `getQueryData<List<Todo>>(['todos'])`.
- **Devtools in the app**, on a device.

Fuery caches server data, deduplicates requests, retries failures, paginates, and refetches stale data in the background. Builder, listener, and consumer widgets turn queries into UI and side effects, and `observe()` gives blocs, cubits, and services the same data as a `Stream`.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)** · **[Try the demo →](https://galaxykhh.github.io/fuery/demo/)**

## Tested

Every package has 100% line coverage, and CI fails when a line loses it. The core's 378 tests run under `fake_async`, so every retry delay, stale timer, and garbage collection is checked against fake time, and the widget tests run on the oldest supported Flutter (3.27) as well as the latest. A regression suite keeps the edge cases that were found and fixed from coming back, such as a cancelled fetch overwriting the one that replaced it, a restore racing a reset, or a removed query leaving a timer that keeps a test process alive.

Every timer Fuery starts is cancelled on the matching destroy path, and time comes from `package:clock`, so your own tests can use `fake_async` and `testWidgets` without leaked timers. See [Testing](https://galaxykhh.github.io/fuery/guides/testing/).

## Packages

| Package | |
|---|---|
| [`fuery`](packages/fuery) | Flutter widgets, app lifecycle integration, `FueryProvider`, and devtools. Re-exports `fuery_core`. |
| [`fuery_core`](packages/fuery_core) | Pure Dart core: `QueryClient`, queries, infinite queries, mutations, cache, and retries. |
| [`fuery_hooks`](packages/fuery_hooks) | `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useMutationState` for [`flutter_hooks`](https://pub.dev/packages/flutter_hooks). Re-exports `fuery`. |

## Development

This repository is a [pub workspace](https://dart.dev/tools/pub/workspaces) and needs Dart 3.6 or later.

```bash
flutter pub get                                  # resolves every package from the root
flutter analyze packages
(cd packages/fuery_core && dart test)
(cd packages/fuery && flutter test)
(cd packages/fuery/example && flutter test)
(cd packages/fuery_hooks && flutter test)
```

The documentation site lives in [`docs/`](docs) and is built with Astro Starlight.

The example app in [`packages/fuery/example`](packages/fuery/example) shows queries, mutations with optimistic updates, and the widgets together.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
