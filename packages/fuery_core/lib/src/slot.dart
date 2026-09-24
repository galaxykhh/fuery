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

/// What a [MutationStateSlot] finds runs by: a [Mutation] definition, for
/// every run with its `mutationKey`, typed like the definition, or
/// [MutationFilters], for the runs of any mutation that match them, typed
/// `Object?`.
sealed class MutationStateSource<TData, TVariables, TContext> {}

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
/// [subscribe] is for rendering. Its listeners run synchronously, sometimes
/// while another component renders, for example when one that mounts starts
/// a fetch. Wrap them in `notifyManager.batchCalls` when the framework can't
/// update during a render, so changes arrive in a microtask, and ignore the
/// ones that arrive after the slot is disposed. A [MutationStateSlot] is the
/// exception: it always calls them in a microtask.
///
/// [listen] is for side effects, such as navigation or a snackbar. Its
/// listeners run in a microtask, never during a render, with the result
/// before the change.
///
/// ```dart
/// final slot = QuerySlot(todosQuery, client);
/// final unsubscribe = slot.subscribe(notifyManager.batchCalls(render));
/// final stop = slot.listen((previous, current) {
///   if (!previous.isError && current.isError) showError(current.error);
/// });
/// slot.update(todosQuery, client); // on every render
/// render(slot.result);
/// ```
sealed class ObserverSlot<TSource, TResult> extends Subscribable<TResult> {
  /// The observer the slot renders from now. [update] replaces it when the
  /// source becomes another observer, the definition's client changes, or a
  /// definition replaces an observer. For a [MutationStateSlot], it is the
  /// client's [MutationCache], replaced only by another client.
  Object get observer;

  /// The result to render now.
  TResult get result;

  /// Points the slot at the latest [source] and [client].
  void update(TSource source, QueryClient client);

  /// Removes every listener, and destroys the observer if the slot created
  /// it.
  void dispose();

  /// Calls [listener] after each later change of [result], with the result
  /// it delivered before, for side effects such as navigation or a snackbar.
  /// Returns a function that stops it.
  ///
  /// Never called for [result] as it is now. Called in a microtask, or at the
  /// end of the outer `notifyManager.batch`, never during a render. A result
  /// equal to the previous one is not a change. When [update] moves the slot
  /// to another observer, it starts over from that observer's result, and
  /// changes the old one had queued are dropped. Listening subscribes like
  /// [subscribe], so a query fetches if it needs to. A listener that throws
  /// is reported to the client's `onUncaughtError`, or without it to the
  /// zone.
  void Function() listen(
    void Function(TResult previous, TResult current) listener,
  ) {
    final listening = _Listening<TResult>(result);
    _listenings.add(listening);
    final unsubscribe = subscribe((current) {
      final generation = _generation;
      notifyManager.schedule(() {
        if (!listening.active || generation != _generation) return;
        final previous = listening.previous;
        if (current == previous) return;
        listening.previous = current;
        _reportTo._guardCallback(() => listener(previous, current));
      });
    });
    return () {
      listening.active = false;
      _listenings.remove(listening);
      unsubscribe();
    };
  }

  /// Every [listen] that hasn't stopped.
  final List<_Listening<TResult>> _listenings = [];

  /// Counts the moves to another observer, so that changes the old one
  /// queued are dropped.
  int _generation = 0;

  /// The client that listener errors are reported to.
  QueryClient get _reportTo;

  /// Starts every [listen] over from [result], after a move to another
  /// observer.
  void _rebaseListenings() {
    if (_listenings.isEmpty) return;
    final current = result;
    for (final listening in _listenings) {
      listening.previous = current;
    }
  }

  void _dropListenings() {
    for (final listening in _listenings) {
      listening.active = false;
    }
    _listenings.clear();
  }
}

/// One [ObserverSlot.listen]: the result it delivered last, and whether it
/// still listens.
final class _Listening<TResult> {
  _Listening(this.previous);

  TResult previous;
  bool active = true;
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
  QueryClient get _reportTo => _client;

