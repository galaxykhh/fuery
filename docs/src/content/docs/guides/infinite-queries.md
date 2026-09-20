---
title: Infinite queries
description: Paginated and infinite scrolling lists in Flutter, with cached pages.
---

An infinite query holds a list of pages under one key and loads the next page on
request. Use it for feeds and endless lists. For numbered pages that replace each
other, a plain query with
[placeholder data](../queries/#keeping-the-previous-page-on-screen) fits better.

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
- Fuery infers the page and param types.

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

`fetchNextPage()` cancels a fetch that is already running, including a background refetch of every page, and starts again. Check `isFetching` first, as in the example above, or pass `cancelRefetch: false`.

## InfiniteData fields

`getNextPageParam` and `getPreviousPageParam` receive the loaded data, with:

- `pages` and `pageParams`: every page and the param it was loaded with
- `lastPage`, `lastPageParam`, `firstPage`, `firstPageParam`

## Cursor-based pages

APIs that return a cursor for the next page work the same way. If the first request has no cursor, give `null` its type so Dart can infer the param type:

```dart
final items = InfiniteQuery.use(
  queryKey: ['items'],
  queryFn: (context) => api.getItems(cursor: context.pageParam),
  initialPageParam: null as String?,
  getNextPageParam: (data) => data.lastPage.nextCursor,
);
```

## Fetching previous pages

Add `getPreviousPageParam` and call `fetchPreviousPage()` for lists that start in the middle, like a chat that opens at the latest message. `maxPages` limits how many pages stay in memory. Fuery drops pages at the other end.

## Refetching every loaded page

Refetching an infinite query reloads every loaded page in order. It starts from the first page and asks `getNextPageParam` for each next one, so the list stays consistent even if items moved between pages.

## In the example app

The example has a paged archive in [the archive screen](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/infinite_todos/infinite_todos.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) lists one screen per case.
