part of 'core.dart';

/// A query as a widget or another adapter takes it: a [Query] the adapter
/// observes itself, or a [QueryObserver] that is already shared.
sealed class QuerySource<TData extends Object> {}

/// An infinite query as an adapter takes it: an [InfiniteQuery] or an
/// [InfiniteQueryObserver].
sealed class InfiniteQuerySource<TPage, TParam>
    implements QuerySource<InfiniteData<TPage, TParam>> {}

/// A mutation as an adapter takes it: a [Mutation] or a [MutationObserver].
sealed class MutationSource<TData, TVariables, TContext> {}

/// Holds the observer that an adapter, such as a widget or a hook, renders
/// from, for a source that can change on every render.
///
/// Call [update] on every render with the latest source. For a definition
/// ([Query], [InfiniteQuery], [Mutation]), the slot creates an observer once
/// and updates its options, so the observer keeps its state, such as the
/// previous data for `keepPreviousData`, and building the definition again
/// costs nothing. For an observer, the slot uses it as it is and leaves it
/// alone when disposed. A different client creates a new observer.
///
/// Read [result] while rendering: it is up to date as soon as [update]
/// returns. [subscribe] receives every later change, and stays subscribed
/// when [update] switches to another observer.
///
/// ```dart
/// final slot = QuerySlot(todosQuery, client);
/// final unsubscribe = slot.subscribe((result) => render(result));
/// slot.update(todosQuery, client); // on every render
/// render(slot.result);
/// ```
sealed class ObserverSlot<TSource, TResult> extends Subscribable<TResult> {
  /// The observer the slot renders from now. [update] replaces it when the
  /// source becomes another observer, the definition's client changes, or a
  /// definition replaces an observer.
  Object get observer;

  /// The result to render now.
  TResult get result;

  /// Points the slot at the latest [source] and [client].
  void update(TSource source, QueryClient client);

  /// Removes every listener, and destroys the observer if the slot created
  /// it.
  void dispose();
}

abstract class _Slot<TSource, TObserver extends Object, TResult>
    extends ObserverSlot<TSource, TResult> {
  _Slot(TSource source, QueryClient client) : _client = client {
    final shared = _sharedObserver(source);
    _owned = shared == null;
    _observer = shared ?? _create(source, client);
  }

  QueryClient _client;
  late TObserver _observer;
  late bool _owned;
  void Function()? _unsubscribe;

  @override
  TObserver get observer => _observer;

  @override
  void update(TSource source, QueryClient client) {
    final shared = _sharedObserver(source);
    if (shared != null) {
      if (!identical(shared, _observer)) _switchTo(shared, owned: false);
    } else if (!_owned || !identical(client, _client)) {
      _switchTo(_create(source, client), owned: true);
    } else {
      _setOptions(_observer, source);
    }
    _client = client;
  }

  @override
  void dispose() {
    clearListeners();
    _stopListening();
    if (_owned) _destroy(_observer);
  }

  @override
  void onSubscribe() {
    if (listeners.length == 1) _startListening();
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) _stopListening();
  }

  void _switchTo(TObserver next, {required bool owned}) {
    final listening = _unsubscribe != null;
    _stopListening();
    if (_owned) _destroy(_observer);
    _observer = next;
    _owned = owned;
    if (listening) _startListening();
  }

  void _startListening() {
    _unsubscribe = _listen(_observer, (result) {
      for (final listener in listeners) {
        listener(result);
      }
    });
  }

  void _stopListening() {
    _unsubscribe?.call();
    _unsubscribe = null;
  }

  /// The observer in [source], or null when [source] is a definition.
  TObserver? _sharedObserver(TSource source);

  TObserver _create(TSource definition, QueryClient client);

  void _setOptions(TObserver observer, TSource definition);

  void Function() _listen(
    TObserver observer,
    void Function(TResult result) listener,
  );

  void _destroy(TObserver observer);
}

