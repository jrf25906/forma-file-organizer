# Right Rail V4 Compressed Editorial Design

**Date:** 2026-04-22  
**Status:** Approved in-thread, pending implementation  
**Scope:** Default right rail hierarchy, composition, copy posture, and semantic color discipline

## Summary

The current right rail is semantically cleaner than the earlier editorial passes, but it still feels visually unresolved.

The logic is stronger, but the composition is stuck in an in-between state:

- `Current Task` still looks like a card that used to support a second focal element
- `Automation` is flatter, but still repeats the same state in too many ways
- `Next Moves` is meant to be the editorial payoff, yet it still arrives too low and with too little space

This pass should not be another cleanup pass. It should be a structural pass that compresses the top of the rail and gives the bottom of the rail more narrative weight.

The approved direction is `Compressed Editorial`.

## Goals

- Make the rail read in a clear three-step sequence:
  - what is in the active pass now
  - whether automation is in a healthy state
  - what the smartest next move is
- Remove visual dead space and leftover composition from the deleted progress ring.
- Reduce redundant system proofing in both `Current Task` and `Automation`.
- Reclaim vertical space so `Next Moves` can feel editorial instead of administrative.
- Tighten the semantic color system so accents mean state rather than decoration.

## Non-Goals

- No new right-rail module types.
- No ranking-model change for the unified `Next Moves` feed.
- No return to the old ring-based hero composition.
- No broad redesign of the center review workflow or left sidebar.

## Problem Statement

### Current Task

The hero is improved but still not recomposed after the ring removal.

- The top-right area now reads as dead air.
- The large pass count still pulls too much weight relative to the tightened semantics.
- The category shelf is too tall for the amount of information it contains.
- The shelf is semantically correct, but visually it still behaves like a large tray instead of a short summary band.

### Automation

The automation card is flatter than before, but still not sharp enough.

- The card repeats state in too many places: live badge, watched roots, waiting count, and metric shelf.
- The split `Scan now` control is louder than the state it is meant to support.
- Permanent zero-value metric proofing wastes vertical space and weakens the beacon feeling.

### Next Moves

The `Next Moves` feed is structurally better than the earlier versions, but it still does not receive enough space or emphasis.

- The featured recommendation is too far down the rail.
- Too much height is spent on quiet chrome in the first two modules.
- The editorial copy has improved, but the section still does not feel like the payoff.

## Approved Direction

Use a compressed editorial right rail:

- compress the top two modules by roughly `20-25%`
- remove redundant metric proofing and zero-state structure
- let `Next Moves` absorb the reclaimed vertical space
- keep the calm, premium, Apple-adjacent restraint
- sharpen hierarchy through composition, not louder styling

This is a refinement of the existing editorial mission-control direction, not a new visual reset.

## Considered Approaches

### 1. Compressed Editorial

Tighten `Current Task` and `Automation`, remove redundant metrics, and let `Next Moves` become the editorial center of gravity.

Why this is chosen:

- preserves the approved right-rail architecture
- fixes the dead-space and redundancy problems directly
- improves hierarchy without turning the rail into an operations dashboard

### 2. Hero + Feed

Push most of the visual emphasis into `Current Task` and collapse `Automation` into a thin status strip.

Why not:

- makes automation too easy to ignore
- undercuts the trust-beacon role that the right rail still needs

### 3. System Dashboard

Keep all three modules data-rich, but compress them into denser operational bands.

Why not:

- too administrative for the approved editorial direction
- would solve information density at the expense of warmth and pacing

## Layout Contract

The rail keeps the same three-module order:

1. `Current Task`
2. `Automation`
3. `Next Moves`

The change is in relative height and emphasis.

### Height Allocation

- `Current Task` should become visibly shorter than the current v3 implementation.
- `Automation` should become a concise beacon card rather than a mini-dashboard.
- `Next Moves` should become the largest information-bearing module in the rail whenever there is at least one featured recommendation.

The rail should feel top-compressed and bottom-open, not evenly padded from top to bottom.

## Current Task Contract

### Intent

`Current Task` should answer one question cleanly:

> What is in the active pass right now?

It should not try to tell the same progress story three ways.

### Structure

The hero should use this order:

1. section label
2. reduced pass count
3. task title
4. one pass-scoped summary sentence
5. one linear progress row
6. compact category footer band

### Count

- Keep the large pass count.
- Reduce it again so it leads without overpowering the card.
- Target scale: approximately `30-32pt` visual feel in compact right-rail conditions, while still adapting to the existing width classes.

### Title and Summary

The title remains the semantic task label, such as:

- `Images in This Pass`
- `Stale Files in This Pass`
- `Files in This Pass`

The support line should become tighter and semantically exact. Example direction:

- `8 files in this pass. Mostly images. 61 wait outside this pass.`

