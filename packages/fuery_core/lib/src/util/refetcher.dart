import 'dart:async';

mixin Refetcher {
  Timer? _timer;

  /// Set timer if timer is null.
  void setRefetchTimer({
    required int interval,
    required void Function() callback,
  }) {
    _timer ??= Timer.periodic(
      Duration(milliseconds: interval),
      (_) => callback(),
    );
  }

  /// Cancel timer if timer exists.
  void cancelRefetchTimer() {
    if (hasRefetchTimer) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool get hasRefetchTimer => _timer is Timer;
}
