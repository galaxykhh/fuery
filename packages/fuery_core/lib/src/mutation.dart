import 'dart:async';

import 'package:fuery_core/src/base/mutation.dart';
import 'package:fuery_core/src/base/mutation_state.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/fuery_client.dart';
import 'package:fuery_core/src/mutation_options.dart';
import 'package:fuery_core/src/mutation_result.dart';
import 'package:fuery_core/src/mutation_state.dart';

part 'mutation_with_params.dart';
part 'mutation_without_params.dart';

sealed class Mutation<Params, Data, Err>
    extends MutationBase<Params, Data, Err, MutationState<Data, Err>> {
  Mutation._({
    MutationKey? mutationKey,
    super.options,
  }) : super(mutationKey: mutationKey ?? []);

  /// Returns cached [MutationBase] if exists. If it doesn't exist, cache the Mutation instance and return it.
  static MutationBase _getCachedMutation<T>({
    required MutationKey? mutationKey,
    required MutationBase Function() orElse,
  }) {
    try {
      final bool hasMutationKey = mutationKey != null;

      if (hasMutationKey) {
        assert(mutationKey.isNotEmpty, 'mutationKey should not be empty');

        final MutationBase? mutation = Fuery.instance.getMutation(mutationKey);
        final bool exists = mutation is MutationBase;

        if (exists) {
          return mutation;
        }
      }

      return orElse();
    } catch (_) {
      rethrow;
    }
  }

  /// Returns [MutationResult] new or existing [Mutation].
  /// If there is no existing [Mutation] with the same [mutationKey], it creates a new [Mutation] instance.
  ///
  /// [onMutate] is called when either [mutationFn] is invoked.
  ///
  /// [onSuccess] is called when the [mutationFn] has successfully completed.
  ///
  /// [onError] is called when an error occurs in the [mutationFn].
  ///
  /// example:
  /// ```dart
  /// late final createPost = Mutation.use(
  /// 	mutationFn: (String content) => repository.createPost(content),
  /// 	onMutate: (param) => print('mutate started with $param'),
  /// 	onSuccess: (param, data) {
  /// 		Fuery.instance.invalidateQueries(queryKey: ['posts']);
  /// 	},
  /// );
  /// ```
  static MutationResult<Data, Err, MutationSyncFn<Params, Data, Err>,
      MutationAsyncFn<Params, Data, Err>> use<Params, Data, Err>({
    required MutationAsyncFn<Params, Data, Err> mutationFn,
    MutationKey? mutationKey,
    int? gcTime,
    MutationMutateCallback<Params>? onMutate,
    MutationSuccessCallback<Params, Data>? onSuccess,
    MutationErrorCallback<Params, Err>? onError,
  }) {
    try {
      final MutationWithParams<Params, Data, Err> mutation =
          _getCachedMutation<MutationWithParams<Params, Data, Err>>(
        mutationKey: mutationKey,
        orElse: () {
          final MutationWithParams<Params, Data, Err> mutation =
              MutationWithParams<Params, Data, Err>(
            mutationKey: mutationKey,
            mutationFn: mutationFn,
            options: MutationOptions<Params, Data, Err>(
              gcTime: gcTime,
              onMutate: onMutate,
              onSuccess: onSuccess,
              onError: onError,
            ),
          );

          if (mutationKey != null) {
            Fuery.instance.addMutation(mutationKey, mutation);
          }

          return mutation;
        },
      ) as MutationWithParams<Params, Data, Err>;

      return MutationResult(
        data: mutation.stream,
        mutate: mutation.mutate,
        mutateAsync: mutation.mutateAsync,
      );
    } catch (_) {
      rethrow;
    }
  }

  /// returns [MutationResult] by new or existing [Mutation].
  /// If there is no existing [Mutation] with the same [mutationKey], it creates a new [Mutation] instance.
  ///
  /// [onMutate] is called when either [mutationFn] is invoked.
  ///
  /// [onSuccess] is called when the [mutationFn] has successfully completed.
  ///
  /// [onError] is called when an error occurs in the [mutationFn].
  ///
  /// example:
  /// ```dart
  /// late final createPost = Mutation.noParam(
  /// 	mutationFn: () => repository.removeAll(),
  /// 	onMutate: () => print('mutate started'),
  /// );
  /// ```
  static MutationResult<Data, Err, MutationNoParamSyncFn,
      MutationNoParamAsyncFn<Data, Err>> noParam<Data, Err>({
    required MutationNoParamAsyncFn<Data, Err> mutationFn,
    MutationKey? mutationKey,
    int? gcTime,
    MutationNoParamMutateCallback? onMutate,
    MutationNoParamSuccessCallback<Data>? onSuccess,
    MutationNoParamErrorCallback<Err>? onError,
  }) {
    try {
      final MutationNoParams<Data, Err> mutation =
          _getCachedMutation<MutationNoParams<Data, Err>>(
        mutationKey: mutationKey,
        orElse: () {
          final MutationNoParams<Data, Err> mutation =
              MutationNoParams<Data, Err>(
            mutationKey: mutationKey,
            mutationFn: mutationFn,
            options: MutationOptions(
              onMutate: (_) => onMutate?.call(),
              onSuccess: (_, data) => onSuccess?.call(data),
              onError: (_, error) => onError?.call(error),
            ),
          );

          if (mutationKey != null) {
            Fuery.instance.addMutation(mutationKey, mutation);
          }

          return mutation;
        },
      ) as MutationNoParams<Data, Err>;

      return MutationResult(
        data: mutation.stream,
        mutate: mutation.mutate,
        mutateAsync: mutation.mutateAsync,
      );
    } catch (_) {
      rethrow;
    }
  }
}
