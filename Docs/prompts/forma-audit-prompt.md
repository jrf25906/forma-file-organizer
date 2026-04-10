# Forma Audit Prompt

> Reusable prompt for auditing the Forma macOS app for bugs, performance
> issues, and layout regressions. Fill in the variables below and hand the
> whole thing to a fresh Claude Code session.

## Variables

- **CURRENT_SYMPTOMS:** <list of user-observed symptoms, one per line, with
  where/what/frequency>
- **SCOPE:** `laser` | `hotspot-sweep` | `full-audit`
- **MODE:** `find-only` | `find+propose` | `find+apply-low-risk`
- **REPORT_PATH:** defaults to `Docs/audits/YYYY-MM-DD-forma-audit.md`

---

## Prompt body (copy everything below this line into the session)

You are auditing the Forma macOS app. Read `CLAUDE.md` first for
architecture, conventions, and file paths. Do NOT modify any source files
under `Forma File Organizing/` unless MODE is `find+apply-low-risk` and
the fix has `Risk: low` and `Confidence: high`.

### Seeded symptoms
<paste CURRENT_SYMPTOMS here>

### Scope
<paste SCOPE here>

### Mode
<paste MODE here>

### Orchestration

Dispatch these four subagents IN PARALLEL in a single message using the
`Agent` tool. Each subagent gets its own brief below. Wait for all four
to return, then synthesize.

**Agent 1 — Reproduction** (`subagent_type: screenshot-orchestrator`)
Build Forma via `mcp__xcodebuildmcp__build_run_macos` using project
`Forma File Organizing.xcodeproj` and scheme `Forma File Organizing`.
Launch the app via `mcp__xcodebuildmcp__launch_mac_app`. For each seeded
symptom, reproduce it and capture evidence:
- Use `mcp__xcodebuildmcp__screenshot` for visual state.
- Use `mcp__xcodebuildmcp__describe_ui` for structural state.
- Record observed timings where measurable.
- To reproduce file-drop / rescan symptoms, copy a throwaway temp file
  (created via `/bin/mkdir -p` and `/usr/bin/touch` in a temp dir) into
  a Forma-watched folder, observe the rescan, then delete the temp
  file. Do NOT touch pre-existing user files.
- Save screenshots to `Docs/audits/YYYY-MM-DD-forma-audit/screenshots/`.
Return: annotated evidence, timings, exact reproduction steps. No
source modifications. Output to
`Docs/audits/YYYY-MM-DD-forma-audit/agent-1-reproduction.md`.

**Agent 2 — Performance** (`subagent_type: performance-optimizer`)
Source-level hotspot audit. Focus areas:
- Main-thread SwiftData fetches (`@Query` on large datasets,
  `modelContext.fetch` off `@MainActor`, missing `fetchLimit` or
  predicates).
- Missing `LazyVStack`/`LazyVGrid` on large lists. Smart Rules
  inspector is a known suspect (~1,574 rules observed).
- `@Observable` / `@Published` cascade storms.
- Chained `.onChange` cascades.
- `FileManager` / IO on `@MainActor`.
- `FileScanPipeline` debouncing and cancellation.
- `NavigationSplitView` column rebuild patterns.
Return findings in the standard shape below. Output to
`Docs/audits/YYYY-MM-DD-forma-audit/agent-2-performance.md`.

**Agent 3 — Bug hunter** (`subagent_type: Explore`, thoroughness:
`very thorough`)
Correctness sweep:
- Security-scoped bookmark leaks (`startAccessingSecurityScopedResource`
  without matching `stop...` on all paths).
- SwiftData unique-constraint risks on `FileItem.path`.
- Swallowed throws (`try?`, empty `catch`). Cross-reference
  `SILENT_FAILURES_REMEDIATION.md`.
- Feature flag gating misses (ML features must gate at entry point via
  `FeatureFlagService.shared.isEnabled(...)`).
- Undo/redo integrity in `ActivityLoggingService`.
- Rule precedence correctness in `FileScanPipeline`.
Return findings in the standard shape below. Output to
`Docs/audits/YYYY-MM-DD-forma-audit/agent-3-bug-hunter.md`.

**Agent 4 — Layout** (`subagent_type: Explore`, thoroughness: `medium`)
SwiftUI layout audit:
- Toolbar item identity thrash on `NavigationSplitView` rebuild.
- `.id(UUID())` or equivalent patterns that trash state.
- Hardcoded colors/sizes vs `FormaColors`/`FormaSpacing`/
  `FormaTypography`.
- Small-window breakage across the four file-row surfaces listed in
  `CLAUDE.md`:
  `Forma File Organizing/Views/Components/FileRow.swift`,
  `Forma File Organizing/Components/FileListRow.swift`,
  `Forma File Organizing/Components/FileGridItem.swift`,
  `Forma File Organizing/Views/MainContentView.swift`.
- Design token drift — unprefixed reusable components.
Return findings in the standard shape below. Output to
`Docs/audits/YYYY-MM-DD-forma-audit/agent-4-layout.md`.

### Finding shape (every finding, every subagent)

```
### [P0|P1|P2] <one-line title>
File: <path>:<line>
Observed: <symptom, measured where possible>
Root cause: <the actual defect>
Proposed fix: <concrete change>
Risk: <low|med|high> — <why>
Confidence: <low|med|high>
```

Priorities:
- **P0** — Directly causes a seeded symptom.
- **P1** — High-confidence contributor to general "messy" feeling.
- **P2** — Adjacent issue found during sweep, not yet user-visible.

### Synthesis

After all four subagents return, write `REPORT_PATH` with this
structure:

1. **Executive summary** — one paragraph naming the root cause(s) of
   the user's overall pain.
2. **P0 — Seeded symptoms, root-caused** — one finding per seeded
   symptom.
3. **P1 — High-confidence contributors.**
4. **P2 — Adjacent issues.**
5. **Appendix: Evidence** — screenshots and timings from Agent 1.

Every finding from every subagent must appear in the synthesized
report. Do not summarize findings away. Cite `file:path:line` for every
claim.

### Guardrails

- No changes outside `Forma File Organizing/` and its test targets.
- Do not skip git hooks or bypass tests.
- Each subagent report must fit in ~300 lines.
- In `find+apply-low-risk` mode, any applied fix must have
  `Risk: low` and `Confidence: high`, and must still appear in the
  report with an "Applied" marker.
