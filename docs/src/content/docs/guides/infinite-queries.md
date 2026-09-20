---
title: Infinite queries
description: Load pages on demand for endless lists.
---

```dart
final posts = InfiniteQuery.use(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);
```

- `queryFn` fetches one page. `context.pageParam` is the page to load.
- `getNextPageParam` returns the param of the next page, or `null` when there are no more pages.
- The types of pages and params are inferred; you don't need to write them.

## Showing pages

```dart
InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : posts.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

`fetchNextPage()` restarts a fetch that is already running, including a background refetch of every page, so check `isFetching` first, as above, or pass `cancelRefetch: false`.

## The data object

`getNextPageParam` and `getPreviousPageParam` receive the loaded data, with:

- `pages` and `pageParams`: every page and the param it was loaded with
- `lastPage`, `lastPageParam`, `firstPage`, `firstPageParam`

## Cursors

APIs that return a cursor for the next page work the same way. If the first request has no cursor, give `null` its type so Dart can infer the param type:

```dart
final items = InfiniteQuery.use(
  queryKey: ['items'],
  queryFn: (context) => api.getItems(cursor: context.pageParam),
  initialPageParam: null as String?,
  getNextPageParam: (data) => data.lastPage.nextCursor,
);
```

## Both directions

Add `getPreviousPageParam` and call `fetchPreviousPage()` for lists that start in the middle, like a chat that opens at the latest message. `maxPages` limits how many pages stay in memory; pages at the other end are dropped.

## Refetching

Refetching an infinite query, for example after invalidation, reloads every loaded page in order, starting from the first page and asking `getNextPageParam` for each next one. The list stays consistent even if items moved between pages.

## In the example app

The example has a paged archive in [the archive screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/infinite_todos/infinite_todos.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
