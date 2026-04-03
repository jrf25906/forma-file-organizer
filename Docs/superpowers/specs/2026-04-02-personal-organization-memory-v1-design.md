# Personal Organization Memory V1 Design

**Status:** Current
**Last Updated:** 2026-04-02
**Audience:** Developers, Product, Design

## Goal

Start the personal-organization-memory layer so Forma compounds from user-specific behavior rather than generic AI classification, while preserving the product's preview-first trust posture.

This v1 should improve two existing surfaces, in order of importance:

1. Review suggestions and explanations
2. Rule suggestions generated from repeated stable behavior

It should also define the data foundation that later roadmap work will consume:

- Progressive automation upgrades
- Metadata Layer v1

## Problem Statement

Forma already records useful history, but the strongest user-intent signals are still too implicit to serve as durable product memory.

Today:

- `ActivityItem` is the user-facing audit feed and stores broad event types plus free-form `details`
- `ActivityLoggingService` logs human-readable outcomes, but not normalized suggestion-vs-choice data
- `LearningService` detects repeated patterns from coarse activity history
- `FileScanPipeline` applies explicit rules first, then learned patterns, then ML destination prediction

That is enough for general heuristics, but not enough for a trustable personal memory layer.

Missing signals include:

- whether the user accepted the original suggestion unchanged
- whether they overrode the proposed destination before organizing
- whether they later undid or corrected the outcome
- whether a skip meant "not now" or "wrong pattern"
- which contexts are stable enough to generalize into reusable rules

Without a structured memory layer, Forma risks either:

- overfitting to generic classification or weak proxies
- or shipping visible "learning" behavior that is hard to trust and hard to evolve into automation and metadata later

## Product Principles

1. User-specific behavior should outrank generic classification whenever sufficient evidence exists.
2. Explicit corrections, overrides, and undo/recovery behavior are stronger signals than passive acceptance.
3. Preview-first remains the default posture. Memory should improve suggestions before it expands automation.
4. Local-first and reversible are part of the product value, not implementation details.
5. Keep the first visible payoff small and legible: better suggestions, better explanations, better rule suggestions.
6. Reuse existing surfaces and models where that reduces scope, but do not force durable learning into audit-oriented abstractions.

## Scope

### In Scope for V1

- Add a structured local memory store for organization decisions
- Capture strong decision signals from review, organization, rule suggestion, and undo/correction flows
- Derive queryable preference state from those memory events
- Use that preference state to improve review suggestions and their explanations
- Use that preference state to improve rule-suggestion quality and thresholds
- Add a light Settings summary/reset surface for transparency and recovery

### Explicitly Out of Scope

- Default-on autopilot or broad auto-organize expansion
- A full memory-inspector or manual memory-editing UI
- Cloud sync, backup, export, or sharing
- Broad metadata authoring UX
- Finder/out-of-app correction tracking
- Replacing the full rule system, rule UI, or ML prediction stack

## Approach Options

### Option A: Keep extending `ActivityItem`

Continue logging more fields onto the activity feed and derive memory directly from activity history.

Pros:

- Lowest short-term implementation cost
- Reuses existing persistence and audit history

Cons:

- Keeps durable learning coupled to a human-readable log
- Encourages more parsing of free-form `details`
- Makes later automation and metadata work harder to reason about

### Option B: Replace the current learning path with a brand-new subsystem immediately

Route all learning, suggestions, and rule-generation through a clean memory architecture right away.

Pros:

- Cleanest long-term architecture
- Clearer separation between audit history and product memory

Cons:

- Too much rewrite for the first slice
- Higher migration and regression risk
- Delays the first visible payoff

### Option C: Hybrid memory layer beside the audit feed

Keep `ActivityItem` as the audit/history surface, but add a dedicated structured memory layer and move consumers onto it incrementally.

Pros:

- Preserves existing audit behavior
- Creates a reliable foundation for later roadmap items
- Fits the scope of a first visible improvement

Cons:

- Temporary overlap between human-readable logging and structured memory capture
- Some existing suggestion logic will coexist during the transition

## Recommendation

Use Option C.

This is the smallest change that gives Forma durable product memory without forcing a subsystem rewrite. It also keeps the first user-facing proof grounded in the current product: better review suggestions and clearer rule suggestions, not a premature autopilot leap.

## Proposed Design

### 1. Separate Audit History from Product Memory

`ActivityItem` should remain the user-facing audit feed. It is valuable for timelines, notifications, and human-readable context, but it should no longer be treated as the canonical source of user-memory truth.

V1 should add a dedicated memory subsystem:

- `PersonalMemoryEvent`
  An append-only SwiftData model for normalized organization-memory events
- `PersonalMemoryPreference`
  A derived SwiftData model for compact, queryable preference state
- `PersonalMemoryService`
  The single service responsible for recording events, updating aggregates, and servicing reset APIs

