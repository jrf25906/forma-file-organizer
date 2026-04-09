# Progressive Automation Upgrades Design

Date: 2026-04-07
Branch: `progressive-automation-upgrades`
Status: Draft

## Summary

`Progressive automation trust scopes v1` created the narrow promotion foundation, but it did not yet turn trusted automation into a first-class product surface. Users can earn trust from review, but they still cannot clearly answer:

- what exactly is trusted
- where autopilot is active
- whether a scope is healthy or blocked
- what a trusted scope did recently
- how to pause or revoke one scope without treating all automation the same

This branch should productize that foundation without jumping ahead to `workflow-engine-v2`.

The release goal is to make promoted rule, folder, and category scopes visible optional autopilot boundaries with clear lifecycle controls, scope health, recent-run context, and scope-aware simulation, preflight, audit, and notifications.

The branch remains intentionally narrow:

- review-earned trust stays the gate
- preview-first stays the default outside trusted scopes
- automatic execution stays move-only
- no generic workflow authoring or multi-step chaining lands here

## Goals

- Make active trusted scopes visible and understandable in ordinary product surfaces.
- Persist explicit trusted boundaries so a promoted scope means more than a loose label.
- Add first-class lifecycle controls for active scopes, including pause, resume, and revoke.
- Add derived health states that explain whether a scope is healthy, quiet, or needs attention.
- Deepen simulation, preflight, audit, and notification behavior around promoted scopes without broad workflow expansion.
- Keep `progressive-automation-upgrades` clearly separate from the later `workflow-engine-v2` branch.

## Non-Goals

- No default-on autopilot posture.
- No blank-canvas workflow builder.
- No multi-step `rename -> tag -> move -> notify -> log` execution.
- No project-space-triggered workflow actions yet.
- No broad manual scope creation flow outside review-earned trust promotion.
- No cloud sync, collaboration, or shared trust state.

## Current State

The repo already has the first narrow trust-scope layer:

- `TrustedAutomationScope` persistence exists.
- `TrustedAutomationScopeService` can recommend and promote rule, folder, and category scopes from review-earned evidence.
- the review celebration flow can surface `Trust this automatically`

That foundation is still too narrow for the intended release slice:

- trusted scopes are not yet a first-class management surface
- boundary data is not explicit enough to explain scope ownership clearly
- automation state, preflight, notifications, and activity remain mostly global instead of scope-owned
- users do not get a durable scope detail view with recent runs, blockers, or lifecycle controls
- the product still feels like "automation with a trust suggestion" instead of "visible optional autopilot scopes"

## Options Considered

### Option A: Dedicated scope layer with explicit boundary descriptors and a narrow scope-run ledger

This option keeps `TrustedAutomationScope` as the permission ledger, expands it with explicit trusted-boundary data, and adds a narrow persisted scope-run model for preflight/execution summaries.

Benefits:

- makes scopes truly first-class
- supports clear scope boundaries, health, recent runs, and lifecycle controls
- keeps the branch self-contained instead of depending on `workflow-engine-v2`
- delivers a user-visible release without prematurely building full workflow audit

Tradeoffs:

- adds another narrow audit layer before the broader workflow engine expands
- requires deliberate separation so this does not turn into chain infrastructure by accident

### Option B: Settings-only scope management backed by derived global automation state

This would add a scope list in Settings and derive health/recent behavior from global automation state plus generic activity rows.

Benefits:

- cheaper implementation
- minimal new persistence

Tradeoffs:

- weak "first-class" story
- fragile recent-run and health explanations
- default panel and trust surfaces still feel disconnected
- leaves too much ambiguity about scope boundaries and blockers

### Option C: Wait for `workflow-engine-v2` and use workflow audit as the scope surface

This would avoid a separate scope-run layer and defer recent-run visibility until workflow expansion lands.

Benefits:

- avoids temporary overlap between scope audit and workflow audit
- keeps engine concepts centralized

Tradeoffs:

- delays a promised user-visible autopilot release behind another foundational branch
- couples `progressive-automation-upgrades` to a branch that is intentionally sequenced later
- weakens the value of trusted scopes in the meantime

## Recommendation

Use Option A.

`progressive-automation-upgrades` should ship as its own user-visible branch with scope-owned lifecycle and visibility, not as a waiting room for `workflow-engine-v2`.

The right boundary is:

- explicit trust boundaries now
- scope lifecycle, health, preflight, and recent-run visibility now
- multi-step workflow execution and deeper chain audit later

## Proposed Design

### 1. Expand trusted scopes from a permission row into an explicit boundary

`TrustedAutomationScope` should remain the canonical permission ledger, but promotion has to persist enough boundary data that the scope can later be explained and matched without guessing from transient file state.

Each promoted scope should persist a trusted boundary descriptor, or an equivalent explicit set of persisted fields, that captures:

- scope type
- trusted source boundary
- trusted destination snapshot
- the concrete object identity when one exists, such as rule ID
- the user-facing boundary summary shown in scope lists and detail views

Recommended boundary shape by type:

- `rule`
  - explicit `Rule.id`
  - rule name
  - destination snapshot
- `folder`
  - monitored root identity or subtree identity
  - source-location context when relevant
  - destination snapshot
- `category`
  - file category
  - trusted destination snapshot
  - concise context summary for where the category earned trust

Important constraint:

- trusted scope matching must be bookmark-backed and destination-aware
- same-name folders must never be treated as interchangeable
- promotion should refresh an existing scope when the identity truly matches, not create near-duplicates

### 2. Separate lifecycle status from health

This branch should stop overloading "status" to mean everything.

