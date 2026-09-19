import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuery/fuery.dart';

void main() {
  test('can be initialized before the Flutter binding', () {
    FueryBinding.ensureInitialized();
    expect(WidgetsBinding.instance, isNotNull);
  });
}
