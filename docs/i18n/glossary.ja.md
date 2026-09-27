# Japanese glossary

This glossary covers the Japanese docs in `docs/src/content/docs/ja/`: how they name each Fuery term, which terms stay in English, and how they write sentences. The Japanese sidebar labels in `astro.config.mjs` and the Japanese title suffix in `src/routeData.ts` use these words too.

The rules under Translations in [`docs/AGENTS.md`](../AGENTS.md) come first. Translate what the English page says and only that. Keep code, API names, file names, commands, and the messages Fuery and Flutter print in English.

Add a term here in the change that first uses it. To change a term, change it here and on every Japanese page in the same change.

## Voice

- Write every sentence in です・ます体. This covers paragraphs, list items, table cells that are sentences, and the frontmatter `description`. Never mix in である体.
- Page titles, headings, sidebar labels, table headers, and card titles aren't sentences. Write them without です・ます, as a noun phrase or as a verb in its dictionary form: 「クエリキー」, 「前のページを表示したままにする」.
- A troubleshooting heading names the symptom in plain form: 「MutationListener が反応しない」.
- Give an instruction with 「〜してください」 and a prohibition with 「〜しないでください」. Don't use 「〜しましょう」 or 「〜してみましょう」, or honorifics such as 「〜いただけます」 and 「ご確認ください」.
- Leave out "you" and "your": "your app" is 「アプリ」, and "a widget of your own" is 「独自のウィジェット」. Never write 「あなた」.

## Sentences

These are the sentence rules of the Toss technical writing guide, applied to Japanese.

- **One idea per sentence.** Split an English sentence that Japanese could only hold together with a chain of 「〜し、〜し、〜して」 or a long modifier before a noun. Keep the subject close to its verb.
- **Active voice, with a named actor.** Fuery, a widget, an observer, or the reader does the action: 「Fuery が再取得します」, not 「Fuery によって再取得されます」. A passive participle that describes a state is fine: 「キャッシュされたページ」, 「保存されたデータ」.
- **A verb, not a verbal noun with 行う.** Write 「再取得します」, not 「再取得を行います」, and 「キャンセルします」, not 「キャンセル処理を実施します」.
- **No filler.** Leave out what the English rules leave out: 「単に」, 「ただ」, 「簡単に」, 「非常に」, and 「〜するために」 where 「〜には」 says it.
- **Conditions and time.** "When" is 「〜とき」 for a moment or an event, 「〜場合」 for a condition, and 「〜すると」 for a consequence that always follows. "While" is 「〜の間」, "until" is 「〜まで」, and "unless" is 「〜でない限り」.
- **"One" that means "shared".** "Every screen shares one cache entry" is 「すべての画面が同じキャッシュエントリを共有します」. Write 「1 つの」 only when the English counts.

Rewrite translationese:

| Avoid | Write |
|---|---|
| 〜することができます | 〜できます |
| 〜を通じて, 〜を介して | 〜で, 〜経由で |
| 〜において | 〜で |
| 〜となります | 〜です, 〜になります |
| 〜に関して | 〜について, or rewrite the sentence |
| それは〜, これは〜, それらを〜 | Repeat the noun, or leave it out |
| 〜のような〜を持つもの | Name the thing: 「有効なオブザーバーがあるキャッシュエントリ」 |

## Spacing and punctuation

