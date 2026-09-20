import 'package:example/app/data/demo_api.dart';
import 'package:example/app/data/todo_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Polls a job while it runs. `refetchWhile` stops the polling once the job
/// is done, without any timer in the screen.
class JobStatusScreen extends StatefulWidget {
  const JobStatusScreen({super.key});

  static const String routeName = 'job_status';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const JobStatusScreen(),
    );
  }

  @override
  State<JobStatusScreen> createState() => _JobStatusScreenState();
}

class _JobStatusScreenState extends State<JobStatusScreen> {
  String? _jobId;

  @override
  Widget build(BuildContext context) {
    final jobId = _jobId;
    return Scaffold(
      appBar: AppBar(title: const Text('Poll a job')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (jobId == null)
                const Text('No job yet')
              else
                QueryBuilder(
                  key: ValueKey(jobId),
                  query: jobQuery(jobId),
                  builder: (context, state) {
                    final job = state.data;
                    if (job == null) {
                      return const CircularProgressIndicator();
                    }
                    return Column(
                      children: [
                        Text('${job.progress}%'),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: job.progress / 100),
                        const SizedBox(height: 12),
                        Text(job.isDone ? 'Done, polling stopped' : 'Polling…'),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _jobId = DemoApi().startJob()),
                child: Text(jobId == null ? 'Start a job' : 'Start another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
