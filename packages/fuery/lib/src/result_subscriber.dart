import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';
import 'fuery_provider.dart';

/// Keys already warned about, so each mistake is reported once.
final Set<String> _warnedKeys = {};

/// Warns, in debug builds, when a widget got a new observer for the same key
/// on a rebuild. That is what `todosQuery.observe()` in `build` looks like,
/// and each new observer subscribes and refetches again.
void debugWarnRecreated<S>(
  String widgetName,
  String? Function(S source)? key,
  S previous,
  S current,
) {
  assert(() {
    if (key == null) return true;
    final keyHash = key(current);
    if (keyHash == null || keyHash != key(previous)) return true;
    if (!_warnedKeys.add(keyHash)) return true;
    debugPrint(
      '[fuery] $widgetName received a new observer for the key $keyHash on '
      'a rebuild. A new observer subscribes and refetches again each time. '
      'Pass the definition instead, such as QueryBuilder(query: todosQuery), '
      'and the widget keeps one observer for it. See https://galaxykhh.github'
      '.io/fuery/troubleshooting/#a-query-fetches-on-every-rebuild',
    );
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
  String? Function(S source)? get _debugKey;
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
      _onAttached(created.result);
      // Results arrive in a microtask, never during build or initState.
      _unsubscribe = created.subscribe(
        notifyManager.batchCalls((R result) {
          if (mounted) _onResult(result);
        }),
      );
    } else if (!identical(client, _client)) {
      _client = client;
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
  void _update() {
    final slot = this.slot;
    final observer = slot.observer;
    slot.update(_source, _client!);
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

  /// The same observer has [result] after an update, before this build.
  void _onUpdated(R result);

  /// A result arrived after the last build.
  void _onResult(R result);
}

/// Renders a source through an [ObserverSlot] and builds, listens, or both.
///
/// [buildWhen] compares against the result that was last built, and
/// [listenWhen] against the result that was last received.
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
    this.debugKey,
  }) : assert(builder != null || child != null);

  final S source;
  final SlotFactory<S, R> createSlot;

  /// The cache key of [source] when it is an observer, for the debug warning
  /// about observers created on every rebuild.
  final String? Function(S source)? debugKey;
  final ResultWidgetBuilder<R>? builder;
  final ResultCondition<R>? buildWhen;
  final ResultWidgetListener<R>? listener;
  final ResultCondition<R>? listenWhen;
  final Widget? child;

  @override
  State<ResultSubscriber<S, R>> createState() => _ResultSubscriberState<S, R>();
}

class _ResultSubscriberState<S, R> extends State<ResultSubscriber<S, R>>
    with _SlotHost<S, R, ResultSubscriber<S, R>> {
  late R _built;
  late R _previous;

  @override
  S get _source => widget.source;

  @override
  SlotFactory<S, R> get _createSlot => widget.createSlot;

  @override
  String? Function(S source)? get _debugKey => widget.debugKey;

  @override
  String get _debugName => widget.builder != null ? 'A builder' : 'A listener';

  @override
  void didUpdateWidget(ResultSubscriber<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _didUpdateSource(oldWidget.source);
  }

  @override
  void _onAttached(R result) {
    _built = result;
    _previous = result;
  }

  @override
  void _onUpdated(R result) {
    // Listeners hear about it when the result arrives; they must not run
    // during build.
    if (_shouldBuild(result)) _built = result;
  }

  @override
  void _onResult(R result) {
    final previous = _previous;
    if (result == previous) return;
    _previous = result;

    final listener = widget.listener;
    if (listener != null &&
        (widget.listenWhen?.call(previous, result) ?? true)) {
      listener(context, result);
    }

    if (_shouldBuild(result)) setState(() => _built = result);
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
    this.debugKey,
  });

  final S source;
  final SlotFactory<S, R> createSlot;

  /// See [ResultSubscriber.debugKey].
  final String? Function(S source)? debugKey;
  final T Function(R result) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  State<ResultSelector<S, R, T>> createState() =>
      _ResultSelectorState<S, R, T>();
}

class _ResultSelectorState<S, R, T> extends State<ResultSelector<S, R, T>>
    with _SlotHost<S, R, ResultSelector<S, R, T>> {
  late T _value;

  @override
  S get _source => widget.source;

  @override
  SlotFactory<S, R> get _createSlot => widget.createSlot;

  @override
  String? Function(S source)? get _debugKey => widget.debugKey;

  @override
  String get _debugName => 'A selector';

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
