# Durable Status V1 Design

**Status:** Current
**Last Updated:** 2026-04-06
**Audience:** Developers, Product, Design

## Goal

Finish the core metadata-lifecycle layer by making workflow status durable and explicit:

- add a durable workflow-status field to [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift)
- write that status only at meaningful system or user transitions
- keep the current live UI state model intact
- expose the durable status as read-only proof in the inspector

This slice should do five things well:

1. persist a file's last meaningful workflow state across scan, organize, undo, and ignore flows
2. keep durable status distinct from the transient [`FileItem.OrganizationStatus`](../../../../Forma%20File%20Organizing/Models/FileItem.swift)
3. avoid status churn from rescans or temporary visibility changes
4. keep structured history as the explanation layer for status changes
5. complete the roadmap's core metadata primitives before project spaces or workflow chains build on them

This is intentionally the next metadata slice after:

- metadata foundation v1
- auto-applied project association v1
- auto-applied content tags v1

It should move the roadmap forward without pulling in:

- manual status editing
- dashboard/global status filters
- project-space behavior
- workflow-step execution
- replacing current review-state behavior

## Problem Statement

Forma now has a durable metadata ledger, durable project association, durable content tags, and structured per-file history. What it still lacks is a durable answer to a simple workflow question:

> What is the last meaningful organization state of this file?

Today, there are two nearby concepts, but neither is the right product primitive:

- [`FileItem.status`](../../../../Forma%20File%20Organizing/Models/FileItem.swift) is the live review-state machine that drives the current dashboard and review UI
- `FileMetadataRecord.latestOrganizationStatus` is an internal move-centric marker with values such as `organized`, `rekeyed`, and `undone`

Those are both useful, but they solve different problems.

`FileItem.status` is intentionally transient. It is tied to the current scan set and UI flow, and it can disappear when files leave the visible working set.

`latestOrganizationStatus` is intentionally operational. It tracks metadata-ledger transitions such as `rekeyed`, which are important for identity preservation and debugging but are not the durable lifecycle language the product roadmap needs.

The roadmap in [`TODO.md`](../../TODO.md) explicitly calls for lightweight local metadata such as tags, status, project association, and organization history. After the project-association and content-tag slices, status is the remaining missing primitive.

Without this slice:

- the metadata ledger still lacks a durable lifecycle field that later project spaces and workflow runs can query directly
- the inspector can explain what happened historically, but it cannot show the current durable lifecycle state cleanly
- future workflow work will either lean on transient `FileItem.status` or overfit to `latestOrganizationStatus`, which mixes different concerns

The design challenge is to add durable lifecycle state without destabilizing the existing UI state machine. The right answer is not to replace `FileItem.status` yet. It is to add a separate durable workflow-status field in the metadata ledger and update it only from trusted transition points.

## Product Principles

1. Durable workflow status is long-lived file memory, not the current UI-state machine.
2. The first status slice should represent organization lifecycle only, not broader work-state semantics.
3. Meaningful transitions should write durable status; passive inspection and transient edits should not.
4. `queued` should not churn based on rescans, folder visibility, or temporary access issues.
5. Structured history remains the explanation layer; durable status is the fast current answer.
6. Existing organize, undo, skip, and scan flows must continue to work even if durable-status writes fail.
7. This slice should complete the metadata foundation, not start workflow-engine behavior early.

## Scope

### In Scope for V1

- add one durable workflow-status field to `FileMetadataRecord`
- define a small lifecycle vocabulary:
  - `queued`
  - `organized`
  - `recovered`
  - `ignored`
- write durable status only from meaningful transition points:
  - scan / explicit discovery
  - organize / bulk organize / redo
  - undo recovery
  - durable skip / ignore
- keep durable status separate from both `FileItem.status` and `latestOrganizationStatus`
- extend inspector proof to show the durable status read-only
- extend structured history so ignored transitions have a matching durable explanation row
- gate the slice behind a dedicated feature flag layered on top of `metadataFoundation`
- add focused model, service, pipeline, coordinator, undo, and inspector coverage

### Explicitly Out of Scope

- manual status controls or overrides
- dashboard/global status filters
- replacing `FileItem.status` as the live UI source of truth
- removing or repurposing `latestOrganizationStatus`
- workflow-step execution or rollback graphs
- project-space grouping or retrieval changes
- file-surface badges in row/card/grid/main content

## Approach Options

### Option A: Reuse `FileItem.status` as the durable source of truth

Promote the existing review-state enum into the durable product status model.

Pros:

