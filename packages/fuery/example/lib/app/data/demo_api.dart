import 'package:example/app/data/todo.dart';

/// A page of todos, as a paginated endpoint would return it.
class TodoPage {
  const TodoPage({required this.todos, required this.hasMore});

  final List<Todo> todos;
  final bool hasMore;
}

/// A long-running job, polled until it finishes.
class Job {
  const Job({required this.id, required this.progress});

  final String id;
  final int progress;

  bool get isDone => progress >= 100;
}

/// Extra endpoints for the example, with the delays a real API would have.
class DemoApi {
  static const _pageSize = 8;
  static const _total = 34;

  static final Map<String, int> _jobs = {};

  Future<TodoPage> getPage(int page) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final first = (page - 1) * _pageSize;
    final last = (first + _pageSize).clamp(0, _total);
    return TodoPage(
      todos: [
        for (var index = first; index < last; index++)
          Todo(
            id: 1000 + index,
            title: 'Archived todo ${index + 1}',
            description: 'Page $page',
            isCompleted: index.isEven,
          ),
      ],
      hasMore: last < _total,
    );
  }

  Future<List<Todo>> search(String term) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final lowercase = term.toLowerCase();
    return [
      for (var index = 0; index < _total; index++)
        if ('archived todo ${index + 1}'.contains(lowercase))
          Todo(
            id: 1000 + index,
            title: 'Archived todo ${index + 1}',
            description: 'Matched "$term"',
            isCompleted: index.isEven,
          ),
    ];
  }

  /// Starts a job and returns its id. It advances with every poll.
  String startJob() {
    final id = 'job-${_jobs.length + 1}';
    _jobs[id] = 0;
    return id;
  }

  Future<Job> getJob(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final progress = (_jobs[id] ?? 0) + 20;
    _jobs[id] = progress.clamp(0, 100);
    return Job(id: id, progress: _jobs[id]!);
  }

  /// An answer that arrives word by word, like a model streaming tokens.
  Stream<String> answer(String question) async* {
    final words = 'Fuery keeps $question cached, fresh, and easy to read '
            'from widgets, cubits, and plain Dart.'
        .split(' ');
    for (final word in words) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      yield word;
    }
  }
}
