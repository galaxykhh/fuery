import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../timeline.dart';
import '../widgets/basics.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const lifecycleScenario = Scenario(
  path: 'lifecycle',
  title: 'Query lifecycle',
  summary: 'A query fetches when its widget mounts. Its data is fresh for '
      'staleTime, then stale. Stale data stays on screen, and Fuery '
      'refetches it when you invalidate it or the app returns to the '
      'foreground.',
  tryThis: [
    'Press "Like on the server". The screen keeps the old count: nothing '
        'told the app.',
    'Set app to background, then to foreground. The data is stale, so Fuery '
        'refetches it, and the new count shows.',
    'Set staleTime to 5 s and watch isStale count down. Background and '
        'foreground while the data is fresh fetch nothing.',
    'Set staleTime to infinite. Now only Refetch and Invalidate fetch.',
  ],
  source: 'lib/scenarios/lifecycle.dart',
  icon: Icons.autorenew,
  child: LifecycleScenario(),
);

// #region snippet
Query<Post> postQuery({required Duration staleTime}) => Query(
      queryKey: ['post'],
      queryFn: (_) => server.getPost(),
      staleTime: staleTime,
    );
// #endregion

class LifecycleScenario extends StatefulWidget {
  const LifecycleScenario({super.key});

  @override
  State<LifecycleScenario> createState() => _LifecycleScenarioState();
}

class _LifecycleScenarioState extends State<LifecycleScenario> {
  static const _staleTimes = [
    Duration.zero,
    Duration(seconds: 5),
    infiniteDuration,
  ];

  Duration _staleTime = Duration.zero;
  bool _inBackground = false;

  @override
  Widget build(BuildContext context) {
    // #region snippet
    final query = postQuery(staleTime: _staleTime);
    return QueryListener(
      query: query,
      // A listener is for side effects. This one writes each change of
      // status, fetchStatus, or isStale to the timeline.
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.fetchStatus != current.fetchStatus ||
          previous.isStale != current.isStale,
      listener: (context, state) => Timeline.of(context).query(
        '${state.status.name} · ${state.fetchStatus.name} · '
        '${state.isStale ? 'stale' : 'fresh'}',
      ),
      child: QueryBuilder(
        query: query,
        builder: (context, state) => ScenarioLayout(
          live: switch (state) {
            QueryResult(:final data?) =>
              PostCard(data, refreshing: state.isFetching),
            QueryResult(:final error?) => ErrorMessage(error),
            _ => const Loading(),
          },
          controls: ControlBar(
            children: [
              ActionButton('Refetch', onPressed: () => state.refetch()),
              ActionButton(
                'Invalidate',
                onPressed: () =>
                    context.queryClient.invalidateQueries(queryKey: ['post']),
              ),
              ActionButton(
                'Like on the server',
                onPressed: server.likePostElsewhere,
              ),
              ControlGroup(
                label: 'app',
                child: Choice(
                  name: 'App',
                  values: const [false, true],
                  selected: _inBackground,
                  label: (inBackground) =>
                      inBackground ? 'background' : 'foreground',
                  onChanged: (inBackground) {
                    setState(() => _inBackground = inBackground);
                    // What the app lifecycle reports: not focused in the
                    // background, and its own state again after.
                    focusManager.setFocused(inBackground ? false : null);
                  },
                ),
              ),
              ControlGroup(
                label: 'staleTime',
                child: Choice(
                  name: 'staleTime',
                  values: _staleTimes,
                  selected: _staleTime,
                  label: (staleTime) =>
                      formatDuration(staleTime, infinite: infiniteDuration),
                  onChanged: (staleTime) =>
                      setState(() => _staleTime = staleTime),
                ),
              ),
            ],
          ),
          state: QueryStatePanel(state, staleTime: _staleTime),
        ),
      ),
    );
    // #endregion
  }
}

/// The post, with its likes.
class PostCard extends StatelessWidget {
  const PostCard(this.post, {super.key, required this.refreshing});

  final Post post;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: const Icon(Icons.article_outlined),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.favorite,
                      size: 18, color: Color(0xFFE5484D)),
                  const SizedBox(width: 6),
                  Text(
                    '${post.likes} likes',
                    key: const Key('likes'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
        RefreshingDot(visible: refreshing),
      ],
    );
  }
}
