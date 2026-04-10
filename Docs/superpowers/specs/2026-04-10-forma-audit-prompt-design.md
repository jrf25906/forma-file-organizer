# Forma Audit Prompt — Design

**Date:** 2026-04-10
**Author:** James Farmer (brainstormed with Claude)
**Status:** Draft, awaiting user review

## Purpose

Forma currently feels slow and "messy" in daily use — the right-panel toggle
lags, the left-panel toolbar icon visually glitches when panels rebuild,
file drops trigger hitches, and general input latency makes the app feel
unpolished. Rather than chase symptoms one at a time, this design produces:

1. **A reusable audit prompt template** that orchestrates a multi-agent
   investigation across bugs, performance, and layout — runnable any time
   Forma feels off.
2. **One immediate seeded execution** of that template targeting the
   symptoms observed on 2026-04-10.

The output of every run is a single prioritized findings report with
concrete, file-scoped proposed fixes that the user approves before any
code changes.

## Seeded symptoms (2026-04-10 run)

These are the symptoms the one-shot run must reproduce and root-cause:

1. **Right-panel toggle lag** — Opening the right inspector panel shows the
   macOS spinning cursor and hitches the sidebar. In the observed state the
   panel contained the Smart Rules view rendering ~1,574 rules.
2. **Toolbar icon glitch (left panel)** — The left-panel toolbar toggle
   icon visually "messes up" when the right panel is opened, consistent
   with a SwiftUI toolbar rebuild / view-identity thrash on
   `NavigationSplitView` updates.
3. **File drop → rescan is not seamless** — Dropping a file on the Desktop
   triggers a rescan, which is correct behavior, but the UI visibly
   stutters during the scan.
4. **General input latency** — "Every button feels messy," suggesting
   main-thread contention across the app, not an isolated view.

## Scope (this run)

`full-audit` — the most aggressive of the three scope options considered:

- `laser` — one agent per seeded symptom (fastest, misses adjacent issues)
- `hotspot-sweep` — laser + one broader perf audit
- **`full-audit`** — hotspot-sweep + codebase-wide bug and layout hunt

## Mode (this run)

`find+propose` — subagents identify issues and propose fixes in a
standardized finding shape, but **do not apply any changes**. The user
approves each fix in a follow-up implementation session.

Rationale: the last four commits on `main` are all stabilization work
(`Stabilize UI suite integration probes`, `Stabilize macOS UI regression
suite`, `Fix grid destination parity for file surfaces`, `Polish review
flow follow-up`). Introducing unreviewed automated fixes mid-audit is
the wrong risk profile right now.

## Orchestration

The main agent dispatches **four subagents in parallel in a single
message**, each with a tightly scoped brief. Each subagent returns a
compact report (~300 lines max) using the standard finding shape. The
main agent then synthesizes all four into one prioritized report.

### Agent 1 — Reproduction (`screenshot-orchestrator`)

**Purpose:** Drive the real app to capture ground-truth evidence of the
seeded symptoms.

**Tools required:** `mcp__xcodebuildmcp__build_run_macos`,
`mcp__xcodebuildmcp__launch_mac_app`, `mcp__xcodebuildmcp__screenshot`,
`mcp__xcodebuildmcp__describe_ui`, `mcp__xcodebuildmcp__stop_mac_app`.

**Tasks:**
- Build Forma from `Forma File Organizing.xcodeproj` using the
  `Forma File Organizing` scheme.
- Launch the app and drive it to reproduce each seeded symptom:
  - Cold launch → toggle right panel → capture timing and
    before/after screenshots.
  - Simulate a file drop into a Forma-watched folder by copying a
    small throwaway file (created via `FileManager` in a temp dir)
    into the target folder, observing the rescan, and deleting the
    file afterward. The subagent must not modify any pre-existing
    user files. Capture UI timing and any stutter during the scan.
  - Toggle panels in sequence to reproduce the toolbar icon glitch.
  - Navigate to Smart Rules in the right panel; observe load time
    and scroll performance on the ~1,574-row list.
- Return: annotated screenshots, observed timings, exact reproduction
  steps. No code changes, no fix proposals.

**Constraint:** The subagent must not modify source files. Its output
is evidence only.

### Agent 2 — Performance (`performance-optimizer`)

**Purpose:** Source-level hotspot audit focused on root causes of
main-thread contention.

**Focus areas:**
- Main-thread SwiftData fetches — `@Query` on views that load large
  datasets synchronously, `modelContext.fetch` calls off the
  `@MainActor` boundary, missing predicates/`fetchLimit`.
- Missing lazy containers — especially any `VStack`/`ForEach` chains
  over large datasets where `LazyVStack`/`LazyVGrid` is required.
  The Smart Rules inspector is a known suspect.
- `@Observable` / `@Published` cascades — views that re-render on
  every keystroke or selection change because of unfiltered
  observation.
- `onChange` cascade storms — chained `.onChange` modifiers that
  re-trigger each other.
- `FileManager` / IO on `@MainActor` — any file system call that
  blocks the main actor.
- `FileScanPipeline` debounce and cancellation — file-system event
  debouncing, cancellation of in-flight scans on new events.
