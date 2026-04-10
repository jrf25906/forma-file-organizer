# Review-First Selection Intent Design

Date: 2026-04-09
Branch: `codex/macos-integration-os-surface-adoption`
Status: Approved in-thread, pending written review

## Summary

Forma should add a dedicated review-first Shortcut / App Intent for explicit user selections instead of changing the meaning of the existing immediate organize intent.

The new intent should:

- accept multiple selected files or folders
- auto-organize any clearly runnable items through the existing workflow-backed ingress path
- open Forma only when reviewable items remain
- keep the app closed when the outcome is recovery-only or fully successful

This preserves the current meaning of `Organize Selected Item` while giving Shortcuts and App Intents a second, more honest handoff for "run what is safe, then bring me into Forma for the rest."

## Goals

- Add a dedicated review-first explicit-selection intent without changing existing immediate-intent behavior.
- Support multiple selected files or folders from Shortcuts/App Intents.
- Reuse the current `ExternalIngressCoordinator` path instead of introducing a second selection-ingress implementation.
- Keep user-facing result copy aligned with the structured external-ingress summary model already introduced in this branch.
- Open Forma only when review work actually remains.

## Non-Goals

- Do not change Finder service behavior in this slice.
- Do not replace or rename the existing `OrganizeSelectionIntent`.
- Do not add a new extension target, Finder Sync surface, or Quick Action bundle.
- Do not introduce a second workflow planner/runner path outside `ExternalIngressCoordinator`.
- Do not expand workflow step kinds or workflow template semantics.

## Product Decisions

### Existing intent remains immediate

`OrganizeSelectionIntent` should keep its current role as the immediate explicit-selection action. It can continue to organize a selected item through the current external-ingress path and return compact outcome messaging.

This avoids silently changing existing Shortcuts behavior and keeps backward compatibility for users who already depend on an immediate action.

### New intent is explicitly review-first

Add a second intent, likely named `ReviewSelectionIntent`, whose product promise is:

- organize what is obviously safe
- bring the user into Forma only if reviewable items remain
- otherwise return an honest result string without forcing the app open

This makes the Shortcut choice legible:

- "Organize Selected Item" means "try to complete this now"
- "Review Selected Items in Forma" means "run what is safe, then hand the remainder to Forma"

### Multi-item input is required

The new review-first intent should accept multiple `IntentFile` inputs, not just a single selected item.

The underlying ingress system already supports multiple URLs in one request, so the new intent should expose that capability directly rather than forcing users into repeated single-item invocations.

### Recovery-only outcomes should not auto-open Forma

If the result contains only skipped items or permission-recovery guidance and no reviewable items, the intent should return recovery text and keep the app closed.

That keeps "review-first" aligned with real review work instead of opening Forma for a dead-end state that the user must resolve from Finder or Shortcuts anyway.

## Options Considered

### Option A: Add a separate review-first intent

Add a new intent and App Shortcut while preserving the existing immediate intent.

Benefits:

- preserves backward compatibility
- gives users a clean, explicit choice in Shortcuts
- matches existing product language around organize vs review
- keeps Siri/App Shortcut phrases honest

Tradeoffs:

- one additional intent and phrase set to maintain

### Option B: Add a mode parameter to the existing selection intent

One intent would support both immediate and review-first behavior via a parameter.

Benefits:

- smaller surface area in theory

Tradeoffs:

- worse Shortcut ergonomics
- muddier Siri and Spotlight phrasing
- packs two distinct user intents into one action

### Option C: Add a separate review-first intent with a separate dashboard-only path

The review-first action would bypass `ExternalIngressCoordinator` and directly open Forma review state.

Benefits:

- superficially faster to sketch

Tradeoffs:

- duplicates bookmark resolution and explicit-selection scan logic
- splits outcome handling across multiple code paths
- conflicts with the branch goal of deepening existing workflow-backed rails

## Recommendation

Use Option A.

Add a dedicated multi-item review-first intent and route it through the same external-ingress coordinator with a different execution mode.

## Architecture

### 1. Add an ingress execution mode

`ExternalIngressCoordinator` should gain a small execution-policy seam, for example:

- `immediate`
- `reviewFirst`

The coordinator should continue to own:

- queuing explicit selections
- security-scoped bookmark resolution
- explicit-selection scanning
- workflow-backed auto-organization of eligible files
- structured result creation
- dashboard update publishing

The new execution mode should affect presentation behavior only, especially whether the coordinator activates Forma and publishes an external review session for immediate handoff.

### 2. Keep source attribution separate from execution policy

`ExternalIngressSource` should continue to represent the origin surface, not the product mode.

That means the new review-first App Intent should still identify as `.spotlightIntent` unless a later analytics/audit requirement proves that intent-level distinctions must be durable in source metadata.

The new behavior belongs in execution mode, not in a fake new source enum case.

### 3. New review-first intent stays thin

`FormaAppIntents.swift` should add a second selection intent that:

- accepts multiple `IntentFile` values
- keeps the same workflow-template parameter shape as the current selection intent
- calls `ExternalIngressCoordinator.handleRequest(...)` with `.reviewFirst`
- derives user-facing messages from a pure helper beside the existing selection-intent feedback code

The intent should not directly parse files, open dashboard state, or assemble external-review sessions itself.

### 4. App-open policy

The review-first execution mode should follow this policy:

- onboarding required: activate Forma
- reviewable items remain: activate Forma and publish the external-review session
- only skipped / recovery items remain: keep Forma closed
- everything auto-organized cleanly: keep Forma closed

This is the core product rule for the new intent.

### 5. Result copy model

The review-first intent should use a small dedicated copy helper that renders:

- clean success text when everything organized without review
- review handoff text when Forma opened for review
- recovery-only text when the user needs to re-run the selection to restore access
- onboarding-resume text when setup is incomplete

The copy helper should consume `ExternalIngressDisposition` / `ExternalIngressResult`, not rebuild counts itself.

## File Ownership

### Primary implementation files

- `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- `Forma File Organizing/Services/FormaAppIntents.swift`

### Secondary files only if needed

- `Forma File Organizing/Services/FormaActions.swift` only if intent-facing helpers need widening
- `Forma File Organizing/Models/WorkflowInvocationContext.swift` only if the new intent requires durable trigger differentiation

### Tests

- `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- `Forma File OrganizingTests/FormaAppIntentsTests.swift`

## Error Handling

- Preserve the existing onboarding deferral behavior and pending-request resume semantics.
- Preserve security-scoped bookmark handling and recovery messaging.
- Do not auto-open Forma for recovery-only outcomes.
- Do not silently degrade a review-first result into a generic success message when reviewable items remain.

## Testing Strategy

- Add coordinator tests for review-first execution mode:
  - review-needed results activate Forma and publish a review session
  - recovery-only results do not activate Forma
  - fully successful results do not activate Forma
- Add App Intent feedback tests for the new review-first intent helper:
  - multi-item success
  - multi-item review handoff
  - recovery-only
  - onboarding resume
- Re-run focused intent/coordinator suites first, then the repo-preferred non-UI suite.

## Acceptance Criteria

- A new explicit review-first selection intent exists alongside the current immediate selection intent.
- The new intent accepts multiple selected files or folders.
- Both intents continue to use the shared external-ingress coordinator path.
- Review-first behavior opens Forma only when real review work remains.
- Recovery-only and clean-success outcomes return honest Shortcut/App Intent text without forcing the app open.
