import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const paginationScenario = Scenario(
  path: 'pagination',
  title: 'Keeping the previous page',
  summary: 'Each page is a query with its own key. With keepPreviousData, '
      'the page on screen stays while the next one loads, and '
      'isPlaceholderData says so.',
  tryThis: [
    'Press Next. Page 1 stays, dimmed, until page 2 arrives: '
        'isPlaceholderData is true meanwhile.',
    'Press Previous. Page 1 is cached, so it shows at once, and Fuery '
        'refetches it in the background.',
    'Turn keepPreviousData off and press Next. Each new page shows the '
        'loading state instead.',
  ],
  source: 'lib/scenarios/pagination.dart',
  icon: Icons.last_page,
  child: PaginationScenario(),
);

// #region snippet
Query<ProjectPage> projectsQuery(int page, {required bool keepPrevious}) {
  return Query(
    queryKey: ['projects', page],
    queryFn: (_) => server.getProjects(page),
    // While the next page loads, show the page before it.
    placeholderData: keepPrevious ? keepPreviousData : null,
  );
}
// #endregion

class PaginationScenario extends StatefulWidget {
  const PaginationScenario({super.key});

  @override
  State<PaginationScenario> createState() => _PaginationScenarioState();
}

class _PaginationScenarioState extends State<PaginationScenario> {
  int _page = 1;
  bool _keepPrevious = true;

  @override
  Widget build(BuildContext context) {
    // #region snippet
    final query = projectsQuery(_page, keepPrevious: _keepPrevious);
    // The widget keeps one observer as _page changes, so the observer has
    // the previous page to show.
    final page = QueryBuilder(
      query: query,
      builder: (context, state) => ScenarioLayout(
        live: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (state) {
              QueryResult(:final data?) => AnimatedOpacity(
                  opacity: state.isPlaceholderData ? 0.4 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: ProjectList(data),
                ),
              QueryResult(:final error?) => ErrorMessage(error),
              _ => const Loading(),
            },
            Pager(
              page: _page,
              onPrevious: _page > 1 ? () => setState(() => _page--) : null,
              // Wait for the page on its way before asking for another.
              onNext: state.data?.hasMore == true && !state.isPlaceholderData
                  ? () => setState(() => _page++)
                  : null,
            ),
          ],
        ),
        controls: ControlBar(
          children: [
            ControlGroup(
              label: 'placeholderData',
              child: Choice(
                name: 'placeholderData',
                values: const [true, false],
                selected: _keepPrevious,
                label: (keep) => keep ? 'keepPreviousData' : 'none',
                onChanged: (keep) => setState(() => _keepPrevious = keep),
              ),
            ),
          ],
        ),
        state: QueryStatePanel(
          state,
          describe: (page) => 'ProjectPage(page: ${page.page})',
          extra: [StateRow('queryKey', ValueText('${query.queryKey}'))],
        ),
      ),
    );
    // #endregion
    return QueryLog(query: query, child: page);
  }
}

class ProjectList extends StatelessWidget {
  const ProjectList(this.page, {super.key});

  final ProjectPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final project in page.projects)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(project, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
      ],
    );
  }
}

class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ActionButton('Previous', onPressed: onPrevious),
          Expanded(
            child: Text(
              'Page $page of ${FakeServer.projectPages}',
              key: const Key('page'),
              textAlign: TextAlign.center,
            ),
          ),
          ActionButton('Next', onPressed: onNext),
        ],
      ),
    );
  }
}
