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

  fakeTest('refetchWhile gets the typed result', (async) {
    final todo = Query.use(
      queryKey: ['todo'],
      queryFn: (_) async => const Todo('done'),
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => state.data?.title != 'done',
      client: client,
    );
    final posts = InfiniteQuery.use(
      queryKey: ['posts'],
      queryFn: (context) async => const PostPage([], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => state.hasNextPage,
      client: client,
    );
    todo.subscribe((_) {});
    posts.subscribe((_) {});
    async.elapse(const Duration(seconds: 3));

    final QueryObserver<Todo> typedTodo = todo;
    final InfiniteQueryObserver<PostPage, int> typedPosts = posts;
    expect(typedTodo.result.data!.title, 'done');
    expect(typedPosts.result.pages, hasLength(1));
  });

  fakeTest('streamedQuery infers the chunk and data types', (async) {
    final answer = Query.use(
      queryKey: ['answer'],
      queryFn: streamedQuery(
        stream: (context) => Stream.fromIterable(['a', 'b']),
        initialValue: '',
        combine: (text, token) => text + token,
      ),
      client: client,
    );
    answer.subscribe((_) {});
    async.flushMicrotasks();

    final QueryObserver<String> typed = answer;
    expect(typed.result.data, 'ab');
  });

  fakeTest('persist codecs infer their data types', (async) {
    final storage = <String, String>{};
    final persisting = QueryClient(storage: _MapStorage(storage));
    final todos = Query.use(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
      persist: QueryPersist(
        toJson: (todos) => [for (final todo in todos) todo.title],
        fromJson: (json) => [for (final t in json! as List) Todo(t as String)],
      ),
      client: persisting,
    );
    final posts = InfiniteQuery.use(
      queryKey: ['posts'],
      queryFn: (context) async => const PostPage(['p'], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
      persist: InfiniteQueryPersist(
        pageToJson: (page) => page.titles,
        pageFromJson: (json) =>
            PostPage(List<String>.from(json! as List), hasMore: false),
      ),
      client: persisting,
    );
    final days = InfiniteQuery.use(
      queryKey: ['days'],
      queryFn: (context) async => 'day ${context.pageParam.day}',
      initialPageParam: DateTime.utc(2026, 9, 1),
      getNextPageParam: (data) => null,
      persist: InfiniteQueryPersist(
        pageToJson: (page) => page,
        pageFromJson: (json) => json! as String,
        paramToJson: (date) => date.toIso8601String(),
        paramFromJson: (json) => DateTime.parse(json! as String),
      ),
      client: persisting,
    );

    // Persisting doesn't widen the inferred data or page param types.
    final QueryObserver<List<Todo>> typedTodos = todos;
    final InfiniteQueryObserver<PostPage, int> typedPosts = posts;
    final InfiniteQueryObserver<String, DateTime> typedDays = days;
    typedTodos.subscribe((_) {});
    typedPosts.subscribe((_) {});
    typedDays.subscribe((_) {});
    async.flushMicrotasks();

    expect(storage, hasLength(3));
    persisting.clear();
  });

  fakeTest('watch infers the selected type', (async) {
    final values = <int>[];
    final Stream<int> fetching = client.watch((client) => client.isFetching());
    fetching.listen(values.add);
    async.flushMicrotasks();

    expect(values, [0]);
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

class _MapStorage implements QueryStorage {
  _MapStorage(this.entries);

  final Map<String, String> entries;

  @override
  String? read(String key) => entries[key];

  @override
  void write(String key, String value) => entries[key] = value;

  @override
  void delete(String key) => entries.remove(key);

  @override
  Map<String, String> readAll() => Map.of(entries);
}
