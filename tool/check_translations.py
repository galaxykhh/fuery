#!/usr/bin/env python3
"""Fails unless every English docs page has an up-to-date translation.

Usage:
    python3 tool/check_translations.py
    python3 tool/check_translations.py --print-hash docs/src/content/docs/guides/queries.md

The English pages live in docs/src/content/docs. Each other language in
docs/i18n/locales.json translates every one of them in a folder of its own,
at the same path: ko/guides/queries.md translates guides/queries.md. A
translation may be .md where the English page is .mdx, or the other way round.

A translation records the English page it was translated from as
`sourceHash` in its frontmatter. The hash covers the whole English file,
frontmatter included, with its line endings normalized, so any change to the
English page, even to its title or description, makes its translations stale.
--print-hash prints the hash of an English page, or of the English page that a
translation's path translates, to paste into the translation once it says
what the English says.

The check fails on:
- an English page with no translation in some language,
- a translation whose sourceHash is missing or isn't the English page's hash,
- a translation of an English page that no longer exists.

Nothing refreshes the hashes in bulk on purpose: a new hash says that the
translation matches the English page, and only whoever updated it knows that.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "src" / "content" / "docs"
LOCALES = ROOT / "docs" / "i18n" / "locales.json"
PAGE_SUFFIXES = (".md", ".mdx")

FRONTMATTER = re.compile(r"\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\Z)", re.DOTALL)
SOURCE_HASH = re.compile(r"""^sourceHash:[ \t]*(['"]?)([^'"\s#]*)\1[ \t]*(?:#.*)?$""", re.MULTILINE)


def locales() -> list[str]:
    """The folder of each translation: every locale but the English root."""
    return [key for key in json.loads(LOCALES.read_text(encoding="utf-8")) if key != "root"]


def read(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def source_hash(page: Path) -> str:
    """The hash a translation of `page` records as its sourceHash."""
    return hashlib.sha256(read(page).encode("utf-8")).hexdigest()[:12]


def recorded_hash(translation: Path) -> str | None:
    frontmatter = FRONTMATTER.match(read(translation))
    found = frontmatter and SOURCE_HASH.search(frontmatter.group(1))
    return found.group(2) if found and found.group(2) else None


def pages(folder: Path) -> list[Path]:
    return sorted(path for path in folder.rglob("*") if path.suffix in PAGE_SUFFIXES)


def counterpart(folder: Path, relative: Path) -> Path | None:
    """The page at `relative` in `folder`, as .md or .mdx."""
    for suffix in PAGE_SUFFIXES:
        page = folder / relative.with_suffix(suffix)
        if page.is_file():
            return page
    return None


def english_pages(languages: list[str]) -> list[Path]:
    return [page for page in pages(DOCS) if page.relative_to(DOCS).parts[0] not in languages]


def check() -> list[str]:
    languages = locales()
    problems = []
    for page in english_pages(languages):
        relative = page.relative_to(DOCS)
        expected = source_hash(page)
        untranslated = []
        for language in languages:
            translation = counterpart(DOCS / language, relative)
            if translation is None:
                untranslated.append(f"{language}/")
                continue
            recorded = recorded_hash(translation)
            where = translation.relative_to(DOCS)
            if recorded is None:
                problems.append(f"{where}: records no sourceHash ({relative} is {expected})")
            elif recorded != expected:
                problems.append(
                    f"{where}: translates an older {relative} "
                    f"(sourceHash {recorded}; {relative} is now {expected})"
                )
        if untranslated:
            problems.append(f"{relative}: no translation in {', '.join(untranslated)}")
    for language in languages:
        for translation in pages(DOCS / language):
            relative = translation.relative_to(DOCS / language)
            if counterpart(DOCS, relative) is None:
                problems.append(
                    f"{translation.relative_to(DOCS)}: translates {relative}, which doesn't "
                    "exist; move or delete the translation with the English page"
                )
    return problems


def english_page(path: Path) -> Path | None:
    """The English page that `path` is, or that it translates or will translate."""
    path = path.resolve()
    if path.is_relative_to(DOCS):
        parts = path.relative_to(DOCS).parts
        if parts and parts[0] in locales():
            return counterpart(DOCS, Path(*parts[1:])) if len(parts) > 1 else None
    return path if path.is_file() else None


def print_hash(argument: str) -> int:
    # The path is relative to the working directory or to the repository.
    for candidate in (Path(argument), ROOT / argument):
        page = english_page(candidate)
        if page is not None:
            print(source_hash(page))
            return 0
    print(f"No English page for {argument}", file=sys.stderr)
    return 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument(
        "--print-hash",
        metavar="PAGE",
        help="print the sourceHash for a translation of this English page "
        "(a translation's path prints its English page's hash)",
    )
    options = parser.parse_args()
    if options.print_hash:
        return print_hash(options.print_hash)

    problems = check()
    if problems:
        print(f"Translations that are missing or out of date, in {DOCS.relative_to(ROOT)}:")
        for problem in problems:
            print(f"  {problem}")
        print(
            "Bring each translation up to date with its English page, then set its sourceHash\n"
            "to what `python3 tool/check_translations.py --print-hash <English page>` prints.\n"
            "The rules are under Translations in docs/AGENTS.md."
        )
        return 1
    print(f"Every docs page has an up-to-date translation in {', '.join(locales())}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
