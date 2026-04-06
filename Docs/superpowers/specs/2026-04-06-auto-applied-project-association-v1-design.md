# Auto-Applied Project Association V1 Design

**Status:** Current
**Last Updated:** 2026-04-06
**Audience:** Developers, Product, Design

## Goal

Build the first real metadata layer on top of the new ledger by auto-writing one durable retrieval field:

- `FileMetadataRecord.projectAssociation`

This slice should do four things well:

1. write a durable project label automatically when evidence is strong enough
2. prefer explicit organize destinations over heuristic inference
3. keep the UI read-only and inspector-scoped
4. avoid turning generic folders into fake "projects"

This is intentionally the next metadata slice after foundation, not a broader project-space or metadata-authoring release.

It should move the roadmap forward without pulling in:

- manual metadata editing
- metadata-backed filters or badges across file surfaces
- tags or durable status authoring
- project-space navigation
- workflow-step execution

## Problem Statement

The metadata foundation slice created the right storage seam, but it still leaves the ledger mostly empty from a retrieval perspective.

Today:

- [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift) already has a `projectAssociation` field
- [`FileMetadataFoundationService`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift) already preserves metadata identity across scan, organize, undo, and redo
- [`ProjectCluster`](../../../../Forma%20File%20Organizing/Models/ProjectCluster.swift) already exists as a heuristic grouping surface

What is missing is a conservative path from those ingredients to one durable, useful metadata value.

The roadmap item in [`TODO.md`](../../TODO.md) calls for metadata such as tags, status, project association, and organization history, biased toward auto-applied metadata before manual tagging UX. The safest way to begin that product step is not to add an editor or a new project model. It is to make `projectAssociation` real in a narrow, legible way.

Without this slice:

- the metadata ledger remains a storage foundation without a durable retrieval primitive
- project heuristics remain isolated in suggestion surfaces instead of strengthening file memory
- later project-space or metadata UX will still need to answer where durable project labels come from

The challenge is trust. A move to `Screenshots` or `Invoices` should not silently become a project label. A weak clustering guess should not thrash durable metadata. This slice therefore needs a narrow precedence model and a conservative write policy.

## Product Principles

1. `projectAssociation` is durable file memory, not just a mirror of the current destination path.
2. Explicit organize intent should beat heuristic inference.
3. Generic category folders must not be reinterpreted as project labels.
4. Weak or conflicting inference should result in no write.
5. This slice should improve retrieval value without introducing metadata-editing UX.
6. Existing file operations must remain successful even if project-association writes fail.
7. The implementation should reuse the metadata ledger and existing project heuristics rather than inventing a second storage system.

## Scope

### In Scope for V1

- auto-write `FileMetadataRecord.projectAssociation` as one normalized label string
- resolve project-association candidates from two sources:
  - explicit project-like destination signals
  - heuristic inference with a strong-winner requirement
- define strict precedence: explicit destination wins over inference
- keep the proof surface in the single-file inspector only
- add source explanation copy to the inspector proof
- gate the slice behind a dedicated feature flag layered on top of `metadataFoundation`
- add focused service, pipeline, coordinator, and inspector coverage

### Explicitly Out of Scope

- manual project assignment
- tags
- durable status authoring
- project grouping or filtering in the main app
- project-space views
- file-surface badges in card/list/grid/main content
- a durable project entity or project graph
- Finder tags or Finder metadata sync
- workflow execution beyond the existing scan / move / undo / redo seams

## Approach Options

### Option A: Explicit destination only

Write `projectAssociation` only when Forma has a rule-backed or direct organize destination.

Pros:

- easiest to reason about
- avoids heuristic mistakes

Cons:

- leaves existing project heuristics disconnected from the ledger
- misses durable associations for repeated project-like behavior before a formal move happens

### Option B: Introduce a separate project entity now

Replace the string field with a new durable project model and attach files to that.

Pros:

- potentially closer to future project-space behavior

Cons:

- over-builds the first retrieval slice
- creates entity lifecycle, deduplication, and migration work before the label itself is proven useful
- expands planning into a larger subsystem

### Option C: Hybrid auto-applied association with a single label

Keep `projectAssociation` as a single normalized string, prefer explicit project-like destination signals, and fall back to heuristic inference only when one project candidate clearly wins.

Pros:

- adds real product value to the ledger immediately
- reuses the existing storage model
- keeps behavior conservative and explainable
- lets future project-space work build on already-stored durable labels

Cons:

- requires a precise "project-like destination" rule
- keeps provenance mostly out of persistence in this slice

## Recommendation

Use Option C: hybrid auto-applied association with a single label.

