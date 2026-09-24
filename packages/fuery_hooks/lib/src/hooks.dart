import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuery/fuery.dart';

/// Returns the latest result of [query], and rebuilds when it changes.
///
/// [query] is a [Query] definition, or an observer that is already shared.
/// A definition can be built in `build`: the hook keeps one observer for it
/// and updates its options, so a new key shows in the same frame.
///
/// ```dart
/// class TodoList extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final todos = useQuery(todosQuery);
///     return switch (todos) {
///       QueryResult(:final data?) => TodoListView(data),
///       QueryResult(:final error?) => ErrorView(error, onRetry: todos.refetch),
///       _ => const CircularProgressIndicator(),
///     };
///   }
/// }
/// ```
///
/// [listener] runs side effects, such as a snackbar or navigation, after
/// each later change, as a [QueryListener] does: never during a build, and
/// not for the result the widget mounts with. [listenWhen] compares the
/// previous result received with the new one, and needs a [listener]. The
/// listener gets the widget's own `context`, and the latest build's
/// [listener] and [listenWhen] are used.
///
/// ```dart
/// final todos = useQuery(
///   todosQuery,
///   listenWhen: (previous, current) =>
///       !previous.isRefetchError && current.isRefetchError,
///   listener: (context, result) => ScaffoldMessenger.of(context)
///       .showSnackBar(SnackBar(content: Text('${result.error}'))),
/// );
/// ```
QueryResult<TData> useQuery<TData extends Object>(
  QuerySource<TData> query, {
  ResultWidgetListener<QueryResult<TData>>? listener,
  ResultCondition<QueryResult<TData>>? listenWhen,
}) {
  return use(
    _SlotHook<QuerySource<TData>, QueryResult<TData>, QueryResult<TData>>(
      query,
      QuerySlot<TData>.new,
      _recreatedQuery,
      'useQuery',
      _listenToResults,
      listener: listener,
      listenWhen: listenWhen,
    ),
  );
}

/// Returns the latest result of an infinite [query], and rebuilds when it
/// changes. Load more with `fetchNextPage` on the result.
///
/// [listener] and [listenWhen] work as in [useQuery]. See [useQuery].
InfiniteQueryResult<TPage, TParam> useInfiniteQuery<TPage, TParam>(
  InfiniteQuerySource<TPage, TParam> query, {
  ResultWidgetListener<InfiniteQueryResult<TPage, TParam>>? listener,
  ResultCondition<InfiniteQueryResult<TPage, TParam>>? listenWhen,
}) {
  return use(
    _SlotHook<InfiniteQuerySource<TPage, TParam>,
        InfiniteQueryResult<TPage, TParam>, InfiniteQueryResult<TPage, TParam>>(
      query,
      InfiniteQuerySlot<TPage, TParam>.new,
      _recreatedQuery,
      'useInfiniteQuery',
      _listenToResults,
      listener: listener,
      listenWhen: listenWhen,
    ),
  );
}

/// Returns the latest result of [mutation], and rebuilds when it changes.
/// Run it with `mutate` on the result.
///
/// [mutation] is a [Mutation] definition, or an observer that is already
/// shared. For a definition, when the widget goes away the runs it started
/// finish, and the callbacks passed to their `mutate` calls are dropped. A
/// shared observer is left alone and still runs them, so check
/// `context.mounted` in them, or call `reset()` where the observer is owned.
///
/// ```dart
/// final addTodo = useMutation(addTodoMutation);
/// return ElevatedButton(
///   onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
///   child: const Text('Add'),
/// );
/// ```
///
/// A [NoVariablesMutation] runs with `mutate(null)`.
///
/// [listener] and [listenWhen] work as in [useQuery]. For a definition, the
/// listener hears the runs started with the result this hook returns, also
/// when a child runs it; another `useMutation` of the same definition has
/// an observer of its own. For a shared observer, it hears every run.
///
/// ```dart
/// final addTodo = useMutation(
///   addTodoMutation,
///   listenWhen: (previous, current) => current.isSuccess,
///   listener: (context, result) => Navigator.pop(context),
/// );
/// ```
MutationResult<TData, TVariables, TContext>
    useMutation<TData, TVariables, TContext>(
  MutationSource<TData, TVariables, TContext> mutation, {
  ResultWidgetListener<MutationResult<TData, TVariables, TContext>>? listener,
  ResultCondition<MutationResult<TData, TVariables, TContext>>? listenWhen,
}) {
  return use(
    _SlotHook<
        MutationSource<TData, TVariables, TContext>,
        MutationResult<TData, TVariables, TContext>,
        MutationResult<TData, TVariables, TContext>>(
      mutation,
      MutationSlot<TData, TVariables, TContext>.new,
      _recreatedMutation,
      'useMutation',
      _listenToResults,
      listener: listener,
      listenWhen: listenWhen,
    ),
  );
}

