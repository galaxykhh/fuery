# Simplified Chinese glossary

How the Simplified Chinese docs in `src/content/docs/zh-cn/` name every Fuery term, which words stay in English, and how sentences, spacing, and punctuation work. The `'zh-CN'` sidebar labels in `astro.config.mjs` and the title suffix in `src/routeData.ts` use these words too.

Write standard written technical Chinese, as docs.flutter.cn and dart.cn do. The rules in `docs/AGENTS.md` under How to write apply to every sentence. When a page needs a term that isn't here, add it in the same change: take the word docs.flutter.cn or dart.cn uses, or keep the English word when Chinese developers write it in English.

## Spacing and punctuation

| Rule | Write | Not |
|---|---|---|
| One half-width space between Chinese and Latin letters, digits, or inline code | ``用 `QueryBuilder` 显示查询``, `默认值为 5 分钟` | ``用`QueryBuilder`显示查询``, `5分钟` |
| No space next to full-width punctuation | ``缓存条目（`CachedQuery`）``, `默认值：0` | ``缓存条目 （ `CachedQuery` ）``, `默认值： 0` |
| Full-width punctuation in prose: ，。、；：？！（）“”——…… | `查询、变更和无限查询。` | `查询, 变更和无限查询.` |
| 、 between items of a series, 和 or 或 before the last one, no comma before it | `` `invalidateQueries`、`refetchQueries` 和 `resetQueries` `` | `` `invalidateQueries`，`refetchQueries`，和 `resetQueries` `` |
| Full-width parentheses, also around code or English | ``垃圾回收时间（`gcTime`）`` | ``垃圾回收时间(`gcTime`)`` |
| “” for quotation marks, ‘’ inside them | `“Buy milk”` | `「Buy milk」`, `"Buy milk"` |
| A sentence ends with 。, also after code | ``调用 `refetch()`。`` | ``调用 `refetch()` `` |
| Arabic numerals, with a space before the unit | `3 次`, `1 秒、2 秒、4 秒`, `1 天` | `三次`, `1s、2s、4s` |
| Half-width punctuation only inside code, commands, URLs, and English messages | `StateError: Query holds X, but was requested as Y` | Translating or re-punctuating the message |

- A code name in prose drops the English plural: "`Duration`s" becomes `Duration` 值, and "the `MutationState`s" becomes 每个 `MutationState`.
- widget, hook, slot, and stream stay lowercase, also at the start of a sentence.
- UI text quoted from a snippet, such as *Adding…* or `Load more`, stays as the code writes it.

## Headings and anchors

- Write a heading as what the reader wants to do, as a verb phrase with no trailing punctuation. "Keeping the previous page on screen" becomes `在屏幕上保留上一页`, not `如何在屏幕上保留上一页` or `上一页的保留`.
- A heading's id drops full-width punctuation, turns each space into `-`, and lowercases Latin letters: `## QueryResult 字段` becomes `#queryresult-字段`, and ``## 缓存条目（`CachedQuery`）`` becomes `#缓存条目cachedquery`.
- A heading that quotes a message Fuery or Flutter prints stays in English, so its id stays the English one: `### StateError: Query holds X, but was requested as Y`.

## Terms

### The cache model

