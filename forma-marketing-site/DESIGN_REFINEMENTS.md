# Forma Marketing Site — Design Refinements Plan

> Living document for tracking design improvements and adjustments

---

## Overview

The current implementation has a solid foundation with GSAP animations, Lenis smooth scroll, and a coherent visual language. This document outlines refinements to elevate the experience from "good" to "exceptional."

---

## 0. Navigation & Header — Priority: HIGH ⚠️ NEW

### Current State

No persistent navigation exists. Users landing on the page have no way to:
- Understand what Forma is at a glance
- Jump to specific sections
- Access the CTA without scrolling

### Proposed Changes

- [ ] **Add minimal sticky header** — Logo + single CTA button
- [ ] **Section jump links** — Optional nav items for Features, Testimonials, etc.
- [ ] **Scroll-aware styling** — Header becomes more opaque after hero section
- [ ] **Mobile hamburger** — Collapsed nav for touch devices

### Implementation Notes

```tsx
// Minimal header structure
<header className="fixed top-0 inset-x-0 z-50 transition-colors">
  <nav className="flex items-center justify-between px-6 py-4">
    <Logo />
    <Button variant="primary" size="sm">Join the Beta</Button>
  </nav>
</header>
```

Consider: Does the scrollytelling hero need the full viewport, or can a slim header coexist?

---

## 1. Hero Section (Scrollytelling) — Priority: HIGH

### Core Problem: "Show, Don't Tell" Failure

The narrative follows four beats: **Chaos → Recognition → Organization → Resolution**

The text promises intelligence ("Forma sees the patterns"), but the visuals only deliver simple motion. Users don't see *why* files are being grouped — they just see them moving.

### Beat-by-Beat Analysis

#### Beat 1: "Chaos" (0%–22%) — Not Chaotic Enough

| Issue | Current State | Target State |
|-------|---------------|--------------|
| File positions | Hardcoded, relatively neat | Overlapping, messy, like a real cluttered desktop |
| Visual stress | Calm, organized scatter | Uncomfortable disorder that makes "After" feel like relief |

**Fix:** Increase overlap in `chaosX/Y` coordinates. Make it look painful.

#### Beat 2: "Recognition" (22%–48%) — THE WEAK LINK

| Issue | Current State | Target State |
|-------|---------------|--------------|
| Visual communication | Files pulse/glow sequentially (`scanIntensity`) | Visible connection lines between related files |
| Intelligence signal | Looks like generic "antivirus scanning" | Shows the "invisible threads" Forma sees |

**Fix:** Draw SVG bezier curves connecting related files *before* they move:
- Connect `Screenshot 2024...` to `IMG_4291.jpg`
- Connect `proposal_FINAL` to `notes_meeting`
- Lines should fade in during recognition phase, then fade out as organization begins

#### Beat 3: "Organization" (48%–78%) — Feels Robotic

| Issue | Current State | Target State |
|-------|---------------|--------------|
| Motion | Linear interpolation: `start + (end - start) * progress` | Staggered, organic movement with overshoot |
| Timing | All files move simultaneously | Group 1 moves, then Group 2, then Group 3 |
| Easing | Linear slide to halt | `back.out` ease — files snap into folders with energy |
| Feedback | Folders are static | Folders scale up when "catching" a file |

**Fix:**
1. Split `organizeProgress` into `imagesProgress`, `docsProgress`, `codeProgress`
2. Stagger group animations in GSAP timeline
3. Add `back.out` or elastic easing
4. Folders react (scale pulse) when files arrive

#### Beat 4: "Resolution" (78%–100%) — Weak Payoff

| Issue | Current State | Target State |
|-------|---------------|--------------|
| CTA copy | "This could be you" | Something more specific/urgent |
| Momentum | Disconnected from animation | CTA feels earned after watching transformation |

### Implementation Plan for FileCloud.tsx

```
1. Define Relationships
   - Add `relatedTo: string[]` field to DesktopFile interface
   - Map which files connect to which

2. Create ConnectionLayer (SVG)
   - New component that renders behind icons
   - When `scanProgress > 0.5`, draw bezier lines between related files
   - Animate line drawing with GSAP drawSVG or stroke-dashoffset

3. Stagger Organization
   - Replace single `organizeProgress` with per-group progress
   - Timeline: images (0-0.3) → documents (0.1-0.4) → code (0.2-0.5)
   - Each group uses `back.out` easing

4. Folder Reactions
   - When file enters folder zone, folder scales 1.0 → 1.1 → 1.0
   - Subtle "catch" animation
```

