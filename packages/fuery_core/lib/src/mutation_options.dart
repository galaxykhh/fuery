import 'package:fuery_core/src/base/typedefs.dart';

class MutationOptions<Params, Data, Err> {
  MutationOptions({
    Params? params,
    int? gcTime,
    MutationMutateCallback<Params>? onMutate,
    MutationSuccessCallback<Params, Data>? onSuccess,
    MutationErrorCallback<Params, Err>? onError,
  })  : _params = params,
        _gcTime = gcTime ?? 0,
        _onMutate = onMutate,
        _onSuccess = onSuccess,
        _onError = onError;

  final Params? _params;
  Params? get params => _params;

  final int _gcTime;
  int get gcTime => _gcTime;

  final MutationMutateCallback<Params>? _onMutate;
  MutationMutateCallback<Params>? get onMutate => _onMutate;

  final MutationSuccessCallback<Params, Data>? _onSuccess;
  MutationSuccessCallback<Params, Data>? get onSuccess => _onSuccess;

  final MutationErrorCallback<Params, Err>? _onError;
  MutationErrorCallback<Params, Err>? get onError => _onError;

  MutationOptions<Params, Data, Err> copyWith({
    ValueGetter<Params>? params,
    ValueGetter<int>? gcTime,
    ValueGetter<MutationMutateCallback<Params>>? onMutate,
    ValueGetter<MutationSuccessCallback<Params, Data>>? onSuccess,
    ValueGetter<MutationErrorCallback<Params, Err>>? onError,
  }) {
    return MutationOptions<Params, Data, Err>(
      params: params != null ? params() : this.params,
      onMutate: onMutate != null ? onMutate() : this.onMutate,
      onSuccess: onSuccess != null ? onSuccess() : this.onSuccess,
      onError: onError != null ? onError() : this.onError,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MutationOptions<Params, Data, Err> &&
        other._params == _params &&
        other._gcTime == _gcTime &&
        other._onMutate == _onMutate &&
        other._onSuccess == _onSuccess &&
        other._onError == _onError;
  }

  @override
  int get hashCode {
    return _params.hashCode ^
        _gcTime.hashCode ^
        _onMutate.hashCode ^
        _onSuccess.hashCode ^
        _onError.hashCode;
  }
}
