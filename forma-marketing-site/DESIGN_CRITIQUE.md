# Forma Marketing Site - Exhaustive Design Critique

**Date:** January 2026
**Scope:** Complete visual and interaction audit
**Purpose:** Redesign specification document

---

## Executive Summary

The Forma marketing site demonstrates ambitious design intentions with sophisticated animation systems, but suffers from **execution inconsistencies** that undermine the premium positioning. The site feels like a talented developer's interpretation of design rather than a designer-led implementation. Key issues include: **typographic hierarchy confusion**, **spacing inconsistency**, **animation overengineering**, and **incomplete visual systems**.

---

## 1. Hero Section - Deep Dive

### 1.1 Layout Architecture

**File:** `src/components/hero/InstantHero.tsx`

**Problem: Arbitrary Height Constraints**
```tsx
// Line 86
<div className="relative w-full max-w-6xl h-[600px] md:h-[800px] mx-auto perspective-container">
```
The `h-[600px] md:h-[800px]` is a magic number with no relationship to the content. This creates:
- Awkward whitespace on ultrawide displays
- Content cramping on tablet viewports
- No accommodation for dynamic content length

**Recommendation:** Use `min-h-[70vh]` with `max-h-[900px]` and let content determine actual height.

---

**Problem: Radial Gradient Positioning**
```tsx
// Lines 73-79
<div
  className="absolute inset-0 pointer-events-none transition-opacity duration-[2s]"
  style={{
    background: "radial-gradient(circle at 50% 50%, rgba(91, 124, 153, 0.08) 0%, transparent 60%)",
    opacity: progress > 0.5 ? 1 : 0.5
  }}
/>
```
- The gradient is **dead center** (50% 50%) which fights with the visual weight of the file cloud
- Opacity toggle from 0.5 to 1 is binary - should ease smoothly with progress
- The 60% transparent stop creates a harsh edge on larger screens

**Recommendation:** Position gradient at `55% 45%` to complement file cloud placement. Use `opacity: 0.4 + (progress * 0.6)` for smooth transition.

---

### 1.2 Hero Copy Positioning

**File:** `src/components/hero/InstantHero.tsx`, Lines 89-144

**Problem: Aggressive Fog Masking**
```tsx
// Lines 93-97
<div
  className="absolute -inset-x-10 -inset-y-6 pointer-events-none"
  style={{
    background: "radial-gradient(ellipse at center, rgba(250, 250, 248, 0.95) 0%, rgba(250, 250, 248, 0.85) 55%, rgba(250, 250, 248, 0) 72%)",
  }}
/>
```
This fog creates a "spotlight" effect that:
- Competes with the file cloud animation (the actual hero)
- Creates an unintentional visual hierarchy where text feels "stuck on top"
- The 72% stop is too tight, creating visible edges on certain backgrounds

**Recommendation:** Remove the fog entirely. The `#FAFAF8` background provides sufficient contrast. If needed, use a much subtler `rgba(250, 250, 248, 0.6)` at 0% fading to 0 at 50%.

---

**Problem: Eyebrow Text Styling**
```tsx
// Lines 99-101
<span className="block font-mono text-[11px] tracking-[0.25em] text-forma-steel-blue/80">
  AUTOMATIC FILE ORGANIZATION FOR MAC
</span>
```
Issues:
- `text-[11px]` is below accessibility minimum (12px recommended)
- `tracking-[0.25em]` (0.25em = 2.75px at 11px) is excessive - makes text harder to scan
- The `/80` opacity reduces contrast below WCAG AA
- All-caps + extreme letter-spacing is a dated design pattern

**Recommendation:** Use `text-xs` (12px), `tracking-[0.15em]`, and `text-forma-steel-blue` (full opacity). Consider sentence case: "Automatic file organization for Mac".

---

**Problem: Headline Line Height**
```tsx
// Lines 102-104
<h1 className="mt-4 text-4xl md:text-6xl font-display text-forma-obsidian leading-[1.05]">
  Your files, sorted by context.
</h1>
```
- `leading-[1.05]` is too tight for display text, especially at `text-6xl` (60px)
- Single-line headline doesn't need this tight leading, but it sets a bad precedent
- No responsive line-height adjustment

**Recommendation:** Use `leading-[1.1] md:leading-[1.08]`. For single-line headlines, `leading-none` (1.0) can work, but document this exception.

---

### 1.3 File Cloud Positioning & Animation

**File:** `src/components/hero/RichFileCloud.tsx`

