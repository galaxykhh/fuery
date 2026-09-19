part of 'fuery_exception.dart';

class InvalidTimestampException extends FueryException {
  InvalidTimestampException({
    super.message,
    required this.value,
  });

  final int value;
}
