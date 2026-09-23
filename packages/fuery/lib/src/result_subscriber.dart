import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';

/// Keys already warned about, so each mistake is reported once.
final Set<String> _warnedKeys = {};

/// Warns, in debug builds, when a widget got a new observer for the same key
/// on a rebuild. That is what `Query.observe` in `build` looks like, and each new
/// observer subscribes and refetches again.
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
      'a rebuild. A new observer subscribes and refetches again each time, '
      'so create it once, in a State field, a cubit, or a function called '
      'once, and pass that instance. See https://galaxykhh.github.io/fuery/'
      'troubleshooting/#a-query-fetches-on-every-rebuild',
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

/// Subscribes to an observer and builds, listens, or both.
///
/// [buildWhen] compares against the result that was last built, and
/// [listenWhen] against the result that was last received.
class ResultSubscriber<S, R> extends StatefulWidget {
  const ResultSubscriber({
    super.key,
    required this.source,
    required this.initialResult,
    required this.subscribe,
    this.builder,
    this.buildWhen,
    this.listener,
    this.listenWhen,
    this.child,
    this.debugKey,
  }) : assert(builder != null || child != null);

  final S source;
  final R Function(S source) initialResult;
  final void Function() Function(S source, void Function(R) listener) subscribe;

  /// The cache key of [source], for the debug warning about observers
  /// created on every rebuild.
  final String? Function(S source)? debugKey;
  final ResultWidgetBuilder<R>? builder;
  final ResultCondition<R>? buildWhen;
  final ResultWidgetListener<R>? listener;
  final ResultCondition<R>? listenWhen;
  final Widget? child;

  @override
  State<ResultSubscriber<S, R>> createState() => _ResultSubscriberState<S, R>();
}

class _ResultSubscriberState<S, R> extends State<ResultSubscriber<S, R>> {
  late R _built;
  late R _previous;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    FueryBinding.ensureInitialized();
    _subscribe();
  }

  @override
  void didUpdateWidget(ResultSubscriber<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      debugWarnRecreated(
        widget.builder != null ? 'A builder' : 'A listener',
        widget.debugKey,
        oldWidget.source,
        widget.source,
      );
      _unsubscribe?.call();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _subscribe() {
    final source = widget.source;
    final initial = widget.initialResult(source);
    _built = initial;
    _previous = initial;

    // Results arrive in a microtask, never during build or initState.
    _unsubscribe = widget.subscribe(
      source,
      notifyManager.batchCalls((R result) {
        if (mounted && identical(source, widget.source)) _onResult(result);
      }),
    );
  }

  void _onResult(R result) {
    final previous = _previous;
    if (result == previous) return;
    _previous = result;

    final listener = widget.listener;
    if (listener != null &&
        (widget.listenWhen?.call(previous, result) ?? true)) {
      listener(context, result);
    }

    if (widget.builder != null &&
        (widget.buildWhen?.call(_built, result) ?? true)) {
      setState(() => _built = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder?.call(context, _built) ?? widget.child!;
  }
}

/// Subscribes to an observer and builds from a value selected from its
/// results, rebuilding only when that value changes.
///
/// Selected values go through structural sharing, so lists, maps, and sets
/// that are equal by content count as unchanged.
class ResultSelector<S, R, T> extends StatefulWidget {
  const ResultSelector({
    super.key,
    required this.source,
    required this.initialResult,
    required this.subscribe,
    required this.selector,
    required this.builder,
    this.debugKey,
  });

  final S source;
  final R Function(S source) initialResult;
  final void Function() Function(S source, void Function(R) listener) subscribe;

  /// See [ResultSubscriber.debugKey].
  final String? Function(S source)? debugKey;
  final T Function(R result) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  State<ResultSelector<S, R, T>> createState() =>
      _ResultSelectorState<S, R, T>();
}

class _ResultSelectorState<S, R, T> extends State<ResultSelector<S, R, T>> {
  late R _result;
  late T _value;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    FueryBinding.ensureInitialized();
    _subscribe();
  }

  @override
  void didUpdateWidget(ResultSelector<S, R, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      debugWarnRecreated(
        'A selector',
        widget.debugKey,
        oldWidget.source,
        widget.source,
      );
      _unsubscribe?.call();
      _subscribe();
    } else {
      // The new selector may read other values, so select again.
      _value = _select(_result);
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _subscribe() {
    final source = widget.source;
    _result = widget.initialResult(source);
    _value = widget.selector(_result);

    // Results arrive in a microtask, never during build or initState.
    _unsubscribe = widget.subscribe(
      source,
      notifyManager.batchCalls((R result) {
        if (mounted && identical(source, widget.source)) _onResult(result);
      }),
    );
  }

  T _select(R result) {
    final next = widget.selector(result);
    final shared = replaceEqualDeep(_value, next);
    return shared is T ? shared : next;
  }

  void _onResult(R result) {
    _result = result;
    final next = _select(result);
    if (identical(next, _value)) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
