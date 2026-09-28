import 'package:flutter/material.dart';
import 'package:fuery/fuery.dart';

import 'fake_server.dart';
import 'scenario.dart';
import 'scenarios/persistence.dart' show MemoryStorage;
import 'timeline.dart';
import 'widgets/scenario_page.dart';

/// What a scenario runs on: its own client, fake server, storage, and
/// timeline.
abstract interface class Session {
  Scenario get scenario;
  QueryClient get client;
  FakeServer get server;
  MemoryStorage get storage;
  Timeline get timeline;

  /// Starts the scenario over: a new client, storage, and timeline, and a
  /// server with its first data.
  void reset();

  /// Restarts the app on the same storage and server: the requests in
  /// flight are dropped, [start] creates the next client, and the scenario's
  /// widgets are built again with it.
  Future<void> restart(
      Future<QueryClient> Function(MemoryStorage storage) start);

  /// The session of the scenario around [context].
  static Session of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_SessionScope>();
    assert(scope != null, 'No ScenarioHost above this widget');
    return scope!.session;
  }
}

/// Runs a [Scenario] on a [Session] of its own, and shows it with the
/// devtools.
class ScenarioHost extends StatefulWidget {
  const ScenarioHost({super.key, required this.scenario});

  final Scenario scenario;

  @override
  State<ScenarioHost> createState() => _ScenarioHostState();
}

class _ScenarioHostState extends State<ScenarioHost> implements Session {
  @override
  Scenario get scenario => widget.scenario;

  @override
  late final FakeServer server = FakeServer(latency: scenario.latency);

  @override
  final Timeline timeline = Timeline();

  @override
  MemoryStorage storage = MemoryStorage();

  @override
  late QueryClient client = QueryClient(storage: storage);

  /// Clients that a restart replaced. They keep the storage, so they are
  /// cleared only when the scenario starts over or closes.
  final List<QueryClient> _retired = [];

  /// Changes whenever the scenario's widgets must start over.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    FakeServer.current = server;
    server.addRequestListener(timeline.request);
  }

  @override
  void reset() {
    final old = [..._retired, client];
    _retired.clear();
    server.reset(latency: scenario.latency);
    timeline.clear();
    setState(() {
      storage = MemoryStorage();
      client = QueryClient(storage: storage);
      _generation++;
    });
    // The old widgets unsubscribe in this frame. Clearing the old clients
    // after it cancels their timers without starting any fetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final client in old) {
        client.clear();
      }
      _restoreDevice();
    });
  }

  @override
  Future<void> restart(
    Future<QueryClient> Function(MemoryStorage storage) start,
  ) async {
    server.dropPending();
    final next = await start(storage);
    if (!mounted) {
      next.clear();
      return;
    }
    setState(() {
      _retired.add(client);
      client = next;
      _generation++;
    });
  }

  /// Puts the device back online and in the foreground, for the next
  /// scenario.
  void _restoreDevice() {
    onlineManager.setOnline(true);
    focusManager.setFocused(null);
  }

  @override
  void dispose() {
    server.removeRequestListener(timeline.request);
    server.dispose();
    // The widgets below are gone, so nothing refetches.
    for (final client in [..._retired, client]) {
      client.clear();
    }
    timeline.dispose();
    _restoreDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SessionScope(
      session: this,
      child: TimelineScope(
        timeline: timeline,
        child: FueryProvider(
          client: client,
          // The devtools inspect this scenario's client. The playground
          // shows them in release builds too.
          child: FueryDevtools(
            enabled: true,
            buttonAlignment: Alignment.bottomRight,
            child: ScenarioPage(
              scenario: scenario,
              child: KeyedSubtree(
                key: ValueKey(_generation),
                child: scenario.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionScope extends InheritedWidget {
  const _SessionScope({required this.session, required super.child});

  final Session session;

  @override
  bool updateShouldNotify(_SessionScope oldWidget) => false;
}
