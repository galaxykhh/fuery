import 'dart:async';

/// Thrown by [AbortSignal.throwIfAborted] when no custom reason was given.
class AbortedException implements Exception {
  const AbortedException();

  @override
  String toString() => 'AbortedException: the operation was aborted';
}

/// Signals that the work a query function is doing is no longer needed.
///
/// Reading `context.signal` inside a query function tells Fuery that the
/// function supports cancellation, so the fetch is aborted when the last
/// listener goes away instead of being left to finish in the background.
class AbortSignal {
  AbortSignal._();

  bool _aborted = false;
  Object? _reason;
  final List<void Function()> _listeners = [];

  bool get aborted => _aborted;

  Object? get reason => _reason;

  /// Calls [listener] once when the signal is aborted. Returns a function that
  /// removes the listener.
  void Function() onAbort(void Function() listener) {
    if (_aborted) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Completes when the signal is aborted.
  Future<void> get whenAborted {
    if (_aborted) return Future.value();
    final completer = Completer<void>();
    onAbort(completer.complete);
    return completer.future;
  }

  void throwIfAborted() {
    if (_aborted) throw _reason ?? const AbortedException();
  }
}

class AbortController {
  final AbortSignal signal = AbortSignal._();

  void abort([Object? reason]) {
    if (signal._aborted) return;
    signal._aborted = true;
    signal._reason = reason ?? const AbortedException();

    final listeners = signal._listeners.toList();
    signal._listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}
