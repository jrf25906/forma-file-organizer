# Forma Website Editorial Redesign Design

**Date:** 2026-04-20

## Goal

Redesign the entire `forma-website/` marketing site so it feels more deliberate, memorable, and premium without turning it into a generic startup page or disconnecting it from the product shell that already works.

The finished site should:

- feel visibly redesigned at the whole-site level, not just polished
- keep the core product promise and trust-first messaging intact
- use stronger editorial composition across the page canvas while preserving the dark product shell as the hero object
- reduce visual and runtime noise from the current heavier atmospheric treatments
- carry the new system across homepage and secondary routes so the redesign reads as one site

## Context

- The site already has strong positioning and a recognizable product shell language in `forma-website/src/app/page.tsx`, `src/components/Header.tsx`, `src/components/Footer.tsx`, `src/components/ui/forma-shell-card.tsx`, and `src/components/ui/forma-shell-cta.tsx`.
- The current system is built on a dark, glass-heavy token layer in `forma-website/src/app/globals.css` and `src/app/layout.tsx`.
- The homepage combines that shell with a more expensive runtime layer, especially `src/components/effects/ScrollDrivenTornado.tsx`, plus several animated or hover-reactive sections.
- Secondary routes such as blog, support, legal, and `for-agents` currently inherit pieces of the shell but often fall back to simpler dark-section compositions rather than a distinct site-wide design language.
- The user requested a full-site pass using these skills in spirit and in order:
  - `/ui-ux-pro-max-skill` which is not installed here, so `design-taste-frontend` is the closest substitute
  - `make-interfaces-feel-better`
  - `interface-craft`
  - `simplify`

## Problem Statement

The current site has a recognizable voice, but it is visually compressed into one dominant mode:

- dark background
- glass shells
- soft borders
- atmospheric motion
- centered or near-centered feature framing in several sections

That creates three problems:

1. The homepage can feel like one continuous dark treatment instead of a paced editorial story with strong shifts in hierarchy.
2. The product shell sometimes competes with the page shell. The product window, header shell, feature cards, and section bands are all speaking with similar visual weight.
3. The runtime layer is more active than it needs to be, especially in the hero. The site spends too much attention budget on ambient motion instead of using motion to sharpen hierarchy.

The redesign problem is therefore not "make the site prettier."

It is:

- give the site a stronger page-level visual identity
- preserve the product shell as the trusted object on the page
- make sections feel more intentional and easier to scan
- reduce unnecessary motion and treatment cost without flattening the brand

## Approved Direction

Use a controlled version of the statement redesign direction.

This is not a full aesthetic reset. It is a stronger editorial redesign built around contrast between the page canvas and the product shell.

Approved product decisions:

- move the page canvas toward warm light editorial surfaces
- keep dark product and shell surfaces as intentional anchors
- use larger, left-aligned, more asymmetrical section compositions
- replace broad atmospheric motion with staged, purposeful motion
- preserve the current product story, route structure, and trust-first copy spine unless a layout change clearly requires a copy adjustment
- carry the redesign through homepage and secondary routes instead of leaving support/legal/blog as fallback templates

## Considered Approaches

### 1. Restrained refinement

Keep the current dark shell system and mainly sharpen type, spacing, borders, and motion restraint.

Why not:

- too subtle for a whole-site redesign brief
- would feel like careful polish rather than a new visual chapter
- would leave the page canvas and product shell too visually similar

### 2. Hybrid editorial product

Move toward lighter page surfaces while keeping the product shell premium and dark.

Why not:

- closest to the final answer, but not strong enough for the chosen direction
- still leaves the redesign slightly too cautious at the section-composition level

### 3. Controlled statement redesign

Use a warmer editorial canvas, stronger section asymmetry, more dramatic typography, and clearer contrast between storytelling zones and product surfaces.

Why this is chosen:

- best fits the user's "somewhere in between" answer after the visual comparison
- creates a clear redesign without abandoning the current product shell language
- gives the site a more memorable shape while still allowing conservative implementation decisions around motion and shared primitives

## Current System Touchpoints

The redesign is anchored in these files and surfaces:

- token and layout backbone:
  - `forma-website/src/app/layout.tsx`
  - `forma-website/src/app/globals.css`
- homepage:
  - `forma-website/src/app/page.tsx`
  - `forma-website/src/components/sections/FormaHeroWindow.tsx`
  - `forma-website/src/components/sections/FeaturesBento.tsx`
  - `forma-website/src/components/sections/UseCasesBento.tsx`
  - `forma-website/src/components/sections/FormaBeforeAfter.tsx`
  - `forma-website/src/components/sections/FAQSection.tsx`
  - `forma-website/src/components/effects/ScrollDrivenTornado.tsx`
