# Metadata Foundation V1 Design

**Status:** Current
**Last Updated:** 2026-04-03
**Audience:** Developers, Product, Design

## Goal

Start the roadmap's metadata layer by giving Forma a durable local file metadata foundation that survives moves, undo, and rescan reconciliation.

This first slice should do four things well:

1. preserve file identity independently from the mutable `FileItem.path`
2. persist lightweight local metadata in a dedicated ledger instead of overloading review-state models
3. append structured per-file organization history for organize and undo flows
4. prove the ledger is real with one read-only inspector surface

This slice is intentionally foundational, not broad. It should create the right storage and lifecycle seams for later roadmap work:

- metadata-backed tags, status, and project association
- cross-folder project spaces
- workflow runs and step-level audit / rollback

Those later items are intentionally not part of this implementation target.

## Problem Statement

Forma already stores several useful kinds of state, but none of them are the right durable home for local metadata:

- [`FileItem`](../../../../Forma%20File%20Organizing/Models/FileItem.swift) is scan and review state keyed by a mutable path
- [`PersonalMemoryEvent`](../../../../Forma%20File%20Organizing/Models/PersonalMemoryEvent.swift) is a learning-sidecar event stream
- [`PersonalMemoryPreference`](../../../../Forma%20File%20Organizing/Models/PersonalMemoryPreference.swift) is an aggregate preference model
- [`ActivityItem`](../../../../Forma%20File%20Organizing/Models/ActivityItem.swift) is a user-facing activity feed with mostly string-based details
- [`ProjectCluster`](../../../../Forma%20File%20Organizing/Models/ProjectCluster.swift) is a heuristic grouping suggestion, not a durable assignment

That leaves the roadmap blocked in two ways:

1. The metadata roadmap item wants durable local tags, status, project association, and organization history.
2. The workflow-chain roadmap item wants structured audit and rollback that should not depend on parsing activity strings or mutable file paths.

Today, neither requirement has a clean base.

The core technical gap is identity. `FileItem` treats `path` as the persisted source of truth, but organize and undo explicitly mutate that path. That is fine for live review state, but it is the wrong primitive for durable metadata that must survive `move -> undo -> rescan` without becoming orphaned or duplicated.

The first missing capability is therefore not a tag editor or a workflow builder. It is a durable file metadata ledger with stable local identity and structured organization history.

## Product Principles

1. Durable metadata must not depend on the mutable review-state path.
2. The metadata ledger should be local-first, reversible, and resilient to rescans.
3. Existing organize, undo, and automation behavior must continue working even when no metadata row exists yet.
4. `FileItem` remains the live review-state model; the metadata ledger is a separate concern.
5. Personal memory and user-facing activity stay as sidecars, not the source of truth for local metadata.
6. The first slice should show one visible proof of the ledger without expanding into full metadata authoring UX.
7. This slice should make later metadata UX and workflow runs easier, not introduce another temporary abstraction.

## Scope

### In Scope for V1

- add a dedicated SwiftData model for durable local file metadata
- add a dedicated SwiftData model for per-file organization-history entries
- introduce canonical local file identity resolution that does not depend solely on current path
- upsert metadata records during scan and explicit evaluation flows
- keep metadata records attached across organize and undo paths
- append structured history for organize and undo events
- surface a read-only metadata/history proof in the file inspector
- gate the new ledger integration behind a dedicated feature entry point
- add focused model, pipeline, coordinator, undo, and inspector coverage

### Explicitly Out of Scope

- manual tag editing
- Finder tag writes
- Finder/Forma metadata sync
- metadata-backed project spaces
- metadata-driven search or retrieval UX
- workflow step execution (`rename`, `tag`, `notify`)
- persistent workflow-run and workflow-step models
- replacing the existing activity feed
- changing trust-scope behavior or automation policy rules

## Approach Options

### Option A: Extend `FileItem` into the metadata store

Put tags, project association, and history directly on `FileItem`.

Pros:

- fastest implementation path
- reuses an existing persisted model

Cons:

- ties durable metadata to mutable path identity
- risks data loss during scan reconciliation
- mixes live review state with long-lived product memory
- makes later workflow-run audit harder to separate cleanly

### Option B: Build the workflow engine first

Introduce workflow runs, steps, and rollback before a metadata foundation.

Pros:

- moves the roadmap toward `rename -> tag -> move -> notify -> log`

Cons:

- execution would still depend on move-centric undo and path-based file identity
- workflow audit would either duplicate or later rewrite the metadata/history layer
- broader change surface before the durable base exists

### Option C: Add a separate metadata foundation ledger

