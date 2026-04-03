# Progressive Automation Trust Scopes V1 Design

**Status:** Current
**Last Updated:** 2026-04-03
**Audience:** Developers, Product, Design

## Goal

Start the roadmap's progressive automation upgrades by giving Forma a narrow, visible, review-earned autopilot system.

This first slice should let users promote trusted behavior into scoped automatic organization without changing Forma's default posture:

1. Review remains the place where trust is earned.
2. Preview-first remains the default outside trusted scopes.
3. Automatic behavior in v1 stays limited to the current `match -> move -> log` flow.

This design should also create the product and data foundation for later roadmap work:

- workflow chains (`rename`, `tag`, `notify`)
- metadata-backed project and retrieval features
- Finder/Forma tag sync

Those later items are intentionally not part of this implementation target.

## Problem Statement

Forma currently has two strong but disconnected ideas:

- it is intentionally preview-first and trust-oriented
- it already supports background scanning and global auto-organize behavior

The gap is that users cannot grant trust narrowly.

Today:

- `AutomationPolicy` resolves automation globally through `AutomationMode`
- `AutomationEngine` can auto-organize any eligible file once global policy allows it
- `PersonalMemoryService` and `LearnedPattern` can identify repeated stable behavior
- the review flow is where the user most clearly signals "yes, this outcome was right"

What is missing is a way to say:

- trust this rule automatically
- trust this monitored folder automatically
- trust this file category automatically

Without that intermediate layer, users are forced into an awkward choice:

- stay fully preview-first forever
- or enable broader auto-organize than they may actually trust

That is misaligned with the product strategy in [forma-feature-roadmap.md](../../../../forma-feature-roadmap.md): autopilot should be earned, visible, and narrow before it expands.

## Product Principles

1. Trust must be earned from successful manual behavior, not assumed upfront.
2. The narrowest safe scope should be recommended first.
3. Preview-first remains the default outside active trusted scopes.
4. Scope state must be visible, reversible, and legible in ordinary product surfaces.
5. V1 should reuse the current automation engine and move flow where possible.
6. The first implementation target must not silently pull workflow chaining or metadata sync into scope.
7. Future workflow actions should be represented in the model now, but not executed in v1.

## Scope

### In Scope for V1

- add a persisted trust-scope ledger that supports `rule`, `folder`, and `category` scope types
- add a review-flow `Trust this automatically` promotion path
- present a recommended-scope confirmation sheet that preselects the narrowest safe scope
- immediately allow current auto-move behavior inside confirmed trusted scopes
- show active and paused scopes in Settings and summary surfaces
- show when a file or automation action is inside a trusted scope
- gate the feature behind a dedicated feature flag at the entry point
- add targeted model, service, integration, and UI coverage

### Explicitly Out of Scope

- executing `rename`, `tag`, or `notify` as part of automatic chains
- building the later workflow-chain engine
- adding new metadata authoring UX
- writing or syncing Finder tags
- implementing bidirectional Finder/Forma metadata sync
- broad manual scope creation from arbitrary surfaces
- changing the default global automation posture away from preview-first

## Approach Options

### Option A: Unified trust-scope ledger

Create one persisted `TrustedAutomationScope` model for `rule`, `folder`, and `category` scopes, then resolve auto-organize eligibility through that shared ledger.

Pros:

- one mental model for users
- one persistence model for developers
- one policy-resolution path for automation
- extends cleanly into future workflow chaining

Cons:

- requires slightly more upfront design than a narrow rule-only solution

### Option B: Rule-first with derived folder/category wrappers

Treat trusted rules as the only real primitive and turn folder/category promotions into hidden generated rules.

Pros:

- maximizes reuse of the existing rule system

Cons:

- folder/category trust becomes an awkward abstraction leak
- the UI ends up describing scopes that do not really exist as first-class objects
- harder to extend into future action chains cleanly

### Option C: Separate implementations for each scope type

Build independent persistence, matching, and UI logic for trusted rules, trusted folders, and trusted categories.

Pros:

- fastest path to a prototype

Cons:

- duplicated matching and lifecycle logic
- inconsistent management UI
- difficult to reason about precedence and future workflow support

## Recommendation

Use Option A: a unified trust-scope ledger.

This is the smallest implementation that still matches the product intent:

- review earns trust
- trust becomes visible state
- automation only expands where that trust exists

It also avoids painting later workflow chaining and metadata work into separate corners.

## Proposed Design

### 1. Add a Dedicated Trusted Scope Ledger

V1 should add a new SwiftData model:

- `TrustedAutomationScope`

Recommended fields:

- `id`
- `scopeType`
  - `rule`
  - `folder`
  - `category`
- `scopeKey`
  - stable unique identifier for the promoted scope
- `displayName`
  - user-facing label shown in Settings, status, and activity surfaces
- `status`
  - `active`
  - `paused`
  - `revoked`
- `promotionSource`
  - `reviewFlow`
  - reserve additional values for later manual and suggestion surfaces
- `recommendationSource`
  - `matchedRule`
  - `learnedPattern`
  - `personalMemory`
  - `reviewAcceptance`