- `NavigationSplitView` column rebuild patterns — identity and
  sizing issues that cause full rebuilds on panel toggle.

### Agent 3 — Bug hunter (`Explore`, very thorough)

**Purpose:** Correctness audit across the codebase.

**Focus areas:**
- Security-scoped bookmark leaks — every call to
  `startAccessingSecurityScopedResource` must have a matching
  `stop...` on all paths.
- SwiftData unique-constraint risks — `FileItem.path` uniqueness
  under concurrent scan / merge scenarios.
- Swallowed throws — `try?` and empty `catch` blocks that hide
  meaningful failures (see `SILENT_FAILURES_REMEDIATION.md`).
- Feature flag gating — all ML features must be gated at entry
  points via `FeatureFlagService.shared.isEnabled(...)`.
- Undo/redo integrity — command pattern in `ActivityLoggingService`,
  verify every mutating operation is reversible.
- Rule precedence correctness — `FileScanPipeline` rule evaluation
  order, matching semantics.

### Agent 4 — Layout (`Explore`, medium thoroughness)

**Purpose:** SwiftUI layout audit focused on the toolbar glitch and
design-system drift.

**Focus areas:**
- Toolbar item identity — `.id()` misuse on toolbar items causing
  state loss on `NavigationSplitView` rebuild.
- View identity thrash — `.id(UUID())` patterns or equivalent that
  break state across updates.
- Hardcoded sizes and colors — anything that should use
  `FormaColors`, `FormaSpacing`, or `FormaTypography` tokens.
- Small-window breakage — all four file-row surfaces listed in
  `CLAUDE.md` must render correctly at minimum window size:
  `Forma File Organizing/Views/Components/FileRow.swift`,
  `Forma File Organizing/Components/FileListRow.swift`,
  `Forma File Organizing/Components/FileGridItem.swift`,
  `Forma File Organizing/Views/MainContentView.swift`.
- Design token drift — components not prefixed with `Forma` that
  should be, or reusable patterns open for extraction.

## Finding shape

Every finding from every subagent uses this exact shape so the final
report is scannable and each finding can be handed to an implementation
session independently:

```
### [P0|P1|P2] <one-line title>
File: <path>:<line>
Observed: <symptom, measured where possible>
Root cause: <the actual defect>
Proposed fix: <concrete change>
Risk: <low|med|high> — <why>
Confidence: <low|med|high>
```

**Priorities:**
- **P0** — Directly causes a seeded symptom.
- **P1** — High-confidence contributor to the general "messy" feeling.
- **P2** — Adjacent issue found during the sweep, not directly
  user-visible yet.

## Synthesis (main agent)

After all four subagents return, the main agent writes a single report
to `docs/audits/2026-04-10-forma-audit.md` with this structure:

1. **Executive summary** — one paragraph naming the root cause(s) of
   "every button feels messy."
2. **P0 — Seeded symptoms, root-caused** — one finding per seeded
   symptom, linked to the source file and the specific defect.
3. **P1 — High-confidence contributors** — issues agents found that
   likely feed the same user-visible pain.
4. **P2 — Adjacent issues** — bugs and perf issues found during the
   sweep, not yet user-visible.
5. **Appendix: Evidence** — annotated screenshots and timings from
   Agent 1, grouped by symptom.

## Reusable template

The reusable form will be written during the implementation phase
(task 1 of the plan) to `docs/prompts/forma-audit-prompt.md`. It is
NOT written as part of this design doc. Parameterized slots:

- `{{current_symptoms}}` — the seeded user-observed pain points for
  the run.
- `{{scope}}` — `laser`, `hotspot-sweep`, or `full-audit`.
- `{{mode}}` — `find-only`, `find+propose`, or `find+apply-low-risk`.
- `{{report_path}}` — defaults to
  `docs/audits/YYYY-MM-DD-forma-audit.md`.

The template body is the Orchestration + Finding shape + Synthesis
sections of this doc, with the slots above substituted in.

## Guardrails (every run, every mode)

- Subagents must not modify files outside `Forma File Organizing/`
  and its test targets.
- Subagents must not skip git hooks or bypass tests.
- `find+apply-low-risk` mode (not used in this run) requires that any
  applied fix have `Risk: low` and `Confidence: high`, and must still
  be surfaced in the report with a "Applied" marker.
- Each subagent report must fit in ~300 lines. Subagents must cite
  `file:path:line` for every claim.
- The main agent must not summarize findings away — every subagent
  finding appears in the final report, even if deprioritized.

## Non-goals

- **No automated fixes in this run.** The user explicitly wants to
  review before any code changes land.
- **No scope outside the macOS app.** The `forma-website/` and
  marketing assets are out of scope for this audit.
- **No new feature work.** Findings must be defects or perf issues,
  not feature suggestions.
- **No architectural rewrites.** Proposed fixes should be surgical
  and scoped to the defect. Large refactors become separate design
  docs.

## Success criteria

- All four seeded symptoms are reproduced with evidence and
  root-caused to specific source locations.
- The final report contains at least the P0 section, populated with
  concrete proposed fixes the user can triage.
- No source files are modified during the run (mode is
  `find+propose`).
- The reusable template exists and can be re-run with different
  seeded symptoms without re-brainstorming the orchestration.
