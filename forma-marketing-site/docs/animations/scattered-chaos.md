# Scattered Chaos Animation

## Overview

**Purpose:** "Before" state visualization showing disorganized files
**Emotional Goal:** Disorder, stress, overwhelm (stylized/beautiful chaos)
**Duration:** 3000ms
**Loop:** true (seamless infinite loop)
**Trigger:** Visible on page load in hero/comparison section

---

## Forma Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| forma-warm-orange | `#C97E66` | Primary chaos accent, file icons |
| forma-warm-orange-light | `#D9A08E` | Secondary file icons |
| forma-cream | `#F5F2EB` | File document backgrounds |
| forma-charcoal | `#2D2D2D` | File icon details, outlines |
| forma-steel-blue | `#5B7C99` | Subtle accent on 1-2 files |

---

## File Icon Designs

### Icon Set (5 Total)

| Icon | Type | Size | Primary Color | Accent |
|------|------|------|---------------|--------|
| file-1 | Document (lines) | 32x40 | `#F5F2EB` | `#C97E66` corner fold |
| file-2 | Image (mountain) | 36x36 | `#F5F2EB` | `#5B7C99` thumbnail |
| file-3 | Spreadsheet (grid) | 30x38 | `#F5F2EB` | `#C97E66` cells |
| file-4 | PDF (badge) | 34x42 | `#F5F2EB` | `#D9A08E` badge |
| file-5 | Folder (open) | 40x32 | `#C97E66` | `#2D2D2D` outline |

### Icon Visual Style

- Rounded corners: 4px
- Stroke weight: 1.5px
- Drop shadow: `0 2px 8px rgba(45, 45, 45, 0.1)`
- Slight 3D perspective (subtle)

---

## Animation Sequence

### Global Container Settings

- Canvas size: 200x200px (scalable)
- Background: Transparent
- All 5 icons start at randomized positions within bounds

### Per-Icon Drift Animation

Each icon has independent, overlapping animations creating organic chaos.

#### File 1 - Document

| Property | Keyframe 0% | Keyframe 50% | Keyframe 100% | Easing |
|----------|-------------|--------------|---------------|--------|
| translateX | 0px | 12px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| translateY | 0px | -8px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| rotate | -5deg | 3deg | -5deg | ease-in-out |
| Duration | — | — | 3000ms | — |

**Starting position:** x: 30px, y: 45px

#### File 2 - Image

| Property | Keyframe 0% | Keyframe 50% | Keyframe 100% | Easing |
|----------|-------------|--------------|---------------|--------|
| translateX | 0px | -15px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| translateY | 0px | 10px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| rotate | 8deg | -2deg | 8deg | ease-in-out |
| Duration | — | — | 2700ms | — |

**Starting position:** x: 120px, y: 25px

#### File 3 - Spreadsheet

| Property | Keyframe 0% | Keyframe 50% | Keyframe 100% | Easing |
|----------|-------------|--------------|---------------|--------|
| translateX | 0px | 8px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| translateY | 0px | 14px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| rotate | -12deg | -4deg | -12deg | ease-in-out |
| Duration | — | — | 3400ms | — |

**Starting position:** x: 85px, y: 110px

#### File 4 - PDF

| Property | Keyframe 0% | Keyframe 50% | Keyframe 100% | Easing |
|----------|-------------|--------------|---------------|--------|
| translateX | 0px | -10px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| translateY | 0px | -12px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| rotate | 15deg | 7deg | 15deg | ease-in-out |
| Duration | — | — | 2900ms | — |

**Starting position:** x: 145px, y: 95px

#### File 5 - Folder

| Property | Keyframe 0% | Keyframe 50% | Keyframe 100% | Easing |
|----------|-------------|--------------|---------------|--------|
| translateX | 0px | 6px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| translateY | 0px | 8px | 0px | `cubic-bezier(0.45, 0.05, 0.55, 0.95)` |
| rotate | -3deg | 5deg | -3deg | ease-in-out |
| Duration | — | — | 3200ms | — |

**Starting position:** x: 55px, y: 135px

---

## Seamless Loop Technique

### Duration Offset Strategy

Each icon has a slightly different duration (2700ms - 3400ms) creating non-repeating patterns that feel organic. The master loop resets at 3000ms but individual icons continue their cycles.

### Crossfade Method (Alternative)

If exact loop is needed:
1. Duplicate entire animation group
2. Offset duplicate by 1500ms
3. Crossfade between groups at loop point
4. Creates imperceptible loop seam

---

## Figma Layer Structure

