// The names 1.3 replaced keep working until they are removed.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late QueryClient client;

  setUp(() {
    resetManagers();
    client = QueryClient()..mount();
  });

  tearDown(() {
    client.unmount();
    client.clear();
  });

  fakeTest('the options names build the definitions', (async) {
    final QueryOptions<String> todos =
        QueryOptions(queryKey: ['todos'], queryFn: (_) async => 'todos');
    final InfiniteQueryOptions<int, int> pages = infiniteQueryOptions(
      queryKey: ['pages'],
      queryFn: (context) async => context.pageParam,
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    );
    final MutationOptions<int, int, Object?> add =
        MutationOptions(mutationFn: (int x) async => x + 1);
    final AnyMutationOptions any = add;

    final todosObserver = todos.observe(client: client)..subscribe((_) {});
    final pagesObserver = pages.observe(client: client)..subscribe((_) {});
    final addObserver = add.observe(client: client)..mutate(1);
    async.flushMicrotasks();

    expect(todosObserver.result.data, 'todos');
    expect(pagesObserver.result.pages, [1]);
    expect(addObserver.result.data, 2);
    expect(any, isA<Mutation<int, int, Object?>>());
  });
}
