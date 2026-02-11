# Forma Marketing Website -- Visual Review

**Date:** 2026-02-07
**Reviewed at:** http://localhost:3001 (Next.js 16.1.6 / Turbopack dev server)
**Viewports tested:** Desktop 1440x900, Tablet 768x1024, Mobile 375x812
**Theme:** Light mode (production default). Dark mode tested via manual `data-theme` toggle.

---

## Executive Summary

The Forma marketing site presents a clean, understated aesthetic that aligns well with a premium macOS utility. The typography pairing (Instrument Serif for display, DM Sans for body) is distinctive and well-chosen. The overall information architecture is sound: hero, credibility badges, features, before/after comparison, pricing, FAQ, newsletter, and footer flow logically.

However, there are several issues ranging from a critical layout bug to polish details that undermine the site's ability to convert visitors. The most significant problem is a CSS layout issue where the `.site-container` class fails to center content or apply side padding, causing left-aligned content at wide viewports and edge-bleeding text on narrow screens. The dormant dark mode CSS, while not exposed to users, has severe readability issues if ever enabled.

---

## 1. Critical: Layout Centering Bug (`.site-container`)

**Severity: HIGH -- affects all viewports**

The `.site-container` class defined in `globals.css` inside `@layer components` specifies:
```css
.site-container {
  width: 100%;
  max-width: 1160px;
  margin-inline: auto;
  padding-inline: clamp(1.5rem, 4vw, 3.25rem);
}
```

At runtime, `max-width: 1160px` applies correctly, but **`margin-inline: auto` and `padding-inline: clamp(...)` both resolve to `0px`**. This appears to be a Tailwind v4 `@layer components` processing issue where these specific CSS logical properties are not being applied.

**Observed impact:**
- **Desktop (1440px):** The 1160px container is pinned to the left edge of the viewport instead of being horizontally centered. There is a ~280px gap on the right side of the page. Content appears noticeably left-heavy.
- **Mobile (375px):** The container has zero side padding, so text elements that are not constrained by inner `max-w-*` classes extend to the absolute edges of the screen.

**Why it looks partially acceptable despite the bug:** Inner elements like the hero's `max-w-[860px]` div and `text-center` alignment make centered text *appear* centered within its container. But the container itself is not centered in the viewport, creating an asymmetric layout at wide screens.

**Recommended fix:** Either:
1. Move `.site-container` out of `@layer components` and define it as a regular CSS rule, or
2. Replace the CSS-based approach with Tailwind utility classes directly (e.g., `mx-auto max-w-[1160px] px-6 md:px-[3.25rem]`), or
3. Investigate the Tailwind v4 `@layer` interaction and ensure `margin-inline` and `padding-inline` are processed.

---

## 2. What Looks Good

### Typography Pairing
The Instrument Serif (display) and DM Sans (body) combination is excellent. Instrument Serif gives headlines an editorial, premium feel without being overly decorative. DM Sans is highly readable for body copy. The JetBrains Mono used in feature previews and code-like elements adds appropriate technical credibility.

### Hero Section Copy
The headline "A file organizer for people who gave up on file organizers." is strong -- it immediately identifies the target audience and establishes empathy. The subheadline pairs of "Your desktop is a dumping ground..." (problem) and "You make rules. Forma follows them..." (solution) create a clear narrative arc.

### App Screenshot / MacWindowFrame
The hero screenshot showing the actual Forma app inside a MacWindowFrame component is well-executed. The rounded corners, subtle border, drop shadow, and backdrop blur create a convincing native macOS presentation. The screenshot itself shows real UI with realistic file names, which builds credibility.

### Credibility Strip
The three trust badges (Mac-Native, Privacy-First, Always Reversible) are well-designed with icon circles, clear labels, and concise descriptions. The rounded-2xl cards with subtle borders and backdrop blur feel native to macOS design language.

### Feature Section Interactive Previews
Each feature card includes a "LIVE PREVIEW" mini-demo (rule input, connection grouping, file preview checklist, undo timeline). These are a strong differentiator -- they show rather than tell. The mono-spaced font for file paths and the color-coded category dots (blue for Images, sage for Documents, orange for Code) make the previews feel like actual UI.

### Pricing Section
"$29. Once. Forever." is a killer headline. The anti-subscription positioning is clear and differentiated. The Mac App Store button with the Apple logo is properly styled and immediately recognizable. Feature bullets with sage-green check icons are clean.

### FAQ Section
The accordion interaction (powered by GSAP) is smooth. Questions are well-chosen and address genuine user concerns (deletion, privacy, undo capability). The first item being open by default is the right UX choice.

