import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../theme.dart';
import '../timeline.dart';
import '../widgets/basics.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const sharedCacheScenario = Scenario(
  path: 'shared-cache',
  title: 'One key, one request',
  summary: 'Widgets that show the same query share one cache entry and one '
      'request. When the last of them leaves, the entry stays for gcTime, '
      'then Fuery removes it.',
  tryThis: [
    'Count the requests: three widgets, one request.',
    'Unmount the profile card and mount it again. It shows the cached user '
        'at once and sends no request: the data is fresh for a minute.',
    'Unmount all three. The entry stays in the cache for gcTime (10 s), '
        'then leaves it.',
    'Mount one again. The cache no longer has the user, so it fetches.',
  ],
  source: 'lib/scenarios/shared_cache.dart',
  icon: Icons.hub_outlined,
  child: SharedCacheScenario(),
);

// #region snippet
final userQuery = Query(
  queryKey: ['user'],
  queryFn: (_) => server.getUser(),
  staleTime: const Duration(minutes: 1),
  gcTime: const Duration(seconds: 10),
);
// #endregion

enum _Spot { header, profile, inbox }

class SharedCacheScenario extends StatefulWidget {
  const SharedCacheScenario({super.key});

  @override
  State<SharedCacheScenario> createState() => _SharedCacheScenarioState();
}

class _SharedCacheScenarioState extends State<SharedCacheScenario> {
  final Set<_Spot> _mounted = {..._Spot.values};

  void _toggle(_Spot spot, bool mounted) {
    setState(() {
      if (mounted) {
        _mounted.add(spot);
      } else {
        _mounted.remove(spot);
      }
    });
    Timeline.of(context).action(
      '${mounted ? 'Mounted' : 'Unmounted'} the ${_labels[spot]}',
    );
  }

  static const _labels = {
    _Spot.header: 'header',
    _Spot.profile: 'profile card',
    _Spot.inbox: 'inbox badge',
  };

  @override
  Widget build(BuildContext context) {
    // #region snippet
    // Three widgets, one definition. They share the cache entry of ['user'],
    // and the request that fills it.
    final header = QueryBuilder(
      query: userQuery,
      builder: (context, state) => AccountHeader(state.data),
    );
    final profile = QueryBuilder(
      query: userQuery,
      builder: (context, state) => ProfileCard(state.data),
    );
    final inbox = QueryBuilder(
      query: userQuery,
      builder: (context, state) => InboxBadge(state.data),
    );
    // #endregion
    return ScenarioLayout(
      live: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Slot(
            label: _labels[_Spot.header]!,
            child: _mounted.contains(_Spot.header) ? header : null,
          ),
          const SizedBox(height: 12),
          _Slot(
            label: _labels[_Spot.profile]!,
            child: _mounted.contains(_Spot.profile) ? profile : null,
          ),
          const SizedBox(height: 12),
          _Slot(
            label: _labels[_Spot.inbox]!,
            child: _mounted.contains(_Spot.inbox) ? inbox : null,
          ),
        ],
      ),
      controls: ControlGroup(
        label: 'mounted widgets',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final spot in _Spot.values)
              FilterChip(
                label: Text(_labels[spot]!),
                selected: _mounted.contains(spot),
                onSelected: (mounted) => _toggle(spot, mounted),
              ),
          ],
        ),
      ),
      stateTitle: 'Cache entry',
      state: CacheEntryPanel(query: userQuery),
    );
  }
}

/// A place in the live UI that a widget can be mounted in.
class _Slot extends StatelessWidget {
  const _Slot({required this.label, required this.child});

  final String label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = this.child;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: child == null ? null : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child ??
          Center(
            child: Text(
              'The $label is unmounted',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
    );
  }
}

