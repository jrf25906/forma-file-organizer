# Auto-Applied Content Tags V1 Design

**Status:** Current
**Last Updated:** 2026-04-06
**Audience:** Developers, Product, Design

## Goal

Build the next real metadata slice on top of the durable ledger by making content tags durable and useful:

- write a small curated set of auto-applied content tags onto [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift)
- expose those tags through lightweight dashboard quick filters
- keep the system read-only and conservative in v1

This slice should do five things well:

1. write durable content tags from narrow explicit signals and obvious inference
2. keep tags multi-label but capped so output stays legible
3. make tags immediately useful for retrieval, not just inspection
4. preserve tags across scan, organize, redo, and undo without churn
5. avoid pulling in manual metadata editing or workflow-engine work too early

This is intentionally the next metadata slice after:

- metadata foundation v1
- auto-applied project association v1

It should move the roadmap forward without pulling in:

- manual tag editing
- Finder tag writes or sync
- file-surface tag badges across card/list/grid
- durable status authoring
- project-space navigation
- workflow-step execution

## Problem Statement

The metadata ledger now has stable identity, structured history, and one useful retrieval field:

- `projectAssociation`

That is progress, but it is not yet enough to make metadata broadly useful in the dashboard.

Today:

- [`FileMetadataRecord`](../../../../Forma%20File%20Organizing/Models/FileMetadataRecord.swift) already has a `tags` field
- [`FileMetadataFoundationService`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift) already preserves metadata identity across scan, organize, undo, and redo
- [`FileInspectorView`](../../../../Forma%20File%20Organizing/Views/FileInspectorView.swift) already has a read-only metadata proof surface
- the dashboard already has an established filtering flow through [`FilterViewModel`](../../../../Forma%20File%20Organizing/ViewModels/FilterViewModel.swift), [`FileFilterManager`](../../../../Forma%20File%20Organizing/Coordinators/FileFilterManager.swift), and [`ActiveFiltersBar`](../../../../Forma%20File%20Organizing/Components/ActiveFiltersBar.swift)

What is missing is a second durable retrieval primitive that is broader than project association and more reusable across mixed folders.

The roadmap in [`TODO.md`](../../TODO.md) explicitly calls for lightweight local metadata such as tags, status, project association, and organization history, biased toward auto-applied metadata before manual tagging UX. The right next step is therefore not manual editing and not the workflow engine. It is to make `tags` real in a conservative, durable way.

Without this slice:

- the metadata ledger still under-delivers on retrieval value
- content-type memory remains trapped in transient filename or destination heuristics
- later workflow chains will have no durable tag field to write into
- dashboard retrieval still depends mostly on search text, category, and coarse secondary filters

The challenge is trust. Tags are useful only if they stay predictable. A first slice that writes too many labels, writes arbitrary free-form values, or silently removes earlier tags would make the dashboard harder to trust. The system therefore needs a small taxonomy, a narrow write policy, and sticky behavior.

## Product Principles

1. Content tags are durable file memory, not ephemeral UI annotations.
2. The first tag slice should favor clarity over coverage.
3. Tags are inherently multi-label, but v1 should cap them to keep the result readable.
4. Explicit signals should be deterministic; inference should only handle obvious cases.
5. Tags should become useful through retrieval before Forma adds manual authoring UX.
6. Auto-applied tags must never block scan, organize, redo, or undo behavior.
7. Once written, v1 tags should not churn or disappear based on weaker later evidence.

## Scope

### In Scope for V1

- auto-write a small curated set of durable content tags into `FileMetadataRecord.tags`
- define a fixed built-in taxonomy for the first slice
- resolve tags from two sources:
  - explicit rule/category/destination mappings
  - conservative inference for obvious file types
- merge explicit and inferred tags with deduplication and a small per-file cap
- keep tags sticky and append-only once written
- surface tags in the inspector's existing metadata proof
- add dashboard quick filters for the durable content tags
- keep the slice behind a dedicated feature flag layered on top of `metadataFoundation`
- add focused resolver, metadata-service, filter, pipeline, and integration coverage

### Explicitly Out of Scope

- manual tag editing
- Finder tags or Finder/Forma sync
- row/card/grid/main-content tag badges
- free-form or open-ended tag generation
- tag provenance persistence beyond best-effort proof
- tag-driven automation behavior
- durable status semantics
- workflow-step execution and rollback

## Approach Options

### Option A: Metadata-first tag layer

Resolve and append content tags inside the metadata layer, then expose them through inspector proof and dashboard quick filters.

Pros:

- keeps tag logic in one place
- builds directly on the metadata ledger just shipped
- scales cleanly into later workflow-chain work

Cons:

- requires a little more service integration before the UI payoff lands

### Option B: UI-first filter layer

