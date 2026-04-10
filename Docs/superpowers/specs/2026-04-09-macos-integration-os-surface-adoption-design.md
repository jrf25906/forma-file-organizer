# macOS Integration OS Surface Adoption Design

Date: 2026-04-09
Branch: `codex/macos-integration-os-surface-adoption`
Status: Approved in-thread, pending implementation

## Summary

The next post-`workflow-engine-v2` slice should deepen the macOS surfaces Forma already owns instead of creating a new extension target.

The branch goal is to make Finder service, Spotlight/App Intents, Shortcuts, menu bar, and external-ingress review flows feel like one coherent workflow-backed system:

- OS-launched runs should preserve template identity and trigger-surface attribution.
- Review-first launches should carry structured outcome state into the app instead of flattening everything to one status string.
- App Intents and menu bar actions should explain blocked, skipped, and permission-recovery states honestly.

This branch should not add a Finder Sync extension, a brand-new Quick Action extension target, or any new execution path outside the existing workflow/external-ingress plumbing.

## Goals

- Deepen Shortcuts/App Intents on top of the workflow-backed entry-point layer.
- Improve menu bar workflow UX around template selection, blocked-plan guidance, and completion feedback.
- Make external-ingress review handoff carry structured outcome data, not just `statusText`.
- Keep Finder service, Spotlight/App Intents, and menu bar flows aligned around one review-first trust story.
- Preserve preview-first posture: open the app when review or permission recovery is required instead of pretending OS automation fully completed.

## Non-Goals

- No Finder Sync extension or separate Finder extension target.
- No new Quick Action extension target.
- No new workflow step kinds or workflow-engine expansion in this branch.
- No redesign of unrelated menu bar layout or dashboard navigation.
- No cloud sync, collaboration, or new AI-first entry points.

## Product Boundary

### What This Branch Ships

- A structured external-ingress outcome model that can describe:
  - files auto-organized immediately
  - files that still need review
  - skipped items
  - permission-reauthorization situations
  - selected workflow template identity when relevant
- Review-first App Intent / Shortcut behavior for explicit file or folder selection.
- Better menu bar guidance when a workflow template is missing or a simulated plan contains blockers.
- Clearer in-app external-review feedback built from structured outcome data rather than concatenated strings.

### What Stays Later

- Finder extension / Finder Sync adoption.
- New OS surfaces beyond the existing Finder service, Spotlight/App Intents, and menu bar.
- Generic workflow authoring or new workflow execution branches.
- Broad UI redesign of the dashboard or review surfaces.

## Options Considered

### Option A: Existing-surface depth only

Deepen Finder service, Spotlight/App Intents, Shortcuts, menu bar, and dashboard review handoff without adding any new Finder-level surface.

Benefits:

- stays inside proven plumbing
- minimizes entitlement and bundle-surface risk
- keeps the branch focused on outcome quality, not surface proliferation

Tradeoffs:

- less visible "new surface" marketing value

### Option B: Existing-surface depth plus a review-first Finder Quick Action concept

Treat the current Finder service as the review-first Finder-side quick action and improve its handoff semantics instead of adding a new extension target.

Benefits:

- gives users a clearer Finder-side review story immediately
- reuses the existing `NSServices` surface and `ExternalIngressCoordinator`
- aligns with preview-first product posture

Tradeoffs:

- "Quick Action" remains implemented through the current Finder service, not a distinct system extension

### Option C: New extension target now

Add Finder Sync or another brand-new OS surface during the same branch.

Benefits:

- broadest macOS-platform story

Tradeoffs:

- highest bundle, entitlement, and registration risk
- most likely to dilute the branch into platform plumbing instead of user-visible trust improvements
- not justified while existing surfaces still return flat outcome strings

## Recommendation

Use Option B.

That means:

- stay inside the current Finder service / Spotlight / App Intent / menu bar surface area
- define a richer shared outcome model first
- use that shared model to improve App Intents, dashboard review handoff, and menu bar guidance
- defer any brand-new extension target until these surfaces feel complete

