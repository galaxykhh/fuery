import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../theme.dart';
import '../timeline.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const infiniteScenario = Scenario(
  path: 'infinite',
  title: 'Infinite query',
  summary: 'An infinite query keeps a list of pages under one key. '
      'fetchNextPage loads the page that getNextPageParam names, until it '
      'names none.',
  tryThis: [
    'Press "Load more". isFetchingNextPage is true while the page loads, '
        'and the pages grow by one.',
    'Load every page. hasNextPage turns false, and the button is gone.',
    'Press "Refetch all pages". Fuery reloads every loaded page, in order, '
        'and isFetchingNextPage stays false.',
  ],
  source: 'lib/scenarios/infinite.dart',
  icon: Icons.all_inclusive,
  child: InfiniteScenario(),
);

// #region snippet
final feedQuery = InfiniteQuery(
  queryKey: ['feed'],
  queryFn: (context) => server.getFeed(context.pageParam),
  initialPageParam: 1,
  // The page after the last one, or null when there is none.
  getNextPageParam: (data) => data.lastPage.nextPage,
);
// #endregion

class InfiniteScenario extends StatelessWidget {
  const InfiniteScenario({super.key});

  @override
  Widget build(BuildContext context) {
    return InfiniteQueryListener(
      query: feedQuery,
      listenWhen: (previous, current) =>
          queryChanged(previous, current) ||
          previous.isFetchingNextPage != current.isFetchingNextPage ||
          previous.pages.length != current.pages.length,
      listener: (context, state) => Timeline.of(context).query(
        '${describeQuery(state)} · pages ${state.pages.length}'
        '${state.isFetchingNextPage ? ' · isFetchingNextPage' : ''}',
      ),
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    // #region snippet
    return InfiniteQueryBuilder(
      query: feedQuery,
      builder: (context, state) => ScenarioLayout(
        live: switch (state) {
          InfiniteQueryResult(hasData: true) => Feed(
              pages: state.pages,
              footer: state.isFetchingNextPage
                  ? const Loading(label: 'Loading the next page…')
                  : state.hasNextPage
                      ? ActionButton(
                          'Load more',
                          primary: true,
                          // A refetch of every page is running: let it
                          // finish first.
                          onPressed: state.isFetching
                              ? null
                              : () => state.fetchNextPage(),
                        )
                      : const Text('No more pages.'),
            ),
          InfiniteQueryResult(:final error?) => ErrorMessage(error),
          _ => const Loading(),
        },
        controls: ControlBar(
          children: [
            ActionButton(
              'Refetch all pages',
              onPressed: () => state.refetch(),
            ),
          ],
        ),
        state: QueryStatePanel(
          state,
          describe: (data) => 'InfiniteData(pageParams: ${data.pageParams})',
          extra: [
            StateRow('pages.length', ValueText('${state.pages.length}')),
            StateRow(
              'hasNextPage',
              Pill(
                '${state.hasNextPage}',
                tone: state.hasNextPage
                    ? Tone.good(context)
                    : Tone.neutral(context),
              ),
            ),
            StateRow(
              'isFetchingNextPage',
              Pill(
                '${state.isFetchingNextPage}',
                tone: state.isFetchingNextPage
                    ? Tone.active(context)
                    : Tone.neutral(context),
              ),
            ),
          ],
        ),
      ),
    );
    // #endregion
  }
}

/// The loaded pages, each under its number, and a footer.
class Feed extends StatelessWidget {
  const Feed({super.key, required this.pages, required this.footer});

  final List<FeedPage> pages;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, page) in pages.indexed) ...[
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 4),
            child: Text(
              'Page ${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final item in page.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(item),
            ),
        ],
        const SizedBox(height: 12),
        Center(child: footer),
      ],
    );
  }
}
