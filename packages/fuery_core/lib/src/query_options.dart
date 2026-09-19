import 'package:fuery_core/src/base/typedefs.dart';

class QueryOptions<Data> {
  const QueryOptions({
    int? gcTime,
    Data? initialData,
    int? staleTime,
    int? refetchInterval,
  })  : _gcTime = gcTime ?? 1000 * 60 * 5,
        _initialData = initialData,
        _staleTime = staleTime ?? 0,
        _refetchInterval = refetchInterval ?? 0;

  final int _gcTime;
  final Data? _initialData;
  final int _staleTime;
  final int _refetchInterval;

  int get gcTime => _gcTime;

  Data? get initialData => _initialData;

  int get staleTime => _staleTime;

  int get refetchInterval => _refetchInterval;

  QueryOptions<Data> copyWith({
    ValueGetter<int>? gcTime,
    ValueGetter<Data>? initialData,
    ValueGetter<int>? staleTime,
    ValueGetter<int>? refetchInterval,
  }) {
    return QueryOptions<Data>(
      gcTime: gcTime != null ? gcTime() : _gcTime,
      initialData: initialData != null ? initialData() : _initialData,
      staleTime: staleTime != null ? staleTime() : _staleTime,
      refetchInterval:
          refetchInterval != null ? refetchInterval() : _refetchInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QueryOptions<Data> &&
        other._gcTime == _gcTime &&
        other._initialData == _initialData &&
        other._staleTime == _staleTime &&
        other._refetchInterval == _refetchInterval;
  }

  @override
  int get hashCode {
    return _gcTime.hashCode ^
        _initialData.hashCode ^
        _staleTime.hashCode ^
        _refetchInterval.hashCode;
  }
}
