# Cross-Folder Project Spaces v1 Design

Date: 2026-04-06
Branch: `codex/cross-folder-project-spaces-v1`
Status: Draft for spec review

## Summary

`Cross-folder project spaces v1` turns the metadata ledger into a visible retrieval surface.

The slice introduces read-only project spaces that are derived from durable `projectAssociation` labels already stored on `FileMetadataRecord`. Users see a new `Project Spaces` section in the dashboard, can open a known space, and can browse the currently resolvable files associated with that project across folders. The first slice is intentionally narrow: no new project entity, no speculative membership, no editing tools, and no workflow execution from spaces.

This follows the roadmap order already established in the repo:

- metadata foundation shipped first
- auto-applied project association shipped next
- content tags and durable workflow status completed afterward
- project spaces now use that foundation for retrieval before the later workflow-engine work

## Goals

- Use durable metadata to answer "where did I put that?" across folders.
- Surface known project contexts directly in the dashboard without adding a new top-level app section.
- Keep membership strict and explainable by relying only on durable `projectAssociation`.
- Reuse current file selection and inspector behavior instead of creating space-specific actions.
- Keep the implementation local-first, read-only, and reversible.

## Non-Goals

- No manual project labeling or editing UX.
- No new persisted `Project` model.
- No live inference fallback inside project spaces.
- No historical placeholder rows for files that no longer resolve locally.
- No organizing, relabeling, or workflow triggers from the project-space surface.
- No project-space badges or broad navigation refactors in v1.

## Product Boundary

### Membership

Project-space membership is strict in v1:

- a file is in a space only if its metadata record carries a durable `projectAssociation`
- the space key is the normalized project label already stored in metadata
- if a file has no durable project label, it is not in any project space
- if the metadata record exists but the file cannot currently be resolved to a local file, it does not appear in the space

There is no cluster-based, history-based, or heuristic fallback for unlabeled files in this slice.

### Entry Surface

Project spaces first appear inside the existing dashboard flow:

- add a `Project Spaces` section to the dashboard/default-home experience
- show it only when the feature is enabled and at least one known project space exists
- opening a space stays within the dashboard flow rather than creating a new sidebar destination

### Space Detail

Opening a project space shows a read-only detail surface with:

- project label
- current file count
- last activity
- source folders summary
- files currently in that space

The detail surface reuses existing file selection and inspector flows. It does not introduce editing or organization actions in v1.

## Data Model

### Persistence Posture

This slice does not create a new persisted project-space model.

Instead it derives project spaces from existing metadata:

- `FileMetadataRecord.projectAssociation`
- `FileMetadataRecord.lastSeenAt`
- `FileMetadataRecord.lastOrganizedAt`
- `FileMetadataRecord.workflowStatus`
- `FileOrganizationHistoryEntry`

### Presentation Models

The app may add lightweight derived models for query/view use, such as:

- `ProjectSpaceSummary`
- `ProjectSpaceFileRow`
- `ProjectSpaceDetail`

These models are read models only. They are not persisted independently.

Recommended fields:

`ProjectSpaceSummary`
- `projectLabel: String`
- `fileCount: Int`
- `lastActivityAt: Date`
- `sourceFolderHints: [String]`

`ProjectSpaceFileRow`
- `canonicalIdentity: String`
- `path: String`
- `displayName: String`
- `fileExtension: String`
- `lastActivityAt: Date`
- `workflowStatus: MetadataWorkflowStatus?`
- `tags: [String]`

`ProjectSpaceDetail`
- `summary: ProjectSpaceSummary`
- `files: [ProjectSpaceFileRow]`

## Query and Resolution Rules

### Label Grouping

Project spaces are grouped by normalized durable `projectAssociation` value, using the same normalization rules already applied when metadata is written.

### Resolvable Files Only

The service must only surface files whose metadata still resolves to a current local file.

Resolution should prefer the metadata foundation's existing identity/path lookup behavior instead of ad hoc file probing. If a record cannot be resolved into a present file item or path-backed representation, it is excluded from v1 project spaces.

### Last Activity

`lastActivityAt` should be derived conservatively from durable metadata/history, preferring the most recent meaningful known activity, for example:

1. latest durable history entry timestamp
2. `lastOrganizedAt`
3. `lastSeenAt`
4. `firstSeenAt`

This keeps the ranking stable and explainable without inventing a second activity system.

### Source Folder Hints

Each summary should include a bounded list of source folder hints derived from current member file paths.

