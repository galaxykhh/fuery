import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

/// `QueryWidgetBuilder` is a callback used to handle data and errors.
/// It takes `BuildContext` and `QueryState<Data, Err>` as parameters and is used to build the UI.
typedef QueryWidgetBuilder<Data, Err> = Widget Function(
    BuildContext context, QueryState<Data, Err> state);

/// QueryBuilder actually performs the data query and updates the UI.
/// It takes query and builder as parameters.
///
/// example:
/// ```dart
/// QueryBuilder(
///		query: todos,
///		builder: (context, state) {
///			switch (state.status) {
///				case QueryStatus.idle:
///				case QueryStatus.pending:
///					return Text('LOADING);
///
///				case QueryStatus.failure:
///					return Text('ERROR');
///
///				case QueryStatus.success:
///					return ...
/// ```
class QueryBuilder<Data, Err> extends StatelessWidget {
  const QueryBuilder({
    required this.query,
    required this.builder,
    super.key,
  });

  final QueryResult<Data, Err> query;
  final QueryWidgetBuilder<Data, Err> builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueryState<Data, Err>>(
      stream: query.stream,
      builder: (context, snapshot) {
        return Offstage(
          offstage: !snapshot.hasData,
          child: snapshot.hasData
              ? builder(context, snapshot.data!)
              : const SizedBox(),
        );
      },
    );
  }
}