- `evidenceAcceptedCount`
- `evidenceOverrideCount`
- `evidenceUndoCount`
- `evidenceCorrectionCount`
- `confidenceSnapshot`
- `rationaleSummary`
- `allowedActions`
  - v1 persists only `move`
  - later schema may also contain `rename`, `tag`, `notify`
- `createdAt`
- `updatedAt`
- `lastUsedAt`
- `revokedAt`

The ledger is the product truth for trusted automation state.

Uniqueness rule:

- scopes should be unique by `scopeType + scopeKey`
- promoting the same scope again should refresh evidence and reactivate a paused scope, not create a duplicate row

It should not be folded into `Rule`, `BookmarkFolder`, or `LearnedPattern`, because those models already have separate responsibilities:

- `Rule` describes matching logic and destination behavior
- `BookmarkFolder` describes monitored roots and permissions
- `LearnedPattern` describes inferred habits
- `TrustedAutomationScope` describes where the user has explicitly allowed autopilot

### 2. Define Stable Scope Keys

`scopeKey` needs to be deterministic and explainable:

- `rule`
  - use the existing `Rule.id`
- `folder`
  - use the monitored root identity rather than a raw path
  - in practice this should map to the bookmark-backed monitored folder identity already used by automation
- `category`
  - use the existing `FileTypeCategory.rawValue`

Important constraint:

- category scopes in v1 should mean existing `FileTypeCategory` values such as `documents` or `images`
- finer semantic groupings like `screenshots` or `invoices` remain future work, likely built from rules or metadata

This keeps the first implementation aligned with the current codebase instead of inventing a second category system.

### 3. Review Flow Owns the First Promotion Entry

The first creation path for trusted scopes should live in the review flow, because that is where Forma receives the clearest trust signal.

Behavior:

- after a qualifying successful manual organize action, the review-success surface shows `Trust this automatically`
- selecting that action opens a compact recommended-scope sheet
- the sheet explains:
  - the recommended scope
  - why it is being recommended
  - what automatic behavior will be enabled
  - the alternative scope types the user may choose instead
- confirming writes or reactivates a `TrustedAutomationScope`

V1 creation entry is intentionally narrow:

- review flow is the only place users create a new trusted scope in this slice
- Settings is the management surface for already-created scopes

This preserves the "hybrid" long-term direction without forcing broad manual scope creation into the first implementation target.

### 4. Recommend the Narrowest Safe Scope

The recommended-scope sheet should preselect the narrowest safe scope using current evidence.

Recommendation order:

1. `rule`
2. `folder`
3. `category`

Suggested heuristics for v1:

- recommend `rule` when the approved file is governed by an existing explicit rule, or when the same repeated behavior can be turned into a concrete rule immediately
- recommend `folder` when the behavior is stable within one monitored root but not yet stable enough across contexts to promote more broadly
- recommend `category` when the same file-type category has been accepted repeatedly across multiple relevant contexts and no narrower rule recommendation is clearly better

Minimum promotion evidence should be explicit enough for implementation planning:

- at least 3 successful accepted behaviors in the same context
- zero undo events across the last 5 related memory events in that context
- correction or override rate at or below 20 percent for the candidate context
- destination remains valid and bookmark-resolvable

If no recommendation meets that bar:

- no trust CTA should be shown

### 5. Rule-Scope Promotion Must Materialize a Real Rule

If the recommended scope type is `rule` and the behavior does not yet point at an existing explicit rule, confirmation should:

1. create or upsert a real `Rule`
2. create or update a `TrustedAutomationScope` that points at that rule's ID

This is important because v1 should not invent a shadow rule system.

Lifecycle rule:

- removing or pausing a trusted rule scope should not delete the underlying rule
- the rule remains available for preview-first suggestions and manual review behavior
- the scope only controls whether that rule may auto-execute

Inside automation, trusted rule scopes should resolve against the real rule engine and real rule identifiers. Folder and category scopes remain first-class ledger objects and should not be translated into hidden generated rules.

### 6. Keep Global Automation Policy, Add Scope-Specific Authorization

`AutomationPolicy` should remain the global gate for whether automation is even allowed to scan and auto-organize.

V1 adds a second gate:

- a candidate file may auto-organize only if it passes normal preflight and matches at least one active trusted scope

This means global automation still controls:

- whether background automation is running
- whether auto-organize is enabled
- notification settings
- thresholds and backoff behavior

Trusted scopes newly control:

- where automatic moves are permitted

Trusted scopes do not:

- invent a destination by themselves
- bypass destination validity checks
- bypass permission checks
- bypass the existing confidence threshold
- override exclusion or skip logic already present in automation preflight

This is the core product behavior change.

### 7. Add a Scope Resolver Instead of Rewriting the Engine

V1 should add a dedicated resolver, for example:

- `TrustedAutomationScopeResolver`

Responsibilities:

- load active scopes
- evaluate whether a candidate file matches any active scope
- return the matched scope and match reason
- enforce precedence when multiple scopes match

Recommended precedence:

1. explicit trusted rule
2. trusted folder
3. trusted category

That precedence should be used consistently by:

- automation preflight filtering
- inspector reasoning UI
- activity/audit copy

