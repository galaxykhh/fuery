---
title: Streamed queries
description: "Cache a stream in Flutter: show chunks as they arrive, then keep the result."
---

`streamedQuery` turns a `Stream` into a query function. The screen shows the data while chunks arrive. The cache keeps the result when the stream ends.

Use it for a response that arrives in chunks and then ends: a streamed answer, a progress log, a file being processed. A connection that stays open, such as a live feed, isn't a fetch and doesn't fit a query.

```dart
final answer = Query(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

- **The query succeeds with the first chunk.** Widgets show the data as it grows.
- **`isFetching` stays true until the stream is done.**
- **`combine` works like `Stream.fold`.** It adds one chunk to the value so far, starting from `initialValue`.
- **`initialValue` sets the data type**, so the call needs no type arguments.
- **An empty stream succeeds with `initialValue`.**
- **An error in the stream or in `combine` fails the query.** `data` keeps the chunks received so far.
- **Each retry starts a new stream** and follows `refetchMode`. The default mode clears the data first.

The `Query` takes the other [query options](../../reference/query-options/) as usual, such as `staleTime`.

## Collecting chunks in a list

Start from an empty list and add each chunk to it:

```dart
final log = Query(
  queryKey: ['jobs', id, 'log'],
  queryFn: streamedQuery(
    stream: (context) => api.jobLog(id),
    initialValue: const <LogLine>[],
    combine: (lines, line) => [...lines, line],
  ),
);
```

## Refetching a streamed query

`refetchMode` decides what happens to the cached data when the query fetches again, for example after `invalidateQueries`:

| Mode | While the new stream runs | When it's done |
|---|---|---|
| `StreamRefetchMode.reset` (default) | Fuery clears the data, and the query is pending until the first chunk | The new data |
| `StreamRefetchMode.append` | Fuery folds new chunks onto the existing data | The combined data |
| `StreamRefetchMode.replace` | The old data stays on screen | The new data, all at once |

```dart
queryFn: streamedQuery(
  stream: (context) => api.ask(question),
  initialValue: '',
  combine: (text, token) => text + token,
  refetchMode: StreamRefetchMode.replace,
),
```

## Stopping the stream

Fuery cancels the stream when it cancels the fetch: on `cancelQueries`, or when a refetch replaces the running fetch.

By default, the stream keeps running when no widget uses the query, and Fuery caches the result. A streamed answer is then complete when the user comes back. To stop the stream instead, read `context.signal` in `stream`, which makes the fetch [cancellable](../queries/#cancelling-a-request):

```dart
stream: (context) {
  final request = api.startAnswer(question); // a request you can cancel
  context.signal.onAbort(request.cancel);
  return request.tokens;
},
```

## In the example app

The example streams a thread summary in [the post screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/post/post_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
