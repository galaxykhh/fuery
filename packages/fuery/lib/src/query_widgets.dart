import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

/// Builds UI from a query.
///
/// [query] is a [Query] definition, or an observer that is already shared.
/// A definition can be built in `build`: the widget keeps one observer for
/// it, and follows a new key or new options on every rebuild. Mounting
/// subscribes, which fetches if needed.
///
/// ```dart
/// final todos = Query(queryKey: ['todos'], queryFn: (_) => api.getTodos());
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

  final QuerySource<TData> query;
  final ResultWidgetBuilder<QueryResult<TData>> builder;

  /// Rebuilds only when this returns true for the last built result and the
  /// new one.
  final ResultCondition<QueryResult<TData>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QuerySource<TData>, QueryResult<TData>>(
      source: query,
      createSlot: QuerySlot<TData>.new,
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

  final QuerySource<TData> query;
  final ResultWidgetListener<QueryResult<TData>> listener;

  /// Calls [listener] only when this returns true for the previous result and
  /// the new one.
  final ResultCondition<QueryResult<TData>>? listenWhen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QuerySource<TData>, QueryResult<TData>>(
      source: query,
      createSlot: QuerySlot<TData>.new,
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

  final QuerySource<TData> query;
  final ResultWidgetBuilder<QueryResult<TData>> builder;
  final ResultWidgetListener<QueryResult<TData>> listener;
  final ResultCondition<QueryResult<TData>>? buildWhen;
  final ResultCondition<QueryResult<TData>>? listenWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<QuerySource<TData>, QueryResult<TData>>(
      source: query,
      createSlot: QuerySlot<TData>.new,
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

  final QuerySource<TData> query;
  final T Function(QueryResult<TData> state) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<QuerySource<TData>, QueryResult<TData>, T>(
      source: query,
      createSlot: QuerySlot<TData>.new,
      debugKey: _debugKey,
      selector: selector,
      builder: builder,
    );
  }
}

String? _debugKey<TData extends Object>(QuerySource<TData> query) {
  return query is QueryObserver<TData> ? hashKey(query.options.queryKey) : null;
}
