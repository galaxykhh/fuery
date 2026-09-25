# Benchmarks

Widget benchmarks for `fuery`: how many builds, fetches, and cache notifications a change causes, and how the time of a change grows with the number of queries, items, or runs.

```bash
cd packages/fuery
flutter test benchmark/
```

Each scenario prints lines that start with its number, such as `S2`. The first line records the Dart version and mode. A full run takes about two minutes on an Apple M2 Pro. `flutter test` alone runs only `test/`, and CI analyzes these files but doesn't run them.

## Scenarios

| | What happens | Checked with `expect` |
|---|---|---|
| S1 | A parent rebuilds 1,000 times a `StatelessWidget` that builds `QueryBuilder(query: postQuery(id))` in `build`, and the same with `QuerySelector` and with a shared observer | one builder call per rebuild, one fetch, no cache notification |
| S2 | A `ListView` of `QueryBuilder`s, each over `rowQuery(i)` with data set, lazy and with every item mounted; `setData` changes one item | only that item's builder runs, none for an unmounted item, no fetch |
| S3 | `QuerySelector` over a list query; a field it doesn't select changes | no rebuild; a change it selects rebuilds once |
| S4 | `QueriesBuilder` over 500 queries: one changes, the parent rebuilds, the list is reordered | one build each, every observer kept, no fetch |
| S5 | `MutationStateSelector` with 1,000 settled runs of other mutations and 10 matching; a matching run and an unrelated run start, settle, and are collected | rebuilds only when the selected value changes, never for the unrelated run |
| S7 | `FueryDevtools(enabled: false)` in `MaterialApp.builder`: the app rebuilds, the keyboard opens and closes, a query changes | its child builds no more than without it, and no panel is mounted |

S6, the hooks, is in [`packages/fuery_hooks/benchmark`](../../fuery_hooks/benchmark/README.md).

The scaling tests repeat S2 to S5 at several sizes and print `Time xA for ... count xB`: A near B is linear, A near 1 is constant, and A well above B grows faster than linear.

## Reading the times

- `flutter test` runs Dart in JIT mode with asserts on. Compare the times with each other, within one run, and not with a release build of an app.
- Each timing warms up, then runs several rounds, and prints the median of every sample with the IQR, the min and max, and the range of the round medians. Variants compared with each other (S1, S7) alternate in three passes, so the order they run in favors none of them.
- The baselines without Fuery, a plain widget and `ValueListenableBuilder`, show what Flutter itself costs in the same test.
- Semantics are off, as in an app that no accessibility service reads. With them on, the default of `testWidgets`, a frame with 10,000 mounted items spends most of its time updating Flutter's semantics tree.
- Fuery delivers a change to widgets in a microtask, so the benchmarks pump with `Duration.zero` to deliver it and draw the frame in one pump. S2 times Fuery's part, from `setData` to the item's `setState`, apart from the frame.
