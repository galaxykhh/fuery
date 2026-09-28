import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const offlineScenario = Scenario(
  path: 'offline',
  title: 'Offline',
  summary: 'While the device is offline, a fetch pauses and the data stays '
      'on screen, and a mutation waits. When the network returns, Fuery '
      'runs the waiting mutation first, then refetches.',
  tryThis: [
    'Set the network to offline and press Refetch. fetchStatus is paused, '
        'and the messages stay on screen.',
    'Send a message. Its run is pending and isPaused: it waits in the '
        'outbox.',
    'Set the network to online. The timeline shows the message sent first, '
        'then the list fetched once.',
  ],
  source: 'lib/scenarios/offline.dart',
  icon: Icons.wifi_off,
  child: OfflineScenario(),
);

// #region snippet
final messagesQuery = Query(
  queryKey: ['messages'],
  queryFn: (_) => server.getMessages(),
  staleTime: const Duration(seconds: 5),
);

final sendMessage = Mutation(
  mutationKey: const ['messages', 'send'],
  mutationFn: (String text) => server.sendMessage(text),
  // The run stays pending until the list has refetched.
  onSuccess: (message, text, context, client) =>
      client.invalidateQueries(queryKey: ['messages']),
);
// #endregion

class OfflineScenario extends StatefulWidget {
  const OfflineScenario({super.key});

  @override
  State<OfflineScenario> createState() => _OfflineScenarioState();
}

class _OfflineScenarioState extends State<OfflineScenario> {
  static const _texts = ['On my way', 'Running late', 'See you soon', 'Hi!'];

  bool _online = onlineManager.isOnline;
  int _sent = 0;

  String get _nextText => _texts[_sent % _texts.length];

  @override
  Widget build(BuildContext context) {
    return QueryLog(
      query: messagesQuery,
      child: MutationLog(mutation: sendMessage, child: _build(context)),
    );
  }

  Widget _build(BuildContext context) {
    // #region snippet
    return QueryBuilder(
      query: messagesQuery,
      builder: (context, state) => ScenarioLayout(
        live: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (state) {
              QueryResult(:final data?) =>
                MessageList(data, refreshing: state.isFetching),
              QueryResult(:final error?) => ErrorMessage(error),
              _ => const Loading(),
            },
            // The runs on their way, found by the mutation's key.
            MutationStateBuilder(
              mutation: sendMessage,
              builder: (context, runs) => Outbox([
                for (final run in runs)
                  if (run
                      case MutationState(isPending: true, :final variables?))
                    (text: variables, isPaused: run.isPaused),
              ]),
            ),
          ],
        ),
        controls: ControlBar(
          children: [
            ControlGroup(
              label: 'network',
              child: Choice(
                name: 'Network',
                values: const [true, false],
                selected: _online,
                label: (online) => online ? 'online' : 'offline',
                onChanged: (online) {
                  setState(() => _online = online);
                  // In an app, a connectivity source reports this.
                  onlineManager.setOnline(online);
                },
              ),
            ),
            ActionButton('Refetch', onPressed: () => state.refetch()),
            ActionButton(
              'Send "$_nextText"',
              primary: true,
              onPressed: () {
                sendMessage.mutate(_nextText, context.queryClient);
                setState(() => _sent++);
              },
            ),
          ],
        ),
        state: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QueryStatePanel(state, staleTime: messagesQuery.staleTime),
            const Divider(height: 24),
            MutationStateBuilder(
              mutation: sendMessage,
              builder: (context, runs) => MutationRunsPanel(runs),
            ),
          ],
        ),
      ),
    );
    // #endregion
  }
}

class MessageList extends StatelessWidget {
  const MessageList(this.messages, {super.key, required this.refreshing});

  final List<Message> messages;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Messages',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RefreshingDot(visible: refreshing),
          ],
        ),
        const SizedBox(height: 8),
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(message.text),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The messages on their way to the server.
class Outbox extends StatelessWidget {
  const Outbox(this.messages, {super.key});

  final List<({String text, bool isPaused})> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Outbox',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    message.isPaused ? Icons.schedule : Icons.north_east,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message.text)),
                  Text(
                    message.isPaused ? 'waiting for the network' : 'sending',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
