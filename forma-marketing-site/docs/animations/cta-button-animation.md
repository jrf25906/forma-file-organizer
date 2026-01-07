# AnimatedCTAButton Lottie Animation Specification

> Design specification for the "Join the Beta" CTA button hover animation in the Forma marketing site.

---

## 1. Animation Overview

### Emotional Intent

This animation communicates **effortless organization**. When users hover over the CTA button, scattered files gracefully flow into a welcoming folder, conveying:

- **Simplicity**: Chaos transforms into order without effort
- **Delight**: A moment of joy that rewards curiosity
- **Trust**: Visual proof that Forma handles file organization elegantly
- **Action**: Encourages the click by previewing the product's core value

### Visual Metaphor

Three diverse file types (representing the variety of files users deal with) find their home in a single, organized destination. This mirrors Forma's promise: no matter what files you have, we'll help you organize them.

---

## 2. Keyframe Breakdown

### Canvas Setup

- **Artboard Size**: 48 x 48px (matches button icon area)
- **Safe Zone**: 4px padding on all sides
- **Working Area**: 40 x 40px centered

---

### Frame 1: Idle State (0%)

**Description**: Three file icons scattered in a loose triangular formation.

```
Visual Layout:
        [DOC]
          
    [IMG]     [CODE]
```

| Element | Position (x, y) | Size | Rotation | Opacity |
|---------|-----------------|------|----------|---------|
| Document Icon | 24, 8 | 12 x 14px | -8deg | 100% |
| Image Icon | 10, 28 | 12 x 12px | 5deg | 100% |
| Code Icon | 38, 26 | 10 x 12px | -3deg | 100% |

**File Icon Designs**:

- **Document**: Rounded rectangle with 2 horizontal lines (forma-obsidian stroke)
- **Image**: Rounded rectangle with mountain/sun glyph (forma-steel-blue fill)
- **Code**: Rounded rectangle with `</>` symbol (forma-sage fill)

**State**: Static, waiting for hover trigger.

---

### Frame 2: Movement Initiated (30%)

**Description**: Files begin their journey toward the center. Slight rotation correction begins.

```
Visual Layout:
      [DOC]
        ↓
   [IMG] → ← [CODE]
```

| Element | Position (x, y) | Size | Rotation | Opacity |
|---------|-----------------|------|----------|---------|
| Document Icon | 24, 14 | 12 x 14px | -4deg | 100% |
| Image Icon | 16, 24 | 12 x 12px | 2deg | 100% |
| Code Icon | 32, 24 | 10 x 12px | -1deg | 100% |

**Motion Characteristics**:
- Files move inward with **anticipation** (slight overshoot preparation)
- Rotation normalizing begins
- No scale change yet

---

### Frame 3: Folder Appears (60%)

**Description**: Folder materializes at center via scale-up. Files converge tightly around the folder opening.

```
Visual Layout:
     [DOC]
       ↓
   [FOLDER]
    ↑     ↑
 [IMG]   [CODE]
```

| Element | Position (x, y) | Size | Rotation | Opacity | Scale |
|---------|-----------------|------|----------|---------|-------|
| **Folder** | 24, 24 | 20 x 16px | 0deg | 100% | 100% (from 0%) |
| Document Icon | 24, 12 | 10 x 12px | 0deg | 90% | 85% |
| Image Icon | 18, 20 | 10 x 10px | 0deg | 90% | 85% |
| Code Icon | 30, 20 | 8 x 10px | 0deg | 90% | 85% |

