#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]

DOC_GLOBS = [
    "Docs/**/*.md",
    "README.md",
    "CHANGELOG.md",
    "TODO.md",
    "API_REFERENCE.md",
    "CONTRIBUTING.md",
    "AGENTS.md",
    "WARP.md",
]

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")

SKIP_PREFIXES = (
    "http://",
    "https://",
    "mailto:",
    "tel:",
    "javascript:",
)

LEGACY_PATHS = {
    "Views/OnboardingFlowView.swift": "Views/Onboarding/OnboardingFlowView.swift",
    "/Views/OnboardingFlowView.swift": "Views/Onboarding/OnboardingFlowView.swift",
    "Views/SettingsView.swift": "Views/Settings/SettingsView.swift",
    "/Views/SettingsView.swift": "Views/Settings/SettingsView.swift",
}


def iter_doc_files() -> list[Path]:
    files: list[Path] = []
    for pattern in DOC_GLOBS:
        files.extend(ROOT.glob(pattern))
    return sorted({path for path in files if path.is_file()})


def normalize_target(target: str) -> str | None:
    target = target.strip()
    if not target:
        return None
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1].strip()
    if target.startswith("#"):
        return None
    for prefix in SKIP_PREFIXES:
        if target.startswith(prefix):
            return None
    target = target.split("#", 1)[0].split("?", 1)[0].strip()
    if not target:
        return None
    return unquote(target)


def resolve_target(base: Path, target: str) -> Path:
    if target.startswith("/"):
        return ROOT / target.lstrip("/")
    return (base / target).resolve()


def main() -> int:
    missing_links: list[tuple[Path, int, str]] = []
    legacy_refs: list[tuple[Path, int, str, str]] = []

    for path in iter_doc_files():
        text = path.read_text(encoding="utf-8")
        in_code_block = False
        for line_no, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("```") or stripped.startswith("~~~"):
                in_code_block = not in_code_block
                continue
            if in_code_block:
                continue
            for match in LINK_RE.finditer(line):
                raw_target = match.group(1)
                target = normalize_target(raw_target)
                if target is None:
                    continue
                candidate = resolve_target(path.parent, target)
                if not candidate.exists():
                    missing_links.append((path, line_no, raw_target))
            for legacy, replacement in LEGACY_PATHS.items():
                if legacy in line:
                    legacy_refs.append((path, line_no, legacy, replacement))

    if missing_links:
        print("Missing documentation links:")
        for path, line_no, target in missing_links:
            rel = path.relative_to(ROOT)
            print(f"  - {rel}:{line_no} -> {target}")
        print()

    if legacy_refs:
        print("Legacy path references:")
        for path, line_no, legacy, replacement in legacy_refs:
            rel = path.relative_to(ROOT)
            print(f"  - {rel}:{line_no} uses {legacy} (use {replacement})")
        print()

    if missing_links or legacy_refs:
        return 1

    print("Docs check OK: no missing links or legacy onboarding/settings paths.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
