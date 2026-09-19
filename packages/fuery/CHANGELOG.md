## 0.7.0
- Includes `fuery_core` 0.7.0, which keeps cache internals private. `QueryClient.watch` replaces cache event subscriptions.

## 0.6.0
- Add `FueryDevtools` and `FueryDevtoolsPanel` to inspect queries and mutations in debug and profile builds.
- Includes `fuery_core` 0.6.0: `Fuery.client`, which mounts the client when assigned.

## 0.5.0
- Includes `fuery_core` 0.5.0: persisting query data with `QueryStorage` and `QueryPersist`.

## 0.4.0
- Add `QuerySelector`, `InfiniteQuerySelector`, and `MutationSelector`, which rebuild only when a selected value changes.
- Includes `fuery_core` 0.4.0: `refetchWhile`, `QueryClient.watch`, and `streamedQuery`.

## 0.3.2
- Read query data with pattern matching in the README and examples, instead of `state.data!`.

## 0.3.1
- Update the package description and README, and link the documentation site at https://galaxykhh.github.io/fuery/.

## 0.3.0
- Rebuild the widgets on the new `fuery_core`: `Builder`, `Listener`, and `Consumer` for queries, infinite queries, and mutations, with `buildWhen` and `listenWhen`. Most APIs changed; see the README.
- Add `FueryProvider`, and refetch stale queries when the app resumes.

## 0.0.1
- chore: Fuery initial release