The hints are only lightweight context for the dashboard row. They are not new saved metadata. A capped summary such as one to three distinct roots is enough for v1.

## Service Boundary

`FileMetadataFoundationService` remains the natural home for project-space retrieval.

Recommended additions:

- fetch all project-space summaries
- fetch one project-space detail by normalized label
- resolve project-space file rows from metadata records

Responsibilities:

- fetch and normalize metadata-backed labels
- exclude records without valid `projectAssociation`
- exclude unresolved historical records
- derive recency and source-folder hints
- return stable read models for the view model

Responsibilities that stay out of the service:

- SwiftUI presentation state
- navigation/panel routing
- custom space-specific action handling

## View-Model Integration

`DashboardViewModel` should own project-space UI state for this slice.

Recommended responsibilities:

- load project-space summaries when the feature is enabled
- expose a selected project space summary/detail
- refresh project spaces alongside other metadata-backed dashboard refresh points
- keep project-space state separate from content-tag filters and cluster suggestions

Recommended state additions:

- `projectSpaces: [ProjectSpaceSummary]`
- `selectedProjectSpace: ProjectSpaceSummary?`
- `selectedProjectSpaceDetail: ProjectSpaceDetail?`
- `isShowingProjectSpaceDetail: Bool`

The view model should not treat project spaces as secondary filters in v1. A project space is a distinct retrieval surface, not just another chip layered onto the current file list.

## UI Surface

### Dashboard Section

Add a `Project Spaces` section to the dashboard/default-home surface when:

- `FeatureFlagService.shared.isEnabled(...)` for the new project-space feature returns `true`
- and at least one known project space exists

Each row/card should show:

- project label
- file count
- recency text based on `lastActivityAt`
- optional compact source-folder hint

Sort order:

1. most recent `lastActivityAt` first
2. larger `fileCount` as secondary sort
3. alphabetical label as final stable tie-breaker

### Detail Surface

Selecting a project space opens a read-only detail view inside the dashboard flow.

The detail view should include:

- summary header for the selected project
- file list for current members
- current file selection and inspector affordances when a file is chosen

The detail view should not add:

- rename/relabel controls
- tag editing
- workflow buttons
- simulated actions
- historical placeholders for missing files

## Navigation Posture

This slice should avoid introducing a new `NavigationSelection` case for project spaces unless existing dashboard flow constraints make that unavoidable.

Preferred posture:

- the dashboard remains the entry point
- project-space detail behaves like a dashboard-owned substate or presentation mode
- sidebar information architecture does not change in v1

If implementation pressure later proves a new route is required, keep it dashboard-scoped rather than presenting project spaces as a new top-level product area.

## Feature Gating and Rollout

Add a dedicated feature flag for this slice at the app entry point, for example:

- `FeatureFlagService.Feature.projectSpaces`

Rollout rules:

- when disabled, no dashboard section or project-space detail UI appears
- no writes are introduced by this slice, so the feature flag only gates retrieval/UI exposure
- existing metadata behavior remains unchanged whether the UI is on or off

## Error Handling

The slice should fail closed and quietly:

- if project-space retrieval fails, the dashboard section simply does not render
- if one metadata record is malformed or unresolved, it is skipped without blocking the whole space
- if a selected space becomes empty during refresh, the detail surface dismisses back to the dashboard section state

No new user-facing error banners are required for v1 unless the dashboard already has an established non-disruptive pattern for this class of failure.

## Testing

Add focused coverage for the new retrieval layer and dashboard orchestration.

Service/query coverage:

- summaries only include records with durable `projectAssociation`
- unlabeled records do not appear in any space
- unresolved records are excluded
- recency ordering uses the intended timestamp precedence
- source-folder hints stay bounded and stable
- detail membership exactly matches the selected normalized label

View-model coverage:

- dashboard exposes project spaces only when the feature is enabled
- no spaces are shown when no labeled/resolvable records exist
- selecting a space loads the expected detail payload
- clearing or invalidating the selected space returns the dashboard to a safe state

UI coverage:

- dashboard project-spaces section renders only when expected
- opening a project space shows summary plus file list
- selecting a file from a project space still uses existing inspector/file selection behavior

## Open Future Path

This slice intentionally leaves room for later work:

- project-space filters or saved retrieval modes
- manual project metadata editing
- project-space badges across broader file surfaces
- richer timelines and status/tag breakdowns
- workflow-aware spaces
- a later persisted project model if the product truly needs one

For now, project spaces remain a thin metadata-backed retrieval surface that proves the value of cross-folder memory before the later workflow-engine expansion.
