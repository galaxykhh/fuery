# Fuery

Server state caching for Flutter, with widgets that work like `flutter_bloc`. This is a pub workspace with two published packages:

- `packages/fuery_core`: pure Dart core (queries, infinite queries, mutations, cache, retries). No Flutter imports.
- `packages/fuery`: Flutter widgets, app lifecycle binding, and `FueryProvider`. Re-exports `fuery_core`.
- `packages/fuery/example`: todo app with a widget test.

Each package has its own `AGENTS.md` with package-specific rules.

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

## Rules for every change

- Keep `flutter analyze packages` at zero issues and `dart format` clean.
- Keep 100% line coverage in both packages. Mark truly unreachable defensive code with `// coverage:ignore-start` / `// coverage:ignore-end` and a comment explaining why it can't run.
- For a bug fix, write the failing test first and confirm it fails before fixing.
- Public entry points (`Query.use`, `InfiniteQuery.use`, `Mutation.use`, `Mutation.noParam`, `infiniteQueryOptions`) must work without explicit type arguments. `packages/fuery_core/test/inference_test.dart` stops compiling if inference breaks; extend it for new entry points.
- Fetch outside widgets with `client.query` and `client.infiniteQuery`. Don't add `fetchQuery`, `prefetchQuery`, or `ensureQueryData`-style methods.
- `fuery` and `fuery_core` are released together with the same version. Breaking changes are allowed before 1.0.
- Update the READMEs when public behavior changes, and make sure every code snippet in them compiles.

## Writing docs

- Describe Fuery on its own terms: what it does and how it fits Flutter and bloc. Don't compare it with other libraries or call it a port.
- Keep README examples short and runnable against the real API.
- READMEs describe the current API only. Don't add upgrade or migration guides.

## Commits

Use `type: summary` in the imperative, matching the history: `feat`, `fix`, `refactor`, `test`, `doc`, `chore`. Don't add AI co-author or tool attribution trailers to commit messages.