**Problem: Hardcoded Percentage Positions**
```tsx
// Lines 48-213 (DESKTOP_FILES array)
{
  id: "1",
  name: "Screenshot 2024-12-14.png",
  chaosX: 22,
  chaosY: 28,
  // ...
  organizedX: 72,
  organizedY: 35,
}
```
Every file has manually specified X/Y percentages. This creates:
- **Maintenance nightmare** when adding/removing files
- **Viewport fragility** - percentages look different at 1200px vs 1920px
- **No algorithmic beauty** - positions feel hand-placed rather than systematically derived

**Recommendation:** Implement a layout algorithm:
```tsx
// Chaos: Golden ratio spiral with jitter
// Organized: Grid-based with category clustering
const calculateChaosPosition = (index: number, total: number) => {
  const angle = index * 137.5; // Golden angle
  const radius = Math.sqrt(index) * 8;
  return {
    x: 50 + Math.cos(angle * Math.PI / 180) * radius + (Math.random() - 0.5) * 10,
    y: 50 + Math.sin(angle * Math.PI / 180) * radius + (Math.random() - 0.5) * 10,
  };
};
```

---

**Problem: Z-Index Chaos**
```tsx
// Various files have chaosZIndex values: 10, 11, 12, 14, 15, 16, 18, 20
chaosZIndex: 15,  // Line 58
chaosZIndex: 12,  // Line 74
chaosZIndex: 18,  // Line 91
```
These arbitrary z-index values don't follow a system. The visual stacking appears random rather than intentional (e.g., newest on top, or larger on top).

**Recommendation:** Derive z-index from file properties:
```tsx
const zIndex = isFolder ? 5 : 10 + (file.depth * 10);
```

---

**Problem: Scale Inconsistency**
```tsx
chaosScale: 1.05,   // Line 57
chaosScale: 0.92,   // Line 73
chaosScale: 1.0,    // Line 90
chaosScale: 0.88,   // Line 108
chaosScale: 1.08,   // Line 125
```
Five different scale values with no apparent logic. This should communicate depth or importance, but currently feels arbitrary.

**Recommendation:** Use exactly 3 scale tiers: `0.9` (background), `1.0` (midground), `1.1` (foreground), derived from `depth` property.

---

### 1.4 CTA Buttons

**File:** `src/components/hero/InstantHero.tsx`, Lines 109-138

**Problem: Inconsistent Button Sizing**
```tsx
// Primary CTA - Line 112
className="... px-7 py-3 ..."

// Secondary CTA - Line 126
className="... px-6 py-3 ..."
```
Primary has `px-7` (28px), secondary has `px-6` (24px). This 4px difference is noticeable and creates visual imbalance. Both should share the same padding for consistent touch targets.

---

**Problem: Hover State Disparity**
```tsx
// Primary - Line 112
className="... hover:scale-105 transition-transform ..."

// Secondary - Line 126
className="... hover:border-forma-obsidian/30 hover:text-forma-obsidian transition-colors"
```
- Primary scales on hover (physical metaphor)
- Secondary changes colors on hover (state change metaphor)

This mixed metaphor creates cognitive dissonance. Both buttons should use the same interaction model.

**Recommendation:** Standardize on subtle scale (`hover:scale-[1.02]`) + color shift for both.

---

**Problem: Shadow on Primary Only**
```tsx
// Line 112
className="... shadow-xl"
```
The `shadow-xl` on the primary CTA creates visual weight asymmetry. The secondary button appears to "float" at a different elevation.

**Recommendation:** Add `shadow-md` to secondary, or remove shadow from primary and rely on background contrast.

---

### 1.5 Status Bar Animation

**File:** `src/components/hero/InstantHero.tsx`, Lines 154-166

**Problem: Sliding Transform Feels Disconnected**
```tsx
style={{
  transform: `translateX(-50%) translateY(${progress < 0.1 ? 100 : 0}px)`,
  opacity: progress < 0.1 ? 0 : 1
}}
```
The status bar slides up from 100px below and fades in. This entrance:
- Uses a binary threshold (< 0.1) rather than smooth interpolation
- The 100px offset is arbitrary and doesn't relate to any other spacing value
- Conflicts with the file cloud animation happening simultaneously

**Recommendation:** Use GSAP timeline to choreograph entrance:
```tsx
// Delay status bar until files start moving
const statusOpacity = Math.max(0, (progress - 0.15) / 0.2);
const statusY = (1 - statusOpacity) * 30; // Smaller, smoother offset
```

---

**Problem: Pulsing Dot Accessibility**
```tsx
// Line 162
<div className="w-3 h-3 rounded-full bg-forma-steel-blue animate-pulse" />
```
The `animate-pulse` is:
- Distracting during reading
- Not pausable (no reduced motion handling here, even though `useReducedMotion` exists elsewhere)
- Communicates "loading" rather than "processing" or "complete"

