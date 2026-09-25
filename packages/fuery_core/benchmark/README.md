# fuery_core benchmarks

Micro-benchmarks of the core, one file per area. They use plain `Stopwatch`es and no extra packages. Each case warms up, then prints the median time of 21 samples with the interquartile range and the fastest and slowest sample. Where a case does many things at once (listeners, queries, items), the last column divides the median by their number.

| File | Measures |
| --- | --- |
| `hash_key.dart` | `hashKey` for typical keys |
| `query_cache.dart` | a client with N queries: `setData`, `getData`, `find`, `findAll` by prefix, `invalidateQueries`, `removeQueries` |
| `notifications.dart` | N observers across M queries: mounting them, and a batched write until the last listener ran |
| `observer_rebuild.dart` | a widget's build without Flutter: `setOptions` with a rebuilt definition, `getOptimisticResult`, `QuerySlot.update`, and `MutationObserver.setOptions` |
| `structural_sharing.dart` | `replaceEqualDeep` and refetches of a list of N JSON maps, equal or with changes |
| `queries_slot.dart` | `QueriesSlot` with N queries: create, update, reorder, key change, and the push after one query changes |
| `mutation_state_slot.dart` | `MutationStateSlot` over many settled runs: reading the result, and the flushes after one run settles |
| `memory.dart` | RSS growth per 10,000 cached queries (`--variant=cached`, `no-gc-timer`, `observed`, or `data-only`) |

## Running

From `packages/fuery_core`, on the VM (JIT):

```bash
dart run benchmark/query_cache.dart
```

Compiled ahead of time (AOT), as a release app runs:

```bash
dart compile exe benchmark/query_cache.dart -o /tmp/query_cache
/tmp/query_cache
```

`--quick` takes fewer and shorter samples, to check that a file runs. `--tsv` prints tab-separated rows instead of a table. Run the memory variants each in a process of its own, since memory the process freed stays in its RSS:

```bash
dart run benchmark/memory.dart --variant=cached
dart run benchmark/memory.dart --variant=data-only
```

Close other programs while measuring, compare runs on the same machine only, and report whether they ran JIT or AOT (each file prints it).