### General Changes

- [ ] **Reduce scroll depth** — Condense from ~4vh to ~2.5vh
- [ ] **Remove or redesign progress indicator** — Either make it meaningful or remove
- [ ] **Add ambient file drift** — Subtle movement in chaos state so files don't feel frozen

### Alternative Approaches to Consider

1. **Non-scrollytelling hero** — Simple above-fold with video/GIF demo
2. **Hybrid** — Shorter scroll section + embedded demo below
3. **Interactive hero** — Let user drag files to see them organize
4. **Steal from self** — Port `ConnectionsDemo` logic from ActThree into Hero

---

## 2. Features Section (ActThree) — Priority: MEDIUM

### Current Issues

- Feature 04 has awkward empty space (demo pushed far right)
- Section is very long due to alternating layout
- Interactive demos may not communicate on mobile (tap vs hover)

### Proposed Changes

- [ ] Audit demo auto-cycling for mobile clarity
- [ ] Tighten spacing between features
- [ ] Consider 2-column grid for features 3+4 on desktop
- [ ] Add visual connector between features (timeline? dotted line?)

---

## 3. Before/After Section (ActFour) — Priority: MEDIUM

### Current Issues

- Both cards have similar visual weight
- "Before" doesn't feel chaotic enough
- "After" doesn't feel serene enough

### Proposed Changes

- [ ] **Before card:** Add scattered file icons, use warmer/stressed color tint
- [ ] **After card:** Enhance the calm — more green tint, organized icon cluster
- [ ] Consider animation: Before items could "shake" slightly, After items "settle"
- [ ] Add subtle iconography (chaos vs order visual metaphor)

---

## 4. CTA Section (ActFive) — Priority: MEDIUM

### Current Issues

- Testimonial is separated from stats by CTA button (awkward flow)
- Stats could have more visual impact
- **Post-CTA experience undefined** — What happens after clicking "Join the Beta"?

### Proposed Changes

- [ ] Move testimonial above CTA or integrate with stats row
- [ ] Add subtle animation to stats (count-up on scroll?)
- [ ] Consider adding app preview/screenshot near CTA

### Post-CTA Flow ⚠️ NEW

- [ ] **Define click destination** — Form modal? External link? Email capture?
- [ ] **Confirmation state** — Success message, next steps, expected timeline
- [ ] **Friction reduction** — Add "No credit card required" or "Free during beta" near button
- [ ] **Urgency/social proof** — Consider "Join 847 early adopters" style copy

---

## 5. Tech Credibility Strip — Priority: LOW

### Current Issues

- Hover hints invisible on mobile
- Could be more visually integrated

### Proposed Changes

- [ ] Show hints on mobile (always visible or tap-to-reveal)
- [ ] Consider moving into footer or making sticky on scroll

---

## 6. Global Design Adjustments — Priority: MEDIUM

### Spacing

- [ ] Audit vertical rhythm — some sections feel too padded
- [ ] Reduce `py-32 md:py-48` to `py-24 md:py-32` in some sections

### Color

- [ ] Consider adding one accent moment (hero CTA? key feature?)
- [ ] Ensure sufficient contrast for accessibility

### Typography

- [ ] Review line-height on body copy (currently comfortable, could tighten)
- [ ] Ensure mono font rendering is crisp at small sizes

### Animation

- [ ] Add page load entrance animation (fade in + slight rise)
- [ ] Consider reduced motion mode improvements
- [ ] Audit animation timing for consistency

---

## 7. Mobile & Responsive Experience — Priority: HIGH

### Known Issues

- [ ] Hover states don't translate to touch
- [ ] Interactive demos need tap affordances
- [ ] Hero scrollytelling may be confusing on mobile
- [ ] Footer link hints don't work on touch
- [ ] **500vh scroll height is tedious on mobile** — "thumb friction" too high

### Proposed Changes

- [ ] Add tap indicators to interactive demos
- [ ] **Reduce hero scroll height on mobile** — `h-[300vh]` or use `ScrollTrigger.normalizeScroll(true)` for snappier touch scrubbing
- [ ] Make footer hints always visible on mobile
- [ ] Test on real devices (not just responsive mode)

