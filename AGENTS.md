# Fuery

Server state caching for Flutter: queries, infinite queries, and mutations, with builder and listener widgets. This is a pub workspace with two published packages:

- `packages/fuery_core`: pure Dart core (queries, infinite queries, mutations, cache, retries). No Flutter imports.
- `packages/fuery`: Flutter widgets, app lifecycle binding, `FueryProvider`, and the in-app devtools. Re-exports `fuery_core`.
- `packages/fuery/example`: a social feed app (feed, post, compose, search, notifications) whose README maps each screen to the Fuery features it shows. Show a new feature where it belongs in that app, with a widget test.
- `docs`: the documentation site (Astro Starlight), deployed to https://galaxykhh.github.io/fuery/

Each package and `docs/` has its own `AGENTS.md` with package-specific rules.

## Commands

Run from the repository root unless noted. Requires Dart 3.6+ (pub workspaces).

```bash
flutter pub get                                   # resolves the whole workspace
flutter analyze packages                          # must report no issues
dart format packages                              # keep formatting clean
(cd packages/fuery_core && dart test)
(cd packages/fuery && flutter test)
(cd packages/fuery/example && flutter test)
```

Coverage (both packages are at 100% line coverage):

```bash
(cd packages/fuery_core && dart pub global run coverage:test_with_coverage)  # needs: dart pub global activate coverage
(cd packages/fuery && flutter test --coverage)                               # writes coverage/lcov.info
```

`coverage/` is gitignored.

CI (`.github/workflows/ci.yml`) runs format, analyze, and all three test suites on the latest stable Flutter, and analyze and the tests on the oldest supported version (Flutter 3.27, Dart 3.6), for every pull request and every push to `main`. Raise the pubspec constraints and that CI version together. `.github/workflows/docs.yml` builds the example for the web into `docs/public/demo`, builds the docs site, and deploys both to GitHub Pages from `main`. It runs on pull requests that touch the docs, the example, or either package's `lib/`. The demo passes `--dart-define=fuery.demo=true`, which turns the devtools on in that release build.

## Rules for every change

- Keep `flutter analyze packages` at zero issues and `dart format` clean.
- Keep 100% line coverage in both packages. Mark truly unreachable defensive code with `// coverage:ignore-start` / `// coverage:ignore-end` and a comment explaining why it can't run.
- For a bug fix, write the failing test first and confirm it fails before fixing.
- Public entry points (`Query.use`, `InfiniteQuery.use`, `Mutation.use`, `Mutation.noParam`, `infiniteQueryOptions`, `streamedQuery`, `QueryClient.watch`, `QueryPersist`, `InfiniteQueryPersist`, and the widgets) must work without explicit type arguments. This includes apps that enable `strict-inference`: give a type parameter that only optional arguments use a bound, such as `TContext extends Object?`, so it falls back to the bound instead of failing inference. Both packages enable `strict-casts`, `strict-inference`, and `strict-raw-types`, so `packages/fuery_core/test/inference_test.dart` fails analysis or stops compiling if inference breaks; extend it for new entry points.
- Keep the public API to what apps and `fuery` use. Making something public later is not breaking, but hiding it is. Apps change the caches through `QueryClient` and observe them with `QueryClient.watch`; don't add public cache events or cache-mutating methods.
- Fetch outside widgets with `client.query` and `client.infiniteQuery`. Don't add `fetchQuery`, `prefetchQuery`, or `ensureQueryData`-style methods.
- `fuery` and `fuery_core` are released together with the same version. Breaking changes are allowed before 1.0.
- To release, bump both versions and add a short CHANGELOG entry to each, merge to `main`, then push a tag `vX.Y.Z`. `.github/workflows/publish.yml` tests and publishes `fuery_core`, then `fuery`, and creates a GitHub release from both `## X.Y.Z` CHANGELOG entries. Don't publish or create releases by hand.
- Update the READMEs and the docs site when public behavior changes, and make sure every code snippet compiles.

## Writing docs

- The logo, README banner, GitHub social preview, and icon live in `assets/brand/`. Edit the SVGs, then run `python3 assets/brand/render.py` to regenerate the PNGs. Palette: violet `#6B4EFF`, lime `#C6F542`, lavender `#C9BEFF`, ink `#14112B`.
- Describe Fuery on its own terms: what it does and how it fits Flutter. Don't compare it with other libraries, describe it as working like another package, or call it a port. Guides may show how to use Fuery together with other packages, such as bloc.
- Keep README examples short and runnable against the real API.
- READMEs and the docs site describe the current API only. Don't add upgrade or migration guides.

## Commits

Use `type: summary` in the imperative, matching the history: `feat`, `fix`, `refactor`, `test`, `doc`, `chore`. Don't add AI co-author or tool attribution trailers to commit messages.
