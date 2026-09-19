import 'dart:async';

import 'package:meta/meta.dart';

import 'utils.dart';

const Duration defaultGcTime = Duration(minutes: 5);

/// Base for cache entries that are garbage collected [gcTime] after they
/// become unused.
abstract class Removable {
  Duration gcTime = Duration.zero;
  Timer? _gcTimer;

  @mustCallSuper
  void destroy() => clearGcTimeout();

  @protected
  void scheduleGc() {
    clearGcTimeout();

    if (isValidTimeout(gcTime)) {
      _gcTimer = Timer(gcTime, optionalRemove);
    }
  }

  /// Keeps the longest gcTime requested by any user of this entry.
  @protected
  void updateGcTime(Duration? newGcTime) {
    final next = newGcTime ?? defaultGcTime;
    if (next > gcTime) gcTime = next;
  }

  @protected
  void clearGcTimeout() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  @protected
  void optionalRemove();
}
