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

- **Built the Flutter way.** A screen that shows a query stays a `StatelessWidget`, so you can start with one screen of the app you have. Queries live outside `build` and need no `BuildContext` or setup. Widgets render them in the shape of `StreamBuilder`: builders for UI, listeners for side effects.
- **Nothing beyond Dart and Flutter.** `fuery` depends on Flutter and `fuery_core`, and `fuery_core` only on the Dart team's `clock`, `collection`, and `meta`. The core is pure Dart, so blocs, cubits, services, CLIs, and servers get the same queries as a `Stream` from `observe()`. Hooks live in [`fuery_hooks`](packages/fuery_hooks), a package of its own, so only apps that choose `flutter_hooks` depend on it.
- **One idea to learn.** A query is a definition. You pass the same object to a widget, fetch it with the client, and read its cached data.
- **Types come from your functions, with no code generation.** The snippet names no type: `todos` is a `Query<List<Todo>>` because `api.getTodos()` returns a `Future<List<Todo>>`. Mutations, widgets, results, and callbacks infer their types the same way. You name a type in two cases: a read or write by key alone, as in `getQueryData<List<Todo>>(['todos'])`, and an [infinite query whose first page param is `null`](https://galaxykhh.github.io/fuery/guides/infinite-queries/#cursor-based-pages).
- **Devtools in the app.** Inspect every query and mutation on a device, inside the running app.

Fuery caches server data and sends one request per key, however many screens use it. It retries failures, paginates, and refetches stale data in the background.

**[Read the documentation →](https://galaxykhh.github.io/fuery/)** · **[Try the demo →](https://galaxykhh.github.io/fuery/demo/)**

## Tested

Every package has 100% line coverage, and CI fails when a line loses it. The core's 411 tests run under `fake_async`, which checks every retry delay, stale timer, and garbage collection against fake time. The widget tests run on the oldest supported Flutter, 3.27, and on the latest. A regression suite keeps fixed edge cases fixed, such as a cancelled fetch overwriting the one that replaced it, a restore racing a reset, or a removed query leaving a timer that keeps a test process alive.

Your own tests can use `fake_async` and `testWidgets` without leaked timers. Fuery cancels each timer it starts when it destroys the query, mutation, or observer that owns the timer, and it reads time from `package:clock`. See [Testing](https://galaxykhh.github.io/fuery/guides/testing/).

## Packages

| Package | What it has |
|---|---|
| [`fuery`](packages/fuery) | Flutter widgets, app lifecycle integration, `FueryProvider`, and devtools. Re-exports `fuery_core`. |
| [`fuery_core`](packages/fuery_core) | Pure Dart core: `QueryClient`, queries, infinite queries, mutations, cache, and retries. |
| [`fuery_hooks`](packages/fuery_hooks) | `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useMutationState` for [`flutter_hooks`](https://pub.dev/packages/flutter_hooks), and `useOnQueryChange`, `useOnMutationChange`, and `useOnMutationStateChange` for side effects. Re-exports `fuery`. |

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

Benchmarks live in the `benchmark/` folder of every package, with a README of what they measure. The tests don't run them:

```bash
(cd packages/fuery_core && dart run benchmark/queries_slot.dart)   # one file per area
(cd packages/fuery && flutter test benchmark/)
(cd packages/fuery_hooks && flutter test benchmark/)
```

The documentation site lives in [`docs/`](docs) and is built with Astro Starlight.

The example app in [`packages/fuery/example`](packages/fuery/example) is a social feed that shows queries, mutations with optimistic updates, and the widgets together.

## Acknowledgements

Fuery's caching and refetching model is inspired by [TanStack Query](https://tanstack.com/query).
