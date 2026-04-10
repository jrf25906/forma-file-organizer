# Forma Audit Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Forma audit prompt template, then execute it once against the 2026-04-10 seeded symptoms to produce a prioritized findings report with proposed fixes.

**Architecture:** Two deliverables: (1) a parameterized prompt template saved to `Docs/prompts/forma-audit-prompt.md`; (2) one executed audit that dispatches 4 parallel subagents (reproduction via `screenshot-orchestrator`, perf via `performance-optimizer`, bug hunt via `Explore`, layout via `Explore`) and synthesizes their reports into `Docs/audits/2026-04-10-forma-audit.md`. No code changes are applied in this run (mode: `find+propose`).

**Tech Stack:** Markdown (prompt + reports), Claude Code subagents (`Agent` tool with `subagent_type`), macOS xcodebuild MCP tools (driven by `screenshot-orchestrator`), git for commits.

**Spec:** `Docs/superpowers/specs/2026-04-10-forma-audit-prompt-design.md`

---

## File Structure

- **Create:** `Docs/prompts/forma-audit-prompt.md` — Reusable parameterized audit prompt template.
- **Create:** `Docs/audits/2026-04-10-forma-audit.md` — Synthesized findings report from this run.
- **Create:** `Docs/audits/2026-04-10-forma-audit/agent-1-reproduction.md` — Raw Agent 1 (reproduction) output + screenshots.
- **Create:** `Docs/audits/2026-04-10-forma-audit/agent-2-performance.md` — Raw Agent 2 (performance) output.
- **Create:** `Docs/audits/2026-04-10-forma-audit/agent-3-bug-hunter.md` — Raw Agent 3 (bug hunter) output.
- **Create:** `Docs/audits/2026-04-10-forma-audit/agent-4-layout.md` — Raw Agent 4 (layout) output.
- **Create:** `Docs/audits/2026-04-10-forma-audit/screenshots/` — Evidence screenshots captured by Agent 1.
- **No source files in `Forma File Organizing/` are modified in this plan.**

The `Docs/prompts/` and `Docs/audits/` directories do not yet exist and will be created in Task 1 and Task 3 respectively.

---

## Task 1: Create the reusable audit prompt template

**Files:**
- Create: `Docs/prompts/forma-audit-prompt.md`

- [ ] **Step 1: Verify the target directory does not already exist**

Run:
```bash
ls "/Users/jamesfarmer/Developer/Application Prototype/Forma/Docs/prompts" 2>/dev/null || echo "does not exist"
```
Expected: `does not exist` (or if it exists, note any files present before continuing).

- [ ] **Step 2: Write the reusable template file**

Create `Docs/prompts/forma-audit-prompt.md` with exactly this content:

````markdown
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
````

- [ ] **Step 3: Verify the file was written correctly**

Run:
```bash
wc -l "/Users/jamesfarmer/Developer/Application Prototype/Forma/Docs/prompts/forma-audit-prompt.md"
```
Expected: approximately 120–140 lines.

- [ ] **Step 4: Commit**

```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma"
git add "Docs/prompts/forma-audit-prompt.md"
git commit -m "Add reusable Forma audit prompt template

Parameterized prompt that dispatches 4 parallel subagents
(reproduction, performance, bug hunter, layout) and synthesizes a
single findings report. Usable any time Forma feels slow or buggy.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Prepare the audit output directory

**Files:**
- Create: `Docs/audits/2026-04-10-forma-audit/screenshots/` (empty directory placeholder)

- [ ] **Step 1: Create the audit output directory tree**

Run:
```bash
mkdir -p "/Users/jamesfarmer/Developer/Application Prototype/Forma/Docs/audits/2026-04-10-forma-audit/screenshots"
```
Expected: no output, exit code 0.

- [ ] **Step 2: Verify the directory exists**

Run:
```bash
ls -la "/Users/jamesfarmer/Developer/Application Prototype/Forma/Docs/audits/2026-04-10-forma-audit"
```
Expected: shows `screenshots` subdirectory.

- [ ] **Step 3: Add a placeholder README so git tracks the empty directory**

Create `Docs/audits/2026-04-10-forma-audit/README.md` with content:

```markdown
# Forma Audit — 2026-04-10

Raw subagent reports and evidence for the 2026-04-10 Forma audit run.

- `agent-1-reproduction.md` — Reproduction agent evidence
- `agent-2-performance.md` — Performance hotspot findings
- `agent-3-bug-hunter.md` — Correctness findings
- `agent-4-layout.md` — SwiftUI layout findings
- `screenshots/` — Evidence screenshots from Agent 1

