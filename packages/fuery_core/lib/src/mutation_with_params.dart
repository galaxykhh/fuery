part of 'mutation.dart';

class MutationWithParams<Params, Data, Err>
    extends Mutation<Params, Data, Err> {
  MutationWithParams({
    required MutationAsyncFn<Params, Data, Err> mutationFn,
    MutationOptions<Params, Data, Err>? options,
    MutationKey? mutationKey,
  })  : _mutationFn = mutationFn,
        super._(
          mutationKey: mutationKey,
          options: options,
        );

  final MutationAsyncFn<Params, Data, Err> _mutationFn;

  Future<Data> _invoke(Params params) async {
    setParams(params);
    emit(stream.value.copyWith(status: MutationStatus.pending));

    try {
      final Future<Data> future = _mutationFn(params);

      options.onMutate?.call(params);

      final Data data = await future;

      emit(stream.value.copyWith(
        data: () => data,
        status: MutationStatus.success,
      ));
      options.onSuccess?.call(params, data);

      return data;
    } catch (e) {
      emit(
        stream.value.copyWith(
          status: MutationStatus.failure,
          error: () => e as Err,
        ),
      );
      options.onError?.call(params, e as Err);
      rethrow;
    }
  }

  void mutate(Params params) => _invoke(params);

  Future<Data> mutateAsync(Params params) async => await _invoke(params);
}
