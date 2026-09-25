---
title: Devtools
description: Inspect the Flutter query cache while the app runs, on a device or in the browser.
---

`FueryDevtools` shows every query and mutation of a client while the app runs: their status, their data, and buttons to refetch or clear them. It adds a button over your app that opens the panel.

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
| `stale` | In use, and refetches on the next trigger |
| `fresh` | In use, and younger than its `staleTime` |

Select a query to see its status, observers, last update, failure count, error, and data. Data shows as JSON, through `toJson()` where an object has one and `toString()` otherwise.

The buttons act on the selected query:

| Button | What it does |
|---|---|
| Refetch | Fetches it again, like [`refetchQueries`](../../reference/query-client/#operations-on-matching-queries), which skips a disabled query, a static query with data, and a query that only `setQueryData` wrote |
| Invalidate | Marks it stale. Fuery refetches it if it's in use |
| Reset | Returns it to its initial state and deletes its [persisted data](../persistence/). Fuery refetches it if it's in use |
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
