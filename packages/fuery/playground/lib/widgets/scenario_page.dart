import 'package:flutter/material.dart';

import '../scenario.dart';
import '../session.dart';
import '../theme.dart';
import 'basics.dart';
import 'code_panel.dart';
import 'event_timeline.dart';

/// Content wider than this shows its panels in two columns.
const twoColumnWidth = 820.0;

/// A scenario's page: its title, what it shows, what to try, the fake
/// server's controls, and [child].
class ScenarioPage extends StatelessWidget {
  const ScenarioPage({super.key, required this.scenario, required this.child});

  final Scenario scenario;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 32,
        narrow ? 16 : 32,
        narrow ? 16 : 32,
        96,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  scenario.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  scenario.summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _TryThis(steps: scenario.tryThis),
                const SizedBox(height: 16),
                const ServerBar(),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TryThis extends StatelessWidget {
  const _TryThis({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Try this',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final (index, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The fake server's latency, the requests it fails, how many it received,
/// and the button that starts the scenario over.
class ServerBar extends StatelessWidget {
  const ServerBar({super.key});

  static const latencies = [
    Duration(milliseconds: 300),
    Duration(seconds: 1),
    Duration(seconds: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final server = session.server;
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      title: 'Fake server',
      trailing: OutlinedButton.icon(
        onPressed: session.reset,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset scenario'),
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      ),
      child: ListenableBuilder(
        listenable: server,
        builder: (context, _) => ControlBar(
          children: [
            ControlGroup(
              label: 'latency',
              child: Choice(
                values: latencies,
                selected: server.latency,
                label: formatDuration,
                onChanged: (latency) => server.latency = latency,
              ),
            ),
            ControlGroup(
              label: 'fail next',
              child: _Stepper(
                value: server.failNext,
                unit: server.failNext == 1 ? 'request' : 'requests',
                onChanged: (value) => server.failNext = value,
              ),
            ),
            ControlGroup(
              label: 'requests received',
              child: SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    '${server.requestCount}',
                    key: const Key('request-count'),
                    style: TextStyle(
                      fontFamily: monoFamily,
                      fontSize: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Fail one request fewer',
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text(
            '$value $unit',
            key: const Key('fail-next'),
            style: const TextStyle(fontFamily: monoFamily, fontSize: 13),
          ),
          IconButton(
            tooltip: 'Fail one request more',
            visualDensity: VisualDensity.compact,
            onPressed: value < 9 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Lays out a scenario: the controls, the live UI, and the timeline next to
/// its state, and the code below. On narrow screens, one column.
///
/// The controls come first, so the live UI can grow without moving them.
class ScenarioLayout extends StatelessWidget {
  const ScenarioLayout({
    super.key,
    required this.live,
    required this.state,
    this.controls,
    this.liveTitle = 'Live',
    this.stateTitle = 'State',
  });

  final Widget live;
  final Widget? controls;
  final Widget state;
  final String liveTitle;
  final String stateTitle;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final controls = this.controls;
    final livePanel = Panel(title: liveTitle, child: live);
    final controlsPanel =
        controls == null ? null : Panel(title: 'Controls', child: controls);
    final statePanel = Panel(title: stateTitle, child: state);
    const timelinePanel = Panel(title: 'Timeline', child: EventTimeline());
    final codePanel = Panel(
      title: 'Code',
      child: CodePanel(source: session.scenario.source),
    );
    const gap = SizedBox(height: 16, width: 16);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < twoColumnWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controlsPanel != null) ...[controlsPanel, gap],
              livePanel,
              gap,
              statePanel,
              gap,
              timelinePanel,
              gap,
              codePanel,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controlsPanel != null) ...[controlsPanel, gap],
                      livePanel,
                      gap,
                      timelinePanel,
                    ],
                  ),
                ),
                gap,
                Expanded(child: statePanel),
              ],
            ),
            gap,
            codePanel,
          ],
        );
      },
    );
  }
}
