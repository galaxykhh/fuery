import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'result_subscriber.dart';

/// Builds UI from a list of queries of one data type, such as one query per
/// id, with every result in the order of [queries].
///
/// The list can be built in `build`. Every query keeps its observer while its
/// key stays in the list, even when the list is reordered, and changes that
/// arrive together rebuild once.
///
/// ```dart
/// QueriesBuilder(
///   queries: [for (final id in ids) todoQuery(id)],
///   builder: (context, results) => results.every((r) => r.hasData)
///       ? Text('${results.length} loaded')
///       : const CircularProgressIndicator(),
/// )
/// ```
class QueriesBuilder<TData extends Object> extends StatelessWidget {
  const QueriesBuilder({
    super.key,
    required this.queries,
    required this.builder,
    this.buildWhen,
  });

  final List<QuerySource<TData>> queries;
  final ResultWidgetBuilder<List<QueryResult<TData>>> builder;

  /// Rebuilds only when this returns true for the last built results and the
  /// new ones.
  final ResultCondition<List<QueryResult<TData>>>? buildWhen;

  @override
  Widget build(BuildContext context) {
    return ResultSubscriber<List<QuerySource<TData>>, List<QueryResult<TData>>>(
      source: queries,
      createSlot: QueriesSlot<TData>.new,
      builder: builder,
      buildWhen: buildWhen,
    );
  }
}

/// Builds UI from a value combined from a list of queries, and rebuilds only
/// when that value changes.
///
/// ```dart
/// QueriesSelector(
///   queries: [for (final id in ids) todoQuery(id)],
///   selector: (results) =>
///       results.where((result) => result.data?.done ?? false).length,
///   builder: (context, doneCount) => Text('$doneCount done'),
/// )
/// ```
class QueriesSelector<TData extends Object, T> extends StatelessWidget {
  const QueriesSelector({
    super.key,
    required this.queries,
    required this.selector,
    required this.builder,
  });

  final List<QuerySource<TData>> queries;
  final T Function(List<QueryResult<TData>> results) selector;
  final ResultWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return ResultSelector<List<QuerySource<TData>>, List<QueryResult<TData>>,
        T>(
      source: queries,
      createSlot: QueriesSlot<TData>.new,
      selector: selector,
      builder: builder,
    );
  }
}
