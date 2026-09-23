# Fuery example

A small social feed: posts, likes, comments, search, and notifications,
against an in-memory server with real delays. It is the app behind
[the web demo](https://galaxykhh.github.io/fuery/demo/). Every screen is one
you would ship, and each shows a part of Fuery in the place it belongs.

```bash
flutter run
```

The devtools button is on in debug and profile builds, and on the web demo
through `--dart-define=fuery.demo=true`.

## Screens

| Screen | What you do | What Fuery does |
|---|---|---|
| [Feed](lib/app/screens/feed/feed_screen.dart) | Scroll, pull to refresh, like posts | `InfiniteQueryBuilder` gets the feed's `InfiniteQuery` and loads a page at a time, with `state.fetchNextPage` and `state.refetch`. `InfiniteQueryPersist` stores the pages, so a restart shows the feed at once. A like updates the cached pages (`mapPages`), the post, and every cached search result (`updateQueriesData`) before the request, and rolls back when it fails (the post that says so always fails); one observer from `observe()` is shared by every card and the `MutationListener`. Hovering a card on the web or desktop prefetches the post with `client.query`. |
| [Post](lib/app/screens/post/post_screen.dart) | Read a post and its comments, comment, summarize the thread | Opens with the feed's copy as `placeholderData`, read through the client it receives, so there is no spinner. A comment written offline pauses and sends when the app is back online; `MutationBuilder` shows `isPaused`. The summary is a `streamedQuery` that grows word by word and is complete at once when reopened. A post stays fresh for 30 seconds (`staleTime`), so opening it again soon after, or seeing it in the recently viewed list, asks the server nothing. |
| [Compose](lib/app/screens/compose/compose_screen.dart) | Write a post | `MutationBuilder` runs the mutation with `state.mutate`, with the feed invalidation in the mutation and the screen's own `onSuccess` at the call site. The new post polls with `refetchInterval` until `refetchWhile` sees it published, then stops. |
| [Search](lib/app/screens/search/search_screen.dart) | Search as you type | The term lives in `setState`, and the widgets get `searchQuery(term)` on every build, keeping their observers. Each result shows its likes, which a like in the feed updates in every cached term at once. While nothing is typed, `QueriesBuilder` shows the posts opened lately, one query each, straight from the cache. `keepPreviousData` keeps the last results on screen while the next ones load, and an empty term is `enabled: false`. |
| [Notifications](lib/app/screens/notifications/notifications_screen.dart) | See what happened, mark all read | Polls every five seconds while the app is in the foreground. The badge on the tab is a [cubit](lib/app/screens/notifications/notifications_cubit.dart) over the same query, so both share one request. Marking all read updates the cache first; it is a `NoVariablesMutation`, so the button takes `markAllRead.mutate`. |
| [Home](lib/app/screens/home/home_shell.dart) | Switch tabs, go offline | `client.watch` drives the activity indicator. The wifi button reports connectivity with `onlineManager.setOnline`, which pauses mutations while offline and resumes them after. |

## Where things live

- [`data/feed_queries.dart`](lib/app/data/feed_queries.dart): every query defined once, so screens and cubits share cache entries.
- [`data/feed_mutations.dart`](lib/app/data/feed_mutations.dart): the same for mutations. The cache work is written once, with the client each callback receives; each screen gets its own pending and error state.
- [`data/demo_api.dart`](lib/app/data/demo_api.dart): the in-memory server, with delays and one request that always fails.
- [`data/preferences_storage.dart`](lib/app/data/preferences_storage.dart): a `QueryStorage` on shared preferences. [`main.dart`](lib/main.dart) gives it to the client.
- [`test/`](test/): a widget test for each screen, and `helpers.dart` to open one.