```tsx
// Example: Responsive scroll height
className={`relative ${isMobile ? 'h-[300vh]' : 'h-[500vh]'}`}

// Or use ScrollTrigger normalization for touch
ScrollTrigger.normalizeScroll(true); // Makes scrubbing snappier on touch
```

### Form Factor Extremes ⚠️ NEW

| Viewport | Issue | Consideration |
|----------|-------|---------------|
| **Ultra-wide (21:9)** | File cloud may look sparse or stretched | Max-width container? Scale file positions? |
| **Small desktop (≤1280px)** | Content may feel cramped | Test at 1280×720 specifically |
| **iPad landscape** | Neither phone nor desktop | Define explicit tablet breakpoint behavior |
| **Orientation change** | Layout may break on rotate | Handle with CSS or JS resize listener |

### Responsive Scroll Height — Implementation Concern

```tsx
// RISK: JS-based check causes hydration mismatch
className={`relative ${isMobile ? 'h-[300vh]' : 'h-[500vh]'}`}

// BETTER: CSS-based approach
className="relative h-[300vh] md:h-[500vh]"

// OR: CSS clamp() for fluid scaling
style={{ height: 'clamp(300vh, 50vw + 200vh, 500vh)' }}
```

JS-based `isMobile` detection risks layout shift on hydration. Prefer CSS media queries or `clamp()`.

---

## 8. Performance & Accessibility — Priority: HIGH

### Font Loading (CLS Risk)

| Font | Role | Risk |
|------|------|------|
| Instrument_Serif | Display headlines | Late swap could cause jarring layout shift on large headlines |
| DM_Sans | Body text | Lower risk |
| JetBrains_Mono | Code/mono | Lower risk |

**Current State:** Using `next/font/google` with `display: 'swap'` (good)

**Potential Fix:** Add `adjustFontFallback: true` if any jumpiness is observed:
```tsx
const instrumentSerif = Instrument_Serif({
  subsets: ['latin'],
  display: 'swap',
  adjustFontFallback: true, // Reduces CLS
});
```

### Reduced Motion Handling

**Issue:** `globals.css` has a "nuclear option" that breaks ALL animations:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    /* ... */
  }
}
```

**Problem:** This breaks functional transitions (hover states, simple fades) that help users understand UI changes. UI feels "broken" instead of "calm."

**Fix:**
- [ ] Remove the nuclear CSS override
- [ ] Use `useReducedMotion` hook to simplify complex animations (flying files → instant position)
- [ ] Keep subtle opacity fades and color changes for UI feedback

### Grain Overlay CPU Issue — CONTRADICTS "ZERO CPU IDLE"

**Issue:** SVG filter on full-screen fixed overlay is CPU-intensive:

```tsx
<feTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/>
```

On 4K monitors, this can spin up fans — directly contradicting the "Zero CPU idle" promise.

**Fix:** Replace live SVG filter with a static tiled PNG:

```tsx
// Before (CPU-heavy)
<div style={{ backgroundImage: `url("data:image/svg+xml,...")` }} />

// After (near-zero cost)
<div
  className="fixed inset-0 pointer-events-none z-50 opacity-[0.015]"
  style={{ backgroundImage: 'url(/noise-64x64.png)', backgroundRepeat: 'repeat' }}
/>
```

- [ ] Create 64x64px noise PNG tile
- [ ] Replace SVG filter with tiled PNG background
- [ ] Verify visual parity

### Focus States ✓

**Good:** Custom focus ring styles are distinct and high-contrast:
```css
--focus-ring: 0 0 0 2px var(--forma-obsidian), 0 0 0 4px var(--forma-steel-blue);
```

No changes needed.

### Skip Links ⚠️ NEW

**Issue:** CSS styling for `.skip-link` exists but is not implemented in the page component.

**Problem:** Keyboard users have no way to bypass the long scrollytelling hero section.

**Fix:**
- [ ] Add skip link component at top of page
- [ ] Target should jump to main content after hero
- [ ] Test with keyboard-only navigation

```tsx
// Add to layout or page
<a href="#main-content" className="skip-link">
  Skip to main content
</a>

// Add id to first section after hero
<section id="main-content" tabIndex={-1}>
  {/* ActThree content */}