| English | 简体中文 | Notes |
|---|---|---|
| query | 查询 | The definition, `Query`. Never 请求 or 获取器. |
| query key, key | 查询键、键 | "key prefix" 键前缀. "by key" 按键. |
| query function | 查询函数 | `queryFn` |
| definition | 定义 | "query definition" 查询定义. "the definition's `mutate`" 定义的 `mutate`. |
| client | 客户端 | `QueryClient`. "default client" 默认客户端. "the provided client" `FueryProvider` 提供的客户端. |
| cache | 缓存 | "query cache" 查询缓存 (`QueryCache`). "mutation cache" 变更缓存 (`MutationCache`). |
| cache entry | 缓存条目 | `CachedQuery`. Never 缓存的查询, and never 条目 alone. |
| observer | 观察者 | `QueryObserver`, `InfiniteQueryObserver`, `MutationObserver` |
| result | 结果 | `QueryResult`, `InfiniteQueryResult`, `MutationResult` |
| state | 状态 | `QueryState`, `MutationState` |
| status, fetch status | 状态、获取状态 | The fields `status` and `fetchStatus`. |
| mutation | 变更 | `Mutation`. Never 突变 or 修改. |
| run (noun) | 执行 | One `mutate` call, `CachedMutation`. 一次执行, 每次执行, 最近一次执行. "mutation run" 变更的执行, never the compound 变更执行. |
| run a mutation | 执行变更 | 执行 belongs to mutations. Code that runs, such as a callback or a query function, takes 运行. |
| mutation function | 变更函数 | `mutationFn` |
| variables | 变量 | What a `mutate` call passes. |
| context | 上下文 | What `onMutate` returns. "query function context" 查询函数上下文 (`QueryFunctionContext`). |
| infinite query | 无限查询 | `InfiniteQuery` |
| server | 服务器 | The machine that answers. |
| server data, server state | 服务端数据、服务端状态 | |
| app state | 应用状态 | |

### Freshness and the lifecycle

| English | 简体中文 | Notes |
|---|---|---|
| fresh, freshness | 新鲜、新鲜度 | ``数据在 `staleTime` 内保持新鲜`` |
| stale | 过期 | "mark stale" 标记为过期. "stale data" 过期数据. Only in the `staleTime` sense: persisted data older than `maxAge` is 超过 `maxAge`. |
| `staleTime` | `staleTime` | Always the option name. |
| garbage collection, garbage collection time | 垃圾回收、垃圾回收时间 | First use on a page: 垃圾回收时间（`gcTime`）. |
| lifecycle | 生命周期 | "query lifecycle" 查询生命周期. "app lifecycle" 应用生命周期. |
| stage | 阶段 | |
| in use | 正在使用 | |
| active, inactive | 活跃、非活跃 | `QueryTypeFilter.active`, `.inactive` |
| leaves memory | 从内存中移除 | |
| structural sharing | 结构共享 | `structuralSharing` |
| placeholder data | 占位数据 | `placeholderData` |
| initial data | 初始数据 | `initialData` |

### Fetching

| English | 简体中文 | Notes |
|---|---|---|
| fetch (verb and noun) | 获取 | 一次获取. "the fetch in flight" 进行中的获取. Never 拉取. |
| refetch | 重新获取 | "background refetch" 后台重新获取 |
| request | 请求 | The network call. |
| load, first load | 加载、首次加载 | "loading indicator" 加载指示器, also for "spinner". |
| invalidate, invalidation | 使……失效、失效 | ``使 `['todos']` 失效`` |
| retry, retry policy | 重试、重试策略 | "backoff" 退避 |
| poll | 轮询 | `refetchInterval` |
| cancel, cancellable | 取消、可取消 | |
| abort | 中止 | `AbortSignal`. "aborts the signal" 中止信号. |
| prefetch | 预取 | |
| a query that depends on another query | 依赖另一个查询的查询 | "dependent queries" 依赖查询 |
| enabled | 启用 | `enabled` |
| disabled, turned off | 禁用 | `enabled: false` |
| settle, settled | 结束、已结束 | Success or failure, whichever comes. |
| in flight | 进行中 | |
| paused | 暂停 | |
| trigger | 触发条件 | "the next trigger refetches it" 下一次触发时重新获取 |

Status and enum values stay code: a query 处于 `pending` 状态, a fetch is `paused`, a run is `idle`.

### Mutations

| English | 简体中文 | Notes |
|---|---|---|
| optimistic update | 乐观更新 | |
| roll back, rollback | 回滚 | |
| scope | 作用域 | `MutationScope` |
| callback | 回调 | |
| side effect, one-off effect | 副作用、一次性副作用 | |
| shared observer | 共享观察者 | |
| the MutationState widgets | MutationState 系列 widget | `MutationStateBuilder`, `MutationStateSelector`, `MutationStateListener` |
| hear (a listener hears a run) | 接收 | `接收每次执行的变化` |
| resume paused mutations | 继续执行暂停的变更 | `resumePausedMutations`. 恢复 is for restoring from storage. |

