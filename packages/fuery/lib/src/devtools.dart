import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_provider.dart';

const _violet = Color(0xFF6B4EFF);
const _lime = Color(0xFFC6F542);
const _lavender = Color(0xFFC9BEFF);
const _ink = Color(0xFF14112B);
const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);

/// Shows a button over the app that opens a [FueryDevtoolsPanel], to inspect
/// queries and mutations while developing.
///
/// Put it in the app's `builder`, so it sits above every route:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FueryDevtools(child: child!),
///   home: const HomeScreen(),
/// )
/// ```
///
/// It only shows [child] in release builds.
class FueryDevtools extends StatefulWidget {
  const FueryDevtools({
    super.key,
    required this.child,
    this.client,
    this.enabled = !kReleaseMode,
    this.buttonAlignment = Alignment.centerRight,
    this.initiallyOpen = false,
  });

  final Widget child;

  /// The client to inspect. Defaults to `context.queryClient`.
  final QueryClient? client;

  /// Whether to show the devtools. Defaults to false in release builds.
  final bool enabled;

  /// Where the button sits. Defaults to halfway down the right edge, clear of
  /// the app bar, a floating action button, and a bottom navigation bar.
  final Alignment buttonAlignment;

  /// Whether the panel starts open.
  final bool initiallyOpen;

  @override
  State<FueryDevtools> createState() => _FueryDevtoolsState();
}

class _FueryDevtoolsState extends State<FueryDevtools> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;

    // The child keeps its place in the tree, so turning the devtools on or
    // off doesn't reset the app.
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (widget.enabled)
          Positioned.fill(
            child: _open
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.55,
                      child: FueryDevtoolsPanel(
                        client: widget.client,
                        onClose: () => setState(() => _open = false),
                      ),
                    ),
                  )
                : Padding(
                    padding: safeArea + const EdgeInsets.all(16),
                    child: Align(
                      alignment: widget.buttonAlignment,
                      child: _OpenButton(
                        onPressed: () => setState(() => _open = true),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Lists the queries and mutations of a client, with their state and data,
/// and lets you refetch, invalidate, reset, or remove queries.
///
/// [FueryDevtools] opens it over the app. Use it directly to show it
/// elsewhere, for example on a debug screen.
class FueryDevtoolsPanel extends StatefulWidget {
  const FueryDevtoolsPanel({super.key, this.client, this.onClose});

  /// The client to inspect. Defaults to `context.queryClient`.
  final QueryClient? client;

  /// Shows a close button that calls this.
  final VoidCallback? onClose;

  @override
  State<FueryDevtoolsPanel> createState() => _FueryDevtoolsPanelState();
}

typedef _PanelConfig = ({QueryClient client, VoidCallback? onClose});

class _FueryDevtoolsPanelState extends State<FueryDevtoolsPanel> {
  // The panel has its own overlay, so text fields work above the app's
  // navigator. The entry is built once and follows the widget through this
  // notifier.
  late final ValueNotifier<_PanelConfig> _config = ValueNotifier(_read());
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => ValueListenableBuilder(
      valueListenable: _config,
      builder: (context, config, _) => _PanelBody(
        client: config.client,
        onClose: config.onClose,
      ),
    ),
  );

  _PanelConfig _read() {
    return (
      client: widget.client ?? FueryProvider.of(context, listen: true),
      onClose: widget.onClose,
    );
  }

  @override
  void dispose() {
    _config.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _config.value = _read();
    return Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Theme(
        data: _theme,
        child: Overlay(initialEntries: [_entry]),
      ),
    );
  }
}

final _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _violet,
    brightness: Brightness.dark,
  ).copyWith(primary: _lavender, secondary: _lime, surface: _ink),
  visualDensity: VisualDensity.compact,
);

class _PanelBody extends StatefulWidget {
  const _PanelBody({required this.client, required this.onClose});

  final QueryClient client;
  final VoidCallback? onClose;

  @override
  State<_PanelBody> createState() => _PanelBodyState();
}