**Recommendation:** Replace with a subtle "breathing" animation that pauses when `progress > 0.9`, or use a checkmark transition when organized.

---

## 2. Icon System - Complete Audit

### 2.1 Credential Icons

**Files:** `src/components/credibility/icons/`

**Problem: Inconsistent Stroke Weights**
```tsx
// MonitorNativeIcon.tsx - Line 73
strokeWidth="1.5"

// ShieldPrivateIcon.tsx - Line 64
strokeWidth="1.5"

// BoltInstantIcon.tsx - Line 174
strokeWidth="1.5"
```
While stroke width is consistent at 1.5, the **visual weight differs** due to path complexity:
- Monitor has many thin lines (frame, screen, traffic lights)
- Shield has one thick outline
- Bolt has a single filled path

At 24px, the monitor appears lighter than the shield or bolt.

**Recommendation:** Adjust stroke weights per icon to achieve **optical balance**:
- Monitor: `strokeWidth="1.75"`
- Shield: `strokeWidth="1.5"`
- Bolt: `strokeWidth="1.25"` (already has fill to add weight)

---

**Problem: Animation Timing Inconsistency**
```tsx
// MonitorNativeIcon - draw animation
duration: 0.5 // monitor frame
duration: 0.4 // screen
duration: 0.15 each // traffic lights

// ShieldPrivateIcon - draw animation
duration: 0.6 // shield
duration: 0.4 // lock body
duration: 0.25 // lock shackle

// BoltInstantIcon - draw animation
duration: 0.35 // entire bolt
```
Total animation times:
- Monitor: ~1.2s
- Shield: ~1.25s
- Bolt: ~0.75s

The bolt finishes **37% faster** than the others, creating temporal imbalance in the staggered reveal.

**Recommendation:** Normalize total animation time to ~1.0s each. The bolt should have a longer "charge up" delay before its quick draw.

---

**Problem: Glow Effect Inconsistency**
```tsx
// BoltInstantIcon has:
style={{ filter: "blur(4px)" }} // Line 166

// Other icons have no glow
```
Only the bolt has a glow effect. This creates visual hierarchy that may not be intended (bolt appears more important than the other two).

**Recommendation:** Either add subtle glows to all three, or remove from bolt for consistency.

---

### 2.2 File Type Icons

**File:** `src/components/hero/RichFileCloud.tsx`, Lines 29-35

```tsx
const FILE_ICONS = {
  folder: Folder,
  image: Image,
  document: FileText,
  code: Code,
  video: Film,
} as const;
```

**Problem: Generic Lucide Icons**
These are stock Lucide icons with no customization. They:
- Don't match the hand-crafted aesthetic of the credential icons
- Use default 24px sizing with no optical adjustments
- Have no animation capability (unlike the credential icons)

**Recommendation:** Create custom icon components with:
- Consistent stroke weight with credential icons
- Draw animation capability
- Forma brand color integration
- Unique visual treatment (not stock icons)

---

### 2.3 Icon Color Application

**File:** `src/components/hero/RichFileCloud.tsx`, Lines 37-43

```tsx
export const FILE_COLORS = {
  folder: "#C97E66",    // forma-warm-orange
  image: "#5B7C99",     // forma-steel-blue
  document: "#7A9D7E",  // forma-sage
  code: "#6B8CA8",      // lighter steel-blue?
  video: "#8BA688",     // lighter sage?
} as const;
```

**Problem: Inconsistent Color Derivation**
- `folder`, `image`, `document` use exact Forma palette colors
- `code` uses `#6B8CA8` which is NOT in the Tailwind config
- `video` uses `#8BA688` which is NOT in the Tailwind config

These orphan colors break the design system.

**Recommendation:** Define all colors in `tailwind.config.ts`:
```ts
colors: {
  forma: {
    // existing...
    'code-blue': '#6B8CA8',
    'video-green': '#8BA688',
  }
}
```
Or derive them from existing colors using opacity/tint.

---

## 3. Typography - Granular Review

### 3.1 Font Stack Analysis

**File:** `src/app/layout.tsx`, Lines 8-25

```tsx
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-display",
  display: "swap",
  adjustFontFallback: false,
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
  adjustFontFallback: false,
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
  adjustFontFallback: false,
});
```

**Problem: Single Weight for Display Font**
Instrument Serif is only loaded at weight 400. This limits:
- No bold for emphasis
- No light for large display sizes
- Reliance on faux-bold (browser synthesized, looks poor)

