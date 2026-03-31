# Forma Website Header Shell Design

**Date:** 2026-03-31

## Goal

Fix the marketing-site header so it feels like a floating part of the hero instead of a full-width bar sitting above it.

The first viewport should read as one composition:

- a light floating navigation shell
- a clear hero text block
- the product window as the dominant visual anchor

## Context

- The current header in `forma-website/src/components/Header.tsx` renders inside a full-width top bar with a border and background.
- The home hero in `forma-website/src/app/page.tsx` begins immediately below that bar and adds its own border treatment.
- In practice, this creates a stacked horizontal-divider effect that makes the first screen feel segmented instead of composed.
- The user wants the header to feel floating and integrated with the hero, and to remain light rather than turning into a heavier sticky state on scroll.

## Problem Statement

The issue is not the inner shell card itself.

The problem is the outer header container:

- it occupies its own full-width band
- it creates a hard top-of-page divider
- it visually detaches the navigation from the hero
- it spends too much viewport budget before the headline and product visual begin

## Approved Direction

Use a floating overlay header.

The header should stop behaving like a page section and start behaving like a lightweight shell layered over the hero. The inner shell remains the visual object; the outer full-width bar disappears.

Approved product decisions:

- remove the outer header border/background treatment
- overlay the header shell near the top of the hero
- add enough top offset to the hero so the headline does not collide with the shell
- keep the current navigation pill, CTA, and mobile sheet structure
- keep the floating shell light and translucent as the page scrolls
- do not add a heavier scroll-state transformation for this pass

## Considered Approaches

### 1. Floating overlay header

Make the shell sit over the hero and remove the outer bar entirely.

Why this is chosen:

- best matches the user's stated preference
- gives the first viewport a cleaner single-composition feel
- preserves the current shell design while fixing the layout relationship around it

### 2. Transparent in-flow header

Keep the header in normal flow but remove the background and border from the outer element.

Why not:

- lower risk, but still spends vertical space before the hero begins
- still feels more stacked than composed

### 3. Scroll-reactive header

Start minimal, then tighten or solidify on scroll.

Why not:

- more moving parts than needed for the current problem
- the user explicitly preferred keeping it light rather than transitioning to a heavier sticky shell

## Layout Design

### Header Positioning

- The header shell should sit above the hero content, not push it down as a separate section.
- The outer header wrapper should become transparent and non-segmenting.
- The header shell should keep a centered max-width aligned with the site container.
- Vertical offset should feel intentional on desktop and mobile, with enough breathing room above the shell.

### Hero Relationship

- The hero needs additional top padding to account for the overlaid shell.
- The shell and hero should feel designed together rather than stacked.
- The product window should remain the dominant visual object, not the header.
- The headline should still land in the first viewport at common laptop widths.

### Scroll Behavior

- Keep the shell visible as the page scrolls.
- Preserve a light, translucent material language.
- Avoid large shrink, color-flip, or solidification transitions.
- Small polish adjustments on scroll are acceptable only if they support legibility without changing the overall visual weight.

## Responsive Behavior

### Desktop

- The floating shell should read as one crisp object above the hero.
- The hero plus header should still fit comfortably within the initial viewport on common desktop sizes.
- The shell should not create a second visual frame competing with the hero window.

### Mobile

- The shell should remain compact and avoid consuming too much of the first screen.
- The mobile menu trigger remains part of the same floating shell.
- The mobile sheet interaction remains unchanged.
- Hero top spacing must be tuned so the headline and CTA do not start too low.

## Non-Goals

This pass does not:

- redesign the nav links
- change copy
- rework the hero composition itself
- add new scroll-state choreography
- change the mobile sheet IA

## Affected Areas

- `forma-website/src/components/Header.tsx`
- `forma-website/src/app/page.tsx`
- potentially shared shell spacing or token usage if small supporting adjustments are needed

## Validation

Verify:

- the header no longer renders as a full-width band
- the first viewport feels like one composition
- the headline remains visible and balanced beneath the shell
- mobile spacing remains usable
- no regressions to keyboard focus, nav links, CTA, or sheet behavior

## Implementation Notes

- Favor layout and shell treatment changes over component redesign.
- Preserve existing accessibility attributes and navigation structure.
- If sticky positioning is used, it should support the floating-shell illusion rather than reintroduce a hard bar at the top of the page.