This lets `AutomationEngine` and `DashboardFileScanProvider` stay mostly intact:

- `DashboardFileScanProvider` still loads candidates
- existing preflight still filters by destination validity, permissions, confidence, and exclusion rules
- the new resolver adds one more eligibility requirement before a candidate is considered auto-organize-ready

### 8. Preserve the Current Automatic Action Set in V1

Promoted scopes should immediately enable the current automatic move behavior, but only that behavior.

In v1 the executable action set is:

- `match -> move -> log`

Not in v1:

- `rename`
- `tag`
- `notify` as a workflow action

Current notifications about automation outcomes may still fire, but they remain side effects of the move/log flow, not separate chain steps.

This keeps the first slice shippable and avoids coupling trust scopes to unfinished workflow infrastructure.

### 9. User-Facing Surfaces

#### Review Flow

The review success state becomes the creation surface:

- show `Trust this automatically` only when recommendation criteria are met
- open the recommended-scope sheet from that CTA
- after confirmation, show a success message such as:
  - `Autopilot enabled for this rule`
  - `Autopilot enabled for Downloads`
  - `Autopilot enabled for Images`

Likely implementation touch points:

- `DashboardOrganizationController.swift`
- dashboard review-success state in the current review experience

#### Default Panel

`DefaultPanelView` should summarize trusted scope state inside the automation section, for example:

- `Autopilot active in 2 trusted scopes`

It should not become a creation surface in v1.

#### Settings

`SmartFeaturesSection` should gain a trusted-scope management subsection that lists:

- active scopes
- paused scopes

Per-row actions:

- `Pause`
- `Resume`
- `Remove`

V1 Settings behavior is management-only, not creation-from-scratch.

#### File Inspector

`FileInspectorView` should show whether the current file is:

- inside an active trusted scope
- outside trusted scopes and still preview-only

This is important for legibility. Users should not have to infer why a file will move automatically.

### 10. Activity, Audit, and Reversibility

Automation actions taken because of a trusted scope should name that scope in user-facing audit text.

Recommended additions:

- scope creation log
- scope pause/resume log
- scope removal log
- auto-organize batch details that include the matched scope label when practical

The existing undo path remains the reversal mechanism for automatic moves.

If an automatic move is undone later, that event should remain a strong negative signal for future recommendations, but v1 does not need to auto-revoke the scope immediately. A later refinement can tune revocation heuristics after real usage.

### 11. Feature Flag and Rollout

This roadmap item should be gated behind a dedicated feature flag, for example:

- `trustedAutomationScopes`

Recommended dependency chain:

- `patternLearning`
- `backgroundMonitoring`
- `autoOrganize`

Rationale:

- recommendation depends on learned behavior
- the promoted behavior only matters when automation and auto-organize are active

The entry point must be guarded at the user-facing promotion surface using `FeatureFlagService.shared.isEnabled(...)`, per repo convention for AI/automation features.

### 12. Implementation Touch Points

Expected primary code areas:

- models
  - new `TrustedAutomationScope`
- services
  - `PersonalMemoryService` or a new recommendation helper for evidence lookup
  - new scope service / scope resolver
  - `AutomationEngine`
  - `DashboardFileScanProvider`
  - `FeatureFlagService`
- view models / coordinators
  - `DashboardOrganizationController`
  - `DashboardViewModel`
- views
  - `DefaultPanelView`
  - `SmartFeaturesSection`
  - `FileInspectorView`

This slice should avoid unrelated UI churn outside those surfaces.

## Testing

### Model and Service Coverage

- create/update/reactivate trusted scopes without duplicates
- resolve scope keys and display names deterministically
- recommend the narrowest safe scope from given evidence
- enforce rule > folder > category precedence
- ensure category scope maps only to existing `FileTypeCategory` values

### Automation Coverage

- auto-organize candidates outside active trusted scopes are skipped
- candidates inside active scopes still respect existing preflight checks
- paused or revoked scopes no longer authorize automatic moves
- trusted rule promotion creates a real rule before scope activation

### UI Coverage

- review flow shows the promotion CTA only when recommendation criteria are met
- recommended-scope sheet reflects recommendation and alternatives correctly
- Settings lists active and paused scopes with the expected actions
- Default panel automation summary reflects scope counts
- File inspector shows scope membership state correctly

## Explicit Deferrals

The following are intentionally deferred and should not be backdoored into this implementation plan:

- multi-step workflow execution
- rule-step chaining
- local metadata tags as a product primitive
- Finder tag writes
- Finder/Forma tag reconciliation
- bidirectional metadata sync
- manual scope creation outside review flow

These remain important roadmap work, but they are separate implementation targets.

## Why This Slice First

This first implementation target is valuable on its own:

- it makes automation feel earned instead of binary
- it gives users a visible answer to where autopilot is active
- it narrows automatic behavior to places the user has explicitly trusted

It also preserves planning clarity for later work:

- trust scopes decide where automation may act
- a future workflow engine decides what multi-step chain to run
- a future metadata layer decides what non-folder state exists

That separation is what keeps the roadmap buildable instead of collapsing into one oversized automation rewrite.