### Infinite queries and streams

| English | 简体中文 | Notes |
|---|---|---|
| page | 页 | "loaded pages" 已加载的页. 下一页, 上一页, 第一页, 最后一页. |
| page param | 页参数 | `pageParam` |
| cursor | 游标 | |
| infinite scrolling, pagination | 无限滚动、分页 | |
| footer, header of a list | 列表底部、列表顶部 | |
| streamed query | 流式查询 | `streamedQuery` |
| stream | stream | `Stream` when the type is meant. |
| chunk | 数据块 | |

### Widgets, hooks, and adapters

| English | 简体中文 | Notes |
|---|---|---|
| widget | widget | As docs.flutter.cn writes it. "widget tree" widget 树. "widget test" widget 测试. |
| builder | 构建器 | The widget kind. The `builder` argument stays code. |
| listener | 监听器 | The widget kind, and a `listener` function. |
| consumer | 消费者 | |
| selector | 选择器 | The widget kind, and a `selector` function. |
| the query, infinite query, and mutation widgets | 查询、无限查询和变更 widget | |
| hook | hook | "change hook" 变化 hook. "reading hook" 读取 hook. |
| keys (of `useMemoized` or `useEffect`) | keys | Kept in English, so they don't read as 查询键. |
| adapter | 适配器 | |
| public API | 公开 API | "the public API of `fuery_core`" `fuery_core` 的公开 API. Never 公共 API. |
| slot | slot | `ObserverSlot`. Never 插槽, which readers know as another concept. |
| the slot contract | slot 的约定 | What an adapter calls, and when. |
| state library | 状态管理库 | "an adapter for another state library" 面向其他状态管理库的适配器 |
| source | 来源 | `QuerySource`. "event source" 事件源. "connectivity source" 网络状态来源. |
| mount, unmount | 挂载、卸载 | Widgets and clients. |
| subscribe, unsubscribe | 订阅、取消订阅 | |
| listen | 监听 | |
| watch | 观察 | An observer 观察 a cache entry. "Watching the cache", with `client.watch`, 观察缓存. |
| emit | 发出 | |
| notify | 通知 | |
| render | 渲染 | |
| build, rebuild | 构建、重建 | "the `build` method" `build` 方法 |
| dispose | 释放 | `dispose` |
| destroy | 销毁 | `destroy()` |
| screen | 界面 | 详情界面, 登录界面. Keeps 页 free for infinite-query pages. |
| feed, post, compose screen, notifications screen | 信息流、帖子、撰写界面、通知界面 | The example app's screens. |
| thread (of a post) | 讨论串 | "a thread summary" 讨论串摘要 |
| on screen | 屏幕上 | |
| frame | 帧 | "the first frame" 第一帧 |
| subtree | 子树 | |
| the home shell | 主页框架 | The example app's `home_shell.dart`. |

### Reading and changing the cache

| English | 简体中文 | Notes |
|---|---|---|
| filter | 过滤器 | "query filters" 查询过滤器 (`QueryFilters`). "mutation filters" 变更过滤器 (`MutationFilters`). |
| a filter in the UI, such as a search filter | 筛选条件 | Keeps 过滤器 for `QueryFilters` and `MutationFilters`. The text field is 筛选框. |
| predicate | 谓词函数 | `predicate` |
| match, matching | 匹配 | |
| exact | 精确匹配 | `exact: true` |
| defaults, per-key defaults | 默认值、按键设置的默认值 | `DefaultOptions`, `setQueryDefaults` |
| option | 选项 | |
| read, write | 读取、写入 | |
| update | 更新 | |
| updater | 更新函数 | The function `updateData`, `updateQueryData`, and `updateQueriesData` take. |
| config | 配置 | `QueryCacheConfig`, `MutationCacheConfig` |
| reset | 重置 | |
| remove | 移除 | From the cache. |
| delete | 删除 | Persisted data. |
| clear | 清空 | `clear()` |
| batch | 批量 | `notifyManager.batch` |

### App lifecycle, network, and persistence