</section>
```

### First-Load Performance ⚠️ NEW

**Gap:** CLS is addressed but FCP/LCP are not discussed.

| Metric | Concern | Mitigation |
|--------|---------|------------|
| **FCP** | GSAP + Lenis may block first paint | Ensure scripts are deferred or code-split |
| **LCP** | Hero headline is critical | Preload Instrument_Serif font |
| **TTI** | Complex animations may delay interactivity | Lazy-load below-fold demos |

**Proposed Audit:**
- [ ] Run Lighthouse on production build
- [ ] Check if GSAP is in critical path
- [ ] Consider skeleton states for hero if FCP > 1.5s
- [ ] Verify image optimization (file icons are SVG — good)

---

## 9. CSS Architecture — Priority: LOW (moved from MEDIUM)

### Theme Variable Naming Problem

**Issue:** `globals.css` has overrides that invert semantic meaning:

```css
[data-theme="light"] .bg-forma-obsidian {
  background-color: #FFFFFF; /* Obsidian = White?! */
}
```

**Problem:** "Obsidian" literally means "dark volcanic glass." Making it mean "white" in light mode breaks developer mental model and makes code harder to reason about.

**Fix:** Use truly semantic variable names:

```css
/* Instead of literal color names */
--forma-obsidian: #1C1C1E;

/* Use semantic purpose names */
--bg-primary: ...;
--bg-surface: ...;
--text-primary: ...;
--text-muted: ...;

