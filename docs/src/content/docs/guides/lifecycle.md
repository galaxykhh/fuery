---
title: Automatic refetching
description: Refetch stale data when a Flutter app resumes, pause while offline, and resume when the network reconnects.
---

Fuery refetches stale data when the app returns to the foreground and when the network reconnects, so screens catch up without a pull to refresh. Fuery widgets, hooks, and `FueryProvider` connect the app lifecycle for you. For connectivity, connect a source with `onlineManager.setEventListener`.

## When the app resumes

Fuery maps each `AppLifecycleState` to focus:

| App state | Fuery treats the app as |
|---|---|
| `resumed` | Focused |
| `hidden`, `paused`, `detached` | Not focused |
| `inactive` | Unchanged. Brief interruptions like a system dialog don't count. |

- When the app is focused again, Fuery refetches every stale query in use, such as one a mounted widget shows.
- While the app isn't focused, retries wait.
- Polling stops in the background too, unless the query sets `refetchIntervalInBackground`.
- `refetchOnFocus` sets this per query: `RefetchMode.ifStale` (default), `RefetchMode.always`, or `RefetchMode.never`.

`focusManager`, a `FueryFocusManager`, holds the focus state. It tracks whether the app is in the foreground, not keyboard focus:

| Member | What it does |
|---|---|
| `setFocused(false)` | Reports the app as in the background. A test uses it to simulate backgrounding. |
| `setFocused(null)` | Drops the state set by hand. The app counts as focused until the event source reports a change. |
| `isFocused` | Whether Fuery treats the app as focused. `true` until something reports otherwise. |
| `setEventListener(setup)` | Replaces the focus source, including the one `FueryBinding` connects. Outside Flutter, connect whatever your host provides. `setup` receives `setFocused` and returns a cleanup function or `null`. |

An app that uses queries only from blocs, without a `FueryProvider`, has nothing that connects the lifecycle. Call this once at startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## When the network reconnects

Fuery treats the device as online until a source reports otherwise. To pause fetches while offline and refetch on reconnect, connect a connectivity source, for example [`connectivity_plus`](https://pub.dev/packages/connectivity_plus):

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

While the device is offline:

- A query that needs to fetch reports `FetchStatus.paused` and keeps showing its data.
- A mutation started offline waits, and runs when the connection returns.

When the connection returns, Fuery resumes the paused mutations first. It refetches queries after the mutations finish, so a refetch can't overwrite an optimistic update. A query still loading its first data doesn't wait: it resumes right away. Fuery runs the same steps when the app returns to the foreground.

`onlineManager` holds the connectivity state:

| Member | What it does |
|---|---|
| `setEventListener(setup)` | Connects a connectivity source. `setup` receives `setOnline` and returns a cleanup function or `null`. A new source replaces the previous one. |
| `setOnline(online)` | Reports connectivity by hand, for example from a debug switch or a test. |
| `isOnline` | Whether Fuery treats the device as online. `true` until a source reports otherwise. |

`networkMode` sets how a query or a mutation reacts to connectivity:

| Mode | Behavior |
|---|---|
| `NetworkMode.online` | Default. Fetches and retries only while online. |
| `NetworkMode.always` | Ignores connectivity, for example for a local database. A query in this mode refetches on reconnect only when `refetchOnReconnect` is set. |
| `NetworkMode.offlineFirst` | Runs the first attempt regardless, then pauses retries while offline. Suits a request that a cache layer can answer offline. |

## Resuming mutations that paused offline

Fuery resumes a mutation paused offline when the app is focused again or the network reconnects. To resume at another moment, call `resumePausedMutations`:

```dart
await client.resumePausedMutations();
```

- It resumes every paused mutation on the client.
- It does nothing while the device is offline.
- A paused mutation is lost when the app restarts, unless it has a `persist`. See [Persisting mutations](../persistence/#persisting-mutations).

## In the example app

The wifi button in [the home shell](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/home/home_shell.dart) stands in for a connectivity source: it reports connectivity with `onlineManager.setOnline`. A comment written offline on [the post screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart) pauses, and sends when the app is back online.