| English | 简体中文 | Notes |
|---|---|---|
| foreground, background | 前台、后台 | |
| focus, focused | 焦点、获得焦点 | "the app is focused" 应用处于前台. "refetch on focus" 获得焦点时重新获取. Keyboard focus is 键盘焦点. |
| the app resumes | 应用回到前台 | |
| online, offline | 在线、离线 | |
| reconnect | 重新连接 | |
| connectivity | 网络连接状态 | |
| network mode | 网络模式 | `networkMode` |
| persist, persistence | 持久化 | |
| storage, key-value storage | 存储、键值存储 | `QueryStorage` |
| stored entry | 存储条目 | What Fuery writes to storage. Never 缓存条目. |
| restore | 恢复 | From storage. |
| discard | 丢弃 | |
| devtools | 开发者工具 | `FueryDevtools`. "panel" 面板, "tab" 标签页. |

### Dart, Flutter, and testing

| English | 简体中文 | Notes |
|---|---|---|
| type, data type | 类型、数据类型 | |
| type argument | 类型参数 | |
| infer, type inference | 推断、类型推断 | |
| analyzer, compiler | 分析器、编译器 | The Dart analyzer that `flutter analyze` runs, and the compiler a build runs |
| nullable, non-nullable | 可空、不可空 | |
| parameter, argument | 参数 | |
| constructor | 构造函数 | |
| field, member, method | 字段、成员、方法 | |
| enum | 枚举 | |
| top-level value | 顶层值 | |
| closure | 闭包 | |
| block body | 块函数体 | A function body in `{}`, as opposed to `=>`. |
| tear-off | tear-off | `onPressed: logoutMutation.mutate` |
| throw | 抛出 | ``抛出 `StateError`。`` |
| exception | 异常 | |
| error boundary | 错误边界 | The React concept, on the TanStack Query page. |
| uncaught error | 未捕获的错误 | |
| microtask | 微任务 | |
| await (a future or a call) | 用 `await` 等待 | ``用 `await` 等待 `mutateAsync` ``. A future in prose is `` `Future` ``. |
| assert | 断言 | |
| warning | 警告 | |
| debug, profile, release build | debug 构建、profile 构建、release 构建 | |
| hot reload | 热重载 | |
| fake, fake clock | 模拟、模拟时钟 | |
| timer | 计时器 | "garbage collection timer" 垃圾回收计时器 |
| test body | 测试主体 | The callback of `testWidgets` or `test`. |
| helper | 工具函数 | |
| dev dependency | 开发依赖 | |
| tear-down | 清理回调 | `addTearDown` |
| repository | 仓库 | |
| service | 服务 | |
| navigation | 导航 | |
| pull to refresh | 下拉刷新 | |
| debounce | 防抖 | |
| todo | 待办事项 | What the snippets' `Todo` holds. |
| crash reporter | 崩溃上报工具 | |
| list item | 列表项 | Never 条目. |
| map entry | 键值对 | Never 条目. |
| list, map, set | 列表、Map、Set | "compares lists, maps, and sets by content" 按内容比较列表、Map 和 Set |
| milliseconds since epoch | 自 Unix 纪元以来的毫秒数 | |
| code generation, native code | 代码生成、原生代码 | |

## Kept in English

- Everything `docs/AGENTS.md` keeps: code blocks with their comments, API names, file names and paths, commands, and messages that Fuery or Flutter print.
- Product and package names: Fuery, Flutter, Dart, pub.dev, TanStack Query, React Query, `fuery`, `fuery_core`, `fuery_hooks`, `flutter_hooks`.
- widget, hook, slot, stream, zone, cubit, bloc, snackbar, `Future`, and the build modes debug, profile, and release.
- JSON, API, UI, HTTP, and CLI.

## Lines the site leads with

The home page leads with the first three. Translate each of these lines the same way on every page that has it:

| English | 简体中文 |
|---|---|
| Fetch, cache, and keep server data fresh in Flutter. | 在 Flutter 中获取、缓存服务端数据，并让它保持新鲜。 |
| Built the Flutter way | 以 Flutter 的方式构建 |
| Nothing beyond Dart and Flutter | 只需 Dart 和 Flutter |
| Fuery depends on nothing beyond Dart and Flutter. | 除了 Dart 和 Flutter，Fuery 不依赖任何其他东西。 |
| Fuery's caching and refetching model is inspired by TanStack Query. | Fuery 的缓存和重新获取模型受 TanStack Query 启发。 |

