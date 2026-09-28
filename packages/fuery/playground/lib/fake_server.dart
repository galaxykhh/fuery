import 'dart:async';

import 'package:flutter/foundation.dart';

/// The fake server of the scenario on screen.
///
/// Each scenario starts a server of its own, so a query function always
/// reaches the server of the scenario it runs in.
FakeServer get server => FakeServer.current;

/// An in-memory server with a delay on every request.
///
/// The server bar shows its [latency], [failNext], and [requestCount], and
/// the timeline shows every request.
class FakeServer extends ChangeNotifier {
  FakeServer({Duration latency = const Duration(seconds: 1)})
      : _latency = latency {
    _seed();
  }

  /// The server that [server] returns.
  static FakeServer current = FakeServer();

  /// How long each request takes.
  Duration get latency => _latency;
  Duration _latency;
  set latency(Duration value) {
    _latency = value;
    _notifyLater();
  }

  /// How many of the next requests fail.
  int get failNext => _failNext;
  int _failNext = 0;
  set failNext(int value) {
    _failNext = value.clamp(0, 9);
    _notifyLater();
  }

  /// How many requests the server has received.
  int get requestCount => _requestCount;
  int _requestCount = 0;

  /// The latest requests, oldest first.
  List<ServerRequest> get log => List.unmodifiable(_log);
  final List<ServerRequest> _log = [];

  final Map<Timer, ServerRequest> _pending = {};
  final List<void Function(ServerRequest request)> _requestListeners = [];
  bool _notifying = false;
  bool _disposed = false;

  /// Calls [listener] when a request starts and when it ends.
  void addRequestListener(void Function(ServerRequest request) listener) {
    _requestListeners.add(listener);
  }

  void removeRequestListener(void Function(ServerRequest request) listener) {
    _requestListeners.remove(listener);
  }

  /// Answers after [latency] with what [respond] returns, or fails when
  /// [failNext] says so. The response is read when the request ends, so it
  /// includes what changed on the server in the meantime.
  Future<T> _request<T>(String method, String path, T Function() respond) {
    final request = ServerRequest(
      id: ++_requestCount,
      method: method,
      path: path,
      fails: _failNext > 0,
    );
    if (request.fails) _failNext--;
    _log.add(request);
    if (_log.length > 100) _log.removeAt(0);
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(latency, () {
      _pending.remove(timer);
      if (request.fails) {
        request.outcome = RequestOutcome.failed;
        completer.completeError(
          ServerException('500 on request #${request.id}'),
        );
      } else {
        request.outcome = RequestOutcome.succeeded;
        completer.complete(respond());
      }
      _report(request);
    });
    _pending[timer] = request;
    _report(request);
    return completer.future;
  }

  void _report(ServerRequest request) {
    for (final listener in _requestListeners.toList()) {
      listener(request);
    }
    _notifyLater();
  }

  /// Drops the requests in flight: they never answer, as when the app that
  /// sent them closes.
  void dropPending() {
    final dropped = _pending.entries.toList();
    _pending.clear();
    for (final MapEntry(key: timer, value: request) in dropped) {
      timer.cancel();
      request.outcome = RequestOutcome.dropped;
      _report(request);
    }
  }

  /// Drops the requests in flight, and starts over with the first data.
  void reset({Duration? latency}) {
    dropPending();
    if (latency != null) _latency = latency;
    _failNext = 0;
    _requestCount = 0;
    _log.clear();
    _seed();
    _notifyLater();
  }

