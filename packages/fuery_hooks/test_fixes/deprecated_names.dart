// `dart fix --compare-to-golden`, run in this directory, checks that the
// transforms in fuery_core's lib/fix_data.yaml turn this file into
// deprecated_names.dart.expect. FocusManager is left out: this library hides
// it, so it means Flutter's class.
import 'package:fuery_hooks/fuery_hooks.dart';

// QueryOptions
final QueryOptions<String> todos =
    QueryOptions(queryKey: ['todos'], queryFn: (_) async => 'todos');

const QueryOptions<int> count =
    QueryOptions<int>(queryKey: ['count'], queryFn: _count);

Future<int> _count(QueryFunctionContext context) async => 1;

class TodoQuery extends QueryOptions<String> {
  TodoQuery(int id)
      : super(queryKey: ['todos', id], queryFn: (_) async => 'todo');
}

bool isQuery(Object value) => value is QueryOptions<String>;

// InfiniteQueryOptions and infiniteQueryOptions
final InfiniteQueryOptions<int, int> pages = infiniteQueryOptions(
  queryKey: ['pages'],
  queryFn: (context) async => context.pageParam,
  initialPageParam: 1,
  getNextPageParam: (data) => null,
);

final InfiniteQueryOptions<int, int> morePages = InfiniteQueryOptions(
  queryKey: ['more'],
  queryFn: (context) async => context.pageParam,
  initialPageParam: 1,
  getNextPageParam: (data) => null,
);

class PagesQuery extends InfiniteQueryOptions<int, int> {
  PagesQuery()
      : super(
          queryKey: ['pages'],
          queryFn: (context) async => context.pageParam,
          initialPageParam: 1,
          getNextPageParam: (data) => null,
        );
}

bool isPages(Object value) => value is InfiniteQueryOptions<int, int>;

// MutationOptions and AnyMutationOptions
final MutationOptions<int, int, Object?> add =
    MutationOptions(mutationFn: (int x) async => x + 1);

class AddMutation extends MutationOptions<int, int, Object?> {
  AddMutation() : super(mutationFn: (int x) async => x + 1);
}

bool isMutation(Object value) => value is MutationOptions<int, int, Object?>;

final AnyMutationOptions any = add;

final List<AnyMutationOptions> mutations = [add, AddMutation()];

bool isAnyMutation(Object value) => value is AnyMutationOptions;