Create a dedicated durable metadata record plus structured organization history, and integrate it into scan / organize / undo before broader metadata UX or workflow execution.

Pros:

- gives both later roadmap items the right base
- keeps `FileItem` focused on live review state
- reduces risk of metadata drift across move and undo flows
- lets future workflow audit attach to stable file identity

Cons:

- less flashy than visible metadata editing
- requires careful identity and migration design up front

## Recommendation

Use Option C: a separate metadata foundation ledger.

This is the smallest slice that actually unblocks the roadmap cleanly.

If Forma adds tags or workflow runs before fixing durable identity, those features will either:

- bind themselves to mutable paths and drift
- or immediately require a second foundational rewrite

That is avoidable. The right move is to fix the storage boundary first, then add metadata authoring and workflow execution on top of it.

## Proposed Design

### 1. Add a Dedicated Metadata Ledger

V1 should add a new SwiftData model:

- `FileMetadataRecord`

Recommended fields:

- `id`
- `canonicalIdentity`
  - stable unique key for the file on this machine
- `identityKind`
  - `resourceIdentifier`
  - `pathFallback`
- `lastKnownPath`
- `displayName`
- `fileExtension`
- `lastSeenAt`
- `firstSeenAt`
- `lastOrganizedAt`
- `organizationCount`
- `latestOrganizationStatus`
  - reserved durable status summary, distinct from live `FileItem.status`
- `tags`
  - empty in v1 is fine; keep the shape ready
- `projectAssociation`
  - optional string or lightweight typed value
- `notesSummary`
  - optional reserved field for later metadata-backed retrieval

This ledger is the product truth for durable per-file metadata. It should not be folded into `FileItem`, because `FileItem` already has a different job:

- `FileItem` = current scan/review state
- `FileMetadataRecord` = durable local memory about the file across moves and rescans

### 2. Add Structured Organization History

V1 should add a second SwiftData model:

- `FileOrganizationHistoryEntry`

Recommended fields:

- `id`
- `fileIdentity`
  - copy of the metadata record identity for stable queries
- `metadataRecord`
  - optional relationship back to `FileMetadataRecord`
- `eventKind`
  - `organized`
  - `undoRecovery`
  - reserve later kinds for workflow steps
- `timestamp`
- `sourceSurface`
  - `reviewFlow`
  - `bulkOrganize`
  - `automation`
  - `undoSurface`
- `fromPath`
- `toPath`
- `destinationDisplayName`
- `matchedRuleID`
- `trustedScopeID`
  - optional reserve field for later integration
- `detailsSummary`
  - short structured summary, not user-facing rich prose

This model is intentionally smaller and more structured than `ActivityItem`.

`ActivityItem` remains the user-facing feed.
`FileOrganizationHistoryEntry` becomes the durable per-file history source for later metadata UX and workflow audit.

### 3. Resolve Canonical Local File Identity

The metadata service needs a stable local identity that survives path changes.

Preferred identity:

- filesystem-backed identity derived from resource values such as:
  - `fileResourceIdentifier`
  - `volumeIdentifier`

Fallback identity:

- a normalized path-based surrogate when the filesystem identity is unavailable

The ledger should store:

- `canonicalIdentity`
- `identityKind`
- `lastKnownPath`

Behavior:

- when resource-based identity is available, moving the file should preserve the same metadata row
- when only path fallback is available, the system should still function, but the record is marked as degraded through `identityKind == pathFallback`

This keeps the slice resilient:

- no hard failure when identity resolution is incomplete
- no silent assumption that path is durable when it is not

### 4. Introduce a Metadata Foundation Service

V1 should add a dedicated service, for example:

- `FileMetadataFoundationService`

Responsibilities:

- resolve canonical identity for a file URL or `FileMetadata`
- fetch or create a `FileMetadataRecord`
- update `lastKnownPath`, `displayName`, `lastSeenAt`, and extension information
- append `FileOrganizationHistoryEntry` records
- update durable organization summary fields after organize and undo
- expose lookup helpers for inspector read-only rendering

This service should be the only place that understands how the metadata ledger works. Other systems should call it rather than duplicating identity logic.

### 5. Integrate at the Existing Seams

The existing architecture already has the right seams for this foundation.

#### Scan Pipeline

Update [`FileScanPipeline`](../../../../Forma%20File%20Organizing/Services/FileScanPipeline.swift):

- after scan evaluation and before or during `FileItem` persistence, upsert `FileMetadataRecord`
- refresh `lastKnownPath`, `displayName`, `fileExtension`, and `lastSeenAt`
- do not block scan or review if metadata upsert fails; log and continue

This keeps metadata rows aligned with the latest known live file state.