**Recommendation:** Load weights 400 and 500 (if available), or choose a display font with more weights.

---

**Problem: No Fallback Font Adjustment**
`adjustFontFallback: false` is set on all fonts. This disables Next.js's automatic fallback font metrics adjustment, which means:
- Larger CLS (Cumulative Layout Shift) during font load
- Flash of unstyled text with different metrics

**Recommendation:** Remove `adjustFontFallback: false` or set to `true` for better CLS scores.

---

### 3.2 Type Scale Issues

**File:** `tailwind.config.ts` - Uses default Tailwind type scale

No custom `fontSize` configuration exists, meaning the site uses Tailwind defaults:
```
xs: 12px
sm: 14px
base: 16px
lg: 18px
xl: 20px
2xl: 24px
3xl: 30px
4xl: 36px
5xl: 48px
6xl: 60px
```

**Problem: Non-Harmonic Scale**
This is a linear scale with arbitrary increments. A more sophisticated design would use a modular scale (e.g., 1.25 ratio):
```
12, 15, 18.75, 23.4, 29.3, 36.6, 45.8, 57.2...
```

**Recommendation:** Define custom fontSize in Tailwind config using a 1.2 or 1.25 modular scale.

---

### 3.3 Line Height Audit

Across the codebase, I found these line-height values:

| File | Class | Value | Context |
|------|-------|-------|---------|
| InstantHero.tsx:103 | `leading-[1.05]` | 1.05 | H1 headline |
| page.tsx:141 | `leading-[1.08]` | 1.08 | H2 section title |
| page.tsx:156 | `leading-relaxed` | 1.625 | Body paragraph |
| page.tsx:287 | `leading-snug` | 1.375 | Feature description |

**Problem: Five Different Line Heights**
The site uses `leading-[1.05]`, `leading-[1.08]`, `leading-snug`, `leading-normal`, and `leading-relaxed`. This creates:
- Visual inconsistency between sections
- No clear system for when to use which
- Maintenance difficulty

**Recommendation:** Establish a 3-tier system:
- Display: `leading-tight` (1.25) for headlines
- Body: `leading-normal` (1.5) for paragraphs
- Compact: `leading-snug` (1.375) for UI text

---

### 3.4 Letter Spacing Audit

| File | Class | Value | Context |
|------|-------|-------|---------|
| InstantHero.tsx:99 | `tracking-[0.25em]` | 0.25em | Eyebrow |
| Header.tsx:52 | `tracking-tight` | -0.025em | Logo |
| page.tsx:138 | `tracking-[-0.02em]` | -0.02em | Section title |
| TechCredibilityStrip.tsx | (none) | 0 | Badge labels |

**Problem: Extreme Tracking on Eyebrow**
`tracking-[0.25em]` is 250% of the default letter spacing. At 11px font size, this adds 2.75px between each letter, making "AUTOMATIC FILE ORGANIZATION FOR MAC" extremely wide and hard to read.

**Recommendation:** Maximum `tracking-[0.1em]` for all-caps text, or `tracking-widest` (0.1em) from Tailwind.

---

## 4. Spacing System - Complete Analysis

### 4.1 Padding/Margin Audit

**Section Padding Values Found:**

| Component | Padding | Notes |
|-----------|---------|-------|
| Hero | `px-6` | 24px horizontal |
| TechCredibilityStrip | `py-12 md:py-16 px-6` | 48/64px vertical, 24px horizontal |
| ActThree | `py-24 md:py-32` | 96/128px vertical |
| ActFour | `py-24 md:py-32` | Consistent with ActThree |
| ActFive | `py-32 md:py-48` | 128/192px vertical - WHY different? |
| Footer | (none) | Fixed positioning, no padding |

**Problem: Inconsistent Vertical Rhythm**
- Most sections use `py-24 md:py-32`
- ActFive uses `py-32 md:py-48` with no clear reason
- This breaks the visual rhythm of the page

**Recommendation:** Standardize section padding: `py-20 md:py-28 lg:py-32`

---

### 4.2 Gap Analysis

```tsx
// InstantHero.tsx:109
gap-3  // 12px between CTAs

// TechCredibilityStrip.tsx:119
gap-10 sm:gap-16 md:gap-24  // 40/64/96px between badges

// page.tsx:155
gap-6  // 24px in feature grid

// page.tsx:289
gap-4  // 16px between capability items
```

**Problem: Non-Systematic Gap Values**
Gaps range from 12px to 96px with no apparent scale relationship.

**Recommendation:** Use Tailwind's spacing scale consistently:
- Tight: `gap-3` (12px)
- Normal: `gap-6` (24px)
- Loose: `gap-10` (40px)
- Section: `gap-16` (64px)