Rules:

- always lead with the pass
- if dominant composition exists, say it in the second sentence fragment
- if hidden backlog exists, describe it as being outside the pass rather than behind the pass

### Progress

Keep one progress treatment only.

Rules:

- no ring
- one linear progress bar
- `PASS PROGRESS` label on the left
- exact count text on the right, such as `0 of 8 organized`
- no second percent expression in the same card

### Category Footer Band

The category shelf remains, but changes role.

Rules:

- it is a short footer band, not a large stat tray
- three equal columns
- fixed equal height
- full-height dividers
- no inner mini-cards
- category labels must stay single-line
- visual emphasis comes from typography first, color second

Example shape:

- `4 Images | 3 Documents | 1 Archive`

The band should read as a compact summary of the active pass composition.

### Semantic Source Of Truth

All hero numbers remain fully pass-scoped.

Rules:

- pass count, progress denominator, and category composition all describe the active review pass only
- no hero metric should drift based on broader filtered analytics outside the current pass snapshot

## Automation Contract

### Intent

`Automation` should answer one question cleanly:

> Is the system in a trustworthy state right now?

It should feel like a beacon, not a dashboard with proof-of-work tiles.

### Structure

The card should reduce to:

1. section label + `Live` state chip
2. watched-root headline
3. primary waiting-state line
4. one optional secondary support line when meaningful
5. full-width split footer control

### Content Rules

Required:

- watched roots, for example `Watching Desktop + Downloads`
- one strong system-state line, for example `69 files waiting for review`

Optional:

- one secondary support line only when it communicates meaningful state
- examples:
  - `2 folders on autopilot`
  - `1 folder blocked`

Not allowed:

- builder-language helper copy
- always-on zero-value metric shelves
- repeating the same count in multiple stacked treatments

### Split Control

Keep the split control, but reduce its dominance.

Rules:

- keep the wide `Scan now` segment and narrow `Pause/Resume` segment
- use a quieter surface treatment
- blue should act as emphasis, not as a heavy filled slab
- the system state must remain more visually important than the control itself

## Next Moves Contract

### Intent

`Next Moves` should become the editorial payoff of the rail.

It should answer:

> What is the most consequential action I can take next?

### Structure

The section stays a unified ranked feed with featured-first ordering, but the featured card gets more breathing room and narrative clarity.

Featured card structure:

1. quiet provenance / motif
2. stronger headline
3. `2-3` lines of consequence text
4. `Why it matters` line
5. pinned footer CTA with divider above it

Secondary cards keep the same model in a compressed form.

### Footer CTA

The explicit action remains in the footer row, not on the headline line.

Rules:

- keep the full card tappable
- keep the footer CTA visually clear
- let the title and body copy use full width without competing with a top-right action

### Space Priority

The section should receive the vertical space reclaimed from the first two cards.

The featured recommendation should be the first place in the rail where the UI feels editorial rather than administrative.

## Color Discipline

The right rail should use one small semantic palette:

- blue = progress and primary guidance
- sage = live, healthy, confirmed-ready
- orange = blocked, needs setup, missing destination
- red = actual failure only
- neutral gray = structure, metadata, passive dividers

Rules:

- category color is a secondary cue only
- category hue must not compete with semantic state meaning
- automation and hero accents should read as stateful, not decorative

## Copy Posture

The rail should sound shorter, more declarative, and less system-authored.

Rules:

- say the important thing first
- avoid explanatory filler when one confident sentence will do
- avoid internal-builder language such as `active scopes`
- prefer human-readable nouns with concrete units

## Accessibility And Resize Expectations

- compact and regular right-panel widths must preserve the same hierarchy
- the category footer band must remain equal-height across widths
- the automation card must not rely on color alone to communicate state
- footer CTAs in `Next Moves` must remain keyboard and VoiceOver clear
- the compressed layout must still tolerate longer titles and support lines without creating visual holes

## Acceptance Criteria

- `Current Task` no longer contains obvious leftover empty space from the deleted ring layout.
- The pass count is visibly reduced relative to v3.
- The hero uses exactly one progress treatment.
- The hero category footer reads as a compact summary band, not a large tray.
- `Automation` does not permanently render redundant zero-value proofing.
- The automation split control is quieter than the system state content.
- `Next Moves` is visually more prominent because of reclaimed vertical space, not because of louder styling.
- The featured recommendation has enough room to feel like a briefing, not a tile.
- The rail uses a smaller semantic accent system and no longer mixes decorative category color with state color in competing ways.

## Implementation Boundary

This spec is a layout and presentation refinement of the existing editorial mission-control work.

It should primarily affect:

- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Components/AutomationStatusWidget.swift`
- the existing editorial suggestion card composition inside the default right rail

It does not require a new recommendation model or a new panel architecture.
