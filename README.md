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

<p align="center">
  <img src="https://github.com/galaxykhh/fuery/assets/79380337/15ad2527-a059-44ce-a8d2-51920c02596f"/>
  <h1 align="center">Fuery</h1>
</p>

### Asynchronous state management library that helps implements the server side state management in Flutter

## Features

- Async data fetching, caching, invalidation, pagination
- Mutation with side effect
- Widget builders and listeners

## Installation

```bash
flutter pub add fuery
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


// Widget
...
return QueryBuilder(
    query: post,
    builder: (context, state) {
        if (state.status.isPending) {
            ...
        }

        if (state.status.isError) {
            ...
        }
    }
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

// Widget
...
return InfiniteQueryBuilder(
    query: posts,
    builder: (context, state) {
        if (state.status.isPending) {
            ...
        }

        if (state.status.isError) {
            ...
        }
    }
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

### MutationBuilder

```dart

// Shows loading barrier when deleting todo item.
MutationBuilder(
  mutation: deleteTodo,
  builder: (context, state) {
    if (state.status.isPending) {
      return LoadingBarrier();
    }

    return const SizedBox();
  },
),
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
