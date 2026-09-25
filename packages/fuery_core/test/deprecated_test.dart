// The names 1.3 and 1.5 replaced keep working until the next major removes
// them.
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

  test('FocusManager names FueryFocusManager', () {
    final FocusManager manager = FocusManager();
    expect(manager, isA<FueryFocusManager>());

    final FocusManager shared = focusManager;
    expect(shared, same(focusManager));
  });

  fakeTest('the page param typedefs still fit InfiniteQuery', (async) {
    // A helper that an app typed with the old names.
    InfiniteQuery<int, int> pages({
      required GetNextPageParam<int, int> next,
      GetPreviousPageParam<int, int>? previous,
    }) {
      return InfiniteQuery(
        queryKey: ['pages'],
        queryFn: (context) async => context.pageParam,
        initialPageParam: 1,
        getNextPageParam: next,
        getPreviousPageParam: previous,
      );
    }

    final observer = pages(next: (data) => null, previous: (data) => null)
        .observe(client: client)
      ..subscribe((_) {});
    async.flushMicrotasks();

    expect(observer.result.pages, [1]);
    expect(observer.result.hasNextPage, isFalse);
    expect(observer.result.hasPreviousPage, isFalse);
  });
}
