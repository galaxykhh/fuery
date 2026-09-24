#!/usr/bin/env python3
"""Fails unless the packages are ready to be released together.

Usage: python3 tool/check_versions.py

Checks that fuery_core, fuery, and fuery_hooks have the same version, and
that fuery depends on `fuery_core: ^<version>` and fuery_hooks on
`fuery: ^<version>`. The workspace always resolves the local packages, so a
stale lower bound passes every other check and only breaks apps that resolve
from pub.dev.

On a tag push (GITHUB_REF_TYPE=tag), it also checks that the tag is
`v<version>` and that each package's CHANGELOG.md has a `## <version>` entry,
which the release notes are built from.
"""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ["fuery_core", "fuery", "fuery_hooks"]
# The package each one depends on at the same version.
DEPENDS_ON = {"fuery": "fuery_core", "fuery_hooks": "fuery"}


def read_version(pubspec: str) -> str | None:
    match = re.search(r"^version:\s*['\"]?([^'\"\s#]+)", pubspec, re.MULTILINE)
    return match.group(1) if match else None


def read_dependency(pubspec: str, name: str) -> str | None:
    """Returns the constraint of [name] in the `dependencies:` block."""
    block = re.search(r"^dependencies:\n((?:[ \t]+.*\n|[ \t]*\n)*)", pubspec, re.MULTILINE)
    if block is None:
        return None
    match = re.search(
        rf"^[ \t]+{re.escape(name)}:[ \t]*['\"]?([^'\"\n#]*?)['\"]?[ \t]*(?:#.*)?$",
        block.group(1),
        re.MULTILINE,
    )
    return match.group(1) if match else None


def check(root: Path, env: dict[str, str]) -> list[str]:
    errors = []
    pubspecs = {}
    versions = {}
    for package in PACKAGES:
        path = root / "packages" / package / "pubspec.yaml"
        pubspecs[package] = path.read_text()
        version = read_version(pubspecs[package])
        if version is None:
            errors.append(f"{path.relative_to(root)}: no version")
        else:
            versions[package] = version

    if len(set(versions.values())) > 1:
        found = ", ".join(f"{package} {version}" for package, version in versions.items())
        errors.append(f"the packages must have the same version, found: {found}")

    version = versions.get("fuery_core")
    if version is None:
        return errors

    for package, dependency in DEPENDS_ON.items():
        constraint = read_dependency(pubspecs[package], dependency)
        if constraint is None:
            errors.append(f"packages/{package}/pubspec.yaml: doesn't depend on {dependency}")
        elif constraint != f"^{version}":
            errors.append(
                f"packages/{package}/pubspec.yaml: depends on {dependency}: {constraint},"
                f" expected ^{version}"
            )

    if env.get("GITHUB_REF_TYPE") == "tag":
        tag = env.get("GITHUB_REF_NAME", "")
        if tag != f"v{version}":
            errors.append(f"the tag {tag} doesn't match the version, expected v{version}")
        for package in PACKAGES:
            changelog = root / "packages" / package / "CHANGELOG.md"
            if f"## {version}" not in changelog.read_text().splitlines():
                errors.append(f"{changelog.relative_to(root)}: no '## {version}' entry")

    return errors


def main() -> int:
    errors = check(ROOT, dict(os.environ))
    if errors:
        print("The packages aren't ready to release together:")
        for error in errors:
            print(f"  {error}")
        return 1
    print("The packages have the same version, and depend on each other at it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
