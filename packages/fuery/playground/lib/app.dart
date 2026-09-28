import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'scenario.dart';
import 'scenarios/infinite.dart';
import 'scenarios/lifecycle.dart';
import 'scenarios/offline.dart';
import 'scenarios/optimistic.dart';
import 'scenarios/pagination.dart';
import 'scenarios/persistence.dart';
import 'scenarios/retries.dart';
import 'scenarios/shared_cache.dart';
import 'session.dart';
import 'theme.dart';

/// Every scenario, in the order of the sidebar.
const scenarios = [
  lifecycleScenario,
  sharedCacheScenario,
  retriesScenario,
  offlineScenario,
  optimisticScenario,
  paginationScenario,
  infiniteScenario,
  persistenceScenario,
];

/// The scenario at [path], such as `/lifecycle`, or null for the home page.
Scenario? scenarioAt(String path) {
  for (final scenario in scenarios) {
    if (path == '/${scenario.path}') return scenario;
  }
  return null;
}

/// Screens at least this wide show the sidebar instead of a drawer.
const sidebarWidth = 1000.0;

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key, this.initialLocation});

  /// The route to open first, such as `/lifecycle`. Defaults to the one the
  /// platform reports: on the web, the part of the URL after `#`.
  final String? initialLocation;

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  late final _routeInformation = PlatformRouteInformationProvider(
    initialRouteInformation: RouteInformation(
      uri: Uri.parse(
        widget.initialLocation ??
            WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      ),
    ),
  );
  final _themeMode = ValueNotifier(ThemeMode.system);
  late final _router = _PlaygroundRouter(_themeMode);

  @override
  void dispose() {
    _routeInformation.dispose();
    _router.dispose();
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _themeMode,
      builder: (context, themeMode, _) => MaterialApp.router(
        title: 'Fuery playground',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: themeMode,
        routeInformationProvider: _routeInformation,
        routeInformationParser: const _PathParser(),
        routerDelegate: _router,
      ),
    );
  }
}

/// Reads `/lifecycle` from a URL, and anything it doesn't know as `/`.
class _PathParser extends RouteInformationParser<String> {
  const _PathParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) {
    final scenario = scenarioAt(routeInformation.uri.path);
    return SynchronousFuture(scenario == null ? '/' : '/${scenario.path}');
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri(path: configuration));
}

class _PlaygroundRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  _PlaygroundRouter(this.themeMode);

  final ValueNotifier<ThemeMode> themeMode;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  String _path = '/';

  @override
  String get currentConfiguration => _path;

  void go(String path) {
    if (path == _path) return;
    _path = path;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) {
    _path = configuration;
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          key: const ValueKey('shell'),
          child: PlaygroundShell(
            path: _path,
            onNavigate: go,
            themeMode: themeMode,
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

/// The sidebar, or a drawer on narrow screens, and the page at [path].
class PlaygroundShell extends StatelessWidget {
  const PlaygroundShell({
    super.key,
    required this.path,
    required this.onNavigate,
    required this.themeMode,
  });

  final String path;
  final ValueChanged<String> onNavigate;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final scenario = scenarioAt(path);
    final page = scenario == null
        ? HomePage(onOpen: onNavigate)
        : ScenarioHost(key: ValueKey(scenario.path), scenario: scenario);
    final wide = MediaQuery.sizeOf(context).width >= sidebarWidth;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              titleSpacing: 0,
              title: const Row(
                children: [
                  FueryMark(size: 24),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Fuery playground',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [ThemeModeButton(themeMode: themeMode)],
            ),
      drawer: wide
          ? null
          : Drawer(
              child: Builder(
                builder: (context) => ScenarioNav(
                  current: scenario,
                  themeMode: themeMode,
                  onNavigate: (path) {
                    Scaffold.of(context).closeDrawer();
                    onNavigate(path);
                  },
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) ...[
            SizedBox(
              width: 280,
              child: ScenarioNav(
                current: scenario,
                themeMode: themeMode,
                onNavigate: onNavigate,
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(key: const ValueKey('page'), child: page),
        ],
      ),
    );
  }
}

/// The list of scenarios.
class ScenarioNav extends StatelessWidget {
  const ScenarioNav({
    super.key,
    required this.current,
    required this.onNavigate,
    required this.themeMode,
  });

  final Scenario? current;
  final ValueChanged<String> onNavigate;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onNavigate('/'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const FueryMark(size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fuery',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Playground',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ThemeModeButton(themeMode: themeMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, scenario) in scenarios.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: ListTile(
                  dense: true,
                  selected: identical(scenario, current),
                  selectedTileColor: scheme.primaryContainer,
                  selectedColor: scheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(scenario.icon, size: 20),
                  title: Text(
                    '${index + 1}. ${scenario.title}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          identical(scenario, current) ? FontWeight.w600 : null,
                      color: identical(scenario, current)
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  onTap: () => onNavigate('/${scenario.path}'),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Each scenario runs on its own QueryClient and an in-memory '
                'server. The button at the bottom right opens the devtools.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switches between the system's theme, light, and dark.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, required this.themeMode});

  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => IconButton(
        tooltip: switch (mode) {
          ThemeMode.system => 'Theme: system',
          ThemeMode.light => 'Theme: light',
          ThemeMode.dark => 'Theme: dark',
        },
        icon: Icon(switch (mode) {
          ThemeMode.system => Icons.brightness_auto_outlined,
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
        }),
        onPressed: () => themeMode.value = switch (mode) {
          ThemeMode.system => ThemeMode.light,
          ThemeMode.light => ThemeMode.dark,
          ThemeMode.dark => ThemeMode.system,
        },
      ),
    );
  }
}

/// The page at `/`: what the playground is, and a card for each scenario.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.all(narrow ? 16 : 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FueryMark(size: 48),
                const SizedBox(height: 16),
                Text(
                  'Fuery playground',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    'Each scenario shows a query or a mutation next to the '
                    'state its widget receives, a timeline of what happened, '
                    'and the code that drives it. The server is in memory, '
                    'and you set its latency and the requests it fails.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - 16 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final (index, scenario) in scenarios.indexed)
                          SizedBox(
                            width: width,
                            child: _ScenarioCard(
                              number: index + 1,
                              scenario: scenario,
                              onTap: () => onOpen('/${scenario.path}'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.number,
    required this.scenario,
    required this.onTap,
  });

  final int number;
  final Scenario scenario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(scenario.icon, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$number. ${scenario.title}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scenario.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Fuery mark: tiles forming an F, with a fresh lime tile landing.
class FueryMark extends StatelessWidget {
  const FueryMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        ghostOpacity:
            Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.22,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.ghostOpacity});

  final double ghostOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // The geometry of assets/brand/mark.svg, on a 512 grid.
    canvas.scale(size.width / 512);
    void tile(double x, double y, double w, double h, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(34),
        ),
        Paint()..color = color,
      );
    }

    tile(40, 40, 132, 432, Brand.violet);
    tile(190, 40, 282, 132, Brand.violet);
    tile(190, 190, 132, 132, Brand.violet.withValues(alpha: ghostOpacity));
    tile(274, 190, 132, 132, Brand.lime);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.ghostOpacity != ghostOpacity;
}