```
Frame: "scattered-chaos" (200x200)
├── Group: "floating-files"
│   ├── Component: "file-document"
│   │   ├── Rectangle: "page" (fill: #F5F2EB, corner-radius: 4px)
│   │   ├── Rectangle: "corner-fold" (fill: #C97E66)
│   │   └── Group: "lines"
│   │       ├── Line: "line-1"
│   │       ├── Line: "line-2"
│   │       └── Line: "line-3"
│   │
│   ├── Component: "file-image"
│   │   ├── Rectangle: "page" (fill: #F5F2EB)
│   │   └── Group: "thumbnail"
│   │       ├── Rectangle: "sky" (fill: #5B7C99)
│   │       └── Polygon: "mountain"
│   │
│   ├── Component: "file-spreadsheet"
│   │   ├── Rectangle: "page" (fill: #F5F2EB)
│   │   └── Group: "grid"
│   │       └── Rectangle[]: "cells" (6 cells, fill: #C97E66)
│   │
│   ├── Component: "file-pdf"
│   │   ├── Rectangle: "page" (fill: #F5F2EB)
│   │   └── Rectangle: "badge" (fill: #D9A08E, text: "PDF")
│   │
│   └── Component: "file-folder"
│       ├── Rectangle: "folder-back" (fill: #C97E66)
│       ├── Rectangle: "folder-tab" (fill: #C97E66)
│       └── Rectangle: "folder-front" (fill: #D9A08E)
│
└── Rectangle: "bounds" (no fill, for reference only)
```

---

## Magic Animator Setup

### Component Variants

Create each file icon as a component with animation variants:

1. **State: Position-A** (starting position)
2. **State: Position-B** (mid-animation position)

### Smart Animate Configuration

For each file component:
1. Create variant with transformed position/rotation
2. Set up Smart Animate between variants
3. Use "After delay" trigger to auto-play
4. Enable "Loop back" to create continuous animation

### Prototype Flow

```
file-1 Position-A → (Smart Animate, 1500ms) → Position-B → (Smart Animate, 1500ms) → Position-A
file-2 Position-A → (Smart Animate, 1350ms) → Position-B → (Smart Animate, 1350ms) → Position-A
file-3 Position-A → (Smart Animate, 1700ms) → Position-B → (Smart Animate, 1700ms) → Position-A
file-4 Position-A → (Smart Animate, 1450ms) → Position-B → (Smart Animate, 1450ms) → Position-A
file-5 Position-A → (Smart Animate, 1600ms) → Position-B → (Smart Animate, 1600ms) → Position-A
```

---

## CSS/Lottie Implementation Reference

```css
/* CSS Animation keyframes reference */
@keyframes float-1 {
  0%, 100% {
    transform: translate(0, 0) rotate(-5deg);
  }
  50% {
    transform: translate(12px, -8px) rotate(3deg);
  }
}

@keyframes float-2 {
  0%, 100% {
    transform: translate(0, 0) rotate(8deg);
  }
  50% {
    transform: translate(-15px, 10px) rotate(-2deg);
  }
}

/* Apply with staggered durations */
.file-1 { animation: float-1 3s ease-in-out infinite; }
.file-2 { animation: float-2 2.7s ease-in-out infinite; }
.file-3 { animation: float-1 3.4s ease-in-out infinite; }
.file-4 { animation: float-2 2.9s ease-in-out infinite; }
.file-5 { animation: float-1 3.2s ease-in-out infinite; }
```

---

## Visual Composition Guidelines

### Z-Index Layering

| Layer | Icon | Reason |
|-------|------|--------|
| 5 (top) | file-4 (PDF) | Draws attention |
| 4 | file-1 (Document) | Primary file type |
| 3 | file-5 (Folder) | Ironic - folder but still chaotic |
| 2 | file-2 (Image) | Supporting element |
| 1 (bottom) | file-3 (Spreadsheet) | Background element |

### Overlap Strategy

- 2-3 icons should slightly overlap at various points
- Never fully occlude any icon
- Maintain visual breathing room

### Shadow Consistency

All icons share the same shadow:
```css
box-shadow: 0 2px 8px rgba(45, 45, 45, 0.1);
```

---

## Export Settings

### For Lottie (Recommended)

1. Install LottieFiles plugin in Figma
2. Select the entire frame
3. Export as JSON
4. Settings:
   - Frame rate: 30fps (sufficient for subtle motion)
   - Quality: High
   - Include hidden layers: No

### For SVG + CSS

1. Export icons as individual SVGs
2. Compose in HTML with CSS animations
3. Use CSS custom properties for easy timing adjustments

### For Video Fallback

- Format: WebM (with MP4 fallback)
- Resolution: 400x400 (2x)
- Frame rate: 30fps
- Duration: 6000ms (2 full cycles for seamless loop)
- Background: Transparent

---

## Accessibility Considerations

- Animation respects `prefers-reduced-motion`
- Fallback: Static scattered layout (no motion)
- Decorative only - no ARIA labels needed
- Consider pause button for motion-sensitive users

---

## Implementation Checklist

- [ ] Design 5 file icon components in Figma
- [ ] Set up position variants for each icon
- [ ] Configure Smart Animate with staggered durations
- [ ] Test loop seamlessness in prototype
- [ ] Export to Lottie JSON
- [ ] Implement reduced-motion fallback
- [ ] Test performance on low-end devices
- [ ] Verify loop is truly seamless
