import 'dart:async';

import 'package:fuery_core/src/base/cacheable.dart';
import 'package:fuery_core/src/util/garbage_collector.dart';
import 'package:fuery_core/src/util/refetcher.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fuery_core/src/base/typedefs.dart';
import 'package:fuery_core/src/query_options.dart';
import 'package:fuery_core/src/query_state.dart';
import 'package:fuery_core/src/fuery_client.dart';

/// An interface for [Query] and [InfiniteQuery]
abstract class QueryBase<Data, Err, State extends QueryState<Data, Err>>
    extends Cacheable with Refetcher, GarbageCollector {
  QueryBase({
    required QueryKey queryKey,
    required QueryOptions? options,
    required State state,
  })  : assert(queryKey.isNotEmpty, 'queryKey should not be empty'),
        _options = options ?? Fuery.instance.defaultOptions,
        _state = state,
        super(key: queryKey);

  QueryOptions _options;
  QueryOptions get options => _options;

  State _state;

  BehaviorSubject<State>? _subject;

  void _setRefetchTimer() {
    final bool canUpdateRefetcher = _options.refetchInterval > 0 && hasListener;

    if (canUpdateRefetcher) {
      super.setRefetchTimer(
        interval: _options.refetchInterval,
        callback: refetch,
      );
    }
  }

  void _setGcTimer() {
    super.setGcTimer(
      gcTime: _options.gcTime,
      callback: () => Fuery.instance.removeQuery(key),
    );
  }

  void _cancelGcTimer() {
    if (hasListener) super.cancelGcTimer();
  }

  void fetch();

  void refetch();

  /// Updates the state to the provided [state].
  void emit(State state) {
    _state = state;
    _subject?.add(_state);
  }

  /// Mark as [invalidated] to true.
  void invalidate() {
    emit(_state.copyWith(invalidated: true) as State);
  }

  /// Updates options to the provided [options].
  ///
  /// If the [refetchInterval] is changed, the Timer will reset.
  void updateOptions(QueryOptions options) {
    if (_options == options) return;

    final bool shouldUpdateRefetchTimer =
        _options.refetchInterval != options.refetchInterval;

    _options = options;

    if (shouldUpdateRefetchTimer) {
      cancelRefetchTimer();
      _setRefetchTimer();
    }
  }

  /// Assign a [BehaviorSubject], indicating that listeners can subscribe to it.
  void wake() {
    if (_subject != null) return;

    _subject = BehaviorSubject<State>.seeded(_state)
      ..onListen = () {
        _setRefetchTimer();
        _cancelGcTimer();
      }
      ..onCancel = sleep;
  }

  /// Close [BehaviorSubject] and start the garbage collector timer.
  Future<void> sleep() async {
    await _subject?.close();
    cancelRefetchTimer();
    _subject = null;
    _setGcTimer();
  }

  /// Returns stream of state and Assign [BehaviorSubject] if not exists.
  ValueStream<State> get stream {
    wake();
    return _subject!.stream;
  }

  bool get shouldSkipFetch =>
      stream.value.isLoading || stream.value.isRefetching;

  bool get hasListener => _subject?.hasListener ?? false;

  bool get isStale {
    if (_options.staleTime.isInfinite) return false;

    final QueryState state = stream.value;

    return state.invalidated ||
        state.updatedAt.value == 0 ||
        DateTime.now().difference(state.updatedAt.toDateTime()).inSeconds >=
            options.staleTime;
  }
}
