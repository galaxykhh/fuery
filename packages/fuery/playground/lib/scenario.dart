import 'package:flutter/widgets.dart';

/// One page of the playground: an idea of Fuery, shown with a live UI, its
/// state, a timeline, and the code that drives it.
@immutable
class Scenario {
  const Scenario({
    required this.path,
    required this.title,
    required this.summary,
    required this.tryThis,
    required this.source,
    required this.icon,
    required this.child,
    this.latency = const Duration(seconds: 1),
  });

  /// The route, without the leading slash: `/#/lifecycle` opens `lifecycle`.
  final String path;

  final String title;

  /// One or two sentences on what the scenario shows.
  final String summary;

  /// Steps to try, in order.
  final List<String> tryThis;

  /// The asset path of the file whose `// #region snippet` regions the code
  /// panel shows.
  final String source;

  final IconData icon;

  /// The scenario's live UI, controls, and panels. It is built again, with a
  /// fresh client and server, when the scenario starts over.
  final Widget child;

  /// The fake server's latency when the scenario starts.
  final Duration latency;
}
