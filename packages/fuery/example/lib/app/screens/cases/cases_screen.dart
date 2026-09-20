import 'package:example/app/data/todo_queries.dart';
import 'package:example/app/screens/infinite_todos/infinite_todos.dart';
import 'package:example/app/screens/job_status/job_status.dart';
import 'package:example/app/screens/prefetch/prefetch.dart';
import 'package:example/app/screens/search_todos/search_todos.dart';
import 'package:example/app/screens/streaming_answer/streaming_answer.dart';
import 'package:example/app/screens/todo_list/todo_list.dart';
import 'package:example/app/screens/todo_stats/todo_stats.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Lists every case in the example. Each one is a small screen that shows one
/// way of using Fuery.
class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  static const String routeName = 'cases';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const CasesScreen(),
    );
  }

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  // The todo list is shared with the list screen and the stats cubit, so the
  // count below and those screens use one request.
  final todos = todosQuery();

  // Any value computed from the client can be watched as a stream, without
  // fetching anything.
  late final Stream<int> activity = Fuery.client.watch(
    (client) => client.isFetching() + client.isMutating(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuery examples'),
        actions: [
          // Rebuilds only when the number of todos changes.
          QuerySelector(
            query: todos,
            selector: (state) => state.data?.length ?? 0,
            builder: (context, count) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('$count todos')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StreamBuilder(
              stream: activity,
              builder: (context, snapshot) => SizedBox.square(
                dimension: 16,
                child: (snapshot.data ?? 0) > 0
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          _Case(
            title: 'List, refresh, and optimistic delete',
            subtitle: 'QueryBuilder, buildWhen, Mutation with rollback',
            route: TodoListScreen.route,
          ),
          _Case(
            title: 'Stats in a cubit',
            subtitle: 'The same query, read from a Cubit through its stream',
            route: TodoStatsScreen.route,
          ),
          _Case(
            title: 'Paged archive',
            subtitle: 'InfiniteQuery with fetchNextPage',
            route: InfiniteTodosScreen.route,
          ),
          _Case(
            title: 'Search as you type',
            subtitle: 'A key per term, keeping the previous results on screen',
            route: SearchTodosScreen.route,
          ),
          _Case(
            title: 'Poll a job until it finishes',
            subtitle: 'refetchInterval with refetchWhile',
            route: JobStatusScreen.route,
          ),
          _Case(
            title: 'Streamed answer',
            subtitle: 'streamedQuery folds chunks into the cached data',
            route: StreamingAnswerScreen.route,
          ),
          _Case(
            title: 'Prefetch before navigating',
            subtitle:
                'client.query outside widgets, so the next screen is ready',
            route: PrefetchScreen.route,
          ),
        ],
      ),
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final Route Function() route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, route()),
    );
  }
}
