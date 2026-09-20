---
title: Streamed queries
description: "Cache a stream in Flutter: show chunks as they arrive, then keep the result."
---

`streamedQuery` turns a `Stream` into a query function and folds each chunk into the query data. Use it when a response arrives in chunks: a streamed answer, a progress log, a file being processed.

```dart
final answer = Query.use(
  queryKey: ['answer', question],
  queryFn: streamedQuery(
    stream: (context) => api.ask(question),
    initialValue: '',
    combine: (text, token) => text + token,
  ),
);
```

- **The query succeeds with the first chunk.** Widgets show the data as it grows, while `isFetching` stays true until the stream is done.
- **`combine` works like `Stream.fold`.** It adds one chunk to the value so far, starting from `initialValue`. The data type comes from `initialValue`, so the call needs no type arguments.
- **An empty stream** succeeds with `initialValue`.
- **An error** in the stream or in `combine` fails the query, and the chunks received so far stay in `data`. Retries work like any other query: each attempt starts a new stream and follows `refetchMode`.

Use it for streams that end. A connection that stays open, like a live feed, isn't a fetch and doesn't fit a query.

## Collecting chunks in a list

```dart
final log = Query.use(
  queryKey: ['jobs', id, 'log'],
  queryFn: streamedQuery(
    stream: (context) => api.jobLog(id),
    initialValue: const <LogLine>[],
    combine: (lines, line) => [...lines, line],
  ),
);
```

## Refetching a streamed query

When the query fetches again, for example after `invalidateQueries`, `refetchMode` decides what happens to the data it already has:

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

Cancelling the fetch cancels the stream, for example with `cancelQueries`. A refetch that replaces it does the same.

When the last widget stops using the query, the stream keeps running by default and its result is cached, so a streamed answer is complete when the user comes back. To stop it instead, read `context.signal` in `stream`, the same way any query function becomes cancellable:

```dart
stream: (context) {
  final request = api.startAnswer(question); // a request you can cancel
  context.signal.onAbort(request.cancel);
  return request.tokens;
},
```

## In the example app

The example has a streamed answer in [the streamed answer screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/streaming_answer/streaming_answer.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
