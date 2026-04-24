# Forma Codebase Audit — 2026-04-23

> **Mode:** `find+propose` — no source files were modified.
> **Scope:** Full-codebase parallel review across 8 architectural layers.
> **Agents dispatched:** 8 in parallel (code-reviewer × 7, audit × 1).
> **Total findings across all severities:** ~170.
> **Precedent:** [2026-04-10 audit](2026-04-10-forma-audit.md).

## Executive summary

Forma is well-architected at the baseline — principled entitlements, careful
dark-mode contrast work, a mature design-token system, and a clean test-gating
pattern. The audit surfaced ~170 individual findings, but the highest-signal
issues cluster around five systemic themes:

1. **Silent data loss through `try? + default fallback`.** Multiple SwiftData
   decode paths silently replace corrupt rows with benign — or sometimes
   *more permissive* — defaults (`RuleCategory.scope` → `.global`,
   `RuleCondition` → empty extension, `LearnedPattern.destination` →
   empty bookmark).
2. **Security-scoped access gaps.** Symlink resolution missing in
   `PathValidator` and `TrustedAutomationScopeBoundaryDescriptor`; test-only
   permission relaxation ships in Release; a privacy debug log leaks every
   browsed path to `/tmp`.
3. **Broken-but-deployed ML paths.** `DestinationPredictionService` drift
   detection and confidence-acceptance gates are non-functional — the
   pipeline is effectively disabled while looking live.
4. **Schema versioning absent.** 23 `@Model` types, zero
   `VersionedSchema`/`SchemaMigrationPlan`. The next non-additive change
   will corrupt user stores.
5. **Architecture documentation is aspirational.** `CLAUDE.md` mandates
   `@MainActor @Observable` ViewModels and protocols-first services.
   `@Observable` is used in zero ViewModels. `FileOperationsService` —
   the riskiest service in the app — has no protocol, no mock.

This document tracks the **10 must-fix items** extracted from the broader
review. Each is scoped small enough to be a single PR; the whole list is
~2–3 weeks of focused work if executed tier-by-tier.

The full per-layer findings are preserved in agent conversation history
rather than transcribed here — this document captures only what should
ship.

---

## Priority order

Work the tiers in sequence. Within a tier, items are independent and can
be parallelized across sessions.

### Tier A — Same day / pre-release (low-risk, high-impact)

Quick wins that remove real user/security risk with minimal code change.
Can ship as a single PR.

1. **A1** — Delete `/tmp/thumbnail_debug.log` writer
2. **A2** — Gate `UITestFolderAccessConfiguration` behind `#if DEBUG || UI_TESTS`
3. **A3** — Add `selectedTests` to default xctestplan; un-orphan existing test files
4. **A4** — Add `resolvingSymlinksInPath()` to `PathValidator` + `TrustScope.matches`

### Tier B — This week (medium complexity, high-value)

Each is a focused change but requires care and targeted tests. One PR per item.

5. **B1** — Route `moveFileUsingBookmark` through `secureFileMove`
6. **B2** — Emit `.skipped` audit entries from `WorkflowRunner` when `fileLoop` breaks
7. **B3** — Add `isFullyConfigured` + confirmation gates to `FormaAppIntents`
8. **B4** — Decide fate of `DestinationPredictionService` drift / acceptance gate

### Tier C — Planning required (structural, do before next schema/release)

Architectural. Needs a plan doc and touches many call sites. Should be scheduled
before the next breaking schema change or major release.

9. **C1** — Adopt `VersionedSchema` / `SchemaMigrationPlan`; wrap `Data` blobs in version envelopes
10. **C2** — Extract `FileOperationsServiceProtocol`, inject everywhere, add mock

---

## The 10 action items

### A1 — Remove production `/tmp` thumbnail debug log

- **Severity:** HIGH (privacy leak in all build configs)
- **Effort:** < 1 hour
- **File:** `Forma File Organizing/Services/ThumbnailService.swift:8-26, 64-72, 388-391`

**What's broken.** `debugLog(_:)` opens `/tmp/thumbnail_debug.log` and writes
every file path the user previews. `/tmp` is accessible outside the app
container. Unconditional (not `#if DEBUG`), no rotation, no size cap,
`FileHandle` calls are un-`try`'d.

**Fix.** Delete the `/tmp` sink entirely. `Log.debug(verboseOnly: true)`
already exists and routes through the logging facade. Also move the
startup maintenance `Task {}` off of `init` and store the handle so tests
can cancel it.

