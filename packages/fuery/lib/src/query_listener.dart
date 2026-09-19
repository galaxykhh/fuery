import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

/// Callback function type for the listener
typedef QueryListenerCallback<Data, Err> = void Function(
  BuildContext context,
  QueryState<Data, Err> state,
);

/// Condition function type to determine when the listener should act
typedef QueryListenerCondition<Data, Err> = bool Function(
  QueryState<Data, Err> prev,
  QueryState<Data, Err> curr,
);

/// QueryListener is responsible for listening to changes in the provided
///
/// example:
/// ``` dart
/// QueryListener(
/// 	query: todos,
///		listenWhen: (prev, curr) => prev.fetchStatus != curr.fetchStatus,
///		listener: (context, data) {
/// 		print('FETCH STATUS CHANGED!');
/// 	},
/// 	child: ...
/// ```
class QueryListener<Data, Err> extends StatefulWidget {
  const QueryListener({
    required this.query,
    this.listenWhen,
    required this.listener,
    required this.child,
    super.key,
  });

  final QueryResult<Data, Err> query;
  final QueryListenerCondition<Data, Err>? listenWhen;
  final QueryListenerCallback<Data, Err> listener;
  final Widget child;

  @override
  State<QueryListener<Data, Err>> createState() =>
      _QueryListenerState<Data, Err>();
}

class _QueryListenerState<Data, Err> extends State<QueryListener<Data, Err>> {
  late final StreamSubscription<QueryState<Data, Err>> _subscription;
  QueryState<Data, Err>? _previousState;

  @override
  void initState() {
    _subscription = widget.query.stream.listen(_listenState);
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  _listenState(QueryState<Data, Err> state) {
    if (widget.listenWhen == null) {
      widget.listener(context, state);
      return;
    }

    final bool shouldAct =
        widget.listenWhen!(_previousState ?? state, state) == true;

    if (shouldAct) {
      widget.listener(context, state);
    }

    _previousState = state;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
