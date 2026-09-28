import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../theme.dart';
import 'basics.dart';

/// One labeled value of a state panel.
class StateRow extends StatelessWidget {
  const StateRow(this.label, this.value, {super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: value),
          ),
        ],
      ),
    );
  }
}

/// A value of a state panel in the code font.
class ValueText extends StatelessWidget {
  const ValueText(this.text, {super.key, this.maxLines = 3});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: monoFamily, fontSize: 12.5),
      ),
    );
  }
}

Tone statusTone(BuildContext context, QueryStatus status) => switch (status) {
      QueryStatus.success => Tone.good(context),
      QueryStatus.error => Tone.bad(context),
      QueryStatus.pending => Tone.neutral(context),
    };

Tone fetchStatusTone(BuildContext context, FetchStatus status) =>
    switch (status) {
      FetchStatus.fetching => Tone.active(context),
      FetchStatus.paused => Tone.waiting(context),
      FetchStatus.idle => Tone.neutral(context),
    };

/// The fields of a [QueryResult] as a widget receives them.
///
/// With [staleTime], it counts down to the moment the data goes stale.
class QueryStatePanel<TData extends Object> extends StatelessWidget {
  const QueryStatePanel(
    this.result, {
    super.key,
    this.staleTime,
    this.describe,
    this.extra = const [],
  });

  final QueryResult<TData> result;

  /// The query's staleTime, for the countdown.
  final Duration? staleTime;

  /// How to show the data. Defaults to its `toString()`.
  final String Function(TData data)? describe;

  /// Rows after the others, such as the pages of an infinite query.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final data = result.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StateRow(
          'status',
          Pill(result.status.name, tone: statusTone(context, result.status)),
        ),
        StateRow(
          'fetchStatus',
          Pill(
            result.fetchStatus.name,
            tone: fetchStatusTone(context, result.fetchStatus),
          ),
        ),
        StateRow(
          'isStale',
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                '${result.isStale}',
                tone:
                    result.isStale ? Tone.neutral(context) : Tone.good(context),
              ),
              if (_freshness(result) case final freshness?) freshness,
            ],
          ),
        ),
        StateRow(
          'isPlaceholderData',
          Pill(
            '${result.isPlaceholderData}',
            tone: result.isPlaceholderData
                ? Tone.waiting(context)
                : Tone.neutral(context),
          ),
        ),
        StateRow(
          'failureCount',
          Pill(
            '${result.failureCount}',
            tone: result.failureCount > 0
                ? Tone.bad(context)
                : Tone.neutral(context),
          ),
        ),
        StateRow(
          'failureReason',
          ValueText('${result.failureReason ?? 'null'}'),
        ),
        StateRow('error', ValueText('${result.error ?? 'null'}')),
        StateRow(
          'data',
          ValueText(
            data == null ? 'null' : (describe?.call(data) ?? '$data'),
          ),
        ),
        StateRow(
          'dataUpdatedAt',
          result.dataUpdatedAt == 0
              ? const ValueText('0 (never)')
              : Ticking(
                  builder: (context) =>
                      ValueText(formatAgo(result.dataUpdatedAt)),
                ),
        ),
        ...extra,
      ],
    );
  }

  /// "stale in 3.2 s" while the data is fresh for a while.
  Widget? _freshness(QueryResult<TData> result) {
    final staleTime = this.staleTime;
    if (staleTime == null || result.isStale || result.dataUpdatedAt == 0) {
      return null;
    }
    if (staleTime >= infiniteDuration) {
      return const _Note('fresh until invalidated');
    }
    return Ticking(
      interval: const Duration(milliseconds: 100),
      builder: (context) {
        final left = Duration(
          milliseconds:
              result.dataUpdatedAt + staleTime.inMilliseconds - nowMs(),
        );
        return _Note(
          left > Duration.zero ? 'stale in ${formatSeconds(left)}' : 'stale',
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: monoFamily,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The states of mutation runs, newest first, as the MutationState widgets
/// report them. A `MutationResult` is one of them.
class MutationRunsPanel extends StatelessWidget {
  const MutationRunsPanel(this.runs, {super.key, this.limit = 5});

  /// The runs, oldest first.
  final List<MutationState<Object?, Object?, Object?>> runs;

  final int limit;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return Text(
        'No runs yet.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final shown = runs.reversed.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, run) in shown.indexed)
          _RunRow(number: runs.length - index, run: run),
        if (runs.length > limit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _Note('and ${runs.length - limit} older'),
          ),
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.number, required this.run});

  final int number;
  final MutationState<Object?, Object?, Object?> run;

  @override
  Widget build(BuildContext context) {
    final variables = run.variables;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ValueText(
            'run $number  ${variables is String ? '"$variables"' : '$variables'}',
            maxLines: 1,
          ),
          Pill(
            run.status.name,
            tone: switch (run.status) {
              MutationStatus.success => Tone.good(context),
              MutationStatus.error => Tone.bad(context),
              MutationStatus.pending => Tone.active(context),
              MutationStatus.idle => Tone.neutral(context),
            },
          ),
          if (run.isPaused) Pill('isPaused', tone: Tone.waiting(context)),
          if (run.failureCount > 0) _Note('failureCount ${run.failureCount}'),
        ],
      ),
    );
  }
}
