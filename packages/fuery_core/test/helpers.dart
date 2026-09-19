import 'package:fake_async/fake_async.dart';
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

/// Runs [body] with fake timers, microtasks, and clock.
void fakeTest(String description, void Function(FakeAsync async) body) {
  test(description, () => fakeAsync(body));
}

/// Resets global managers between tests.
void resetManagers() {
  focusManager.setFocused(null);
  onlineManager.setOnline(true);
}

/// A query function that counts calls and resolves after [delay].
class FakeFetcher<T extends Object> {
  FakeFetcher(this.value, {this.delay = const Duration(milliseconds: 10)});

  T Function() value;
  Duration delay;
  Object? error;
  int calls = 0;

  Future<T> call(QueryFunctionContext context) async {
    calls++;
    await Future<void>.delayed(delay);
    final error = this.error;
    if (error != null) throw error;
    return value();
  }
}

const ms10 = Duration(milliseconds: 10);
