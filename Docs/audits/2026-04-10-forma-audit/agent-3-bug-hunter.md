# Agent 3 — Bug Hunter (Partial)

> **Status:** Partial. The subagent hit permission restrictions mid-run and
> could not complete the full correctness sweep. The findings below are the
> evidence it managed to surface before terminating. Remaining categories
> (swallowed throws across ~115 files, SwiftData uniqueness, feature-flag
> gating, undo/redo integrity, rule precedence) are **not covered** and
> should be re-run in a follow-up session.

## Scope covered before termination

- Enumerated 12 files touching security-scoped bookmark APIs.
- Audited `FileOperationsService.swift` for `startAccessingSecurityScopedResource` / `stop...` pairing.
- Spot-checked `FileSystemService` (uses the safer `defer`-based pattern).
- Spot-checked `SecureBookmarkStore.swift` (no critical issues found).
- Identified ~115 candidate files containing `try?` / `catch` blocks for a
  deeper swallowed-throws pass that was not executed.

## Scope NOT covered

- Swallowed throws sweep (`try?`, empty `catch`) across the 115 candidates.
- SwiftData unique-constraint risks on `FileItem.path` under concurrent
  scan / merge.
- Feature-flag gating audit — ML entry points via
  `FeatureFlagService.shared.isEnabled(...)`.
- Undo/redo integrity in `ActivityLoggingService`.
- Rule precedence correctness in `FileScanPipeline`.

A follow-up run should target these categories specifically.

## Findings

### [P0] Security-scoped bookmark resource leak in FileOperationsService

File: `Forma File Organizing/Services/FileOperationsService.swift:446`

Observed: The destination folder's security-scoped access is started via a
direct `destinationFolderURL.startAccessingSecurityScopedResource()` call at
line 446, without the RAII `SecurityScopedAccess` wrapper used elsewhere in
the same file.

Root cause: Any throw that escapes between the `startAccessing` call at line
446 and the `defer` cleanup at lines 452–454 leaks the security-scoped
resource handle. CLAUDE.md explicitly requires a matching
`stopAccessingSecurityScopedResource` on all paths, and the `moveToTrash`
method at lines 744–760 already demonstrates the correct RAII pattern.
Repeated leaks over an app session degrade sandbox posture and can exhaust
system handles.

Proposed fix: Wrap the access in the existing `SecurityScopedAccess` RAII
class (defined at `FileOperationsService.swift:30-47`), mirroring the
`moveToTrash` implementation at lines 744–760. No behavioral change — just
routes cleanup through the wrapper so any throw path is covered.

Risk: low — RAII wrapper already exists and is used in-file; the change is
mechanical and localized.

Confidence: high — the leak is documented against an explicit project
convention, and a working template exists in the same file.