- Put a half-width space between Japanese text and half-width letters, digits, or inline code: 「Fuery は」, 「`staleTime` の間」, 「3 回」, 「Flutter 3.27 以降」. The title suffix 「Flutter 向け Fuery」 follows this rule.
- Put no space next to full-width punctuation: 「`staleTime`（デフォルトはゼロ）」, 「`gcTime`、`retry`」.
- A link follows the same rule by its visible text: ``[クエリのライフサイクル](../how-the-cache-works/#クエリのライフサイクル)を参照してください``, but ``[`MutationStateSelector`](../mutations/#ミューテーションのすべての実行を表示する) を使います``.
- End sentences with 「。」 and separate clauses with 「、」.
- Use full-width 「（）」 for every parenthesis in prose, whatever it holds: 「キャッシュエントリ（`CachedQuery`）」.
- Put a full-width 「：」 after a label, with no space after it: `**変換**：`.
- Keep a 「。」 or 「：」 that follows bold text outside the `**`: `**古くなります**。`, `**購読**：`. Markdown doesn't close `**` after that punctuation when Japanese text follows, so `**古くなります。**1 分前` shows the asterisks.
- Quote words and UI text with 「」, and a quote inside a quote with 『』. Strings in code stay in backticks.
- End the sentence before a code block or a list with 「。」, not with a colon.
- End a list item or a table cell that is a sentence with 「。」. A noun phrase gets none.
- Don't use 「！」. Don't use 「・」 between words in prose; use 「、」 or 「と」. Don't use 「〜」 for a range; write 「1 から 3」.
- Quote a frontmatter `description` that contains a half-width `: `, as in English. A full-width 「：」 needs no quotes.
- Write numbers in half-width digits, with a space before the counter: 「5 分」, 「1 日」, 「300 ミリ秒」, 「1 秒、2 秒、4 秒」, 「2 つ」. "(default: 5 minutes)" is 「（デフォルトは 5 分）」, and "(default: zero)" is 「（デフォルトはゼロ）」.

## Katakana and kana

- A loanword whose English ends in -er, -or, or -ar ends in 「ー」: ユーザー, サーバー, オブザーバー, リスナー, ビルダー, セレクター, アダプター, コンシューマー, プロバイダー, パラメーター, フィルター, インジケーター, コンストラクター, ハンドラー, ブラウザー, フォルダー.
- A loanword whose English ends in -y doesn't: クエリ, エントリ, メモリ, ライブラリ, リポジトリ, プロパティ, ユーティリティ.
- Join the parts of a katakana compound with nothing between them: キャッシュエントリ, クエリキー, プレースホルダーデータ, ガベージコレクション時間.
- Write these in kana: こと, とき, もの, ところ, ため, ください, できる, すべて, など, ほか, まず, すでに, さらに, たとえば, あらかじめ. Write 「または」, not 「あるいは」, and 「と」, not 「および」.

## How Fuery is described

| English | Japanese |
|---|---|
| Built the Flutter way | Flutter の流儀で設計 |
| Nothing beyond Dart and Flutter | Dart と Flutter 以外に依存しない |
| Fuery depends on nothing beyond Dart and Flutter. | Fuery は Dart と Flutter 以外に依存しません。 |
| The hero tagline, `Fetch, cache, and keep server data <strong>fresh</strong> in Flutter.` | `Flutter でサーバーデータを取得し、キャッシュし、<strong>新鮮</strong>に保ちます。` |
| Fuery's caching and refetching model is inspired by TanStack Query. | Fuery のキャッシュと再取得のモデルは、TanStack Query から着想を得ています。 |

- Keep the card titles 「Flutter の流儀で設計」 and 「Dart と Flutter 以外に依存しない」 wherever the English leads with "Built the Flutter way" and "Nothing beyond Dart and Flutter".
- Never call Fuery a port, a clone, or a version of another library, never say it works like one, and never rank it against one. About Fuery, never write 「移植」, 「移植版」, 「ポート」, 「クローン」, 「〜の Flutter 版」, 「〜と同じように動く」, 「〜より優れた」, 「〜より軽い」, or 「〜の代替」.
- Translate each mention of TanStack Query as the English page words it, and add none.

## Terms

Use the same Japanese term on every page. Where a note says "first use", write the English in 「（）」 after the term the first time it appears on a page: 「古い（stale）」.

### The cache

| English | Japanese | Notes |
|---|---|---|
| query | クエリ | Not クエリー. The class stays `Query`. |
| query key, key | クエリキー, キー | |
| query function | クエリ関数 | `queryFn` |
| definition | 定義 | A `Query` or a `Mutation` object: 「クエリの定義」, 「定義の `mutate`」. |
| cache | キャッシュ | |
| query cache, mutation cache | クエリキャッシュ, ミューテーションキャッシュ | `QueryCache`, `MutationCache` |
| cache entry | キャッシュエントリ | `CachedQuery`. Never 「キャッシュされたクエリ」, and never 「エントリ」 alone. |
| client | クライアント | `QueryClient` |
| observer | オブザーバー | |
| observe, watch | 監視する | `observe()` and `client.watch` stay code. |
| result | 結果 | `QueryResult` and the other result types |
| state | 状態 | `QueryState`. "App state" is 「アプリの状態」. |
| server data | サーバーデータ | |
| server state | サーバー状態 | |
| data type | データ型 | |
| infinite query | 無限クエリ | `InfiniteQuery` |
| infinite scroll, pagination | 無限スクロール, ページネーション | |
| page, page param | ページ, ページパラメーター | `pageParam` |
| cursor | カーソル | |
| item (of a list or page) | 項目 | |
| todo (the example data) | Todo | 「Todo のリスト」, 「タイトルが「Buy milk」の Todo」 |
| streamed query | ストリーミングクエリ | `streamedQuery` |
| filter | フィルター | `QueryFilters`, `MutationFilters` |
| key prefix | キーのプレフィックス | "Starts with" is 「〜で始まる」. |
| match | 一致する | "The matches" are 「一致するキャッシュエントリ」 or 「一致する実行」. |
| exact | 完全一致 | |
| structural sharing | 構造共有 | |

### Fetching and freshness

| English | Japanese | Notes |
|---|---|---|
| fetch | 取得, 取得する | Keep 取得 for fetching. For "get" or "read" in any other sense, write 読み取る, 参照する, or 受け取る. Not フェッチ. |
| refetch | 再取得, 再取得する | Not リフェッチ or 再フェッチ. |
| prefetch | 事前取得 | |
| request | リクエスト | |
| in flight | 実行中の | 「実行中の取得」. For a run, see 実行 under [Mutations](#mutations). |
| fresh | 新鮮 | First use: 新鮮（fresh） |
| stale | 古い | First use: 古い（stale）. "Goes stale" is 古くなる, and "marks stale" is 古い状態にする. |
| freshness | 鮮度 | |
| invalidate | 無効化する | `invalidateQueries`, and the devtools button Invalidate |
| enabled | 有効 | 「有効なオブザーバー」 |
| disabled, turned off | オフ | For `enabled: false`: 「オフのクエリ」, 「`enabled` でオフにする」. Never 無効, which reads like 無効化. A button that can't be tapped is still 「ボタンを無効にする」. |
| active, inactive | アクティブ, 非アクティブ | `QueryTypeFilter.active`, `.inactive` |
| in use | 使用中 | |
| static | 静的 | `staticStaleTime` |
| garbage collection | ガベージコレクション | |
| garbage collection time | ガベージコレクション時間 | `gcTime` |
| leave memory | メモリから削除される | With Fuery as the subject: 「Fuery がメモリから削除します」. |
| lifecycle | ライフサイクル | "The app lifecycle" is 「アプリのライフサイクル」. |
| load | 読み込む | "Loading more" is 「さらに読み込む」. |
| loading | 読み込み中 | "Loading indicator" is ローディングインジケーター. |
| status | ステータス | `status` and `fetchStatus` stay code. |
| pending, success, error, idle, fetching, paused (as status names) | Keep in English | 「pending 状態」, 「`idle` に戻ります」. Write them as code where the English does, as with the devtools statuses `inactive`, `disabled`, `stale`, and `fresh`. As ordinary words, translate them: "a paused mutation" is 「一時停止中のミューテーション」. |
| settle | 完了する | Success or failure: 「取得が完了すると」. |
| succeed, fail | 成功する, 失敗する | |
| retry | 再試行, 再試行する | Not リトライ. `RetryPolicy` is 再試行ポリシー in prose. |
| backoff | バックオフ | |
| poll, polling | ポーリングする, ポーリング | |
| placeholder data | プレースホルダーデータ | `placeholderData` |
| initial data | 初期データ | `initialData` |
| cancel | キャンセルする | |
| abort | 中止する | 「シグナルが中止されると」 |
| signal | シグナル | `context.signal`, `AbortSignal` |
| focus | フォーカス | The app in the foreground, not keyboard focus |
| foreground, background | フォアグラウンド, バックグラウンド | "Returns to the foreground" is 「フォアグラウンドに戻る」. |
| resume (the app) | 再開する | |
| pause | 一時停止する | |
| online, offline | オンライン, オフライン | |
| network | ネットワーク | |
| connectivity | 接続状態 | |
| connectivity source, focus source | 接続状態のソース, フォーカスのソース | |
| reconnect | 再接続する | "The network reconnects" is 「ネットワークに再接続する」. |

### Mutations

| English | Japanese | Notes |
|---|---|---|
| mutation | ミューテーション | `Mutation`, `NoVariablesMutation` |
| run (noun) | 実行 | One `mutate` call, a `CachedMutation`: 「1 回の `mutate` 呼び出しが 1 つの実行です」. "Every run" is すべての実行, and "the latest run" is 最新の実行. A run in progress is 進行中の実行; never write 「実行中の実行」. |
| run (a mutation) | 実行する | Running a mutation starts a run. |
| settled run | 完了した実行 | |
| oldest first | 開始順 | Not 古い順, which reads like stale. |
| call, `mutate` call | 呼び出し, `mutate` 呼び出し | |
| variables | 変数 | What `mutate` receives |
| `context` (what `onMutate` returns) | `context` | Keep as code. |
| callback | コールバック | |
| optimistic update | 楽観的更新 | |
| roll back, rollback | ロールバックする, ロールバック | |
| scope | スコープ | `MutationScope` |
| mutation key | ミューテーションキー | `mutationKey` |
| the MutationState widgets | MutationState ウィジェット | `MutationStateBuilder`, `MutationStateListener`, and `MutationStateSelector` |
| shared observer | 共有したオブザーバー | An observer from `observe()` that several widgets are given |

### Persistence

| English | Japanese | Notes |
|---|---|---|
| persistence, persist | 永続化, 永続化する | The option stays `persist`. |
| persisted data | 永続化されたデータ | |
| storage | ストレージ | `QueryStorage` |
| store (noun) | ストア | "Key-value store" is キーバリューストア. |
| store (verb) | 保存する | "Stored data" is 保存されたデータ. |
| restore | 復元する | |
| discard | 破棄する | |
| expire | 期限切れになる | |
| remove, delete | 削除する | |
| clear | 消去する | `clear()` |
| version | バージョン | |
| encode, decode | エンコードする, デコードする | |

### Flutter and widgets

| English | Japanese | Notes |
|---|---|---|
| widget | ウィジェット | |
| widget tree, subtree | ウィジェットツリー, サブツリー | |
| builder | ビルダー | A builder widget, or the `builder` callback |
| listener | リスナー | |
| consumer | コンシューマー | |
| selector | セレクター | |
| select | 選択する | |
| provider | プロバイダー | `FueryProvider` stays code. |
| hook | フック | `fuery_hooks` stays code. |
| change hook, reading hook | 変更に反応するフック, 読み取り用のフック | `useOnQueryChange` and the other `useOn...Change` hooks; `useQuery` and the other hooks that return a result |
| build | ビルドする | The method is 「`build` メソッド」. |
| rebuild | リビルドする | Not 再ビルド |
| mount, unmount | マウントする, アンマウントする | |
| render | 描画する | |
| show | 表示する | |
| screen | 画面 | |
| navigation, navigate | 画面遷移, 画面遷移する | |
| snackbar | スナックバー | |
| side effect | 副作用 | |
| one-off effect | 1 回きりの処理 | |
| pull to refresh | 引っ張って更新 | |
| progress bar, spinner | プログレスバー, スピナー | |
| cubit, bloc | Cubit, Bloc | Capitalized, as Flutter developers write them. "Cubits and blocs" is 「Cubit と Bloc」. |
| state management | 状態管理 | |
| slot | スロット | `ObserverSlot`, `QuerySlot` |
| adapter | アダプター | |
| source | ソース | `QuerySource` and the other source types |
| contract (of an API) | 仕様 | 「スロットの仕様」 |
| devtools | devtools | Keep in English, lowercase in prose. The page title is Devtools. |
| panel | パネル | |
| debug build, profile build, release build | デバッグビルド, プロファイルビルド, リリースビルド | |
| hot reload | ホットリロード | |
| widget test | ウィジェットテスト | |
| example app | サンプルアプリ | |

### Dart and code

| English | Japanese | Notes |
|---|---|---|
| listen, hear | リッスンする | "A listener hears every run" is 「リスナーはすべての実行をリッスンします」. |
| subscribe, unsubscribe | 購読する, 購読を解除する | |
| subscription | 購読 | |
| stream | ストリーム | `Stream` in code |
| chunk | チャンク | What a streamed query receives from its stream |
| emit | 流す | 「まず現在の結果を流します」. Bloc's `emit` stays code. |
| future | Future | |
| throw | スローする | 「`StateError` をスローします」 |
| catch | キャッチする | |
| uncaught error | キャッチされないエラー | |
| zone | ゾーン | |
| microtask | マイクロタスク | |
| type argument | 型引数 | |
| infer | 推論する | |
| nullable, non-nullable | null 許容, 非 null 許容 | |
| cast | キャストする | |
| top-level | トップレベル | |
| tear-off | tear-off | Keep in English. |
| closure | クロージャ | |
| enum | enum | Keep in English. |
| field, member, method | フィールド, メンバー, メソッド | |
| argument, parameter | 引数, パラメーター | |
| return value, returns | 戻り値, 返す | |
| constructor, getter | コンストラクター, ゲッター | |
| assert | アサート | "Fails an assert" is 「アサートに失敗します」. |
| warning | 警告 | |
| fake, fake clock | フェイク, フェイククロック | |
| tear-down | ティアダウン | `addTearDown` stays code. |
| package, dependency | パッケージ, 依存関係 | |
| dev dependency | 開発用の依存関係 | |
| branch (of a `switch`) | 分岐 | 「データの分岐」, 「エラーの分岐」 |
| code generation, native code | コード生成, ネイティブコード | |
| batch | バッチ | |
| notify | 通知する | |
| handle | ハンドル | |
| event, event handler | イベント, イベントハンドラー | |
| repository, service | リポジトリ, サービス | |

### Keep in English

- Product and package names: Fuery, Flutter, Dart, pub.dev, GitHub, TanStack Query, React Query, React, `fuery`, `fuery_core`, `fuery_hooks`, `flutter_hooks`, `connectivity_plus`, `shared_preferences`, and `fake_async`.
- What `docs/AGENTS.md` keeps in English: code blocks with their comments, API names, file names, paths, commands, and the messages Fuery and Flutter print.
- Status names used as names, as in the table under [Fetching and freshness](#fetching-and-freshness).
- devtools, tear-off, enum, JSON, and ISO 8601.
- UI text that a snippet shows or a test finds, such as "Buy milk" and *Adding…*.
- The tab and button labels of the devtools panel, which the panel shows in English: Queries, Mutations, Refetch, Invalidate, Reset, and Remove. "The Queries tab" is 「Queries タブ」.

## Tables

| English header | Japanese header |
|---|---|
| Option | オプション |
| Field | フィールド |
| Member | メンバー |
| Method | メソッド |
| Argument, Arguments | 引数 |
| Parameter | パラメーター |
| Callback | コールバック |
| Filter | フィルター |
| Name | 名前 |
| Type | 型 |
| Default | デフォルト |
| Returns | 戻り値 |
| What it does, Description | 説明 |
| Meaning | 意味 |
| What it holds | 内容 |
| Runs (when a callback runs) | 実行タイミング |
| Selects (what a filter selects) | 対象 |
| Status | ステータス |
| Mode | モード |
| Stage | 段階 |
| What happens | 内容 |
| What ends it | 終了条件 |
| Term | 用語 |
| API type | API の型 |
| Widget, Hook | ウィジェット, フック |

In cells, "required" is 必須, "none" is なし, "now" is 現在時刻, "zero" is ゼロ, and "1s, 2s, 4s, … up to 30s" is 「1 秒、2 秒、4 秒…（最大 30 秒）」.

## Links

When the English link text is the title of the page or heading it opens, the Japanese link text is that title in [Page titles](#page-titles) or [Linked headings](#linked-headings). Translate other link text like the words around it. These sentences recur on most pages:

| English | Japanese |
|---|---|
| `See [Query lifecycle](../how-the-cache-works/#query-lifecycle).` | `[クエリのライフサイクル](../how-the-cache-works/#クエリのライフサイクル)を参照してください。` |
| `[Query options](../../reference/query-options/) lists every option.` | `すべてのオプションの一覧は[クエリのオプション](../../reference/query-options/)にあります。` |
| `[How the cache works](../../how-the-cache-works/) explains when a query fetches.` | `クエリがいつ取得するかは、[キャッシュのしくみ](../../how-the-cache-works/)で説明しています。` |
| `[Organizing queries](../organizing-queries/) shows where to keep queries.` | `クエリを置く場所は[クエリを整理する](../organizing-queries/)で紹介しています。` |
| `- [Queries](../guides/queries/): keys, freshness, and queries that depend on each other.` | `- [クエリ](../guides/queries/)：キー、鮮度、ほかのクエリに依存するクエリ` |

## Labels and repeated headings

| Where | English | Japanese |
|---|---|---|
| `astro.config.mjs` sidebar group | Concepts | 概念 |
| | Guides | ガイド |
| | Reference | リファレンス |
| | Example app | サンプルアプリ |
| `src/routeData.ts` title suffix | Fuery for Flutter | Flutter 向け Fuery |
| `index.mdx` hero actions | Get started | はじめる |
| | Try the demo | デモを試す |
| | View on GitHub | GitHub で見る |
| Headings that end many pages | Next steps | 次のステップ |
| | In the example app | サンプルアプリでは |

## Page titles

A page's frontmatter `title` is also its sidebar label, and the text of links to the page.

| Page | English | Japanese |
|---|---|---|
| `index.mdx` | Server state for Flutter | Flutter のためのサーバー状態 |
| `getting-started.md` | Getting started | はじめに |
| `coming-from-tanstack-query.md` | Coming from TanStack Query | TanStack Query を使ってきた方へ |
| `server-state.md` | Server state in Flutter | Flutter のサーバー状態 |
| `how-the-cache-works.md` | How the cache works | キャッシュのしくみ |
| `guides/queries.md` | Queries | クエリ |
| `guides/widgets.md` | Widgets | ウィジェット |
| `guides/mutations.md` | Mutations | ミューテーション |
| `guides/infinite-queries.md` | Infinite queries | 無限クエリ |
| `guides/streaming.md` | Streamed queries | ストリーミングクエリ |
| `guides/organizing-queries.md` | Organizing queries | クエリを整理する |
| `guides/query-client.md` | Reading and updating the cache | キャッシュの読み取りと更新 |
| `guides/client-setup.md` | Setting up the client | クライアントを設定する |
| `guides/lifecycle.md` | Refetching and going offline | 再取得とオフライン |
| `guides/persistence.md` | Persistence | 永続化 |
| `guides/hooks.md` | Hooks | フック |
| `guides/bloc.md` | Bloc and cubits | Bloc と Cubit |
| `guides/testing.md` | Testing | テスト |
| `guides/devtools.md` | Devtools | Devtools |
| `guides/adapters.md` | Building an adapter | アダプターを作る |
| `reference/query-options.md` | Query options | クエリのオプション |
| `reference/query-results.md` | Query results | クエリの結果 |
| `reference/mutation-options.md` | Mutation options | ミューテーションのオプション |
| `reference/mutation-results.md` | Mutation results | ミューテーションの結果 |
| `reference/query-client.md` | QueryClient | QueryClient |
| `troubleshooting.md` | Troubleshooting | トラブルシューティング |

## Linked headings

Pages link to these headings by their `#anchor`. Give each heading the Japanese text below, and write each link to it with the Japanese anchor. Astro makes an anchor from the heading text with `github-slugger`: it lowercases Latin letters, drops most punctuation, and turns each space into a hyphen. An anchor below holds while no earlier heading on the same page has the same text. The two troubleshooting headings that quote a message stay in English, so their anchors don't change.

To change one of these headings, change this table and every link to its anchor in the same change.

| Page | English | Japanese | Anchor |
|---|---|---|---|
| `how-the-cache-works` | Observers | オブザーバー | `#オブザーバー` |
|  | Query lifecycle | クエリのライフサイクル | `#クエリのライフサイクル` |
|  | Mutation runs | ミューテーションの実行 | `#ミューテーションの実行` |
| `coming-from-tanstack-query` | What's different in Flutter | Flutter で異なる点 | `#flutter-で異なる点` |
| `guides/queries` | Query keys | クエリキー | `#クエリキー` |
|  | Using a query | クエリを使う | `#クエリを使う` |
|  | Query data can't be null | クエリのデータは null にできない | `#クエリのデータは-null-にできない` |
|  | Which errors to retry | 再試行するエラーを選ぶ | `#再試行するエラーを選ぶ` |
|  | Keeping the previous page on screen | 前のページを表示したままにする | `#前のページを表示したままにする` |
|  | Rebuilding only what changed | 変わった部分だけをリビルドする | `#変わった部分だけをリビルドする` |
|  | Cancelling a request | リクエストをキャンセルする | `#リクエストをキャンセルする` |
| `guides/widgets` | Selecting part of the state | 状態の一部を選択する | `#状態の一部を選択する` |
|  | Reacting to changes | 変更に反応する | `#変更に反応する` |
|  | Showing several queries together | 複数のクエリをまとめて表示する | `#複数のクエリをまとめて表示する` |
| `guides/mutations` | Running a mutation | ミューテーションを実行する | `#ミューテーションを実行する` |
|  | Showing every run of a mutation | ミューテーションのすべての実行を表示する | `#ミューテーションのすべての実行を表示する` |
|  | Telling the user a mutation failed | ミューテーションの失敗をユーザーに伝える | `#ミューテーションの失敗をユーザーに伝える` |
|  | Acting after one call succeeds | 1 回の呼び出しが成功した後に処理する | `#1-回の呼び出しが成功した後に処理する` |
|  | Callbacks | コールバック | `#コールバック` |
|  | Optimistic updates | 楽観的更新 | `#楽観的更新` |
|  | Mutations without variables | 変数のないミューテーション | `#変数のないミューテーション` |
|  | Sharing one observer | 1 つのオブザーバーを共有する | `#1-つのオブザーバーを共有する` |
| `guides/infinite-queries` | Updating items in cached pages | キャッシュされたページの項目を更新する | `#キャッシュされたページの項目を更新する` |
|  | Cursor-based pages | カーソルベースのページ | `#カーソルベースのページ` |
|  | Refetching every loaded page | 読み込んだすべてのページを再取得する | `#読み込んだすべてのページを再取得する` |
| `guides/organizing-queries` | Reporting failures from a repository | リポジトリの失敗を報告する | `#リポジトリの失敗を報告する` |
| `guides/query-client` | Reading and writing the cache | キャッシュを読み書きする | `#キャッシュを読み書きする` |
|  | Invalidating | 無効化する | `#無効化する` |
|  | Watching the cache | キャッシュを監視する | `#キャッシュを監視する` |
|  | Fetching outside widgets | ウィジェットの外で取得する | `#ウィジェットの外で取得する` |
|  | Clearing everything at logout | ログアウト時にすべてを消去する | `#ログアウト時にすべてを消去する` |
| `guides/client-setup` | Reporting every failure in one place | すべての失敗を 1 か所で報告する | `#すべての失敗を-1-か所で報告する` |
|  | Catching errors that callbacks throw | コールバックがスローしたエラーをキャッチする | `#コールバックがスローしたエラーをキャッチする` |
|  | Which client a query uses | クエリが使うクライアント | `#クエリが使うクライアント` |
| `guides/lifecycle` | When the app resumes | アプリが再開したとき | `#アプリが再開したとき` |
|  | When the network reconnects | ネットワークに再接続したとき | `#ネットワークに再接続したとき` |
| `guides/persistence` | Persisting infinite queries | 無限クエリを永続化する | `#無限クエリを永続化する` |
|  | When stored data is discarded | 保存されたデータが破棄される場合 | `#保存されたデータが破棄される場合` |
|  | Restoring ahead of time | 事前に復元する | `#事前に復元する` |
|  | Deleting stored data | 保存されたデータを削除する | `#保存されたデータを削除する` |
|  | Persisting mutations | ミューテーションを永続化する | `#ミューテーションを永続化する` |
| `guides/hooks` | Showing only the runs a widget starts | ウィジェットが開始した実行だけを表示する | `#ウィジェットが開始した実行だけを表示する` |
|  | Showing every run of a mutation | ミューテーションのすべての実行を表示する | `#ミューテーションのすべての実行を表示する` |
|  | Reacting to changes | 変更に反応する | `#変更に反応する` |
|  | Snackbars and navigation in useEffect | useEffect でのスナックバーと画面遷移 | `#useeffect-でのスナックバーと画面遷移` |
|  | Reading the client | クライアントを参照する | `#クライアントを参照する` |
| `guides/bloc` | In a cubit | Cubit で使う | `#cubit-で使う` |
|  | Mutations from a cubit or bloc | Cubit や Bloc からのミューテーション | `#cubit-や-bloc-からのミューテーション` |
|  | Sharing with widgets | ウィジェットと共有する | `#ウィジェットと共有する` |
| `guides/testing` | Testing cubits and blocs | Cubit と Bloc をテストする | `#cubit-と-bloc-をテストする` |
| `guides/adapters` | Every run of a mutation | ミューテーションのすべての実行 | `#ミューテーションのすべての実行` |
| `reference/query-options` | InfiniteQuery options | InfiniteQuery のオプション | `#infinitequery-のオプション` |
|  | Page param errors | ページパラメーターのエラー | `#ページパラメーターのエラー` |
|  | Query function context | クエリ関数のコンテキスト | `#クエリ関数のコンテキスト` |
| `reference/query-results` | QueryResult fields | QueryResult のフィールド | `#queryresult-のフィールド` |
|  | QueryStatus and FetchStatus | QueryStatus と FetchStatus | `#querystatus-と-fetchstatus` |
|  | QueryResult actions | QueryResult のアクション | `#queryresult-のアクション` |
|  | InfiniteQueryResult fields | InfiniteQueryResult のフィールド | `#infinitequeryresult-のフィールド` |
|  | InfiniteQueryResult actions | InfiniteQueryResult のアクション | `#infinitequeryresult-のアクション` |
| `reference/mutation-options` | Options | オプション | `#オプション` |
|  | Running the mutation | ミューテーションを実行する | `#ミューテーションを実行する` |
|  | Callbacks | コールバック | `#コールバック` |
|  | NoVariablesMutation | NoVariablesMutation | `#novariablesmutation` |
|  | MutateOptions | MutateOptions | `#mutateoptions` |
|  | MutationPersist | MutationPersist | `#mutationpersist` |
| `reference/mutation-results` | MutationResult | MutationResult | `#mutationresult` |
|  | MutationState fields | MutationState のフィールド | `#mutationstate-のフィールド` |
| `reference/query-client` | Constructor options | コンストラクターのオプション | `#コンストラクターのオプション` |
|  | Operations on matching queries | 一致するクエリへの操作 | `#一致するクエリへの操作` |
|  | Query filters | クエリフィルター | `#クエリフィルター` |
|  | Refetch and cancel arguments | 再取得とキャンセルの引数 | `#再取得とキャンセルの引数` |
|  | Defaults | デフォルト | `#デフォルト` |
|  | Cache callbacks | キャッシュのコールバック | `#キャッシュのコールバック` |
|  | Caches | キャッシュ | `#キャッシュ` |
|  | QueryState fields | QueryState のフィールド | `#querystate-のフィールド` |
| `troubleshooting` | StateError: Query holds X, but was requested as Y | StateError: Query holds X, but was requested as Y | `#stateerror-query-holds-x-but-was-requested-as-y` |
|  | A Timer is still pending even after the widget tree was disposed | A Timer is still pending even after the widget tree was disposed | `#a-timer-is-still-pending-even-after-the-widget-tree-was-disposed` |
|  | A test passes only when it runs first | 最初に実行したときだけテストが通る | `#最初に実行したときだけテストが通る` |
|  | A MutationListener never runs | MutationListener が反応しない | `#mutationlistener-が反応しない` |
|  | A screen reads another client's cache | 画面が別のクライアントのキャッシュを読んでいる | `#画面が別のクライアントのキャッシュを読んでいる` |

## Example sentences

### Freshness

From "What Fuery did for you" in `getting-started.md`:

> Data is stale as soon as it arrives (`staleTime` defaults to zero). Fuery refetches it in the background when another screen starts using it and when the app returns to the foreground, and the old list stays on screen meanwhile.

Avoid:

> データは到着するとすぐにステールになります（`staleTime`はデフォルトでゼロです）。Fuery は、別の画面がそれの使用を開始したときおよびアプリがフォアグラウンドに戻ったときに、バックグラウンドでそれのリフェッチを行い、その間古いリストは画面上に残されます。

Write:

> `staleTime` のデフォルトはゼロなので、データは届いた時点で古く（stale）なります。別の画面がデータを使い始めたときと、アプリがフォアグラウンドに戻ったときに、Fuery はバックグラウンドでデータを再取得します。その間も、古いリストは画面に表示されたままです。

- "Stale" is 古い, with the English on its first use, and "refetch" is 再取得.
- The parenthesis becomes the reason, 「〜なので」, instead of a second pair of 「（）」 in one sentence.
- The long English sentence becomes two, so each holds one idea.
- 「それの使用を開始した」 and 「リフェッチを行い」 become the verbs 「使い始めた」 and 「再取得します」, with Fuery as the subject.
- A half-width space separates `staleTime` and Fuery from the Japanese around them.

### Runs

From "Running a mutation" in `guides/mutations.md`:

> `mutate` starts a run and returns at once. When the run fails, the error goes to the run's state and to the callbacks, not to the caller.

Avoid:

> `mutate`はランを開始して即座にリターンします。ランが失敗した場合、エラーは呼び出し元ではなく、ランのステートとコールバックに行きます。

Write:

> `mutate` は実行を開始し、すぐに戻ります。実行が失敗すると、エラーは呼び出し元には届かず、実行の状態とコールバックに届きます。

- "Run" is 実行 and "state" is 状態, never ラン or ステート.
- The failure always sends the error to the same place, so the condition is 「〜すると」.
- One verb, 届く, carries both halves: 「呼び出し元には届かず」 and 「コールバックに届きます」. 「〜に行きます」 and 「リターンします」 are word-for-word English.

### Invalidating

From "Invalidating" in `guides/query-client.md`:

> Fuery refetches the matching cache entries in use right away: those with an enabled observer, such as a mounted widget. The others refetch the next time something uses them. Pass `refetchType: RefetchType.none` to only mark them stale.

Avoid:

> Fuery は使用中のマッチしたキャッシュエントリを直ちにリフェッチします：マウントされたウィジェットのような、有効化されたオブザーバーを持つものです。その他は次に何かがそれらを使用する時にリフェッチします。それらをステールとしてマークするだけのためには `refetchType: RefetchType.none` を渡してください。

Write:

> 一致するキャッシュエントリのうち、使用中のものを Fuery はすぐに再取得します。使用中とは、マウントされたウィジェットなど、有効なオブザーバーがあることです。それ以外のキャッシュエントリは、次に使われたときに Fuery が再取得します。古い状態にするだけなら、`refetchType: RefetchType.none` を渡してください。

- The colon becomes a sentence of its own, which defines 使用中.
- "Enabled" is 有効, "mark stale" is 古い状態にする, and "matching" is 一致する.
- 「それら」 and 「その他」 become the noun they stand for, キャッシュエントリ.
- The instruction ends in 「〜してください」.
