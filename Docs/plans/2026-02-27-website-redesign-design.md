# Forma Website Redesign — Design Document

**Date:** 2026-02-27
**Status:** Draft (pending approval)
**Direction:** C+ ("Honest Utility" with B-style feature presentation)

---

## 1. Design Direction

Direction C ("Honest Utility") was chosen for its no-nonsense, utility-first aesthetic. Direction B's feature card layout (full-width alternating cards with copy + demo panels) was grafted in for deeper product storytelling. The result: a page that feels honest and functional without sacrificing visual depth.

### Visual Personality
- Confident utility — not flashy, not sterile.
- Let the product speak through real UI, not abstract illustrations.
- One strong visual opinion: the product itself (rule builder, file sort animation, undo timeline) is the hero image, the illustration, the ornament. No stock photos, no icons-as-features.

---

## 2. Page Architecture

Current section order (preserved unless noted):

```
1. Hero                    — tagline + CTA + file sort animation
2. CredibilityStrip        — trust signals strip
3. FeaturesSection         — 4 full-width feature cards with demos
4. BeforeAfterSection      — before/after transformation
5. SocialProofSection      — "How Forma works" principles (placeholder for testimonials)
6. PricingSection          — $29 once
7. FAQSection              — accordion
8. Guides                  — blog links (inline in page.tsx)
9. NewsletterSection       — email capture
10. Footer
```

### Structural changes from review feedback

| Change | Rationale |
|--------|-----------|
| **Add mid-page CTA** after BeforeAfterSection | Conversion: capture high-intent users after the transformation moment |
| **Remove "See how it works" secondary CTA** from hero | Conversion: secondary CTA dilutes primary download action |
| **Move Guides section** below FAQ or into footer | Conversion: guides are SEO content, not conversion funnel |
| **Surface pricing earlier** — add small "$29 once" badge near hero CTA | Conversion: price anchoring reduces friction on a $29 impulse purchase |

---

## 3. Typography

### Current (keeping)
- **Display:** Instrument Serif (via `--font-display`)
- **Body:** DM Sans (via `--font-body`)
- **Mono:** JetBrains Mono (via `--font-mono`)

### Rationale
The design review criticized Inter 600 (Direction C mockup), but the live site already uses Instrument Serif for display — a strong editorial choice with real personality. DM Sans for body is clean and legible. This stack already has more character than the mockup suggested. No font changes needed.

### Hierarchy adjustments
- Feature card headings: keep `font-display` (Instrument Serif), ensure they read as display weight not UI weight.
- Section labels: mono uppercase at 11px tracking-wide — already in place, works well with the utility aesthetic.

---

## 4. Color System

### Current palette (dark-mode-first, light-mode overrides)
The site uses CSS custom properties with semantic tokens. Base brand colors:

| Token | Hex | Role |
|-------|-----|------|
| `--forma-obsidian` | #1A1A1A | Primary dark |
| `--forma-bone` | #FAFAF8 | Primary light |
| `--forma-steel-blue` | #4A6B88 | Primary accent |
| `--forma-sage` | #6B8F71 | Secondary accent |
| `--forma-muted-blue` | #6B7FA8 | Tertiary accent |
| `--forma-warm-orange` | #B86B52 | Warning/undo accent |

### Accessibility fixes (from review)

These changes apply to semantic tokens, not brand colors:

| Token | Current | Proposed | Context |
|-------|---------|----------|---------|
| `--text-secondary` (light) | `rgba(26,26,26,0.65)` | `rgba(26,26,26,0.72)` | Body text — push toward 5:1 on bone |
| `--text-muted` (light) | `rgba(26,26,26,0.62)` | `rgba(26,26,26,0.58)` | Already passes 4.5:1 on #FAFAF8 — verify |
| Feature accent labels on `--bg-secondary` | ~2.5-2.8:1 | Ensure 4.5:1 | Use darker shade of each accent for text |
| Minimum text size | 10px in some places | 12px floor | Per WCAG guidance |

**Note:** The dark mode tokens are already contrast-safe (white on dark backgrounds). The fixes above target light mode only.

---

## 5. Spacing & Layout

### Current
- Section padding: `py-10 md:py-16` (small), `py-14 md:py-24` (large)
- Feature card gap: needs increase from 12px to 20-24px
- Site container: max-width 1160px, inline padding `clamp(1.5rem, 4vw, 3.25rem)`

### Adjustments
- Feature card gap: `gap-4` (16px) to `gap-6` (24px) for breathing room between full-width cards
- Hero showcase top margin: slightly reduce on desktop to pull the file sort animation closer to the CTA

---

## 6. Animation Specifications

All animations respect `prefers-reduced-motion: reduce` — the site already has a comprehensive reduced-motion media query in globals.css.

