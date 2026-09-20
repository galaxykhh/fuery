import 'package:example/app/data/todo_queries.dart';
import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

/// A streamed answer. `streamedQuery` folds every chunk into the query's data,
/// so the text grows while it arrives and stays cached when you come back.
class StreamingAnswerScreen extends StatefulWidget {
  const StreamingAnswerScreen({super.key});

  static const String routeName = 'streaming_answer';

  static Route route() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => const StreamingAnswerScreen(),
    );
  }

  @override
  State<StreamingAnswerScreen> createState() => _StreamingAnswerScreenState();
}

class _StreamingAnswerScreenState extends State<StreamingAnswerScreen> {
  static const _questions = ['your todos', 'this example'];

  String _question = _questions.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streamed answer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton(
              segments: [
                for (final question in _questions)
                  ButtonSegment(value: question, label: Text(question)),
              ],
              selected: {_question},
              onSelectionChanged: (selection) =>
                  setState(() => _question = selection.first),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: QueryBuilder(
                key: ValueKey(_question),
                query: answerQuery(_question),
                builder: (context, state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.data ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (state.isFetching)
                      const Text('Streaming…')
                    else
                      const Text('Complete, and cached'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
