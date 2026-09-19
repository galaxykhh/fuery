<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->


# Fuery Core
### Asynchronous State Management for Dart.

## Features
* Async data fetching, caching, invalidation, pagination
* Mutation with side effect

## Installation
```bash
flutter pub add fuery_core
```

## Basic Usage
### Query
```dart
int id = 2;

// QueryResult<Post, Error>
late final post = Query.use<Post, Error>(
  queryKey: ['posts', id],
  queryFn: () => repository.getPostById(id),
);
```
### Infinite Query
```dart
class PageResponse<T> {
  final List<T> items;
  final int? nextCursor;

  ...
  
  factory PageResponse.fromJson(Map<String, dynamic> map) {
    return ...;
  }
}

class MyRepository {
  Future<PageResponse<Post>> getPostsByPage(int page) async {
    try {
      return PageResponse.fromJson(...);
    } catch(_) {
      throw Error();
    }
  }
}

// InfiniteQueryResult<int, List<InfiniteData<int, PageResponse<Post>>>, Error>
late final posts = InfiniteQuery.use<int, PageResponse<Post>, Error>(
  queryKey: ['posts', 'list'],
  queryFn: (int page) => repository.getPostsByPage(page),
  initialPageParam: 1,
  getNextPageParam: (lastPage, allPages) {
    print(lastPage.runtimeType) // InfiniteData<int, PageResponse<Post>>,
    print(allPages.runtimeType) // List<InfiniteData<int, PageResponse<Post>>>,
    
    return lastPage.data.nextPage;
  },
);
```


### Mutation
```dart
// MutationResult<Post, Error, void Function(String), Future<Post> Function(String)>
late final createPost = Mutation.use<String, Post, Error>(
  mutationFn: (String content) => repository.createPost(content),
  onMutate: (param) => print('mutate started'),
  onSuccess: (param, data) => print('mutate succeed'),
  onError: (param, error) => print('mutate error occurred'),
);

createPost.mutate('some content');
// or
await createPost.mutateAsync('some content');
```

### Mutation without parameters
Sometimes you may need a Mutation without parameters. In such situations, you can use the Mutation.noParams constructor.

```dart
// MutationResult<Post, Error, void Function(), Future<void> Function()>
late final createRandomPost = Mutation.noParams<Post, Error>(
  mutationFn: () => repository.createRandomPost(),
  onMutate: () => print('mutate started'),
  onSuccess: (data) => print('mutate succeed'),
  onError: (error) => print('mutate error occurred'),
);

createRandomPost.mutate();
// or
await createRandomPost.mutateAsync();
```

### Fuery Client
```dart
// invalidate.
Fuery.invalidateQueries(queryKey: ['posts']);

// Default query options configuration
Fuery.configQueryOptions(
  query: QueryOptions(...),
  infiniteQuery: InfiniteQueryOptions(...),
);
```

## Todo
* More complex features like query-core (from react-query)