---

### 4.3 Max-Width Containers

```tsx
// Various files
max-w-6xl   // 72rem = 1152px (Hero)
max-w-5xl   // 64rem = 1024px (TechCredibility)
max-w-4xl   // 56rem = 896px (ActFive CTA)
max-w-3xl   // 48rem = 768px (ActFive description)
max-w-2xl   // 42rem = 672px (Hero copy)
```

**Problem: Five Different Max-Widths**
Each section uses a different container width, creating an inconsistent content "spine."

**Recommendation:** Standardize on 2-3 max-widths:
- Wide: `max-w-7xl` for full-bleed sections
- Standard: `max-w-5xl` for content sections
- Narrow: `max-w-2xl` for text-heavy sections

---

## 5. Color Application - Deep Analysis

### 5.1 Background Colors

```tsx
// InstantHero.tsx:69
bg-[#FAFAF8]

// This is NOT in the Tailwind config!
// Closest is forma-bone: #FAF9F6
```

**Problem: Orphan Background Color**
The hero uses a hardcoded hex value that's 2 units different from `forma-bone`. This breaks design system integrity.

**Recommendation:** Use `bg-forma-bone` or add `#FAFAF8` to the config as `forma-warm-bone`.

---

### 5.2 Opacity Usage Patterns

Searching for opacity patterns reveals inconsistency:

```tsx
// Text opacities used:
text-forma-obsidian/80   // 80%
text-forma-obsidian/70   // 70%
text-forma-obsidian/60   // 60%
text-forma-obsidian/45   // 45%
text-forma-obsidian/40   // 40%

// Border opacities used:
border-forma-obsidian/5   // 5%
border-forma-obsidian/8   // 8%
border-forma-obsidian/10  // 10%
border-forma-obsidian/15  // 15%
border-forma-obsidian/20  // 20%
border-forma-obsidian/30  // 30%
```

**Problem: 11 Different Opacity Values**
There's no systematic approach to opacity. Is 45% different from 40%? What's the semantic meaning?

**Recommendation:** Define semantic opacity tiers:
```ts
// Text
primary: 100%
secondary: 70%
tertiary: 50%
disabled: 35%

// Borders
subtle: 5%
light: 10%
medium: 20%
strong: 40%
```

---

### 5.3 Gradient Usage

**File:** `src/app/globals.css`

```css
/* Lines 73-78 */
.bg-gradient-radial-glow {
  background: radial-gradient(
    ellipse at center,
    rgba(91, 124, 153, 0.15) 0%,
    transparent 70%
  );
}
```

**Problem: Hardcoded RGBA in CSS**
This gradient uses `rgba(91, 124, 153, ...)` instead of CSS custom properties. If the `forma-steel-blue` color changes, this gradient won't update.

**Recommendation:** Use CSS custom properties:
```css
.bg-gradient-radial-glow {
  background: radial-gradient(
    ellipse at center,
    hsl(var(--forma-steel-blue) / 0.15) 0%,
    transparent 70%
  );
}
```

---

## 6. Component-by-Component Critique

### 6.1 Header

**File:** `src/components/Header.tsx`

**Problem: Logo Grid Opacity Logic**
```tsx
// Lines 17-34
const getCellOpacity = (row: number, col: number) => {
  const opacityMap: Record<string, number> = {
    "0-0": 0.95, "0-1": 0.7, "0-2": 0.5,
    "1-0": 0.7, "1-1": 0.85, "1-2": 0.65,
    "2-0": 0.45, "2-1": 0.6, "2-2": 0.4,
  };
  return opacityMap[`${row}-${col}`] || 0.5;
};
```
This creates a diagonal gradient effect, but:
- The values feel arbitrary (why 0.85 for center?)
- No relationship to Forma brand or file organization concept
- Different from actual app icon treatment

**Recommendation:** Either make the grid uniform opacity, or create a clear visual pattern (e.g., all same opacity, or a clear "F" letterform).

---

**Problem: Scroll Behavior Complexity**
```tsx
// Lines 85-115 - Complex scroll direction detection
```
The header hides on scroll down and shows on scroll up. This is:
- Competing with Lenis smooth scroll
- Adding JavaScript complexity for minor UX gain
- Potentially jarring when combined with GSAP scroll animations

**Recommendation:** Keep header always visible (sticky), or use CSS `scroll-behavior` with `IntersectionObserver` for better performance.

---

### 6.2 TechCredibilityStrip

**File:** `src/components/credibility/TechCredibilityStrip.tsx`