  @override
  void update(TSource source, QueryClient client) {
    final previous = _observer;
    final shared = _sharedObserver(source);
    if (shared != null) {
      if (!identical(shared, _observer)) _switchTo(shared, owned: false);
    } else if (!_owned || !identical(client, _client)) {
      _switchTo(_create(source, client), owned: true);
    } else {
      _setOptions(_observer, source);
    }
    _client = client;
    if (!identical(previous, _observer)) _rebaseListenings();
  }

  @override
  void dispose() {
    clearListeners();
    _dropListenings();
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
    // Before starting, so what the new observer reports then is kept.
    _generation++;
    if (listening) _startListening();
  }

  void _startListening() {
    _unsubscribe = _listen(_observer, (result) {
      for (final listener in listeners) {
        // A listener that throws is reported, so the others still get the
        // result.
        _client._guardCallback(() => listener(result));
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

  // Runs finish on their own. Resetting drops the callbacks of the latest
  // `mutate` call, which belong to the widget that is going away.
  @override
  void _destroy(MutationObserver<TData, TVariables, TContext> observer) {
    observer.reset();
  }
}

/// An [ObserverSlot] for a list of queries of one data type, such as one
/// query per id. Its result lists the result of every query, in order.
///
/// Every query keeps its own observer while its key stays in the list, even
/// when the list is reordered; a key that leaves the list lets its observer
/// go. A query whose key changes therefore starts over, and its
/// `placeholderData` gets no previous data: one item's data never stands in
/// for another's. Changes that arrive together reach listeners once. The
/// result is a new list only when one of its results changed, so [listen]
/// compares lists by identity.
final class QueriesSlot<TData extends Object>
    extends ObserverSlot<List<QuerySource<TData>>, List<QueryResult<TData>>> {
  QueriesSlot(List<QuerySource<TData>> queries, QueryClient client) {
    update(queries, client);
  }

  /// The client of the latest [update].
  late QueryClient _client;

  /// The slot of every query, with the key it is reused by.
  List<(Object, QuerySlot<TData>)> _entries = const [];
  final Map<QuerySlot<TData>, void Function()> _unsubscribes = {};

  /// The latest result each query pushed, so a push reads no observer.
  final Map<QuerySlot<TData>, QueryResult<TData>> _pushedBy = {};
  List<QueryObserver<TData>> _observers = const [];
  List<QueryResult<TData>> _result = const [];
  List<QueryResult<TData>>? _pushed;
  bool _scheduled = false;

  /// The observer of every query, in order. A new list only when an
  /// observer is added, removed, replaced, or moved.
  @override
  List<QueryObserver<TData>> get observer => _observers;

  @override
  List<QueryResult<TData>> get result {
    return _combine([for (final (_, slot) in _entries) slot.result]);
  }

  @override
  QueryClient get _reportTo => _client;

  /// Keeps the previous list while every result is the same object. Results
  /// equal by value can belong to other queries, so `==` isn't enough.
  List<QueryResult<TData>> _combine(List<QueryResult<TData>> next) {
    if (!_sameItems(next, _result)) _result = List.unmodifiable(next);
    return _result;
  }

  @override
  void update(List<QuerySource<TData>> source, QueryClient client) {
    _client = client;
    final reusable = <Object, List<QuerySlot<TData>>>{};
    for (final (key, slot) in _entries) {
      (reusable[key] ??= []).add(slot);
    }

    final entries = <(Object, QuerySlot<TData>)>[];
    for (final query in source) {
      // Owned observers are reused by key, shared ones by identity.
      final key = query is Query<TData> ? hashKey(query.queryKey) : query;
      final slots = reusable[key];
      final QuerySlot<TData> slot;
      if (slots != null && slots.isNotEmpty) {
        slot = slots.removeAt(0);
        slot.update(query, client);
        // A new client can give the slot another observer.
        _pushedBy.remove(slot);
      } else {
        slot = QuerySlot<TData>(query, client);
        if (hasListeners) _listenTo(slot);
      }
      entries.add((key, slot));
    }
    for (final slot in reusable.values.expand((slots) => slots)) {
      _unsubscribes.remove(slot)?.call();
      _pushedBy.remove(slot);
      slot.dispose();
    }

    _entries = entries;
    final observers = [for (final (_, slot) in entries) slot.observer];
    if (!_sameItems(observers, _observers)) {
      _observers = List.unmodifiable(observers);
      _generation++;
      _rebaseListenings();
    }
  }

  @override
  void dispose() {
    clearListeners();
    _dropListenings();
    for (final unsubscribe in _unsubscribes.values) {
      unsubscribe();
    }
    _unsubscribes.clear();
    for (final (_, slot) in _entries) {
      slot.dispose();
    }
    _entries = const [];
    _observers = const [];
    _result = const [];
    _pushedBy.clear();
  }

  @override
  void onSubscribe() {
    if (listeners.length != 1) return;
    for (final (_, slot) in _entries) {
      _listenTo(slot);
    }
  }

  @override
  void onUnsubscribe() {
    if (hasListeners) return;
    for (final unsubscribe in _unsubscribes.values) {
      unsubscribe();
    }
    _unsubscribes.clear();
    _pushedBy.clear();
  }

  void _listenTo(QuerySlot<TData> slot) {
    _unsubscribes[slot] = slot.subscribe((result) {
      _pushedBy[slot] = result;
      _schedulePush();
    });
  }

  /// Pushes the combined result once, after the changes of this batch.
  void _schedulePush() {
    if (_scheduled) return;
    _scheduled = true;
    notifyManager.schedule(() {
      _scheduled = false;
      if (!hasListeners) return;
      final result = _combine([
        for (final (_, slot) in _entries) _pushedBy[slot] ?? slot.result,
      ]);
      if (identical(result, _pushed)) return;
      _pushed = result;
      for (final listener in listeners) {
        listener(result);
      }
    });
  }
}

/// Whether [a] and [b] hold the same objects in the same order.
bool _sameItems(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

typedef _AnyState = MutationState<Object?, Object?, Object?>;

/// The state of every run in a cache when it was read, by run.
typedef _Snapshot = Map<AnyCachedMutation, _AnyState>;

typedef _RunListener<TData, TVariables, TContext> = void Function(
  MutationState<TData, TVariables, TContext> previous,
  MutationState<TData, TVariables, TContext> current,
);

/// An [ObserverSlot] over the mutation cache: the state of every run a
/// source finds, wherever it was started, such as a `MutationBuilder`, a
/// hook, a cubit's observer, or `restore(mutations:)`.
///
/// A [Mutation] finds the runs with its `mutationKey`, exactly, typed like
/// the definition; a definition without a key fails an assert. A run of
/// other types under the key is left out and reported once to the client's
/// `onUncaughtError`, so give each definition a key of its own.
/// [MutationFilters] find the runs of any mutation that match them, as
/// [MutationCache.findAll] does, typed `Object?`.
///
/// The slot only reads. It never runs, keeps, or resets a mutation, and it
/// applies none of a definition's options, so a definition built again on
/// every render costs nothing. Only the runs of the slot's client count.
///
/// [result] lists the matching runs oldest first. It is the same list while
/// no matching run was added, removed, or changed. A run stays until the
/// cache removes it: `gcTime` after it settles with no observer, or on
/// `clear()`.
///
/// Unlike the other slots, the slot calls [subscribe] listeners in a
/// microtask, once per batch, and only when the list changed.
/// [subscribeToRuns] reports each change of each run instead, for side
/// effects such as a snackbar when any run fails.
///
/// ```dart
/// final slot = MutationStateSlot(addTodo, client);
/// final unsubscribe = slot.subscribe(render);
/// final stop = slot.subscribeToRuns((previous, current) {
///   if (current.isError) showError(current.error);
/// });
/// slot.update(addTodo, client); // on every render
/// render(slot.result);
/// ```
final class MutationStateSlot<TData, TVariables, TContext> extends ObserverSlot<
    MutationStateSource<TData, TVariables, TContext>,
    List<MutationState<TData, TVariables, TContext>>> {
  MutationStateSlot(
    MutationStateSource<TData, TVariables, TContext> source,
    QueryClient client,
  )   : _client = client,
        _source = source {
    _matches = _matcherOf(source);
  }

  QueryClient _client;
  MutationStateSource<TData, TVariables, TContext> _source;
  late bool Function(AnyCachedMutation run) _matches;
  List<MutationState<TData, TVariables, TContext>> _result = const [];

  /// The list [subscribe] listeners got last.
  List<MutationState<TData, TVariables, TContext>>? _pushed;
  void Function()? _stopCache;
  bool _scheduled = false;

  /// Each [subscribeToRuns] listener, with the state of every run in the
  /// cache when it last heard of it.
  final Map<_RunListener<TData, TVariables, TContext>, _Snapshot>
      _runListeners = {};

  /// The cache the slot reads, `client.mutationCache` of its client. It is
  /// another object only after [update] got another client.
  @override
  MutationCache get observer => _client.mutationCache;

  /// The state of every matching run, oldest first. The same list while no
  /// matching run was added, removed, or changed. Current as soon as
  /// [update] returns.
  @override
  List<MutationState<TData, TVariables, TContext>> get result {
    final states = <MutationState<TData, TVariables, TContext>>[];
    for (final run in observer.getAll()) {
      if (!_matches(run)) continue;
      final state = _typed(run, run.state);
      if (state != null) states.add(state);
    }
    return _combine(states);
  }

  @override
  QueryClient get _reportTo => _client;

  @override
  void update(
    MutationStateSource<TData, TVariables, TContext> source,
    QueryClient client,
  ) {
    final sameClient = identical(client, _client);
    if (identical(source, _source) && sameClient) return;
    _source = source;
    _matches = _matcherOf(source);
    if (!sameClient) {
      final listening = _stopCache != null;
      _stopListening();
      _client = client;
      if (listening) _startListening();
      _generation++;
      _rebaseListenings();
      if (_runListeners.isNotEmpty) {
        // Nothing the new cache's runs did before now is a change.
        final snapshot = _snapshot();
        _runListeners.updateAll((_, __) => snapshot);
      }
    }
    // Pushes the new list, if it is one.
    if (_stopCache != null) _schedule();
  }

  /// Calls [listener] for each later change of a matching run, with the
  /// state that run had before (idle for a run that started later) and its
  /// new state. Returns a function that removes it.
  ///
  /// Never called for a state a run already had when [listener] was added,
  /// for a run that doesn't match, or for a run that the cache removed.
  /// Called in a microtask, never during a render, with each run's latest
  /// state of a batch; a state equal to the one before is not a change. A
  /// new source reports only later changes of its runs, and a run that
  /// starts to match a filter reports the state it really had before. A new
  /// client starts over from its cache's runs. A listener that throws is
  /// reported to the client's `onUncaughtError`, or without it to the zone.
  void Function() subscribeToRuns(
    void Function(
      MutationState<TData, TVariables, TContext> previous,
      MutationState<TData, TVariables, TContext> current,
    ) listener,
  ) {
    _runListeners.putIfAbsent(listener, _snapshot);
    _startListening();
    return () {
      if (_runListeners.remove(listener) != null) _stopIfUnused();
    };
  }

  /// Removes every listener of both kinds and stops reading the cache.
  @override
  void dispose() {
    clearListeners();
    _dropListenings();
    _runListeners.clear();
    _stopListening();
  }

  @override
  void onSubscribe() {
    // Before reading, so the slot follows the cache even when a predicate
    // throws.
    _startListening();
    // The list as it is now, which the adapter renders whether it read
    // [result] before subscribing or reads it after.
    if (listeners.length == 1) _pushed = result;
  }

  @override
  void onUnsubscribe() => _stopIfUnused();

  bool Function(AnyCachedMutation run) _matcherOf(
    MutationStateSource<TData, TVariables, TContext> source,
  ) {
    switch (source) {
      case Mutation(:final mutationKey):
        assert(
          mutationKey != null,
          'MutationStateSlot got a Mutation without a mutationKey. Its runs '
          'are found by their key, so give the definition one, such as '
          "mutationKey: ['todos', 'add'].",
        );
        // coverage:ignore-start
        // Only a release build gets here, as the assert above always runs in
        // tests: a definition without a key shows no runs.
        if (mutationKey == null) return (run) => false;
        // coverage:ignore-end
        return MutationFilters(mutationKey: mutationKey, exact: true)
            ._matcher();
      case final MutationFilters filters:
        return filters._matcher();
    }
  }

  /// [state] of [run] as this slot's type, or null for a run of other types
  /// under the key, which is reported once.
  MutationState<TData, TVariables, TContext>? _typed(
    AnyCachedMutation run,
    _AnyState state,
  ) {
    if (state is MutationState<TData, TVariables, TContext>) return state;
    final key = run.options.mutationKey;
    final type = 'MutationStateSlot<$TData, $TVariables, $TContext>';
    _client._reportOnce(
      'mutation state $key ${state.runtimeType} $type',
      StateError(
        'A run with the mutationKey $key has a ${state.runtimeType}, so a '
        '$type for that key leaves it out. Give each definition with other '
        'types a mutationKey of its own.',
      ),
      StackTrace.current,
    );
    return null;
  }

  /// Keeps the previous list while every state is the same object.
  List<MutationState<TData, TVariables, TContext>> _combine(
    List<MutationState<TData, TVariables, TContext>> next,
  ) {
    if (!_sameItems(next, _result)) _result = List.unmodifiable(next);
    return _result;
  }

  _Snapshot _snapshot() =>
      {for (final run in observer.getAll()) run: run.state};

  void _startListening() {
    _stopCache ??= observer._subscribe(_schedule);
  }

  void _stopListening() {
    _stopCache?.call();
    _stopCache = null;
  }

  void _stopIfUnused() {
    if (!hasListeners && _runListeners.isEmpty) _stopListening();
  }

  /// Reads the cache once, after the changes of this batch.
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    notifyManager.schedule(_flush);
  }

  void _flush() {
    _scheduled = false;
    if (_stopCache == null) return;
    final runs = observer.getAll();
    final states = [for (final run in runs) run.state];
    final heard = _runListeners.entries.toList();
    final List<MutationState<TData, TVariables, TContext>?> matching;
    try {
      matching = [
        for (var i = 0; i < runs.length; i++)
          _matches(runs[i]) ? _typed(runs[i], states[i]) : null,
      ];
    } catch (error, stackTrace) {
      // A predicate that throws. What the runs did until now is still seen.
      _client._reportError(error, stackTrace);
      _advance(heard, runs, states);
      return;
    }

    for (final MapEntry(key: listener, value: seen) in heard) {
      for (var i = 0; i < runs.length; i++) {
        final current = matching[i];
        if (current == null) continue;
        final previous = switch (seen[runs[i]]) {
          final MutationState<TData, TVariables, TContext> state => state,
          // A run that started after the listener last heard.
          _ => MutationState<TData, TVariables, TContext>(),
        };
        if (previous == current) continue;
        // Another listener can remove this one.
        if (!_runListeners.containsKey(listener)) break;
        _client._guardCallback(() => listener(previous, current));
      }
    }
    _advance(heard, runs, states);

    if (!hasListeners) return;
    final result = _combine([...matching.nonNulls]);
    if (identical(result, _pushed)) return;
    _pushed = result;
    for (final listener in listeners) {
      _client._guardCallback(() => listener(result));
    }
  }

  /// Moves the listeners that heard [runs] in [states] on to them. A
  /// listener added since keeps the snapshot it was added with.
  void _advance(
    List<MapEntry<_RunListener<TData, TVariables, TContext>, _Snapshot>> heard,
    List<AnyCachedMutation> runs,
    List<_AnyState> states,
  ) {
    if (heard.isEmpty) return;
    final _Snapshot seen = {
      for (var i = 0; i < runs.length; i++) runs[i]: states[i],
    };
    for (final MapEntry(key: listener, value: before) in heard) {
      if (identical(_runListeners[listener], before)) {
        _runListeners[listener] = seen;
      }
    }
  }
}
