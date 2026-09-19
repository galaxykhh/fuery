import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

/// Builds UI from a query, like `BlocBuilder`.
///
/// Mounting the builder subscribes to [query], which fetches if needed.
/// Create the query once, for example in a `State` field, not in `build`.
///
/// ```dart
/// late final todos = Query.use(
///   queryKey: ['todos'],
///   queryFn: (_) => api.getTodos(),
/// );
///
/// QueryBuilder(
///   query: todos,
///   builder: (context, state) => switch (state) {
///     QueryResult(:final data?) => TodoList(data),
///     QueryResult(:final error?) => Text('$error'),
///     _ => const CircularProgressIndicator(),
///   },
/// )
/// ```
class QueryBuilder<TData extends Object> extends StatelessWidget {
  const QueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.buildWhen,
  });

  final QueryObserver<TData> query;
  final ResultWidgetBuilder<QueryResult<TData>> builder;

  /// Rebuilds only when this returns true for the last built result and the
  /// new one.
  final ResultCondition<QueryResult<TData>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QueryObserver<TData>, QueryResult<TData>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when a query changes, like `BlocListener`. Not called for
/// the result the query already had when the listener mounted.
///
/// ```dart
/// QueryListener(
///   query: todos,
///   listenWhen: (previous, current) => !previous.isError && current.isError,
///   listener: (context, state) => showErrorSnackBar(context, state.error),
///   child: ...,
/// )
/// ```
class QueryListener<TData extends Object> extends StatelessWidget {
  const QueryListener({
    super.key,
    required this.query,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  final QueryObserver<TData> query;
  final ResultWidgetListener<QueryResult<TData>> listener;

  /// Calls [listener] only when this returns true for the previous result and
  /// the new one.
  final ResultCondition<QueryResult<TData>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QueryObserver<TData>, QueryResult<TData>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// A [QueryBuilder] and [QueryListener] in one, like `BlocConsumer`.
class QueryConsumer<TData extends Object> extends StatelessWidget {
  const QueryConsumer({
    super.key,
    required this.query,
    required this.builder,
    required this.listener,
    this.buildWhen,
    this.listenWhen,
  });

  final QueryObserver<TData> query;
  final ResultWidgetBuilder<QueryResult<TData>> builder;
  final ResultWidgetListener<QueryResult<TData>> listener;
  final ResultCondition<QueryResult<TData>>? buildWhen;
  final ResultCondition<QueryResult<TData>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QueryObserver<TData>, QueryResult<TData>>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
    );
  }
}

QueryResult<TData> _initialResult<TData extends Object>(
  QueryObserver<TData> query,
) {
  return query.getOptimisticResult();
}

void Function() _subscribe<TData extends Object>(
  QueryObserver<TData> query,
  void Function(QueryResult<TData>) listener,
) {
  return query.subscribe(listener);
}
