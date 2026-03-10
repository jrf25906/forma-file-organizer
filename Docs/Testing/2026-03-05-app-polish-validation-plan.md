# Forma App Polish / Visual Validation Plan

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

This is the first validation pass for the macOS app polish work. It focuses on visual hierarchy, native-feeling behavior, and cross-surface consistency in the current app build before another app polish implementation loop begins.

Companion execution documents:

- `Docs/Testing/2026-03-05-app-polish-current-build-capture-checklist.md`
- `Docs/Testing/2026-03-05-app-polish-first-pass-findings-template.md`

## 1. Goals and Pass / Fail Criteria

### Primary goals

1. Confirm that the main workspace feels like a focused, premium Mac utility rather than a washed-out glass demo.
2. Confirm that the right panel and rule builder carry the correct visual and operational weight.
3. Confirm that Smart Rules and Analytics guide action clearly in empty, low-data, and live-data states.
4. Confirm that file presentation remains coherent across card, list, and grid views.
5. Confirm that onboarding, settings, and the main workspace feel like one product.
6. Confirm that the app holds up in light mode, dark mode, inactive-window state, and Reduce Transparency mode.

### Mandatory pass criteria

- `C1 - Shell hierarchy`: Sidebar, content, and inspector surfaces are visually distinct, and the current task region reads as primary when reviewable files exist.
- `C2 - Review workflow clarity`: Pending review, all files, toolbar controls, and row-level actions point toward one obvious next step rather than competing actions.
- `C3 - Rule-builder authority`: The inline rule builder feels deliberate and powerful, with clear `When`, `Then`, and impact consequences.
- `C4 - Operational secondary surfaces`: Smart Rules and Analytics explain what matters next instead of reading like admin filler or dashboard theater.
- `C5 - Cross-view parity`: Card, list, and grid communicate the same core status story with matched destination, confidence, and next-action semantics.
- `C6 - Native cohesion`: Onboarding, settings, and the main workspace retain native macOS behavior and feel like the same product.

### Quality pass criteria

- `Q1 - Visual density and contrast`: Toolbar labels, row metadata, inspector copy, and secondary labels remain readable and intentional in light and dark modes.
- `Q2 - State resilience`: The app remains coherent in active and inactive window states and with `Reduce Transparency` enabled.
- `Q3 - Brand cohesion`: The app does not shift between overly soft onboarding, generic settings, and operational dashboard voices.
- `Q4 - Capture completeness`: Baseline evidence includes dashboard, list, grid, rule builder, Smart Rules, Analytics, Settings, Onboarding, and state variants needed for judgment.

### Fail conditions

- Any failure of `C1` through `C6` blocks app-polish sign-off.
- More than three medium-severity issues across `Q1` through `Q4` block readiness.
- Missing evidence for grid parity, inactive-window state, or `Reduce Transparency` means the validation pass is incomplete even if the visible screens look strong.

## 2. Screens / Surfaces to Capture

### Core workspace surfaces

- Dashboard pending-review queue in card view with default inspector
- All Files in list view
- File grid view
- Inline rule builder in the inspector
- Right panel default state with current task and automation section

### Secondary workflow surfaces

- Smart Rules empty state
- Smart Rules live state with at least one enabled rule
- Smart Rules needs-access state if available
- Analytics low-data state
- Analytics populated-data state if available
- Settings `General`
- Onboarding welcome step

### State variants

- Light mode core workspace
- Dark mode core workspace
- Inactive-window core workspace
- `Reduce Transparency` core workspace

### Evidence requirements

- Capture before / after screenshot pairs for every surface that materially changes during the polish pass.
- Record one desktop interaction flow covering review queue -> rule builder -> Smart Rules -> Analytics -> Settings.
- Capture one parity strip showing the same file in card, list, and grid.
- Store a findings log with severity, evidence, and required fix for each issue discovered.

## 3. Screenshot Matrix by Surface and State

Each required row below needs a baseline screenshot and a post-polish screenshot.

| Surface | Light active | Dark active | Inactive window | Reduce Transparency | Notes |
| --- | --- | --- | --- | --- | --- |
| Dashboard pending queue + default inspector | Required | Required | Required | Required | Primary judgment surface for shell hierarchy and task focus. |
| All Files list view | Required | Optional | Optional | Optional | Must show dense row hierarchy and toolbar state. |
| File grid view | Required | Optional | Optional | Optional | Must use the same file set as list or card where possible. |
| Inline rule builder | Required | Required | Optional | Optional | Capture with validation message visible if possible. |
| Smart Rules empty state | Required | Optional | Optional | Optional | Current build baseline already includes this state. |
| Smart Rules live / needs-access state | Required | Optional | Optional | Optional | Required for operational triage review. |
| Analytics low-data state | Required | Required | Optional | Optional | Capture zero or near-zero activity state. |
| Analytics populated-data state | Required | Optional | Optional | Optional | Required once real metrics exist. |
| Settings `General` | Required | Optional | Optional | Optional | Verify shell consistency and native control treatment. |
| Onboarding welcome step | Required | Optional | Optional | Optional | Verify tone and trust signaling against main app shell. |
| Card / list / grid parity triptych | Required | Optional | Optional | Optional | Same file or same file set across all three modes. |

