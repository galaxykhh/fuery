import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

typedef State<Param, Data, Err>
    = InfiniteQueryState<List<InfiniteData<Param, Data>>, Err>;

class InfiniteQueryBuilder<Param, Data, Err> extends StatelessWidget {
  const InfiniteQueryBuilder({
    required this.query,
    required this.builder,
    super.key,
  });

  final InfiniteQueryResult<Param, Data, Err> query;
  final Widget Function(
    BuildContext context,
    State<Param, Data, Err> state,
  ) builder;

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