**Problem: Grid Background Contrast**
```tsx
// Lines 93-102
<div className="absolute inset-0 pointer-events-none opacity-[0.03]">
  <div
    className="absolute inset-0"
    style={{
      backgroundImage: `linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)`,
      backgroundSize: '40px 40px',
    }}
  />
</div>
```
At `opacity-[0.03]` (3%), this grid is barely visible on most monitors. It's either:
- Too subtle to be worth the render cost
- Or should be more visible (5-8%) to serve as intentional texture

**Recommendation:** Either remove entirely or increase to `opacity-[0.06]`.

---

**Problem: Connecting Line Z-Index**
```tsx
// Lines 135-137
<div className="hidden sm:block absolute top-1/2 left-0 right-0 -translate-y-1/2 pointer-events-none -z-10">
```
The connecting line uses `-z-10`, placing it behind everything. But since badges have `data-badge` and custom positioning, the line sometimes appears in front of badge content on certain viewports.

**Recommendation:** Use `z-0` and ensure badge content has `z-10`.

---

### 6.3 ActThree (Features Section)

**File:** `src/app/page.tsx`, Lines 125-220

**Problem: Hardcoded Demo Components**
```tsx
// Lines 171-214
{capabilities.map((cap, i) => (
  // Each capability has a different demo component
  {i === 0 && <NaturalLanguageDemo />}
  {i === 1 && <ConnectionsDemo />}
  {i === 2 && <ControlDemo />}
  {i === 3 && <UndoDemo />}
))}
```
This tight coupling of index to component is fragile. Reordering capabilities breaks the demos.

**Recommendation:** Include demo component in capability data:
```tsx
const capabilities = [
  { title: "...", demo: NaturalLanguageDemo },
  // ...
];
```

---

### 6.4 ActFour (Before/After)

**File:** `src/app/page.tsx`, Lines 222-285

**Problem: Static Comparison**
The before/after comparison is static images/mockups. This misses an opportunity for:
- Interactive slider comparison
- Animated transition between states
- Reuse of the RichFileCloud component from hero

**Recommendation:** Create an interactive `<BeforeAfterSlider />` component using the existing file cloud system.

---

### 6.5 ActFive (CTA Section)

**File:** `src/app/page.tsx`, Lines 287-350

**Problem: Duplicate CTA Styling**
```tsx
// Line 312 - Same button styles as hero
className="inline-flex items-center gap-2 px-8 py-4 bg-forma-obsidian text-forma-bone rounded-full..."
```
This duplicates the hero CTA styling with slight variations (`px-8 py-4` vs `px-7 py-3`).

**Recommendation:** Create a `<Button variant="primary" size="lg" />` component to ensure consistency.

---

### 6.6 Footer

**File:** `src/components/Footer.tsx`

**Problem: Fixed Positioning Interaction**
```tsx
// Line 14
className="fixed bottom-0 left-0 right-0 h-[400px] z-[-1]"
```
The footer is fixed with negative z-index, revealed as content scrolls away. This creates:
- Complex scroll calculations elsewhere
- Footer content inaccessible until full scroll
- Potential issues with keyboard navigation

**Recommendation:** Use standard sticky footer pattern or make footer part of normal document flow.

---

**Problem: Minimal Footer Content**
The footer contains only:
- Logo
- Two link groups (Product, Legal)
- Copyright

Missing:
- Social links
- Newsletter signup
- Trust badges
- Contact information
- App Store badge (for beta)

**Recommendation:** Expand footer to include standard marketing site elements.

---

## 7. Visual Problems - Specific Issues

### 7.1 Alignment Issues

**Hero CTA Buttons**
```tsx
// InstantHero.tsx:109
<div className="mt-6 flex flex-col sm:flex-row items-center justify-center gap-3">
```
On mobile (`flex-col`), buttons stack but maintain center alignment. The secondary button's text "Watch it work" is shorter than "Join the Beta", creating visual imbalance in the stack.

**Recommendation:** Set `min-w-[200px]` on both buttons for consistent width when stacked.

---

**Tech Credential Badges**
On tablet viewports (640-768px), the three badges wrap awkwardly - sometimes 2+1, sometimes all inline but cramped.

**Recommendation:** Force 3-column on sm+ or explicit 1-column on mobile:
```tsx
className="grid grid-cols-1 sm:grid-cols-3 gap-8"
```

---

### 7.2 Orphaned Text

**Hero Subtitle**
```tsx
// InstantHero.tsx:105-108
<p className="mt-4 text-base md:text-lg text-forma-obsidian/60">
  Forma learns the intent behind each file and suggests the right place.
  Apply changes with one click.
</p>
```
At certain viewport widths, "Apply changes with one click." orphans to its own line with only 4 words.

