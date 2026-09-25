---
title: Devtools
description: Inspect the Flutter query cache while the app runs, on a device or in the browser.
---

`FueryDevtools` shows what a client's cache holds while the app runs. For each query, it shows the status and the data, with buttons to refetch, invalidate, reset, or remove the query. For each mutation run, it shows the status, variables, and error. It adds a button over your app that opens the panel.

## Adding the devtools

Put `FueryDevtools` in your app's `builder`, so it stays above every route:

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

It appears in debug and profile builds. A release build shows only your app.

The example app adds it in [its app widget](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/app.dart).

## The Queries tab

The Queries tab lists every query in the cache, one row per key, with its status and its number of [observers](../../how-the-cache-works/#observers). Each widget that got the query counts once, and so does each observer from `observe()`. Type in the filter to find a key.

| Status | Meaning |
|---|---|
| `fetching` | A fetch is running |
| `paused` | A fetch is waiting for the network, or for the app to return to the foreground to retry |
| `inactive` | No observer uses it. Fuery removes it after `gcTime` |
| `disabled` | Every observer has `enabled: false`, so it doesn't fetch on its own |
| `stale` | In use, and Fuery refetches it the next time a widget starts using it, the app returns to the foreground, or the network reconnects |
| `fresh` | In use, its data was updated within its `staleTime`, and it hasn't been invalidated |

Select a query to see its status, observers, last update, failure count, error, and data. Data shows as JSON, through `toJson()` where an object has one and `toString()` otherwise.

The buttons act on the selected query:

| Button | What it does |
|---|---|
| Refetch | Fetches it again, like [`refetchQueries`](../../reference/query-client/#operations-on-matching-queries), which skips a disabled query, a static query with data, and a query that only `setQueryData` wrote |
| Invalidate | Marks it stale. If an enabled observer uses it, Fuery refetches it as Refetch does |
| Reset | Returns it to its initial state and deletes its [persisted data](../persistence/). If an enabled observer uses it, Fuery refetches it as Refetch does |
| Remove | Removes it from the cache and deletes its persisted data. A widget still using it loads it again |

## The Mutations tab

The Mutations tab lists every [mutation run](../../how-the-cache-works/#mutation-runs), newest first, with its status, key, variables, and error.

## FueryDevtools options

| Option | Type | Default | What it does |
|---|---|---|---|
| `child` | `Widget` | Required | Your app |
| `client` | `QueryClient?` | `context.queryClient` | The client to inspect |
| `enabled` | `bool` | `!kReleaseMode` | Whether to show anything besides your app |
| `buttonAlignment` | `Alignment` | `Alignment.centerRight` | Where the button sits |
| `initiallyOpen` | `bool` | `false` | Whether the panel starts open |

## The panel without the button

`FueryDevtoolsPanel` is the same panel without the button. Show it on a screen of your own, such as a debug menu:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const Scaffold(
      body: SafeArea(child: FueryDevtoolsPanel()),
    ),
  ),
);
```

It takes a `client`, which defaults to `context.queryClient`, and an `onClose` callback, which adds a close button.
