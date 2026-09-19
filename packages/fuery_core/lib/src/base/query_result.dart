import 'package:fuery_core/src/base/query_state.dart';
import 'package:fuery_core/src/query_options.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:rxdart/rxdart.dart';

class QueryResultBase<Data, Err, State extends QueryState<Data, Err>> {
  const QueryResultBase({
    required ValueStream<State> stream,
    required void Function() refetch,
    required void Function(QueryOptions<Data> options) updateOptions,
  })  : _stream = stream,
        _refetch = refetch,
        _updateOptions = updateOptions;

  final ValueStream<State> _stream;

  ValueStream<State> get stream => _stream;

  Stream<Data?> get data => _stream.map((s) => s.data);
  Data? get dataValue => _stream.value.data;

  Stream<QueryStatus> get status => _stream.map((s) => s.status);
  QueryStatus get statusValue => _stream.value.status;

  Stream<FetchStatus> get fetchStatus => _stream.map((s) => s.fetchStatus);
  FetchStatus get fetchStatusValue => _stream.value.fetchStatus;

  Stream<Err?> get error => _stream.map((s) => s.error);
  Err? get errorValue => _stream.value.error;

  final void Function() _refetch;
  void Function() get refetch => _refetch;

  final void Function(QueryOptions<Data> options) _updateOptions;

  void updateOptions({
    int? gcTime,
    int? staleTime,
    int? refetchInterval,
    Data? initialData,
  }) {
    _updateOptions(QueryOptions<Data>(
      gcTime: gcTime,
      staleTime: staleTime,
      refetchInterval: refetchInterval,
      initialData: initialData,
    ));
  }

  bool get isSuccess => _stream.value.isSuccess;

  bool get isPending => _stream.value.isPending;

  bool get isFetching => _stream.value.isFetching;

  bool get isLoading => _stream.value.isPending || _stream.value.isFetching;

  bool get isRefetching => _stream.value.fetchStatus.isRefetching;

  bool get isError => _stream.value.error != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QueryResultBase &&
        other._stream == _stream &&
        other._refetch == _refetch &&
        other._updateOptions == _updateOptions;
  }

  @override
  int get hashCode =>
      _stream.hashCode ^ _refetch.hashCode ^ _updateOptions.hashCode;
}