- fewer models to explain
- might reduce short-term duplication

Cons:

- ties durable lifecycle state to scan-driven UI state
- risks churn whenever files leave or re-enter the live review set
- forces broader migration of dashboard and review logic before the metadata model is ready

### Option B: Derive durable status from history on every read

Do not add a new field. Compute durable status from the latest relevant history entry instead.

Pros:

- smaller schema change
- keeps history as the single source of truth

Cons:

- turns a simple current-state read into replay logic
- makes later filtering and retrieval more expensive and brittle
- still requires new history semantics for ignored transitions

### Option C: Add an explicit durable workflow-status field in the metadata ledger

Keep `FileItem.status` and `latestOrganizationStatus` as they are, and add a separate lifecycle field to [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift) that is written only from approved transition points.

Pros:

- clean separation between live UI state and durable lifecycle memory
- simple fast reads for later project-space and workflow work
- preserves the current dashboard/review model while completing the metadata ledger
- keeps history as explanation instead of forcing history replay

Cons:

- introduces one more status concept in the short term
- requires careful naming to avoid confusion with `latestOrganizationStatus`

## Recommendation

Use Option C: add an explicit durable workflow-status field in the metadata ledger.

This is the smallest slice that completes the metadata layer cleanly.

It keeps the repo's current state model intact:

- `FileItem.status` stays transient and UI-facing
- `latestOrganizationStatus` stays operational and move-centric
- the new durable workflow status becomes the product-facing lifecycle memory

That separation matters. It avoids a premature migration of review behavior now while giving later slices a clear stable field to read from.

## Proposed Design

### 1. Add a Dedicated Durable Workflow-Status Field

Extend [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift) with a new sibling field rather than overloading `latestOrganizationStatus`.

Recommended shape:

- `private var workflowStatusRaw: String?`
- computed `workflowStatus: MetadataWorkflowStatus?`

Recommended enum:

- `MetadataWorkflowStatus`
  - `queued`
  - `organized`
  - `recovered`
  - `ignored`

Important design choice:

- keep the field optional in v1

Why optional:

- avoids a destructive migration or eager backfill
- existing metadata rows can remain unset until a new qualifying transition writes a value
- inspector reads can stay best-effort for existing installs

Important non-goal:

- do not rename or repurpose `latestOrganizationStatus` in this slice

`latestOrganizationStatus` should remain the move-centric metadata-internal field that can still represent values like `rekeyed`. The new durable workflow status is a product-facing lifecycle field and should not inherit `rekeyed` or `unknown`.

### 2. Add a Dedicated Entry-Point Flag

This slice should add a new feature flag, for example:

- `FeatureFlagService.Feature.durableWorkflowStatus`

Behavior:

- it depends on `metadataFoundation`
- default should be `false`
- it should be exposed alongside the other metadata flags in [`SmartFeaturesSection.swift`](../../../../Forma%20File%20Organizing/Views/Settings/SmartFeaturesSection.swift)
- durable-status reads and writes should require both:
  - `metadataFoundation`
  - `durableWorkflowStatus`

This keeps rollout consistent with the earlier metadata slices:

- `metadataFoundation` gates the ledger itself
- `durableWorkflowStatus` gates the lifecycle field layered on top of that ledger

### 3. Define the Lifecycle Vocabulary Narrowly

V1 should use only four durable statuses:

- `queued`
  - the file is in Forma's reviewable system and has not yet reached a terminal durable transition
- `organized`
  - the file was successfully moved through organize, bulk organize, or redo
- `recovered`
  - the file was restored by undo after previously being organized
- `ignored`
  - the user explicitly skipped or ignored the file in a durable way

Deliberately do not include:

- `reviewed`
- `errored`
- `draft`
- `archived`
- `reference`

Those either belong to broader work-state semantics or require larger UX and workflow decisions than this slice needs.

### 4. Centralize Writes in the Metadata Service

Durable workflow-status writes should live inside [`FileMetadataFoundationService.swift`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift), not in scattered view models.

Recommended responsibility:

- add one narrow helper that updates durable workflow status from approved transitions
- keep the write-through logic near the existing metadata upsert, transition, and history code
- expose the new helper through [`FileMetadataFoundationServiceProtocol`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift), because [`FileScanPipeline`](../../../../Forma%20File%20Organizing/Services/FileScanPipeline.swift) already depends on the protocol rather than the concrete service

Why this boundary:

- scan, organize, undo, and metadata proof already route through the metadata foundation
- this keeps lifecycle writes consistent with the ledger's existing identity guarantees
- it avoids a split system where `FileItem.status` mutations silently drift from metadata state

