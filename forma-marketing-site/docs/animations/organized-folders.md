# Organized Folders Animation

## Overview

**Purpose:** "After" state visualization showing organized file structure
**Emotional Goal:** Order, calm, satisfaction, accomplishment
**Duration:** 1200ms
**Loop:** false (plays once on scroll into view)
**Trigger:** Intersection Observer when element enters viewport

---

## Forma Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| forma-sage | `#7A9D7E` | Primary folder color, success accent |
| forma-sage-light | `#9BB89E` | Folder highlights, hover states |
| forma-sage-dark | `#5C7A60` | Folder shadows, depth |
| forma-cream | `#F5F2EB` | Document previews peeking out |
| forma-charcoal | `#2D2D2D` | Labels, outlines |
| forma-warm-orange | `#C97E66` | Subtle accent (one folder tab) |

---

## Folder Icon Design

### Stack Configuration (3 Folders)

| Folder | Size | Position (Final) | Color | Label |
|--------|------|------------------|-------|-------|
| folder-1 (back) | 64x48 | x: 68, y: 100 | `#5C7A60` | "Archive" |
| folder-2 (middle) | 64x48 | x: 68, y: 90 | `#7A9D7E` | "Projects" |
| folder-3 (front) | 64x48 | x: 68, y: 80 | `#9BB89E` | "Active" |

### Folder Visual Style

- Corner radius: 6px (body), 4px (tab)
- Tab width: 24px
- Tab height: 8px
- Document peek: 4px visible above folder
- Drop shadow: `0 4px 12px rgba(45, 45, 45, 0.15)`

---

## Animation Sequence

### Phase 1: Scatter Entry (0ms - 200ms)

**What happens:** Folders appear from scattered positions, already rotating towards final state.

| Folder | Start Position | Start Rotation | Start Opacity |
|--------|----------------|----------------|---------------|
| folder-1 | x: 20, y: 160 | -15deg | 0 |
| folder-2 | x: 140, y: 40 | 20deg | 0 |
| folder-3 | x: 90, y: 180 | -8deg | 0 |

**Animation:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| opacity | 0 | 1 | `cubic-bezier(0.4, 0, 0.2, 1)` |

### Phase 2: Convergence (200ms - 700ms)

**What happens:** Folders fly toward center stack position with rotation correction.

#### Folder 1 (Back)

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| translateX | -48px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| translateY | 60px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| rotate | -15deg | 0deg | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| Delay | 0ms | — | — |

#### Folder 2 (Middle)

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| translateX | 72px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| translateY | -50px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| rotate | 20deg | 0deg | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| Delay | 50ms | — | — |

#### Folder 3 (Front)

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| translateX | 22px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| translateY | 100px | 0px | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| rotate | -8deg | 0deg | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| Delay | 100ms | — | — |

### Phase 3: Stack Bounce (700ms - 1000ms)

**What happens:** Folders settle with satisfying bounce as they stack.

| Property | Keyframe 0% (700ms) | Keyframe 50% (850ms) | Keyframe 100% (1000ms) |
|----------|---------------------|----------------------|------------------------|
| folder-1 translateY | 0px | -3px | 0px |
| folder-2 translateY | 0px | -5px | 0px |
| folder-3 translateY | 0px | -8px | 0px |
| scale (all) | 1.0 | 1.02 | 1.0 |

**Easing:** `cubic-bezier(0.34, 1.56, 0.64, 1)` (spring overshoot)

### Phase 4: Settle Glow (900ms - 1200ms)

**What happens:** Subtle success glow emanates from the stack.

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| box-shadow blur | 0px | 16px → 0px | ease-out |
| box-shadow color | transparent | `#7A9D7E40` → transparent | ease-out |
| scale | 1.02 | 1.0 | ease-out |

---

## Figma Layer Structure

```
Frame: "organized-folders" (200x200)
├── Group: "folder-stack"
│   ├── Component: "folder-1" (back, darkest)
│   │   ├── Rectangle: "folder-body" (fill: #5C7A60, corner-radius: 6px)
│   │   ├── Rectangle: "folder-tab" (fill: #5C7A60, corner-radius: 4px 4px 0 0)
│   │   ├── Rectangle: "document-peek" (fill: #F5F2EB, partial visibility)
│   │   └── Text: "label" (optional, "Archive")
│   │
│   ├── Component: "folder-2" (middle, medium)
│   │   ├── Rectangle: "folder-body" (fill: #7A9D7E)
│   │   ├── Rectangle: "folder-tab" (fill: #7A9D7E)
│   │   ├── Rectangle: "document-peek" (fill: #F5F2EB)
│   │   └── Text: "label" (optional, "Projects")
│   │
│   └── Component: "folder-3" (front, lightest)
│       ├── Rectangle: "folder-body" (fill: #9BB89E)
│       ├── Rectangle: "folder-tab" (fill: #C97E66) ← accent color
│       ├── Rectangle: "document-peek" (fill: #F5F2EB)
│       └── Text: "label" (optional, "Active")
│
├── Ellipse: "glow-effect" (blur: 16px, fill: #7A9D7E, opacity: 0.25)
└── Rectangle: "bounds" (no fill, for reference)
```

---

## Magic Animator Setup

### Component Variants

Create a component set with these variants:

1. **State: Scattered**
   - folder-1: x: 20, y: 160, rotate: -15deg, opacity: 0
   - folder-2: x: 140, y: 40, rotate: 20deg, opacity: 0
   - folder-3: x: 90, y: 180, rotate: -8deg, opacity: 0
   - glow-effect: opacity: 0

