# Fuery playground

A web app with one page per idea of Fuery. Each scenario shows a query or a
mutation next to the state its widget receives, a timeline of what happened,
and the code that drives it. It runs at
[galaxykhh.github.io/fuery/demo](https://galaxykhh.github.io/fuery/demo/),
and each scenario has its own address, such as `/fuery/demo/#/lifecycle`.

## Running it

From the repository root, resolve the workspace once, then run the app in
Chrome:

```bash
flutter pub get
cd packages/fuery/playground
flutter run -d chrome
```

The devtools button is on in every build, the release build included.

## Scenarios

| Route | Scenario | What it shows |
|---|---|---|
| `#/lifecycle` | [Query lifecycle](lib/scenarios/lifecycle.dart) | Fresh turning stale with `staleTime`, refetch, invalidate, and the app going to the background and back. A `QueryListener` writes each change to the timeline. |
| `#/shared-cache` | [One key, one request](lib/scenarios/shared_cache.dart) | Three widgets with one definition share one request. When the last one unmounts, the entry leaves the cache after `gcTime`. |
| `#/retries` | [Retries](lib/scenarios/retries.dart) | Retries with a short `retryDelay`, `failureCount` and `failureReason` while they run, and the error once they run out. |
| `#/offline` | [Offline](lib/scenarios/offline.dart) | A fetch that pauses offline and keeps its data, and a mutation that waits and runs on reconnect before the list refetches. |
| `#/optimistic` | [Optimistic updates](lib/scenarios/optimistic.dart) | A todo added to the cache in `onMutate` and taken out in `onError`. A `MutationStateSelector` counts the runs, and a `MutationStateListener` reports failures. |
| `#/pagination` | [Keeping the previous page](lib/scenarios/pagination.dart) | `placeholderData: keepPreviousData` and `isPlaceholderData` while the next page loads. |
| `#/infinite` | [Infinite query](lib/scenarios/infinite.dart) | `fetchNextPage`, `hasNextPage`, and `isFetchingNextPage`. |
| `#/persistence` | [Surviving a restart](lib/scenarios/persistence.dart) | A `QueryStorage` that outlives "Restart app", and data restored with its old `dataUpdatedAt`. |

## How it works

- Each scenario runs on a `QueryClient` of its own under a `FueryProvider`, against a fake server of its own ([`lib/session.dart`](lib/session.dart)). Reset replaces both, so a scenario starts over clean.
- The fake server ([`lib/fake_server.dart`](lib/fake_server.dart)) keeps its data in memory. The page sets its latency and how many of the next requests fail, and shows how many requests it received. The timeline lists each request and each change the scenario reports.
- The code panel reads the scenario's own file, declared as an asset in `pubspec.yaml`, and shows the lines between each `// #region snippet` and `// #endregion`. The code on screen is the code that runs.
- The shared widgets live in [`lib/widgets/`](lib/widgets): the state panels, the timeline, the controls, and the code panel.

## Adding a scenario

1. Add a file to `lib/scenarios/` with a `Scenario` and its widget, and mark the code to show with `// #region snippet` and `// #endregion`.
2. Add the scenario to `scenarios` in [`lib/app.dart`](lib/app.dart). Its `path` is its route.
3. Add a widget test to `test/` that opens it with `pumpPlayground` from [`test/helpers.dart`](test/helpers.dart) and checks what it shows. The 360 px layout test in `test/app_test.dart` covers the new scenario on its own.

```bash
flutter test
```