- shared shell and primitives:
  - `forma-website/src/components/Header.tsx`
  - `forma-website/src/components/Footer.tsx`
  - `forma-website/src/components/ui/forma-shell-card.tsx`
  - `forma-website/src/components/ui/forma-shell-cta.tsx`
  - `forma-website/src/components/ui/forma-shell-section-heading.tsx`
- secondary routes:
  - `forma-website/src/app/blog/page.tsx`
  - `forma-website/src/app/blog/[slug]/page.tsx`
  - `forma-website/src/app/support/page.tsx`
  - `forma-website/src/app/privacy/page.tsx`
  - `forma-website/src/app/terms/page.tsx`
  - `forma-website/src/app/for-agents/page.tsx`
  - `forma-website/src/components/legal/LegalPageShell.tsx`

## Design Intent

Forma should feel calmer, more distinct, and more authored.

The site should not read like a dark SaaS landing page with decorative motion. It should feel closer to a premium editorial utility product:

- clear page rhythm
- more contrast between storytelling and product zones
- heavier reliance on type and layout for drama
- less reliance on glow, blur, and permanent animation

The emotional target is:

- understood
- reassured
- impressed
- not overwhelmed

## Visual System

### Page Canvas

The page canvas should move from near-uniform dark surfaces toward warm light editorial surfaces.

Rules:

- use warm, lightly textured or softly tinted light backgrounds as the default page canvas
- reserve the darkest surfaces for product shells, hero objects, and a few deliberate high-contrast anchors
- make section changes visible through composition and tonal shifts, not repeated card bands
- avoid turning every section into a bordered container

### Product Shell

The existing dark product-shell language remains important.

Rules:

- keep the floating header shell and hero app window as dark premium objects
- maintain the sense that the product itself is denser and more precise than the page around it
- preserve trust cues through clarity and crispness, not through more glass everywhere
- use the product shell as an anchor, not as the background mode for the entire site

### Typography

Typography needs to do more of the work.

Rules:

- replace `Inter` in `layout.tsx` with a sharper, less generic display/body pairing that is already supported through `next/font/google`
- keep a clean mono for code-like or system detail moments
- use larger left-aligned headlines and more distinct editorial line lengths
- reduce dependence on tiny all-caps labels as the main source of hierarchy
- apply balanced headline wrapping and prettier paragraph wrapping where appropriate

### Color and Accent

Color should feel disciplined and slightly warmer.

Rules:

- keep the palette rooted in Forma's existing neutral and muted accent language
- avoid generic AI-purple or neon gradients
- use one dominant accent family plus quiet support tones
- let warmth come from the page canvas and contrast, not oversaturated decorative color

### Surfaces and Borders

The surface system should feel more intentional and less foggy.

Rules:

- use fewer blurred glass panels as default section wrappers
- rely on subtle depth, cleaner outlines, and stronger tonal contrast
- keep concentric radii consistent between parent shells and nested controls
- shift some visual separation from borders into shadow, spacing, and background contrast

## Layout and Composition

### Whole-Site Composition

The redesign should break the one-mode page rhythm.

Rules:

- use more left-aligned and asymmetric section layouts
- avoid a repeated sequence of centered heading over dark rounded card over another dark section
- let some sections feel roomier and more editorial while others stay more compact and product-like
- preserve a strong single-column fallback on mobile

### Homepage

The homepage should remain the primary storytelling surface.

#### Hero

- keep the product shell and the core headline
- retain a left-copy and right-product structure
- let the page background around the hero feel more intentionally designed
- make the hero read as an authored composition, not a dark effect field with content placed on top

#### Features and Proof

- redesign the current bento and proof sections so they feel less like evenly weighted dark cards
- introduce stronger asymmetry, larger type moments, and clearer section separation
- preserve the preview-first and undo-first trust model as the core story spine

#### FAQ and Closing CTA

- keep these direct and readable
- let them inherit the new page system rather than feel like default dark utility blocks

### Secondary Routes

Secondary pages should inherit the redesign system without forcing drama where it does not help.

#### Blog Index and Blog Posts

- move these routes toward an editorial reading environment
- keep strong scanability for post lists and post metadata
- use the redesign to make articles feel more authored and less like dark cards in a stack

#### Support

- keep clarity first
- use the new system to make support feel thoughtful rather than merely decorated
- maintain direct access to the email CTA and quick-fix content

#### Legal

- legal pages should feel calmer and more readable, not more theatrical
- prioritize type rhythm, spacing, and section organization over strong asymmetry

