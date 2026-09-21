import 'dart:async';

/// Schedules and batches listener notifications.
///
/// Updates made inside [batch] are queued and delivered together once the
/// outermost batch finishes, so a single state change notifies each listener
/// once instead of once per intermediate step.
class NotifyManager {
  List<void Function()> _queue = [];
  int _transactions = 0;

  /// Runs [callback] and defers any notifications scheduled inside it until
  /// the outermost batch completes. Batches can be nested.
  T batch<T>(T Function() callback) {
    _transactions++;
    try {
      return callback();
    } finally {
      _transactions--;
      if (_transactions == 0) _flush();
    }
  }

  /// Wraps [callback] so every call is scheduled on the next batch.
  void Function(T) batchCalls<T>(void Function(T) callback) {
    return (T value) => schedule(() => callback(value));
  }

  /// Schedules [callback] to run on the next batch.
  void schedule(void Function() callback) {
    if (_transactions > 0) {
      _queue.add(callback);
    } else {
      scheduleMicrotask(callback);
    }
  }

  void _flush() {
    final queue = _queue;
    _queue = [];
    if (queue.isEmpty) return;

    scheduleMicrotask(() {
      for (final callback in queue) {
        callback();
      }
    });
  }
}

final NotifyManager notifyManager = NotifyManager();