**Verification.** Grep confirms no remaining `/tmp/thumbnail_debug.log`
references anywhere in the codebase; `ThumbnailService` unit tests still
pass; preview flow works unchanged.

---

### A2 — Gate `UITestFolderAccessConfiguration` behind Debug / UI tests

- **Severity:** HIGH (shipped binary can be coerced via `--uitesting` argv)
- **Effort:** < 1 hour
- **File:** `Forma File Organizing/Utilities/UITestFolderAccessConfiguration.swift`

**What's broken.** The whole file compiles into Release. `isEnabled` checks
`CommandLine.arguments.contains("--uitesting")`, so a shipped, sandboxed,
signed binary will relax bookmark enforcement if launched with that flag.
Any parent process (or a user running from Terminal with the flag) escalates.

**Fix.** Wrap the file contents in `#if DEBUG || UI_TESTS`. In Release,
have `isEnabled` return `false` unconditionally (no argv read). Add a
compile-time assertion in Release that `UI_TESTS` is not defined for App
Store builds.

**Verification.** `xcodebuild archive` for the Release configuration produces
a binary that does not contain the `--uitesting` string literal. Add a
guard test in the Unit plan asserting the configuration is disabled in
`#if !DEBUG` paths.

---

### A3 — Fix `xctestplan` `selectedTests` hygiene

- **Severity:** HIGH (Cmd-U silently runs integration + performance; ~10 test files are orphaned)
- **Effort:** 1–2 hours
- **Files:**
  - `Forma File Organizing.xctestplan` (root default)
  - `Forma File Organizing - Unit.xctestplan`
  - `Forma File Organizing - Integration.xctestplan`
  - `Forma File Organizing - Performance.xctestplan`
  - `Forma File Organizing - UI.xctestplan`

**What's broken.** The default plan has no `selectedTests` filter, so any
developer hitting Cmd-U runs every test class in the target. Meanwhile, the
`Unit.xctestplan` allowlist omits `BookmarkFolderServiceTests`,
`NotificationServiceTests`, `DuplicateDetectionServiceTests`,
`WorkflowRunnerTests`, `WorkflowPlannerTests`, `WorkflowRollbackCoordinatorTests`,
`ExternalIngressCoordinatorTests`, `PanelStateManagerTests`,
`AppReviewEligibilityServiceTests`, and `AppStoreMigrationTests` —
those files exist but nobody runs them.

**Fix.** Switch plans to inverse `skippedTests` allowlisting. Add a
`selectedTests` filter (or delete the default plan and make `Unit` the
scheme default). Add a CI lint that diffs `find "Forma File OrganizingTests" -name "*.swift"`
against the union of all four plans and fails on drift.

**Verification.** Cmd-U from Xcode runs only unit tests. Each of the named
orphaned test files has at least one test method that executes in the
Unit plan. CI job prints the orphan-list and fails if non-empty.

---

### A4 — Resolve symlinks in `PathValidator` and TrustScope boundary matching

- **Severity:** HIGH (security-scoped access escape)
- **Effort:** 2–4 hours (code + tests)
- **Files:**
  - `Forma File Organizing/Utilities/PathValidator.swift:164-174`
  - `Forma File Organizing/Models/TrustedAutomationScopeBoundaryDescriptor.swift:72-88`
  - `Forma File Organizing/Services/TrustedAutomationScopeResolver.swift:28-55`

**What's broken.** Neither site calls `resolvingSymlinksInPath()`. `PathValidator`
only collapses `.`/`..` lexically — a symlink inside a scanned folder
pointing outside the user's home survives the `hasPrefix(homeDir)` check.
`SourceBoundary.matches(file:)` has the same gap: a symlink inside a scan
root pointing outside the trust scope is treated as inside, granting
auto-execute on paths the user never trusted. `FileOperationsService` and
`FileSystemService` already resolve symlinks correctly, so the inconsistency
is real and exploitable.

**Fix.** In both sites: call
`resolvingSymlinksInPath().standardizedFileURL.path` before prefix
comparison; resolve home/scope root the same way. Add regression tests
that create a symlink inside a trusted scope pointing outside the scope
root and assert `matches()` / `validate()` return `false`.

**Verification.** Existing `SymlinkSecurityTests` pass. Add a new test per
site proving a symlink escape is rejected. Release the security-sensitive
logs from `#if DEBUG` gating so real attempts show up in logs outside dev
builds.

---

### B1 — Route `moveFileUsingBookmark` through `secureFileMove`