### 5. Write Status Only at Meaningful Transitions

Approved v1 write points:

#### Scan / explicit discovery writes `queued`

When a metadata-backed file is first brought into Forma's reviewable system through scan or explicit evaluation, durable status may become `queued`.

Rules:

- new records can be initialized to `queued`
- existing records can only be upgraded to `queued` when all of the following are true:
  - `workflowStatus == nil`
  - `latestOrganizationStatus == .unknown`
  - the record has no prior lifecycle history beyond possible scan-note noise
- when the durable status actually changes to `queued`, append one `scanned` history row from the scan write path
- rescans must not clear `queued`
- rescans that leave the file in `queued` must not append repeated `scanned` history rows
- rescans should not overwrite a stronger existing status such as `organized`, `recovered`, or `ignored`

Important behavior:

- a file leaving the current scan set does not automatically clear `queued`

Recommended ownership:

- the existing metadata upsert path in [`FileScanPipeline.persistMetadataRecords(...)`](../../../../Forma%20File%20Organizing/Services/FileScanPipeline.swift) should own this write-through behavior by calling into the metadata service
- that scan-facing helper should be added to `FileMetadataFoundationServiceProtocol`, not only the concrete service
- the metadata service should decide whether this discovery is a first-write transition or a no-op rescan

This is the explicit approved posture for the slice. Durable status should reflect the last meaningful lifecycle transition, not current scan visibility.

#### Organize / bulk organize / redo writes `organized`

Successful organize transitions should write `organized`.

Recommended seam:

- fold this into the existing `recordTransition(...)` path, which already handles metadata rekeying, project-association writes, content-tag writes, and structured history appends

Rules:

- `organized` should overwrite `queued`
- `organized` should overwrite `recovered`
- `organized` should overwrite `ignored` only when the file is explicitly organized again through a later successful run

#### Undo recovery writes `recovered`

Successful undo that restores a previously organized file should write `recovered`.

Recommended seam:

- reuse the existing undo-driven metadata transition path that currently records the `undone` history event and preserves metadata identity

Rules:

- `recovered` should overwrite `organized`
- `recovered` should remain until a later meaningful transition replaces it
- rescans should not immediately collapse `recovered` back to `queued`

#### Skip / ignore writes `ignored`

Explicit durable skip or ignore actions should write `ignored`.

Current code reality:

- there are several places that directly set `FileItem.status = .skipped`
- the existing metadata history model does not yet have a matching `ignored` event kind

V1 should tighten that seam:

- treat [`FileOrganizationCoordinator.skipFile(...)`](../../../../Forma%20File%20Organizing/Coordinators/FileOrganizationCoordinator.swift) as the sanctioned ignore entry point for this slice
- route durable ignored writes from that coordinator path through the metadata layer
- avoid treating every local list-removal shortcut as a durable metadata update unless it is the sanctioned skip/ignore path for the app
- `SkipFileCommand.execute(context:)` should preserve the same durable-ignore behavior for redo

This is the only transition in the slice that likely requires extending the history vocabulary.

Undo rule:

- when [`SkipFileCommand.undo(context:)`](../../../../Forma%20File%20Organizing/Services/UndoCommand.swift) reverses an ignored file, restore the previously captured durable workflow status snapshot
- in normal v1 flows that restored value will usually be `queued`
- for legacy records created before this slice, the restored value may be `nil`
- v1 does not need a second history row for skip undo; the durable workflow-status field becomes the current answer, while the existing ignored row remains a historical event

Implementation consequence:

- the skip command path needs to snapshot the previous durable workflow status when creating the undo command, just as it already snapshots `previousStatus` and `previousDestination`

### 6. Extend Structured History for Ignored Transitions

History remains the explanation layer for durable status changes.

V1 should continue using existing history events where they already align:

- `scanned` supports `queued`
- `organized` supports `organized`
- `undone` supports `recovered`

For ignored lifecycle writes, add a new history event:

- `FileOrganizationHistoryEntry.EventKind.ignored`

Recommended source-surface change:

- add one dedicated source such as `review`

Why:

- current `SourceSurface` values are `scan`, `organize`, `undo`, and `inspector`
- the sanctioned ignored write originates from `FileOrganizationCoordinator.skipFile(...)`, which is review-driven rather than inspector-driven
- durable lifecycle explanation should not rely on an overloaded or misleading source label

Non-goal:

- do not start logging every transient panel action

Only meaningful transitions should produce durable lifecycle explanation rows.

