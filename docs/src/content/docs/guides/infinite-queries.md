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

- `queryFn` fetches one page. Its `InfiniteQueryFunctionContext` is a [query function context](../organizing-queries/#passing-dependencies-to-a-query-function) plus `pageParam`, the page to load.
- `getNextPageParam` returns the param of the next page, or `null` when there are no more pages.
- Fuery infers the page and param types.

## Showing pages

```dart
InfiniteQueryBuilder(
  query: posts,
  builder: (context, state) => ListView(
    children: [
      for (final page in state.pages) ...page.items.map(PostTile.new),
      if (state.isFetchingNextPage)
        const Center(child: CircularProgressIndicator())
      else if (state.isFetchNextPageError)
        TextButton(
          onPressed: posts.fetchNextPage,
          child: const Text('Loading more failed. Retry'),
        )
      else if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : posts.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

The footer reads `isFetchingNextPage` rather than `isFetching`, so a background refetch of the whole list doesn't replace the button with a spinner.

`fetchNextPage()` does nothing when `hasNextPage` is false, and a call while the next page is loading waits for that page instead of fetching it again, so a scroll listener can call it as often as it likes. Any other fetch that is running, such as a background refetch of every page, is cancelled first. Check `isFetching`, as in the example above, or pass `cancelRefetch: false` to let that fetch finish instead; the call then loads no page. `fetchPreviousPage()` works the same way with `hasPreviousPage`.

## InfiniteQueryResult fields

Builders and streams receive an `InfiniteQueryResult`. It carries every [`QueryResult` field](../queries/#queryresult-fields) and six more questions about the pages:

| Question | True when |
|---|---|
| `hasNextPage` | `getNextPageParam` returned a param. False until the first page loads. |
| `hasPreviousPage` | `getPreviousPageParam` returned a param. False without that option. |
| `isFetchingNextPage` | A `fetchNextPage()` is running |
| `isFetchingPreviousPage` | A `fetchPreviousPage()` is running |
| `isFetchNextPageError` | The last fetch was a `fetchNextPage()` and it failed |
| `isFetchPreviousPageError` | The last fetch was a `fetchPreviousPage()` and it failed |

`state.pages` is the loaded pages, or an empty list when there is no data yet. `state.data` holds the same pages together with their params.

`isRefetching` and `isRefetchError` cover a refetch of the whole list, so both stay false while a single page loads or fails.

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

Add `getPreviousPageParam` and call `fetchPreviousPage()` for lists that start in the middle, like a chat that opens at the latest message. `hasPreviousPage` and `isFetchingPreviousPage` drive a header the way their next-page counterparts drive a footer.

## Limiting how many pages stay in memory

`maxPages` caps the number of cached pages. At the cap, loading a next page drops the first page, and loading a previous page drops the last one:

```dart
final messages = InfiniteQuery.use(
  queryKey: ['messages', roomId],
  queryFn: (context) => api.getMessages(cursor: context.pageParam),
  initialPageParam: null as String?,
  getNextPageParam: (data) => data.lastPage.nextCursor,
  getPreviousPageParam: (data) => data.firstPage.previousCursor,
  maxPages: 5,
);
```

Give `getPreviousPageParam` as well. Without it `fetchPreviousPage()` has no param to ask for, so a page dropped from the front never comes back.

## Refetching every loaded page

Refetching an infinite query reloads every loaded page in order. It starts from the first page and asks `getNextPageParam` for each next one, so the list stays consistent even if items moved between pages.

## Keeping an infinite query in a function

`InfiniteQuery.use` returns an `InfiniteQueryObserver<TPage, TParam>`: the page type first, the page param type second. Name it when you move the query into a function, as [Organizing queries](../organizing-queries/) suggests:

```dart
// lib/data/post_queries.dart
InfiniteQueryObserver<PostPage, int> postsQuery() {
  return InfiniteQuery.use(
    queryKey: ['posts'],
    queryFn: (context) => api.getPosts(page: context.pageParam),
    initialPageParam: 1,
    getNextPageParam: (data) =>
        data.lastPage.hasMore ? data.lastPageParam + 1 : null,
  );
}
```

## In the example app

The example loads the feed a page at a time, as the list scrolls near the end, in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