## 4. Interaction-Recording Review Checklist

### Primary recording

- Record the app in a standard desktop window.
- Start on the dashboard pending-review queue.
- Pause for 2 seconds on the default inspector state.
- Switch to the rule builder and pause long enough to read the section hierarchy.
- Visit Smart Rules, then Analytics, then Settings.
- If possible, switch between card, list, and grid while the same file set is visible.

### Review checklist

- [ ] The current task is obvious within 2 seconds of opening the app.
- [ ] The right panel feels like part of the workflow, not a secondary afterthought.
- [ ] The rule builder explains consequence, not just fields.
- [ ] Smart Rules and Analytics make a next step obvious in empty or low-data states.
- [ ] Switching file view modes does not change the meaning of status, destination, or confidence.
- [ ] Settings and onboarding still feel like the same product once the main app has been seen.

## 5. Heuristic Review Tasks

### Task 1 - Two-second task read

- Open the dashboard pending queue.
- Look for 2 seconds only.
- Answer: "What should I do next?"
- Fail if the answer is unclear or if the inspector looks less important than ambient chrome.

### Task 2 - Rule-builder consequence check

- Open the inline rule builder.
- Answer:
  - What files will this rule match?
  - What will happen to those files?
  - What tells me whether the rule is safe to create?
- Fail if any answer depends on reading the full panel top to bottom with no visual prioritization.

### Task 3 - Smart Rules operational review

- Review Smart Rules in whatever state is available.
- Fail if the screen reads as a generic list or template gallery rather than a rule-control surface.

### Task 4 - Analytics credibility check

- Review Analytics in low-data and populated-data states.
- Fail if the screen shows too much dashboard chrome relative to the amount of real insight available.

### Task 5 - File-view parity audit

- Compare the same file or file set in card, list, and grid.
- Fail if status, destination, rule confidence, or next action become hidden, renamed, or visually reweighted between modes.

### Task 6 - App-family cohesion audit

- Compare onboarding, settings, and the main workspace.
- Fail if they feel like three different product voices or three unrelated surface systems.

### Task 7 - State-resilience pass

- Compare active, inactive, and `Reduce Transparency` states on the main workspace.
- Fail if blur, tint, or contrast loss makes the content hierarchy collapse.

## 6. Lightweight Design Experiments

These are low-overhead experiments for the first app polish cycle.

### Experiment A - Content / inspector material intensity

- Variant A: Current pane material overlays.
- Variant B: Reduced ambient, accent, and sheen overlays for `.content` and `.inspector`.
- Hypothesis: Lower chrome intensity will make rows, task copy, and right-panel hierarchy feel more decisive.
- Primary signal: Reviewer confidence in the current task and inspector hierarchy.

### Experiment B - Rule-builder impact visibility

- Variant A: Current continuous sidebar form.
- Variant B: Three-part builder with a persistent `Impact` summary.
- Hypothesis: A visible impact region will make rule creation feel safer and more powerful.
- Primary signal: Reviewer ability to explain consequence without reading the entire panel.

### Experiment C - Shared file meta strip

- Variant A: Current card / list / grid metadata treatments.
- Variant B: Shared meta strip and status semantics across all three modes.
- Hypothesis: View switching will feel lower-friction and more trustworthy when the same file story is visible in every mode.
- Primary signal: Fewer parity failures in the file-view audit.

## 7. Output Format for Findings

Use one findings log for each app validation pass.

### Required fields

| Field | Description |
| --- | --- |
| ID | Short stable identifier, for example `APP-001` |
| Severity | `Critical`, `High`, `Medium`, or `Low` |
| Surface | Screen or workflow surface |
| Evidence | Screenshot name, recording step, or code-backed state reference |
| Failed criterion | Reference to `C1`-`C6` or `Q1`-`Q4` |
| Finding | Short description of what failed |
| Required fix | Clear change needed before the next pass |
| Owner | Person or area responsible |
| Status | `Open`, `In Progress`, `Fixed`, `Accepted` |

### Findings log template

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| APP-001 | High | Dashboard shell | `forma-01-hero-main-window.png` | C1 | The task surface is readable, but the chrome still dilutes hierarchy. | Reduce pane chrome and strengthen inspector emphasis. | App UI | Open |

### Severity definitions

- `Critical`: Blocks readiness and breaks the core review workflow or makes the app feel unsafe to use.
- `High`: Substantially weakens product confidence, visual clarity, or operational usability and must be fixed before sign-off.
- `Medium`: Noticeably softens polish or clarity but does not break the primary path alone.
- `Low`: Minor polish issue that can be batched after the core pass.
