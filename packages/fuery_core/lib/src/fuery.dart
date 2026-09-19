part of 'core.dart';

/// Holds the default [QueryClient] used by [Query.use], [InfiniteQuery.use],
/// and [Mutation.use] when no client is passed.
abstract final class Fuery {
  static QueryClient? _instance;

  /// The default client. Created and mounted on first use.
  static QueryClient get instance => _instance ??= QueryClient()..mount();

  /// Replaces the default client, for example with one configured with
  /// [DefaultOptions], or a fresh one in tests. Call [QueryClient.mount] on it
  /// to refetch on focus and reconnect.
  static set instance(QueryClient client) => _instance = client;
}
