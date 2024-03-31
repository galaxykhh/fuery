import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

class QueryBuilder<Data, Err> extends StatelessWidget {
  const QueryBuilder({
    required this.query,
    required this.builder,
    super.key,
  });

  final QueryResult<Data, Err> query;
  final Widget Function(
    BuildContext context,
    QueryState<Data, Err> state,
  ) builder;

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