- **Severity:** HIGH (production move path bypasses TOCTOU protection)
- **Effort:** 4–8 hours (code + rollback-correctness tests)
- **File:** `Forma File Organizing/Services/FileOperationsService.swift:406-559`

**What's broken.** `moveFileUsingBookmark` opens the source FD, validates it
(`O_NOFOLLOW`, `fstat`), and immediately `defer close(fd)`s — then falls
through to `fileManager.moveItem(at:to:)` on *path strings*, not
`renameat()` on the validated FD. All the hardening in `secureFileMove`
(lines 164-237) is defeated for the only code path production actually
uses. Additional concrete issues in the same method:

- Equivalence-then-delete (lines 503-527) is not atomic; between
  `fileExists`, `isEquivalentFile`, and `removeItem`, a concurrent replace
  can cause deletion based on stale equivalence evidence.
- `SecurityScopedAccess` (line 446-473) relies on deterministic `deinit`
  for locals — Swift does not guarantee this. Use `withExtendedLifetime`
  or convert to a `struct`-with-`defer` pattern at the call site.

**Fix.** Reroute `moveFileUsingBookmark` so the validated FD is the file
that moves. Either call `secureFileMove(from:to:)` directly, or pass
the FD through `renameat()` on the source directory FD. Wrap the
equivalence-then-delete block in `withExtendedLifetime(access)` and
`fstat` the open FD instead of re-stat'ing the path.

**Verification.** Add tests that simulate a mid-operation replace of the
destination and assert the source is not deleted. Add a test that the
FD opened in validation is the FD used for the rename (introspectable
via `Self.lastMovedFileDescriptor` or similar test-only hook).

---

### B2 — Emit `.skipped` audit entries when `WorkflowRunner` breaks its file loop

- **Severity:** HIGH (rollback state cannot account for skipped files; user sees preview plan but audit shows zero for files 5-N)
- **Effort:** 4–8 hours (code + audit schema + tests)
- **File:** `Forma File Organizing/Services/WorkflowRunner.swift:601-730`

**What's broken.** Any step failure on any file triggers `break fileLoop`,
abandoning every subsequent planned file. Those skipped files receive
neither a preflight-skipped step audit nor a `WorkflowFileActionRecord`
row. A run's audit has *zero entries* for files the user saw in the
preview pane.

**Fix.** Continue iterating after `break`; for each remaining planned
file, emit `.skipped` step audits and a `WorkflowFileActionRecord` with a
new `SkipReason.abandonedAfterUpstreamFailure` (or similar) distinguishing
this from preflight skips. Consider also adding a per-run `abandonedAfter`
field so UI can render "files 5-12 skipped due to rollback on file 4."

**Verification.** Unit test: run a 5-file plan where file 3 fails; assert
files 4 and 5 have audit rows with the new reason. Integration test:
confirm `WorkflowRunDetailSheet` surfaces the skipped files with honest
wording.

**Implementation note.** Landed with `WorkflowRunner` emitting skipped
execution-step rows and one skipped `WorkflowFileActionRecord` per
abandoned file using `abandonedAfterUpstreamFailure`; covered by
`WorkflowRunnerTests.testRunner_RecordsAbandonedFilesAfterFileLoopBreak`.

---

### B3 — Gate `FormaAppIntents` on `isFullyConfigured` + require confirmation for state-mutating intents

- **Severity:** HIGH (Shortcuts/Siri/Spotlight can mutate state without app ever being opened)
- **Effort:** 4–8 hours
- **File:** `Forma File Organizing/Services/FormaAppIntents.swift:41-305`

**What's broken.** None of `OrganizeSelectionIntent`, `ReviewSelectionIntent`,
or `ToggleAutomationIntent` checks `FormaActions.shared.isFullyConfigured`
before dispatching. `ToggleAutomationIntent` has no confirmation —
Spotlight/Siri can silently flip global background-scan behavior.
`OrganizeSelectionIntent` submits arbitrary `IntentFile` URLs into
`ExternalIngressCoordinator` from an app that may never have been
opened and has no bookmarks.

**Fix.**

- Add an early `guard FormaActions.shared.isFullyConfigured else { throw FormaIntentError.notConfigured }`
  in every `perform()`.
- Add `requestConfirmation` to `ToggleAutomationIntent` — the prompt
  should name the current vs. next mode explicitly.
- `OrganizeSelectionIntent` / `ReviewSelectionIntent` should validate
  that every passed `IntentFile` has a bookmark (or is within an existing
  bookmarked scope) before dispatch; surface clear error copy
  otherwise.

