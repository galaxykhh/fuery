# docs

The documentation site, built with Astro Starlight and deployed to https://galaxykhh.github.io/fuery/.

```bash
cd docs
npm install
npm run dev      # local preview
npm run build    # must succeed before a pull request
```

## Structure

- Pages live in `src/content/docs/`. The sidebar is declared in `astro.config.mjs`, so a new page has to be added there to appear.
- The English pages are the source, served at `/fuery/`. Their translations live in `ko/`, `ja/`, and `zh-cn/` inside `src/content/docs/`, at the same paths, and are served at `/fuery/ko/` and so on. `i18n/locales.json` lists the languages; `astro.config.mjs` and the checks in `tool/` read it. See [Translations](#translations).
- The site is served from `/fuery`, set by `base` in `astro.config.mjs`. Link between pages with relative paths ending in a slash (`../queries/`), never with `/fuery/...`.
- `public/demo/` is the playground (`packages/fuery/playground`) built for the web. CI builds it in `.github/workflows/docs.yml`; it does not exist locally, so a local build reports `/fuery/demo/` as missing. A page links a scenario by its route, as in `/fuery/demo/#/lifecycle`.
- Sections: Getting started, Concepts (what server state is and how the cache works), Guides (one page per task, from queries to building an adapter), Reference (every option, result field, and client method in a table), Troubleshooting (symptom, cause, fix).

## How to write

Readers arrive with a task and leave as soon as it works. Write for that.

- **Answer the question in the first sentence.** Put the conclusion first and the reasoning after it. A page opens with what it is for, not with history or motivation.
- **One idea per sentence.** Split a sentence that needs a comma to hold two thoughts together.
- **Cut words that carry nothing.** Delete "simply", "just", "easily", "very", "in order to", and "you can". If deleting a word doesn't change the meaning, it wasn't doing anything.
- **Name things the same way every time.** A query is a query on every page, not a request or a fetcher. What the client keeps for one key is a cache entry (`CachedQuery`), not a cached query or an entry, and one `mutate` call is a run (`CachedMutation`). Define a term where it first appears on each page.
- **Write headings as what the reader wants to do.** "Keeping the previous page on screen" beats "placeholderData". Someone scanning the sidebar should find their problem without opening a page.
- **Be concrete.** Give the default, the duration, the type. "Fresh for `staleTime` (default: zero)" beats "fresh for a while".
- **Show the code that runs.** Every snippet compiles against the current API, uses real names, and is short enough to read at a glance. No `...` where a reader needs the line.
- **Say it once.** When two pages need the same explanation, keep it where it belongs and link to it from the other.
- **Prefer a table for facts you can enumerate**, such as options and their defaults, and prose for ideas that need an argument.
- **Active voice, present tense.** "Fuery refetches the query", not "the query will be refetched".
- **Don't promise what the code doesn't do.** No roadmap, no "coming soon", no describing behavior you haven't run.

Rules from the root `AGENTS.md` apply here too: document the current API only, and don't add upgrade or migration guides.

## Frontmatter

Every page needs `title` and `description`. Quote a description that contains a colon followed by a space, or the YAML fails to parse. A translation also needs `sourceHash`; see [Translations](#translations).

## API coverage

`api-coverage.md` lists every public type, member, option, and filter argument,
and whether the site mentions it. Regenerate it whenever the API changes:

```bash
python3 docs/tool/api_coverage.py           # writes docs/api-coverage.md
python3 docs/tool/api_coverage.py --check   # also exits 1 on any gap
```

CI regenerates the report and fails when it differs from the committed one, so
API added without a mention shows up as a diff. The gaps in the report are work
to do. API an app author never names belongs in `tool/coverage_ignore.txt`,
with the reason, rather than in the report.

A ✅ only means the name appears somewhere. It says nothing about whether a
reader can find it or understand it, which is what the rules above are for.

## Translations

Every English page has a Korean, a Japanese, and a Simplified Chinese translation at the same path in `ko/`, `ja/`, and `zh-cn/`: `ko/guides/queries.md` translates `guides/queries.md`. Write and change a page in English first, then translate it. Run the check from the repository root:

```bash
python3 tool/check_translations.py                                                       # lists missing and stale translations
python3 tool/check_translations.py --print-hash docs/src/content/docs/guides/queries.md  # the sourceHash for its translations
```

CI runs the check on every pull request and fails while a translation is missing or stale.

### Keeping translations in sync

- When an English page changes, update its three translations in the same change. A new title or description is a change too.
- A new English page gets its three translations in the same change. Renaming or deleting a page renames or deletes its translations with it.
- Each translation records the English page it was translated from as `sourceHash` in its frontmatter, after `description`:

  ```yaml
  sourceHash: 064d08f77dd2
  ```

  Set it to what `--print-hash` prints for the English page once the translation says what the English page says. Never refresh a hash without updating the translation: the hash is how the check, and the next editor, know the translation is current.
- To see what changed in the English page of a stale translation, run `git log -p` on the English page.

### Translating a page

- Translate what the English page says, and only that. Add no claims, comparisons, or notes of your own, and drop none. The rules under [How to write](#how-to-write) apply in every language.
- These stay in English, exactly as the English page writes them: code blocks, including their comments; API names and identifiers (`QueryClient`, `staleTime`, `fuery_core`); file names and paths; commands; and messages that Fuery or Flutter print, such as `StateError: Query holds X, but was requested as Y`. Product names stay as they are: Fuery, Flutter, Dart, pub.dev.
- Translate the text in the frontmatter too: `title`, `description`, a `<title>` set in `head` (it keeps its ` | Fuery` ending), and the home page's hero text.
- Write each link the way the English page writes it. Links between pages are relative, so they resolve inside the language: in `ko/guides/queries.md`, `../../reference/query-options/` opens `/fuery/ko/reference/query-options/`. Never add a language folder to a link.
- An `#anchor` names a heading, and a translated heading gets a new id, made from its text: `## 쿼리 키 정하기` becomes `#쿼리-키-정하기`. Point each anchor at the translated heading, on the same page or another one, and check it in the built site.
- Keep punctuation that ends bold text outside the `**` when a letter follows: `**変換**：`, `**古くなります**。`. Markdown doesn't close `**` right after punctuation when text follows, so `**変換：**テキスト` shows the asterisks. The check flags it on every page.
- A file path in the frontmatter or an `import`, such as the hero image in `index.mdx`, is relative to the file, so a translation one folder deeper adds a `../`.
- Use the language's glossary, `i18n/glossary.<lang>.md` (`glossary.ko.md`, `glossary.ja.md`, `glossary.zh-cn.md`). It lists how the language translates each Fuery term, which terms stay in English, and choices such as spacing and punctuation. Name things the same way every time, as in English, and add a new term to the glossary in the change that first uses it. The sidebar labels in `astro.config.mjs` and the title suffixes in `src/routeData.ts` use the glossary's words too.

### Style in each language

- **Korean** follows the [Toss technical writing guide](https://technical-writing.dev/), in particular [natural Korean expressions](https://technical-writing.dev/sentence/natural-kor-expression.html), in 해요체 (`~해요`, `~하세요`). Use a verb instead of a Sino-Korean noun with `수행하다` or `진행하다`: "로그 파일을 삭제해요", not "로그 파일 삭제 작업을 수행해요". Rewrite translationese such as `~를 통해`: "이 API로 데이터를 가져와요", not "이 API를 통해 데이터를 가져와요". Keep sentences active, spell out an abbreviation where it first appears, and write a loanword the way developers commonly write it.
- **Japanese** uses です・ます throughout.
- **Simplified Chinese** uses standard written technical Chinese.

### Adding a language

Add it to `i18n/locales.json`. Give each `translations` in `astro.config.mjs` and the title suffixes in `src/routeData.ts` an entry for its `lang`. Then translate every page, with a glossary of its own. The checks cover the new folder from then on.

## Before a pull request

- `npm run build` succeeds.
- Every internal link and anchor still resolves. Heading renames break links silently.
- Snippets match the API in `packages/`.
- `python3 docs/tool/api_coverage.py` leaves `api-coverage.md` unchanged, or the change is intended.
- `python3 tool/check_doc_links.py` passes: the debug warnings, READMEs, and pubspecs link to docs pages and anchors that exist. A released package keeps printing its links, so keep a page or heading that a warning links to instead of renaming it.
- `python3 tool/check_translations.py` passes: every English page has its three translations, each made from the page's current text.
