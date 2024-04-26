import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

/// `MutationWidgetBuilder` is a callback used to handle data and errors.
/// It takes `BuildContext` and `MutationState<Data, Err>` as parameters and is used to build the UI.
typedef MutationWidgetBuilder<Data, Err> = Widget Function(
    BuildContext context, MutationState<Data, Err> state);

/// MutationBuilder actually performs the data query and updates the UI.
/// It takes query and builder as parameters.
///
/// example:
/// ```dart
/// MutationBuilder(
///		mutation: removeTodo,
///		builder: (context, state) {
///			return ...
/// ```
class MutationBuilder<Data, Err> extends StatelessWidget {
  const MutationBuilder({
    required this.mutation,
    required this.builder,
    super.key,
  });

  final MutationResult<Data, Err, dynamic, dynamic> mutation;
  final MutationWidgetBuilder<Data, Err> builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MutationState<Data, Err>>(
      stream: mutation.data,
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
