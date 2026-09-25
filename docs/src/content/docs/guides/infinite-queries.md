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

`queryFn` loads the page that `context.pageParam` names, starting with `initialPageParam`. `getNextPageParam` returns the param of the page after the last one, or `null` when there are no more pages. [InfiniteQuery options](../../reference/query-options/#infinitequery-options) lists the other options and what Fuery does when a page param function fails.

## Showing pages

`InfiniteQueryBuilder` gives its builder the loaded pages and the flags a footer needs:

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

The footer reads `isFetchingNextPage` rather than `isFetching`, so a background refetch of the whole list doesn't replace the button with a spinner. [InfiniteQueryResult fields](../../reference/query-results/#infinitequeryresult-fields) lists every flag the builder can read.

A scroll listener can call `state.fetchNextPage()` as often as it likes:

- Once the query has data, the call does nothing when `hasNextPage` is false.
- A call while the next page loads waits for that page instead of fetching it again.
- The call cancels any other fetch that is running, such as a background refetch of every page. To let that fetch finish, disable the button while `isFetching` is true, as the footer does. `cancelRefetch: false` also lets it finish, but the call then loads no page.

`fetchPreviousPage()` works the same way with `hasPreviousPage`. [InfiniteQueryResult actions](../../reference/query-results/#infinitequeryresult-actions) lists their arguments.

## Updating items in cached pages

`mapPages` replaces every page and keeps the params. Use it to change one item, for example in an optimistic update, without reloading any page:

```dart
client.updateData(
  posts,
  (data) => data?.mapPages((page) => page.withPost(updatedPost)),
);
```

Fuery keeps a write made while `fetchNextPage()` or `fetchPreviousPage()` loads a page. It adds the new page to the pages as they are when the page arrives, unless the write changed which pages are loaded.

A refetch of every page replaces the pages with what it loaded. An optimistic update therefore [cancels refetches first](../mutations/#optimistic-updates).

## Keeping an infinite query in a function

`InfiniteQuery<TPage, TParam>` names the page type first and the page param type second. Fuery infers the page type from `queryFn` and the param type from `initialPageParam`. Write both as the return type when you move the query into a function, as [Organizing queries](../organizing-queries/) suggests:

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

Outside widgets, `postsQuery().observe()` returns an `InfiniteQueryObserver<PostPage, int>`, which has `fetchNextPage()` too.

## Cursor-based pages

APIs that return a cursor for the next page work the same way. When the first request has no cursor, `initialPageParam` is `null`, which says nothing about the cursor's type. Declare the type instead: keep the query in a function that returns `InfiniteQuery<ItemPage, String?>`, with the page type first and the cursor type second:

```dart
InfiniteQuery<ItemPage, String?> itemsQuery() => InfiniteQuery(
      queryKey: ['items'],
      queryFn: (context) => api.getItems(cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
    );
```

`context.pageParam` is then a `String?`, and `data.lastPage` an `ItemPage`.

## Fetching previous pages

Add `getPreviousPageParam` and call `state.fetchPreviousPage()` for a list that opens in the middle, like a chat that opens at the latest message. `hasPreviousPage` and `isFetchingPreviousPage` drive a header the way their next-page counterparts drive a footer.

## Limiting how many pages stay in memory

`maxPages` caps the number of cached pages. At the cap, loading a next page drops the first page, and loading a previous page drops the last one:

```dart
InfiniteQuery<MessagePage, String?> messagesQuery(String roomId) =>
    InfiniteQuery(
      queryKey: ['messages', roomId],
      queryFn: (context) => api.getMessages(roomId, cursor: context.pageParam),
      initialPageParam: null,
      getNextPageParam: (data) => data.lastPage.nextCursor,
      getPreviousPageParam: (data) => data.firstPage.previousCursor,
      maxPages: 5,
    );
```

Give `getPreviousPageParam` as well. Without it, `fetchPreviousPage()` has no param to ask for, so a page dropped from the front never comes back.

## Refetching every loaded page

A refetch of an infinite query reloads every loaded page, in order. Fuery starts from the first page's param and asks `getNextPageParam` for each next one, so the pages stay consistent when items moved between them. The refetch stops early when `getNextPageParam` returns `null`.

## In the example app

The example loads the feed a page at a time, as the list scrolls near the end, in [the feed](https://github.com/galaxykhh/fuery/blob/main/packages/fuery/example/lib/app/screens/feed/feed_screen.dart). Its [README](https://github.com/galaxykhh/fuery/tree/main/packages/fuery/example) maps each screen to what it shows.
