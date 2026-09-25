---
title: Setting up the client
description: Configure the Flutter QueryClient once in main, with defaults, failure reporting, and a client per subtree when needed.
---

One `QueryClient` sets the defaults, reports the failures, and catches the callback errors of the whole app. Configure it once, in `main`, before anything creates an [observer](../../how-the-cache-works/#observers). Every constructor option is listed in the [QueryClient reference](../../reference/query-client/#constructor-options).

## Creating the client

`Fuery.client` is the client that widgets use without a `FueryProvider`, and that `observe()` uses without `client:`. Fuery creates it on first use, so an app that configures nothing still works.

To configure it, assign a new client in `main`:

```dart
void main() {
  Fuery.client = QueryClient(
    defaultOptions: const DefaultOptions(
      queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    ),
  );
  runApp(const App());
}
```

- Assigning `Fuery.client` mounts the new client and unmounts the previous one.
- A mounted client refetches on focus and on reconnect, and resumes paused mutations.
- Assign it before anything creates an observer. An observer keeps the client it was created with.
- Register defaults before observers exist too. An observer applies the defaults when it receives its options, not afterwards.

## Setting defaults

Set defaults for every query and mutation of the client, or for a key prefix:

```dart
Fuery.client = QueryClient(
  defaultOptions: const DefaultOptions(
    queries: QueryDefaults(staleTime: Duration(seconds: 30)),
    mutations: MutationDefaults(retry: RetryPolicy.count(2)),
  ),
);

Fuery.client.setQueryDefaults(
  ['settings'],
  const QueryDefaults(staleTime: infiniteDuration),
);

Fuery.client.setMutationDefaults(
  ['todos'],
  const MutationDefaults(networkMode: NetworkMode.offlineFirst),
);
```

- Options set on the query or mutation win over per-key defaults.
- Per-key defaults win over the client's `defaultOptions`.
- A mutation gets per-key defaults only when it has a `mutationKey`.
- `getQueryDefaults(['settings'])` and `getMutationDefaults(['todos'])` return what a key resolves to, merged from every matching prefix.

The fields of `QueryDefaults` and `MutationDefaults` are listed in [Defaults](../../reference/query-client/#defaults).

## Reporting every failure in one place

Give the caches a config to run a callback for every query and every mutation, for example to report failures to a crash or logging service:

```dart
Fuery.client = QueryClient(
  queryCache: QueryCache(
    config: QueryCacheConfig(
      onError: (error, query) => reportError(error, query.queryKey),
    ),
  ),
  mutationCache: MutationCache(
    config: MutationCacheConfig(
      onError: (error, variables, context, mutation) =>
          reportError(error, mutation.options.mutationKey),
    ),
  ),
);
```

- A cache keeps its config for its whole life, so pass the config when you construct the client.
- `QueryCacheConfig` callbacks run after a fetch. A cancelled fetch isn't a failure and reaches none of them.
- `MutationCacheConfig` callbacks run before the [callbacks of the mutation itself](../mutations/#callbacks), and Fuery awaits a future they return.
- A mutation arrives as an `AnyCachedMutation`, whose `data`, `variables`, and `context` are `Object?`. Tell mutations apart by `mutation.options.mutationKey` or `mutation.options.meta`.

Every callback and when it runs is listed in [Cache callbacks](../../reference/query-client/#cache-callbacks).

## Catching errors that callbacks throw

`onUncaughtError` receives the errors that no caller can catch, so you decide how to record them:

- An error thrown by a `QueryCacheConfig` or `MutateOptions` callback.
- An error thrown by `onError` or `onSettled` after a mutation failed, from the mutation or from its `MutationCacheConfig`.
- An error thrown by `refetchWhile` or `placeholderData` while Fuery updates an observer after its query changed.
- An error thrown by a listener: the `listener` of a listener widget, a consumer, or a hook, or a function passed to a slot's `listen` or `subscribeToRuns`.
- A mistake Fuery finds while running, such as a `getNextPageParam` that returns a param of the wrong type, or a persisted `mutationKey` that can't be stored.

```dart
Fuery.client = QueryClient(
  onUncaughtError: (error, stackTrace) => reportError(error, stackTrace),
);
```

- The query or mutation goes on as if the callback hadn't thrown.
- Fuery reports each mistake once per client, not every time the code runs.
- When `onUncaughtError` throws, its error and the error it received both go to the current zone.

Without `onUncaughtError`, these errors go to the current zone, and Flutter passes them to `PlatformDispatcher.onError`. A crash reporter that records everything there as fatal then counts them as crashes, although the app keeps running.

The other callbacks of a `Mutation` and a `MutationCacheConfig` are part of the mutation. An error thrown by `onMutate`, or by `onSuccess` or `onSettled` after a success, fails the mutation and reaches its `onError`.

## Which client a query uses

A `Query` holds no client, so one definition works with every client. Fuery picks the client where the query is used:

- A widget or hook that gets a definition uses the client of the nearest `FueryProvider`, or `Fuery.client` without one. It follows a provider whose client is replaced.
- `observe()` uses the client you pass as `client:`, or `Fuery.client` at that moment. The observer keeps that client for its whole life, and `observer.client` returns it.
- A widget or hook that gets an observer uses the observer's client. In debug builds, it prints a warning when that isn't its own client. See [A screen reads another client's cache](../../troubleshooting/#a-screen-reads-another-clients-cache).
- Query functions, `placeholderData`, and mutation callbacks receive the client that runs them.

Queries can therefore be top-level values. Widget tests that each get a fresh client, through `Fuery.client` or a `FueryProvider`, need nothing else.

## Giving a subtree its own client

Wrap part of the app in `FueryProvider` to run it on another client, for example in a widget test. Keep the client in a `State` field, so the subtree keeps one client while it is mounted:

```dart
class _SettingsPageState extends State<SettingsPage> {
  final client = QueryClient();

  @override
  Widget build(BuildContext context) {
    return FueryProvider(client: client, child: const SettingsView());
  }
}
```

- Create the client once: in `main`, in a `State` field, or in a test's `setUp`.
- Don't create it in `build`. A `QueryClient` created there is a new, empty cache on every rebuild and every hot reload, so the widgets below go back to loading and fetch again.
- `FueryProvider` mounts the client and unmounts it when the provider goes away, so the `State` needs no `dispose`.

Widgets below the provider use its client. `context.queryClient` returns it, or `Fuery.client` when there is no provider. Pass it to `observe` for an observer of your own:

```dart
late final todos = todosQuery.observe(client: context.queryClient);
```

An [adapter](../adapters/) for another state library reads the client with `FueryProvider.of(context, listen: true)`, which rebuilds when the provider's client is replaced.

## In the example app

The example assigns `Fuery.client` in [`main`](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/main.dart), with a storage, and restores stored mutations before `runApp`. Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
