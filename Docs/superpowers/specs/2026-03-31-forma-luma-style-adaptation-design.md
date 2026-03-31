# Forma Luma-Style Adaptation Design

**Date:** 2026-03-31

## Goal

Adopt the visual qualities the user likes from a modern soft, luminous shadcn-style preset while preserving Forma's distinct identity across both the marketing site and the native macOS app.

The end state should make:

- the website feel more premium, composed, and current
- the macOS app feel more refined and readable under load
- both products feel like the same brand without forcing them into the same component language

## Context

- The website in `forma-website/` already has a custom token system, custom motion, and bespoke product-demo surfaces.
- The native app in `Forma File Organizing/` already has a mature design system with semantic colors, spacing, typography, glass treatments, and native macOS layout patterns.
- The user likes the feel of a new shadcn-style aesthetic and wants to know what that would look like for Forma.
- The right question is not whether to transplant a web preset into both products. The real question is how to translate the visual principles into each surface without making either one generic.

## Current System Touchpoints

The current design work is anchored in these areas:

- Website token layer: `forma-website/src/app/globals.css`
- Website shared file-card/product-demo tokens: `forma-website/src/lib/forma-design-tokens.ts`
- Website hero app replica: `forma-website/src/components/sections/FormaHeroWindow.tsx`
- Native semantic color system: `Forma File Organizing/DesignSystem/FormaColors.swift`
- Native typography system: `Forma File Organizing/DesignSystem/FormaTypography.swift`
- Native control chrome and elevation language: `Forma File Organizing/DesignSystem/FormaControlChrome.swift`
- Native sidebar glass treatment: `Forma File Organizing/Components/SidebarGlassOverlay.swift`
- Native main surface composition: `Forma File Organizing/Views/MainContentView.swift`

## Recommendation

Use a split-adoption strategy.

- Apply a stronger style shift to the website through a custom shadcn preset and updated marketing primitives.
- Apply a lighter style shift to the macOS app through the existing Swift design system only.
- Keep the product-demo surfaces on the website custom.
- Keep the native app native.

This approach keeps the website visibly fresher without turning the app into a web-styled shell.

## Considered Approaches

### 1. Full transplant

Adopt the style everywhere, including app chrome and component patterns.

Why not:

- high risk of making the native app feel webby
- weakens Forma's current native utility character
- would force a large amount of visual churn with limited UX payoff

### 2. Token-only refresh

Slightly adjust colors, radii, and shadows without changing composition or component behavior.

Why not:

- low risk but too subtle
- would not deliver the visual shift the user is actually asking for

### 3. Split adoption

Use the visual logic across both products, but express it differently in each environment.

Why this is the chosen approach:

- strongest brand payoff for the least product risk
- lets the website become more premium without losing the bespoke product storytelling
- lets the app improve materially while staying recognizably macOS-native

## UX Intent

Forma should feel calmer, more expensive, and more trustworthy.

On the website, the style should communicate polish and confidence before the user reads deeply.

In the app, the style should improve clarity during actual file work. Under heavy file loads, the interface should feel more legible, more structured, and less visually mushy.

## Website Design

### Role of shadcn

Use shadcn as the marketing shell, not as the product visual identity.

shadcn should own commodity UI:

- header and mobile navigation
- pricing shell
- FAQ accordion
- newsletter and support forms
- dialogs, drawers, popovers, and generic buttons and inputs

shadcn should not own Forma's signature product surfaces:

- hero app replica
- before/after file demos
- any section meant to look like the real macOS product

### Visual Direction

The website should move toward:

- softer but still disciplined radii
- luminous low-contrast borders instead of heavier card outlines
- dark matte surfaces with restrained warm and cool accent bloom
- cleaner spacing between eyebrow, headline, body copy, and CTA
- calmer form styling with higher perceived quality

The website should not move toward:

- generic startup landing-page cards everywhere
- oversized pill controls
- brighter neon accents
- replacing the product-demo compositions with stock components

### Website System Rules

- Keep the current custom hero and demo sections as bespoke React components.
- Build a custom preset for reusable marketing primitives.
- Map the preset back into Forma's existing brand palette rather than importing a foreign color system.
- Use the preset to make the scaffolding feel more premium while preserving the site's existing content structure and product storytelling.

### Website Token Translation

The website preset should encode:

- radius defaults for controls and panels
- surface, border, and shadow hierarchy
- primary and secondary CTA treatment
- input and focus treatment
- spacing rhythm for marketing sections

