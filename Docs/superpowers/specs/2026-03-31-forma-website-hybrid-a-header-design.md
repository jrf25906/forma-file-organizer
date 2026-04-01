# Forma Website Hybrid A Header Design

**Date:** 2026-03-31

## Goal

Replace the current always-formed floating header with a calmer two-state header that gives the hero first priority on page load and becomes more navigational once scrolling begins.

The approved direction is the `Hybrid A` concept:

- quiet top-of-page state
- compact split-nav sticky state after scroll
- stronger, warmer, more intentional light-mode shell treatment

## Context

The existing floating header solved the original full-width-bar problem, but it still fails in two important ways:

- it asks the header to do too much before the hero has landed
- it reads as a large floating object even when the user has not started navigating yet

In the current implementation:

- the shell is fixed from the start
- the nav treatment is already fully formed in the first viewport
- the shell remains visually prominent in light mode
- the result competes with the headline instead of framing it

The user feedback is clear:

- the layout still feels off
- the buttons are not reading clearly enough
- the color treatment feels wrong
- the header needs both better taste and better information hierarchy

## Problem Statement

The issue is no longer just “floating vs not floating.”

The issue is state and emphasis.

The current header uses one visual mode for two different jobs:

1. top-of-page brand framing
2. persistent navigation while scrolling

Those jobs should not look identical.

At the top of the page, the header should stay quiet and defer to the hero.
After the user begins scrolling, the header should become more explicit and more useful as navigation.

## Approved Direction

Use the `Hybrid A` header behavior.

### Initial Top State

At the top of the homepage:

- keep the floating shell
- keep the brand visible on the left
- keep the primary `Get Forma` action visible on the right
- do not show the full desktop nav links yet
- keep the shell visually lighter and quieter than the scrolled state

This state should feel like framing, not a control panel.

### Scrolled Sticky State

Once the user scrolls past a small threshold:

- transition the shell into a compact split-nav layout
- reveal the key desktop nav links
- keep the primary CTA visible
- maintain a compact height and strong readability

This state should feel clearly navigational, but still premium and restrained.

## Why Hybrid A Was Chosen

This direction combines the strongest qualities of the earlier explored options:

- from the minimal-header direction, it keeps the first viewport hero-first
- from the compact split-nav direction, it restores obvious usable navigation once the page becomes scroll-oriented

It best addresses the current failure mode:

- the header no longer dominates the first screen
- the sticky state still becomes genuinely useful
- the visual treatment remains premium without becoming decorative fog

## Rejected Alternatives

### 1. Keep the nav fully visible from the top

Why not:

- still competes with the hero in the first viewport
- keeps too much header mass active before navigation is needed
- does not resolve the user’s current complaint about buttons and layout hierarchy

### 2. Use only a minimal top state and never expand

Why not:

- too sparse once the user is deep into the page
- gives up useful in-page navigation on longer marketing screens
- leaves too much work to footer or manual scrolling

### 3. Quiet top state with a persistent menu affordance

Why not:

- viable, but still noisier than needed
- not as disciplined as Hybrid A
- introduces an extra control in the first viewport that does not feel necessary for the homepage

## Layout Design

### Shell Geometry

- The shell remains centered within the site container.
- The top state should be slightly slimmer and calmer than the current implementation.
- The scrolled state should stay compact, roughly in the same height family as the existing tuned shell, not taller.
- The shell should never become a full-width slab or a large empty capsule.

### Top-State Composition

- Left: Forma mark and wordmark
- Right: `Get Forma`
- Middle: no visible desktop nav links
- Mobile: keep a compact menu trigger available when needed, but do not let it visually overpower the CTA or the brand

### Scrolled-State Composition

- Left: Forma mark and wordmark
- Center: high-priority nav links only (`How it works`, `Pricing`, `Blog`)
- Right: `Get Forma`
- Keep the nav count intentionally short

## Visual Design

### Material

The shell should use a denser, more adaptive light-mode treatment than the current washed-out appearance.

Requirements:

- near-opaque warm-white surface in light mode
- subtle but visible border
- clear shadow separation from the hero
- enough contrast that controls remain legible over the moving background

The material should feel like a deliberate navigation layer, not a translucent blank overlay.

### Color

- Keep the Forma warm CTA color as the primary action accent.
- Keep the rest of the shell mostly neutral.
- Avoid over-tinting the entire shell.
- Do not use a cold or icy glass look; the page palette should stay warm and editorial.

### Hierarchy

- In the top state, the hero headline remains visually louder than the header.
- In the scrolled state, the shell becomes clearer but does not become heavier than the product window or CTA.
- The nav should feel present because of contrast and clarity, not because of size.

## Motion

The state change should be subtle and quick.

Allowed behaviors:

- fade or slide in the nav links
- slightly refine shell opacity/shadow on scroll
- keep the transition calm and premium

Not allowed:

- dramatic shrink animations
- strong color flips
- bouncy or playful motion
- large geometry morphs that call attention to the header

## Responsive Behavior

### Desktop

- top state should keep the hero feeling open
- scrolled state should clearly reveal navigation
- shell width should remain disciplined and not overextend horizontally

### Mobile

- keep the shell compact
- preserve the mobile menu sheet pattern
- top-of-page state should not consume too much vertical space
- CTA and menu trigger must remain individually legible and tappable

## Accessibility

- The sticky shell must not obscure focused elements.
- Internal anchors must still account for the sticky header offset.
- The stronger light-mode shell treatment must preserve contrast for text and controls.
- The motion between top state and scrolled state should remain subtle and not depend on motion for comprehension.

## Non-Goals

This pass does not:

- redesign the hero copy
- redesign the hero product window
- change marketing IA beyond the header itself
- introduce extra nav destinations
- redesign the mobile sheet contents

## Affected Areas

- `forma-website/src/components/Header.tsx`
- `forma-website/src/lib/header-shell-layout.ts`
- `forma-website/src/app/globals.css`
- homepage hero spacing only if needed to keep the first viewport balanced

## Validation

Verify:

- the top-of-page header feels quieter than the current implementation
- the first viewport makes the headline and product window feel primary
- the scrolled state exposes obvious usable navigation
- the `Get Forma` action remains clearly visible in both states
- light-mode contrast is strong enough that the shell no longer reads as a washed-out blocker
- mobile still feels compact and usable

## Implementation Notes

- Prefer a scroll-state class or stateful header mode over a full structural rewrite.
- The top-state and scrolled-state relationship should be encoded as one clear contract rather than one-off style exceptions.
- Preserve the existing accessibility labels, mobile sheet behavior, and tracked CTA behavior.
