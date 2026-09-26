import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';
import 'fuery_provider.dart';

/// Keys already warned about, so each mistake is reported once.
final Set<String> _warnedKeys = {};

const _troubleshooting = 'https://galaxykhh.github.io/fuery/troubleshooting/';

/// Returns the key of an observer in `current` that replaced a different
/// observer for the same key in `previous`, or null.
typedef DebugRecreatedKey<S> = String? Function(S previous, S current);

/// The client of [source] when it is an observer, or null for a definition.
QueryClient? _clientOf(Object? source) => switch (source) {
      QueryObserver(:final client) => client,
      MutationObserver(:final client) => client,
      _ => null,
    };

/// The [DebugRecreatedKey] of a source that holds one observer, from the key
/// of that observer, or null for a definition.
///
/// A new observer of another client is null too: it replaces the old one on
/// purpose, as after the provided client was replaced.
DebugRecreatedKey<S> debugSameKey<S>(String? Function(S source) key) {
  return (previous, current) {
    final keyHash = key(current);
    return keyHash != null &&
            keyHash == key(previous) &&
            identical(_clientOf(previous), _clientOf(current))
        ? keyHash
        : null;
  };
}

/// The [DebugRecreatedKey] of a source that never holds an observer, such
/// as a [MutationStateSource]: never a key.
String? debugNoRecreatedKey(Object? previous, Object? current) => null;

/// Warns, in debug builds, when a widget got a new observer for the same key
/// on a rebuild. That is what `todosQuery.observe()` in `build` looks like:
/// each new query observer subscribes and refetches again, and each new
/// mutation observer starts idle.
void debugWarnRecreated<S>(
  String widgetName,
  DebugRecreatedKey<S> key,
  S previous,
  S current,
) {
  assert(() {
    final keyHash = key(previous, current);
    if (keyHash == null) return true;
    final mutation = current is MutationObserver;
    if (!_warnedKeys.add('${mutation ? 'mutation' : 'query'}:$keyHash')) {
      return true;
    }
    final advice = mutation
        ? 'A new observer starts idle, so the widget stops showing a running '
            "mutation's pending or error state. Create the observer once, in "
            'a State field or a cubit, or pass the definition to a widget '
            'that runs it, such as MutationBuilder(mutation: saveTodo).'
        : current is List
            ? 'A new observer subscribes and refetches again each time. Pass '
                'the definitions instead, such as $widgetName(queries: [for '
                '(final id in ids) todoQuery(id)]), and the widget keeps one '
                'observer for each.'
            : 'A new observer subscribes and refetches again each time. Pass '
                'the definition instead, such as $widgetName(query: '
                'todosQuery), and the widget keeps one observer for it.';
    debugPrint(
      '[fuery] $widgetName received a new observer for the key $keyHash on '
      'a rebuild. $advice See $_troubleshooting'
      '#a-query-fetches-on-every-rebuild',
    );
    return true;
  }());
}

/// Warns, in debug builds, when a widget that can't run a mutation got a
/// [Mutation] definition. The widget then watches an observer of its own
/// that nothing runs, so it never hears a change.
void debugWarnMutationDefinition(String widgetName) {
  assert(() {
    if (!_warnedKeys.add('definition:$widgetName')) return true;
    debugPrint(
      '[fuery] $widgetName got a Mutation definition, so it watches an '
      'observer of its own that nothing runs, and it never hears a change. '
      'To hear every run of the mutation, give it a mutationKey and use '
      'MutationStateListener(mutation: addTodo, ...). For an effect of one '
      "call, await addTodo.mutateAsync(...). To hear only one observer's "
      'runs, create it with addTodo.observe() in a State field or a cubit '
      'and pass it here and to the widget that runs it. See $_troubleshooting'
      '#a-mutationlistener-never-runs',
    );
    return true;
  }());
}

