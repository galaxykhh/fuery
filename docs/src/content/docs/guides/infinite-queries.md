---
title: Infinite queries
description: Paginated and infinite scrolling lists in Flutter, with cached pages.
---

An infinite query holds a list of pages under one key and loads the next page on
request. Use it for feeds and endless lists. For numbered pages that replace each
other, a plain query with
[placeholder data](../queries/#keeping-the-previous-page-on-screen) fits better.

```dart
final posts = InfiniteQuery(
  queryKey: ['posts'],
  queryFn: (context) => api.getPosts(page: context.pageParam),
  initialPageParam: 1,
  getNextPageParam: (data) =>
      data.lastPage.hasMore ? data.lastPageParam + 1 : null,
);
```

- `queryFn` fetches one page. Its `InfiniteQueryFunctionContext` is a [query function context](../organizing-queries/#passing-dependencies-to-a-query-function) plus `pageParam`, the page to load.
- `getNextPageParam` returns the param of the next page, or `null` when there are no more pages. It has to return the param type: Dart can't check that there without losing inference, so another type is [reported as an error](../query-client/#catching-errors-that-callbacks-throw), once, and counts as no next page. An error it throws, such as `data.lastPage.last` on an empty page, is reported and counts the same way. While a refetch reloads the pages, that error fails the refetch instead.
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
          onPressed: state.fetchNextPage,
          child: const Text('Loading more failed. Retry'),
        )
      else if (state.hasNextPage)
        TextButton(
          onPressed: state.isFetching ? null : state.fetchNextPage,
          child: const Text('Load more'),
        ),
    ],
  ),
)
```

The footer reads `isFetchingNextPage` rather than `isFetching`, so a background refetch of the whole list doesn't replace the button with a spinner.

`state.fetchNextPage()` does nothing when `hasNextPage` is false, and a call while the next page is loading waits for that page instead of fetching it again, so a scroll listener can call it as often as it likes. Any other fetch that is running, such as a background refetch of every page, is cancelled first. Check `isFetching`, as in the example above, or pass `cancelRefetch: false` to let that fetch finish instead; the call then loads no page. `fetchPreviousPage()` works the same way with `hasPreviousPage`.

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

To change an item in the cached pages, for an optimistic update, `mapPages` replaces every page and keeps the params:

```dart
client.updateData(
  postsQuery(),
  (data) => data?.mapPages((page) => page.withPost(updatedPost)),
);
```

A write made while `fetchNextPage()` or `fetchPreviousPage()` loads a page is kept. The new page is added to the pages as they are when it arrives, unless the write changed which pages are loaded. A refetch of every page replaces the pages with what it loaded, so an optimistic update still [cancels refetches first](../mutations/#optimistic-updates).

## Cursor-based pages

APIs that return a cursor for the next page work the same way. If the first request has no cursor, give `null` its type so Dart can infer the param type:

```dart
final items = InfiniteQuery(
  queryKey: ['items'],
  queryFn: (context) => api.getItems(cursor: context.pageParam),
  initialPageParam: null as String?,
  getNextPageParam: (data) => data.lastPage.nextCursor,
);
```

## Fetching previous pages

Add `getPreviousPageParam` and call `state.fetchPreviousPage()` for lists that start in the middle, like a chat that opens at the latest message. `hasPreviousPage` and `isFetchingPreviousPage` drive a header the way their next-page counterparts drive a footer.

## Limiting how many pages stay in memory

`maxPages` caps the number of cached pages. At the cap, loading a next page drops the first page, and loading a previous page drops the last one:

```dart
final messages = InfiniteQuery(
  queryKey: ['messages', roomId],
  queryFn: (context) => api.getMessages(cursor: context.pageParam),
  initialPageParam: null as String?,
  getNextPageParam: (data) => data.lastPage.nextCursor,
  getPreviousPageParam: (data) => data.firstPage.previousCursor,
  maxPages: 5,
);
```

Give `getPreviousPageParam` as well. Without it `fetchPreviousPage()` has no param to ask for, so a page dropped from the front never comes back.

Cached pages above the cap, for example from `setData`, are trimmed to `maxPages` when the next page or previous page loads. With nothing cached, `pages` above `maxPages` loads only `maxPages` pages.

## Refetching every loaded page

Refetching an infinite query reloads every loaded page in order. It starts from the first page and asks `getNextPageParam` for each next one, so the list stays consistent even if items moved between pages.

## Keeping an infinite query in a function

`InfiniteQuery<TPage, TParam>` names the page type first and the page param type second. Write it as the return type when you move the query into a function, as [Organizing queries](../organizing-queries/) suggests:

```dart
// lib/data/post_queries.dart
InfiniteQuery<PostPage, int> postsQuery() => InfiniteQuery(
      queryKey: ['posts'],
      queryFn: (context) => api.getPosts(page: context.pageParam),
      initialPageParam: 1,
      getNextPageParam: (data) =>
          data.lastPage.hasMore ? data.lastPageParam + 1 : null,
    );
```

Outside widgets, `postsQuery().observe()` returns an `InfiniteQueryObserver<PostPage, int>`, with `fetchNextPage()` on the observer itself.

## In the example app

The example loads the feed a page at a time, as the list scrolls near the end, in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
