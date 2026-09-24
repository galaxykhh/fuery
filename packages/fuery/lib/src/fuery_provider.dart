import 'package:flutter/widgets.dart';
import 'package:fuery_core/fuery_core.dart';

import 'fuery_binding.dart';

/// Provides a [QueryClient] to the widgets below and keeps it mounted.
///
/// Optional: without a provider, [FueryProvider.of] returns [Fuery.client].
/// Fuery widgets that get a definition, such as `QueryBuilder(query:
/// todosQuery)`, observe it with the provided client. An observer created
/// with `observe()` keeps the client it was given, [Fuery.client] by
/// default.
///
/// ```dart
/// runApp(
///   FueryProvider(
///     client: QueryClient(
///       defaultOptions: const DefaultOptions(
///         queries: QueryDefaults(staleTime: Duration(seconds: 30)),
///       ),
///     ),
///     child: const App(),
///   ),
/// );
/// ```
///
/// Create the client once, in `main`, in a `State` field, or in a test's
/// `setUp`, and pass it in. A [QueryClient] created in `build` is a new,
/// empty cache on every rebuild, including every hot reload: the provider
/// replaces its client, and the widgets below go back to loading and fetch
/// again.
class FueryProvider extends StatefulWidget {
  const FueryProvider({super.key, required this.client, required this.child});

  final QueryClient client;
  final Widget child;

  /// The nearest provided client, or [Fuery.client].
  ///
  /// With [listen], [context] rebuilds when the provided client is replaced,
  /// which is what widgets and hooks that render queries need. Without it,
  /// this is safe to call in `initState` and in `late final` field
  /// initializers.
  static QueryClient of(BuildContext context, {bool listen = false}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<_FueryScope>()
        : context.getInheritedWidgetOfExactType<_FueryScope>();
    return scope?.client ?? Fuery.client;
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
