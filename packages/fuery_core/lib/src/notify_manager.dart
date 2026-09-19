import 'dart:async';

typedef NotifyCallback = void Function();
typedef NotifyFunction = void Function(NotifyCallback callback);
typedef ScheduleFunction = void Function(NotifyCallback callback);

/// Schedules and batches listener notifications.
///
/// Updates made inside [batch] are queued and delivered together once the
/// outermost batch finishes, so a single state change notifies each listener
/// once instead of once per intermediate step.
class NotifyManager {
  List<NotifyCallback> _queue = [];
  int _transactions = 0;
  NotifyFunction _notifyFn = (callback) => callback();
  NotifyFunction _batchNotifyFn = (callback) => callback();
  ScheduleFunction _scheduleFn = scheduleMicrotask;

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
  void schedule(NotifyCallback callback) {
    if (_transactions > 0) {
      _queue.add(callback);
    } else {
      _scheduleFn(() => _notifyFn(callback));
    }
  }

  void _flush() {
    final queue = _queue;
    _queue = [];
    if (queue.isEmpty) return;

    _scheduleFn(() {
      _batchNotifyFn(() {
        for (final callback in queue) {
          _notifyFn(callback);
        }
      });
    });
  }

  /// Sets a function that wraps every notification.
  void setNotifyFunction(NotifyFunction fn) => _notifyFn = fn;

  /// Sets a function that wraps a whole batch of notifications.
  void setBatchNotifyFunction(NotifyFunction fn) => _batchNotifyFn = fn;

  /// Sets how the next batch is scheduled. Defaults to [scheduleMicrotask].
  void setScheduler(ScheduleFunction fn) => _scheduleFn = fn;
}

final NotifyManager notifyManager = NotifyManager();