/// An [ObserverSlot] for queries.
final class QuerySlot<TData extends Object> extends _Slot<QuerySource<TData>,
    QueryObserver<TData>, QueryResult<TData>> {
  QuerySlot(super.source, super.client);

  @override
  QueryResult<TData> get result => observer.getOptimisticResult();

  @override
  QueryObserver<TData>? _sharedObserver(QuerySource<TData> source) {
    return source is QueryObserver<TData> ? source : null;
  }

  @override
  QueryObserver<TData> _create(
    QuerySource<TData> definition,
    QueryClient client,
  ) {
    return (definition as Query<TData>).observe(client: client);
  }

  @override
  void _setOptions(
    QueryObserver<TData> observer,
    QuerySource<TData> definition,
  ) {
    observer.setOptions(definition as Query<TData>);
  }

  @override
  void Function() _listen(
    QueryObserver<TData> observer,
    void Function(QueryResult<TData> result) listener,
  ) {
    return observer.subscribe(listener);
  }

  @override
  void _destroy(QueryObserver<TData> observer) => observer.destroy();
}

/// An [ObserverSlot] for infinite queries.
final class InfiniteQuerySlot<TPage, TParam> extends _Slot<
    InfiniteQuerySource<TPage, TParam>,
    InfiniteQueryObserver<TPage, TParam>,
    InfiniteQueryResult<TPage, TParam>> {
  InfiniteQuerySlot(super.source, super.client);

  @override
  InfiniteQueryResult<TPage, TParam> get result =>
      observer.getOptimisticResult();

  @override
  InfiniteQueryObserver<TPage, TParam>? _sharedObserver(
    InfiniteQuerySource<TPage, TParam> source,
  ) {
    return source is InfiniteQueryObserver<TPage, TParam> ? source : null;
  }

  @override
  InfiniteQueryObserver<TPage, TParam> _create(
    InfiniteQuerySource<TPage, TParam> definition,
    QueryClient client,
  ) {
    return (definition as InfiniteQuery<TPage, TParam>).observe(
      client: client,
    );
  }

  @override
  void _setOptions(
    InfiniteQueryObserver<TPage, TParam> observer,
    InfiniteQuerySource<TPage, TParam> definition,
  ) {
    observer.setOptions(definition as InfiniteQuery<TPage, TParam>);
  }

  @override
  void Function() _listen(
    InfiniteQueryObserver<TPage, TParam> observer,
    void Function(InfiniteQueryResult<TPage, TParam> result) listener,
  ) {
    return observer.subscribe(
      (result) => listener(result as InfiniteQueryResult<TPage, TParam>),
    );
  }

  @override
  void _destroy(InfiniteQueryObserver<TPage, TParam> observer) {
    observer.destroy();
  }
}

/// An [ObserverSlot] for mutations.
final class MutationSlot<TData, TVariables, TContext> extends _Slot<
    MutationSource<TData, TVariables, TContext>,
    MutationObserver<TData, TVariables, TContext>,
    MutationResult<TData, TVariables, TContext>> {
  MutationSlot(super.source, super.client);

  @override
  MutationResult<TData, TVariables, TContext> get result => observer.result;

  @override
  MutationObserver<TData, TVariables, TContext>? _sharedObserver(
    MutationSource<TData, TVariables, TContext> source,
  ) {
    return source is MutationObserver<TData, TVariables, TContext>
        ? source
        : null;
  }

  @override
  MutationObserver<TData, TVariables, TContext> _create(
    MutationSource<TData, TVariables, TContext> definition,
    QueryClient client,
  ) {
    return (definition as Mutation<TData, TVariables, TContext>).observe(
      client: client,
    );
  }

  @override
  void _setOptions(
    MutationObserver<TData, TVariables, TContext> observer,
    MutationSource<TData, TVariables, TContext> definition,
  ) {
    observer.setOptions(definition as Mutation<TData, TVariables, TContext>);
  }

  @override
  void Function() _listen(
    MutationObserver<TData, TVariables, TContext> observer,
    void Function(MutationResult<TData, TVariables, TContext> result) listener,
  ) {
    return observer.subscribe(listener);
  }

  // A mutation observer holds nothing to release: its runs finish on their
  // own, and unsubscribing detaches it from its mutation.
  @override
  void _destroy(MutationObserver<TData, TVariables, TContext> observer) {}
}
