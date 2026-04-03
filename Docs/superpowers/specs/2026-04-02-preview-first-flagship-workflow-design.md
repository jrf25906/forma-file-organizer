# Preview-First Flagship Workflow Design

**Date:** April 2, 2026

## Goal

Make Forma's main differentiated behavior feel like one coherent workflow: review files, understand why a suggestion exists, create or edit a rule in context, execute the action, and recover with undo if needed.

## Problem Statement

Forma already has the necessary primitives:

- Review-first queueing and chunked review
- Inspector reasoning and rule simulation
- Inline right-panel rule building
- Full modal rule editing
- Undoable organization batches and activity history

What is missing is workflow continuity. The current experience still feels like adjacent features:

- The inspector, inline rule builder, and modal rule editor do not behave like one shared composer.
- The right panel and modal editor use separate local `RuleFormState` ownership, so expanding or collapsing the editor can drop in-progress draft edits.
- Primary action ownership is split between the center pane, inspector, default panel, celebration surfaces, and undo affordances.
- Explanation and undo language are present, but not consistently framed as one review-driven journey.

## Product Principles

1. Preview-first remains the default posture.
2. Rule creation should feel like a continuation of review, not a trip to settings.
3. The user should never lose place in the active review chunk while exploring explanation or editing a rule.
4. Each state should have one obvious next action.
5. Undo and auditability should stay visible enough to reinforce trust, but should not compete with the primary action.

## Recommended Scope

This pass should be a workflow-cohesion slice, not a subsystem rewrite.

It should include:

- Shared draft continuity between inline and modal rule editing
- Stable review-context handoff between list/grid, inspector, panel builder, and modal editor
- Clear primary-action ownership by state
- Consistent explanation and undo framing

It should not include:

- Replacing the full rule architecture
- Merging inline and modal editors into a single implementation
- New automation capabilities
- Metadata or personal-memory work
- A major visual redesign unrelated to workflow clarity

## Approach Options

### Option A: Copy and layout polish only

Improve labels, hierarchy, and CTA prominence without changing state ownership.

Pros:

- Fastest delivery
- Low code risk

Cons:

- Leaves the main continuity bug intact
- Does not materially improve the review -> rule -> undo journey

### Option B: Shared workflow state with existing surfaces

Keep the right-panel builder and modal editor, but give them a shared draft session and a clearer handoff model.

Pros:

- Fixes the real continuity problem
- Preserves existing surfaces and architecture
- Matches the roadmap goal with moderate scope

Cons:

- Requires careful state ownership and tests
- Some duplicate UI structure remains

### Option C: Replace panel and modal editing with one unified editor

Collapse rule editing into one surface and remove the panel/modal split.

Pros:

- Cleanest long-term model

Cons:

- Too large for this roadmap item
- High regression risk across dashboard, rules management, and onboarding flows

## Recommendation

Use Option B.

It fixes the highest-friction workflow break without reopening the broader rule-editor architecture. This is the smallest change that makes the product feel more intentionally designed.

## Proposed Design

### 1. Shared Rule Draft Session

Introduce a lightweight draft-session model owned above both rule-editing surfaces.

Responsibilities:

- Hold the current `RuleFormState`
- Track the source of the session:
  - new rule from file context
  - edit existing rule
  - suggested natural-language seed
- Preserve validation and destination state while switching surfaces
- Clear only on explicit save, discard, or context reset

Preferred owner:

- `NavigationViewModel`, because it already coordinates the modal rule editor and carries editing context across views

The inline panel and modal editor should both initialize from, and write back to, this shared session instead of keeping isolated draft state.

### 2. Review Context Preservation

The active review chunk remains the source of truth while the user:

- opens the inspector
- opens inline rule creation from a file
- expands into the modal editor
- returns back to the right panel or file review

Required behavior:

