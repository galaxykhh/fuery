class InfiniteData<Param, Data> {
  const InfiniteData({
    required this.data,
    required this.param,
  });

  final Data data;
  final Param param;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InfiniteData<Param, Data> &&
        other.data == data &&
        other.param == param;
  }

  @override
  int get hashCode => data.hashCode ^ param.hashCode;

  @override
  String toString() => 'InfiniteData(data: $data, param: $param)';
}