Say what the English says about another library, and nothing more. Never call Fuery a port, clone, or copy of one (移植版、克隆、翻版、仿制), never write that it works like one (类似于、等同于), and never rank it against one.

## Recurring labels and headings

| English | 简体中文 |
|---|---|
| Concepts | 概念 |
| Guides | 指南 |
| Reference | 参考 |
| Example app | 示例应用 |
| Fuery for Flutter (title suffix) | 适用于 Flutter 的 Fuery |
| Getting started | 快速开始 |
| Get started | 开始使用 |
| Try the playground | 试用演练场 |
| Try it in the playground | 在演练场中试试 |
| View on GitHub | 在 GitHub 上查看 |
| Coming from TanStack Query | 写给 TanStack Query 用户 |
| Troubleshooting | 问题排查 |
| Next steps | 下一步 |
| In the example app | 在示例应用中 |
| required (a default in a table) | 必填 |
| none (a default in a table) | 无 |

"Coming from TanStack Query" gives the Fuery name for each TanStack Query concept. It isn't a migration guide, so its title never says 迁移.

## Sentences

1. **Put the answer first.** The page's first sentence says what it is for, as in English.
2. **One idea per sentence.** Keep each English sentence as one Chinese sentence, or split it. Never merge two, and end a thought with 。 rather than chaining clauses with ，.
3. **Active voice, with the actor as the subject.** `Fuery 在后台重新获取数据。`, not `数据会在后台被重新获取。` Avoid 被.
4. **Present tense.** Don't mark the future with 将 or 将会. For the preposition that moves the object forward, write 把, not 将.
5. **Verbs, not nouns made from verbs.** `缓存数据`, not `对数据进行缓存`. `获取`, not `执行获取操作`. 进行, 实现, and 完成 before a noun usually hide the verb. The one 执行 + noun pair is 执行变更.
6. **Cut words that carry nothing:** 只需, 简单地, 轻松, 非常, 为了, 你可以, 能够, 相关的. ``用 `enabled` 禁用查询。``, not ``你可以简单地用 `enabled` 来禁用查询。``
7. **No translationese.** `用这个 API 获取数据`, not `通过这个 API 来获取数据`. `……时`, not `当……的时候`. Drop 一个 where Chinese needs no article, and prefer 它 or 这个 to 其 and 该.
8. **你, never 您 or 我们.** Most instructions need no pronoun: ``在 `main` 中配置客户端。``
9. **Name each thing the same way every time.** Use the words above. Where a term first appears on a page, give its API name in parentheses: ``缓存条目（`CachedQuery`）``.
10. **Be as concrete as the English.** Keep every default, duration, type, and count: `默认值：5 分钟`, `重试 3 次`.
11. **Measure words:** 一个查询, 一个缓存条目, 一次获取, 一次执行, 一页.
12. **Lists and tables follow the English.** One English item is one Chinese item. An item that is a full sentence ends with 。, and a fragment doesn't.
13. **Translate link text** to the target's Chinese page title or heading. Add no notes, warnings, or emphasis that the English page doesn't have.

## Example sentences

| English | 简体中文 |
|---|---|
| Every widget that shows the same key shares one cache entry and one request, so you never pass the data down the tree. | 显示同一个键的所有 widget 共享一个缓存条目和一个请求，因此无须沿 widget 树向下传递数据。 |
| Data is fresh for `staleTime` (default: zero) and stale after it. Stale data stays on screen. | 数据在 `staleTime`（默认值：0）内保持新鲜，之后变为过期。过期数据仍然显示在屏幕上。 |
| `mutate` starts a run and returns at once. When the run fails, the error goes to the run's state and to the callbacks, not to the caller. | `mutate` 开始一次执行，并立即返回。执行失败时，错误记入这次执行的状态并传给回调，不会传给调用方。 |