/// Returns the latest results of a list of [queries] of one data type, in
/// order, such as one query per id, and rebuilds when any of them changes.
///
/// Every query keeps its observer while its key stays in the list, even
/// when the list is reordered. Changes that arrive together rebuild once.
///
/// ```dart
/// final posts = useQueries([for (final id in ids) postQuery(id)]);
/// ```
List<QueryResult<TData>> useQueries<TData extends Object>(
  List<QuerySource<TData>> queries,
) {
  return use(
    _SlotHook<List<QuerySource<TData>>, List<QueryResult<TData>>,
        List<QueryResult<TData>>>(
      queries,
      QueriesSlot<TData>.new,
      _recreatedInList,
      'useQueries',
      _listenToResults,
    ),
  );
}

/// Returns the state of every run of [mutation], oldest first, wherever it
/// was started: a `useMutation` or a `MutationBuilder` in another widget, a
/// cubit's observer, or `restore(mutations:)`. Rebuilds when a run is added,
/// removed, or changes.
///
/// [mutation] is a [Mutation] definition with a `mutationKey`, which finds
/// the runs with that key, typed like the definition, or [MutationFilters],
/// which find the runs of any mutation that match them. The hook only reads:
/// it never runs the mutation, and it works as [MutationStateBuilder] does.
///
/// ```dart
/// final runs = useMutationState(addTodoMutation);
/// return runs.any((run) => run.isPending)
///     ? const LinearProgressIndicator()
///     : const SizedBox.shrink();
/// ```
///
/// [listener] runs side effects for each run that changes, as a
/// [MutationStateListener] does: it gets the run's new state, and
/// [listenWhen] compares the state that run had before with its new one. It
/// isn't called for the states runs had when listening started.
///
/// ```dart
/// useMutationState(
///   addTodoMutation,
///   listenWhen: (previous, current) => current.isError,
///   listener: (context, run) => ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Could not add "${run.variables}"')),
///   ),
/// );
/// ```
List<MutationState<TData, TVariables, TContext>>
    useMutationState<TData, TVariables, TContext>(
  MutationStateSource<TData, TVariables, TContext> mutation, {
  ResultWidgetListener<MutationState<TData, TVariables, TContext>>? listener,
  ResultCondition<MutationState<TData, TVariables, TContext>>? listenWhen,
}) {
  return use(
    _SlotHook<
        MutationStateSource<TData, TVariables, TContext>,
        List<MutationState<TData, TVariables, TContext>>,
        MutationState<TData, TVariables, TContext>>(
      mutation,
      MutationStateSlot<TData, TVariables, TContext>.new,
      _noRecreated,
      'useMutationState',
      _listenToRuns,
      listener: listener,
      listenWhen: listenWhen,
    ),
  );
}

/// Returns the client that the hooks of this widget use: the one a
/// [FueryProvider] above provides, or [Fuery.client]. Rebuilds when the
/// provided client is replaced.
QueryClient useQueryClient() => FueryProvider.of(useContext(), listen: true);

/// Returns the key of an observer in `current` that replaced a different
/// observer for the same key in `previous`, or null.
typedef _RecreatedKey<S> = String? Function(S previous, S current);

String? _queryKey(Object? source) {
  return source is QueryObserver ? hashKey(source.options.queryKey) : null;
}

String? _mutationKey(Object? source) {
  if (source is! MutationObserver) return null;
  final key = source.options.mutationKey;
  return key == null ? null : hashKey(key);
}

/// The client of [source] when it is an observer, or null for a definition.
QueryClient? _clientOf(Object? source) => switch (source) {
      QueryObserver(:final client) => client,
      MutationObserver(:final client) => client,
      _ => null,
    };

/// The [_RecreatedKey] of a source that holds one observer, from the key of
/// that observer, or null for a definition.
///
/// A new observer of another client is null too: it replaces the old one on
/// purpose, as `useMemoized(() => todosQuery.observe(client: client),
/// [client])` does when the provided client is replaced.
_RecreatedKey<Object?> _sameKey(String? Function(Object? source) key) {
  return (previous, current) {
    final keyHash = key(current);
    return keyHash != null &&
            keyHash == key(previous) &&
            identical(_clientOf(previous), _clientOf(current))
        ? keyHash
        : null;
  };
}

