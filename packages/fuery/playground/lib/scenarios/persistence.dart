import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import '../fake_server.dart';
import '../scenario.dart';
import '../session.dart';
import '../theme.dart';
import '../timeline.dart';
import '../widgets/basics.dart';
import '../widgets/query_log.dart';
import '../widgets/scenario_page.dart';
import '../widgets/state_panels.dart';

const persistenceScenario = Scenario(
  path: 'persistence',
  title: 'Surviving a restart',
  summary: 'A query with persist is stored as it changes. After a restart, '
      'the new client restores it: the data shows at once, with the time it '
      'was fetched, and refetches if it is stale.',
  tryThis: [
    'Press "Restart app". The list is back at once, restored from storage, '
        'and nothing is fetched: it is fresh for 10 s.',
    'Press "Add a book on the server", wait 10 s, then restart. The '
        'restored list shows first, with its old dataUpdatedAt, then the '
        'refetch brings the new book.',
    'Watch the storage below the state: one entry, written again after each '
        'fetch.',
  ],
  source: 'lib/scenarios/persistence.dart',
  icon: Icons.save_outlined,
  child: PersistenceScenario(),
);

// #region snippet
/// A QueryStorage that keeps its entries in memory. An app stores them on
/// the device, for example with shared preferences.
class MemoryStorage implements QueryStorage {
  final Map<String, String> _entries = {};

  @override
  String? read(String key) => _entries[key];

  @override
  void write(String key, String value) => _entries[key] = value;

  @override
  void delete(String key) => _entries.remove(key);

  @override
  Map<String, String> readAll() => Map.of(_entries);
}

final booksQuery = Query(
  queryKey: ['books'],
  queryFn: (_) => server.getBooks(),
  staleTime: const Duration(seconds: 10),
  persist: QueryPersist(
    toJson: (books) => books,
    fromJson: (json) => [for (final book in json! as List) book as String],
  ),
);

/// What "Restart app" runs: a new client on the same storage, restored
/// before the app shows anything, as `main` would.
Future<QueryClient> startApp(QueryStorage storage) async {
  final client = QueryClient(storage: storage);
  await client.restore();
  return client;
}
// #endregion

class PersistenceScenario extends StatelessWidget {
  const PersistenceScenario({super.key});

  void _restart(BuildContext context) {
    Timeline.of(context).action('The app closed. Starting it again…');
    Session.of(context).restart(startApp);
  }

  @override
  Widget build(BuildContext context) {
    return QueryLog(
      query: booksQuery,
      child: QueryBuilder(
        query: booksQuery,
        builder: (context, state) => ScenarioLayout(
          live: switch (state) {
            QueryResult(:final data?) => BookList(
                data,
                // Restored data counts as fetched only after a fetch.
                restored: !state.isFetchedAfterMount,
                refreshing: state.isFetching,
              ),
            QueryResult(:final error?) => ErrorMessage(error),
            _ => const Loading(),
          },
          controls: ControlBar(
            children: [
              ActionButton(
                'Restart app',
                primary: true,
                icon: Icons.power_settings_new,
                onPressed: () => _restart(context),
              ),
              ActionButton(
                'Add a book on the server',
                onPressed: server.addBookElsewhere,
              ),
              ActionButton('Refetch', onPressed: () => state.refetch()),
            ],
          ),
          state: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QueryStatePanel(state, staleTime: booksQuery.staleTime),
              const Divider(height: 24),
              const StorageView(),
            ],
          ),
        ),
      ),
    );
  }
}

class BookList extends StatelessWidget {
  const BookList(
    this.books, {
    super.key,
    required this.restored,
    required this.refreshing,
  });

  final List<String> books;
  final bool restored;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Reading list', style: theme.textTheme.titleMedium),
            ),
            if (restored)
              Pill('restored from storage', tone: Tone.waiting(context)),
            const SizedBox(width: 8),
            RefreshingDot(visible: refreshing),
          ],
        ),
        const SizedBox(height: 8),
        for (final book in books)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(book),
              ],
            ),
          ),
      ],
    );
  }
}

/// What the storage holds, read again every half second.
class StorageView extends StatelessWidget {
  const StorageView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Session.of(context).storage;
    final scheme = Theme.of(context).colorScheme;
    return Ticking(
      interval: const Duration(milliseconds: 500),
      builder: (context) {
        final entries = storage.readAll();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'storage (${entries.length} ${entries.length == 1 ? 'entry' : 'entries'})',
              style: TextStyle(
                fontFamily: monoFamily,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            for (final MapEntry(:key, :value) in entries.entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ValueText('$key\n$value', maxLines: 6),
              ),
          ],
        );
      },
    );
  }
}
