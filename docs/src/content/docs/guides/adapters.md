---
title: Building an adapter
description: "Render Fuery queries and mutations in your own widgets or another state library, with the slots of fuery_core."
---

An adapter renders Fuery's queries and mutations in your own widgets or another state library, with only the public API of `fuery_core`. The widgets of `fuery` and the hooks of [`fuery_hooks`](../hooks/) are adapters built this way, so yours can do everything they do.

An adapter keeps one **slot** per rendered query or mutation. A slot, an `ObserverSlot`, holds the [observer](../../how-the-cache-works/#observers) for a source that can change on every render.

## Rendering a query with a slot

Call `update` on every render, read `result`, and subscribe to render again. This hook, written with `flutter_hooks` alone, holds the whole contract:

```dart
QueryResult<TData> useMyQuery<TData extends Object>(QuerySource<TData> query) {
  final client = FueryProvider.of(useContext(), listen: true);
  final slot = useMemoized(() => QuerySlot(query, client));
  final changes = useState(0);
  useEffect(() {
    var active = true;
    final unsubscribe = slot.subscribe(notifyManager.batchCalls((_) {
      if (active) changes.value++;
    }));
    return () {
      active = false;
      unsubscribe();
      slot.dispose();
    };
  }, [slot]);
  slot.update(query, client);
  return slot.result;
}
```

## The slot contract

`QuerySlot` takes a `QuerySource`: a `Query` or a `QueryObserver`. Every slot has these members:

| Member | What it does |
|---|---|
| `update(source, client)` | Call it on every render. For a definition, the slot owns an observer and updates its options. For an observer, the slot uses it as it is. A new client gets a new observer. |
| `result` | The result to render, current as soon as `update` returns. |
| `subscribe(listener)` | Calls `listener` with every later result, and stays subscribed when `update` moves the slot to another observer. Returns a function that removes it. |
| `listen((previous, current) {...})` | Calls its listener after each later change, for side effects such as navigation. Returns a function that stops it. |
| `dispose()` | Removes every listener. If the slot created the observer, it destroys a query observer or resets a mutation observer. The reset drops the callbacks of the latest `mutate` call. |
| `observer` | The observer the slot renders from now. |

`listen` holds the rules of the listener widgets, `useOnQueryChange`, and `useOnMutationChange`, which use it:

- It runs in a microtask, never during a render.
- It isn't called for the `result` it starts from, or for a result equal to the previous one.
- After `update` moves the slot to another observer, it starts over from the new `result` without a call.
- It subscribes, so a query fetches as it would for a mounted widget.
- Fuery reports a listener that throws to the client's `onUncaughtError`.

## Batching listener calls

`subscribe` calls its listener synchronously, sometimes while another widget builds: a widget that mounts can start a fetch. In a framework that can't update during a render, do what the hook above does:

1. Wrap the listener in `notifyManager.batchCalls`, so changes arrive in a microtask.
2. Ignore the changes that arrive after dispose.

## Other slots

| Slot | Source | Result |
|---|---|---|
| `InfiniteQuerySlot` | `InfiniteQuerySource`: an `InfiniteQuery` or an `InfiniteQueryObserver` | `InfiniteQueryResult` |
| `MutationSlot` | `MutationSource`: a `Mutation` or a `MutationObserver` | `MutationResult` |
| `QueriesSlot` | A list of `QuerySource`s of one data type | A list of `QueryResult`s, in order |

`QueriesSlot` serves a hook like `useQueries`. It calls `subscribe` listeners in a microtask, once for the changes that arrive together, so they need no `batchCalls`. Each query keeps its observer while its key stays in the list, even when the list is reordered. Its `observer` is the list of observers, a new list only when one is added, removed, replaced, or moved.

## Every run of a mutation

`MutationStateSlot` gives the state of every run of a mutation, wherever it started. The MutationState widgets and `useMutationState` use it.

- It takes a `MutationStateSource`: a `Mutation` with a `mutationKey`, or `MutationFilters`.
- It only reads the cache. Its `observer` is the client's `MutationCache`.
- Its `result` lists the runs' states, oldest first. It stays the same list until a matching run is added, removed, or changes.
- It calls `subscribe` listeners in a microtask, once per batch, and only when the list changed.

`subscribeToRuns((previous, current) {...})` calls its listener for each later change of each matching run, with that run's previous state: idle for a run that started later. It never reports the states runs had when it was added, or a run that the cache removes. `MutationStateListener` and `useOnMutationStateChange` use it.

## Listening from a result alone

A result carries the observer that reported it, as `result.observer`. An adapter given only a result listens through a slot of its own over that observer, as `useOnQueryChange` and `useOnMutationChange` do:

```dart
void Function() listenTo<TData extends Object>(
  QueryResult<TData> result,
  void Function(QueryResult<TData> previous, QueryResult<TData> current)
      listener,
) {
  final observer = result.observer;
  if (observer == null) return () {};
  final slot = QuerySlot(observer, observer.client);
  slot.listen(listener);
  return slot.dispose;
}
```

- The slot uses the observer as it is, and never destroys it.
- `observer` is null for a `QueryResult` built with its constructor.
- An `InfiniteQueryResult` has an `InfiniteQueryObserver`, which an `InfiniteQuerySlot` takes.

## Reading the client

In Flutter, `FueryProvider.of(context, listen: true)` returns the nearest provided client, or `Fuery.client`. The caller rebuilds when the provided client is replaced, and the next `update` moves the slot to it. Outside Flutter, pass the client your app uses.

## In the Fuery sources

- [`adapter_test.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_core/test/adapter_test.dart) renders queries through slots without Flutter.
- [`hooks.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery_hooks/lib/src/hooks.dart) builds every hook of `fuery_hooks` on a slot.
- [`result_subscriber.dart`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/lib/src/result_subscriber.dart) builds the widgets of `fuery` on a slot.