class _PanelBodyState extends State<_PanelBody> {
  var _showMutations = false;
  var _filter = '';
  String? _selected;
  late StreamSubscription<Object> _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_PanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client)) {
      _subscription.cancel();
      _selected = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // Rebuilds whenever anything the panel shows changes.
  void _listen() {
    _subscription = widget.client.watch(_snapshot).listen((_) {
      if (mounted) setState(() {});
    });
  }

  static Object _snapshot(QueryClient client) => [
        for (final query in client.queryCache.getAll())
          (query, query.state, query.observersCount, query.isStale),
        for (final mutation in client.mutationCache.getAll())
          (mutation, mutation.state),
      ];

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final queries = client.queryCache.getAll();
    final mutations = client.mutationCache.getAll().reversed.toList();
    final bottom = MediaQuery.maybePaddingOf(context)?.bottom ?? 0;

    return Material(
      color: _ink,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: _Mark(size: 18),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _Tab(
                          label: 'Queries (${queries.length})',
                          selected: !_showMutations,
                          onPressed: () =>
                              setState(() => _showMutations = false),
                        ),
                        _Tab(
                          label: 'Mutations (${mutations.length})',
                          selected: _showMutations,
                          onPressed: () =>
                              setState(() => _showMutations = true),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onClose case final onClose?)
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _showMutations
                  ? _MutationList(mutations: mutations)
                  : _queries(client, queries),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queries(QueryClient client, List<CachedQuery<Object>> queries) {
    final shown = queries.where((q) => q.queryHash.contains(_filter)).toList();
    final selected =
        _selected == null ? null : client.queryCache.get(_selected!);

    final list = ListView(
      children: [
        for (final query in shown)
          ListTile(
            dense: true,
            selected: identical(query, selected),
            selectedTileColor: _violet.withAlpha(0x40),
            leading: _Badge(queryStatusLabel(query)),
            title: Text(query.queryHash, style: _mono),
            trailing: Text('${query.observersCount}'),
            onTap: () => setState(() => _selected = query.queryHash),
          ),
      ],
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Filter by key',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: selected == null
              ? list
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final detail = _QueryDetail(
                      client: client,
                      query: selected,
                      onRemoved: () => setState(() => _selected = null),
                    );
                    final wide = constraints.maxWidth >= 600;
                    return Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      children: [
                        Expanded(child: list),
                        if (wide)
                          const VerticalDivider(width: 1)
                        else
                          const Divider(height: 1),
                        Expanded(child: detail),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// How the devtools label a query: `fetching`, `paused`, `stale`, `fresh`,
/// or `inactive` when nothing watches it.
@visibleForTesting
String queryStatusLabel(CachedQuery<Object> query) {
  if (query.state.fetchStatus == FetchStatus.fetching) return 'fetching';
  if (query.state.fetchStatus == FetchStatus.paused) return 'paused';
  if (query.observersCount == 0) return 'inactive';
  if (!query.isActive) return 'disabled';
  return query.isStale ? 'stale' : 'fresh';
}

class _QueryDetail extends StatelessWidget {
  const _QueryDetail({
    required this.client,
    required this.query,
    required this.onRemoved,
  });

  final QueryClient client;
  final CachedQuery<Object> query;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final state = query.state;
    final key = query.queryKey;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(query.queryHash, style: _mono.copyWith(fontSize: 14)),
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () =>
                  client.refetchQueries(queryKey: key, exact: true).ignore(),
              child: const Text('Refetch'),
            ),
            TextButton(
              onPressed: () =>
                  client.invalidateQueries(queryKey: key, exact: true).ignore(),
              child: const Text('Invalidate'),
            ),
            TextButton(
              onPressed: () =>
                  client.resetQueries(queryKey: key, exact: true).ignore(),
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () {
                client.removeQueries(queryKey: key, exact: true);
                onRemoved();
              },
              child: const Text('Remove'),
            ),
          ],
        ),
        _Field('Status', '${state.status.name} · ${state.fetchStatus.name}'),
        _Field('Observers', '${query.observersCount}'),
        _Field('Updated', formatTime(state.dataUpdatedAt)),
        _Field('Failures', '${state.fetchFailureCount}'),
        if (state.error case final error?) _Field('Error', '$error'),
        const SizedBox(height: 8),
        SelectableText(formatData(state.data), style: _mono),
      ],
    );
  }
}

class _MutationList extends StatelessWidget {
  const _MutationList({required this.mutations});

  final List<AnyCachedMutation> mutations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final mutation in mutations)
          ListTile(
            dense: true,
            leading: _Badge(mutation.state.status.name),
            title: Text(
              switch (mutation.options.mutationKey) {
                final key? => hashKey(key),
                null => 'Mutation ${mutation.mutationId}',
              },
              style: _mono,
            ),
            subtitle: Text(
              [
                'variables: ${formatData(mutation.state.variables)}',
                if (mutation.state.error case final error?) 'error: $error',
              ].join('\n'),
              style: _mono,
            ),
          ),
      ],
    );
  }
}

/// Formats data as indented JSON, using `toJson()` where objects have it,
/// and falls back to `toString()`.
@visibleForTesting
String formatData(Object? data) {
  try {
    return const JsonEncoder.withIndent('  ', _toEncodable).convert(data);
  } catch (_) {
    return '$data';
  }
}

Object? _toEncodable(Object? value) {
  try {
    // ignore: avoid_dynamic_calls
    return (value as dynamic).toJson();
  } on NoSuchMethodError {
    return '$value';
  }
}

/// Formats a timestamp in milliseconds as `HH:mm:ss`, or `-` for none.
@visibleForTesting
String formatTime(int milliseconds) {
  if (milliseconds == 0) return '-';
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(color: _lavender),
            ),
            TextSpan(text: value, style: _mono),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  static const _colors = {
    'fresh': _lime,
    'success': _lime,
    'fetching': Color(0xFF9D8CFF),
    'pending': Color(0xFF9D8CFF),
    'paused': Color(0xFFFFB547),
    'stale': Color(0xFFFFD84D),
    'error': Color(0xFFFF6B6B),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[label] ?? const Color(0xFF8A86A3);
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(0x2E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(color: selected ? _lime : _lavender),
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Open Fuery devtools',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(blurRadius: 8, color: Color(0x55000000))
            ],
          ),
          child: const _Mark(size: 24),
        ),
      ),
    );
  }
}

/// The Fuery mark: two violet bars and a lime tile forming an F.
class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bar = size * 0.3;
    Widget tile(Color color) => DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.08),
          ),
        );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Positioned(
              left: 0, top: 0, bottom: 0, width: bar, child: tile(_violet)),
          Positioned(
              left: bar * 1.2,
              top: 0,
              right: 0,
              height: bar,
              child: tile(_violet)),
          Positioned(
            left: size * 0.5,
            top: bar * 1.2,
            width: bar,
            height: bar,
            child: tile(_lime),
          ),
        ],
      ),
    );
  }
}
