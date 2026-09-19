import 'package:example/app/screens/todo_stats/todo_stats_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TodoStatsScreen extends StatelessWidget {
  const TodoStatsScreen({super.key});

  static const String routeName = 'todo_stats';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const TodoStatsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TodoStatsCubit(),
      child: const _TodoStatsView(),
    );
  }
}

class _TodoStatsView extends StatelessWidget {
  const _TodoStatsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton.outlined(
            onPressed: context.read<TodoStatsCubit>().refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<TodoStatsCubit, TodoStatsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text('Error: ${state.error}'));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.completed} of ${state.total} completed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state.progress),
                if (state.isRefreshing) ...[
                  const SizedBox(height: 12),
                  const Text('Refreshing…'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
