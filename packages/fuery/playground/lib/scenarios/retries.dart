import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const retriesScenario = Scenario(
  path: 'retries',
  title: 'Retries',
  summary: 'A failed fetch retries before the query gives up. While it '
      'retries, failureCount and failureReason say why, and the error '
      'shows only when every attempt has failed.',
  tryThis: [
    'Set "fail next" to 2 requests, then press "Reset and load". Two '
        'attempts fail, and the third succeeds.',
    'Set it to 5 and press "Reset and load" again. All four attempts fail, '
        '0.5 s, 1 s, then 2 s apart, and the error shows.',
    'Press "Try again". One request still fails, and the retry after it '
        'succeeds.',
    'With data on screen, fail 4 and press Refetch. The data stays, and the '
        'error shows beside it.',
  ],
  source: 'lib/scenarios/retries.dart',
  icon: Icons.replay,
  latency: Duration(milliseconds: 300),
  child: RetriesScenario(),
);

// #region snippet
final reportQuery = Query(
  queryKey: ['report'],
  queryFn: (_) => server.getReport(),
  // Retry three times, 0.5 s, 1 s, then 2 s after each failure. By
  // default, a query retries three times, 1 s, 2 s, then 4 s apart.
  retry: const RetryPolicy.count(3),
  retryDelay: (failureCount, error) =>
      Duration(milliseconds: 500 << failureCount),
);
// #endregion

class RetriesScenario extends StatelessWidget {
  const RetriesScenario({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryLog(query: reportQuery, child: _build(context));
  }

  Widget _build(BuildContext context) {
    // #region snippet
    return QueryBuilder(
      query: reportQuery,
      builder: (context, state) => ScenarioLayout(
        live: switch (state) {
          QueryResult(:final data?) => ReportCard(data, state: state),
          QueryResult(:final error?) =>
            ErrorMessage(error, onRetry: () => state.refetch()),
          _ => Retrying(state),
        },
        controls: ControlBar(
          children: [
            ActionButton('Refetch', onPressed: () => state.refetch()),
            ActionButton(
              'Reset and load',
              onPressed: () =>
                  context.queryClient.resetQueries(queryKey: ['report']),
            ),
          ],
        ),
        state: QueryStatePanel(state),
      ),
    );
    // #endregion
  }
}

/// How long the query waits after its latest failure.
Duration _nextDelay(QueryResult<Report> state) =>
    reportQuery.retryDelay!(state.failureCount - 1, state.failureReason!);

/// The loading state, with the attempts that failed so far.
class Retrying extends StatelessWidget {
  const Retrying(this.state, {super.key});

  final QueryResult<Report> state;

  @override
  Widget build(BuildContext context) {
    if (state.failureCount == 0) return const Loading(label: 'Attempt 1…');
    return Loading(
      label: 'Attempt ${state.failureCount} failed: ${state.failureReason}.\n'
          'Attempt ${state.failureCount + 1} of 4 follows '
          '${formatSeconds(_nextDelay(state))} after it.',
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard(this.report, {super.key, required this.state});

  final Report report;
  final QueryResult<Report> state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = this.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Weekly report', style: theme.textTheme.titleMedium),
            ),
            RefreshingDot(visible: state.isFetching),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${report.visitors} visitors',
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          'Built by request #${report.request}',
          key: const Key('report-request'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.isFetching && state.failureCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Refetch attempt ${state.failureCount} failed. Attempt '
            '${state.failureCount + 1} of 4 follows '
            '${formatSeconds(_nextDelay(state))} after it.',
          ),
        ] else if (state.isRefetchError) ...[
          const SizedBox(height: 12),
          Text(
            'The refetch failed: ${state.error}. The data above stays.',
            style: const TextStyle(color: Color(0xFFE5484D)),
          ),
        ],
      ],
    );
  }
}
