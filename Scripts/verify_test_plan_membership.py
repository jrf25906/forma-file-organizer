#!/usr/bin/env python3
"""Verify Xcode test plans explicitly list the suites they own."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_TESTS_DIR = ROOT / "Forma File OrganizingTests"
UI_TESTS_DIR = ROOT / "Forma File OrganizingUITests"

APP_TEST_TARGET = "Forma File OrganizingTests"
UI_TEST_TARGET = "Forma File OrganizingUITests"

DEFAULT_PLAN = ROOT / "Forma File Organizing.xctestplan"
UNIT_PLAN = ROOT / "Forma File Organizing - Unit.xctestplan"
INTEGRATION_PLAN = ROOT / "Forma File Organizing - Integration.xctestplan"
PERFORMANCE_PLAN = ROOT / "Forma File Organizing - Performance.xctestplan"
UI_PLAN = ROOT / "Forma File Organizing - UI.xctestplan"


@dataclass(frozen=True)
class Suite:
    name: str
    relative_path: str
    text: str
    target: str


def swift_files(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.swift"))


def suites_in_file(path: Path, target: str) -> list[Suite]:
    text = path.read_text(encoding="utf-8")
    names: set[str] = set()

    for match in re.finditer(
        r"\b(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*XCTestCase\b",
        text,
    ):
        names.add(match.group(1))

    if "@Test" in text:
        for match in re.finditer(
            r"\b(?:final\s+)?(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_]*)\b",
            text,
        ):
            name = match.group(1)
            if name.endswith("Tests"):
                names.add(name)

    relative_path = str(path.relative_to(ROOT))
    return [
        Suite(name=name, relative_path=relative_path, text=text, target=target)
        for name in sorted(names)
    ]


def discover_suites() -> list[Suite]:
    suites: list[Suite] = []
    for path in swift_files(APP_TESTS_DIR):
        suites.extend(suites_in_file(path, APP_TEST_TARGET))
    for path in swift_files(UI_TESTS_DIR):
        suites.extend(suites_in_file(path, UI_TEST_TARGET))
    return sorted(suites, key=lambda suite: (suite.target, suite.name))


def is_integration_suite(suite: Suite) -> bool:
    if suite.target != APP_TEST_TARGET:
        return False

    return bool(
        re.search(
            r"^\s*(try\s+TestGating\.requireIntegration\(\)|guard\s+requireIntegration\(\)\s+else)",
            suite.text,
            re.MULTILINE,
        )
    )


def is_performance_suite(suite: Suite) -> bool:
    if suite.target != APP_TEST_TARGET:
        return False

    return (
        "Benchmarks" in suite.name
        or bool(
            re.search(
                r"^\s*try\s+TestGating\.requirePerformance\(\)",
                suite.text,
                re.MULTILINE,
            )
        )
    )


def selected_tests(plan_path: Path, target_name: str) -> set[str] | None:
    data = json.loads(plan_path.read_text(encoding="utf-8"))
    for test_target in data.get("testTargets", []):
        target = test_target.get("target", {})
        if target.get("name") != target_name:
            continue

        selected = test_target.get("selectedTests")
        if selected is None:
            return None

        return set(selected)

    raise ValueError(f"{plan_path.name} does not contain target {target_name!r}")


def assert_plan(
    errors: list[str],
    plan_path: Path,
    target_name: str,
    expected: set[str],
) -> None:
    selected = selected_tests(plan_path, target_name)
    label = f"{plan_path.name} target {target_name}"

    if selected is None:
        errors.append(
            f"{label} has no selectedTests; expected {len(expected)} explicit suite entries"
        )
        return

    missing = sorted(expected - selected)
    extra = sorted(selected - expected)

    if missing:
        errors.append(f"{label} is missing selectedTests: {', '.join(missing)}")
    if extra:
        errors.append(f"{label} has stale selectedTests: {', '.join(extra)}")


def main() -> int:
    suites = discover_suites()
    app_suites = {suite.name for suite in suites if suite.target == APP_TEST_TARGET}
    ui_suites = {suite.name for suite in suites if suite.target == UI_TEST_TARGET}
    integration_suites = {suite.name for suite in suites if is_integration_suite(suite)}
    performance_suites = {suite.name for suite in suites if is_performance_suite(suite)}
    unit_suites = app_suites - integration_suites - performance_suites

    errors: list[str] = []
    assert_plan(errors, DEFAULT_PLAN, APP_TEST_TARGET, app_suites)
    assert_plan(errors, DEFAULT_PLAN, UI_TEST_TARGET, ui_suites)
    assert_plan(errors, UNIT_PLAN, APP_TEST_TARGET, unit_suites)
    assert_plan(errors, INTEGRATION_PLAN, APP_TEST_TARGET, integration_suites)
    assert_plan(errors, PERFORMANCE_PLAN, APP_TEST_TARGET, performance_suites)
    assert_plan(errors, UI_PLAN, UI_TEST_TARGET, ui_suites)

    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print(
        "Test plan membership verified: "
        f"{len(unit_suites)} unit, "
        f"{len(integration_suites)} integration, "
        f"{len(performance_suites)} performance, "
        f"{len(ui_suites)} UI suites."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
