import 'package:example/app/data/demo_api.dart';
import 'package:example/app/data/todo.dart';
import 'package:example/app/data/todo_repository.dart';
import 'package:fuery/fuery.dart';

/// Keys live next to their query, so a typo can't create a second cache
/// entry. Everything below `['todos']` is invalidated together.
const todosKey = ['todos', 'list'];
const pagedTodosKey = ['todos', 'paged'];

QueryKey todoKey(int id) => ['todos', 'detail', id];

QueryKey searchTodosKey(String term) => ['todos', 'search', term];

QueryKey jobKey(String id) => ['jobs', id];

QueryKey answerKey(String question) => ['answers', question];

Future<Todo> _fetchTodo(int id) => TodoApi().getOne(id);

/// The todo list. Every widget and cubit that calls this shares one cache
/// entry, so a change made on one screen shows up on the others.
///
/// `persist` stores the list with the client's storage, so a restart shows it
/// before the request finishes. See `main.dart`.
QueryObserver<List<Todo>> todosQuery() {
  return Query.use(
    queryKey: todosKey,
    queryFn: (_) => TodoApi().getList(),
    persist: QueryPersist(
      toJson: (todos) => [for (final todo in todos) todo.toJson()],
      fromJson: (json) => [
        for (final todo in json! as List) Todo.fromJson(todo),
      ],
    ),
  );
}

/// One todo. While it loads, the list's copy is shown as placeholder data, so
/// opening the detail screen never shows a spinner.
QueryObserver<Todo> todoQuery(int id) {
  return Query.use(
    queryKey: todoKey(id),
    queryFn: (_) => _fetchTodo(id),
    placeholderData: (previous) {
      if (previous != null) return previous;
      final todos = Fuery.client.getQueryData<List<Todo>>(todosKey);
      for (final todo in todos ?? const <Todo>[]) {
        if (todo.id == id) return todo;
      }
      return null;
    },
  );
}

/// The same key and function as [todoQuery], for fetching outside widgets
/// with `client.query`.
QueryOptions<Todo> todoOptions(int id) {
  return QueryOptions(queryKey: todoKey(id), queryFn: (_) => _fetchTodo(id));
}

Future<TodoPage> _fetchPage(int page) => DemoApi().getPage(page);

int? _nextPage(InfiniteData<TodoPage, int> data) =>
    data.lastPage.hasMore ? data.lastPageParam + 1 : null;

/// An archive that loads a page at a time.
InfiniteQueryObserver<TodoPage, int> pagedTodosQuery() {
  return InfiniteQuery.use(
    queryKey: pagedTodosKey,
    queryFn: (context) => _fetchPage(context.pageParam),
    initialPageParam: 1,
    getNextPageParam: _nextPage,
  );
}

/// The same archive, for prefetching it with `client.infiniteQuery`.
InfiniteQueryOptions<TodoPage, int> pagedTodosOptions() {
  return infiniteQueryOptions(
    queryKey: pagedTodosKey,
    queryFn: (context) => _fetchPage(context.pageParam),
    initialPageParam: 1,
    getNextPageParam: _nextPage,
  );
}

/// Search results for [term]. Each term is its own cache entry, and an empty
/// term doesn't fetch at all.
///
/// One observer follows the typing: pass [searchTodosOptions] to its
/// `setOptions` so `placeholderData` can keep the previous term's results on
/// screen. A new observer per term would have nothing to keep.
QueryObserver<List<Todo>> searchTodosQuery(String term) {
  return Query.use(
    queryKey: searchTodosKey(term),
    queryFn: (_) => DemoApi().search(term),
    enabled: term.isNotEmpty,
    placeholderData: (previous) => previous,
    staleTime: const Duration(minutes: 1),
  );
}

QueryOptions<List<Todo>> searchTodosOptions(String term) {
  return QueryOptions(
    queryKey: searchTodosKey(term),
    queryFn: (_) => DemoApi().search(term),
    enabled: term.isNotEmpty,
    placeholderData: keepPreviousData,
    staleTime: const Duration(minutes: 1),
  );
}

/// Polls a job while it runs, and stops polling once it is done.
QueryObserver<Job> jobQuery(String id) {
  return Query.use(
    queryKey: jobKey(id),
    queryFn: (_) => DemoApi().getJob(id),
    refetchInterval: const Duration(milliseconds: 300),
    refetchWhile: (state) => state.data?.isDone != true,
  );
}

/// Folds a stream of words into the query's data, so the answer grows while
/// it arrives and stays cached afterwards.
QueryObserver<String> answerQuery(String question) {
  return Query.use(
    queryKey: answerKey(question),
    queryFn: streamedQuery(
      stream: (context) => DemoApi().answer(question),
      initialValue: '',
      combine: (answer, word) => answer.isEmpty ? word : '$answer $word',
    ),
    staleTime: infiniteDuration,
  );
}
