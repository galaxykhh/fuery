import 'package:fuery_core/fuery_core.dart';

class PageResponse<T> {
  final List<T> items;
  final int? nextCursor;

  PageResponse({
    required this.items,
    this.nextCursor,
  });

  factory PageResponse.fromJson(Map<String, dynamic> map) {
    return PageResponse(
      items: map['items'],
      nextCursor: map['nextCursor'],
    );
  }
}

class NameRepository {
  Future<String> getOne(int id) async {
    return 'Name $id';
  }

  Future<PageResponse<String>> getPage(int page) async {
    return PageResponse(
      items: [
        'Name $page-1',
        'Name $page-2',
        'Name $page-3',
        'Name $page-4',
        'Name $page-5',
      ],
      nextCursor: page + 1,
    );
  }

  Future<String> create(String name) async {
    return name;
  }

  Future<void> removeAll() async {
    // ...
  }
}

final nameRepository = NameRepository();

late final name = Query.use(
  queryKey: ['names', 1],
  queryFn: () => nameRepository.getOne(1),
);

late final names = InfiniteQuery.use(
  queryKey: ['names', 'list'],
  queryFn: (int page) => nameRepository.getPage(page),
  initialPageParam: 1,
  getNextPageParam: (lastPage, _) => lastPage.data.nextCursor,
);

late final createName = Mutation.use(
  mutationFn: (String name) => nameRepository.create(name),
  onSuccess: (_, data) => print('$data created'),
);

late final removeAll = Mutation.noParam(
  mutationFn: () => nameRepository.removeAll(),
  onSuccess: (_) => print('all names removed'),
);
