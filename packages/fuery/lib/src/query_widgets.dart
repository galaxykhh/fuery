import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

/// Builds UI from a query.
///
/// Mounting the builder subscribes to [query], which fetches if needed.
/// Create the query once, for example in a `State` field, not in `build`.
///
/// ```dart
/// final todos = Query.use(
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
      debugKey: _debugKey,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Runs side effects when a query changes. Not called for
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
      debugKey: _debugKey,
      listener: listener,
      listenWhen: listenWhen,
      child: child,
    );
  }
}

/// A [QueryBuilder] and [QueryListener] in one.
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
      debugKey: _debugKey,
      builder: builder,
      buildWhen: buildWhen,
      listener: listener,
      listenWhen: listenWhen,
    );
  }
}

/// Builds UI from a value selected from a query's results, and rebuilds only
/// when that value changes.
///
/// Lists, maps, and sets are compared by content, other values with `==`.
///
/// ```dart
/// QuerySelector(
///   query: todos,
///   selector: (state) => state.data?.where((todo) => todo.done).length ?? 0,
///   builder: (context, doneCount) => Text('$doneCount done'),
/// )
/// ```
class QuerySelector<TData extends Object, T> extends StatelessWidget {
  const QuerySelector({
    super.key,
    required this.query,
    required this.selector,
    required this.builder,
  });

  final QueryObserver<TData> query;
  final T Function(QueryResult<TData> state) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<QueryObserver<TData>, QueryResult<TData>, T>(
      source: query,
      initialResult: _initialResult,
      subscribe: _subscribe,
      debugKey: _debugKey,
      selector: selector,
      builder: builder,
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

String _debugKey<TData extends Object>(QueryObserver<TData> query) =>
    hashKey(query.options.queryKey);