Lifecycle status should remain explicit user- or system-controlled state:

- `active`
- `paused`
- `revoked`

Health should be a derived read model that explains whether an active scope is currently trustworthy to run:

- `healthy`
  - boundary resolves cleanly and recent runs are not reporting blockers
- `needsAttention`
  - destination access is broken, the rule is stale or disabled, or recent runs are being held or failing
- `quiet`
  - the scope is valid but has had no meaningful recent matches

Paused and revoked scopes should present lifecycle first and health second:

- paused scopes are intentionally dormant
- revoked scopes preserve history but are no longer candidates for autopilot

### 3. Add a narrow scope-run ledger for recent runs, simulation, and preflight

This branch needs more audit than a plain activity row, but less than the later workflow engine.

Add a narrow persisted scope-run model that records scope-level summaries only. It should not become a generic workflow-run system.

Each scope-run record should capture:

- scope ID
- timestamp
- trigger source
  - promotion preview
  - scheduled automation pass
  - realtime automation pass
  - manual refresh or inspection
- status
  - simulated
  - executed
  - held
  - failed
- counts for:
  - matched
  - eligible
  - organized
  - held
  - failed
- held or failure buckets such as:
  - permission
  - missing destination
  - low confidence
  - excluded from automation
- a concise summary line
- a small set of example file names

This gives the scope detail UI enough context to say:

- what this scope would do now
- what it did last time
- what is blocking it when it is not healthy

It also keeps the branch cleanly short of `workflow-engine-v2`, which should own broader per-step and per-file chain audit later.

### 4. Make the automation engine scope-aware

`AutomationEngine` should stop treating trusted scopes as a side story and start treating them as the explicit auto-organize boundary when the feature is enabled.

Add a `TrustedAutomationScopeResolver` that:

- matches candidate files against active trusted scopes
- confirms destination alignment against the trusted boundary descriptor
- prefers narrower matching when multiple scopes could apply
- skips paused and revoked scopes

Preflight should become scope-aware:

- global preflight can remain for the top-level automation card
- scope detail should also expose the latest scope-specific preflight rollup

Automatic organize behavior should follow one clear rule:

- only files that match an active trusted scope may auto-organize when trusted scopes are enabled
- everything else stays in the preview-first review flow

### 5. Make scopes first-class UI in the default panel and Settings

This branch should give scopes two homes:

#### Default Panel

The default panel should gain a concise `Autopilot scopes` surface near the existing automation status area.

That surface should show:

- active scope count
- a small list of the most relevant scopes
  - recently active
  - needs attention
  - newly promoted
- direct entry into scope detail

This is the "what is autopilot doing on my Mac right now?" surface.

#### Settings

Settings should become the management home for full scope lifecycle.

It should present grouped sections for:

- active scopes
- paused scopes
- revoked scopes

Each row should show:

- scope type
- boundary summary
- destination summary
- lifecycle status
- health state
- last run or last activity summary

Scope detail should support:

- pause
- resume
- revoke
- recent-run inspection
- latest preflight summary
- earned-trust rationale

### 6. Upgrade the review promotion flow from suggestion to boundary preview

The review celebration flow remains the only creation path for this slice, but the promotion sheet should get more explicit.

The confirmation UI should show:

- recommended scope and alternatives
- source boundary
- trusted destination
- the automatic behavior that becomes allowed
- a first scope-specific preflight or simulation summary

That keeps trust explicit at the moment of promotion instead of making the user confirm a vague future permission.

### 7. Add scope-aware activity and notifications

Current automation activity and notifications are too global for a scope-first autopilot release.

Activity should gain scope-aware entries for:

- scope promoted
- scope paused
- scope resumed
- scope revoked
- scope auto-organized run summary
- scope needs attention

Notifications should become more specific when a single scope is involved, for example:

- `Screenshots moved 6 files automatically`
- `Receipts needs folder access before autopilot can run`

When a pass spans multiple scopes, notifications should stay concise and group by scope count rather than spam per-file updates.

Tone should remain aligned with the repo's current direction:

- progress and health
- no guilt-driven backlog framing

### 8. Hold the line before `workflow-engine-v2`

This branch should intentionally stop short of:

- multi-step workflow templates
- deeper per-file workflow audit
- rollback redesign
- project-space-triggered workflow execution

The output of this branch should be:

- users understand and manage trusted autopilot scopes
- automation has a visible lifecycle and trust surface
- the next branch can focus on broader workflow power, not on basic trust legibility

## Exit Criteria

- Users can identify every active autopilot scope at a glance from ordinary product surfaces.
- Each promoted scope has an explicit visible boundary and destination summary.
- Scope detail exposes lifecycle controls, health, recent runs, and the latest scope-specific preflight summary.
- Automatic moves are restricted to active trusted scopes when the feature is enabled.
- Notifications and activity explain scope behavior in scope-aware language instead of generic automation summaries.
- No multi-step workflow authoring or broader chain execution slips into this branch.

## Explicit Deferrals

The following stay with later branches:

- multi-step workflow templates and executors
- richer per-file workflow audit and rollback
- project-space-triggered automation
- sync, backup, and shared trust state
- collaboration or cloud-managed autopilot

## Recommendation

Proceed with `progressive-automation-upgrades` as the branch that turns trusted-scope promotion into a visible, optional, lifecycle-managed autopilot surface.

That is the clean bridge between:

1. `cross-folder-project-spaces-v2`
2. `progressive-automation-upgrades`
3. `workflow-engine-v2`

It honors the roadmap posture: retrieval and local memory first, then earned automation, then broader workflow power.
