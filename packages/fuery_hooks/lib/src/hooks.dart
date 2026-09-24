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
QueryResult<TData> useQuery<TData extends Object>(QuerySource<TData> query) {
  return use(
    _SlotHook<QuerySource<TData>, QueryResult<TData>>(
      query,
      QuerySlot<TData>.new,
      _queryKey,
      'useQuery',
    ),
  );
}

/// Returns the latest result of an infinite [query], and rebuilds when it
/// changes. Load more with `fetchNextPage` on the result.
///
/// See [useQuery].
InfiniteQueryResult<TPage, TParam> useInfiniteQuery<TPage, TParam>(
  InfiniteQuerySource<TPage, TParam> query,
) {
  return use(
    _SlotHook<InfiniteQuerySource<TPage, TParam>,
        InfiniteQueryResult<TPage, TParam>>(
      query,
      InfiniteQuerySlot<TPage, TParam>.new,
      _queryKey,
      'useInfiniteQuery',
    ),
  );
}

/// Returns the latest result of [mutation], and rebuilds when it changes.
/// Run it with `mutate` on the result.
///
/// [mutation] is a [Mutation] definition, or an observer that is already
/// shared. When the widget goes away, the runs it started finish, and the
/// callbacks passed to their `mutate` calls are dropped.
///
/// ```dart
/// final addTodo = useMutation(addTodoMutation);
/// return ElevatedButton(
///   onPressed: addTodo.isPending ? null : () => addTodo.mutate('Buy milk'),
///   child: const Text('Add'),
/// );
/// ```
MutationResult<TData, TVariables, TContext>
    useMutation<TData, TVariables, TContext>(
  MutationSource<TData, TVariables, TContext> mutation,
) {
  return use(
    _SlotHook<MutationSource<TData, TVariables, TContext>,
        MutationResult<TData, TVariables, TContext>>(
      mutation,
      MutationSlot<TData, TVariables, TContext>.new,
      _mutationKey,
      'useMutation',
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
    _SlotHook<List<QuerySource<TData>>, List<QueryResult<TData>>>(
      queries,
      QueriesSlot<TData>.new,
      null,
      'useQueries',
    ),
  );
}

/// Returns the client that the hooks of this widget use: the one a
/// [FueryProvider] above provides, or [Fuery.client]. Rebuilds when the
/// provided client is replaced.
QueryClient useQueryClient() => FueryProvider.of(useContext(), listen: true);

String? _queryKey(Object source) {
  return source is QueryObserver ? hashKey(source.options.queryKey) : null;
}

String? _mutationKey(Object? source) {
  if (source is! MutationObserver) return null;
  final key = source.options.mutationKey;
  return key == null ? null : hashKey(key);
}

/// Renders a source through the [ObserverSlot] that [createSlot] creates,
/// the way the widgets of `fuery` do.
class _SlotHook<S, R> extends Hook<R> {
  const _SlotHook(this.source, this.createSlot, this.debugKey, this.name);

  final S source;
  final ObserverSlot<S, R> Function(S source, QueryClient client) createSlot;

  /// The key of [source] when it is an observer, for the warning about
  /// observers created on every build.
  final String? Function(S source)? debugKey;
  final String name;

  @override
  _SlotHookState<S, R> createState() => _SlotHookState<S, R>();
}

class _SlotHookState<S, R> extends HookState<R, _SlotHook<S, R>> {
  ObserverSlot<S, R>? _slot;
  void Function()? _unsubscribe;
  R? _built;

  @override
  void initHook() {
    super.initHook();
    FueryBinding.ensureInitialized();
  }

  @override
  void didUpdateHook(_SlotHook<S, R> oldHook) {
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
      // Results arrive in a microtask, never during a build.
      _unsubscribe = slot.subscribe(
        notifyManager.batchCalls((R result) {
          if (context.mounted && result != _built) setState(() {});
        }),
      );
    } else {
      slot.update(hook.source, client);
    }
    // Current as soon as update returns, so a new key shows in this frame.
    final result = slot.result;
    _built = result;
    return result;
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _slot?.dispose();
    super.dispose();
  }

  @override
  String get debugLabel => hook.name;
}

/// Keys already warned about, so each mistake is reported once.
final Set<String> _warnedKeys = {};

/// Warns, in debug builds, when a hook got a new observer for the same key
/// on a rebuild, which is what `useQuery(todosQuery.observe())` looks like.
void _debugWarnRecreated<S, R>(_SlotHook<S, R> hook, S previous) {
  assert(() {
    final key = hook.debugKey;
    if (key == null) return true;
    final keyHash = key(hook.source);
    if (keyHash == null || keyHash != key(previous)) return true;
    if (!_warnedKeys.add(keyHash)) return true;
    debugPrint(
      '[fuery] ${hook.name} received a new observer for the key $keyHash on '
      'a rebuild. A new observer subscribes and refetches again each time. '
      'Pass the definition instead, such as ${hook.name}(todosQuery), and '
      'the hook keeps one observer for it.',
    );
    return true;
  }());
}

/// Forgets which keys were warned about, for tests.
@visibleForTesting
void debugResetHookWarnings() => _warnedKeys.clear();
