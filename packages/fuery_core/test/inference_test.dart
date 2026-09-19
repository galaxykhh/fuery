// These tests pin down that the public entry points need no explicit type
// arguments. If inference regresses, this file stops compiling.
import 'package:fuery_core/fuery_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class Todo {
  const Todo(this.title);
  final String title;
}

class PostPage {
  const PostPage(this.titles, {required this.hasMore});
  final List<String> titles;
  final bool hasMore;
}

class CursorPage {
  const CursorPage(this.items, this.nextCursor);
  final List<String> items;
  final String? nextCursor;
}

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

  fakeTest('Query.use infers the data type', (async) {
    final todos = Query.use(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
      client: client,
    );
    todos.subscribe((_) {});
    async.flushMicrotasks();

    final QueryObserver<List<Todo>> typed = todos;
    expect(typed.result.data!.single.title, 'a');
  });

  fakeTest('InfiniteQuery.use infers page and param types', (async) {
    final posts = InfiniteQuery.use(
      queryKey: ['posts'],
      queryFn: (context) async => PostPage(
        ['post ${context.pageParam}'],
        hasMore: context.pageParam < 2,
      ),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
      client: client,
    );
    posts.subscribe((_) {});
    async.flushMicrotasks();
    posts.fetchNextPage();
    async.flushMicrotasks();

    final InfiniteQueryObserver<PostPage, int> typed = posts;
    expect(typed.result.pages.expand((p) => p.titles), ['post 1', 'post 2']);
    expect(typed.result.hasNextPage, isFalse);
  });

  fakeTest('InfiniteQuery.use infers a nullable cursor', (async) {
    final cursors = <String?>[];
    final items = InfiniteQuery.use(
      queryKey: ['items'],
      queryFn: (context) async {
        cursors.add(context.pageParam);
        return context.pageParam == null
            ? const CursorPage(['a'], 'next')
            : const CursorPage(['b'], null);
      },
      initialPageParam: null as String?,
      getNextPageParam: (data) => data.lastPage.nextCursor,
      client: client,
    );
    items.subscribe((_) {});
    async.flushMicrotasks();
    items.fetchNextPage();
    async.flushMicrotasks();

    final InfiniteQueryObserver<CursorPage, String?> typed = items;
    expect(cursors, [null, 'next']);
    expect(typed.result.hasNextPage, isFalse);
  });

  fakeTest('Mutation.use infers data, variables, and context', (async) {
    client.setQueryData(['todos'], [const Todo('a')]);

    final addTodo = Mutation.use(
      mutationFn: (String title) async => Todo(title),
      onMutate: (title) => client.getQueryData<List<Todo>>(['todos']),
      onError: (error, title, previous) {
        client.setQueryData(['todos'], previous!);
      },
      client: client,
    );
    addTodo.mutate('b');
    async.flushMicrotasks();

    final MutationObserver<Todo, String, List<Todo>> typed = addTodo;
    expect(typed.result.data!.title, 'b');
  });

  fakeTest('Mutation.noParam infers the data type', (async) {
    final refresh = Mutation.noParam(
      mutationFn: () async => 42,
      client: client,
    );
    refresh.mutate();
    async.flushMicrotasks();

    final NoParamMutationObserver<int, Object?> typed = refresh;
    expect(typed.result.data, 42);
  });
}