The synthesized report lives at `../2026-04-10-forma-audit.md`.
```

- [ ] **Step 4: Commit the directory scaffold**

```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma"
git add "Docs/audits/2026-04-10-forma-audit/README.md"
git commit -m "Scaffold 2026-04-10 Forma audit output directory

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Dispatch all 4 subagents in parallel

**Files:**
- Create: `Docs/audits/2026-04-10-forma-audit/agent-1-reproduction.md` (written by Agent 1)
- Create: `Docs/audits/2026-04-10-forma-audit/agent-2-performance.md` (written by Agent 2)
- Create: `Docs/audits/2026-04-10-forma-audit/agent-3-bug-hunter.md` (written by Agent 3)
- Create: `Docs/audits/2026-04-10-forma-audit/agent-4-layout.md` (written by Agent 4)

- [ ] **Step 1: Pre-flight the build once so Agent 1 starts from a clean state**

Run:
```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma" && \
xcodebuild -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -configuration Debug \
  build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **` in the last lines.

If the build fails, STOP — fix the build before running the audit. A
broken build will mask audit findings and Agent 1 cannot drive the app.

- [ ] **Step 2: Dispatch all 4 subagents IN A SINGLE MESSAGE**

Using the `Agent` tool, issue 4 tool calls in one response. Each call
uses the prompt text below. Do NOT sequentialize these — they must go
out in parallel so their reports land together.

**Agent 1 call** (`subagent_type: screenshot-orchestrator`,
`description: "Reproduce Forma audit symptoms"`):

> Build and drive the Forma macOS app to reproduce and capture evidence
> for these seeded symptoms. The project is at
> `/Users/jamesfarmer/Developer/Application Prototype/Forma` — read its
> `CLAUDE.md` first for build commands, then read
> `Docs/prompts/forma-audit-prompt.md` for the Agent 1 brief and the
> finding shape. Do NOT modify source files.
>
> Seeded symptoms:
> 1. Right-panel toggle is slow — opening the inspector shows the macOS
>    spinning cursor and hitches the sidebar. Smart Rules view in the
>    right panel contains ~1,574 rules.
> 2. Left-panel toolbar toggle icon visually glitches when the right
>    panel opens.
> 3. File drop into a Forma-watched folder triggers a rescan that
>    visibly stutters. Reproduce by copying a throwaway temp file into
>    a watched folder — do NOT touch user files. Clean up after.
> 4. General input latency — "every button feels messy."
>
> Build the app with `mcp__xcodebuildmcp__build_run_macos` against
> project `Forma File Organizing.xcodeproj` and scheme
> `Forma File Organizing`. Launch with
> `mcp__xcodebuildmcp__launch_mac_app`. Capture screenshots with
> `mcp__xcodebuildmcp__screenshot` and structural state with
> `mcp__xcodebuildmcp__describe_ui`. Save all screenshots to
> `Docs/audits/2026-04-10-forma-audit/screenshots/`.
>
> Output a markdown report to
> `Docs/audits/2026-04-10-forma-audit/agent-1-reproduction.md` with:
> reproduction steps, observed timings, references to the screenshot
> files you captured, and any immediate structural observations about
> the offending views. Do NOT propose code fixes — that is for
> Agents 2–4. Keep the report under 300 lines.

**Agent 2 call** (`subagent_type: performance-optimizer`,
`description: "Forma performance hotspot audit"`):

> Audit the Forma macOS app for performance hotspots contributing to
> user-visible lag. The project is at
> `/Users/jamesfarmer/Developer/Application Prototype/Forma`. Read
> `CLAUDE.md` first for architecture and conventions, then read
> `Docs/prompts/forma-audit-prompt.md` for the Agent 2 brief and the
> finding shape. You must NOT modify any source files — this is a
> find-and-propose audit only.
>
> Seeded symptoms you are looking to root-cause:
> 1. Right-panel toggle lag (Smart Rules view with ~1,574 rules).
> 2. File drop → rescan hitch.
> 3. General input latency across every button.
>
> Focus areas (from the prompt template): main-thread SwiftData
> fetches, missing `LazyVStack`/`LazyVGrid`, `@Observable` cascade
> storms, `.onChange` cascades, `FileManager`/IO on `@MainActor`,
> `FileScanPipeline` debouncing, `NavigationSplitView` column rebuild
> patterns.
>
> Write your report to
> `Docs/audits/2026-04-10-forma-audit/agent-2-performance.md` using the
> standard finding shape for every issue. Cite `file:path:line` for
> every claim. Keep it under 300 lines.

**Agent 3 call** (`subagent_type: Explore`,
`description: "Forma correctness bug hunt"`):