The preset should translate Forma's palette into a more luminous shell, not replace it.

## Native App Design

### Role of the Style

The macOS app should borrow the visual logic only.

It should not attempt to mimic web components, shadcn component structure, or web-style spacing density.

### App UX Intent

- make the dashboard feel calmer under large file sets
- improve scannability in list, card, and grid views
- make hover, focus, and selection easier to parse instantly
- raise perceived quality through depth and material refinement rather than decoration

### Layout and Interaction Proposal

- Keep existing native layout patterns such as sidebar/content/inspector structure.
- Preserve current compact information density for file work.
- Clarify the elevation ladder between background, sidebar glass, content region, file surface, floating action surface, and inspector cards.
- Make toolbar chrome feel tighter and more machined, with less visual ambiguity between background and control.
- Make file surfaces across card, list, and grid feel like one system expressed at three densities.

### Component and State Specification

Define a shared file-surface visual system for:

- rest
- hover
- selected
- focused
- pending
- processing
- error

Expected behavior:

- hover uses a brighter inner edge and clearer border, not a large fill jump
- selected uses restrained steel-blue tint plus a sharper selected border
- focused is more visible than selected and clearly keyboard-driven
- metadata text gains slightly more contrast on dark surfaces
- primary actions remain compact and native
- inspector cards and floating bars inherit the same elevation language as file rows

### App System Rules

- Implement the refresh through the existing Swift design system.
- Avoid web-style oversized radius, extra-large card padding, or pill-heavy controls.
- Keep SF Pro and the current typography scale.
- Preserve current brand accents: steel blue, sage, and muted category colors.

## Shared Brand System

The website and app should converge on a shared visual philosophy:

- matte base surfaces
- soft glass overlays where appropriate
- luminous edge highlights
- restrained accent color
- clearer selection language

They should diverge on density and component expression:

- website: roomier, more atmospheric, more editorial
- app: tighter, more native, more task-oriented

## Implementation Sequence

### Phase 1: Website preset definition

- define a Forma-specific shadcn preset for marketing primitives
- encode radius, border, shadow, focus, and CTA defaults
- align it with existing website tokens rather than replacing the token layer wholesale

### Phase 2: Website primitive pass

- update navigation
- update reusable buttons, inputs, sheets, and popovers
- refit pricing shell, FAQ accordion, and forms
- target the shared marketing shell first so the homepage can adopt the new mood without disturbing product demos

### Phase 3: Website integration pass

- integrate the new primitives into the homepage and support pages
- preserve bespoke product-demo sections and tune them so they still harmonize with the refreshed shell

### Phase 4: Native token refinement

- refine elevation, borders, highlight opacity, and dark-surface text contrast in the Swift design system
- tune shared chrome primitives before changing surface-specific views
- keep changes centered in the design-system layer before touching many call sites

### Phase 5: Native file-surface pass

- refresh file surfaces across:
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/MainContentView.swift`
- ensure list, grid, and card states remain visually parallel

### Phase 6: Native chrome pass

- apply the same elevation language to inspector cards, floating action surfaces, and toolbar chrome

### Phase 7: Validation pass

- verify keyboard focus visibility
- verify contrast in light and dark mode
- verify long filenames and mixed metadata remain scannable
- verify resize extremes and dense-file scenarios

## Risks

- The website could become prettier but more generic if bespoke sections are replaced with stock components.
- The app could become less native if padding, radius, or CTA treatment drifts toward web conventions.
- The two products could diverge if the website preset and app token changes are not mapped deliberately.
- Dense file views could lose scannability if softness is overemphasized.

## Non-Goals

- No full redesign of the information architecture.
- No rewrite of homepage copy.
- No replacement of bespoke website product demos with generic UI.
- No move toward a shared cross-platform component library.
- No abandonment of native macOS interaction conventions.

## Success Criteria

- The website feels more premium within the first screenful.
- The app feels cleaner and more legible within the first minute of use.
- Hover, selection, and focus states become easier to parse.
- The two products feel more coherent without becoming visually identical.
- Forma still looks like Forma rather than a generic shadcn implementation.

## Validation

Design validation should include:

- visual inspection of key website pages and the homepage shell
- native app review across sidebar, main file surfaces, floating bars, and inspector
- light and dark mode comparison
- keyboard-focus review
- resize and dense-content review