**Recommendation:** Add `text-balance` (CSS) or use `<br className="hidden md:block" />` to control breaks.

---

### 7.3 Border Radius Inconsistency

```tsx
// Buttons
rounded-full  // 9999px

// Cards
rounded-lg    // 8px
rounded-xl    // 12px
rounded-2xl   // 16px

// File icons
rounded-lg    // 8px
rounded       // 4px
rounded-md    // 6px
```

**Problem:** Six different border-radius values with no clear system.

**Recommendation:** Define 3 border-radius tiers:
- Small: `rounded` (4px) for small elements
- Medium: `rounded-lg` (8px) for cards
- Large: `rounded-2xl` (16px) for modals
- Full: `rounded-full` for buttons only

---

### 7.4 Shadow Inconsistency

```tsx
// Hero CTA
shadow-xl

// Status bar
shadow-2xl

// File cards (RichFileCloud.tsx:345-349)
boxShadow: `
  0 10px 18px -14px rgba(0, 0, 0, 0.25),
  0 4px 10px -6px rgba(0, 0, 0, 0.12),
  inset 0 1px 0 rgba(255, 255, 255, 0.6)
`

// GlowCard
shadow-glass (custom)
```

**Problem:** Mix of Tailwind shadows, custom shadows, and inline styles.

**Recommendation:** Define all shadows in Tailwind config:
```ts
boxShadow: {
  'card': '0 10px 18px -14px rgba(0, 0, 0, 0.25), ...',
  'card-hover': '...',
  'button': '...',
  'modal': '...',
}
```

---

## 8. What's Missing

### 8.1 Trust Signals

**Not Present:**
- Testimonials or social proof
- User count / download numbers
- Press mentions or logos
- Security certifications
- Privacy policy summary
- App Store rating (once available)

**Recommendation:** Add a `<SocialProof />` section between TechCredibilityStrip and ActThree.

---

### 8.2 Standard Marketing Elements

**Not Present:**
- Pricing section (even if "Free during beta")
- FAQ section
- Comparison table (vs. Hazel, vs. manual organization)
- Feature tour / product screenshots
- Video demo
- System requirements
- Changelog / What's New

**Recommendation:** Prioritize FAQ and comparison table for pre-launch.

---

### 8.3 Accessibility Features

**Not Present:**
- Skip to content link
- Proper heading hierarchy (jumps from h1 to h3 in some places)
- Focus indicators on interactive elements
- Reduced motion alternatives for all animations
- Screen reader announcements for dynamic content

**Current WCAG Issues:**
- Color contrast failures on `/60` and `/45` opacity text
- No `aria-live` regions for animation status
- Keyboard navigation breaks in mobile menu

---

### 8.4 Performance Optimizations

**Not Present:**
- Image optimization (no `<Image />` from Next.js)
- Font subsetting (loading full character sets)
- Animation budget (multiple GSAP timelines running)
- Code splitting for heavy components

**Recommendation:** Audit with Lighthouse and implement:
- `next/image` for all images
- Font subsetting for display font
- `will-change` hints for animated elements
- Dynamic imports for below-fold sections

---

### 8.5 Responsive Breakpoint Gaps

**Current Breakpoints:**
```ts
// tailwind.config.ts
screens: {
  tablet: "900px",
  "3xl": "1800px",
  ultrawide: "2400px",
}
```

**Missing Coverage:**
- No explicit handling for 768-900px ("tablet portrait")
- No handling for 320-375px (small phones)
- `ultrawide` defined but rarely used in components

**Recommendation:** Audit all components at 320px, 768px, and 2400px widths.

---

## 9. Animation System Critique

### 9.1 GSAP Configuration

**File:** `src/lib/animation/gsap-config.ts`

The site uses GSAP with ScrollTrigger, which is powerful but:
- Adds ~60KB to bundle (gzipped)
- Requires careful cleanup to prevent memory leaks
- Conflicts with CSS transitions in some cases

**Problem:** Multiple animation systems running:
1. GSAP timelines
2. CSS transitions (`transition-all`, `transition-colors`)
3. CSS keyframe animations (`animate-pulse`)
4. Lenis smooth scroll

This creates:
- Potential jank when systems conflict
- Debugging difficulty
- Higher CPU usage

**Recommendation:** Consolidate to GSAP for orchestrated animations, CSS for micro-interactions only.

---

### 9.2 Reduced Motion Handling

```tsx
// TechCredibilityStrip.tsx:26
const reducedMotion = useReducedMotion();

// Used correctly to skip GSAP animations
if (!container || !badges || reducedMotion) return;
```