#### For Agents

- keep the technical content structured and easy to scan
- apply the new design language through surface quality, typography, and spacing rather than decorative flourish

## Motion and Interaction Philosophy

Motion stays, but it becomes narrower and more useful.

### Motion Rules

- use motion to stage hierarchy, reveal sections, and support shell transitions
- avoid continuous atmospheric motion when it is not carrying meaning
- prefer transform and opacity-based motion with careful cleanup
- honor reduced-motion settings consistently

### ScrollDrivenTornado

`src/components/effects/ScrollDrivenTornado.tsx` is the main motion risk.

Approved direction:

- either substantially simplify and cheapen it, or replace it with a more controlled editorial background treatment
- do not preserve it purely because it is technically impressive
- the hero should feel sharper and calmer after the redesign than it does today

### Interface Craft Scope

The `interface-craft` pass should be narrow.

Use it for:

- storyboarded hero and section entrances
- any important shell or transition timing that benefits from named choreography

Do not use it for:

- decorative animation everywhere
- motion systems that make maintenance harder than the design payoff justifies

## Skill-to-Work Mapping

### `design-taste-frontend` as the substitute for `/ui-ux-pro-max-skill`

Use it to drive:

- the overall editorial direction
- typography choices
- asymmetrical section layouts
- the separation between page canvas and product shell

### `make-interfaces-feel-better`

Use it to enforce:

- concentric radius cleanup
- better shadow discipline
- press-state tactility
- balanced text wrapping
- clearer image and surface outlining
- more exact transition-property usage

### `interface-craft`

Use it to:

- refactor key motion into readable timing/storyboard structures where needed
- keep any retained animations understandable and tunable

### `simplify`

Use it after the visual work to:

- centralize duplicated styling
- reduce one-off utility noise
- consolidate tokens and shared section patterns
- make the stronger redesign cheaper to maintain than a pile of page-specific overrides

## Non-Goals

This redesign does not:

- change the site's content strategy or route map
- add new product claims or new marketing funnels
- redesign the product app window into a different fictional UI
- introduce a heavy illustration system unrelated to the real product
- add gratuitous animation for the sake of novelty
- widen scope into the native macOS app

## Affected Areas

Expected change clusters:

### Backbone

- `forma-website/src/app/layout.tsx`
- `forma-website/src/app/globals.css`

### Shared Shell

- `forma-website/src/components/Header.tsx`
- `forma-website/src/components/Footer.tsx`
- `forma-website/src/components/ui/forma-shell-card.tsx`
- `forma-website/src/components/ui/forma-shell-cta.tsx`
- `forma-website/src/components/ui/forma-shell-section-heading.tsx`

### Homepage

- `forma-website/src/app/page.tsx`
- relevant homepage sections under `src/components/sections/`
- hero background/effect treatment under `src/components/effects/`

### Secondary Routes

- blog index and post templates
- support
- legal shell
- `for-agents`

## Risks

- the redesign could drift into a visually louder brand language than Forma can support if asymmetry is used without restraint
- the site could become prettier but less coherent if shared primitives are not redesigned first
- the hero could regress in trust if the editorial background treatment starts competing with the product shell
- motion changes could reduce polish if the runtime-heavy pieces are removed without replacing them with a calmer but still intentional transition model
- secondary pages could feel under-designed if the new system only truly exists on the homepage

## Validation

Validate both presentation quality and restraint.

### Automated

Run in `forma-website/`:

- `npm run lint`
- `npm run test`
- `npm run build`

### Manual

Review at minimum:

- homepage
- blog index
- blog post
- support
- privacy
- terms
- for-agents

At:

- mobile width
- tablet width
- desktop width

Validate:

- the site feels like one redesign system
- the product shell stands out more clearly than before
- sections are easier to scan
- type is stronger and less generic
- motion is calmer and more intentional
- no route falls back to an obviously older visual language

## Success Criteria

The redesign is successful if:

1. the site feels clearly redesigned without losing the product's trust-first character
2. the page canvas and product shell are more distinct from each other
3. the hero and homepage spend less attention on ambient runtime spectacle and more on hierarchy
4. secondary routes inherit the new system cleanly
5. the final code is cleaner and more centralized than a page-by-page patchwork

## Implementation Philosophy

Implement from the system layer outward.

Recommended order:

1. redefine the backbone in `layout.tsx` and `globals.css`
2. update shared shell primitives
3. redesign homepage composition and hero treatment
4. carry the new system through secondary pages
5. simplify and centralize

This keeps the redesign coherent and prevents the implementation from degenerating into isolated page styling.
