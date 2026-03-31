# Forma Preview-First Roadmap Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first roadmap wave that strengthens Forma's preview-first moat: first-run proof, lower-overwhelm review, safer automation, better notification tone, and promotion of useful one-off ingress into persistent monitored folders.

**Architecture:** This wave should extend the existing review-first system instead of introducing a parallel "autopilot" path. Build in sequence: establish first-run proof and chunking primitives first, then layer trust infrastructure and external-ingress promotion on top, then use the resulting data flow to define the first personal-organization-memory slice.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, macOS app services (Finder Services, Spotlight/App Intents), security-scoped bookmarks

---

## Scope and sequencing

This plan intentionally covers the `Now` roadmap bucket plus the smallest useful foundation for personal organization memory. It does **not** include cloud work, broad chatbot-style AI features, or Finder extension work.

Execution order:

1. Quick-win onboarding and first-run proof
2. Chunked review sessions and `Done for now`
3. Notification tone reset
4. External ingress promotion into persistent monitored folders
5. Trust infrastructure: simulation, preflight, rollback, audit surfaces
6. Personal organization memory foundation

This order is deliberate:

- First-run proof gives the later chunking and promotion flows a real entry point.
- Chunking should land before trust/simulation UI so review surfaces do not get redesigned twice.
- Notification copy should be updated before more automation states are exposed.
- External-ingress promotion should reuse the same monitored-folder primitives used by onboarding and settings.
- Personal memory should be built after the user interaction model is clearer, so it records stable signals rather than temporary UI behaviors.

## File map

### Core UI surfaces

- `Forma File Organizing/Views/Onboarding/WelcomeStepView.swift`
- `Forma File Organizing/Views/Onboarding/HowItWorksStepView.swift`
- `Forma File Organizing/Views/Onboarding/GetStartedStepView.swift`
- `Forma File Organizing/Views/Onboarding/OnboardingFlowView.swift`
- `Forma File Organizing/Views/MainContentView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/FileInspectorView.swift`
- `Forma File Organizing/Views/Components/FileRow.swift`
- `Forma File Organizing/Components/FileListRow.swift`
- `Forma File Organizing/Components/FileGridItem.swift`
- `Forma File Organizing/Components/FirstRunSuggestionBanner.swift`
- `Forma File Organizing/Components/ActivityFeed.swift`

### View models and coordination

- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/ViewModels/BulkOperationViewModel.swift`
- `Forma File Organizing/ViewModels/FilterViewModel.swift`
- `Forma File Organizing/ViewModels/MenuBarViewModel.swift`
- `Forma File Organizing/ViewModels/DashboardTemplateController.swift`
- `Forma File Organizing/ViewModels/DashboardPermissionState.swift`
- `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- `Forma File Organizing/Coordinators/PanelStateManager.swift`

### Automation, ingress, and services

- `Forma File Organizing/Services/AutomationEngine.swift`
- `Forma File Organizing/Services/NotificationService.swift`
- `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- `Forma File Organizing/Services/BookmarkFolderService.swift`
- `Forma File Organizing/Services/FileMonitorService.swift`
- `Forma File Organizing/Services/FileScanPipeline.swift`
- `Forma File Organizing/Services/RuleEngine.swift`
- `Forma File Organizing/Services/ActivityLoggingService.swift`
- `Forma File Organizing/Services/LearningService.swift`
- `Forma File Organizing/Services/InsightsService.swift`

### Models and persistence

- `Forma File Organizing/Models/BookmarkFolder.swift`
- `Forma File Organizing/Models/FileItem.swift`
- `Forma File Organizing/Models/FileMetadata.swift`
- `Forma File Organizing/Models/ActivityItem.swift`
- `Forma File Organizing/Models/LearnedPattern.swift`
- `Forma File Organizing/Models/ProjectCluster.swift`
- `Forma File Organizing/Models/DestinationPredictionTypes.swift`

### Settings and supporting UI

- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/Views/Settings/CustomFoldersSection.swift`
- `Forma File Organizing/Views/SidebarView.swift`
- `Forma File Organizing/Views/MenuBarView.swift`

### Tests

- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `Forma File OrganizingTests/BulkOperationViewModelTests.swift`
- `Forma File OrganizingTests/AutomationIntegrationTests.swift`
- `Forma File OrganizingTests/NotificationServiceTests.swift` if missing, create it
- `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- `Forma File OrganizingTests/BookmarkFolderServiceTests.swift`
- `Forma File OrganizingUITests/` for onboarding, review flow, and external-ingress regression coverage

### Docs to keep aligned

- `forma-feature-roadmap.md`
- `TODO.md`
- `Docs/Getting-Started/TODO.md`
- `Docs/Getting-Started/CHANGELOG.md` only when behavior actually ships
- `Docs/Getting-Started/USER-GUIDE.md`

---

### Task 1: Quick-Win Onboarding and First-Run Proof

**Dependencies:** None. This establishes the top-of-funnel entry point for the rest of the wave.

**Files:**
- Modify: `Forma File Organizing/Views/Onboarding/WelcomeStepView.swift`
- Modify: `Forma File Organizing/Views/Onboarding/GetStartedStepView.swift`
- Modify: `Forma File Organizing/Views/Onboarding/OnboardingFlowView.swift`
- Modify: `Forma File Organizing/Components/FirstRunSuggestionBanner.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardTemplateController.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: `Forma File OrganizingUITests/` onboarding flow coverage

