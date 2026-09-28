import 'package:flutter/material.dart';

import '../theme.dart';
import '../timeline.dart';

/// The scenario's timeline, newest event first.
class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, this.height = 280});

  final double height;

  @override
  Widget build(BuildContext context) {
    final timeline = Timeline.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: ListenableBuilder(
        listenable: timeline,
        builder: (context, _) {
          final events = timeline.events;
          if (events.isEmpty) {
            return Center(
              child: Text(
                'Nothing yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) =>
                _EventRow(events[events.length - 1 - index]),
          );
        },
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (event.kind) {
      EventKind.request => scheme.onSurfaceVariant,
      EventKind.response => dark ? Brand.lime : const Color(0xFF4F6B00),
      EventKind.failure => const Color(0xFFE5484D),
      EventKind.query => scheme.primary,
      EventKind.mutation =>
        dark ? const Color(0xFFFFD27A) : const Color(0xFF9A5B00),
      EventKind.cache => scheme.onSurfaceVariant,
      EventKind.action => scheme.onSurface,
    };
    final label = switch (event.kind) {
      EventKind.request || EventKind.response || EventKind.failure => 'server',
      EventKind.query => 'query',
      EventKind.mutation => 'mutation',
      EventKind.cache => 'cache',
      EventKind.action => 'you',
    };
    const mono = TextStyle(fontFamily: monoFamily, fontSize: 12, height: 1.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '+${(event.at.inMilliseconds / 1000).toStringAsFixed(1)}s',
              style: mono.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(label, style: mono.copyWith(color: color)),
          ),
          Expanded(
            child: Text(
              event.text,
              style: mono.copyWith(
                color: event.kind == EventKind.request
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