/* Then in themes */
[data-theme="light"] {
  --bg-primary: #FFFFFF;
  --text-primary: #1C1C1E;
}
[data-theme="dark"] {
  --bg-primary: #1C1C1E;
  --text-primary: #F5F5F0;
}
```

- [ ] Audit all color variable usage
- [ ] Create semantic variable layer
- [ ] Refactor components to use semantic names
- [ ] Remove inverted class overrides

---

## 10. Analytics & Measurement ⚠️ NEW

### Current State

No tracking is mentioned for measuring the effectiveness of design changes.

### Proposed Tracking Plan

| Metric | Tool | Purpose |
|--------|------|---------|
| **Scroll depth** | GA4 / Mixpanel | Measure how far users scroll through hero |
| **CTA clicks** | Event tracking | Conversion rate baseline |
| **Demo interactions** | Click/hover events | Which features get attention |
| **Bounce rate by section** | Heatmaps | Where do users drop off |
| **Time on page** | GA4 | Engagement proxy |

### Key Questions to Answer

- [ ] What % of users complete the scrollytelling hero?
- [ ] Do connection lines increase scroll completion?
- [ ] Which feature demo gets the most interaction?
- [ ] Does the Before/After section affect CTA clicks?

### Implementation

- [ ] Add scroll milestone tracking (25%, 50%, 75%, 100% of hero)
- [ ] Track CTA button clicks with UTM parameters
- [ ] Consider Hotjar/FullStory for session replays during beta
- [ ] A/B test hero variations once baseline is established

---

## 11. Additional Ideas (To Discuss)

### Content Additions

- [ ] **Video demo** — 30-60s screen recording showing Forma in action
- [ ] **App preview section** — Screenshots or mockup of actual UI
- [ ] **FAQ section** — Address common questions (pricing, data privacy, etc.)
- [ ] **Comparison table** — Forma vs manual organization vs other tools

### Technical Additions

- [ ] **Download button** — Direct .dmg download (when ready)
- [ ] **Email capture** — Newsletter/waitlist for non-beta users
- [ ] **Blog/Updates** — Link to changelog or blog

### Trust Signals

- [ ] **More testimonials** — Carousel or grid of user quotes
- [ ] **Press mentions** — If any coverage exists
- [ ] **Security badges** — Apple notarization, privacy certifications

---

## 12. User's Additional Items

> Add your items here:

- [ ] _____
- [ ] _____
- [ ] _____

---

## Implementation Priority (Revised)

### Phase 1 (Immediate) — Ship Blockers
1. **Navigation/Header** — Minimal sticky nav with logo + CTA ⚠️ NEW
2. **Hero scrollytelling rework** — Connection lines, staggered motion, folder reactions
3. **Grain overlay optimization** — Replace SVG filter with PNG tile (CPU issue)
4. **Mobile scroll height** — Reduce via CSS `h-[300vh] md:h-[500vh]`
5. **Reduced motion fix** — Remove nuclear CSS, use hook-based simplification (~4-6 hrs)
6. **Skip links** — Implement keyboard bypass for scrollytelling ⚠️ NEW
7. **First-load performance audit** — Lighthouse check, ensure GSAP isn't blocking ⚠️ NEW

### Phase 2 (Short-term) — Polish + Measurement
8. **Scroll depth analytics** — Track hero completion rate ⚠️ NEW
9. Before/After visual contrast enhancement
10. CTA section restructure (testimonial placement + post-CTA flow)
11. Features section spacing
12. Chaos state messiness increase

### Phase 3 (Medium-term) — Architecture & Edge Cases
13. Form factor testing (ultra-wide, tablet, small desktop) ⚠️ NEW
14. Font loading CLS check
15. Global spacing audit

### Phase 4 (Later) — Content & Tech Debt
16. Video demo integration
17. Additional content sections
18. Email capture flow
19. CSS semantic variable refactor (deprioritized — no user impact)

---

## Implementation Risks & Concerns ⚠️ NEW

### iOS Safari Scroll Behavior
`ScrollTrigger.normalizeScroll(true)` can conflict with iOS Safari's address bar hide/show. Test on actual devices with browser chrome visible.

### Connection Lines SVG Performance
Dynamic bezier curves on 8+ files simultaneously may cause jank. Prototype in isolation first. Consider Canvas-based approach if SVG is slow.

### PNG Noise Tile Seams
64×64 tile may show seams on Retina displays. Test at 128×128 or 256×256. Verify at 2× and 3× scales.

### Reduced Motion Scope
Hook integration required across all animated components. This is ~4-6 hours of careful work, not a quick fix.

### Staggered Animation Timing
Splitting `organizeProgress` into per-group progress adds complexity. User test to ensure staggered motion reads as "intelligent" not "laggy."

### Feature Demo Auto-Cycling
`setInterval`-based cycling continues when off-screen (CPU waste). Add IntersectionObserver to pause. Pause on first user interaction.

---

## 13. What's Working Well (Keep These)

These elements are strong and should be preserved:

### Visual Design
- **Obsidian/Steel Blue palette** — Developer aesthetic without being cold
- **Grain overlay at 0.015 opacity** — Subtle texture, avoids "template fatigue"
- **Typography mixing** — Serif display + sans body + mono accents

### Interactions
- **NaturalLanguageDemo & ConnectionsDemo** — More interactive/explanatory than hero (steal from these!)
- **Footer hover hints** — Delightful micro-interaction with personality
- **TiltCard effects** — Subtle depth without being gimmicky

### Copy
- "Zero CPU idle. Only works when you do." — Fantastic, specific copy
- "Not another Electron app" — Addresses real developer skepticism
- Feature descriptions are clear and benefit-focused

### Structure
- Bento-grid layouts in ActThree
- Before/After comparison concept (execution needs work, concept is solid)
- Social proof stats are impact-focused, not headcount

---

## Notes

### Feedback Sources
- Internal review (January 2025)
- External code review #1: Hero animation analysis (`GSAPScrollytellingHero.tsx`, `FileCloud.tsx`, `page.tsx`)
- External code review #2: Performance, accessibility, CSS architecture (`globals.css`, font config, theme system)
- **UX Design Critique** (January 2025): Navigation gaps, first-load performance, analytics plan, skip links, form factor extremes, implementation risks

### Key Insights

> "The issue isn't the technology (GSAP + React is a solid choice); it's a disconnect between your narrative promise and the visual execution."

The hero's text promises intelligence, but visuals only deliver motion. Recognition phase is the critical failure point — needs visible connection lines to show *why* files are grouping.

> "SVG filters on a full-screen fixed overlay can be extremely CPU-intensive... This contradicts your 'Zero CPU idle' promise if the landing page itself spins up the fans."

The grain overlay needs to be replaced with a static PNG tile.

> "Don't invert color names (Obsidian != White). Use semantic names."

CSS architecture needs semantic variable layer to avoid confusing color mappings.

> "Users landing on this page have no persistent way to understand what Forma is, navigate to specific sections, or access critical links."

Navigation is a Phase 1 priority — not optional polish.

> "Without data on how far users scroll, the team cannot validate whether the hero improvements are working."

Analytics implementation should follow immediately after Phase 1 changes.

### Decision Log
_Record decisions as we make them:_

- [ ] Decision: Keep scrollytelling or switch to simpler hero?
- [ ] Decision: How chaotic should chaos state be?
- [ ] Decision: Final CTA copy direction?

---

*Last updated: January 2025 (UX critique incorporated)*
