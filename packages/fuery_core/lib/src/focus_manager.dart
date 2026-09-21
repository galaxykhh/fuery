import 'subscribable.dart';

/// Receives a `setFocused` callback and returns an optional cleanup function.
/// Call `setFocused(true/false)` to set the state, or `setFocused()` to notify
/// listeners with the current state.
typedef FocusSetup = void Function()? Function(
  void Function([bool? focused]) setFocused,
);

/// Tracks whether the app is focused (in the foreground).
///
/// Pure Dart has no notion of focus, so the app is considered focused unless
/// told otherwise. The Flutter binding connects this to the app lifecycle.
class FocusManager extends Subscribable<bool> {
  bool? _focused;
  void Function()? _cleanup;
  FocusSetup _setup = (_) => null;

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

  /// Replaces the event source used to detect focus changes.
  void setEventListener(FocusSetup setup) {
    _setup = setup;
    _cleanup?.call();
    _cleanup = setup(([focused]) {
      if (focused != null) {
        setFocused(focused);
      } else {
        onFocus();
      }
    });
  }

  /// Sets the focus state manually. Pass `null` to fall back to the default.
  void setFocused(bool? focused) {
    if (_focused != focused) {
      _focused = focused;
      onFocus();
    }
  }

  /// Notifies listeners with the current focus state.
  void onFocus() {
    final focused = isFocused;
    for (final listener in listeners) {
      listener(focused);
    }
  }

  bool get isFocused => _focused ?? true;
}

final FocusManager focusManager = FocusManager();
