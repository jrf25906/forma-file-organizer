# Dashboard Layout State Contract

**Date:** 2026-04-21
**Status:** Approved in-thread, pending implementation
**Scope:** Dashboard root layout states, destination routing, inspector behavior, and home-state restoration

## Summary

Forma's dashboard needs an explicit root-screen contract so the app stops mixing two different ideas:

- `Home` as a working three-area dashboard with a contextual right panel
- `Analytics` / global `Smart Rules` as full-width destinations that need the whole workspace area

This spec makes that split explicit.

The left sidebar is persistent across all top-level states. `Home` remains the default workspace and uses the current sidebar + center + right-panel layout. `Analytics` and left-sidebar `Smart Rules` become full-workspace destinations that replace everything to the right of the sidebar. Contextual rule creation from the center workflow stays inside `Home` and uses the compact right panel.

Returning from a full-workspace destination restores the previous `Home` state exactly, including whether the right panel was open and its width.

## Goals

- Make the root layout model explicit so split-view behavior is predictable.
- Keep the left sidebar stable across `Home`, `Analytics`, and `Smart Rules`.
- Give `Analytics` and global `Smart Rules` enough width to function as real workspaces.
- Preserve compact right-panel flows for contextual actions inside `Home`.
- Restore the exact prior `Home` workspace after leaving a full-workspace destination.

## Non-Goals

- No redesign of the existing center-column review workflow in `Home`.
- No redesign of the file inspector's content model.
- No sidebar information-architecture changes beyond routing behavior.
- No new dashboard destinations beyond `Home`, `Analytics`, and global `Smart Rules` in this slice.

## State Model

### Root States

The app should have three named root presentation states:

1. `homeWorkspace`
2. `analyticsWorkspace`
3. `rulesWorkspace`

These are mutually exclusive root states for the area to the right of the persistent left sidebar.

### Home Snapshot

`homeWorkspace` must preserve and restore a snapshot of the user's last dashboard working state:

- `isRightPanelVisible`
- `rightPanelWidth`
- `rightPanelMode`
- current center-workspace context

The implementation may store more `Home` state than this, but these fields are the minimum contract required by the agreed behavior.

## State Definitions

### `homeWorkspace`

Layout:

- persistent left sidebar
- center dashboard workspace
- contextual right panel

Rules:

- This is the default dashboard mode.
- On first/default launch, `homeWorkspace` should open with the right panel visible at a good predefined width matching the current preferred visual balance.
- After the user has established a `Home` state, returning to `homeWorkspace` should restore that exact prior state instead of reapplying the default.
- The inspector toggle belongs to this state.

### `analyticsWorkspace`

Layout:

- persistent left sidebar
- full analytics workspace occupying the entire area to the right of the sidebar

Rules:

- The narrow right-panel analytics presentation is not used here.
- The center workspace and contextual right panel are not independently visible in this state.
- This screen must provide a visible `Back to Dashboard` action.
- The inspector toggle should be hidden or disabled in this state.

### `rulesWorkspace`

Layout:

- persistent left sidebar
- full Smart Rules workspace occupying the entire area to the right of the sidebar

Rules:

- This is the destination used when the user enters Smart Rules from the left sidebar.
- The compact right-panel rule UI is not used here.
- This screen must provide a visible `Back to Dashboard` action.
- The inspector toggle should be hidden or disabled in this state.

## Source-Dependent Smart Rules Behavior

Smart Rules has two valid presentations, chosen by entry source:

### Global entry

When the user clicks `Smart Rules` from the left sidebar:

- transition to `rulesWorkspace`
- keep the left sidebar fixed
- dedicate the full remaining width to the Smart Rules experience

### Contextual entry

When the user starts rule creation from a decision inside the center workflow:

- remain in `homeWorkspace`
- keep the center workflow visible
- open the compact right-panel rule UI

This source-dependent split is intentional and should be preserved.

## Transitions

### Launch and Restore

`appLaunch` -> `homeWorkspace`

- First/default launch: open `homeWorkspace` with the right panel visible at the preferred default width.
- Relaunch with saved `Home` state: restore the prior `homeWorkspace` snapshot.

### Destination Entry

`sidebar.analyticsTapped` from any root state -> `analyticsWorkspace`

- preserve the current `homeWorkspace` snapshot before leaving `Home`
- leave the left sidebar in place
- replace the entire workspace area with analytics

`sidebar.smartRulesTapped` from any root state -> `rulesWorkspace`

- preserve the current `homeWorkspace` snapshot before leaving `Home`
- leave the left sidebar in place
- replace the entire workspace area with Smart Rules

### Contextual Rule Entry

`centerWorkflow.createRuleTapped` from `homeWorkspace` -> `homeWorkspace`

- no root-state change
- show compact rule UI in the right panel
- preserve center workflow context

### Return to Home

`analyticsWorkspace.backToDashboardTapped` -> `homeWorkspace`

`rulesWorkspace.backToDashboardTapped` -> `homeWorkspace`

For both transitions:

- restore the previously captured `homeWorkspace` snapshot exactly
- restore the prior right-panel visibility
- restore the prior right-panel width
- restore the prior center-workspace context

### Inspector Toggle

`homeWorkspace.inspectorToggleTapped` -> `homeWorkspace`

- only changes `Home` panel visibility
- never acts as cross-screen navigation

`analyticsWorkspace.inspectorToggleTapped` and `rulesWorkspace.inspectorToggleTapped`

- should not be available as active navigation
- control is hidden or disabled

## Layout Rules

### Persistent Sidebar Rule

The left sidebar is stable across all root states and should never be repurposed, collapsed unexpectedly, or replaced by destination content.

### Home Rule

`Home` is the only state that uses the contextual right panel as part of the primary workspace composition.

### Destination Rule

`Analytics` and left-sidebar `Smart Rules` are destination screens, not inspector modes.

### Restore Rule

Leaving a destination screen must never reset `Home` to a generic default if a prior `Home` snapshot exists.

## Toolbar Rules

- The inspector toggle is a `Home` control.
- Full-workspace `Analytics` and `Smart Rules` should instead expose a clear `Back to Dashboard` affordance.
- The user should not have to infer that the inspector toggle also means "go home."

## Acceptance Criteria

- Launching Forma opens `homeWorkspace` in the intended dashboard composition, including a usable default right-panel width.
- Clicking left-sidebar `Analytics` preserves the sidebar and gives analytics the full remaining workspace width.
- Clicking left-sidebar `Smart Rules` preserves the sidebar and gives Smart Rules the full remaining workspace width.
- Starting rule creation from the center workflow keeps the user in `homeWorkspace` and uses the compact right-panel rule UI.
- Full-workspace `Analytics` and `Smart Rules` both offer a clear `Back to Dashboard` action.
- Returning from either full-workspace destination restores the exact previous `Home` state, including right-panel visibility and width.
- The inspector toggle no longer acts as an accidental routing control for full-workspace destinations.

## Implementation Boundary

This spec implies a clean separation between:

- root destination state (`homeWorkspace`, `analyticsWorkspace`, `rulesWorkspace`)
- `Home`-only panel state (inspector visibility, width, and mode)

The implementation should preserve that boundary rather than encoding destination behavior indirectly through `NavigationSplitView` column tricks or through reusing the inspector panel as a stand-in for full-workspace destinations.