/// Warns, in debug builds, when [source] holds an observer of another client
/// than the [client] the widget uses. That is `observe()` without a client
/// under a [FueryProvider] with its own.
///
/// Warns once per widget name and key, or once per widget name for a
/// mutation without a key, so observers created in `build` warn once.
void debugWarnOtherClient(
  String widgetName,
  Object? source,
  QueryClient client,
) {
  assert(() {
    for (final observer in source is List ? source : [source]) {
      final own = _clientOf(observer);
      if (own == null || identical(own, client)) continue;
      final keyHash = switch (observer) {
        QueryObserver(:final options) => hashKey(options.queryKey),
        MutationObserver(options: Mutation(:final mutationKey?)) =>
          hashKey(mutationKey),
        _ => '',
      };
      if (!_warnedKeys.add('other-client:$widgetName:$keyHash')) continue;
      debugPrint(
        '[fuery] $widgetName received an observer of another QueryClient '
        "than the one it uses here (FueryProvider's, or Fuery.client). The "
        "observer reads and writes its own client's cache, so it and the "
        "other widgets of this screen don't see each other's changes. Create "
        'it with observe(client: context.queryClient), or pass the '
        'definition. See $_troubleshooting'
        '#a-screen-reads-another-clients-cache',
      );
    }
    return true;
  }());
}

/// Forgets which keys were warned about, for tests.
@visibleForTesting
void debugResetRecreatedWarnings() => _warnedKeys.clear();

typedef ResultWidgetBuilder<R> = Widget Function(
    BuildContext context, R result);

typedef ResultWidgetListener<R> = void Function(BuildContext context, R result);

/// Decides whether a change from [previous] to [current] should rebuild or
/// notify.
typedef ResultCondition<R> = bool Function(R previous, R current);

/// Creates the slot a widget renders a source from.
typedef SlotFactory<S, R> = ObserverSlot<S, R> Function(
  S source,
  QueryClient client,
);