final _RecreatedKey<Object?> _recreatedQuery = _sameKey(_queryKey);

final _RecreatedKey<Object?> _recreatedMutation = _sameKey(_mutationKey);

/// For a source that never holds an observer, such as a
/// [MutationStateSource].
String? _noRecreated(Object? previous, Object? current) => null;

/// The key of a query observer in [current] that replaced a different
/// observer for the same key and client in [previous]. Definitions,
/// reordering, observers passed again, and new observers of another client
/// are silent.
String? _recreatedInList(List<Object?> previous, List<Object?> current) {
  final before = Set<Object?>.identity()..addAll(previous);
  // QueryClient compares by identity, so the records do too.
  final keys = {
    for (final source in previous)
      if (_queryKey(source) case final key?) (_clientOf(source), key),
  };
  for (final source in current) {
    if (before.contains(source)) continue;
    final key = _queryKey(source);
    if (key != null && keys.contains((_clientOf(source), key))) return key;
  }
  return null;
}

/// How a hook's listener hears changes of its [slot]: as `(previous,
/// current)` pairs of what the listener gets, [L].
typedef _ListenTo<S, R, L> = void Function() Function(
  ObserverSlot<S, R> slot,
  void Function(L previous, L current) onChange,
);

/// Hears each later result of [slot], as the listener widgets do.
void Function() _listenToResults<S, R>(
  ObserverSlot<S, R> slot,
  void Function(R previous, R current) onChange,
) {
  return slot.listen(onChange);
}

/// Hears each later change of each run of [slot], as a
/// [MutationStateListener] does.
void Function() _listenToRuns<TData, TVariables, TContext>(
  ObserverSlot<MutationStateSource<TData, TVariables, TContext>,
          List<MutationState<TData, TVariables, TContext>>>
      slot,
  void Function(
    MutationState<TData, TVariables, TContext> previous,
    MutationState<TData, TVariables, TContext> current,
  ) onChange,
) {
  final runs = slot as MutationStateSlot<TData, TVariables, TContext>;
  return runs.subscribeToRuns(onChange);
}

/// Renders a source through the [ObserverSlot] that [createSlot] creates,
/// the way the widgets of `fuery` do, and calls [listener] after each later
/// change that [listenTo] reports, as the listener widgets do.
class _SlotHook<S, R, L> extends Hook<R> {
  const _SlotHook(
    this.source,
    this.createSlot,
    this.debugKey,
    this.name,
    this.listenTo, {
    this.listener,
    this.listenWhen,
  }) : assert(
          listener != null || listenWhen == null,
          'listenWhen needs a listener',
        );

  final S source;
  final ObserverSlot<S, R> Function(S source, QueryClient client) createSlot;

  /// Finds an observer created on every build, for the debug warning.
  final _RecreatedKey<S> debugKey;
  final String name;

  /// What [listener] hears: each result, or each change of a run.
  final _ListenTo<S, R, L> listenTo;
  final ResultWidgetListener<L>? listener;
  final ResultCondition<L>? listenWhen;

  @override
  _SlotHookState<S, R, L> createState() => _SlotHookState<S, R, L>();
}

class _SlotHookState<S, R, L> extends HookState<R, _SlotHook<S, R, L>> {
  ObserverSlot<S, R>? _slot;
  void Function()? _unsubscribe;
  void Function()? _stopListening;
  R? _built;

  /// What the slot was last updated with, so a rebuild with the same ones,
  /// such as one a result caused, doesn't set the options again.
  Object? _source;
  QueryClient? _client;

  /// A hot reload can dispose the hook while its widget stays, after a
  /// result was already on its way.
  bool _disposed = false;

  @override
  void initHook() {
    super.initHook();
    FueryBinding.ensureInitialized();
  }

  @override
  void didUpdateHook(_SlotHook<S, R, L> oldHook) {
    super.didUpdateHook(oldHook);
    if (!identical(oldHook.source, hook.source)) {
      _debugWarnRecreated(hook, oldHook.source);
    }
  }

