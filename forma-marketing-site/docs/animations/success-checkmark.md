# Success Checkmark Animation

## Overview

**Purpose:** Beta signup confirmation animation
**Emotional Goal:** Accomplishment, welcome, delight
**Duration:** 800ms
**Loop:** false (plays once on signup success)
**Trigger:** Form submission success callback

---

## Forma Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| forma-sage | `#7A9D7E` | Primary checkmark, circle stroke |
| forma-sage-light | `#9BB89E` | Particle bursts |
| forma-cream | `#F5F2EB` | Background glow |
| forma-charcoal | `#2D2D2D` | Optional dark mode variant |

---

## Animation Sequence

### Phase 1: Circle Draw (0ms - 300ms)

**What happens:** A circular outline draws itself clockwise from the top.

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| stroke-dashoffset | 283 (2πr, hidden) | 0 (fully drawn) | `cubic-bezier(0.4, 0, 0.2, 1)` |
| opacity | 0 | 1 | linear |
| scale | 0.8 | 1 | `cubic-bezier(0.34, 1.56, 0.64, 1)` |

**Circle specs:**
- Diameter: 48px
- Stroke width: 3px
- Stroke color: `#7A9D7E` (forma-sage)
- Fill: none
- Stroke-linecap: round

### Phase 2: Checkmark Stroke (200ms - 550ms)

**What happens:** Checkmark draws in with slight overshoot.

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| stroke-dashoffset | 32 (path length) | 0 | `cubic-bezier(0.65, 0, 0.35, 1)` |
| opacity | 0 | 1 | linear (instant at 200ms) |

**Checkmark specs:**
- Path: `M14 24 L21 31 L34 18` (relative to 48x48 viewbox)
- Stroke width: 3px
- Stroke color: `#7A9D7E` (forma-sage)
- Stroke-linecap: round
- Stroke-linejoin: round

### Phase 3: Particle Burst (400ms - 800ms)

**What happens:** 8 subtle particles burst outward and fade.

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| transform (translate) | 0px from center | 16-24px radially outward | `cubic-bezier(0, 0.55, 0.45, 1)` |
| opacity | 0.8 | 0 | `cubic-bezier(0.4, 0, 1, 1)` |
| scale | 1 | 0.5 | linear |

**Particle specs:**
- Count: 8 particles
- Shape: Circle
- Size: 4px diameter
- Color: `#9BB89E` (forma-sage-light)
- Distribution: Evenly spaced at 45-degree intervals
- Stagger: 20ms between each particle

### Phase 4: Settle Pulse (550ms - 800ms)

**What happens:** Entire icon does a subtle "breathing" pulse.

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| scale | 1.0 | 1.05 → 1.0 | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| filter: drop-shadow | 0px 0px 0px | 0px 0px 8px `#7A9D7E40` → 0px | ease-out |

---

## Figma Layer Structure

```
Frame: "success-checkmark" (48x48)
├── Group: "particles"
│   ├── Ellipse: "particle-1" (4x4, positioned at 45°)
│   ├── Ellipse: "particle-2" (4x4, positioned at 90°)
│   ├── Ellipse: "particle-3" (4x4, positioned at 135°)
│   ├── Ellipse: "particle-4" (4x4, positioned at 180°)
│   ├── Ellipse: "particle-5" (4x4, positioned at 225°)
│   ├── Ellipse: "particle-6" (4x4, positioned at 270°)
│   ├── Ellipse: "particle-7" (4x4, positioned at 315°)
│   └── Ellipse: "particle-8" (4x4, positioned at 360°)
├── Ellipse: "circle-outline" (48x48, stroke only)
└── Vector: "checkmark" (stroke path)
```

---

## Magic Animator Setup

### Component Variants

Create a component set with these variants:

1. **State: Initial**
   - All layers hidden (opacity: 0)
   - Circle scale: 0.8
   - Checkmark stroke-dashoffset: 100%

2. **State: Complete**
   - All layers visible
   - Circle fully drawn
   - Checkmark fully drawn
   - Particles at final expanded + faded position

### Smart Animate Transitions

| From | To | Duration | Easing |
|------|-----|----------|--------|
| Initial | Complete | 800ms | Custom spring |

### Prototype Settings

- **Trigger:** After delay (0ms) or On click
- **Action:** Smart animate
- **Destination:** Complete state
- **Animation:** Smart animate, 800ms

---

## CSS/Lottie Implementation Reference

```css
/* CSS Animation keyframes reference */
@keyframes circle-draw {
  0% {
    stroke-dashoffset: 283;
    opacity: 0;
    transform: scale(0.8);
  }
  100% {
    stroke-dashoffset: 0;
    opacity: 1;
    transform: scale(1);
  }
}

@keyframes checkmark-draw {
  0% {
    stroke-dashoffset: 32;
  }
  100% {
    stroke-dashoffset: 0;
  }
}

@keyframes particle-burst {
  0% {
    transform: translate(0, 0) scale(1);
    opacity: 0.8;
  }
  100% {
    transform: translate(var(--tx), var(--ty)) scale(0.5);
    opacity: 0;
  }
}
```

---

## Export Settings

### For Lottie (Recommended)

1. Install LottieFiles plugin in Figma
2. Select the component set
3. Export as JSON
4. Settings:
   - Frame rate: 60fps
   - Quality: High
   - Include hidden layers: No

### For SVG Animation

1. Export SVG from Figma
2. Ensure "Include id attribute" is checked
3. Add CSS animations manually or use GSAP

### For GIF/Video Fallback

- Format: WebM or MP4
- Resolution: 96x96 (2x)
- Frame rate: 60fps
- Background: Transparent

---

## Accessibility Considerations

- Animation respects `prefers-reduced-motion`
- Fallback: Static checkmark icon appears instantly
- ARIA: `role="status"` with `aria-live="polite"`
- Screen reader: "Signup successful" announcement

---

## Implementation Checklist

- [ ] Create Figma component set with variants
- [ ] Configure Smart Animate transitions
- [ ] Test animation timing in prototype
- [ ] Export to Lottie JSON
- [ ] Implement reduced-motion fallback
- [ ] Test on mobile devices
- [ ] Verify color contrast accessibility
