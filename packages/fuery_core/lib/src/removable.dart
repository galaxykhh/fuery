part of 'core.dart';

const Duration _defaultGcTime = Duration(minutes: 5);

/// Base for cache entries that are garbage collected [_gcTime] after they
/// become unused.
abstract class _Removable {
  Duration _gcTime = Duration.zero;
  Timer? _gcTimer;

  @mustCallSuper
  void _destroy() => _clearGcTimeout();

  void _scheduleGc() {
    _clearGcTimeout();

    if (isValidTimeout(_gcTime)) {
      _gcTimer = Timer(_gcTime, _optionalRemove);
    }
  }

  /// Keeps the longest gcTime requested by any user of this entry.
  void _updateGcTime(Duration? newGcTime) {
    final next = newGcTime ?? _defaultGcTime;
    if (next > _gcTime) _gcTime = next;
  }

  void _clearGcTimeout() {
    _gcTimer?.cancel();
    _gcTimer = null;
  }

  void _optionalRemove();
}
