import 'package:fuery_core/src/mutation_state.dart';
import 'package:rxdart/rxdart.dart';

abstract class MutationResultBase<Data, Err, Mutate, MutateAsync,
    State extends MutationState<Data, Err>> {
  const MutationResultBase({
    required ValueStream<State> data,
    required Mutate mutate,
    required MutateAsync mutateAsync,
  })  : _data = data,
        _mutate = mutate,
        _mutateAsync = mutateAsync;

  final ValueStream<State> _data;
  ValueStream<State> get data => _data;

  final Mutate _mutate;
  Mutate get mutate => _mutate;

  final MutateAsync _mutateAsync;
  MutateAsync get mutateAsync => _mutateAsync;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MutationResultBase &&
        other._data == _data &&
        other._mutate == _mutate &&
        other._mutateAsync == _mutateAsync;
  }

  @override
  int get hashCode => _data.hashCode ^ _mutate.hashCode ^ _mutateAsync.hashCode;
}