- [ ] Define the first-run proof policy.
  Notes:
  - Favor deterministic, obvious categories first: screenshots, archives, stale downloads, invoices.
  - Use existing scan results rather than introducing a second classifier path.
  - Keep it one action at a time, not a wall of suggestions.

- [ ] Add a small value-type model for first-run proof candidates.
  Suggested location:
  - `DashboardViewModel` private type first, extract later only if reused.
  Suggested shape:
  - candidate kind
  - source folder
  - matching file count
  - suggested destination summary
  - primary CTA copy

- [ ] Wire onboarding completion to generate or reveal the first available quick-win instead of dropping the user into a generic dashboard state.

- [ ] Expand `FirstRunSuggestionBanner` from generic "Organize by type?" copy into a specific quick-win surface that can represent one concrete batch.

- [ ] Add dismissal persistence so ignored first-run prompts do not reappear too aggressively.

- [ ] Add tests for:
  - first-run suggestion appears when obvious candidates exist
  - specific candidate selection order is stable
  - dismissals persist
  - skip-onboarding still allows post-onboarding first-run proof

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`

**Acceptance notes:**
- The user sees a concrete, low-risk first action.
- The first action is based on existing file reality, not template theory.

---

### Task 2: Chunked Review Sessions and `Done for Now`

**Dependencies:** Task 1. Reuse the first-run proof model and avoid separate batch semantics.

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/ViewModels/BulkOperationViewModel.swift`
- Modify: `Forma File Organizing/ViewModels/FilterViewModel.swift`
- Modify: `Forma File Organizing/Views/MainContentView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/Components/FileRow.swift`
- Modify: `Forma File Organizing/Components/FileListRow.swift`
- Modify: `Forma File Organizing/Components/FileGridItem.swift`
- Test: `Forma File OrganizingTests/BulkOperationViewModelTests.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] Define chunk-session state.
  Required behaviors:
  - current chunk size
  - current chunk identity/scope
  - files deferred by `Done for now`
  - ability to resume later without losing overall review integrity

- [ ] Add dashboard-level chunk computation based on current reviewable files.
  Constraints:
  - do not mutate underlying file status just to hide deferred items
  - keep external review session behavior compatible

- [ ] Add a `Done for now` action that defers the current chunk without implying the work is complete.

- [ ] Update default-panel hero copy and progress framing to emphasize handled work over remaining backlog.

- [ ] Make card/list/grid surfaces show the same chunk-scoped action semantics.
  Important parity surfaces:
  - `FileRow.swift`
  - `FileListRow.swift`
  - `FileGridItem.swift`
  - `MainContentView.swift`

- [ ] Ensure menu bar and external review scope do not accidentally inherit hidden-deferred state unless explicitly intended.

- [ ] Add tests for:
  - chunk size stability
  - deferred chunk exclusion from the current session only
  - resume behavior
  - interaction with external review scoping

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/BulkOperationViewModelTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`

**Acceptance notes:**
- The user can stop without feeling like they failed.
- The dashboard no longer shouts the entire backlog at once.

---

### Task 3: Notification Tone Reset

**Dependencies:** Tasks 1-2. Notification language should reflect the new quick-win and chunking behavior.

**Files:**
- Modify: `Forma File Organizing/Services/NotificationService.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Models/ActivityItem.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Test: `Forma File OrganizingTests/AutomationIntegrationTests.swift`
- Test: `Forma File OrganizingTests/NotificationServiceTests.swift`

- [ ] Audit existing notification types and classify them as:
  - progress/wins
  - reminders
  - errors/permissions

- [ ] Rewrite backlog reminder copy so it frames momentum and next steps rather than guilt.

- [ ] Rewrite auto-organize summary copy to emphasize benefit and clarity.

- [ ] Keep error and permission notifications explicit, but reduce blame language.

- [ ] Add test coverage around rendered notification copy and identifiers so future changes do not regress tone or deduping behavior.

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/AutomationIntegrationTests"`

**Acceptance notes:**
- Notifications feel like operational status, not nagging.
- Reminder copy matches the roadmap’s emotional strategy.

---

### Task 4: Promote One-Time External Requests Into Persistent Monitored Folders

**Dependencies:** Task 2. This should use the same chunk/review semantics, not bypass them.

