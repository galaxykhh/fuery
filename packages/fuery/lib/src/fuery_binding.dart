import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

/// Connects Fuery to the Flutter app lifecycle.
///
/// When the app returns to the foreground, stale queries refetch and paused
/// retries resume. Fuery widgets and [FueryProvider] call [ensureInitialized]
/// for you; call it yourself if you only use observers from blocs.
abstract final class FueryBinding {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    focusManager.setEventListener((setFocused) {
      final listener = AppLifecycleListener(
        onStateChange: (state) {
          switch (state) {
            case AppLifecycleState.resumed:
              setFocused(true);
            case AppLifecycleState.hidden:
            case AppLifecycleState.paused:
            case AppLifecycleState.detached:
              setFocused(false);
            case AppLifecycleState.inactive:
              // Brief interruptions, such as a system dialog, are not a
              // focus change.
              break;
          }
        },
      );
      return listener.dispose;
    });
  }
}
