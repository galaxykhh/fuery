# Benchmarks

Scenarios 1, 2, and 4 of the [`fuery` widget benchmarks](../../fuery/benchmark/README.md) with hooks, and the `fuery` widgets next to them in the same run for comparison.

```bash
cd packages/fuery_hooks
flutter test benchmark/
```

Each scenario prints lines that start with its number, such as `S6.2`. The first line records the Dart version and mode. A full run takes about two minutes on an Apple M2 Pro. `flutter test` alone runs only `test/`, and CI analyzes these files but doesn't run them.

| | What happens | Checked with `expect` |
|---|---|---|
| S6.1 | A parent rebuilds 1,000 times a `HookWidget` that calls `useQuery(postQuery(id))`, and the same with a shared observer | one build per rebuild, one fetch |
| S6.2 | A `ListView` of `HookWidget`s, each calling `useQuery(rowQuery(i))` with data set, lazy and with every item mounted; `setData` changes one item | only that item builds, none for an unmounted item, no fetch |
| S6.4 | `useQueries` over 500 queries, with the list of definitions built in `build` and kept with `useMemoized` on the ids: one changes, the parent rebuilds, the list is reordered | one build each, every observer kept, no fetch |

The times come from `flutter test`, which runs Dart in JIT mode with asserts on, with semantics off. Compare them with each other, within one run. [Reading the times](../../fuery/benchmark/README.md#reading-the-times) explains the statistics and the scaling lines.