class AccountHeader extends StatelessWidget {
  const AccountHeader(this.user, {super.key});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child:
              Text(user?.initials ?? '', style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            user == null ? 'Loading…' : 'Signed in as ${user.handle}',
            style: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard(this.user, {super.key});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final theme = Theme.of(context);
    if (user == null) {
      return const Loading(label: 'Loading the profile…');
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(user.initials),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: theme.textTheme.titleMedium),
              Text(
                user.handle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class InboxBadge extends StatelessWidget {
  const InboxBadge(this.user, {super.key});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return Row(
      children: [
        Badge(
          label: Text('${user?.unread ?? 0}'),
          isLabelVisible: user != null,
          child: const Icon(Icons.inbox_outlined),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            user == null
                ? 'Loading…'
                : '${user.unread} unread for ${user.name}',
          ),
        ),
      ],
    );
  }
}

typedef _Entry = ({
  int observers,
  QueryStatus status,
  FetchStatus fetchStatus,
  int dataUpdatedAt,
});

/// The cache entry of a query as the client holds it: how many observers
/// use it, and when garbage collection removes it. It reads the client with
/// `client.watch`, which fetches nothing.
class CacheEntryPanel extends StatefulWidget {
  const CacheEntryPanel({super.key, required this.query});

  final Query<Object> query;

  @override
  State<CacheEntryPanel> createState() => _CacheEntryPanelState();
}

class _CacheEntryPanelState extends State<CacheEntryPanel> {
  QueryClient? _client;
  StreamSubscription<_Entry?>? _subscription;
  _Entry? _entry;

  /// When the last observer left, while the entry waits for gcTime.
  int? _unusedSince;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = FueryProvider.of(context, listen: true);
    if (identical(client, _client)) return;
    _client = client;
    _subscription?.cancel();
    _subscription = client.watch<_Entry?>((client) {
      final query = client.queryCache.find(
        QueryFilters(queryKey: widget.query.queryKey, exact: true),
      );
      if (query == null) return null;
      return (
        observers: query.observersCount,
        status: query.state.status,
        fetchStatus: query.state.fetchStatus,
        dataUpdatedAt: query.state.dataUpdatedAt,
      );
    }).listen(_onEntry);
  }

  void _onEntry(_Entry? entry) {
    final previous = _entry;
    final timeline = Timeline.of(context);
    if (entry == null && previous != null) {
      timeline.cache('gcTime passed: ${widget.query.queryKey} left the cache');
    } else if (entry != null && previous == null) {
      timeline.cache('${widget.query.queryKey} added to the cache');
    }
    if (entry != null && entry.observers != (previous?.observers ?? 0)) {
      timeline
          .cache('observers: ${previous?.observers ?? 0} → ${entry.observers}');
    }
    setState(() {
      _entry = entry;
      if (entry == null || entry.observers > 0) {
        _unusedSince = null;
      } else if (previous == null || previous.observers > 0) {
        _unusedSince = nowMs();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final gcTime = widget.query.gcTime ?? const Duration(minutes: 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StateRow('queryKey', ValueText('${widget.query.queryKey}')),
        StateRow(
          'in the cache',
          Pill(
            entry == null ? 'no' : 'yes',
            tone: entry == null ? Tone.neutral(context) : Tone.good(context),
          ),
        ),
        StateRow(
          'observers',
          Pill(
            '${entry?.observers ?? 0}',
            key: const Key('observers'),
            tone: (entry?.observers ?? 0) > 0
                ? Tone.active(context)
                : Tone.neutral(context),
          ),
        ),
        if (entry != null) ...[
          StateRow(
            'status',
            Pill(entry.status.name, tone: statusTone(context, entry.status)),
          ),
          StateRow(
            'fetchStatus',
            Pill(
              entry.fetchStatus.name,
              tone: fetchStatusTone(context, entry.fetchStatus),
            ),
          ),
          StateRow(
            'dataUpdatedAt',
            entry.dataUpdatedAt == 0
                ? const ValueText('0 (never)')
                : Ticking(
                    builder: (context) =>
                        ValueText(formatAgo(entry.dataUpdatedAt)),
                  ),
          ),
        ],
        StateRow(
          'gcTime',
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ValueText(formatDuration(gcTime)),
              if (_unusedSince case final since?)
                Ticking(
                  interval: const Duration(milliseconds: 100),
                  builder: (context) {
                    final left = Duration(
                      milliseconds: since + gcTime.inMilliseconds - nowMs(),
                    );
                    return Pill(
                      left > Duration.zero
                          ? 'removed in ${formatSeconds(left)}'
                          : 'removing',
                      tone: Tone.waiting(context),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
