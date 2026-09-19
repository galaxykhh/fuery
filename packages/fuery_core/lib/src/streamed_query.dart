part of 'core.dart';

/// What [streamedQuery] does with the data it already has when it fetches
/// again.
enum StreamRefetchMode {
  /// Clears the data and folds the new stream from `initialValue`. The query
  /// is pending until the first chunk arrives.
  reset,

  /// Keeps the data and folds the new stream onto it.
  append,

  /// Keeps showing the data and replaces it once the new stream is done.
  replace,
}

/// Builds a query function that folds a [Stream] into the query data, for
/// streams that end, such as a streamed answer or a progress log.
///
/// The query succeeds with the first chunk and keeps fetching until the stream
/// is done, so widgets show the data as it arrives. [combine] adds each chunk
/// to the value so far, starting from [initialValue]:
///
/// ```dart
/// final answer = Query.use(
///   queryKey: ['answer', question],
///   queryFn: streamedQuery(
///     stream: (context) => api.ask(question),
///     initialValue: '',
///     combine: (text, token) => text + token,
///   ),
/// );
/// ```
///
/// The stream is cancelled when the fetch is cancelled. Like any query
/// function, it keeps running when the last listener goes away, unless
/// [stream] reads `context.signal`.
QueryFn<TData> streamedQuery<TChunk, TData extends Object>({
  required Stream<TChunk> Function(QueryFunctionContext context) stream,
  required TData initialValue,
  required TData Function(TData value, TChunk chunk) combine,
  StreamRefetchMode refetchMode = StreamRefetchMode.reset,
}) {
  return (context) {
    final client = context.client;
    final queryKey = context.queryKey;
    final query = client.queryCache.get(hashKey(queryKey)) as Query<TData>?;
    final hasData = query?.state.data != null;
    final replace = hasData && refetchMode == StreamRefetchMode.replace;

    if (hasData && refetchMode == StreamRefetchMode.reset) {
      query!._setState(query.state.copyWith(
        data: null,
        error: null,
        status: QueryStatus.pending,
      ));
    }

    final completer = Completer<TData>();
    StreamSubscription<TChunk>? subscription;
    var replacement = initialValue;

    void fail(Object error, [StackTrace? stackTrace]) {
      subscription?.cancel().ignore();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    subscription = stream(context).listen(
      (chunk) {
        try {
          if (replace) {
            replacement = combine(replacement, chunk);
          } else {
            final value = client.getQueryData<TData>(queryKey) ?? initialValue;
            client.setQueryData<TData>(queryKey, combine(value, chunk));
          }
        } catch (error, stackTrace) {
          fail(error, stackTrace);
        }
      },
      onError: fail,
      onDone: () {
        if (completer.isCompleted) return;
        completer.complete(
          replace
              ? replacement
              : client.getQueryData<TData>(queryKey) ?? initialValue,
        );
      },
      cancelOnError: true,
    );
    // A synchronous stream can fail while listen() is still running.
    if (completer.isCompleted) subscription.cancel().ignore();

    // Stop when the fetch is cancelled, without making the query function
    // cancellable on unmount.
    final signal = context._peekSignal?.call();
    signal?.onAbort(() => fail(signal.reason ?? const CancelledError()));

    return completer.future;
  };
}