  @override
  R build(BuildContext context) {
    final client = FueryProvider.of(context, listen: true);
    var slot = _slot;
    if (slot == null) {
      slot = _slot = hook.createSlot(hook.source, client);
      _debugWarnOtherClient(hook.name, hook.source, client);
      // Results arrive in a microtask, never during a build.
      _unsubscribe = slot.subscribe(
        notifyManager.batchCalls((R result) {
          if (!_disposed && result != _built) setState(() {});
        }),
      );
    } else if (!identical(hook.source, _source) ||
        !identical(client, _client)) {
      slot.update(hook.source, client);
      _debugWarnOtherClient(hook.name, hook.source, client);
    }
    _source = hook.source;
    _client = client;
    // From the first build that passes a listener, whose result, or the
    // states its runs have, are not changes. A later build without one keeps
    // listening and skips the calls.
    if (hook.listener != null) {
      _stopListening ??= hook.listenTo(slot, _onChange);
    }
    // Current as soon as update returns, so a new key shows in this frame.
    final result = slot.result;
    _built = result;
    return result;
  }

  /// Runs in a microtask, never during a build, with the latest build's
  /// listener.
  void _onChange(L previous, L current) {
    final listener = hook.listener;
    if (listener != null &&
        (hook.listenWhen?.call(previous, current) ?? true)) {
      listener(context, current);
    }
  }

  @override
  void dispose() {
    _stopListening?.call();
    _disposed = true;
    _unsubscribe?.call();
    _slot?.dispose();
    super.dispose();
  }

  @override
  String get debugLabel => hook.name;
}

/// Keys already warned about, so each mistake is reported once.
final Set<String> _warnedKeys = {};

const _troubleshooting = 'https://galaxykhh.github.io/fuery/troubleshooting/';

/// How to pass the hook named [hookName] a definition, for the warnings.
String _definitionExample(String hookName) {
  return switch (hookName) {
    'useMutation' => 'useMutation(addTodoMutation)',
    'useQueries' => 'useQueries([for (final id in ids) todoQuery(id)])',
    _ => '$hookName(todosQuery)',
  };
}

/// Warns, in debug builds, when a hook got a new observer for the same key
/// on a rebuild, which is what `useQuery(todosQuery.observe())` looks like:
/// each new query observer subscribes and refetches again, and each new
/// mutation observer starts idle.
void _debugWarnRecreated<S, R, L>(_SlotHook<S, R, L> hook, S previous) {
  assert(() {
    final keyHash = hook.debugKey(previous, hook.source);
    if (keyHash == null) return true;
    final mutation = hook.source is MutationObserver;
    if (!_warnedKeys.add('${mutation ? 'mutation' : 'query'}:$keyHash')) {
      return true;
    }
    final list = hook.source is List;
    final effect = mutation
        ? 'A new observer starts idle, so the hook stops showing a running '
            "mutation's pending or error state."
        : 'A new observer subscribes and refetches again each time.';
    debugPrint(
      '[fuery] ${hook.name} received a new observer for the key $keyHash on '
      'a rebuild. $effect Pass the definition${list ? 's' : ''} instead, '
      'such as ${_definitionExample(hook.name)}, and the hook keeps one '
      'observer for ${list ? 'each' : 'it'}. See $_troubleshooting'
      '#a-query-fetches-on-every-rebuild',
    );
    return true;
  }());
}

/// Warns, in debug builds, when [source] holds an observer of another client
/// than the [client] the hook uses. That is `observe()` without a client
/// under a [FueryProvider] with its own.
///
/// Warns once per hook name and key, or once per hook name for a mutation
/// without a key, so observers created in `build` warn once.
void _debugWarnOtherClient(
  String hookName,
  Object? source,
  QueryClient client,
) {
  assert(() {
    for (final observer in source is List ? source : [source]) {
      final own = _clientOf(observer);
      if (own == null || identical(own, client)) continue;
      final keyHash = _queryKey(observer) ?? _mutationKey(observer) ?? '';
      if (!_warnedKeys.add('other-client:$hookName:$keyHash')) continue;
      debugPrint(
        '[fuery] $hookName received an observer of another QueryClient than '
        "the one it uses here (FueryProvider's, or Fuery.client). The "
        "observer reads and writes its own client's cache, so it and the "
        "other hooks and widgets of this screen don't see each other's "
        'changes. Pass the definition, as in ${_definitionExample(hookName)}, '
        'or create the observer with the client useQueryClient() returns. '
        'See $_troubleshooting#a-screen-reads-another-clients-cache',
      );
    }
    return true;
  }());
}

/// Forgets which keys were warned about, for tests.
@visibleForTesting
void debugResetHookWarnings() => _warnedKeys.clear();
