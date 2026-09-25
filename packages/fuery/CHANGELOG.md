## 1.5.1
- Released with `fuery_core` 1.5.1. A widget given a definition built in `build`, such as `QueryBuilder`, `QueriesBuilder`, or `MutationBuilder`, rebuilds faster: it no longer hashes its key each time. `MutationStateBuilder`, `MutationStateListener`, and `MutationStateSelector` stay fast with many runs in the cache.

## 1.5.0
- Add `MutationStateBuilder`, `MutationStateListener`, and `MutationStateSelector`, which show or hear every run of a mutation, wherever the run was started. Each takes `mutation:`, a `Mutation` whose runs it finds by `mutationKey`, or `MutationFilters`. They work in a `StatelessWidget`, without sharing an observer. `MutationStateListener` is called once for each run that changes, and never for the states runs had when it mounted.
- Report errors that listeners throw to the client's `onUncaughtError`, if it has one. Before, its error always went to the zone. Listener widgets and consumers now listen through `ObserverSlot.listen`.
- Fix: a listener that throws no longer skips the rebuild of a `QueryConsumer`, `InfiniteQueryConsumer`, or `MutationConsumer`.
- Fix: a listener no longer hears a change that the widget's previous observer had queued, as after the provided client was replaced.
- Fix: listener widgets and consumers are no longer called on mount for a state the query already had, such as while a persisted query's restore is still reading, or when they join a fetch that already failed.
- Point the debug warning for a `MutationListener` given a `Mutation` definition to `MutationStateListener` with a `mutationKey` first, then to `MutateOptions`, then to one shared observer.
- Update the example: it reports every failed like, also when likes overlap. It keeps the comments queued on a post listed after you leave the post, and runs "mark all read" from a `MutationBuilder`.
- Released with `fuery_core` 1.5.0, which renames Fuery's focus manager class to `FueryFocusManager`. `package:fuery/fuery.dart` exports it, and still exports the deprecated `FocusManager` alias, which clashes with Flutter's. In a file that also imports Flutter, write `primaryFocus` or `WidgetsBinding.instance.focusManager`, or hide `FocusManager`.

## 1.4.4
- Fix: when the provided client and a query's key change in the same frame, the new key is no longer fetched on the old client.
- Debug warnings: a `MutationListener` given a `Mutation` definition, whose runs it can never hear, and a widget given an observer of another client than the one it uses, once per widget and key. The warning about observers created on every rebuild also covers `QueriesBuilder` and `QueriesSelector`, names the widget, and explains the effect for mutations.
- Devtools: the button sits halfway down the right edge by default, so it no longer covers a floating action button. The panel stays above the on-screen keyboard while there is room for its tabs and filter field, and goes under it otherwise. It keeps the filter text across tabs and the query list's scroll position, and disposes its overlay entry.
- Released together with `fuery_core`'s fixes, among them: a listener that throws no longer freezes `QueriesBuilder` or other widgets notified in the same batch or sharing its observer, a query that awaits a cancelled query no longer loads forever, and refetches (including the devtools buttons) skip queries that only `setQueryData` wrote.

## 1.4.3
- Released together with the first version of `fuery_hooks`, which renders queries and mutations with `flutter_hooks`. No changes in `fuery`.

## 1.4.2
- Released together with `fuery_core` 1.4.2, which adds `QueryClient.onUncaughtError` for errors that callbacks throw, and keeps a fetch successful when a `QueryCacheConfig` callback throws.

## 1.4.1
- Released together with `fuery_core` 1.4.1, which stores persisted queries under keys that are the same in every build, so queries with enums in their keys are restored after an app update, and stores persisted mutations whose keys hold enums.

## 1.4.0
- Add `QueriesBuilder` and `QueriesSelector`, which build from a list of queries of one data type at once, in order, such as one query per id. The example's search screen shows recently viewed posts with them.
- Released together with `fuery_core` 1.4.0, which adds `QueryClient.updateQueriesData` and `InfiniteData.mapPages`, and runs `MutateOptions` callbacks for observers without listeners. A mutation widget that unmounts still drops the callbacks of its calls.
- The example's like updates cached search results too, and the search screen shows like counts.

## 1.3.0
This release has breaking changes in a minor version, together with `fuery_core` 1.3.0, whose CHANGELOG lists what to write instead.

- Widgets take a definition: `QueryBuilder(query: todoQuery(id))`, `InfiniteQueryBuilder(query: feedQuery)`, `MutationBuilder(mutation: addTodo)`. The widget keeps one observer for it, follows a new key or new options on every rebuild, and shows the new key's cached data in that frame. Widgets still take an observer from `observe()`.
- Widgets that get a definition use the client of the nearest `FueryProvider`, and follow a provider whose client is replaced.
- Builders call the actions on the result: `state.refetch()`, `state.fetchNextPage()`, and `state.mutate(...)`.
- `FueryProvider.of(context, listen: true)` rebuilds the caller when the provided client is replaced, for widgets and hooks of your own.
- **Breaking:** the `query` and `mutation` fields of the widgets are typed `QuerySource`, `InfiniteQuerySource`, and `MutationSource`, and mutation widgets report a `MutationResult`.
- The example app defines every query and mutation once and passes them to widgets.

## 1.2.0
- Released together with `fuery_core` 1.2.0, which adds `observe()` to query and mutation options, `QueryClient.getData`, `setData`, and `updateData`, and renames `use` to `observe` and `noParam` to `noVariables`. The example app defines each query once as options.

## 1.1.1
- Released together with `fuery_core` 1.1.1, which fixes `fetchNextPage()` cancelling a refetch when there is no next page, `isFetchedAfterMount` for observers listened to after they were created, and expired persisted queries staying in the storage.

## 1.1.0
- In debug builds, a Fuery widget that gets a new observer for the same key on a rebuild, which is what `Query.use` in `build` looks like, prints a warning once per key with a link to the fix.
- Getting started ends with the first widget test, including the two lines that keep cache timers from failing it.

## 1.0.0
- The public API is stable: from here, a breaking change bumps the major version. No changes since 0.10.0.

## 0.10.0
- Includes `fuery_core` 0.10.0: mutations with `persist` survive a restart. The example's offline comment is sent after the app is opened again.

## 0.9.0
- **Breaking:** includes `fuery_core` 0.9.0: boolean reads such as `query.isStale` and `focusManager.isFocused` are getters, and API that only the package called is removed.

## 0.8.3
- Documentation only: a description and topics that match what people search for, a live demo at https://galaxykhh.github.io/fuery/demo/, and a new page on server state in Flutter.

## 0.8.2
- Documentation only: the README leads with how Fuery fits an existing app, and the example is now a gallery with one screen per case.

## 0.8.1
- Includes `fuery_core` 0.8.1: no inference failures in apps that enable `strict-inference`.

## 0.8.0
- Fix the devtools panel: it follows a replaced provider client, works with the iOS text selection toolbar, keeps the app's state when toggled, and labels disabled queries.
- Fix: mutation widgets show the latest state when they mount again, and `FueryBinding.ensureInitialized` works before the Flutter binding exists.
- Includes `fuery_core` 0.8.0.

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
