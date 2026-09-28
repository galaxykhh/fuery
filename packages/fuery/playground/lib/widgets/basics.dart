import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../timeline.dart';

/// A card with a small title, for each part of a scenario page.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing case final trailing?) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A small rounded label, such as a status.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone});

  final String label;

  /// Defaults to [Tone.neutral].
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone ?? Tone.neutral(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: monoFamily,
            fontSize: 12,
            height: 1.4,
            color: tone.foreground,
          ),
        ),
      ),
    );
  }
}

/// The wall clock, in milliseconds since epoch, as Fuery's timestamps are.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// "just now", "12 s ago", or "3 min ago".
String formatAgo(int timestamp) {
  final seconds = ((nowMs() - timestamp) / 1000).floor();
  if (seconds < 1) return 'just now';
  if (seconds < 120) return '$seconds s ago';
  return '${seconds ~/ 60} min ago';
}

/// A duration in seconds with one decimal, such as "2.5 s".
String formatSeconds(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1)} s';
}

/// A duration as a person would say it: "300 ms", "5 s", "2 min", or
/// "infinite".
String formatDuration(Duration duration, {Duration? infinite}) {
  if (infinite != null && duration >= infinite) return 'infinite';
  if (duration == Duration.zero) return '0';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  if (duration.inSeconds < 120) return '${duration.inSeconds} s';
  return '${duration.inMinutes} min';
}

/// Builds [builder] again every [interval], for text that counts time.
class Ticking extends StatefulWidget {
  const Ticking({
    super.key,
    required this.builder,
    this.interval = const Duration(milliseconds: 250),
  });

  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// A row of controls that wraps on narrow screens.
class ControlBar extends StatelessWidget {
  const ControlBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: children,
    );
  }
}

/// A control with a small label above it.
class ControlGroup extends StatelessWidget {
  const ControlGroup({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: monoFamily,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// A compact choice among a few values, such as a staleTime. With [name], a
/// change goes to the timeline.
class Choice<T> extends StatelessWidget {
  const Choice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.name,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: [
        for (final value in values)
          ButtonSegment(value: value, label: Text(label(value))),
      ],
      selected: {selected},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: (selection) {
        final value = selection.single;
        if (name case final name?) {
          Timeline.of(context).action('$name: ${label(value)}');
        }
        onChanged(value);
      },
    );
  }
}

/// A button of the Controls panel. Pressing it goes to the timeline.
class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Whether this is the main action, drawn filled.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final callback = onPressed == null
        ? null
        : () {
            Timeline.of(context).action(label);
            onPressed();
          };
    final icon = this.icon;
    if (primary) {
      return icon == null
          ? FilledButton(onPressed: callback, child: Text(label))
          : FilledButton.icon(
              onPressed: callback,
              icon: Icon(icon, size: 18),
              label: Text(label),
            );
    }
    return icon == null
        ? FilledButton.tonal(onPressed: callback, child: Text(label))
        : FilledButton.tonalIcon(
            onPressed: callback,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}

/// A spinner for the live UI while a query loads its first data.
class Loading extends StatelessWidget {
  const Loading({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure the live UI shows, with an optional retry button.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE5484D), size: 32),
          const SizedBox(height: 8),
          Text(
            'Could not load: $error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry case final onRetry?) ...[
            const SizedBox(height: 12),
            ActionButton('Try again', onPressed: onRetry, primary: true),
          ],
        ],
      ),
    );
  }
}

/// A small spinner beside data that is refetching in the background.
class RefreshingDot extends StatelessWidget {
  const RefreshingDot({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: visible
          ? const CircularProgressIndicator(strokeWidth: 2)
          : const SizedBox(),
    );
  }
}
