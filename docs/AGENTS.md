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
- The site is served from `/fuery`, set by `base` in `astro.config.mjs`. Link between pages with relative paths ending in a slash (`../queries/`), never with `/fuery/...`.
- `public/demo/` is the example app built for the web. CI builds it in `.github/workflows/docs.yml`; it does not exist locally, so a local build reports `/fuery/demo/` as missing.
- Sections: Getting started, Concepts (what server state is and how to organize queries), Guides (one page per feature), Reference (every option in a table), Troubleshooting (symptom, cause, fix).

## How to write

Readers arrive with a task and leave as soon as it works. Write for that.

- **Answer the question in the first sentence.** Put the conclusion first and the reasoning after it. A page opens with what it is for, not with history or motivation.
- **One idea per sentence.** Split a sentence that needs a comma to hold two thoughts together.
- **Cut words that carry nothing.** Delete "simply", "just", "easily", "very", "in order to", and "you can". If deleting a word doesn't change the meaning, it wasn't doing anything.
- **Name things the same way every time.** A query is a query on every page, not a request, a fetcher, or a cache entry. Define a term where it first appears.
- **Write headings as what the reader wants to do.** "Keeping the previous page on screen" beats "placeholderData". Someone scanning the sidebar should find their problem without opening a page.
- **Be concrete.** Give the default, the duration, the type. "Fresh for `staleTime` (default: zero)" beats "fresh for a while".
- **Show the code that runs.** Every snippet compiles against the current API, uses real names, and is short enough to read at a glance. No `...` where a reader needs the line.
- **Say it once.** When two pages need the same explanation, keep it where it belongs and link to it from the other.
- **Prefer a table for facts you can enumerate**, such as options and their defaults, and prose for ideas that need an argument.
- **Active voice, present tense.** "Fuery refetches the query", not "the query will be refetched".
- **Don't promise what the code doesn't do.** No roadmap, no "coming soon", no describing behavior you haven't run.

Rules from the root `AGENTS.md` apply here too: describe Fuery on its own terms, never compare it with other packages, document the current API only, and don't add upgrade or migration guides.

## Frontmatter

Every page needs `title` and `description`. Quote a description that contains a colon followed by a space, or the YAML fails to parse.

## Before a pull request

- `npm run build` succeeds.
- Every internal link and anchor still resolves. Heading renames break links silently.
- Snippets match the API in `packages/`.
