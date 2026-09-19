import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';

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
  }) : assert(builder != null || child != null);

  final S source;
  final R Function(S source) initialResult;
  final void Function() Function(S source, void Function(R) listener) subscribe;
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