**Files:**
- Modify: `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Services/BookmarkFolderService.swift`
- Modify: `Forma File Organizing/Models/BookmarkFolder.swift`
- Modify: `Forma File Organizing/Views/SidebarView.swift`
- Modify: `Forma File Organizing/Views/Settings/CustomFoldersSection.swift`
- Test: `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- Test: `Forma File OrganizingTests/BookmarkFolderServiceTests.swift`

- [ ] Decide the promotion model.
  Recommendation:
  - start with standard bookmarked folders only if possible
  - if arbitrary folder support is required, add a clearly scoped bookmark-folder representation rather than reviving the old duplicated `CustomFolder` model

- [ ] Add a post-review affordance when an external session came from a folder and the session proved useful.

- [ ] Persist the promoted folder into the monitored-folder source of truth used by sidebar/settings/automation.

- [ ] Ensure promoted folders respect:
  - enable/disable state
  - automation inclusion/exclusion state
  - bookmark validity checks

- [ ] Add tests for:
  - promotion offered only for eligible folder-based ingress
  - promotion survives app restart
  - invalid/stale bookmarks fail safely

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests"`

**Acceptance notes:**
- A good one-time Finder/Spotlight experience can become a persistent workflow with one deliberate action.

---

### Task 5: Trust Infrastructure: Simulation, Preflight, Rollback, Audit

**Dependencies:** Tasks 1-4. Do this after chunking and ingress promotion so trust surfaces describe the settled workflow model.

**Files:**
- Modify: `Forma File Organizing/Services/RuleEngine.swift`
- Modify: `Forma File Organizing/Services/FileScanPipeline.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Components/ActivityFeed.swift`
- Test: `Forma File OrganizingTests/AutomationIntegrationTests.swift`
- Test: create focused tests for simulation/preflight if missing

- [ ] Introduce rule simulation as a pure read-only path first.
  Required behavior:
  - evaluate a rule against existing files
  - produce counts and representative examples
  - do not mutate status or destination

- [ ] Add a preflight result type for automation runs.
  Include:
  - eligible count
  - skipped for missing destination
  - skipped for permission/access issues
  - skipped for confidence threshold

- [ ] Surface simulation and preflight summaries in the rule-builder or inspector flow before deeper automation changes.

- [ ] Improve rollback discoverability by linking recent automated batches to undo-capable activity entries where possible.

- [ ] Expand audit wording in activity/history views so users can answer:
  - what happened
  - why it happened
  - whether it was automatic or review-driven
  - whether it can be undone

- [ ] Add tests for:
  - simulation does not mutate state
  - preflight correctly categorizes skipped items
  - automated batch activity entries remain undo-compatible

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

**Acceptance notes:**
- Forma should feel safer than prompt-based tools because it can explain and simulate before it acts.

---

### Task 6: Personal Organization Memory Foundation

**Dependencies:** Tasks 1-5. Record stable user behavior only after the interaction model above is in place.

**Files:**
- Modify: `Forma File Organizing/Models/ActivityItem.swift`
- Modify: `Forma File Organizing/Models/FileItem.swift`
- Modify: `Forma File Organizing/Models/LearnedPattern.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/Services/LearningService.swift`
- Modify: `Forma File Organizing/Services/InsightsService.swift`
- Modify: `Forma File Organizing/Models/ProjectCluster.swift` only if needed
- Test: `Forma File OrganizingTests/AutomationIntegrationTests.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: create focused `LearningService` tests if needed

- [ ] Define the first memory slice explicitly.
  Keep scope narrow:
  - accepted destination preferences
  - overridden suggestions
  - deferred chunk patterns
  - promoted monitored-folder origins
  Do not build the full metadata layer yet.

- [ ] Add the minimum schema/persistence changes needed to record those signals without breaking existing learning behavior.

- [ ] Teach `LearningService` and insight generation to distinguish between:
  - durable preferences
  - one-off quick wins
  - rejected or deferred suggestions

- [ ] Add one user-visible insight powered by this memory foundation, but keep it inspectable.
  Example:
  - "You usually move invoices to Finance. Make this a trusted rule?"

- [ ] Add tests for:
  - memory signals are recorded once per meaningful action
  - deferrals and overrides are distinguishable from accepts
  - old learned-pattern behavior still works

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

**Acceptance notes:**
- Forma starts compounding user-specific knowledge without turning into an opaque AI layer.

---

## Cross-cutting testing checklist

- [ ] Add or update unit tests for every new view-model state transition.
- [ ] Add focused integration tests for automation + external-ingress edge cases.
- [ ] Add UI tests for:
  - onboarding first-run proof
  - chunked review flow
  - post-review monitored-folder promotion
- [ ] Re-run non-UI tests:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`
- [ ] Re-run app build:
  Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build`

## Docs follow-up after implementation

- [ ] Update `TODO.md` and `Docs/Getting-Started/TODO.md` as slices land.
- [ ] Update `Docs/Getting-Started/CHANGELOG.md` only for shipped behavior.
- [ ] Update `Docs/Getting-Started/USER-GUIDE.md` once first-run proof and chunked review are user-visible.
- [ ] Update architecture docs if monitored-folder ownership or simulation/preflight architecture changes materially.

## Risks and guardrails

- Do not let chunking mutate persistence in ways that make files "disappear."
- Do not reintroduce a second custom-folder persistence system alongside bookmark-backed folder state.
- Do not build autopilot-first UX while implementing trust infrastructure.
- Do not let personal memory become generic black-box scoring without inspectable reasoning.
- Keep file-surface parity across:
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/MainContentView.swift`