2. **State: Converging**
   - All folders moving toward center
   - opacity: 1
   - rotation reducing

3. **State: Bouncing**
   - All folders at final x position
   - translateY: -5px to -8px (peak of bounce)
   - scale: 1.02

4. **State: Settled**
   - folder-1: x: 68, y: 100, rotate: 0deg
   - folder-2: x: 68, y: 90, rotate: 0deg
   - folder-3: x: 68, y: 80, rotate: 0deg
   - glow-effect: opacity: 0

### Smart Animate Transitions

| From | To | Duration | Delay | Easing |
|------|-----|----------|-------|--------|
| Scattered | Converging | 200ms | 0ms | ease-out |
| Converging | Bouncing | 500ms | 0ms | spring |
| Bouncing | Settled | 300ms | 0ms | ease-out |
| — | glow pulse | 300ms | 900ms | ease-out |

### Prototype Configuration

```
Trigger: On scroll into view (or After delay 0ms for testing)
Action: Navigate to → Converging
Animation: Smart animate, 200ms, ease-out

Auto-continue chain:
Converging → Bouncing → Settled
```

---

## Spring Physics Reference

For the satisfying bounce effect, use these spring parameters:

| Parameter | Value | Description |
|-----------|-------|-------------|
| stiffness | 300 | How "snappy" the spring is |
| damping | 20 | How quickly oscillation stops |
| mass | 1 | Weight of the object |

**CSS cubic-bezier approximation:** `cubic-bezier(0.34, 1.56, 0.64, 1)`

This creates ~15% overshoot before settling, which feels satisfying without being cartoonish.

---

## CSS/Lottie Implementation Reference

```css
/* CSS Animation keyframes reference */
@keyframes folder-converge-1 {
  0% {
    transform: translate(-48px, 60px) rotate(-15deg);
    opacity: 0;
  }
  20% {
    opacity: 1;
  }
  100% {
    transform: translate(0, 0) rotate(0deg);
    opacity: 1;
  }
}

@keyframes folder-bounce {
  0%, 100% {
    transform: translateY(0) scale(1);
  }
  50% {
    transform: translateY(-8px) scale(1.02);
  }
}

@keyframes glow-pulse {
  0% {
    box-shadow: 0 0 0 0 rgba(122, 157, 126, 0);
  }
  50% {
    box-shadow: 0 0 16px 8px rgba(122, 157, 126, 0.25);
  }
  100% {
    box-shadow: 0 0 0 0 rgba(122, 157, 126, 0);
  }
}

/* Staggered application */
.folder-1 {
  animation: folder-converge-1 500ms cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
}
.folder-2 {
  animation: folder-converge-2 500ms cubic-bezier(0.34, 1.56, 0.64, 1) 50ms forwards;
}
.folder-3 {
  animation: folder-converge-3 500ms cubic-bezier(0.34, 1.56, 0.64, 1) 100ms forwards;
}
.folder-stack {
  animation: folder-bounce 300ms cubic-bezier(0.34, 1.56, 0.64, 1) 700ms;
}
.glow {
  animation: glow-pulse 300ms ease-out 900ms;
}
```

---

## Scroll Trigger Implementation

### Intersection Observer Setup

```javascript
// Reference implementation
const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate');
        observer.unobserve(entry.target); // Play only once
      }
    });
  },
  {
    threshold: 0.5, // Trigger when 50% visible
    rootMargin: '0px 0px -50px 0px' // Slight offset for better timing
  }
);

observer.observe(document.querySelector('.organized-folders'));
```

---

## Export Settings

### For Lottie (Recommended)

1. Install LottieFiles plugin in Figma
2. Select the component set
3. Export as JSON
4. Settings:
   - Frame rate: 60fps (for smooth bounce)
   - Quality: High
   - Include hidden layers: No

### For SVG + CSS

1. Export folder icons as SVG group
2. Apply CSS animations with delays
3. Use Intersection Observer for scroll trigger

### For Video Fallback

- Format: WebM (with MP4 fallback)
- Resolution: 400x400 (2x)
- Frame rate: 60fps
- Duration: 1200ms
- Background: Transparent
- Note: Include 200ms padding at end for clean stop

---

## Comparison Section Layout

When used alongside "scattered-chaos" animation:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   [Scattered Chaos]    →    [Organized Folders]         │
│   (looping chaos)            (plays on scroll)          │
│                                                         │
│   "Your files now"           "Your files with Forma"    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Transition Arrow

Consider animating the arrow between the two states:
- Subtle pulse or glow
- Color shifts from `#C97E66` to `#7A9D7E`
- Draws user's eye to the transformation

---

## Accessibility Considerations

- Animation respects `prefers-reduced-motion`
- Fallback: Static stacked folder image (final state)
- ARIA: Decorative only, `aria-hidden="true"`
- Ensure contrast meets WCAG AA for any text labels

---

## Implementation Checklist

- [ ] Design 3 folder components in Figma
- [ ] Create scattered and settled variants
- [ ] Configure Smart Animate with spring easing
- [ ] Add glow effect layer with animation
- [ ] Test stagger timing feels natural
- [ ] Export to Lottie JSON
- [ ] Implement Intersection Observer trigger
- [ ] Add reduced-motion fallback
- [ ] Test alongside scattered-chaos animation
- [ ] Verify one-time play behavior
