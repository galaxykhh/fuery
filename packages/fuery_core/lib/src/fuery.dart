part of 'core.dart';

/// Holds the default [QueryClient], which [Query.observe] and
/// [Mutation.observe] use when no client is passed.
abstract final class Fuery {
  static QueryClient? _client;

  /// The default client. Created and mounted on first use.
  static QueryClient get client => _client ??= QueryClient()..mount();

  /// Replaces the default client, for example with one that has a storage or
  /// other defaults. The new client is mounted, so it refetches on focus and
  /// reconnect, and the previous one is unmounted.
  ///
  /// ```dart
  /// Fuery.client = QueryClient(storage: myStorage); // your QueryStorage
  /// ```
  static set client(QueryClient client) {
    final previous = _client;
    if (identical(previous, client)) return;
    client.mount();
    previous?.unmount();
    _client = client;
  }
}
