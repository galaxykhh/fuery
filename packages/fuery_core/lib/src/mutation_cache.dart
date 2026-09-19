part of 'core.dart';

typedef AnyMutation = Mutation<Object?, Object?, Object?>;

/// Selects mutations, for example in [QueryClient.isMutating].
@immutable
class MutationFilters {
  const MutationFilters({
    this.mutationKey,
    this.exact = false,
    this.status,
    this.predicate,
  });

  final MutationKey? mutationKey;
  final bool exact;
  final MutationStatus? status;
  final bool Function(AnyMutation mutation)? predicate;

  bool matches(AnyMutation mutation) {
    final mutationKey = this.mutationKey;
    if (mutationKey != null) {
      final key = mutation.options.mutationKey;
      if (key == null) return false;
      if (exact) {
        if (hashKey(key) != hashKey(mutationKey)) return false;
      } else if (!partialMatchKey(key, mutationKey)) {
        return false;
      }
    }

    if (status != null && mutation.state.status != status) return false;

    final predicate = this.predicate;
    if (predicate != null && !predicate(mutation)) return false;

    return true;
  }
}

/// Global callbacks for every mutation in a cache.
@immutable
class MutationCacheConfig {
  const MutationCacheConfig({
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  final FutureOr<void> Function(Object? variables, AnyMutation mutation)?
      onMutate;
  final FutureOr<void> Function(
    Object? data,
    Object? variables,
    Object? context,
    AnyMutation mutation,
  )? onSuccess;
  final FutureOr<void> Function(
    Object error,
    Object? variables,
    Object? context,
    AnyMutation mutation,
  )? onError;
  final FutureOr<void> Function(
    Object? data,
    Object? error,
    Object? variables,
    Object? context,
    AnyMutation mutation,
  )? onSettled;
}

/// Holds the mutations of a [QueryClient].
///
/// Read mutations with [find] and [findAll], and watch them with
/// [QueryClient.watch].
class MutationCache {
  MutationCache({this.config = const MutationCacheConfig()});

  final MutationCacheConfig config;
  final Set<AnyMutation> _mutations = {};
  final Map<String, List<AnyMutation>> _scopes = {};
  final Set<void Function()> _listeners = {};
  int _mutationId = 0;

  Mutation<TData, TVariables, TContext> _build<TData, TVariables, TContext>(
    QueryClient client,
    MutationOptions<TData, TVariables, TContext> options,
  ) {
    final mutation = Mutation<TData, TVariables, TContext>._(
      mutationCache: this,
      mutationId: ++_mutationId,
      options: client.defaultMutationOptions(options),
    );
    _add(mutation);
    return mutation;
  }

  void _add(AnyMutation mutation) {
    _mutations.add(mutation);
    final scope = mutation.options.scope?.id;
    if (scope != null) {
      (_scopes[scope] ??= []).add(mutation);
    }
    _notify();
  }

  void _remove(AnyMutation mutation) {
    mutation._removed = true;
    mutation._destroy();
    if (_mutations.remove(mutation)) {
      final scope = mutation.options.scope?.id;
      if (scope != null) {
        final scoped = _scopes[scope];
        scoped?.remove(mutation);
        if (scoped != null && scoped.isEmpty) _scopes.remove(scope);
      }
    }
    _notify();
  }

  /// Whether [mutation] may run now. In a scope, only the first pending
  /// mutation runs.
  bool _canRun(AnyMutation mutation) {
    final scope = mutation.options.scope?.id;
    if (scope == null) return true;
    final firstPending = _scopes[scope]
        ?.firstWhereOrNull((m) => m.state.status == MutationStatus.pending);
    return firstPending == null || identical(firstPending, mutation);
  }

  /// Starts the next paused mutation in the scope of [mutation]. Its result
  /// and errors go to whoever started it, so they are not reported here.
  Future<void> _runNext(AnyMutation mutation) {
    final scope = mutation.options.scope?.id;
    if (scope == null) return Future.value();
    final next = _scopes[scope]
        ?.firstWhereOrNull((m) => !identical(m, mutation) && m.state.isPaused);
    if (next == null) return Future.value();
    return next._resume().then<void>((_) {}, onError: (Object _) {});
  }

  void _clear() {
    for (final mutation in _mutations) {
      mutation._removed = true;
      mutation._destroy();
    }
    _mutations.clear();
    _scopes.clear();
    _notify();
  }

  List<AnyMutation> getAll() => _mutations.toList();

  AnyMutation? find(MutationFilters filters) {
    final exact = MutationFilters(
      mutationKey: filters.mutationKey,
      exact: true,
      status: filters.status,
      predicate: filters.predicate,
    );
    return getAll().firstWhereOrNull(exact.matches);
  }

  List<AnyMutation> findAll([
    MutationFilters filters = const MutationFilters(),
  ]) {
    return getAll().where(filters.matches).toList();
  }

  /// Calls [listener] whenever a mutation or its observers change.
  void Function() _subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notify() {
    notifyManager.batch(() {
      for (final listener in _listeners.toList()) {
        listener();
      }
    });
  }

  /// Resumes every paused mutation.
  Future<void> _resumePausedMutations() {
    final paused = getAll().where((m) => m.state.isPaused).toList();
    return notifyManager.batch(() {
      return Future.wait(
        paused.map((m) => m._resume().then<void>((_) {}, onError: (_) {})),
      );
    });
  }
}
