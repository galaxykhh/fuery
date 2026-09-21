import 'subscribable.dart';

/// Receives a `setOnline` callback and returns an optional cleanup function.
typedef OnlineSetup = void Function()? Function(
  void Function(bool online) setOnline,
);

/// Tracks whether the device has network connectivity.
///
/// Assumes online by default. Connect a connectivity source with
/// [setEventListener] to pause fetches while offline.
class OnlineManager extends Subscribable<bool> {
  bool _online = true;
  void Function()? _cleanup;
  OnlineSetup _setup = (_) => null;

  @override
  void onSubscribe() {
    if (_cleanup == null) setEventListener(_setup);
  }

  @override
  void onUnsubscribe() {
    if (!hasListeners) {
      _cleanup?.call();
      _cleanup = null;
    }
  }

  /// Replaces the event source used to detect connectivity changes.
  void setEventListener(OnlineSetup setup) {
    _setup = setup;
    _cleanup?.call();
    _cleanup = setup(setOnline);
  }

  void setOnline(bool online) {
    if (_online != online) {
      _online = online;
      for (final listener in listeners) {
        listener(online);
      }
    }
  }

  bool get isOnline => _online;
}

final OnlineManager onlineManager = OnlineManager();
