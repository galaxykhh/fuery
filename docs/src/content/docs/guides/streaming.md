---
title: Streaming
description: Show data from a stream as it arrives.
---

Some responses arrive in chunks: a streamed answer, a progress log, a file being processed. `streamedQuery` builds a query function from such a `Stream` and folds each chunk into the query data:

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
- **`combine` works like `Stream.fold`.** It adds one chunk to the value so far, starting from `initialValue`. The data type comes from `initialValue`, so you don't need type arguments.
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

## Fetching again

When the query fetches again, for example after `invalidateQueries`, `refetchMode` decides what happens to the data it already has:

| Mode | While the new stream runs | When it's done |
|---|---|---|
| `StreamRefetchMode.reset` (default) | The data is cleared, and the query is pending until the first chunk | The new data |
| `StreamRefetchMode.append` | New chunks are folded onto the existing data | The combined data |
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

The stream is cancelled when its fetch is cancelled, for example with `cancelQueries`, or when a refetch replaces it.

When the last widget stops using the query, the stream keeps running by default and its result is cached, so a streamed answer is complete when the user comes back. To stop it instead, read `context.signal` in `stream`, the same way any query function becomes cancellable:

```dart
stream: (context) {
  final request = api.ask(question);
  context.signal.onAbort(request.cancel);
  return request.stream;
},
```
