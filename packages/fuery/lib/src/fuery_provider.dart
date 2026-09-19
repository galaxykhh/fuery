import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';

/// Provides a [QueryClient] to the widgets below and keeps it mounted.
///
/// Optional: without a provider, [FueryProvider.of] returns [Fuery.client].
/// Use it to configure a client, or to give each widget test its own client.
///
/// ```dart
/// FueryProvider(
///   client: QueryClient(
///     defaultOptions: const DefaultOptions(
///       queries: QueryDefaults(staleTime: Duration(seconds: 30)),
///     ),
///   ),
///   child: const App(),
/// )
/// ```
class FueryProvider extends StatefulWidget {
  const FueryProvider({super.key, required this.client, required this.child});

  final QueryClient client;
  final Widget child;

  /// The nearest provided client, or [Fuery.client]. Safe to call in
  /// `initState` and in `late final` field initializers.
  static QueryClient of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_FueryScope>()?.client ??
        Fuery.client;
  }

  @override
  State<FueryProvider> createState() => _FueryProviderState();
}

class _FueryProviderState extends State<FueryProvider> {
  @override
  void initState() {
    super.initState();
    FueryBinding.ensureInitialized();
    widget.client.mount();
  }

  @override
  void didUpdateWidget(FueryProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client)) {
      oldWidget.client.unmount();
      widget.client.mount();
    }
  }

  @override
  void dispose() {
    widget.client.unmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FueryScope(client: widget.client, child: widget.child);
  }
}

class _FueryScope extends InheritedWidget {
  const _FueryScope({required this.client, required super.child});

  final QueryClient client;

  @override
  bool updateShouldNotify(_FueryScope oldWidget) => client != oldWidget.client;
}

extension FueryBuildContext on BuildContext {
  /// The nearest provided [QueryClient], or [Fuery.client].
  QueryClient get queryClient => FueryProvider.of(this);
}