**Folder Design**:
- Front flap: forma-sage (#7A9D7E) with 20% darker shade for depth
- Body: forma-sage with subtle inner shadow
- Opening: 2px gap between flap and body

**Motion Characteristics**:
- Folder scales from 0% to 100% with **spring overshoot** (peaks at 110%, settles to 100%)
- Files shrink slightly as they approach (perspective depth)
- Opacity reduces to 90% to begin "entering" effect

---

### Frame 4: Absorption Complete (100%)

**Description**: Files fully absorbed into folder. Folder delivers a subtle, satisfying pulse.

```
Visual Layout:

    [FOLDER]
      ✨
```

| Element | Position (x, y) | Size | Rotation | Opacity | Scale |
|---------|-----------------|------|----------|---------|-------|
| **Folder** | 24, 24 | 20 x 16px | 0deg | 100% | 100% → 105% → 100% |
| Document Icon | 24, 24 | 0 x 0px | 0deg | 0% | 0% |
| Image Icon | 24, 24 | 0 x 0px | 0deg | 0% | 0% |
| Code Icon | 24, 24 | 0 x 0px | 0deg | 0% | 0% |

**Motion Characteristics**:
- Files scale to 0% and fade out simultaneously
- All files converge to folder center point (24, 24)
- Folder pulse: scale 100% → 105% → 100% over final 150ms
- Optional: Subtle glow ring emanates from folder (forma-sage at 30% opacity)

---

## 3. Timing Specification

### Total Duration

**Recommended**: 700ms (0.7 seconds)

This duration balances:
- Fast enough to feel responsive
- Slow enough to appreciate the motion
- Matches typical hover dwell time

### Timeline Breakdown

| Phase | Duration | Cumulative | Description |
|-------|----------|------------|-------------|
| **Idle → Movement** | 0-210ms | 0-30% | Files begin moving |
| **Movement → Convergence** | 210-420ms | 30-60% | Folder appears, files converge |
| **Convergence → Absorption** | 420-700ms | 60-100% | Files absorbed, folder pulses |

### Easing Curves

```css
/* Primary movement easing */
--ease-file-movement: cubic-bezier(0.34, 1.56, 0.64, 1);
/* Spring-like overshoot for playful feel */

/* Folder appearance */
--ease-folder-appear: cubic-bezier(0.175, 0.885, 0.32, 1.275);
/* Anticipation + overshoot */

/* Folder pulse */
--ease-pulse: cubic-bezier(0.4, 0, 0.2, 1);
/* Smooth settle */

/* File fade-out */
--ease-fade: cubic-bezier(0.4, 0, 1, 1);
/* Accelerating fade */
```

### Figma/Magic Animator Easing Translation

| Curve Name | Figma Smart Animate | Magic Animator Preset |
|------------|--------------------|-----------------------|
| File Movement | Custom Bezier | "Spring - Gentle" |
| Folder Appear | Custom Bezier | "Spring - Bouncy" |
| Pulse | Ease Out | "Ease Out - Quad" |
| Fade | Ease In | "Ease In - Quad" |

---

## 4. Color Palette

### Primary Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| forma-bone | `#F5F2ED` | 245, 242, 237 | Background, file icon fills |
| forma-obsidian | `#1A1A1A` | 26, 26, 26 | Strokes, document lines |
| forma-steel-blue | `#5B7C99` | 91, 124, 153 | Image icon accent |
| forma-sage | `#7A9D7E` | 122, 157, 126 | Folder, code icon accent |

### Derived Colors

| Name | Hex | Derivation | Usage |
|------|-----|------------|-------|
| forma-sage-dark | `#5C7E60` | sage - 20% lightness | Folder depth shadow |
| forma-sage-glow | `#7A9D7E4D` | sage @ 30% opacity | Pulse glow ring |
| forma-obsidian-soft | `#1A1A1A80` | obsidian @ 50% opacity | Stroke on hover |

### Color Application by Element

```
DOCUMENT ICON
├── Fill: forma-bone
├── Stroke: forma-obsidian (1px)
└── Lines: forma-obsidian-soft (0.5px)

IMAGE ICON
├── Fill: forma-bone
├── Stroke: forma-obsidian (1px)
├── Mountain: forma-steel-blue
└── Sun: forma-steel-blue @ 60%

CODE ICON
├── Fill: forma-bone
├── Stroke: forma-obsidian (1px)
└── </> Symbol: forma-sage

FOLDER
├── Body: forma-sage
├── Flap: forma-sage
├── Flap Shadow: forma-sage-dark
├── Opening Gap: transparent
└── Glow Ring: forma-sage-glow
```

---

## 5. Figma Layer Structure

### Naming Convention

Use this exact naming structure for Magic Animator compatibility:

```
CTA-Button-Animation (Frame: 48x48)
│
├── 📁 folder-group
│   ├── folder-glow-ring (Ellipse) [hidden initially]
│   ├── folder-body (Rectangle, rounded)
│   └── folder-flap (Rectangle, rounded)
│
├── 📁 files-group
│   ├── 📁 file-document
│   │   ├── doc-body (Rectangle, rounded)
│   │   ├── doc-line-1 (Line)
│   │   └── doc-line-2 (Line)
│   │
│   ├── 📁 file-image
│   │   ├── img-body (Rectangle, rounded)
│   │   ├── img-mountain (Path)
│   │   └── img-sun (Ellipse)
│   │
│   └── 📁 file-code
│       ├── code-body (Rectangle, rounded)
│       └── code-symbol (Text: </>)
│
└── 📁 _export-bounds (hidden, Frame: 48x48)
```

### Layer Properties for Animation

| Layer | Animatable Properties |
|-------|----------------------|
| folder-group | opacity, scale, x, y |
| folder-glow-ring | opacity, scale |
| file-document | x, y, rotation, scale, opacity |
| file-image | x, y, rotation, scale, opacity |
| file-code | x, y, rotation, scale, opacity |

### Smart Animate Keyframe Frames

Create these as separate Figma frames for Smart Animate:

```
1. CTA-Animation-Idle
2. CTA-Animation-30pct
3. CTA-Animation-60pct  
4. CTA-Animation-100pct
```

Each frame contains the exact layer positions/states described in Section 2.

---

## 6. Magic Animator Setup

### Step-by-Step Configuration

1. **Import Layers**
   - Select all layers in `CTA-Button-Animation`
   - Ensure layer names match specification exactly
   - Group structure must be preserved

2. **Create Animation Timeline**
   ```
   Timeline: 700ms
   ├── 0ms: Idle state
   ├── 210ms: Movement keyframe
   ├── 420ms: Convergence keyframe
   └── 700ms: Complete keyframe
   ```

3. **Apply Easing per Element**
   
   | Element | Easing | Start | End |
   |---------|--------|-------|-----|
   | file-document | Spring Gentle | 0ms | 420ms |
   | file-image | Spring Gentle | 0ms | 420ms |
   | file-code | Spring Gentle | 0ms | 420ms |
   | folder-group | Spring Bouncy | 180ms | 420ms |
   | folder-glow-ring | Ease Out | 550ms | 700ms |

4. **Stagger Timing (Optional Enhancement)**
   - file-document: starts at 0ms
   - file-image: starts at 30ms
   - file-code: starts at 60ms
   - Creates a "cascade" effect

---

## 7. Export Settings

### Lottie JSON Configuration

```json
{
  "exportSettings": {
    "format": "lottie",
    "filename": "cta-button-files-to-folder",
    "frameRate": 60,
    "quality": "high"
  },
  "optimizations": {
    "flattenGroups": false,
    "optimizePaths": true,
    "removeDuplicates": true,
    "precision": 2
  },
  "dimensions": {
    "width": 48,
    "height": 48,
    "preserveAspectRatio": true
  }
}
```

### Export Checklist

- [ ] Frame rate: 60fps (smooth on all devices)
- [ ] File size target: < 15KB (aim for 8-12KB)
- [ ] Validate JSON with [LottieFiles Validator](https://lottiefiles.com/tools/json-editor)
- [ ] Test on [LottieFiles Preview](https://lottiefiles.com/preview)
- [ ] Verify colors match hex values exactly
- [ ] Confirm loop setting: `"loop": false` (plays once per hover)

### Integration Code Reference

```tsx
// React component usage
<AnimatedCTAButton
  animationData={ctaButtonAnimation}
  playOnHover={true}
  speed={1}
  style={{ width: 48, height: 48 }}
/>
```

---

## 8. Accessibility Considerations

### Motion Preferences

```css
@media (prefers-reduced-motion: reduce) {
  .cta-animation {
    /* Show static folder icon instead */
    animation: none;
  }
}
```

### Implementation Notes

- Animation should **not** autoplay
- Trigger only on `:hover` or `:focus`
- Provide static fallback for reduced motion preference
- Ensure button remains clickable during animation

---

## 9. Testing Checklist

### Visual QA

- [ ] Colors match Forma palette exactly
- [ ] Animation plays smoothly at 60fps
- [ ] No visual artifacts at keyframe transitions
- [ ] Folder pulse is subtle, not distracting
- [ ] Files disappear cleanly (no popping)

### Interaction QA

- [ ] Animation triggers immediately on hover
- [ ] Hover-out mid-animation handles gracefully
- [ ] Rapid hover in/out doesn't cause glitches
- [ ] Animation completes before allowing re-trigger
- [ ] Focus state triggers same animation

### Performance QA

- [ ] Lottie JSON < 15KB
- [ ] No jank on low-end devices
- [ ] Battery-efficient (minimal repaints)

---

## 10. File Deliverables

After completing the animation, deliver:

| File | Format | Location |
|------|--------|----------|
| Source Design | `.fig` | `/design/animations/` |
| Lottie Animation | `.json` | `/public/animations/cta-button-files-to-folder.json` |
| Static Fallback | `.svg` | `/public/icons/folder-organized.svg` |
| Preview GIF | `.gif` | `/docs/animations/cta-preview.gif` |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-06 | Design Team | Initial specification |

---

*This specification is part of the Forma Design System. For questions, contact the design team.*
