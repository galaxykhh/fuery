#!/usr/bin/env python3
"""Fails unless every link to the docs site that the packages ship resolves.

Usage: python3 tool/check_doc_links.py

Reads the debug warnings in packages/*/lib, the READMEs, and the pubspecs,
and finds each link to https://galaxykhh.github.io/fuery/. A link must name
a page in docs/src/content/docs, and its #anchor must be a heading on that
page. A released package keeps printing its links until the next release, so
renaming a page or a heading must not break one.

The site root and the web demo (demo/, built only in CI) aren't checked.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs" / "src" / "content" / "docs"

LINK = re.compile(r"https?://galaxykhh\.github\.io/fuery/[^\s'\"<>()\[\]`]*")
# Adjacent string literals, which Dart joins into one: 'https://...'
# on one line and '...#anchor' on the next.
ADJACENT_LITERALS = re.compile(r"(['\"])[ \t]*\n[ \t]*\1")
FENCE = re.compile(r"^(```|~~~).*?^\1", re.MULTILINE | re.DOTALL)
HEADING = re.compile(r"^#{2,6}[ \t]+(.+?)(?:[ \t]+#+)?[ \t]*$", re.MULTILINE)
HTML_ID = re.compile(r"\bid=[\"']([^\"']+)[\"']")


def sources(root: Path) -> list[Path]:
    """The files whose links ship with the packages or lead to them."""
    found = [root / "README.md"]
    for package in sorted((root / "packages").iterdir()):
        if not (package / "pubspec.yaml").exists():
            continue
        found.append(package / "pubspec.yaml")
        found.extend(sorted(package.rglob("README.md")))
        found.extend(sorted((package / "lib").rglob("*.dart")))
    return [
        path
        for path in found
        if path.exists() and not {".dart_tool", "build", "node_modules"} & set(path.parts)
    ]


def links(path: Path) -> list[str]:
    text = path.read_text()
    if path.suffix == ".dart":
        text = ADJACENT_LITERALS.sub("", text)
    return [match.group(0).rstrip(".,;:!?*_") for match in LINK.finditer(text)]


def slug(heading: str) -> str:
    """The id the docs site gives a heading, as github-slugger makes it."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", heading)  # links keep their text
    text = re.sub(r"<[^>]+>", "", text)  # inline HTML keeps its text
    text = text.replace("`", "").replace("*", "").strip()
    return re.sub(r"[^\w\- ]", "", text.lower()).replace(" ", "-")


def anchors(page: Path) -> set[str]:
    text = FENCE.sub("", page.read_text())
    found = set(HTML_ID.findall(text))
    seen: dict[str, int] = {}
    for heading in HEADING.findall(text):
        base = slug(heading)
        anchor = base
        # A repeated heading gets -1, -2, and so on.
        while anchor in seen:
            seen[base] += 1
            anchor = f"{base}-{seen[base]}"
        seen[anchor] = 0
        found.add(anchor)
    return found


def find_page(path: str) -> Path | None:
    for candidate in (f"{path}.md", f"{path}.mdx", f"{path}/index.md", f"{path}/index.mdx"):
        page = DOCS / candidate
        if page.is_file():
            return page
    return None


def check(root: Path) -> list[str]:
    problems = []
    for source in sources(root):
        for link in links(source):
            url, _, anchor = link.partition("#")
            path = re.sub(r"^.*?galaxykhh\.github\.io/fuery/", "", url).split("?")[0].strip("/")
            if not path or path == "demo" or path.startswith("demo/"):
                continue
            if "." in path.rsplit("/", 1)[-1]:
                continue  # a file, such as an image, not a page
            where = source.relative_to(root)
            page = find_page(path)
            if page is None:
                problems.append(f"{where}: {link}: no page docs/src/content/docs/{path}.md")
            elif anchor and anchor not in anchors(page):
                problems.append(
                    f"{where}: {link}: no heading #{anchor} in {page.relative_to(root)}"
                )
    return problems


def main() -> int:
    problems = check(ROOT)
    if problems:
        print("Links to the docs site that don't resolve:")
        for problem in problems:
            print(f"  {problem}")
        return 1
    print("Every link to the docs site resolves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