## Architecture

### 1. Shared External-Ingress Outcome Model

`ExternalIngressCoordinator` and `DashboardViewModel` currently communicate mostly through `statusText`, `reviewPaths`, and `skippedItems`.

This should be replaced with a structured summary type carried by both `ExternalIngressResult` and `ExternalReviewSession`.

Recommended shape:

- counts for auto-organized, review-needed, skipped, and permission-recovery items
- source surface
- resolved workflow-template identity when present
- derived display copy helpers for compact surfaces

This keeps business state separate from presentation while letting App Intents, dashboard toasts, and the menu bar all render the same truth differently.

### 2. Review-First OS Handoff

Explicit file or folder selection from Finder service or App Intent should continue through `ExternalIngressCoordinator`, but the handoff should become more honest:

- if review is needed, open the app and focus the external-review scope
- if access must be reauthorized, surface that as a first-class recovery outcome
- if everything completed immediately, return a compact success summary without pretending review happened

The product rule is simple: OS surfaces may start work, but user trust is preserved by moving into the app whenever preview, recovery, or unresolved blockers remain.

### 3. Shortcuts / App Intents

`FormaAppIntents.swift` should expose clearer behavior for explicit selection and bulk organize:

- keep an immediate organize path for high-confidence bulk cases
- make selected-item organization explicitly review-first when needed
- return richer user-facing result strings derived from the structured outcome summary

App Intents should not invent a parallel planner/runner path. They stay thin wrappers over `FormaActions` and `ExternalIngressCoordinator`.

### 4. Menu Bar Guidance

`MenuBarViewModel` and `MenuBarView` should expose why a workflow action cannot run, not just whether it is disabled.

This branch should keep the current workflow picker and simulation preview, then add:

- missing-template guidance
- blocked-plan explanation using existing simulation data
- clearer confirmation language for partial success or review-required cases

The menu bar should feel like a compact workflow cockpit, not a second-class action sheet.

## File Ownership

### Primary service and model files

- `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- `Forma File Organizing/Services/FormaAppIntents.swift`
- `Forma File Organizing/Services/FormaActions.swift`
- `Forma File Organizing/Services/WorkflowTemplateSelectionStore.swift`
- `Forma File Organizing/Models/WorkflowInvocationContext.swift` only if new trigger distinctions become necessary

### Primary view model and UI files

- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/ViewModels/MenuBarViewModel.swift`
- `Forma File Organizing/Views/MenuBarView.swift`
- `Forma File Organizing/Views/Settings/GeneralSettingsSection.swift` only if OS-surface help copy changes materially

### Tests

- `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `Forma File OrganizingTests/MenuBarViewModelTests.swift` if added
- App Intent-specific tests may need a new focused test file if intent result formatting becomes non-trivial

## Error Handling

- Keep onboarding deferral behavior unchanged.
- Preserve security-scoped bookmark handling and treat reauthorization as a first-class outcome, not a silent retry.
- Do not silently downgrade workflow-template failures into generic "organization failed" copy when the real problem is missing template selection or a blocked workflow plan.
- Keep existing fallback behavior when `FeatureFlagService.Feature.workflowEngineV2` is off.

## Testing Strategy

- Add unit coverage for structured external-ingress summaries in `ExternalIngressCoordinatorTests`.
- Add dashboard coverage proving external-review session toast text and scope handling derive from the new structured summary rather than raw string assembly.
- Add focused menu-bar view-model tests for missing-template and blocked-plan guidance if those behaviors move into dedicated computed properties.
- Run the relevant focused suites first, then the repo-preferred non-UI test command from `codex-project.toml`.

## Acceptance Criteria

- External review sessions no longer rely on a single `statusText` as their only shared summary contract.
- App Intents / Shortcuts can distinguish immediate success, review-required, and reauthorization-required outcomes using the shared model.
- Menu bar workflow actions explain missing-template and blocked-plan states more explicitly.
- Finder service, Spotlight/App Intents, and menu bar still route through the same workflow-backed engine/request path with no new side execution branch.
