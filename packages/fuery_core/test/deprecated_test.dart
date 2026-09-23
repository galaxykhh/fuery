// The names replaced in 1.2.0 keep working until the next major version.
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

  fakeTest('use and noParam create the same observers', (async) {
    final todos = Query.use(
      queryKey: ['todos'],
      queryFn: (_) async => 'todos',
      client: client,
    );
    final pages = InfiniteQuery.use(
      queryKey: ['pages'],
      queryFn: (context) async => context.pageParam,
      initialPageParam: 1,
      getNextPageParam: (_) => null,
      client: client,
    );
    final add = Mutation.use(
      mutationFn: (int x) async => x + 1,
      client: client,
    );
    final NoParamMutationObserver<int, Object?> refresh = Mutation.noParam(
      mutationFn: () async => 1,
      client: client,
    );
    todos.subscribe((_) {});
    pages.subscribe((_) {});
    add.mutate(1);
    refresh.mutate();
    async.flushMicrotasks();

    expect(todos.result.data, 'todos');
    expect(pages.result.pages, [1]);
    expect(add.result.data, 2);
    expect(refresh.result.data, 1);
  });
}
