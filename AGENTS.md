# Fuery

Server state caching for Flutter: queries, infinite queries, and mutations, with builder and listener widgets. This is a pub workspace with three published packages:

- `packages/fuery_core`: pure Dart core (queries, infinite queries, mutations, cache, retries). No Flutter imports.
- `packages/fuery`: Flutter widgets, app lifecycle binding, `FueryProvider`, and the in-app devtools. Re-exports `fuery_core`.
- `packages/fuery_hooks`: `useQuery`, `useInfiniteQuery`, `useMutation`, `useQueries`, and `useMutationState` for `flutter_hooks`. Re-exports `fuery`.
- `packages/fuery/example`: a social feed app (feed, post, compose, search, notifications) whose README maps each screen to the Fuery features it shows. Show a new feature of `fuery` or `fuery_core` where it belongs in that app, with a widget test. `fuery_hooks` has its own example in `packages/fuery_hooks/example`, so the app depends on nothing but Fuery.
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
(cd packages/fuery_hooks && flutter test)
for p in fuery_core fuery fuery_hooks; do (cd packages/$p/test_fixes && dart fix --compare-to-golden); done  # dart fix goldens
```

Coverage (every package is at 100% line coverage, and CI fails otherwise):

```bash
(cd packages/fuery_core && dart pub global run coverage:test_with_coverage)  # needs: dart pub global activate coverage
(cd packages/fuery && flutter test --coverage)                               # writes coverage/lcov.info
(cd packages/fuery_hooks && flutter test --coverage)
python3 tool/check_coverage.py packages/fuery_core packages/fuery packages/fuery_hooks  # lists any uncovered line
```

Release and docs checks:

```bash
python3 tool/check_versions.py                    # same version everywhere; fuery and fuery_hooks depend on ^<version>
python3 tool/check_doc_links.py                   # docs links in lib/, READMEs, and pubspecs resolve to a page and heading
```

`coverage/` is gitignored.

CI (`.github/workflows/ci.yml`) runs the version and docs link checks, a `pub publish --dry-run` of every package, format, analyze, the `dart fix` goldens, all four test suites, and the coverage check on the latest stable Flutter, and analyze, the goldens, and the tests on the oldest supported version (Flutter 3.27, Dart 3.6). It runs for every pull request, every push to `main`, weekly (it follows the latest stable Flutter and resolves dependencies fresh, so a new release can break `main` without a commit), and when started by hand. Raise the pubspec constraints and that CI version together. `.github/workflows/docs.yml` builds the example for the web into `docs/public/demo`, builds the docs site, and deploys both to GitHub Pages from `main`. It runs on pull requests that touch the docs, the example, or the `lib/` of `fuery` or `fuery_core`, which the demo is built from. The demo passes `--dart-define=fuery.demo=true`, which turns the devtools on in that release build.

## Rules for every change

- Keep `flutter analyze packages` at zero issues and `dart format` clean.
- Keep the `analyzer: exclude:` lists in the `analysis_options.yaml` of `fuery`, `fuery_hooks`, and the example. The latest `flutter pub get` adds any that are missing, and the modified checked-in file fails the publish dry-run.
- Keep 100% line coverage in every package. Mark truly unreachable defensive code with `// coverage:ignore-start` / `// coverage:ignore-end` and a comment explaining why it can't run.
- For a bug fix, write the failing test first and confirm it fails before fixing.
- Public entry points (the `Query`, `InfiniteQuery`, `Mutation`, and `NoVariablesMutation` constructors, their `observe()`, `QuerySlot`, `InfiniteQuerySlot`, `MutationSlot`, `QueriesSlot`, `MutationStateSlot`, `QueryClient.getData`/`setData`/`updateData`, `streamedQuery`, `QueryClient.watch`, `QueryPersist`, `InfiniteQueryPersist`, the widgets, and the hooks of `fuery_hooks`) must work without explicit type arguments. This includes apps that enable `strict-inference`: give a type parameter that only optional arguments use a bound, such as `TContext extends Object?`, so it falls back to the bound instead of failing inference. Both packages enable `strict-casts`, `strict-inference`, and `strict-raw-types`, so `packages/fuery_core/test/inference_test.dart` fails analysis or stops compiling if inference breaks; extend it for new entry points. The hooks are checked in `packages/fuery_hooks/test/hooks_test.dart`, which infers each hook's result without a context type and then assigns it to the expected type.
- `fuery_core` and `fuery` depend on nothing beyond Dart and Flutter: the SDKs and the Dart team's packages (`clock`, `collection`, `meta`). Anything that needs another package goes in a package of its own, as hooks do in `fuery_hooks` with `flutter_hooks`.
- Anything the Flutter widgets do, another adapter (hooks, another state library) must be able to do with the public API alone. Keep behavior in `fuery_core`: the widgets render through the core's slots (`ObserverSlot`) and add only Flutter plumbing. Don't hide exports that `fuery` itself needs; `packages/fuery_core/test/adapter_test.dart` renders queries through the public API without Flutter and must keep passing.
- Keep the public API to what apps and `fuery` use. Making something public later is not breaking, but hiding it is. Apps change the caches through `QueryClient` and observe them with `QueryClient.watch`; don't add public cache events or cache-mutating methods.
- Fetch outside widgets with `client.query` and `client.infiniteQuery`. Don't add `fetchQuery`, `prefetchQuery`, or `ensureQueryData`-style methods.
- `fuery_core`, `fuery`, and `fuery_hooks` are released together with the same version and follow semver: a breaking change bumps the major version, so prefer additions, and keep what is public public.
- To release, bump every version and the `fuery_core:` and `fuery:` constraints to `^X.Y.Z`, add a short CHANGELOG entry to each, merge to `main`, then push a tag `vX.Y.Z`. `.github/workflows/publish.yml` checks that the tag, versions, and changelogs match (`tool/check_versions.py`), dry-runs every package (CI runs the same dry-runs on every pull request; they fail on any pub warning, such as a checked-in file that `flutter pub get` rewrote), publishes the packages, core first, and creates a GitHub release from their `## X.Y.Z` CHANGELOG entries. A failed run can be re-run: it skips versions already on pub.dev. Don't publish or create releases by hand, except the first version of a new package, which pub.dev can't publish automatically: publish it by hand from a checkout of its tag, not from `main` (the steps are in the header of `publish.yml`).
- Update the READMEs and the docs site when public behavior changes, and make sure every code snippet compiles.

## Writing docs

- The logo, README banner, GitHub social preview, and icon live in `assets/brand/`. Edit the SVGs, then run `python3 assets/brand/render.py` to regenerate the PNGs. Palette: violet `#6B4EFF`, lime `#C6F542`, lavender `#C9BEFF`, ink `#14112B`.
- Keep README examples short and runnable against the real API.
- READMEs and the docs site describe the current API only. Don't add upgrade or migration guides.

## Commits

Use `type: summary` in the imperative, matching the history: `feat`, `fix`, `refactor`, `test`, `doc`, `chore`.