**Problem:** Reduced motion is handled in some components but not others:
- `TechCredibilityStrip` - handled
- `InstantHero` - NOT handled (animation always runs)
- `RichFileCloud` - NOT handled
- Credential icons - NOT handled

**Recommendation:** Create a centralized `useAnimationConfig()` hook:
```tsx
const { shouldAnimate, duration } = useAnimationConfig();
// duration is reduced (0.1) when reducedMotion is true
```

---

## 10. Code Quality Issues Affecting Design

### 10.1 Inline Styles vs Tailwind

The codebase mixes inline styles with Tailwind inconsistently:

```tsx
// Inline style for something Tailwind can do
style={{ transform: `translateX(-50%)` }}
// Should be: className="-translate-x-1/2"

// Inline style for gradient (acceptable - complex)
style={{ background: "radial-gradient(...)" }}

// Inline style for filter (should be utility)
style={{ filter: "blur(4px)" }}
// Should be: className="blur-sm" or custom utility
```

**Recommendation:** Create custom Tailwind utilities for repeated patterns, reserve inline styles for truly dynamic values.

---

### 10.2 Magic Numbers

```tsx
// InstantHero.tsx
h-[600px] md:h-[800px]  // Why these values?
800 // ms delay before animation
2.5 // seconds animation duration

// RichFileCloud.tsx
chaosX: 22  // Why 22%?
1200px // perspective value
15 // degrees tilt
```

**Recommendation:** Extract magic numbers to named constants:
```tsx
const HERO_TIMING = {
  LOAD_DELAY_MS: 800,
  ANIMATION_DURATION_S: 2.5,
} as const;

const TILT_CONFIG = {
  PERSPECTIVE_PX: 1200,
  MAX_ROTATION_DEG: 15,
} as const;
```

---

## 11. Recommendations Summary

### Critical (Fix Before Launch)
1. Fix text contrast issues (opacity values too low)
2. Add reduced motion handling to all animated components
3. Standardize CTA button component
4. Fix orphan hex colors - use design tokens
5. Add skip-to-content and proper heading hierarchy

### High Priority
1. Implement modular type scale
2. Standardize spacing system (section padding, gaps)
3. Create consistent shadow system
4. Add missing trust signals section
5. Fix responsive issues at 768px and 320px

### Medium Priority
1. Refactor file cloud positions to algorithmic
2. Normalize icon animation timing
3. Consolidate animation systems
4. Add FAQ and comparison sections
5. Implement proper image optimization

### Low Priority (Polish)
1. Custom file type icons (replace Lucide)
2. Interactive before/after slider
3. Footer expansion
4. Ultrawide viewport optimization
5. Advanced scroll choreography

---

## Appendix: Design Token Recommendations

```ts
// Recommended tailwind.config.ts additions

const config = {
  theme: {
    extend: {
      // Modular scale (1.25 ratio)
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],
        'sm': ['0.875rem', { lineHeight: '1.25rem' }],
        'base': ['1rem', { lineHeight: '1.5rem' }],
        'lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'xl': ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
        '5xl': ['3rem', { lineHeight: '1.15' }],
        '6xl': ['3.75rem', { lineHeight: '1.1' }],
        '7xl': ['4.5rem', { lineHeight: '1.05' }],
      },

      // Semantic spacing
      spacing: {
        'section-sm': '3rem',    // 48px
        'section-md': '5rem',    // 80px
        'section-lg': '8rem',    // 128px
      },

      // Semantic opacity
      opacity: {
        'text-secondary': '0.7',
        'text-tertiary': '0.5',
        'text-disabled': '0.35',
        'border-subtle': '0.05',
        'border-light': '0.1',
        'border-medium': '0.2',
      },

      // Consolidated shadows
      boxShadow: {
        'card': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'card-hover': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'button': '0 4px 14px 0 rgba(0, 0, 0, 0.1)',
        'button-hover': '0 6px 20px 0 rgba(0, 0, 0, 0.15)',
        'modal': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        'file-card': '0 10px 18px -14px rgba(0, 0, 0, 0.25), 0 4px 10px -6px rgba(0, 0, 0, 0.12), inset 0 1px 0 rgba(255, 255, 255, 0.6)',
      },

      // Border radius system
      borderRadius: {
        'card': '0.5rem',       // 8px
        'button': '9999px',     // full
        'modal': '1rem',        // 16px
        'badge': '0.375rem',    // 6px
      },
    },
  },
};
```

---

**End of Design Critique**

*This document should be treated as a living specification. Update as issues are resolved and new patterns emerge.*