This keeps the responsibilities clean:

- audit feed: what happened
- memory events: what choice was offered and what the user meant by their response
- preferences: what Forma should infer from repeated evidence

### 2. Memory Event Model

`PersonalMemoryEvent` should capture structured signals that today are either implicit or only present in free-form strings.

Recommended fields:

- stable event ID
- timestamp
- event kind
  - suggestion accepted unchanged
  - suggestion accepted with override
  - suggestion skipped/deferred
  - undo/recovery
  - manual correction inside Forma
  - rule suggestion accepted
  - rule suggestion dismissed
- source surface
  - review flow
  - inspector
  - bulk organize
  - rule suggestion surface
  - undo surface
- suggestion source
  - explicit rule
  - personal memory
  - learned pattern
  - ML prediction
  - manual/no suggestion
- file context
  - file extension
  - file type category
  - source location / watched-folder kind
  - scan root identity
  - relative parent path when useful
  - project cluster or similar context if already available
- proposed destination identity, if the app suggested one
- chosen destination identity
- prior destination identity for correction/undo events
- confidence shown to the user, if applicable
- matched rule ID, if applicable
- related prior-decision ID when an event contradicts or recovers an earlier outcome

Destination identity should be normalized and stable enough for local comparison without depending on raw, ad hoc absolute-path strings. Where possible, reuse bookmark-backed destination identity plus display metadata rather than inventing a second destination representation.

### 3. Derived Preference Model

`PersonalMemoryPreference` should represent the compact, queryable output of repeated events.

Recommended fields:

- context key
  - file extension
  - file category
  - source location
  - optional project/context token
- preferred destination identity
- accept count
- override count
- correction count
- undo count
- skip/defer count
- stability score
- correction penalty
- confidence adjustment
- rule-readiness score
- last-observed timestamp
- suppression or "do not generalize yet" state where repeated corrections indicate instability

The append-only event log remains the durable source of truth. The derived preference rows exist for query speed, deterministic explanation text, and later reuse by automation and metadata consumers.

### 4. Signal Weighting

Weight signals asymmetrically.

Strong signals:

- destination override before organize
- undo/recovery of a recent organize action
- later manual correction inside Forma
- explicit dismissal of a reusable rule suggestion

Medium signals:

- accepted suggestion without changes
- repeated successful organize actions toward the same destination

Weak signals:

- skip/defer
- one-off review hesitation without a contradictory action

Expected behavior:

- repeated accepts should strengthen a preference gradually
- corrections and undo behavior should weaken or redirect memory quickly
- a single correction should matter more than a single acceptance
- repeated skips should only suppress generalization when they cluster in the same context

### 5. Capture at Decision Execution Boundaries

Capture memory when the decision becomes real, not just when a button is tapped.

Recommended capture points:

- successful organize actions in review or inspector flows
- organize actions that used an override rather than the original suggestion
- successful undo operations for recent organize batches
- in-app corrective moves that reverse or contradict a prior outcome
- rule suggestion creation from repeated behavior
- dismissal of a rule suggestion

This implies the primary integration points are coordination and service layers, not only views:

- `FileOrganizationCoordinator.swift`
- `ActivityLoggingService.swift`
- `RuleService.swift`
- `BulkOperationViewModel.swift` or the equivalent action-orchestration layer
- `RuleSuggestionView.swift`

The UI can still provide intent context, but the memory write should happen close to the successful operation so the event stream reflects what actually happened.

### 6. Review Suggestions Should Become Memory-Aware First

V1 should improve review suggestions before it changes automation behavior.

Recommended suggestion order in the scan/review pipeline:

1. Explicit rules
2. Personal-memory suggestions
3. Learned-pattern fallback
4. ML destination prediction fallback

Implementation guidance:

- insert a personal-memory evaluation stage into `FileScanPipeline`
- only fall through to learned patterns and ML for files that remain pending
- add a dedicated suggestion source, for example `SuggestionSource.personalMemory`, so audit copy and UI explanations can distinguish user-specific memory from generic pattern or model output
- use the existing `matchReason`, `confidenceScore`, and destination fields on `FileMetadata` so review UI can benefit without a new presentation system

The explanation text should explicitly attribute the suggestion to the user's own behavior, for example:

- "Based on how you usually organize screenshots from Downloads"
- "You have sent similar files here 6 times with no later corrections"

### 7. Rule Suggestions Should Reuse Existing `LearnedPattern` UI

V1 should not replace the current rule-suggestion surface. It should improve the source data behind it.

Recommended approach:

- keep `LearnedPattern` as the UI-facing artifact for rule suggestions in v1
- shift `LearningService` away from mining free-form `ActivityItem.details` as the long-term source of truth
- instead, derive stable repeated-behavior suggestions from `PersonalMemoryEvent` and `PersonalMemoryPreference`
- only produce suggestable patterns when the preference state shows both repetition and low correction/undo rates

