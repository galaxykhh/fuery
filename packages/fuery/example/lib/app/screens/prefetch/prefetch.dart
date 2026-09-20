import 'package:example/app/data/todo_queries.dart';
import 'package:example/app/screens/infinite_todos/infinite_todos.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// Fetching without any widget: `client.infiniteQuery` fills the cache, so the
/// archive screen opens with its first page already there.
class PrefetchScreen extends StatefulWidget {
  const PrefetchScreen({super.key});

  static const String routeName = 'prefetch';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const PrefetchScreen(),
    );
  }

  @override
  State<PrefetchScreen> createState() => _PrefetchScreenState();
}

class _PrefetchScreenState extends State<PrefetchScreen> {
  var _prefetching = false;

  Future<void> _open({required bool prefetch}) async {
    // Start from an empty cache, so both buttons are comparable.
    Fuery.client.removeQueries(queryKey: pagedTodosKey);

    if (prefetch) {
      setState(() => _prefetching = true);
      // The same call a route guard or a splash screen would make.
      await Fuery.client.infiniteQuery(pagedTodosOptions());
      if (!mounted) return;
      setState(() => _prefetching = false);
    }

    await Navigator.push(context, InfiniteTodosScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prefetch')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Both buttons open the archive. Only the second one fills the '
                'cache first, so it opens without a spinner.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _prefetching ? null : () => _open(prefetch: false),
                child: const Text('Open now'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _prefetching ? null : () => _open(prefetch: true),
                child:
                    Text(_prefetching ? 'Prefetching…' : 'Prefetch, then open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