This is the smallest slice that makes the metadata ledger materially more useful.

It keeps the write model simple:

- one durable field
- one precedence order
- one inspector proof surface

It also preserves future optionality:

- later metadata UX can expose and edit the same field
- later project-space work can group from the durable label
- later workflow execution can write against the same record without first inventing project storage

## Proposed Design

### 1. Keep the Storage Model Simple

This slice should reuse:

- `FileMetadataRecord.projectAssociation: String?`

Do not introduce:

- a new durable project entity
- separate confidence fields on `FileMetadataRecord`
- separate provenance fields on `FileMetadataRecord`

The durable value is just a normalized project label string.

Normalization contract:

- extract the candidate label before normalization
  - explicit writes extract the destination folder name first
  - inferred writes use the cluster `suggestedFolderName` directly
- normalize with the same trim-only text policy already used for optional metadata text
- preserve user-visible casing
- do not lowercase, slugify, or strip punctuation
- if normalization produces an empty string, treat it as no candidate
- all equality and overwrite comparisons in this slice should use the normalized label

This choice is intentional. The product question for this slice is whether Forma can conservatively auto-attach one useful durable project label to a file. That question does not require a graph of projects or a richer metadata schema.

### 2. Add a Dedicated Entry-Point Flag

This slice should add a new feature flag, for example:

- `FeatureFlagService.Feature.autoProjectAssociation`

Behavior:

- it depends on `metadataFoundation`
- default should be `false`
- it should be exposed in the same Settings feature surface as `metadataFoundation`
- project-association reads and writes should require both flags to be enabled

This preserves rollout discipline. `metadataFoundation` gates the ledger. `autoProjectAssociation` separately gates the first auto-authored retrieval field on top of that ledger.

### 3. Resolve Candidates with Explicit-First Precedence

The service should resolve candidates in this order:

1. explicit project-like destination
2. heuristic inference with a strong winner
3. otherwise no write

If explicit and inferred signals disagree, explicit wins.

If explicit signals are absent and inference is weak or contested, do not write.

This should be implemented in one place inside the metadata layer, not spread across UI, scan, and coordinator code.

### 4. Define Explicit Project-Like Destination Signals Narrowly

Not every destination folder is a project.

In v1, explicit destination-backed association should only write when the destination is clearly project-like in context.

Approved v1 cases:

- a destination chosen while organizing a [`ProjectCluster`](../../../../Forma%20File%20Organizing/Models/ProjectCluster.swift)
- a rule-backed destination whose resolved path has an immediate parent directory exactly named `Projects`

Write behavior:

- the stored `projectAssociation` is the terminal destination folder name
- example:
  - destination `/Users/.../Projects/Alpha` writes `Alpha`

Exact matching rule for rule-backed destinations:

- match the parent path component by exact value: `Projects`
- do not match prefixes such as `Projects Archive`
- do not treat deeper descendants as project labels in this slice
- positive example:
  - `/Users/.../Projects/Alpha` writes `Alpha`
- negative examples:
  - `/Users/.../Projects Archive/Alpha` does not qualify
  - `/Users/.../Projects/Alpha/Assets` does not qualify

Non-project examples should not write:

- `Screenshots`
- `Invoices`
- `Receipts`
- other generic category or holding folders

The project-like destination check should be centralized in one helper so the allowlist can evolve later without rewriting multiple call sites.

### 5. Use Strong-Winner Inference Only as a Fallback

When no explicit project-like destination exists, the service may fall back to existing project heuristics.

Reuse the existing project-like signal already present in the codebase:

- [`ProjectCluster`](../../../../Forma%20File%20Organizing/Models/ProjectCluster.swift)
- the context-detection and destination-prediction path that already computes per-file cluster context

V1 inference rule:

- only write when one candidate clearly wins

Recommended strong-winner criteria:

- top candidate confidence is at least `0.80`
- and either:
  - there is no competing candidate
  - or the next-best candidate trails by at least `0.15`

Stored label:

- use the cluster's `suggestedFolderName`

Do not write when:

- the best candidate is below threshold
- two candidates are close enough to create ambiguity
- the inferred label is empty after normalization

This preserves the user-selected "strong winner only" boundary and keeps inference from thrashing durable metadata.

### 6. Keep Overwrite Rules Conservative

Because this slice does not add persisted provenance fields, overwrite behavior should stay simple and stable.

Rules:

- if the record has no `projectAssociation`, explicit or strong inferred signals may write one
- if an explicit project-like destination signal exists, it may overwrite an existing association
- inference should not overwrite an already-populated association in this slice
- weak or conflicting inference must never clear an existing association

This means:

- explicit organize intent can correct or refine prior memory
- inference can populate empty records
- inference cannot churn existing durable labels without stronger product scaffolding

### 7. Integrate Only at the Existing Metadata Seams

This slice should not invent a new workflow layer. It should write through the seams that already update the metadata ledger.

#### Scan / Explicit-File Evaluation

Update the metadata integration in [`FileScanPipeline`](../../../../Forma%20File%20Organizing/Services/FileScanPipeline.swift):

- after metadata upsert, attempt project-association resolution
- use explicit destination context when available
- use inferred cluster context when available
- write best-effort only when the feature is enabled

This is the main path for:

- explicit-file evaluation
- rescans of files that already carry destination or cluster context

#### Organize / Bulk Organize / Redo

Update the coordinator path in [`FileOrganizationCoordinator`](../../../../Forma%20File%20Organizing/Coordinators/FileOrganizationCoordinator.swift):

- after successful move metadata updates, resolve explicit destination-backed project association
- if the move came from a project-cluster organize flow, treat the chosen destination as explicit project-like
- if the move came from a rule-backed destination under a project container, treat that as explicit project-like

This path is where explicit intent is strongest, so it should be able to overwrite existing inferred labels.

#### Undo

Undo should preserve the existing `projectAssociation` in v1.

It should not:

- clear the value
- recompute it from weak inference
- try to infer a new project just because the file returned to a generic folder

In this slice, `projectAssociation` is durable file memory. Undo changes the path and appends history, but it does not erase the learned or explicit association.

### 8. Surface Read-Only Proof in the Inspector

The single-file inspector remains the only visible proof surface.

Update the existing metadata proof in [`FileInspectorView`](../../../../Forma%20File%20Organizing/Views/FileInspectorView.swift) so it can show:

- `Project: <label>`
- a short source explanation, for example:
  - `Derived from destination folder`
  - `Derived from related-file pattern`

The proof copy should be best-effort and derived by the metadata layer.

Recommended summary addition:

- extend [`FileMetadataInspectorSummary`](../../../../Forma%20File%20Organizing/Models/FileMetadataInspectorSummary.swift) with an optional `projectAssociationSourceSummary`

Allowed source-summary categories in v1:

- `Derived from destination folder`
- `Derived from related-file pattern`
- omit the line when neither summary can be derived confidently

The UI remains read-only:

- no edit controls
- no filter chips
- no project grouping surfaces

### 9. Keep Provenance Lightweight in V1

This slice should not add persistent provenance fields on `FileMetadataRecord`.

Instead:

- the current durable label lives on `projectAssociation`
- recent history rows already remain available in inspector proof
- the metadata service can derive a short source summary from the current resolution path or the latest relevant metadata event context

This is intentionally lighter than a full provenance schema. If the product later needs editable metadata, conflict resolution, or project spaces, that later slice can decide whether persistent source/confidence fields are warranted.

## Testing

### Service and Resolution Coverage

- explicit cluster-organize destination writes the terminal folder name as `projectAssociation`
- rule-backed destinations under `Projects/...` write the terminal folder name
- generic destinations such as `Screenshots` do not write project association
- strong inferred winner writes `projectAssociation` when the record is empty
- weak inference writes nothing
- conflicting inference writes nothing

### Precedence and Stability Coverage

- explicit destination wins over a competing inferred label
- explicit destination can overwrite a previously inferred label
- inference does not overwrite an already populated association
- weak inference does not clear an existing association

### Lifecycle Coverage

- scan and explicit-file evaluation write project association best-effort without breaking `FileItem` persistence
- organize / bulk organize / redo preserve metadata identity while writing eligible explicit association
- undo preserves the existing project association while restoring path/history continuity

### Inspector Coverage

- inspector shows project association when present
- inspector shows source explanation when available
- inspector hides the project row cleanly when no association exists
- inspector remains unchanged when the feature flag is disabled

## Explicit Deferrals

The following are intentionally deferred:

- manual project assignment
- project-association removal UX
- tags
- durable status authoring
- project filters or grouping
- project-space navigation
- persistent project provenance/confidence fields
- a separate durable project entity
- workflow-step execution and rollback beyond current metadata seams

## Why This Slice First

This is the smallest metadata product slice that makes the foundation feel consequential.

It adds one durable retrieval primitive without reopening the larger product questions of:

- how users edit metadata
- how project spaces should behave
- how workflow chains write multiple metadata fields

That is the right order.

First:

- durable identity
- durable history
- one conservative auto-applied field

Later:

- richer metadata authoring
- project retrieval surfaces
- workflow-driven metadata updates

That sequencing keeps the roadmap buildable and keeps the product trustworthy.