This lets Forma keep the existing `RuleSuggestionView` and much of its current product framing while making the suggestion logic materially more trustworthy.

Rule-suggestion copy should also become more explicit about evidence quality:

- repeated count
- recency
- low correction rate
- why the suggestion is now stable enough to promote into a rule

### 8. Settings Transparency Should Stay Light

V1 should make the memory layer visible enough to trust, but not so exposed that it requires a management subsystem.

Recommended location:

- `Views/Settings/SmartFeaturesSection.swift`

Recommended v1 behavior:

- explain that Forma learns locally from organization decisions
- show lightweight summary information
  - learned destinations count
  - reusable-pattern count
  - last updated timestamp
- provide a reset control for personal memory
- avoid a full editable matrix, per-file browser, or advanced per-context tuning UI

To limit toggle sprawl, v1 should reuse existing entry-point flags:

- memory capture and derivation gated by `FeatureFlagService.shared.isEnabled(.patternLearning)`
- memory-backed rule suggestions also honor `.ruleSuggestions`
- memory-backed review suggestions also honor the existing review-prediction/suggestion entry point in v1

## Likely File Impact

### New Files

- `Forma File Organizing/Models/PersonalMemoryEvent.swift`
- `Forma File Organizing/Models/PersonalMemoryPreference.swift`
- `Forma File Organizing/Services/PersonalMemoryService.swift`
- `Forma File OrganizingTests/PersonalMemoryServiceTests.swift`

### Existing Files Likely to Change

- `Forma File Organizing/Services/ActivityLoggingService.swift`
- `Forma File Organizing/Services/FileScanPipeline.swift`
- `Forma File Organizing/Services/LearningService.swift`
- `Forma File Organizing/Services/RuleService.swift`
- `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- `Forma File Organizing/Models/DestinationPredictionTypes.swift`
- `Forma File Organizing/Views/RuleSuggestionView.swift`
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/ViewModels/BulkOperationViewModel.swift`

## Migration and Compatibility Notes

- Do not remove or repurpose `ActivityItem` in v1.
- Do not break existing `LearnedPattern` UI or persistence in the first slice.
- Keep bookmark-aware destination handling intact; do not route file access through new ad hoc path logic.
- Prefer additive SwiftData migrations for the new memory models and minimal compatibility edits for existing stored enums or suggestion-source fields.

## Testing Strategy

V1 needs focused unit and integration coverage, not just UI smoke tests.

Required test areas:

- memory event recording for accept, override, skip, undo, and correction flows
- preference aggregation and weighting
- fast negative adjustment after correction/undo
- scan-pipeline precedence
  - explicit rules beat memory
  - memory beats learned-pattern fallback
  - fallback still works when no stable memory exists
- rule-suggestion thresholds
  - repeated stable behavior becomes suggestable
  - repeated corrected behavior does not
- Settings reset behavior
  - clearing personal memory removes aggregates and disables downstream influence immediately

Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for any filesystem-backed tests that truly need real paths.

## Risks

1. Overfitting the context key
   If context keys are too specific, memory never compounds. If they are too broad, memory becomes noisy and untrustworthy.

2. Weak correction correlation
   Undo and correction events must be tied back to the prior decision they contradict, or the weighting logic will stay fuzzy.

3. Consumer drift
   Review suggestions and rule suggestions must read the same underlying memory signals or the product will feel inconsistent.

4. Toggle ambiguity
   Reusing existing feature flags is simpler, but the Settings copy must make it clear what is being learned and what is being shown.

## Success Criteria

V1 is successful when:

- review suggestions more often cite the user's own history than generic classification
- an override or undo changes later suggestions faster than repeated passive acceptance alone
- rule suggestions are rarer but more believable
- the user has a lightweight way to understand and reset personal memory
- later roadmap work can consume the same memory layer instead of inventing a second trust system

## After V1

### Progressive Automation Upgrades

The next roadmap item should consume the same memory signals rather than build a new automation-specific trust model.

Specifically, automation planning should use:

- stability score
- correction rate
- undo rate
- repeated destination affinity
- rule-readiness score

to decide:

- which folders, rules, or categories are eligible for optional autopilot promotion
- how to explain scope and trust thresholds
- where preview-first should remain the default because the memory is still unstable

### Metadata Layer V1

The metadata layer should also build on this memory foundation rather than run in parallel.

V1 memory should directly enable:

- organization history as the first durable metadata primitive
- auto-applied metadata candidates such as project association, status, or tags based on repeated stable behavior
- metadata confidence/provenance that explains whether a value came from rule logic, explicit user choice, or personal memory inference

That sequencing matters:

- memory first creates trustworthy behavioral evidence
- automation then consumes trust signals
- metadata then turns repeated evidence into durable retrieval structure
