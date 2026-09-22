#!/usr/bin/env python3
"""Fails unless every package given has 100% line coverage.

Usage: python3 tool/check_coverage.py packages/fuery_core packages/fuery

Reads `<package>/coverage/lcov.info`, written by
`dart pub global run coverage:test_with_coverage` (Dart packages) or
`flutter test --coverage` (Flutter packages). A file under `lib/` that the
report doesn't mention counts as uncovered unless it holds nothing but
library, export, import, part, and const declarations, which have no lines
to run.
"""

import re
import sys
from pathlib import Path

COMMENTS = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)
# Statements that produce no executable line, so a file made only of them
# never appears in a report: the barrel files and the `part` host.
DECLARATION = re.compile(r"^(library|export|import|part|const)\b")


def parse_lcov(path: Path) -> dict[Path, list[int]]:
    """Returns the uncovered line numbers per source file."""
    uncovered: dict[Path, list[int]] = {}
    current: Path | None = None
    for line in path.read_text().splitlines():
        if line.startswith("SF:"):
            current = Path(line[3:])
            if not current.is_absolute():
                current = path.parent.parent / current
            uncovered[current.resolve()] = []
        elif line.startswith("DA:") and current is not None:
            number, hits = line[3:].split(",")[:2]
            if int(hits) == 0:
                uncovered[current.resolve()].append(int(number))
    return uncovered


def has_code(path: Path) -> bool:
    source = COMMENTS.sub("", path.read_text())
    statements = (s.strip() for s in source.split(";"))
    return any(s and not DECLARATION.match(s) for s in statements)


def check(package: Path) -> list[str]:
    report = package / "coverage" / "lcov.info"
    if not report.exists():
        return [f"{report} is missing; run the tests with coverage first"]

    problems = []
    uncovered = parse_lcov(report)
    for source, lines in sorted(uncovered.items()):
        if lines:
            shown = ", ".join(str(n) for n in lines[:20])
            more = f" and {len(lines) - 20} more" if len(lines) > 20 else ""
            problems.append(f"{source.relative_to(package.resolve())}: lines {shown}{more}")

    for source in sorted((package / "lib").rglob("*.dart")):
        if source.resolve() not in uncovered and has_code(source):
            problems.append(f"{source.relative_to(package)}: not in the coverage report")

    return problems


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    failed = False
    for name in argv[1:]:
        package = Path(name)
        problems = check(package)
        if problems:
            failed = True
            print(f"{package}: not fully covered")
            for problem in problems:
                print(f"  {problem}")
        else:
            print(f"{package}: 100% line coverage")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