> You are the bug hunter for a Forma macOS app audit. Be very thorough.
> The project is at
> `/Users/jamesfarmer/Developer/Application Prototype/Forma`. Read
> `CLAUDE.md` first for architecture, then
> `Docs/prompts/forma-audit-prompt.md` for the Agent 3 brief and the
> finding shape. Do NOT modify any source files.
>
> Correctness focus areas: security-scoped bookmark leaks
> (`startAccessingSecurityScopedResource` without matching `stop...` on
> all paths including error paths), SwiftData unique-constraint risks
> on `FileItem.path`, swallowed throws (`try?` and empty `catch` — also
> cross-reference `SILENT_FAILURES_REMEDIATION.md` in the repo root),
> feature flag gating misses (ML features must gate at entry points
> via `FeatureFlagService.shared.isEnabled(...)`), undo/redo integrity
> in `ActivityLoggingService`, and rule precedence correctness in
> `FileScanPipeline`.
>
> Write your report to
> `Docs/audits/2026-04-10-forma-audit/agent-3-bug-hunter.md` using the
> standard finding shape. Cite `file:path:line` for every claim. Keep
> it under 300 lines.

**Agent 4 call** (`subagent_type: Explore`,
`description: "Forma SwiftUI layout audit"`):

> You are the layout auditor for the Forma macOS app. Medium
> thoroughness. The project is at
> `/Users/jamesfarmer/Developer/Application Prototype/Forma`. Read
> `CLAUDE.md` first, then `Docs/prompts/forma-audit-prompt.md` for the
> Agent 4 brief and the finding shape. Do NOT modify any source files.
>
> Primary target: the toolbar icon glitch in the left panel that
> appears when the right panel toggles. This is almost certainly a
> SwiftUI toolbar identity / `NavigationSplitView` rebuild issue.
>
> Other focus areas: view-identity misuse (`.id(UUID())` or equivalent
> patterns trashing state), hardcoded colors/sizes vs `FormaColors`/
> `FormaSpacing`/`FormaTypography`, small-window breakage across the
> four file-row surfaces listed in `CLAUDE.md`
> (`Forma File Organizing/Views/Components/FileRow.swift`,
> `Forma File Organizing/Components/FileListRow.swift`,
> `Forma File Organizing/Components/FileGridItem.swift`,
> `Forma File Organizing/Views/MainContentView.swift`), and design
> token drift.
>
> Write your report to
> `Docs/audits/2026-04-10-forma-audit/agent-4-layout.md` using the
> standard finding shape. Cite `file:path:line` for every claim. Keep
> it under 300 lines.

- [ ] **Step 3: Verify all four report files exist**

Run:
```bash
ls -la "/Users/jamesfarmer/Developer/Application Prototype/Forma/Docs/audits/2026-04-10-forma-audit/"
```
Expected: all four `agent-*.md` files present and non-empty, plus a
populated `screenshots/` directory.

If any agent report is missing, re-dispatch only that agent with the
same prompt. Do NOT re-run agents that succeeded.

- [ ] **Step 4: Commit the raw subagent reports**

```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma"
git add "Docs/audits/2026-04-10-forma-audit/"
git commit -m "Capture raw subagent reports for 2026-04-10 Forma audit

Four parallel subagents (reproduction, performance, bug hunter,
layout) produced their individual findings. Synthesis into a single
prioritized report follows in the next commit.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Synthesize the master findings report

**Files:**
- Create: `Docs/audits/2026-04-10-forma-audit.md`

- [ ] **Step 1: Read all four raw reports**

Read each of these files in full:
- `Docs/audits/2026-04-10-forma-audit/agent-1-reproduction.md`
- `Docs/audits/2026-04-10-forma-audit/agent-2-performance.md`
- `Docs/audits/2026-04-10-forma-audit/agent-3-bug-hunter.md`
- `Docs/audits/2026-04-10-forma-audit/agent-4-layout.md`

- [ ] **Step 2: Assemble the synthesized report**

Create `Docs/audits/2026-04-10-forma-audit.md` with this structure:

```markdown
# Forma Audit — 2026-04-10

**Mode:** find+propose (no code changes applied)
**Scope:** full-audit
**Spec:** `Docs/superpowers/specs/2026-04-10-forma-audit-prompt-design.md`

## Executive summary

<one paragraph, 3–5 sentences, naming the root cause(s) of "every
button feels messy." Derived from correlating findings across all
four agents.>

## P0 — Seeded symptoms, root-caused

<one finding per seeded symptom, in the standard finding shape. If an
agent found multiple contributors to the same symptom, include all of
them under the same symptom heading.>

