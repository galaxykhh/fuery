import 'dart:async';

mixin GarbageCollector {
  Timer? _timer;

  /// Set timer if timer is null.
  void setGcTimer({
    required int gcTime,
    required void Function() callback,
  }) {
    _timer ??= Timer(
      Duration(milliseconds: gcTime),
      callback,
    );
  }

  /// Cancel timer if timer exists.
  void cancelGcTimer() {
    if (hasGcTimer) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool get hasGcTimer => _timer is Timer;
}
