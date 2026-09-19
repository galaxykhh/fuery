---
title: App lifecycle and network
description: Refetch when the app resumes, and pause while offline.
---

## App lifecycle

Fuery widgets connect `AppLifecycleState` to Fuery automatically:

| App state | Fuery treats the app as |
|---|---|
| `resumed` | Focused |
| `hidden`, `paused`, `detached` | Not focused |
| `inactive` | Unchanged. Brief interruptions like a system dialog don't count. |

When the app becomes focused again, stale queries in use refetch. While it isn't focused, retries wait and polling pauses, unless `refetchIntervalInBackground` is set.

`refetchOnFocus` controls this per query: `RefetchMode.ifStale` (default), `RefetchMode.always`, or `RefetchMode.never`.

## Network

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

`networkMode` changes this per query or mutation:

| Mode | Behavior |
|---|---|
| `NetworkMode.online` | Default. Fetch only while online. |
| `NetworkMode.always` | Ignore connectivity, for example for local databases. |
| `NetworkMode.offlineFirst` | Try once regardless, then pause retries while offline. Useful when a cache layer can answer offline. |
