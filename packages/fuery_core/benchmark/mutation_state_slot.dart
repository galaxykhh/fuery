// MutationStateSlot over a mutation cache with many settled runs under
// other keys and 10 under the slot's key: reading the result, and the
// flushes after one run changes, with 0, 1, and 10 slots listening.
import 'dart:async';

import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

typedef AddTodo = Mutation<int, int, Object?>;

const addTodoKey = ['todos', 'add'];

final AddTodo addTodo = Mutation(
  mutationKey: addTodoKey,
  mutationFn: (value) async => value,
  gcTime: infiniteDuration,
);

Future<void> main(List<String> args) async {
  final bench = Bench('mutation_state_slot', args);

  for (final others in [100, 1000, 10000]) {
    final runs = others + 10;
    bench.section('$others settled runs under other keys, 10 under '
        '$addTodoKey');
    final client = QueryClient();
    await Future.wait([
      for (var i = 0; i < others; i++)
        AddTodo(
          mutationKey: ['other', i],
          mutationFn: (value) async => value,
          gcTime: infiniteDuration,
        ).observe(client: client).mutateAsync(i),
      for (var i = 0; i < 10; i++)
        addTodo.observe(client: client).mutateAsync(i),
    ]);

    final byDefinition = MutationStateSlot(addTodo, client);
    final byPrefix = MutationStateSlot(
      const MutationFilters(mutationKey: ['todos']),
      client,
    );
    if (byDefinition.result.length != 10 || byPrefix.result.length != 10) {
      throw StateError('Expected 10 matching runs');
    }

    bench.sync('result, source: Mutation (exact key)', (count) {
      Object? result;
      for (var i = 0; i < count; i++) {
        result = byDefinition.result;
      }
      sink = result;
    }, n: runs, per: runs, unit: 'run');

    bench.sync("result, source: MutationFilters(['todos'])", (count) {
      Object? result;
      for (var i = 0; i < count; i++) {
        result = byPrefix.result;
      }
      sink = result;
    }, n: runs, per: runs, unit: 'run');

    // One run settles: a run started in the setup waits on a completer,
    // and the time runs from completing it until every microtask is done,
    // which includes each slot's flush. With 0 slots it is the mutation
    // alone. The run's gcTime is zero, so it leaves the cache after the
    // time stops, and the cache keeps its size.
    for (final (label, key) in [
      ('a run under the slots\' key settles', addTodoKey),
      ('a run under another key settles', ['other', 'gated']),
    ]) {
      for (final (slots, runListeners) in [(0, 0), (1, 0), (10, 0), (1, 1)]) {
        final listening = [
          for (var i = 0; i < slots; i++) MutationStateSlot(addTodo, client),
        ];
        final stops = [
          for (final slot in listening) slot.subscribe((_) {}),
          for (final slot in listening.take(runListeners))
            slot.subscribeToRuns((_, __) {}),
        ];
        await pump();
        final slotsText = slots == 1 ? '1 slot' : '$slots slots';
        final name = runListeners == 0
            ? '$label, $slotsText'
            : '$label, $slotsText + subscribeToRuns';

        await bench.eachAsync(
          name,
          () async {
            final gate = Completer<int>();
            final gated = AddTodo(
              mutationKey: key,
              mutationFn: (_) => gate.future,
              gcTime: Duration.zero,
            );
            gated.observe(client: client).mutateAsync(1).ignore();
            await pump();
            return gate;
          },
          (gate) {
            gate.complete(1);
            return pump();
          },
          // Lets the finished run be collected, and the slots hear it.
          teardown: (_) => pump(),
          n: runs,
        );
        for (final stop in stops) {
          stop();
        }
        for (final slot in listening) {
          slot.dispose();
        }
      }
    }

    byDefinition.dispose();
    byPrefix.dispose();
    client.clear();
    await pump();
  }
}