### Symptom 1: Right-panel toggle lag
<findings from agents 2 and 4 correlated here>

### Symptom 2: Toolbar icon glitch
<findings from agent 4>

### Symptom 3: File drop → rescan hitch
<findings from agent 2>

### Symptom 4: General input latency
<findings from agent 2>

## P1 — High-confidence contributors

<every P1 finding from any agent, in finding shape>

## P2 — Adjacent issues

<every P2 finding from any agent, in finding shape>

## Appendix: Evidence

Reproduction agent output and screenshots. See
`2026-04-10-forma-audit/agent-1-reproduction.md` for the full
reproduction log and `2026-04-10-forma-audit/screenshots/` for the
captured images.

<inline reference the most important screenshots here with brief
captions>

## Next steps

This is a `find+propose` run — no code changes have been applied.
Triage findings in priority order and hand individual findings to
follow-up implementation sessions.
```

**Rules for synthesis:**
- Every finding from every subagent must appear somewhere in this
  report. Do not drop findings for brevity.
- When two agents report the same root cause from different angles,
  merge them into one finding and cite both agents in the finding
  body.
- Preserve the exact `file:path:line` citations from the source
  reports.
- Do not invent findings that no subagent reported.

- [ ] **Step 3: Verify every raw finding is present in the synthesized report**

For each agent report, count the number of findings (lines matching
`^### \[P[012]\]`) and verify the same count appears in the
synthesized report, minus any merged duplicates (document each merge
inline).

Run:
```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma"
for f in Docs/audits/2026-04-10-forma-audit/agent-*.md; do
  echo -n "$f: "
  grep -c '^### \[P[012]\]' "$f"
done
echo -n "Docs/audits/2026-04-10-forma-audit.md: "
grep -c '^### \[P[012]\]' "Docs/audits/2026-04-10-forma-audit.md"
```
Expected: the synthesized report's count equals the sum of the four
agent reports, minus documented merges.

- [ ] **Step 4: Commit the synthesized report**

```bash
cd "/Users/jamesfarmer/Developer/Application Prototype/Forma"
git add "Docs/audits/2026-04-10-forma-audit.md"
git commit -m "Synthesize 2026-04-10 Forma audit findings

Merges the four parallel subagent reports into a single prioritized
findings document. P0 findings are root-caused to the seeded
symptoms (right-panel lag, toolbar glitch, scan hitch, input
latency). No code changes applied — mode is find+propose.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Present the report to the user

**Files:**
- None (conversational only)

- [ ] **Step 1: Summarize the executive summary and P0 count in a short message**

Write a terse message to the user (≤6 sentences) containing:
- Number of P0 findings root-caused to each seeded symptom.
- Total P1 and P2 counts.
- Direct path to the report file.
- The next-decision question: "Which finding do you want to start
  fixing first?"

- [ ] **Step 2: Wait for user triage decision**

Do NOT proceed into implementing any fix in this session. This plan
ends at the handoff — individual fix work is its own plan, scoped to
the specific finding the user picks.

---

## Self-Review

Checked against spec `Docs/superpowers/specs/2026-04-10-forma-audit-prompt-design.md`:

- **Reusable template deliverable** → Task 1 ✓
- **One-shot seeded execution** → Tasks 2–4 ✓
- **Four parallel subagents with correct types** → Task 3 Step 2 ✓
  (screenshot-orchestrator, performance-optimizer, Explore, Explore)
- **Agent 1 drives real app via xcodebuild MCP** → Task 3 Step 1–2 ✓
- **Safe file-drop reproduction (temp file, no user file touch)** →
  Task 3 Step 2 Agent 1 call ✓
- **Finding shape fixed across all agents** → Task 1 Step 2 template
  body ✓
- **Synthesis structure (exec summary, P0/P1/P2, evidence appendix)**
  → Task 4 Step 2 ✓
- **Every finding preserved, no dropping** → Task 4 Step 2 rules
  + Step 3 verification ✓
- **find+propose mode — no code changes applied** → Task 5 Step 2
  handoff gate ✓
- **Scope guardrails (no changes outside `Forma File Organizing/`)**
  → Task 1 Step 2 template body Guardrails section ✓

Placeholder scan: no `TBD`/`TODO` in task steps. Code blocks
included for every file write, every command, every commit. Agent
prompts are complete — the executor does not need to invent any
agent brief content.

Type / path consistency: report path
`Docs/audits/2026-04-10-forma-audit.md` matches in Tasks 2, 3, 4, and
Self-Review. Raw agent report paths consistent across Task 3 Step 2,
Task 4 Step 1, and Task 4 Step 3.

No gaps found.
