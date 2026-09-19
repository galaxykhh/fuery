part 'invalid_timestamp.dart';
part 'query_state_type.dart';

sealed class FueryException {
  const FueryException({this.message = ''});

  final String message;

  @override
  bool operator ==(covariant FueryException other) {
    if (identical(this, other)) return true;

    return other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}