Compute content tags near scan or dashboard view models, use them for dashboard filtering immediately, and mirror them into metadata secondarily.

Pros:

- fast visible retrieval payoff

Cons:

- duplicates logic across UI and persistence
- risks drift between live file state and durable metadata
- makes later workflow/tag writes harder to reason about

### Option C: Workflow-seeded tags

Treat tags as the first miniature workflow action and model writes like a simplified workflow step before the broader engine exists.

Pros:

- aligns directly with the later `match -> rename -> tag -> move -> notify -> log` roadmap

Cons:

- introduces engine shape too early
- over-builds a slice that only needs conservative durable tagging

## Recommendation

Use Option A: metadata-first tag layer.

This is the smallest slice that makes tags both durable and useful without inventing a second system.

It keeps the product shape narrow:

- one fixed taxonomy
- one centralized resolver
- one sticky append-only write policy
- one lightweight retrieval surface in the dashboard

It also keeps future work clean:

- later manual editing can expose the same stored tags
- later workflow chains can write into the same tag field
- later file-surface badges can reuse the same durable source

## Proposed Design

### 1. Reuse the Existing Durable Store

This slice should reuse:

- `FileMetadataRecord.tags: [String]`

Do not introduce:

- a separate tag entity
- per-tag confidence persistence
- per-tag provenance persistence
- free-form user-authored labels

The first slice only needs durable normalized tag strings.

Storage contract:

- keep using the existing normalization seam on `FileMetadataRecord`
- deduplicate tags before saving
- preserve stable user-visible label casing and spelling through a fixed built-in taxonomy
- cap the stored tag set per file to a small maximum of `3`

Cap behavior:

- explicit tags are retained first
- inferred tags fill any remaining slots
- if more tags are available than fit under the cap, drop the lowest-priority inferred tags first

### 2. Add a Dedicated Feature Flag

This slice should add a dedicated flag, for example:

- `FeatureFlagService.Feature.autoContentTags`

Behavior:

- it depends on `metadataFoundation`
- default should be `false`
- it should be exposed alongside the existing metadata flags in the Settings feature surface
- tag reads and writes should require both `metadataFoundation` and `autoContentTags`

This keeps rollout disciplined in the same way project association did:

- `metadataFoundation` gates the ledger
- `autoContentTags` gates the first durable tag-writing layer on top of it

### 3. Keep the First Taxonomy Small and Curated

V1 should ship a fixed, built-in set of content tags:

- `screenshot`
- `invoice`
- `receipt`
- `contract`
- `statement`
- `presentation`

Why this shape:

- all six are legible to users
- all six have plausible explicit-destination and filename-pattern signals
- all six are useful retrieval filters across mixed folders
- the set is small enough to keep inference conservative and the quick-filter UI manageable

Do not ship:

- broad ontology-style tags
- arbitrary AI-generated labels
- project-prefixed tags like `project:alpha`

### 4. Centralize Resolution in a Metadata Resolver

Add a dedicated metadata-layer resolver, for example:

- `MetadataContentTagResolver`

Responsibilities:

- resolve explicit content tags from narrow deterministic signals
- resolve inferred content tags from conservative heuristics
- merge, normalize, deduplicate, and cap the final tag set

This resolver should be the only place that owns:

- tag vocabulary
- alias tables
- explicit-vs-inferred precedence
- cap ordering

That keeps the rest of the codebase from spreading tag policy across scan code, views, and coordinators.

### 5. Write Explicit Tags Narrowly and Deterministically

Explicit tags should come first, but only from clear signals.

Approved v1 explicit inputs:

- rule destinations whose terminal folder name exactly matches a built-in content-tag alias
- category names or category destination labels that exactly match a built-in content-tag alias
- organize destinations whose terminal folder name exactly matches a built-in content-tag alias

Examples of acceptable v1 aliases:

- `Screenshots` -> `screenshot`
- `Invoices` -> `invoice`
- `Receipts` -> `receipt`
- `Contracts` -> `contract`
- `Statements` -> `statement`
- `Presentations` or `Slides` -> `presentation`

Constraints:

- use a fixed alias table owned by the resolver
- do not use fuzzy semantic matching
- do not infer tags from arbitrary destination names
- do not treat generic folders like `Documents` or `Archive` as tag sources

### 6. Allow Conservative Inference for Obvious Cases

Inference should only add tags for very obvious content types when no deterministic mapping is available.

Approved v1 inference patterns:

- `screenshot`
  - screenshot-style filenames such as `Screenshot ...`
  - image categories with standard screenshot naming patterns
- `invoice`
  - filenames containing strong invoice tokens
- `receipt`
  - filenames containing strong receipt tokens
- `contract`
  - filenames containing strong contract-like document tokens such as `contract`, `agreement`, or `nda`
- `statement`
  - filenames containing strong statement tokens