**Verification.** Unit tests per intent for not-configured, unauthorized
URL, and confirmation paths. Manually: run each Shortcut from a fresh
install and confirm the expected error path.

---

### B4 — Decide fate of `DestinationPredictionService` drift + acceptance gate

- **Severity:** HIGH (ML feature deployed but dead)
- **Effort:** 1–3 days (depends on decision)
- **File:** `Forma File Organizing/Services/DestinationPredictionService.swift:432-445, 480-515, 521, 839-845, 862-882`

**What's broken.** Two independent non-functional paths:

1. **Drift detection.** `PredictionStatistics` has `acceptedCount` /
   `overriddenCount` fields; no `recordAccepted` / `recordOverridden`
   function exists, nothing increments them. Once `predictionCount >= 100`,
   `acceptanceRate = 0/N < 0.5` becomes true vacuously, signaling drift
   on every prediction and triggering retraining continuously.
2. **Model acceptance.** `evaluateModel` writes `// Placeholder` and uses
   `confidence = 1.0` for every sample. `meetsAcceptanceCriteria` requires
   `minimumConfidenceSeparation = 0.15` between correct and incorrect
   average confidence. With both equal to 1.0 the gate is
   mathematically impossible; *no* trained model is ever accepted.

Also: training data is `Array(records.prefix(5000))` before shuffling,
keeping oldest records and dropping recent patterns — opposite of what a
drift-tolerant model wants.

**Fix (decision required).** Choose one:

- **Wire it up.** Add `recordAccepted` / `recordOverridden` called from the
  accept/override flow (`ActivityLoggingService` or wherever decisions
  land). Replace the confidence placeholder with per-prediction
  probabilities via `MLModel`-level prediction (as
  `CoreMLPredictionEngine.predict` already does). Shuffle *before*
  prefix-capping.
- **Remove until wired.** Delete the drift branch and the confidence
  gate; keep training simple and accept every model that parses. Add a
  tracking issue for future ML hardening.

Whichever path, document the chosen approach in a plan doc under
`Docs/plans/` before writing code.

**Verification.** Unit tests exercising accept/override counting and
drift-signal thresholds. Integration test that trains and evaluates a
model in-process and asserts acceptance or rejection matches the chosen
policy.

---

### C1 — Adopt SwiftData `VersionedSchema` + wrap `Data`-blob fields in version envelopes

- **Severity:** HIGH (next breaking schema change corrupts user stores)
- **Effort:** 1–2 weeks (plan + migration infrastructure + rollout)
- **Files:** All of `Forma File Organizing/Models/` (~50 files), plus
  `Forma File Organizing/Forma_File_OrganizingApp.swift:104-126` (schema
  registration).

**What's broken.** Zero `VersionedSchema` / `SchemaMigrationPlan` /
`MigrationStage` declarations exist. The current "just use optional fields
and defaults" approach works for additive changes but any rename, removed
enum case, or tightened uniqueness constraint will silently break
existing stores. Additionally, many fields are stored as `Data` blobs
(`RuleCategory.scopeData`, `LearnedPattern.destinationData`,
`FileItem._destinationBookmarkData`, `TrustedAutomationScope.boundaryDescriptorData`,
`WorkflowFileActionRecord.compensationPayloadData`, etc.) encoded with
`try?`; no version envelope means "old schema blob" is indistinguishable
from "corrupt blob."

**Fix.** This is big enough to warrant its own plan doc. Rough shape:

- Draft a schema plan under `Docs/plans/2026-04-YY-swiftdata-versioned-schema.md`.
- Define `FormaSchemaV1: VersionedSchema` matching the current model set.
- Introduce a `VersionedBlob<T: Codable>` envelope with a `version: Int`
  + `payload: Data` pair; add encode/decode helpers to
  `SwiftDataTransaction` or a new `Models/VersionedBlob.swift`.
- Adopt the envelope at every `Data`-blob field incrementally, one
  model per PR.
- When the next breaking change lands, declare `FormaSchemaV2` and the
  first `MigrationStage`.

**Verification.** `AppStoreMigrationTests` extended to cover each
migration stage. Load-from-old-binary test exists for every future
schema version.

---

### C2 — Extract `FileOperationsServiceProtocol` and inject everywhere

