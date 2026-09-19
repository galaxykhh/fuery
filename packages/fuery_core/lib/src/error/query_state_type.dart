part of 'fuery_exception.dart';

class QueryStateTypeException<T> extends FueryException {
  QueryStateTypeException({
    super.message,
    required this.data,
  });

  final T data;
}
