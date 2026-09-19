---
title: Devtools
description: Inspect queries and mutations while developing.
---

`FueryDevtools` adds a button over your app. It opens a panel with every query and mutation of the client: their status, their data, and buttons to refetch or clear them.

## Add it

Put it in your app's `builder`, so it stays above every route:

```dart
MaterialApp(
  builder: (context, child) => FueryDevtools(child: child!),
  home: const HomeScreen(),
)
```

It only appears in debug and profile builds. In release builds it shows just your app, and its code is left out of the build.

## Queries

The Queries tab lists every query with its key, its status, and how many observers use it. Each `Query.use` object counts once, however many widgets or listeners it has. Type in the filter to find a key.

| Status | Meaning |
|---|---|
| `fetching` | A fetch is running |
| `paused` | A fetch is waiting for the network, or for the app to return to the foreground to retry |
| `inactive` | Nothing uses it; it's removed after `gcTime` |
| `disabled` | Used only with `enabled: false`, so it doesn't fetch on its own |
| `stale` | Used, and would refetch on the next trigger |
| `fresh` | Used, and fresh for its `staleTime` |

Select a query to see its state, when its data was last updated, its failure count and error, and its data. Data is shown as JSON, using `toJson()` where objects have it, and `toString()` otherwise.

The buttons act on the selected query:

| Button | Does |
|---|---|
| Refetch | Fetches it again |
| Invalidate | Marks it stale, which refetches it if it's in use |
| Reset | Returns it to its initial state and deletes its [persisted data](../persistence/) |
| Remove | Removes it from the cache and deletes its persisted data |

## Mutations

The Mutations tab lists mutations, newest first, with their status, key, variables, and error.

## Options

| Option | Default | |
|---|---|---|
| `client` | `context.queryClient` | The client to inspect |
| `enabled` | `!kReleaseMode` | Whether to show anything besides your app |
| `buttonAlignment` | `Alignment.bottomRight` | Where the button sits |
| `initiallyOpen` | `false` | Whether the panel starts open |

## On your own screen

`FueryDevtoolsPanel` is the panel without the button, for example for a debug menu:

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