- **Severity:** HIGH (the riskiest service has no test seam; concrete instantiation bypasses DI, rate limiting, and scoped access)
- **Effort:** 3–5 days
- **Files:**
  - `Forma File Organizing/Services/FileOperationsService.swift` (add protocol)
  - `Forma File Organizing/Services/UndoCommand.swift:143-192`
  - `Forma File Organizing/ViewModels/DashboardViewModel.swift:623`
  - `Forma File Organizing/ViewModels/ReviewViewModel.swift:38`
  - `Forma File Organizing/ViewModels/BulkOperationViewModel.swift:91-92`
  - `Forma File Organizing/Services/MoveWorkflowStepExecutor.swift:178`
  - Plus every remaining direct `FileOperationsService()` call site.
  - New mock: `Forma File OrganizingTests/TestHelpers/MockFileOperationsService.swift`

**What's broken.** CLAUDE.md: "New services need a protocol + mock for testing."
The service that performs every file move, copy, and rollback — and owns
every rate-limiting decision — has neither. Every call site that
instantiates `FileOperationsService()` inline (a) bypasses any cached
state the shared instance holds, (b) skips security-scoped-access
establishment, (c) forks rate-limiter state per instance, and (d) is
untestable without real disk I/O. This is particularly bad in
`UndoCommand.MoveFileCommand.undo` which performs cross-bookmark moves
without starting scoped access.

**Fix.**

- Define `FileOperationsServiceProtocol` matching the public API
  actually used today (move, bulk move, secure move on disk, diagnose
  bookmarks, equivalence check). Keep the surface minimal.
- Make `FileOperationsService: FileOperationsServiceProtocol`.
- Thread the shared instance through `AppServices` (where it already
  lives) into `UndoCommand`, `ReviewViewModel`, `BulkOperationViewModel`,
  `MoveWorkflowStepExecutor`, and `RenameWorkflowStepExecutor`.
- Delete every inline `FileOperationsService()` construction.
- Add `MockFileOperationsService` with programmable success/failure
  per path and recorded call log for assertion.

**Verification.** Every reviewed call site uses the injected protocol;
no direct `FileOperationsService()` construction remains outside
`AppServices` wiring. `UndoCommand` tests now exercise failure paths
without real disk I/O. Cross-bookmark undo test added and passing.

---

## Out of scope for this pass

The broader review surfaced ~160 additional findings — MEDIUM and LOW
severity, plus architectural observations — that are not captured as
individual action items here. Notable clusters tracked separately:

- **`@Observable` migration** across all 20 ViewModels (CLAUDE.md says
  "must be `@MainActor @Observable`" — currently 0 compliance). Should
  start after C2 lands; first targets are leaf VMs (`NavigationViewModel`,
  `MenuBarViewModel`, `DashboardPermissionState`).
- **`SelectionViewModel` ↔ `SelectionManager` and `FilterViewModel` ↔
  `FileFilterManager` duplicated-state pairs.** Collapsing each removes
  ~150 lines of mirror/sync code. Natural follow-on to `@Observable` migration.
- **`DashboardViewModel` further decomposition** — 4,520 lines despite
  partial controller extraction. Still owns Project Space (~700 lines),
  Trusted Automation Scope (~500 lines), First-Run Quick Win (~200 lines),
  External Review session state. Each should become a `Dashboard*Controller`
  following the shipped pattern (`DashboardScanRefreshController`,
  `DashboardOrganizationController`, etc.).
- **`FormaAnimation → FormaEasing` consolidation** (34 call sites) —
  already tracked in memory, pending.
- **Design token adoption** — conservative, already in flight.
- **Reduce Motion coverage** — ~27% of view files; wire `formaAnimated`
  helper into remaining `scaleEffect` / `withAnimation` sites.
- **`FormaFocusRing` exists but has zero call sites** — focus indication
  inconsistent app-wide. Wire at main controls.
- **Log.swift → `os.Logger` with privacy markers** — currently uses
  `print()`, forfeiting all OS-level privacy redaction.
- **`os.Logger` adoption and `ByteSizeFormatterUtil` IEC-vs-SI decision**
  round out the Utilities hygiene pass.

These will be folded into follow-on waves in the normal roadmap document
as priorities shift.

---

## How this was produced

Eight parallel agents reviewed non-overlapping layers of the codebase
read-only. Each produced a structured HIGH / MEDIUM / LOW / "what's
working well" report. The 10 items above were selected by cross-referencing
severity, blast radius, likelihood of user impact, and remediation
effort — prioritizing items that multiple agents flagged independently
or that block the architecture contract documented in `CLAUDE.md`.

Full per-layer agent reports are preserved in conversation history and
can be re-dispatched with the same prompts for a diff-style follow-up
after remediation.
