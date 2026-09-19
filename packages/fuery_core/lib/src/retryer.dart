import 'dart:async';
import 'dart:math' as math;

import 'focus_manager.dart';
import 'online_manager.dart';

/// Controls when a fetch runs based on network connectivity.
enum NetworkMode {
  /// Only fetch while online. Fetches pause while offline and resume on
  /// reconnect.
  online,

  /// Always fetch, ignoring connectivity.
  always,

  /// Run the first attempt regardless of connectivity, then pause retries
  /// while offline.
  offlineFirst,
}

/// Decides whether a failed attempt should be retried.
final class RetryPolicy {
  /// Retry up to [count] times.
  const RetryPolicy.count(int count)
      : _count = count,
        _predicate = null;

  /// Never retry.
  const RetryPolicy.never() : this.count(0);

  /// Retry forever.
  const RetryPolicy.always()
      : _count = null,
        _predicate = null;

  /// Retry while [predicate] returns true. [failureCount] starts at 0 for the
  /// first failure.
  const RetryPolicy.when(
      bool Function(int failureCount, Object error) predicate)
      : _count = null,
        _predicate = predicate;

  final int? _count;
  final bool Function(int failureCount, Object error)? _predicate;

  bool shouldRetry(int failureCount, Object error) {
    final predicate = _predicate;
    if (predicate != null) return predicate(failureCount, error);
    final count = _count;
    return count == null || failureCount < count;
  }
}

typedef RetryDelay = Duration Function(int failureCount, Object error);

/// Exponential backoff: 1s, 2s, 4s, ... capped at 30s.
Duration defaultRetryDelay(int failureCount, Object error) {
  final ms = math.min(1000 * math.pow(2, failureCount).toInt(), 30000);
  return Duration(milliseconds: ms);
}

bool canFetch(NetworkMode? networkMode) {
  return (networkMode ?? NetworkMode.online) == NetworkMode.online
      ? onlineManager.isOnline()
      : true;
}

/// Thrown when a fetch is cancelled.
///
/// [revert] restores the state from before the fetch started. [silent]
/// suppresses the error because a new fetch replaces the cancelled one.
class CancelledError implements Exception {
  const CancelledError({this.revert = false, this.silent = false});

  final bool revert;
  final bool silent;

  @override
  String toString() => 'CancelledError(revert: $revert, silent: $silent)';
}

enum RetryerStatus { pending, resolved, rejected }

/// Runs [fn] with retries, backoff, and pausing while unfocused or offline.
class Retryer<TData> {
  Retryer({
    required this.fn,
    required this.canRun,
    this.onCancel,
    this.onFail,
    this.onPause,
    this.onContinue,
    this.retry,
    this.retryDelay,
    this.networkMode,
  }) {
    // Errors are delivered to whoever awaits [future]; an unobserved rejection
    // (for example after a cancel) must not surface as an uncaught error.
    _completer.future.ignore();
  }

  final FutureOr<TData> Function() fn;
  final bool Function() canRun;
  final void Function(CancelledError error)? onCancel;
  final void Function(int failureCount, Object error)? onFail;
  final void Function()? onPause;
  final void Function()? onContinue;
  final RetryPolicy? retry;
  final RetryDelay? retryDelay;
  final NetworkMode? networkMode;

  final Completer<TData> _completer = Completer<TData>();
  RetryerStatus _status = RetryerStatus.pending;
  bool _isRetryCancelled = false;
  int _failureCount = 0;
  void Function()? _continueFn;

  Future<TData> get future => _completer.future;

  RetryerStatus get status => _status;

  bool get _isResolved => _status != RetryerStatus.pending;

  void cancel({bool revert = false, bool silent = false}) {
    if (_isResolved) return;
    final error = CancelledError(revert: revert, silent: silent);
    _reject(error, StackTrace.current);
    onCancel?.call(error);
  }

  /// Stops retrying after the current attempt.
  void cancelRetry() => _isRetryCancelled = true;

  /// Allows retries again after [cancelRetry].
  void continueRetry() => _isRetryCancelled = false;

  bool canStart() => canFetch(networkMode) && canRun();

  /// Resumes a paused retryer if it is allowed to continue.
  Future<TData> resume() {
    _continueFn?.call();
    return future;
  }

  Future<TData> start() {
    if (canStart()) {
      _run();
    } else {
      _pause().then((_) => _run());
    }
    return future;
  }

  bool _canContinue() {
    return focusManager.isFocused() &&
        (networkMode == NetworkMode.always || onlineManager.isOnline()) &&
        canRun();
  }

  void _resolve(TData value) {
    if (_isResolved) return;
    _status = RetryerStatus.resolved;
    _continueFn?.call();
    _completer.complete(value);
  }

  void _reject(Object error, StackTrace stackTrace) {
    if (_isResolved) return;
    _status = RetryerStatus.rejected;
    _continueFn?.call();
    _completer.completeError(error, stackTrace);
  }

  Future<void> _pause() {
    final completer = Completer<void>();
    _continueFn = () {
      if ((_isResolved || _canContinue()) && !completer.isCompleted) {
        completer.complete();
      }
    };
    onPause?.call();

    return completer.future.then((_) {
      _continueFn = null;
      if (!_isResolved) onContinue?.call();
    });
  }

  void _run() {
    if (_isResolved) return;

    Future<TData>.sync(fn).then(_resolve,
        onError: (Object error, StackTrace st) {
      if (_isResolved) return;

      final retry = this.retry ?? const RetryPolicy.count(3);
      final delay = (retryDelay ?? defaultRetryDelay)(_failureCount, error);
      final shouldRetry = retry.shouldRetry(_failureCount, error);

      if (_isRetryCancelled || !shouldRetry) {
        _reject(error, st);
        return;
      }

      _failureCount++;
      onFail?.call(_failureCount, error);

      Future<void>.delayed(delay)
          .then((_) => _canContinue() ? null : _pause())
          .then((_) {
        if (_isRetryCancelled) {
          _reject(error, st);
        } else {
          _run();
        }
      });
    });
  }
}