- `presentation`
  - presentation-oriented filenames and/or canonical presentation extensions such as `key`, `ppt`, or `pptx`

Inference constraints:

- use filename, extension, and existing file-category signals only
- do not introduce OCR, content parsing, or model-based semantic classification in this slice
- ignore weak, ambiguous, or low-signal matches

This preserves the "conservative inference" boundary chosen for the slice.

### 7. Use Union-with-Cap and Sticky Append-Only Behavior

V1 tag writes should follow this policy:

1. resolve explicit tags
2. resolve inferred tags
3. union them
4. deduplicate and cap
5. append newly qualified tags to the stored set

Persistence behavior:

- never duplicate an existing stored tag
- never remove an existing stored tag in this slice
- if later evidence is absent or weaker, keep the earlier tag
- undo should preserve the current durable tag set rather than recomputing it backward

This makes tags stable enough to be used in quick filters without surprising churn.

### 8. Integrate Writes Through Existing Metadata Seams

Do not invent a separate tagging pipeline.

Write through the same metadata seams already used by foundation and project association:

- scan / explicit-file evaluation in [`FileScanPipeline`](../../../../Forma%20File%20Organizing/Services/FileScanPipeline.swift)
- successful organize / bulk organize / redo transitions through [`FileMetadataFoundationService`](../../../../Forma%20File%20Organizing/Services/FileMetadataFoundationService.swift)
- undo preservation through the existing transition and rekey paths

Write behavior by surface:

- scan and explicit-file evaluation may append obvious tags best-effort
- organize, bulk organize, and redo may append new explicit tags from the chosen destination
- undo preserves existing tags and metadata identity without removing them

As with the rest of the ledger:

- tag writes are best-effort
- failures must not break file scanning, review, organize, redo, or undo

### 9. Add Dashboard Quick Filters Instead of Tag Badges

The first visible payoff should be retrieval, not badge sprawl.

Add lightweight tag quick filters into the existing dashboard filter flow rather than creating a new metadata panel.

Recommended shape:

- add a dedicated content-tag filter state to [`FilterViewModel`](../../../../Forma%20File%20Organizing/ViewModels/FilterViewModel.swift) and [`FileFilterManager`](../../../../Forma%20File%20Organizing/Coordinators/FileFilterManager.swift)
- surface tag chips near the existing dashboard filter controls
- only show tag chips that exist in the currently loaded file set
- mirror active selections in [`ActiveFiltersBar`](../../../../Forma%20File%20Organizing/Components/ActiveFiltersBar.swift) so empty states stay explainable

Filter semantics:

- tag filters are additive with the current search, category, folder, and secondary filters
- multiple selected tags should use any-match semantics within the tag set
  - selecting `invoice` and `receipt` should show files tagged with either one
- clearing tag filters should not disturb the existing search/category/folder state

This makes tags immediately useful without forcing file-surface badge work into the same slice.

### 10. Keep Inspector Proof Read-Only

The inspector should continue to show:

- `Tags` from the durable metadata summary

This slice may add best-effort source-proof copy if the metadata layer can reconstruct it cheaply, but it should not add a new persisted provenance model just for tags.

The product contract is:

- tags are durable and visible in the inspector
- retrieval happens in the dashboard filter flow
- authoring stays out of scope

## Testing Strategy

Add focused coverage for the risky seams:

- resolver tests
  - explicit alias mapping writes the expected built-in tag
  - conservative inference writes only obvious tags
  - explicit and inferred tags union cleanly
  - cap logic preserves explicit tags first
- metadata service tests
  - repeated writes do not duplicate tags
  - sticky append-only behavior preserves earlier tags
  - disabled feature flags skip tag writes safely
- pipeline tests
  - scan and explicit-file evaluation append obvious content tags best-effort
  - non-matching or weak evidence writes nothing
- integration tests
  - organize / bulk organize / redo preserve metadata identity and append eligible explicit tags
  - undo preserves the stored tag set
- filter tests
  - dashboard quick filters show only tags present in the loaded file set
  - tag selection narrows files correctly with any-match semantics
  - tag filters compose with existing category/search/folder filters

## Success Criteria

This slice is successful when:

- the metadata ledger stores a small curated set of durable content tags
- obvious files gain useful durable tags without manual editing
- tags remain stable across scan, organize, redo, and undo
- the dashboard can quickly filter to tagged content like `invoice` or `screenshot`
- the feature stays conservative enough that users can trust it

## Out of Scope for Follow-On Slices

This slice intentionally does not answer:

- how users manually add, remove, or correct tags
- how tags map to Finder tags
- whether tags should become visible badges across all file surfaces
- how durable status should work
- how workflow chains should write or remove metadata fields

Those are later roadmap steps. The job of this slice is narrower:

- make content tags durable
- make them retrievable
- keep the policy conservative and buildable
