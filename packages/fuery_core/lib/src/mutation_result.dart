import 'package:fuery_core/src/base/mutation_result.dart';
import 'package:fuery_core/src/mutation_state.dart';

class MutationResult<Data, Err, MutateType, MutateAsyncType>
    extends MutationResultBase<Data, Err, MutateType, MutateAsyncType,
        MutationState<Data, Err>> {
  MutationResult({
    required super.data,
    required super.mutate,
    required super.mutateAsync,
  });
}