#### Organization Coordinator

Update [`FileOrganizationCoordinator`](../../../../Forma%20File%20Organizing/Coordinators/FileOrganizationCoordinator.swift):

- after successful organize, update the matching metadata record using the file's stable identity
- set `lastKnownPath` to the new path
- update `lastOrganizedAt`, increment `organizationCount`, and refresh durable status
- append an `organized` history entry

This keeps the durable ledger aligned with the actual move result instead of only with scan state.

#### Undo Path

Update [`UndoCommand`](../../../../Forma%20File%20Organizing/Services/UndoCommand.swift) and coordinator undo handling:

- retain the file identity snapshot needed to find the metadata record during undo
- after undo succeeds, update `lastKnownPath` back to the restored path
- append an `undoRecovery` history entry

This is critical. Without it, the metadata layer will drift the first time a user uses the app exactly as designed.

### 6. Keep Existing Sidecars in Their Lanes

This slice should preserve clear boundaries:

- [`PersonalMemoryEvent`](../../../../Forma%20File%20Organizing/Models/PersonalMemoryEvent.swift) stays a learning-sidecar event stream
- [`ActivityItem`](../../../../Forma%20File%20Organizing/Models/ActivityItem.swift) stays the user-facing activity feed
- [`ProjectCluster`](../../../../Forma%20File%20Organizing/Models/ProjectCluster.swift) stays a heuristic grouping surface

None of those models should be promoted into the metadata source of truth.

However, the new metadata ledger should leave room to consume them later:

- project association can later be suggested from `ProjectCluster`
- workflow audit can later complement `ActivityItem`
- learning can later read durable organization history without redefining it

### 7. Add One Visible Read-Only Proof

The first visible product proof should be read-only and low-risk.

Update [`FileInspectorView`](../../../../Forma%20File%20Organizing/Views/FileInspectorView.swift) to show, when available:

- durable organization summary
  - first seen
  - last organized
  - organization count
- current stored project association, if any
- current stored tags summary, if any
- recent organization-history entries

This surface proves the ledger exists and survives the current organize/undo lifecycle without opening the larger questions of authoring UX.

V1 should not add:

- editable tags
- editable project assignment
- grid/list/row metadata chips
- metadata filters

Those belong to the next metadata product slice, after the ledger is proven stable.

### 8. Migration and Rollout

Migration should be additive and lazy.

Behavior:

- existing installs keep working with no destructive migration
- metadata rows are created lazily during scan, explicit file evaluation, or organize
- existing `FileItem` rows do not require a one-shot backfill before the app can run
- missing metadata must never block review, organize, undo, or automation

Feature rollout:

- gate the metadata-ledger integration behind a dedicated entry-point flag
- when disabled, existing scan and organize behavior remains unchanged
- when enabled, the ledger runs in parallel with current review-state persistence

This keeps rollout safe while the storage shape settles.

## Testing

### Model and Service Coverage

- create or reactivate metadata records by canonical identity without duplicates
- resolve resource-identifier-based identities deterministically
- fall back to normalized path identity when resource identity is unavailable
- append organize and undo history entries to the correct metadata record

### Scan and Persistence Coverage

- rescan of the same file reuses the same metadata record
- explicit-file evaluation upserts metadata without reconciling unrelated rows
- metadata upsert failure does not break the existing scan result path

### Organization and Undo Coverage

- organize updates `lastKnownPath` and durable counters
- undo restores `lastKnownPath` while preserving the same metadata identity
- bulk organize appends history per file without creating duplicate metadata rows

### UI Coverage

- file inspector shows read-only metadata summary when the ledger is present
- file inspector hides or degrades cleanly when the ledger is absent

## Explicit Deferrals

The following are intentionally deferred and should not be backdoored into this slice:

- manual tag authoring
- Finder tag writes
- Finder/Forma tag reconciliation
- metadata-backed filters and chips across card/list/grid
- project-space views
- workflow run / step persistence
- `rename`, `tag`, and `notify` workflow execution

These remain important roadmap work, but they are separate implementation targets.

## Why This Slice First

This first metadata slice is valuable on its own:

- it gives Forma durable local file memory beyond the live review queue
- it survives the app's existing move and undo loop
- it creates a structured history source that is not string-parsed activity text

It also preserves planning clarity for later work:

- the metadata ledger decides what durable local memory exists about a file
- later metadata UX decides how users see and edit that memory
- a later workflow engine decides what multi-step execution and rollback model runs against that same stable file identity

That separation is what keeps the roadmap buildable instead of collapsing metadata, UI authoring, and workflow execution into one oversized rewrite.
