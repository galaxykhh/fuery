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

sealed class MutationCacheEvent {
  const MutationCacheEvent();

  /// The mutation the event is about. Only [MutationObserverOptionsUpdatedEvent]
  /// can have none, when its observer has not run a mutation yet.
  AnyMutation? get mutation;
}

final class MutationAddedEvent extends MutationCacheEvent {
  const MutationAddedEvent(this.mutation);
  @override
  final AnyMutation mutation;
}

final class MutationRemovedEvent extends MutationCacheEvent {
  const MutationRemovedEvent(this.mutation);
  @override
  final AnyMutation mutation;
}

final class MutationUpdatedEvent extends MutationCacheEvent {
  const MutationUpdatedEvent(this.mutation, this.action);
  @override
  final AnyMutation mutation;
  final MutationAction action;
}

final class MutationObserverAddedEvent extends MutationCacheEvent {
  const MutationObserverAddedEvent(this.mutation, this.observer);
  @override
  final AnyMutation mutation;
  final MutationObserver<Object?, Object?, Object?> observer;
}

final class MutationObserverRemovedEvent extends MutationCacheEvent {
  const MutationObserverRemovedEvent(this.mutation, this.observer);
  @override
  final AnyMutation mutation;
  final MutationObserver<Object?, Object?, Object?> observer;
}

final class MutationObserverOptionsUpdatedEvent extends MutationCacheEvent {
  const MutationObserverOptionsUpdatedEvent(this.mutation, this.observer);
  @override
  final AnyMutation? mutation;
  final MutationObserver<Object?, Object?, Object?> observer;
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

class MutationCache extends Subscribable<MutationCacheEvent> {
  MutationCache({this.config = const MutationCacheConfig()});

  final MutationCacheConfig config;
  final Set<AnyMutation> _mutations = {};
  final Map<String, List<AnyMutation>> _scopes = {};
  int _mutationId = 0;

  Mutation<TData, TVariables, TContext> build<TData, TVariables, TContext>(
    QueryClient client,
    MutationOptions<TData, TVariables, TContext> options, [
    MutationState<TData, TVariables, TContext>? state,
  ]) {
    final mutation = Mutation<TData, TVariables, TContext>._(
      mutationCache: this,
      mutationId: ++_mutationId,
      options: client.defaultMutationOptions(options),
      state: state,
    );
    add(mutation);
    return mutation;
  }

  void add(AnyMutation mutation) {
    _mutations.add(mutation);
    final scope = mutation.options.scope?.id;
    if (scope != null) {
      (_scopes[scope] ??= []).add(mutation);
    }
    notify(MutationAddedEvent(mutation));
  }

  void remove(AnyMutation mutation) {
    mutation.destroy();
    if (_mutations.remove(mutation)) {
      final scope = mutation.options.scope?.id;
      if (scope != null) {
        final scoped = _scopes[scope];
        scoped?.remove(mutation);
        if (scoped != null && scoped.isEmpty) _scopes.remove(scope);
      }
    }
    notify(MutationRemovedEvent(mutation));
  }

  /// Whether [mutation] may run now. In a scope, only the first pending
  /// mutation runs.
  bool canRun(AnyMutation mutation) {
    final scope = mutation.options.scope?.id;
    if (scope == null) return true;
    final firstPending = _scopes[scope]
        ?.firstWhereOrNull((m) => m.state.status == MutationStatus.pending);
    return firstPending == null || identical(firstPending, mutation);
  }

  /// Starts the next paused mutation in the scope of [mutation]. Its result
  /// and errors go to whoever started it, so they are not reported here.
  Future<void> runNext(AnyMutation mutation) {
    final scope = mutation.options.scope?.id;
    if (scope == null) return Future.value();
    final next = _scopes[scope]
        ?.firstWhereOrNull((m) => !identical(m, mutation) && m.state.isPaused);
    if (next == null) return Future.value();
    return next.resume().then<void>((_) {}, onError: (Object _) {});
  }

  void clear() {
    notifyManager.batch(() {
      for (final mutation in _mutations.toList()) {
        mutation.destroy();
        notify(MutationRemovedEvent(mutation));
      }
      _mutations.clear();
      _scopes.clear();
    });
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

  void notify(MutationCacheEvent event) {
    notifyManager.batch(() {
      for (final listener in listeners.toList()) {
        listener(event);
      }
    });
  }

  /// Resumes every paused mutation.
  Future<void> resumePausedMutations() {
    final paused = getAll().where((m) => m.state.isPaused).toList();
    return notifyManager.batch(() {
      return Future.wait(
        paused.map((m) => m.resume().then<void>((_) {}, onError: (_) {})),
      );
    });
  }
}