### Footer
The dark footer provides good contrast and visual closure. The "Built by someone who got tired of seeing Screenshot 2024-01-15..." copy is charming and on-brand. The three-column layout (story, links, contact) is well-organized.

### Color Palette
The Forma palette (obsidian, bone, steel-blue, sage, warm-orange) is cohesive and restrained. Colors serve functional purposes: steel-blue for primary actions and file paths, sage for success/after states, warm-orange for undo/before states. This creates implicit meaning without being heavy-handed.

---

## 3. Issues and Recommendations

### 3.1 Hero Section: Content Alignment (Medium)

Beyond the `.site-container` centering bug, the hero section's vertical spacing feels cramped at desktop. The `pt-18 pb-18` (72px) top and bottom padding, combined with the app screenshot bleeding below the fold, means a user at 1440x900 never sees the full hero + CTA + screenshot in one view. The CTAs ("Download for Mac" / "See how it works") are barely visible before the screenshot takes over.

**Recommendation:** Consider increasing `pt` to push the headline down slightly so the dual CTA buttons are comfortably above the fold at common desktop resolutions (1440x900, 1920x1080). Alternatively, reduce the gap between CTAs and the screenshot.

### 3.2 Hero Section: CTA Button Hierarchy (Medium)

The primary CTA "Download for Mac" uses `bg-forma-obsidian` (dark background) which works well. However, the secondary CTA "See how it works" uses a very light border (`border-black/[0.12]`) and translucent white background that makes it nearly invisible at a glance, especially against the already-light page background. The two buttons do not have strong enough visual contrast to establish a clear primary/secondary hierarchy.

**Recommendation:** Either darken the secondary button border (e.g., `border-black/[0.2]`) or give it a slightly more opaque background to make it scannable at a glance.

### 3.3 Feature Cards: Left-Aligned, Full-Width on Desktop (Medium)

Feature cards span the full container width as stacked single-column blocks. At 1440px desktop, this creates very long lines of text in the feature descriptions, and the "LIVE PREVIEW" areas appear small relative to the available space. The single-column stack also makes the features section very long vertically.

**Recommendation:** Consider a two-column layout for feature cards at desktop, or at minimum constrain the text content width within each card to improve readability (ideal line length is 50-75 characters).

### 3.4 Before/After Section: Height Imbalance (Low-Medium)

The "Before" card lists 6 chaotic filenames and is significantly taller than the "After" card which shows only 3 organized folders. This creates visible height asymmetry in the two-column grid. The "After" card has substantial empty space at the bottom.

**Recommendation:** Either add more content to the "After" card (e.g., file count details, a brief "organized in 3 seconds" caption) or use a visual element (folder icons, a satisfaction indicator) to fill the vertical space and create visual balance.

### 3.5 Before/After Section: "Before" Card Text Truncation on Mobile (Low)

At 375px, the filename `Screen Recording 2024-02-01 at 10.15.23 AM.mov` truncates with an ellipsis (`AM...`). While truncation is handled with CSS (`truncate` class), the truncated result somewhat undermines the "messy filenames" comedic effect that makes this section effective.

**Recommendation:** Consider using a slightly smaller font size on mobile for the before-card filenames, or hand-picking shorter example filenames that still convey chaos without truncating.

### 3.6 Credibility Badges: Stacking on Mobile (Low)

At 375px, the three credibility badges stack vertically and are left-aligned, which is correct. However, they each occupy different widths since their text content varies, creating a visually ragged stack.

**Recommendation:** Consider making the badges full-width (`w-full`) on mobile so they form a uniform stack, or center-align them.

### 3.7 Newsletter Section: Minimal Visual Weight (Low-Medium)

The "Stay in the loop" newsletter section has very little visual differentiation from surrounding content. It blends into the FAQ section above it and the footer below. There is no background color change, no card container, no visual separator.

**Recommendation:** Add a subtle background treatment (e.g., the light gray used in the features section, or a bordered card) to give the newsletter section its own visual identity and draw the eye to the email input.

### 3.8 FAQ Section: No Visual Separator from Pricing (Low)

The FAQ section starts immediately after the pricing section with only padding between them. At certain scroll positions, the two sections visually blend together.

**Recommendation:** Consider adding a subtle horizontal rule or a background-color shift to delineate the sections more clearly.

### 3.9 Mobile Header: Hamburger + Another Icon (Low)

At 375px the header shows the Forma logo on the left and what appears to be a hamburger menu icon plus an additional icon on the right side. The second icon appears to be part of the header CTA area. With limited space, this feels slightly crowded.

**Recommendation:** Ensure only the hamburger icon shows on mobile, with the "Download for Mac" CTA appearing inside the mobile menu dropdown rather than cramped in the header bar.