  // Listeners rebuild widgets, and a request can start while Flutter builds
  // (a query fetches when its widget mounts), so they hear of it after the
  // frame's work.
  void _notifyLater() {
    if (_notifying || _disposed) return;
    _notifying = true;
    scheduleMicrotask(() {
      _notifying = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _requestListeners.clear();
    dropPending();
    _disposed = true;
    super.dispose();
  }

  // The data, reset by [reset].
  late int _likes;
  late List<Message> _messages;
  late List<Todo> _todos;
  late List<String> _books;
  late int _nextId;

  void _seed() {
    _likes = 12;
    _messages = const [
      Message(id: 1, text: 'Welcome! Messages you send show up here.'),
      Message(id: 2, text: 'Go offline, then send one.'),
    ];
    _todos = const [
      Todo(id: 1, title: 'Read the Fuery docs'),
      Todo(id: 2, title: 'Try the playground'),
    ];
    _books = const ['Dune', 'Neuromancer'];
    _nextId = 100;
  }

  // Scenario 1: a post whose likes change on the server.

  Future<Post> getPost() => _request('GET', '/post', () {
        return Post(title: 'Fuery 1.6 is out', likes: _likes);
      });

  /// Someone else likes the post. The app hears nothing until it refetches.
  void likePostElsewhere() {
    _likes++;
    _notifyLater();
  }

  // Scenario 2: the signed-in user.

  Future<User> getUser() => _request('GET', '/user', () {
        return const User(name: 'Ada Lovelace', handle: '@ada', unread: 3);
      });

  // Scenario 3: a report that is expensive to build.

  Future<Report> getReport() {
    final id = _requestCount + 1;
    return _request('GET', '/report', () {
      return Report(visitors: 1204, request: id);
    });
  }

  // Scenario 4: a chat.

  Future<List<Message>> getMessages() => _request('GET', '/messages', () {
        return _messages;
      });

  Future<Message> sendMessage(String text) {
    return _request('POST', '/messages', () {
      final message = Message(id: ++_nextId, text: text);
      _messages = [..._messages, message];
      return message;
    });
  }

  // Scenario 5: a todo list.

  Future<List<Todo>> getTodos() => _request('GET', '/todos', () => _todos);

  Future<Todo> addTodo(String title) {
    return _request('POST', '/todos', () {
      final todo = Todo(id: ++_nextId, title: title);
      _todos = [..._todos, todo];
      return todo;
    });
  }

  // Scenario 6: numbered pages.

  static const pageSize = 4;
  static const _projects = [
    'Aurora',
    'Basalt',
    'Cedar',
    'Delta',
    'Ember',
    'Fjord',
    'Granite',
    'Harbor',
    'Iris',
    'Juniper',
    'Kestrel',
    'Lagoon',
    'Meadow',
    'Nimbus',
    'Onyx',
    'Prairie',
    'Quartz',
    'Redwood',
    'Sierra',
    'Tundra',
  ];

  /// How many pages of projects there are.
  static int get projectPages => _projects.length ~/ pageSize;

  Future<ProjectPage> getProjects(int page) {
    return _request('GET', '/projects?page=$page', () {
      final start = (page - 1) * pageSize;
      return ProjectPage(
        page: page,
        projects: _projects.sublist(start, start + pageSize),
        hasMore: page < projectPages,
      );
    });
  }

  // Scenario 7: a feed loaded a page at a time.

  static const feedPages = 4;

  Future<FeedPage> getFeed(int page) {
    return _request('GET', '/feed?page=$page', () {
      return FeedPage(
        items: [
          for (var i = 1; i <= 5; i++) 'Post ${(page - 1) * 5 + i}',
        ],
        nextPage: page < feedPages ? page + 1 : null,
      );
    });
  }

  // Scenario 8: a reading list that changes on the server.

  static const _moreBooks = [
    'Hyperion',
    'Foundation',
    'Snow Crash',
    'The Left Hand of Darkness',
  ];

  Future<List<String>> getBooks() => _request('GET', '/books', () => _books);

  /// Someone else adds a book. The app hears nothing until it refetches.
  void addBookElsewhere() {
    final next = _moreBooks[(_books.length - 2) % _moreBooks.length];
    _books = [..._books, next];
    _notifyLater();
  }
}

/// A request the fake server received.
class ServerRequest {
  ServerRequest({
    required this.id,
    required this.method,
    required this.path,
    required this.fails,
  });

  final int id;
  final String method;
  final String path;

  /// Whether the server answers it with an error.
  final bool fails;

  RequestOutcome outcome = RequestOutcome.pending;

  @override
  String toString() => '$method $path';
}

enum RequestOutcome { pending, succeeded, failed, dropped }

/// What the fake server throws when told to fail.
class ServerException implements Exception {
  const ServerException(this.message);

  final String message;

  @override
  String toString() => message;
}

@immutable
class Post {
  const Post({required this.title, required this.likes});

  final String title;
  final int likes;

  @override
  bool operator ==(Object other) =>
      other is Post && other.title == title && other.likes == likes;

  @override
  int get hashCode => Object.hash(title, likes);

  @override
  String toString() => 'Post(likes: $likes)';
}

@immutable
class User {
  const User({required this.name, required this.handle, required this.unread});

  final String name;
  final String handle;
  final int unread;

  String get initials => name.split(' ').map((part) => part[0]).join();

  @override
  String toString() => 'User($handle)';
}

@immutable
class Report {
  const Report({required this.visitors, required this.request});

  final int visitors;

  /// The request that built it.
  final int request;

  @override
  String toString() => 'Report(from request #$request)';
}

@immutable
class Message {
  const Message({required this.id, required this.text});

  final int id;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is Message && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);

  @override
  String toString() => 'Message($id)';
}

@immutable
class Todo {
  const Todo({required this.id, required this.title});

  /// A todo the server hasn't saved yet. It has an id below zero until the
  /// server's copy replaces it.
  factory Todo.draft(String title) => Todo(id: --_lastDraftId, title: title);

  static int _lastDraftId = 0;

  final int id;
  final String title;

  bool get isDraft => id < 0;

  @override
  bool operator ==(Object other) =>
      other is Todo && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => isDraft ? 'Todo(draft)' : 'Todo($id)';
}

@immutable
class ProjectPage {
  const ProjectPage({
    required this.page,
    required this.projects,
    required this.hasMore,
  });

  final int page;
  final List<String> projects;
  final bool hasMore;

  @override
  String toString() => 'ProjectPage($page)';
}

@immutable
class FeedPage {
  const FeedPage({required this.items, required this.nextPage});

  final List<String> items;
  final int? nextPage;

  @override
  String toString() => 'FeedPage(${items.first}…)';
}