Transition matrix for planning:

| Trigger | Owning path | Durable status result | History result |
|---|---|---|---|
| first discovery or explicit evaluation | `FileScanPipeline.persistMetadataRecords(...)` via metadata service | `queued` if previously `nil` | append one `scanned` row only when status changes to `queued` |
| rescan of already-known file | same scan path | no status downgrade or churn | no new row unless another meaningful transition occurred |
| organize / bulk organize / redo | `FileMetadataFoundationService.recordTransition(...)` | `organized` | append `organized` row |
| undo organize | existing undo metadata transition path | `recovered` | append `undone` row |
| skip / ignore | `FileOrganizationCoordinator.skipFile(...)` and `SkipFileCommand.execute(context:)` | `ignored` | append `ignored` row with source surface `review` |
| undo skip | `SkipFileCommand.undo(context:)` | restore previously captured durable workflow status snapshot | no new row in v1 |

### 7. Keep the Inspector Proof Narrow

Extend the existing inspector proof path:

- [`FileMetadataFoundationService.inspectorSummary(for:)`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift)
- [`FileMetadataInspectorSummary`](../../../../Forma%20File%20Organizing/Models/FileMetadataInspectorSummary.swift)
- [`FileInspectorView`](../../../../Forma%20File%20Organizing/Views/FileInspectorView.swift)

Recommended additions:

- one `workflowStatusSummary` field in `FileMetadataInspectorSummary`
- one small read-only row in the metadata proof section

Copy style:

- concise and literal
- example: `Status: organized`

Behavior:

- only show the row when `durableWorkflowStatus` is enabled and the record has a non-`nil` workflow status
- keep history rows as the richer explanation surface below it

Do not add:

- dashboard status chips
- list/grid badges
- manual controls

### 8. Preserve Safe Migration Behavior

Migration posture should stay conservative:

- do not require backfilling all existing metadata rows immediately
- keep the new field optional
- if a record has no durable workflow status yet, existing app behavior must still work unchanged
- read paths must tolerate `nil`

Explicit legacy-row rule:

- do not seed `workflowStatus` from `latestOrganizationStatus`
- do not replay history to backfill `workflowStatus`
- pre-existing rows that already show meaningful legacy movement state such as `organized`, `rekeyed`, or `undone` should remain `nil` until a new v1-era meaningful transition writes a durable workflow status explicitly
- only clearly new or still-uninitialized rows should upgrade to `queued` during scan
- later explicit transitions such as organize, undo organize, or ignore may write the durable field regardless of prior legacy state

This keeps the slice aligned with the metadata foundation rollout strategy:

- enrich existing flows
- never become a new hard dependency for scan, organize, undo, or skip

## Testing Strategy

Add focused coverage for the risky seams first.

### Model and Service Coverage

- `FileMetadataRecord` stores and reads the optional durable workflow status cleanly
- `queued` is written on first discovery when flags are enabled
- rescans do not clear `queued`
- rescans do not overwrite stronger statuses
- `organized` is written through organize and redo transitions
- `recovered` is written through undo transitions
- `ignored` is written only through the sanctioned durable skip/ignore path

### Integration Coverage

- organize preserves metadata identity and updates durable workflow status to `organized`
- undo preserves metadata identity and updates durable workflow status to `recovered`
- ignore writes `ignored` without breaking undo-stack or current review behavior
- project association and content tags remain intact while durable workflow status changes

### Inspector Coverage

- inspector summary exposes the durable status when enabled
- inspector hides the row when the field is unset or the feature flag is off
- history still renders meaningful rows for organized, recovered, and ignored transitions

### Regression Coverage

- `latestOrganizationStatus` behavior continues to work for existing metadata-foundation tests
- existing installs with metadata rows created before this slice continue to load safely

## Success Criteria

This slice is successful when:

1. new and active files can carry a durable lifecycle status in the metadata ledger
2. organize, undo, and ignore flows update that field without changing the current review-state machine
3. rescans do not churn lifecycle state based on visibility alone
4. the inspector can show the current durable status and the history that explains it
5. later roadmap work can query durable lifecycle state without depending on transient `FileItem.status`

## Follow-On Work

This slice should make the next roadmap steps easier, not finish them.

Natural follow-ons:

- metadata-backed dashboard or project-space lifecycle filters
- manual metadata editing
- workflow engine foundation that logs step execution against stable file identity and durable lifecycle state

Notably, this slice should not force those next steps to reinterpret `FileItem.status` or `latestOrganizationStatus`. That is the main architectural value of shipping it now.