- Returning from rule editing should restore the user to the same review chunk and selected file when possible.
- Opening the full editor from the inline builder should not reset review mode or selection.
- Closing the modal editor should restore the previous panel destination:
  - inspector if launched from a file-inspection path
  - default panel if launched from a generic rule-creation path

### 3. Primary-Action Ownership

Each major state should declare one primary action:

- Review chunk active: organize current chunk
- Single file inspector with suggestion: organize file
- Single file inspector without suggestion: create rule for this file
- Rule draft active: save rule
- Freshly completed organization batch: undo recent batch remains the recovery action, but should be visually secondary to successful completion messaging unless the batch is automatic

The default panel should not compete with the active review state for primary CTA ownership.

### 4. Explanation + Undo Framing

Use the same conceptual language across inspector, default panel, and activity surfaces:

- Why this matched
- What will happen
- Whether it came from a rule or suggestion
- Whether the result is undoable right now

The inspector should remain the best place to inspect file-specific reasoning, but the summary language should align with:

- automation preflight cards in the default panel
- undo summaries for recent automatic batches
- activity feed audit badges and detail text

### 5. Rule Composer Framing

The rule builder should read as staged composition:

1. When this file pattern appears
2. Then move/copy/delete it here
3. Impact preview
4. Save rule

This does not require a new builder architecture. It requires stronger continuity between the existing inline and modal flows, plus clearer hierarchy around validation and impact preview.

## Architecture Notes

### New or Expanded State

- `NavigationViewModel`
  - add shared draft-session storage for rule editing
  - add return-target metadata so dismiss paths know whether to restore inspector or default panel

### Existing Views

- `InlineRuleBuilderView`
  - bind to shared draft session
  - update expand-to-modal handoff to preserve current draft contents

- `RuleEditorView`
  - bind to shared draft session
  - update collapse-to-panel handoff to preserve current draft contents

- `FileInspectorView`
  - route "Create Rule for This" and "Based on rule..." through the shared workflow session
  - keep explanation copy aligned with activity/undo language

- `RightPanelView`
  - continue rendering the current mode, but do not own rule draft state

- `DefaultPanelView`
  - keep primary CTA subdued whenever review or rule-editing owns the next action
  - align preflight/undo summaries with inspector language

### Non-Goals

- No persistence of half-complete rule drafts across app relaunch
- No redesign of rules management outside workflow continuity needs
- No changes to rule-evaluation logic or automation policy

## Error Handling

- If a shared draft session becomes invalid, fall back to rebuilding from the explicit source context:
  - existing rule
  - file context
  - suggested natural-language text
- If neither exists, dismiss to the safest neutral state:
  - modal closes
  - right panel returns to default
- Destination picker, bookmark access, and validation errors should remain attached to the draft session so they survive panel/modal transitions.

## Testing Strategy

### Unit / ViewModel

- Shared rule draft session is created with the correct source context.
- Expanding panel -> modal preserves `RuleFormState`.
- Collapsing modal -> panel preserves `RuleFormState`.
- Dismissing a saved or discarded draft clears only the active session.
- Review chunk and selected file survive temporary rule-editing detours.

### UI

- Review a file -> open inline builder -> type draft -> expand to modal -> draft still present
- Modal -> collapse to panel -> draft still present
- Save rule from the workflow -> return to coherent post-save state
- Organize or auto-organize batch -> undo summary remains discoverable and consistent

### Regression Areas

- `RulesManagementView` launch paths into the modal editor
- Productivity/insight deep links that open the modal editor directly
- Inspector and default-panel transitions while selection changes
- File-level parity for card/list/grid review surfaces

## Acceptance Criteria

- Users do not lose in-progress rule edits when switching between inline and modal editors.
- Entering and leaving rule editing does not break review-chunk continuity.
- Each workflow state presents one obvious primary action.
- Explanation and undo language read as one system across inspector, right panel, and activity history.
- The change improves perceived cohesion without introducing a new editing paradigm.