### 6.1 Hero Entrance (existing, refine)
- **Headline:** TextReveal component with word-stagger (already in place)
- **Subtitle:** Fade-up, 600ms, ease `formaReveal`, delay 0.55s after headline
- **CTA buttons:** Fade-up, 600ms, stagger 0.5 overlap
- **Meta line:** Fade-in only, 400ms

### 6.2 Feature Cards — Scroll-triggered reveal
- **Trigger:** `ScrollReveal` component, threshold 85%
- **Animation:** `forma-settle` — translateY(12px) + scale(0.98) to rest
- **Duration:** 500ms per card
- **Stagger:** 120ms between cards (already `stagger={0.1}`)
- **Demo panel:** Content within each demo area animates 200ms after the card settles

### 6.3 CTA Button States
- **Idle:** Resting state with `shadow-lg`
- **Hover:** `translateY(-1px)`, shadow expands to `shadow-xl`, bg shifts to `--cta-bg-hover`
- **Active:** `translateY(0)`, shadow returns — snap back
- **Transition:** 300ms on all properties (already in place)

### 6.4 Feature Card Hover (new)
- **Trigger:** Mouse enter on `.feature-card`
- **Effect:** Border color shifts from `--border-medium` to `--border-strong`, subtle translateY(-2px) lift, shadow deepens slightly
- **Duration:** 250ms ease-out
- **Scope:** Desktop only (pointer: fine)

### 6.5 Section Divider Reveal (new)
- **Element:** Thin horizontal rule between major sections (the `<SectionTransition>` components)
- **Animation:** Width draws from 0% to 100%, left-to-right
- **Duration:** 800ms, ease `cubic-bezier(0.16, 1, 0.3, 1)`
- **Trigger:** Scroll intersection, once

### 6.6 Pricing CountUp (new)
- **Element:** "$29" in PricingSection
- **Animation:** Counts from $0 to $29 when section enters viewport
- **Duration:** 800ms
- **Easing:** Decelerate — fast start, slow finish
- **Trigger:** IntersectionObserver, once

---

## 7. Conversion Improvements

### 7.1 Remove secondary hero CTA
Kill "See how it works" button. Single primary CTA: "Download for Mac".

### 7.2 Price badge in hero
Add "$29 once" as a small pill/badge near or below the primary CTA, not as muted meta text. Make it visible and confident.

### 7.3 Mid-page CTA after Before/After
After BeforeAfterSection, add a simple centered CTA block:
```
Ready to clean up?
[Download for Mac]
```
Re-use the primary CTA component. No new section — just a small interstitial.

### 7.4 Move Guides to footer area
Move the guides links section below the newsletter or integrate into the footer. It's valuable for SEO but not part of the conversion funnel.

### 7.5 Social proof (future)
The SocialProofSection currently shows "How Forma works" principles as a placeholder. When real testimonials, download counts, or review scores are available, swap this section to genuine social proof.

---

## 8. Accessibility Checklist

Items the implementation must address:

- [ ] Fix light-mode contrast ratios per Section 4
- [ ] Ensure all feature accent text on card backgrounds meets 4.5:1
- [ ] Set 12px minimum text size floor (audit all `text-[10px]` and `text-[11px]` usages)
- [ ] Verify `prefers-reduced-motion` coverage for any new animations (countup, section divider reveal, feature card hover)
- [ ] Focus indicators already present via `focus-visible` styles — verify they work on new CTA elements
- [ ] Skip navigation link already present — verify it targets `#top`

---

## 9. Files to Modify

| File | Changes |
|------|---------|
| `globals.css` | Light-mode contrast fixes, feature card hover styles, section divider animation keyframes |
| `HeroSection.tsx` | Remove "See how it works" CTA, add price badge, adjust showcase spacing |
| `FeaturesSection.tsx` | Increase card gap, add hover effect class, adjust demo animation timing |
| `BeforeAfterSection.tsx` | Add mid-page CTA block after section content |
| `PricingSection.tsx` | Add CountUp animation to price display |
| `page.tsx` | Move Guides section below Newsletter or into Footer |
| `Footer.tsx` | Potentially absorb Guides links |

### New files (if needed)
| File | Purpose |
|------|---------|
| `components/animation/CountUp.tsx` | Animated number counter for pricing |
| `components/ui/MidPageCTA.tsx` | Reusable mid-page CTA block (optional — could be inline) |

---

## 10. What This Design Does NOT Change

- Overall dark-mode-first approach
- Font stack (Instrument Serif / DM Sans / JetBrains Mono)
- Brand color palette
- Existing animation infrastructure (GSAP, ScrollScene, ScrollReveal, TextReveal)
- Site container width and responsive breakpoints
- FAQ, Newsletter, Footer structure
- Blog/guides content
