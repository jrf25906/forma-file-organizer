# Website Dark-Mode Hero Design

**Date:** 2026-03-23

## Goal

Make the marketing-site hero and the "How Forma Works" section read correctly in dark mode without changing the current screenshot-style hero composition.

## Context

- The website already resolves light/dark mode through `data-theme`.
- `forma-website/src/components/sections/FormaHeroWindow.tsx` is visually composed like a screenshot, but it hardcodes a light-mode palette in inline styles.
- `forma-website/src/app/page.tsx` renders the "How Forma Works" section on a pale translucent surface that looks washed out on dark pages.

## Design

### Hero

- Keep the existing hero layout, copy, spacing, and overall screenshot-style composition.
- Refactor the hero window to read from shared semantic tokens instead of a light-only palette.
- Make the dark hero feel native to a dark macOS environment rather than like an inverted light screenshot.
- Preserve the current light-mode appearance as closely as possible.

### How Forma Works

- Keep the current two-column structure and sticky intro.
- Replace the pale translucent background with a proper theme-aware section surface.
- Tighten dark-mode hierarchy through contrast, spacing, and step-emphasis adjustments only.
- Do not rewrite copy or reorder steps.

## Non-Goals

- No new section order.
- No hero composition redesign.
- No content rewrite.
- No new theme toggle UI.

## Implementation Notes

- Introduce shared hero-window semantic tokens in website code so theme values are centralized.
- Define token values in global CSS for dark and light themes.
- Update the hero component to consume those tokens rather than hardcoded light-only RGBA values.
- Adjust the "How Forma Works" section styles in `page.tsx` and supporting CSS tokens as needed.

## Verification

- Run `npm run lint` in `forma-website`.
- Run `npm run build` in `forma-website`.
