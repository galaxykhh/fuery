import 'dart:async';

import 'package:flutter/widgets.dart';

import 'fake_server.dart';

/// Where an event of the timeline comes from.
enum EventKind {
  /// The fake server received a request.
  request,

  /// The fake server answered.
  response,

  /// The fake server failed a request, or dropped it.
  failure,

  /// A query reported a change.
  query,

  /// A mutation run reported a change.
  mutation,

  /// The cache changed, as when an entry is garbage collected.
  cache,

  /// You did something, such as press a button.
  action,
}

@immutable
class TimelineEvent {
  const TimelineEvent(this.at, this.kind, this.text);

  /// The time since the scenario started.
  final Duration at;
  final EventKind kind;
  final String text;
}

/// The events of one scenario, oldest first. Events are only ever added, and
/// the oldest leave once there are [capacity].
class Timeline extends ChangeNotifier {
  Timeline({this.capacity = 200});

  final int capacity;
  final Stopwatch _clock = Stopwatch()..start();
  final List<TimelineEvent> _events = [];
  bool _notifying = false;
  bool _disposed = false;

  List<TimelineEvent> get events => List.unmodifiable(_events);

  /// The timeline of the scenario around [context].
  static Timeline of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TimelineScope>();
    assert(scope != null, 'No TimelineScope above this widget');
    return scope!.timeline;
  }

  void add(EventKind kind, String text) {
    _events.add(TimelineEvent(_clock.elapsed, kind, text));
    if (_events.length > capacity) _events.removeAt(0);
    _notifyLater();
  }

  /// Starts over, for a scenario that starts over.
  void clear() {
    _events.clear();
    _clock
      ..reset()
      ..start();
    _notifyLater();
  }

  // Widgets listen, and events can arrive while Flutter builds, so they hear
  // of them after the frame's work.
  void _notifyLater() {
    if (_notifying || _disposed) return;
    _notifying = true;
    scheduleMicrotask(() {
      _notifying = false;
      if (!_disposed) notifyListeners();
    });
  }

  void query(String text) => add(EventKind.query, text);
  void mutation(String text) => add(EventKind.mutation, text);
  void cache(String text) => add(EventKind.cache, text);
  void action(String text) => add(EventKind.action, text);

  /// Adds the start or the end of a request to the fake server.
  void request(ServerRequest request) {
    switch (request.outcome) {
      case RequestOutcome.pending:
        add(EventKind.request, '→ $request');
      case RequestOutcome.succeeded:
        add(EventKind.response, '← 200 $request');
      case RequestOutcome.failed:
        add(EventKind.failure, '← 500 $request');
      case RequestOutcome.dropped:
        add(EventKind.failure, '✕ $request dropped');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Provides a [Timeline] to [Timeline.of].
class TimelineScope extends InheritedWidget {
  const TimelineScope(
      {super.key, required this.timeline, required super.child});

  final Timeline timeline;

  @override
  bool updateShouldNotify(TimelineScope oldWidget) =>
      !identical(oldWidget.timeline, timeline);
}
