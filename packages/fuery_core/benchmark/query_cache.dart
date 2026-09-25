// A QueryClient holding N queries under four key prefixes: writes, reads,
// lookups, and the prefix operations that scan the whole cache.
import 'package:fuery_core/fuery_core.dart';

import 'src/harness.dart';

typedef Item = Map<String, Object?>;

const prefixes = ['todos', 'posts', 'users', 'comments'];

Item item(int id, [int version = 0]) =>
    {'id': id, 'title': 'Item $id', 'version': version};

Query<Item> itemQuery(int id) => Query(
      queryKey: [prefixes[id % prefixes.length], id],
      // A fresh copy, as a decoded response would be.
      queryFn: (_) async => item(id),
      staleTime: infiniteDuration,
    );

Future<void> main(List<String> args) async {
  final bench = Bench('query_cache', args);

  for (final n in [100, 1000, 10000]) {
    final queries = [for (var id = 0; id < n; id++) itemQuery(id)];
    final items = [for (var id = 0; id < n; id++) item(id)];
    final todos = [
      for (var id = 0; id < n; id += prefixes.length) queries[id],
    ];
    void fill(QueryClient client, Iterable<Query<Item>> which) {
      for (final query in which) {
        client.setData(query, items[query.queryKey[1]! as int]);
      }
    }

    bench.section('N=$n queries, ${todos.length} under [\'todos\']');

    bench.each(
      'setData on N new keys (fill the cache)',
      QueryClient.new,
      (client) => fill(client, queries),
      teardown: (client) => client.clear(),
      n: n,
      per: n,
      unit: 'query',
    );

    final client = QueryClient();
    fill(client, queries);
    final middle = queries[n ~/ 2];
    final middleId = n ~/ 2;
    final versions = [item(middleId, 1), item(middleId, 2)];

    bench.sync('setData on one key', (count) {
      for (var i = 0; i < count; i++) {
        client.setData(middle, versions[i & 1]);
      }
    }, n: n);

    bench.sync('getData', (count) {
      Object? data;
      for (var i = 0; i < count; i++) {
        data = client.getData(middle);
      }
      sink = data;
    }, n: n);

    bench.sync('queryCache.find, exact key', (count) {
      Object? found;
      for (var i = 0; i < count; i++) {
        found = client.queryCache.find(QueryFilters(
          queryKey: [prefixes[middleId % prefixes.length], middleId],
          exact: true,
        ));
      }
      sink = found;
    }, n: n);

    bench.sync("queryCache.findAll, prefix ['todos']", (count) {
      var found = 0;
      for (var i = 0; i < count; i++) {
        found += client.queryCache
            .findAll(const QueryFilters(queryKey: ['todos']))
            .length;
      }
      sink = found;
    }, n: n, per: n, unit: 'query scanned');

    bench.each(
      "invalidateQueries(['todos'], refetchType: none)",
      // Writing the data again clears isInvalidated, so each sample
      // invalidates every matching query.
      () => fill(client, todos),
      (_) => client.invalidateQueries(
        queryKey: ['todos'],
        refetchType: RefetchType.none,
      ),
      n: n,
      per: todos.length,
      unit: 'invalidated',
    );

    bench.each(
      "removeQueries(['todos'])",
      () => fill(client, todos),
      (_) => client.removeQueries(queryKey: ['todos']),
      n: n,
      per: todos.length,
      unit: 'removed',
    );
    client.clear();

    // Every query under ['todos'] has a subscribed observer, as a mounted
    // widget would, and refetches with a query function that completes at
    // once, so the time is Fuery's own.
    final active = QueryClient();
    fill(active, queries);
    final unsubscribes = [
      for (final query in todos)
        query.observe(client: active).subscribe((_) {}),
    ];
    await bench.eachAsync(
      "invalidateQueries(['todos']), refetching active",
      () {},
      (_) => active.invalidateQueries(queryKey: ['todos']),
      n: n,
      per: todos.length,
      unit: 'refetch',
    );
    for (final unsubscribe in unsubscribes) {
      unsubscribe();
    }
    active.clear();
  }
}