/// Keeps an [ObserverSlot] for a widget: creates it with the provided client,
/// updates it when the widget or the client changes, and disposes it.
mixin _SlotHost<S, R, W extends StatefulWidget> on State<W> {
  S get _source;
  SlotFactory<S, R> get _createSlot;
  DebugRecreatedKey<S> get _debugKey;
  String get _debugName;

  ObserverSlot<S, R>? _slot;
  QueryClient? _client;
  void Function()? _unsubscribe;

  ObserverSlot<S, R> get slot => _slot!;

  @override
  void initState() {
    super.initState();
    FueryBinding.ensureInitialized();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = FueryProvider.of(context, listen: true);
    final slot = _slot;
    if (slot == null) {
      _client = client;
      final created = _slot = _createSlot(_source, client);
      debugWarnOtherClient(_debugName, _source, client);
      _onAttached(created.result);
      // Subscribes first: the first subscribe can report a result that
      // corrects the one read above, such as the failures of a fetch it
      // joins, and only the listeners it has by then hear it.
      _unsubscribe = _subscribeTo(created);
      _onCreated(created);
    } else if (!identical(client, _client)) {
      _update();
    }
  }

  void _didUpdateSource(S previous) {
    if (!identical(previous, _source)) {
      debugWarnRecreated(_debugName, _debugKey, previous, _source);
    }
    _update();
  }

  /// Points the slot at the current source and client, and takes its result
  /// right away, so this frame already shows it.
  ///
  /// Reads the provided client here: Flutter calls `didUpdateWidget` before
  /// `didChangeDependencies`, so a new key and a new client that arrive in
  /// one frame must both reach the slot at once, or the new key would load
  /// on the old client first.
  void _update() {
    final slot = this.slot;
    final observer = slot.observer;
    final client = _client = FueryProvider.of(context, listen: true);
    slot.update(_source, client);
    debugWarnOtherClient(_debugName, _source, client);
    final result = slot.result;
    if (identical(observer, slot.observer)) {
      _onUpdated(result);
    } else {
      _onAttached(result);
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _slot?.dispose();
    super.dispose();
  }

  /// The slot started rendering from another observer, with [result].
  void _onAttached(R result);

  /// The slot was created, and the widget subscribed to it.
  void _onCreated(ObserverSlot<S, R> slot) {}

  /// Subscribes to the new [slot], and returns the function that stops it.
  void Function() _subscribeTo(ObserverSlot<S, R> slot);

  /// The same observer has [result] after an update, before this build.
  void _onUpdated(R result);
}

/// A [_SlotHost] that hears each new result of its slot, to rebuild.
mixin _ResultHost<S, R, W extends StatefulWidget> on _SlotHost<S, R, W> {
  @override
  void Function() _subscribeTo(ObserverSlot<S, R> slot) {
    // Results arrive in a microtask, never during build or initState.
    return slot.subscribe(
      notifyManager.batchCalls((R result) {
        if (mounted) _onResult(result);
      }),
    );
  }

  /// A result arrived after the last build.
  void _onResult(R result);
}

/// Renders a source through an [ObserverSlot] and builds, listens, or both.
///
/// [buildWhen] compares against the result that was last built, and
/// [listenWhen] against the result that was last received. The listener
/// hears changes through [ObserverSlot.listen].
class ResultSubscriber<S, R> extends StatefulWidget {
  const ResultSubscriber({
    super.key,
    required this.source,
    required this.createSlot,
    this.builder,
    this.buildWhen,
    this.listener,
    this.listenWhen,
    this.child,
    required this.debugName,
    required this.debugKey,
  }) : assert(builder != null || child != null);

  final S source;
  final SlotFactory<S, R> createSlot;

  /// The name of the widget, such as `QueryBuilder`, for debug warnings.
  final String debugName;

  /// Finds an observer created on every rebuild, for the debug warning.
  final DebugRecreatedKey<S> debugKey;
  final ResultWidgetBuilder<R>? builder;
  final ResultCondition<R>? buildWhen;
  final ResultWidgetListener<R>? listener;
  final ResultCondition<R>? listenWhen;
  final Widget? child;

  @override
  State<ResultSubscriber<S, R>> createState() => _ResultSubscriberState<S, R>();
}

class _ResultSubscriberState<S, R> extends State<ResultSubscriber<S, R>>
    with
        _SlotHost<S, R, ResultSubscriber<S, R>>,
        _ResultHost<S, R, ResultSubscriber<S, R>> {
  late R _built;
  void Function()? _stopListening;

  @override
  S get _source => widget.source;

  @override
  SlotFactory<S, R> get _createSlot => widget.createSlot;

  @override
  DebugRecreatedKey<S> get _debugKey => widget.debugKey;

  @override
  String get _debugName => widget.debugName;

  @override
  void didUpdateWidget(ResultSubscriber<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _didUpdateSource(oldWidget.source);
  }

  @override
  void _onAttached(R result) => _built = result;

  /// Listens after the widget subscribed to rebuild, from the result that
  /// subscribing reported. The listener still hears each change before the
  /// rebuild that shows it: both run in a microtask, and a rebuild only
  /// marks the widget to build in the next frame.
  @override
  void _onCreated(ObserverSlot<S, R> slot) {
    if (widget.listener == null) return;
    _stopListening = slot.listen((previous, current) {
      final listener = widget.listener;
      if (listener != null &&
          (widget.listenWhen?.call(previous, current) ?? true)) {
        listener(context, current);
      }
    });
  }

  @override
  void _onUpdated(R result) {
    // Listeners hear about it when the result arrives; they must not run
    // during build.
    if (_shouldBuild(result)) _built = result;
  }

  @override
  void _onResult(R result) {
    if (_shouldBuild(result)) setState(() => _built = result);
  }

  @override
  void dispose() {
    _stopListening?.call();
    super.dispose();
  }

  bool _shouldBuild(R result) {
    return widget.builder != null &&
        result != _built &&
        (widget.buildWhen?.call(_built, result) ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder?.call(context, _built) ?? widget.child!;
  }
}

/// Renders a source through an [ObserverSlot] and builds from a value
/// selected from its results, rebuilding only when that value changes.
///
/// Selected values go through structural sharing, so lists, maps, and sets
/// that are equal by content count as unchanged.
class ResultSelector<S, R, T> extends StatefulWidget {
  const ResultSelector({
    super.key,
    required this.source,
    required this.createSlot,
    required this.selector,
    required this.builder,
    required this.debugName,
    required this.debugKey,
  });

  final S source;
  final SlotFactory<S, R> createSlot;

  /// See [ResultSubscriber.debugName].
  final String debugName;

  /// See [ResultSubscriber.debugKey].
  final DebugRecreatedKey<S> debugKey;
  final T Function(R result) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  State<ResultSelector<S, R, T>> createState() =>
      _ResultSelectorState<S, R, T>();
}

class _ResultSelectorState<S, R, T> extends State<ResultSelector<S, R, T>>
    with
        _SlotHost<S, R, ResultSelector<S, R, T>>,
        _ResultHost<S, R, ResultSelector<S, R, T>> {
  late T _value;

  @override
  S get _source => widget.source;

  @override
  SlotFactory<S, R> get _createSlot => widget.createSlot;

  @override
  DebugRecreatedKey<S> get _debugKey => widget.debugKey;

  @override
  String get _debugName => widget.debugName;

  @override
  void didUpdateWidget(ResultSelector<S, R, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _didUpdateSource(oldWidget.source);
  }

  @override
  void _onAttached(R result) => _value = widget.selector(result);

  @override
  void _onUpdated(R result) {
    // The new selector may read other values, so select again.
    _value = _select(result);
  }

  T _select(R result) {
    final next = widget.selector(result);
    final shared = replaceEqualDeep(_value, next);
    return shared is T ? shared : next;
  }

  @override
  void _onResult(R result) {
    final next = _select(result);
    if (identical(next, _value)) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

typedef _Runs<TData, TVariables, TContext>
    = List<MutationState<TData, TVariables, TContext>>;

/// Calls [listener] for each later change of each run that [source] finds,
/// through [MutationStateSlot.subscribeToRuns], and builds [child]. It never
/// rebuilds.
///
/// [listenWhen] compares the state that run had before with its new state.
class MutationRunListener<TData, TVariables, TContext> extends StatefulWidget {
  const MutationRunListener({
    super.key,
    required this.source,
    required this.listener,
    this.listenWhen,
    required this.child,
    required this.debugName,
  });

  final MutationStateSource<TData, TVariables, TContext> source;
  final ResultWidgetListener<MutationState<TData, TVariables, TContext>>
      listener;
  final ResultCondition<MutationState<TData, TVariables, TContext>>? listenWhen;
  final Widget child;

  /// See [ResultSubscriber.debugName].
  final String debugName;

  @override
  State<MutationRunListener<TData, TVariables, TContext>> createState() =>
      _MutationRunListenerState<TData, TVariables, TContext>();
}

class _MutationRunListenerState<TData, TVariables, TContext>
    extends State<MutationRunListener<TData, TVariables, TContext>>
    with
        _SlotHost<
            MutationStateSource<TData, TVariables, TContext>,
            _Runs<TData, TVariables, TContext>,
            MutationRunListener<TData, TVariables, TContext>> {
  @override
  MutationStateSource<TData, TVariables, TContext> get _source => widget.source;

  @override
  SlotFactory<MutationStateSource<TData, TVariables, TContext>,
          _Runs<TData, TVariables, TContext>>
      get _createSlot => MutationStateSlot<TData, TVariables, TContext>.new;

  @override
  DebugRecreatedKey<MutationStateSource<TData, TVariables, TContext>>
      get _debugKey => debugNoRecreatedKey;

  @override
  String get _debugName => widget.debugName;

  @override
  void didUpdateWidget(
    MutationRunListener<TData, TVariables, TContext> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    _didUpdateSource(oldWidget.source);
  }

  // The core keeps what each run was before, so the list isn't needed.
  @override
  void _onAttached(_Runs<TData, TVariables, TContext> result) {}

  @override
  void _onUpdated(_Runs<TData, TVariables, TContext> result) {}

  @override
  void Function() _subscribeTo(
    ObserverSlot<MutationStateSource<TData, TVariables, TContext>,
            _Runs<TData, TVariables, TContext>>
        slot,
  ) {
    final runs = slot as MutationStateSlot<TData, TVariables, TContext>;
    return runs.subscribeToRuns((previous, current) {
      if (widget.listenWhen?.call(previous, current) ?? true) {
        widget.listener(context, current);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
