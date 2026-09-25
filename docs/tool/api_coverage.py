#!/usr/bin/env python3
"""Check which of the public API the documentation site mentions.

Run from the repository root:

    python3 docs/tool/api_coverage.py            # writes docs/api-coverage.md
    python3 docs/tool/api_coverage.py --check    # exits 1 on new gaps

The public API comes from `dart doc`, which is the same list pub.dev shows.
Named options and filter arguments don't appear there, so those are read from
the source signatures instead.

An entry counts as covered when its name appears anywhere in the docs site.
That is a low bar on purpose: it catches API a reader cannot even learn the
name of. It says nothing about whether the explanation is any good.

Entries nobody writing an app needs are listed in coverage_ignore.txt with the
reason, so the report stays a to-do list rather than a wall of noise.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs" / "src" / "content" / "docs"
REPORT = ROOT / "docs" / "api-coverage.md"
IGNORE = Path(__file__).parent / "coverage_ignore.txt"
PACKAGES = [
    ROOT / "packages" / "fuery_core",
    ROOT / "packages" / "fuery",
    ROOT / "packages" / "fuery_hooks",
]

# dartdoc's numeric kinds, as they appear in index.json.
CLASS, ENUM, FUNCTION, METHOD, FIELD, CONSTANT, VARIABLE, TYPEDEF = 3, 5, 8, 10, 16, 19, 20, 21
TOP_LEVEL = {CLASS: "Types", ENUM: "Types", TYPEDEF: "Types",
             FUNCTION: "Top-level functions", CONSTANT: "Top-level values",
             VARIABLE: "Top-level values"}

# Members are only checked on the types an app actually holds and reads.
# dartdoc lists a member the slots inherit, such as `listen`, only under
# ObserverSlot, so that is checked too.
MEMBERS_OF = {
    "QueryClient", "QueryObserver", "InfiniteQueryObserver", "MutationObserver",
    "NoVariablesMutationObserver", "QueryResult", "InfiniteQueryResult", "InfiniteData",
    "MutationResult", "ObserverSlot", "QuerySlot", "InfiniteQuerySlot", "MutationSlot",
    "QueriesSlot", "MutationStateSlot",
    "MutationState", "QueryState", "Fuery", "QueryStorage", "QueryPersist",
    "InfiniteQueryPersist", "FueryFocusManager", "OnlineManager", "NotifyManager",
    "AbortSignal", "QueryCache", "MutationCache",
}

# Inherited from Object; not this package's API.
FROM_OBJECT = {"toString", "hashCode", "noSuchMethod", "runtimeType", "operator =="}

# Signatures whose named arguments a reader has to know: file, then the
# declaration to read arguments from.
SIGNATURES = [
    ("Query options", "fuery_core/lib/src/query.dart", r"\n  const Query\((?=\{)"),
    ("Infinite query options", "fuery_core/lib/src/infinite_query.dart", r"\n  InfiniteQuery\((?=\{)"),
    ("Mutation options", "fuery_core/lib/src/mutation_state.dart", r"\n  const Mutation\((?=\{)"),
    ("Query filters", "fuery_core/lib/src/query_client.dart", r"Future<void> invalidateQueries\("),
    ("Mutation filters", "fuery_core/lib/src/query_client.dart", r"int isMutating\("),
]


# Sections that list named arguments rather than API names, each with the
# page whose reference table is allowed to stand in for a written call.
ARGUMENTS = {
    "Query options": "reference/query-options.md",
    "Infinite query options": "reference/query-options.md",
    "Mutation options": "reference/query-options.md",
    "Query filters": "reference/query-client.md",
    "Mutation filters": "reference/query-client.md",
}


def public(name: str) -> bool:
    return not name.startswith("_") and "._" not in name


def dart_doc_index(package: Path, cache: Path) -> list[dict]:
    """Return the dartdoc index for one package, generating it if needed."""
    index = cache / package.name / "index.json"
    if not index.exists():
        subprocess.run(["dart", "doc", "--output", str(cache / package.name)],
                       cwd=package, check=True, stdout=subprocess.DEVNULL)
    return json.loads(index.read_text())


def collect(cache: Path) -> dict[str, list[str]]:
    """Group the public API into the sections of the report."""
    sections: dict[str, set[str]] = {}
    for package in PACKAGES:
        for entry in dart_doc_index(package, cache):
            name, kind = entry["name"], entry["kind"]
            if not public(entry["qualifiedName"]):
                continue
            if kind in TOP_LEVEL:
                sections.setdefault(TOP_LEVEL[kind], set()).add(name)
            elif kind in (METHOD, FIELD):
                owner = entry.get("enclosedBy", {}).get("name", "")
                if owner in MEMBERS_OF and name not in FROM_OBJECT:
                    sections.setdefault(f"{owner} members", set()).add(f"{owner}.{name}")
    for title, args in named_arguments().items():
        sections[title] = args
    return {title: sorted(names) for title, names in sections.items()}


def named_arguments() -> dict[str, set[str]]:
    """Read named arguments straight from the source signatures."""
    found: dict[str, set[str]] = {}
    for title, relative, pattern in SIGNATURES:
        source = (ROOT / "packages" / relative).read_text()
        match = re.search(pattern, source)
        if not match:  # the signature moved; better to fail loudly than to pass
            raise SystemExit(f"api_coverage: no match for {title} in {relative}")
        args, depth = "", 0
        for char in source[match.end() - 1:]:
            depth += (char == "(") - (char == ")")
            args += char
            if depth == 0:
                break
        found[title] = {
            name for name in re.findall(r"(?:required\s+)?[\w<>,?\s\.]+?\s+(\w+)\s*(?:=[^,]+)?,", args)
            if public(name)
        } | {name for name in re.findall(r"(?:this|super)\.(\w+)", args) if public(name)}
    return found


def docs_text() -> str:
    return "\n".join(p.read_text() for p in sorted(DOCS.rglob("*.md*")))


def code_only(text: str) -> str:
    """The fenced blocks and inline code spans, with the prose dropped.

    Prose is full of traps: a sentence can end in "the type:", which reads
    like a named argument, and words like `reason` and `listeners` are
    ordinary English. Only code decides whether a lowercase name is used.
    """
    fenced = re.findall(r"```.*?```", text, re.S)
    prose = re.sub(r"```.*?```", "", text, flags=re.S)
    return "\n".join(fenced + re.findall(r"`[^`\n]+`", prose))


def covered_argument(name: str, code: str, reference: str) -> bool:
    """True when the docs pass the argument, or list it in its reference table.

    A bare name is not enough anywhere else: `stale` is also a status in the
    devtools table, and matching that would report the filter argument as
    documented.
    """
    word = re.escape(name)
    if re.search(rf"\b{word}\s*:", code) or re.search(rf"^\|\s*`{word}`", reference, re.M):
        return True
    # `maxPages` names nothing else, so a guide that writes it counts too.
    # `stale` and `type` are not that lucky.
    return (any(char.isupper() for char in name)
            and re.search(rf"`{word}`", code) is not None)


def covered(name: str, text: str, code: str) -> bool:
    """True when the docs mention the name."""
    plain = name.split(".")[-1]
    word = re.escape(plain)
    # A name with a capital in it, like InfiniteData or isFetchingNextPage,
    # reads as itself wherever it appears, headings and prose included.
    if any(char.isupper() for char in plain):
        return re.search(rf"\b{word}\b", text) is not None
    # A lowercase name has to appear as code to count.
    return re.search(rf"\b{word}\b", code) is not None


def ignored() -> dict[str, str]:
    if not IGNORE.exists():
        return {}
    entries = {}
    for line in IGNORE.read_text().splitlines():
        line = line.split("#")[0].strip()
        if line:
            name, _, reason = line.partition(":")
            entries[name.strip()] = reason.strip()
    return entries


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="exit 1 when anything is uncovered")
    parser.add_argument("--cache", type=Path, help="reuse dart doc output from this directory")
    options = parser.parse_args()

    cache = options.cache or Path(tempfile.mkdtemp(prefix="fuery-api-"))
    try:
        sections = collect(cache)
    finally:
        if not options.cache:
            shutil.rmtree(cache, ignore_errors=True)

    text, skip = docs_text(), ignored()
    code = code_only(text)
    references = {title: (DOCS / page).read_text() for title, page in ARGUMENTS.items()}

    def hidden(name: str) -> bool:
        return any(fnmatch.fnmatch(name, pattern) for pattern in skip)
    lines = ["# API coverage", "",
             "Which of the public API the documentation site mentions at least once.",
             "Generated by `python3 docs/tool/api_coverage.py`; don't edit by hand.", ""]
    gaps: list[str] = []
    counts = []
    for title, names in sections.items():
        rows, missing = [], 0
        for name in names:
            if hidden(name):
                continue
            found = (covered_argument(name, code, references[title])
                     if title in ARGUMENTS else covered(name, text, code))
            if found:
                rows.append(f"| `{name}` | ✅ |")
            else:
                rows.append(f"| `{name}` | ❌ |")
                gaps.append(name)
                missing += 1
        if not rows:
            continue
        counts.append((title, len(rows) - missing, len(rows)))
        lines += [f"## {title}", "", f"{len(rows) - missing} of {len(rows)} mentioned.", "",
                  "| Name | In the docs |", "|---|---|", *rows, ""]
    total_ok = sum(ok for _, ok, _ in counts)
    total = sum(all_ for _, _, all_ in counts)
    lines[4:4] = [f"**{total_ok} of {total} mentioned.**", "",
                  "| Section | Mentioned |", "|---|---|",
                  *[f"| [{t}](#{t.lower().replace(' ', '-')}) | {ok}/{all_} |" for t, ok, all_ in counts], ""]
    REPORT.write_text("\n".join(lines) + "\n")

    print(f"{total_ok}/{total} of the public API is mentioned in the docs")
    print(f"report: {REPORT.relative_to(ROOT)}")
    if options.check and gaps:
        print(f"\n{len(gaps)} not mentioned anywhere:")
        for name in gaps:
            print(f"  {name}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
