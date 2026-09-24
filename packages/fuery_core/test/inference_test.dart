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

  fakeTest('Query infers the data type', (async) {
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
    ).observe(client: client);
    todos.subscribe((_) {});
    async.flushMicrotasks();

    final QueryObserver<List<Todo>> typed = todos;
    expect(typed.result.data!.single.title, 'a');
  });

  fakeTest('placeholderData keeps the inferred data type', (async) {
    final posts = Query(
      queryKey: ['posts', 1],
      queryFn: (_) async => [const Todo('a')],
      placeholderData: (previous, client) => previous,
    ).observe(client: client);
    final QueryObserver<List<Todo>> typed = posts;

    // Where the type is known, keepPreviousData does the same.
    typed.setOptions(Query(
      queryKey: ['posts', 2],
      queryFn: (_) async => [const Todo('b')],
      placeholderData: keepPreviousData,
    ));
    typed.subscribe((_) {});
    async.flushMicrotasks();
    expect(typed.result.data!.single.title, 'b');
  });

  fakeTest('InfiniteQuery.observe infers page and param types', (async) {
    final posts = InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) async => PostPage(
        ['post ${context.pageParam}'],
        hasMore: context.pageParam < 2,
      ),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    ).observe(client: client);
    posts.subscribe((_) {});
    async.flushMicrotasks();
    posts.fetchNextPage();
    async.flushMicrotasks();

    final InfiniteQueryObserver<PostPage, int> typed = posts;
    expect(typed.result.pages.expand((p) => p.titles), ['post 1', 'post 2']);
    expect(typed.result.hasNextPage, isFalse);
  });

  fakeTest('InfiniteQuery.observe infers a nullable cursor', (async) {
    final cursors = <String?>[];
    final items = InfiniteQuery(
      queryKey: ['items'],
      queryFn: (context) async {
        cursors.add(context.pageParam);
        return context.pageParam == null
            ? const CursorPage(['a'], 'next')
            : const CursorPage(['b'], null);
      },
      initialPageParam: null as String?,
      getNextPageParam: (data) => data.lastPage.nextCursor,
    ).observe(client: client);
    items.subscribe((_) {});
    async.flushMicrotasks();
    items.fetchNextPage();
    async.flushMicrotasks();

    final InfiniteQueryObserver<CursorPage, String?> typed = items;
    expect(cursors, [null, 'next']);
    expect(typed.result.hasNextPage, isFalse);
  });

  fakeTest('refetchWhile gets the typed result', (async) {
    final todo = Query(
      queryKey: ['todo'],
      queryFn: (_) async => const Todo('done'),
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => state.data?.title != 'done',
    ).observe(client: client);
    final posts = InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) async => const PostPage([], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
      refetchInterval: const Duration(seconds: 1),
      refetchWhile: (state) => state.hasNextPage,
    ).observe(client: client);
    todo.subscribe((_) {});
    posts.subscribe((_) {});
    async.elapse(const Duration(seconds: 3));

    final QueryObserver<Todo> typedTodo = todo;
    final InfiniteQueryObserver<PostPage, int> typedPosts = posts;
    expect(typedTodo.result.data!.title, 'done');
    expect(typedPosts.result.pages, hasLength(1));
  });

  fakeTest('streamedQuery infers the chunk and data types', (async) {
    final answer = Query(
      queryKey: ['answer'],
      queryFn: streamedQuery(
        stream: (context) => Stream.fromIterable(['a', 'b']),
        initialValue: '',
        combine: (text, token) => text + token,
      ),
    ).observe(client: client);
    answer.subscribe((_) {});
    async.flushMicrotasks();

    final QueryObserver<String> typed = answer;
    expect(typed.result.data, 'ab');
  });

  fakeTest('persist codecs infer their data types', (async) {
    final storage = <String, String>{};
    final persisting = QueryClient(storage: _MapStorage(storage));
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
      persist: QueryPersist(
        toJson: (todos) => [for (final todo in todos) todo.title],
        fromJson: (json) => [for (final t in json! as List) Todo(t as String)],
      ),
    ).observe(client: persisting);
    final posts = InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) async => const PostPage(['p'], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
      persist: InfiniteQueryPersist(
        pageToJson: (page) => page.titles,
        pageFromJson: (json) =>
            PostPage(List<String>.from(json! as List), hasMore: false),
      ),
    ).observe(client: persisting);
    final days = InfiniteQuery(
      queryKey: ['days'],
      queryFn: (context) async => 'day ${context.pageParam.day}',
      initialPageParam: DateTime.utc(2026, 9, 1),
      getNextPageParam: (data) => null,
      persist: InfiniteQueryPersist(
        pageToJson: (page) => page,
        pageFromJson: (json) => json! as String,
        paramToJson: (date) => (date! as DateTime).toIso8601String(),
        paramFromJson: (json) => DateTime.parse(json! as String),
      ),
    ).observe(client: persisting);

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

  fakeTest('Mutation infers data, variables, and context', (async) {
    client.setQueryData(['todos'], [const Todo('a')]);

    final addTodo = Mutation(
      mutationFn: (String title) async => Todo(title),
      onMutate: (title, client) => client.getQueryData<List<Todo>>(['todos']),
      onError: (error, title, previous, client) {
        client.setQueryData(['todos'], previous!);
      },
    ).observe(client: client);
    addTodo.mutate('b');
    async.flushMicrotasks();

    final MutationObserver<Todo, String, List<Todo>> typed = addTodo;
    expect(typed.result.data!.title, 'b');
  });

  fakeTest('Mutation infers the variables of a persisted mutation', (async) {
    final addTodo = Mutation(
      mutationKey: const ['todos', 'add'],
      mutationFn: (String title) async => Todo(title),
      persist: MutationPersist(
        toJson: (title) => title,
        fromJson: (json) => json! as String,
      ),
    ).observe(client: client);

    final MutationObserver<Todo, String, Object?> typed = addTodo;
    expect(typed.options.persist, isNotNull);
  });

  fakeTest('NoVariablesMutation infers the data type', (async) {
    final refresh = NoVariablesMutation(
      mutationFn: () async => 42,
    ).observe(client: client);
    refresh.mutate();
    async.flushMicrotasks();

    final NoVariablesMutationObserver<int, Object?> typed = refresh;
    expect(typed.result.data, 42);
  });

  fakeTest('options infer their data type and observe it', (async) {
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
    );
    final QueryObserver<List<Todo>> observer = todos.observe(client: client);
    observer.subscribe((_) {});
    async.flushMicrotasks();

    expect(observer.result.data!.single.title, 'a');
  });

  fakeTest('infinite options observe with an infinite observer', (async) {
    final posts = InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) async =>
          PostPage(['${context.pageParam}'], hasMore: context.pageParam < 2),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    );
    final InfiniteQueryObserver<PostPage, int> observer =
        posts.observe(client: client);
    observer.subscribe((_) {});
    async.flushMicrotasks();
    observer.fetchNextPage();
    async.flushMicrotasks();

    expect(observer.result.pages, hasLength(2));
  });

  fakeTest('mutation options infer their types and observe them', (async) {
    final addTodo = Mutation(
      mutationFn: (String title) async => Todo(title),
    );
    final MutationObserver<Todo, String, Object?> observer =
        addTodo.observe(client: client);
    observer.mutate('a');
    async.flushMicrotasks();

    expect(observer.result.data!.title, 'a');
  });

  fakeTest('getData, setData, and updateData take the type from options',
      (async) {
    Query<Todo> todoOptions(int id) => Query(
          queryKey: ['todo', id],
          queryFn: (_) async => Todo('$id'),
        );
    final pages = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async =>
          PostPage(['${context.pageParam}'], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    );

    client.setData(todoOptions(1), const Todo('a'));
    final Todo? todo = client.getData(todoOptions(1));
    client.updateData(todoOptions(1), (todo) => Todo('${todo?.title}!'));
    client.setData(
      pages,
      const InfiniteData(pages: [
        PostPage(['a'], hasMore: false)
      ], pageParams: [
        1
      ]),
    );
    client.updateData(
      pages,
      (data) => data == null
          ? null
          : InfiniteData(
              pages: [
                for (final page in data.pages)
                  PostPage([...page.titles, 'b'], hasMore: page.hasMore),
              ],
              pageParams: data.pageParams,
            ),
    );

    expect(todo!.title, 'a');
    expect(client.getData(todoOptions(1))!.title, 'a!');
    expect(client.getData(pages)!.lastPage.titles, ['a', 'b']);
  });

  fakeTest('slots infer their types from the source', (async) {
    final todos = Query(
      queryKey: ['todos'],
      queryFn: (_) async => [const Todo('a')],
    );
    final pages = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async =>
          PostPage(['${context.pageParam}'], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    );
    final add = Mutation(mutationFn: (String title) async => Todo(title));

    final todosSlot = QuerySlot(todos, client);
    final observedSlot = QuerySlot(todos.observe(client: client), client);
    final pagesSlot = InfiniteQuerySlot(pages, client);
    final addSlot = MutationSlot(add, client);
    final listSlot =
        QueriesSlot([todos, todos.observe(client: client)], client);
    final QueriesSlot<List<Todo>> typedList = listSlot;
    expect(typedList.result, hasLength(2));
    listSlot.dispose();

    final QuerySlot<List<Todo>> typedTodos = todosSlot;
    final QuerySlot<List<Todo>> typedObserved = observedSlot;
    final InfiniteQuerySlot<PostPage, int> typedPages = pagesSlot;
    final MutationSlot<Todo, String, Object?> typedAdd = addSlot;
    typedAdd.result.mutate('b');
    async.flushMicrotasks();

    expect(typedTodos.result.isPending, isTrue);
    expect(typedObserved.result.isPending, isTrue);
    expect(typedPages.result.pages, isEmpty);
    expect(typedAdd.result.data!.title, 'b');

    // The listeners of listen get the slot's result type.
    final heard = <String>[];
    todosSlot.listen((previous, current) {
      final QueryResult<List<Todo>> typedPrevious = previous;
      final QueryResult<List<Todo>> typedCurrent = current;
      heard.add('todos: ${typedPrevious.data?.length} '
          '${typedCurrent.data?.single.title}');
    });
    addSlot.listen((previous, current) {
      final MutationResult<Todo, String, Object?> typedPrevious = previous;
      final MutationResult<Todo, String, Object?> typedCurrent = current;
      heard.add('add: ${typedPrevious.status.name} '
          '${typedCurrent.status.name} ${typedCurrent.data?.title}');
    });
    typedAdd.result.mutate('c');
    async.flushMicrotasks();
    expect(heard, [
      'add: success pending null',
      'todos: null a',
      'add: pending success c',
    ]);
    // A definition gives its own types, NoVariablesMutation gives void, and
    // filters give Object?.
    final addStateSlot = MutationStateSlot(
      Mutation(
        mutationKey: const ['todos', 'add'],
        mutationFn: (String title) async => Todo(title),
      ),
      client,
    );
    final clearSlot = MutationStateSlot(
      NoVariablesMutation(
        mutationKey: const ['todos', 'clear'],
        mutationFn: () async => 0,
      ),
      client,
    );
    final filtersSlot = MutationStateSlot(
      const MutationFilters(mutationKey: ['todos']),
      client,
    );
    final MutationStateSlot<Todo, String, Object?> typedAddState = addStateSlot;
    final MutationStateSlot<int, void, Object?> typedClear = clearSlot;
    final MutationStateSlot<Object?, Object?, Object?> typedFilters =
        filtersSlot;
    addStateSlot.subscribeToRuns((previous, current) {
      final MutationState<Todo, String, Object?> typedPrevious = previous;
      final MutationState<Todo, String, Object?> typedCurrent = current;
      heard.add('run: ${typedPrevious.status.name} '
          '${typedCurrent.status.name} ${typedCurrent.data?.title}');
    });
    Mutation(
      mutationKey: const ['todos', 'add'],
      mutationFn: (String title) async => Todo(title),
    ).observe(client: client).mutate('d');
    async.flushMicrotasks();
    expect(heard.last, 'run: pending success d');
    expect(typedAddState.result.single.data!.title, 'd');
    expect(typedClear.result, isEmpty);
    expect(typedFilters.result, hasLength(1));

    for (final slot in <ObserverSlot<Object?, Object?>>[
      todosSlot,
      observedSlot,
      pagesSlot,
      addSlot,
      addStateSlot,
      clearSlot,
      filtersSlot,
    ]) {
      slot.dispose();
    }
  });

  fakeTest('updateQueriesData and mapPages take their types from the updater',
      (async) {
    final todos = Query(
      queryKey: ['todos', 'open'],
      queryFn: (_) async => [const Todo('a')],
    );
    final pages = InfiniteQuery(
      queryKey: ['pages'],
      queryFn: (context) async =>
          PostPage(['${context.pageParam}'], hasMore: false),
      initialPageParam: 1,
      getNextPageParam: (data) => null,
    );
    client.setData(todos, [const Todo('a')]);
    client.setData(
      pages,
      const InfiniteData(pages: [
        PostPage(['a'], hasMore: false)
      ], pageParams: [
        1
      ]),
    );

    client.updateQueriesData(
      queryKey: ['todos'],
      (List<Todo> todos) => [...todos, const Todo('b')],
    );
    client.updateData(
      pages,
      (data) => data?.mapPages(
        (page) => PostPage([...page.titles, 'b'], hasMore: page.hasMore),
      ),
    );

    expect(client.getData(todos)!.map((todo) => todo.title), ['a', 'b']);
    expect(client.getData(pages)!.lastPage.titles, ['a', 'b']);
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
