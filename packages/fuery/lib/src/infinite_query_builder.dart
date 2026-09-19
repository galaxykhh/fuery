import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

typedef State<Param, Data, Err>
    = InfiniteQueryState<List<InfiniteData<Param, Data>>, Err>;
typedef InfiniteQueryWidgetBuilder<Data, Err> = Widget Function(
    BuildContext context, InfiniteQueryState<Data, Err> state);

class InfiniteQueryBuilder<Param, Data, Err> extends StatelessWidget {
  const InfiniteQueryBuilder({
    required this.query,
    required this.builder,
    super.key,
  });

  final InfiniteQueryResult<Param, Data, Err> query;
  final InfiniteQueryWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<State<Param, Data, Err>>(
      stream: query.stream as Stream<State<Param, Data, Err>>,
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
