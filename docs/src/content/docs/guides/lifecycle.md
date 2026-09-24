---
title: Refetching automatically
description: Refetch when a Flutter app resumes, pause while offline, and resume when the network reconnects.
---

Fuery refetches stale data on its own at two moments: when the app comes back
to the foreground, and when the network reconnects. The first works out of the
box; the second needs a connectivity source.

## When the app resumes

Fuery widgets connect `AppLifecycleState` for you:

| App state | Fuery treats the app as |
|---|---|
| `resumed` | Focused |
| `hidden`, `paused`, `detached` | Not focused |
| `inactive` | Unchanged. Brief interruptions like a system dialog don't count. |

When the app is focused again, stale queries that widgets use refetch. While it isn't focused, retries wait and polling pauses, unless you set `refetchIntervalInBackground`.

`refetchOnFocus` controls this per query: `RefetchMode.ifStale` (default), `RefetchMode.always`, or `RefetchMode.never`.

`focusManager` is the same switch underneath. `focusManager.setFocused(false)` reports the app as hidden and `setFocused(null)` hands control back, which is how a test simulates backgrounding. `focusManager.isFocused` reads the current state. Outside Flutter, `focusManager.setEventListener` connects whatever your host uses, the way the network source below does.

An app that uses queries only from blocs has no Fuery widget to connect the lifecycle, so call this once at startup:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FueryBinding.ensureInitialized();
  runApp(const App());
}
```

## When the network reconnects

Fuery assumes the device is online. To pause fetches while offline and refetch on reconnect, connect a connectivity source, for example [`connectivity_plus`](https://pub.dev/packages/connectivity_plus):

```dart
onlineManager.setEventListener((setOnline) {
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    setOnline(!results.contains(ConnectivityResult.none));
  });
  return subscription.cancel;
});
```

While offline, a query that needs to fetch reports `fetchStatus: paused` and keeps showing its data. Mutations started offline wait and run when the connection returns.

When the connection returns, Fuery resumes the paused mutations first and refetches queries after they are done, so a refetch can't overwrite an optimistic update. A query still loading its first data doesn't wait for them: it resumes right away. The same happens when the app returns to the foreground.

`onlineManager.isOnline` reads what Fuery currently believes, which is `true` until a source says otherwise.

`networkMode` changes this per query or mutation:

| Mode | Behavior |
|---|---|
| `NetworkMode.online` | Default. Fetch only while online. |
| `NetworkMode.always` | Ignore connectivity, for example for local databases. |
| `NetworkMode.offlineFirst` | Try once regardless, then pause retries while offline. Useful when a cache layer can answer offline. |
