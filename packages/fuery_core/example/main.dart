// ignore_for_file: avoid_print

import 'package:fuery_core/fuery_core.dart';

class Page {
  const Page({required this.items, this.nextCursor});

  final List<String> items;
  final int? nextCursor;
}

class NameRepository {
  Future<String> getOne(int id) async => 'Name $id';

  Future<Page> getPage(int page) async {
    return Page(
      items: [for (var i = 1; i <= 3; i++) 'Name $page-$i'],
      nextCursor: page < 3 ? page + 1 : null,
    );
  }

  Future<String> create(String name) async => name;

  Future<void> removeAll() async {}
}

final repository = NameRepository();

Future<void> main() async {
  // A query fetches when its observer gets the first listener.
  final name = Query.use(
    queryKey: ['names', 1],
    queryFn: (_) => repository.getOne(1),
  );
  final subscription = name.stream.listen((result) {
    print('name: ${result.status.name} ${result.data}');
  });

  // An infinite query loads pages on demand.
  final names = InfiniteQuery.use(
    queryKey: ['names', 'list'],
    queryFn: (context) => repository.getPage(context.pageParam),
    initialPageParam: 1,
    getNextPageParam: (data) => data.lastPage.nextCursor,
  );
  names.subscribe((_) {});
  await Future<void>.delayed(Duration.zero);
  while (names.result.hasNextPage) {
    await names.fetchNextPage();
  }
  print('pages: ${names.result.pages.length}');

  // A mutation invalidates the queries it affects.
  final createName = Mutation.use(
    mutationFn: (String name) => repository.create(name),
    onSuccess: (data, name, _) async {
      print('$data created');
      await Fuery.instance.invalidateQueries(queryKey: ['names']);
    },
  );
  await createName.mutateAsync('New name');

  final removeAll = Mutation.noParam(
    mutationFn: () => repository.removeAll(),
    onSuccess: (_, __) => print('all names removed'),
  );
  removeAll.mutate();

  await subscription.cancel();

  // Stop garbage collection timers so the program can exit.
  Fuery.instance.clear();
}
