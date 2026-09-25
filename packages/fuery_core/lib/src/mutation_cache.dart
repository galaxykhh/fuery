part of 'core.dart';

typedef AnyCachedMutation = CachedMutation<Object?, Object?, Object?>;

/// Any mutation definition, as [QueryClient.restore] takes them.
typedef AnyMutation = Mutation<Object?, Object?, Object?>;

@Deprecated('Use AnyMutation.')
typedef AnyMutationOptions = AnyMutation;

/// Selects mutations, for example in [QueryClient.isMutating], or the runs
/// a [MutationStateSlot] shows.
@immutable
class MutationFilters
    implements MutationStateSource<Object?, Object?, Object?> {
  const MutationFilters({
    this.mutationKey,
    this.exact = false,
    this.status,
    this.predicate,
  });

  final MutationKey? mutationKey;
  final bool exact;
  final MutationStatus? status;
  final bool Function(AnyCachedMutation mutation)? predicate;

  bool matches(AnyCachedMutation mutation) => _matcher()(mutation);

  /// A test for [matches] that converts [mutationKey] once, for testing many
  /// mutations. Each mutation converts its own key once too, and again when
  /// the key no longer holds the same content: new options can bring another
  /// key, and a key can change in place.
  bool Function(AnyCachedMutation mutation) _matcher() {
    final mutationKey = this.mutationKey;
    if (mutationKey == null) return _matchesState;
    // Converted on first use, so a key that can't be converted only throws
    // once there is a mutation with a key to test.
    if (exact) {
      late final hash = hashKey(mutationKey);
      return (mutation) {
        final key = mutation._keyHash;
        return key != null && key == hash && _matchesState(mutation);
      };
    }
    late final form = keyForm(mutationKey);
    return (mutation) {
      final key = mutation._keyForm;
      return key != null &&
          partialMatchForms(key, form) &&
          _matchesState(mutation);
    };
  }

  /// Whether [mutation] matches every filter but [mutationKey].
  bool _matchesState(AnyCachedMutation mutation) {
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

  final FutureOr<void> Function(Object? variables, AnyCachedMutation mutation)?
      onMutate;
  final FutureOr<void> Function(
    Object? data,
    Object? variables,
    Object? context,
    AnyCachedMutation mutation,
  )? onSuccess;
  final FutureOr<void> Function(
    Object error,
    Object? variables,
    Object? context,
    AnyCachedMutation mutation,
  )? onError;
  final FutureOr<void> Function(
    Object? data,
    Object? error,
    Object? variables,
    Object? context,
    AnyCachedMutation mutation,
  )? onSettled;
}

/// Holds the mutations of a [QueryClient].
///
/// Read mutations with [find] and [findAll], and watch them with
/// [QueryClient.watch].
class MutationCache {
  MutationCache({this.config = const MutationCacheConfig()});

  final MutationCacheConfig config;
  final Set<AnyCachedMutation> _mutations = {};
  final Map<String, List<AnyCachedMutation>> _scopes = {};
  final Set<void Function()> _listeners = {};
  int _mutationId = 0;

  CachedMutation<TData, TVariables, TContext>
      _build<TData, TVariables, TContext>(
    QueryClient client,
    Mutation<TData, TVariables, TContext> options,
  ) {
    final mutation = CachedMutation<TData, TVariables, TContext>._(
      client: client,
      mutationCache: this,
      mutationId: ++_mutationId,
      options: client._defaultMutationOptions(options),
    );
    _add(mutation);
    return mutation;
  }

  void _add(AnyCachedMutation mutation) {
    _mutations.add(mutation);
    final scope = mutation._scopeId;
    if (scope != null) {
      (_scopes[scope] ??= []).add(mutation);
    }
    _notify();
  }

  void _remove(AnyCachedMutation mutation) {
    mutation._removed = true;
    mutation._destroy();
    if (_mutations.remove(mutation)) {
      final scope = mutation._scopeId;
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
  bool _canRun(AnyCachedMutation mutation) {
    final scope = mutation._scopeId;
    if (scope == null) return true;
    final firstPending = _scopes[scope]
        ?.firstWhereOrNull((m) => m.state.status == MutationStatus.pending);
    return firstPending == null || identical(firstPending, mutation);
  }

  /// Starts the next paused mutation in the scope of [mutation]. Its result
  /// and errors go to whoever started it, so they are not reported here.
  Future<void> _runNext(AnyCachedMutation mutation) {
    final scope = mutation._scopeId;
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

  List<AnyCachedMutation> getAll() => _mutations.toList();

  AnyCachedMutation? find(MutationFilters filters) {
    final exact = MutationFilters(
      mutationKey: filters.mutationKey,
      exact: true,
      status: filters.status,
      predicate: filters.predicate,
    );
    return getAll().firstWhereOrNull(exact._matcher());
  }

  List<AnyCachedMutation> findAll([
    MutationFilters filters = const MutationFilters(),
  ]) {
    return getAll().where(filters._matcher()).toList();
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