### 3.10 Page Background Gradient (Cosmetic)

The page uses `bg-[linear-gradient(180deg,#ffffff_0%,#f2f4f7_100%)]` on the outer wrapper and the body has a `linear-gradient(180deg, #FFFFFF 0%, #F4F5F7 100%)`. These near-white-to-very-light-gray gradients are extremely subtle to the point of being imperceptible on most displays. The features section has its own background (`#f4f6f8`) which creates a visible but very slight differentiation.

**Recommendation:** This is working as intended if the goal is restraint. If more section differentiation is desired, slightly increase the contrast of background shifts between sections.

---

## 4. Dark Mode Assessment

**Status:** The ThemeProvider is hardcoded to `"light"` and the `setTheme` function is a no-op. There is no user-facing toggle. However, extensive dark mode CSS exists in `globals.css`.

**When manually toggled via `data-theme="dark"`:**

### 4.1 Severe: Text Invisibility
Multiple headings and body text become invisible or nearly invisible. The "How it actually works" section heading, "Sound familiar?" heading, FAQ question text, and "Stay in the loop" heading all disappear because they use Tailwind text color classes that get overridden to light colors by the `[data-theme="dark"]` selectors, while the *background* of their containing sections remains light (the page wrapper `bg-[linear-gradient(180deg,#ffffff_0%,#f2f4f7_100%)]` is hardcoded in `page.tsx` and is not theme-aware).

### 4.2 Severe: Feature Cards Become Black Blocks
The feature card articles turn solid black with white text, but their inner preview areas also become black, creating an undifferentiated dark mass. The rule preview, connection preview, and control preview lose all visual structure.

### 4.3 Severe: Before/After Cards Lose Readability
Both cards turn very dark with low-contrast text. The "Before" card's monospace filenames are nearly invisible.

**Recommendation:** Dark mode CSS should either be removed entirely (since it is not exposed to users and adds CSS weight), or the implementation should be completed holistically so that all sections, including the page wrapper gradient and the features section background, respond to the theme attribute. The current state is a liability if dark mode is ever accidentally enabled.

---

## 5. Accessibility Notes

### Positive
- Skip-to-content link is implemented
- `aria-label` attributes on navigation landmarks
- `aria-expanded` on FAQ accordion buttons
- `role="contentinfo"` on footer
- Focus ring styles are defined with visible outlines
- `prefers-reduced-motion` is respected with a comprehensive media query block
- Touch target minimum sizing (44px) is enforced for coarse pointers

### Concerns
- The nav link text at 13px with `text-forma-obsidian/70` (opacity 0.7) on a near-white background may fall below WCAG AA contrast thresholds for small text. The computed color `lab(9.26324 0 0 / 0.7)` against `#FFFFFF` yields approximately a 4.1:1 ratio, which is borderline for 13px text (AA requires 4.5:1 for text below 18px/14px bold).
- The "LIVE PREVIEW" and "PARSED ACTION" labels use `text-forma-obsidian/45` (opacity 0.45), which is decorative but may be too low-contrast for users who need to read them.
- The FAQ accordion's `aria-labelledby` references `faq-question-${index}` but no corresponding `id` is set on the question button/span, so the ARIA relationship is broken.

---

## 6. Performance Observations

- The hero screenshot uses Next.js `<Image>` with `priority`, which is correct for LCP.
- GSAP and ScrollTrigger are imported but `enableScrollAnimations` is `false` across all sections. This means the animation libraries are loaded but unused. Consider code-splitting or removing the GSAP imports if scroll animations remain disabled.
- The `noise-overlay` SVG data URI and multiple `@keyframes` definitions add CSS weight for effects that may not be visually perceptible.

---

## 7. Summary of Priority Actions

| Priority | Issue | Section |
|----------|-------|---------|
| **P0** | `.site-container` margin/padding not applying -- content not centered | Global layout |
| **P1** | Dark mode CSS creates severe readability issues if ever activated | Global theme |
| **P1** | Hero CTAs may fall below the fold at 1440x900 | Hero |
| **P2** | Secondary CTA button too subtle | Hero |
| **P2** | Feature card text lines too long at desktop | Features |
| **P2** | Newsletter section lacks visual weight | Newsletter |
| **P2** | Before/After card height imbalance | Before/After |
| **P3** | Nav link contrast borderline for WCAG AA | Header |
| **P3** | FAQ aria-labelledby reference broken | FAQ |
| **P3** | GSAP loaded but animations disabled | Performance |

---

*Review conducted via Puppeteer automated screenshots at three viewport sizes with manual dark mode toggle testing and computed style inspection.*
