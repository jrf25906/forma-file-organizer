# Control Demo Animation

## Animation: Approval Checkmarks

**Purpose:** Demonstrate user control in the review process - showing how users approve file organization suggestions one by one.

**Emotional Goal:** Convey control, satisfaction, and progress. Each checkmark should feel like a small victory, building momentum and confidence.

**Total Duration:** 600ms (200ms staggered per item)

---

## Visual Narrative

Three file items appear in a review list. Each receives a checkmark in sequence, accompanied by a sliding highlight effect that washes across the row, confirming the approval. The staggered timing creates a satisfying cascade of completion.

---

## Forma Color Palette Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `--forma-obsidian` | `#1A1A1A` | Background |
| `--forma-bone` | `#FAFAF8` | Text, icons |
| `--forma-steel-blue` | `#5B7C99` | Unchecked state |
| `--forma-sage` | `#7A9D7E` | Checkmark, success highlight |
| `--forma-soft-green` | `#8BA688` | Highlight sweep |

---

## Figma Layer Structure

```
Frame: control-demo (320 x 200)
├── Background
│   └── Rectangle (fill: #1A1A1A, corner-radius: 16)
│
├── Review-List
│   ├── File-Row-1
│   │   ├── Row-BG (glass effect)
│   │   ├── Highlight-Sweep (initially hidden, left of frame)
│   │   ├── Checkbox-Container
│   │   │   ├── Checkbox-BG (circle, border: #5B7C99)
│   │   │   └── Checkmark-Icon (initially scale=0, #7A9D7E)
│   │   ├── File-Icon (document icon)
│   │   ├── File-Name ("Q4-Report.pdf")
│   │   └── Destination-Label ("-> Finance/Reports")
│   │
│   ├── File-Row-2
│   │   ├── Row-BG
│   │   ├── Highlight-Sweep
│   │   ├── Checkbox-Container
│   │   │   ├── Checkbox-BG
│   │   │   └── Checkmark-Icon
│   │   ├── File-Icon
│   │   ├── File-Name ("Invoice-Nov.pdf")
│   │   └── Destination-Label ("-> Finance/Invoices")
│   │
│   └── File-Row-3
│       ├── Row-BG
│       ├── Highlight-Sweep
│       ├── Checkbox-Container
│       │   ├── Checkbox-BG
│       │   └── Checkmark-Icon
│       ├── File-Icon
│       ├── File-Name ("Budget-2024.xlsx")
│       └── Destination-Label ("-> Finance/Budgets")
│
└── Progress-Indicator (optional)
    ├── Progress-BG
    └── Progress-Fill (animates with completions)
```

---

## Keyframe Breakdown

### Timing Overview

| Item | Check Start | Check Complete | Highlight Complete |
|------|-------------|----------------|-------------------|
| Row 1 | 0ms | 120ms | 200ms |
| Row 2 | 200ms | 320ms | 400ms |
| Row 3 | 400ms | 520ms | 600ms |

---

### Row Animation Sequence (repeated for each row with 200ms stagger)

#### Micro-Phase A: Checkbox Transform (0ms - 60ms per row)

**Checkbox Background:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `border-color` | #5B7C99 | #7A9D7E | `power2.out` |
| `background` | transparent | rgba(122,157,126,0.15) | `power2.out` |
| `scale` | 1.0 | 0.95 | `power2.in` |

#### Micro-Phase B: Checkmark Pop (40ms - 120ms per row)

**Checkmark Icon:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `scale` | 0 | 1.0 | `elastic.out(1, 0.5)` |
| `opacity` | 0 | 1 | `power2.out` |
| `rotation` | -45deg | 0deg | `back.out(2)` |

**Checkbox Background (bounce back):**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `scale` | 0.95 | 1.0 | `elastic.out(1, 0.6)` |

#### Micro-Phase C: Highlight Sweep (80ms - 200ms per row)

**Highlight-Sweep Layer:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | -100% (off left) | 100% (off right) | `power2.inOut` |
| `opacity` | 0 -> 0.4 -> 0 | - | - |

**Row Background:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `background` | rgba(255,255,255,0.05) | rgba(122,157,126,0.08) | `power2.out` |

---

## Magic Animator Configuration

### Keyframe 1 (0ms) - Initial State
```
File-Row-1, File-Row-2, File-Row-3:
  - Checkbox-BG: border-color=#5B7C99, background=transparent
  - Checkmark-Icon: scale=0, opacity=0
  - Highlight-Sweep: x=-100%, opacity=0
  - Row-BG: background=rgba(255,255,255,0.05)
```

### Keyframe 2 (60ms) - Row 1 Checkbox Pressed
```
File-Row-1:
  - Checkbox-BG: scale=0.95, border-color=#7A9D7E
  - Checkmark-Icon: scale=0.3, opacity=0.5
```

### Keyframe 3 (120ms) - Row 1 Check Complete
```
File-Row-1:
  - Checkbox-BG: scale=1, background=rgba(122,157,126,0.15)
  - Checkmark-Icon: scale=1, opacity=1, rotation=0
  - Highlight-Sweep: x=0%, opacity=0.4
```

### Keyframe 4 (200ms) - Row 1 Done, Row 2 Starting
```
File-Row-1:
  - Highlight-Sweep: x=100%, opacity=0
  - Row-BG: background=rgba(122,157,126,0.08)

File-Row-2:
  - Checkbox-BG: scale=0.95, border-color=#7A9D7E
```

### Keyframe 5 (320ms) - Row 2 Check Complete
```
File-Row-2:
  - Checkbox-BG: scale=1, background=rgba(122,157,126,0.15)
  - Checkmark-Icon: scale=1, opacity=1
  - Highlight-Sweep: x=0%, opacity=0.4
```

### Keyframe 6 (400ms) - Row 2 Done, Row 3 Starting
```
File-Row-2:
  - Highlight-Sweep: x=100%, opacity=0
  - Row-BG: background=rgba(122,157,126,0.08)

File-Row-3:
  - Checkbox-BG: scale=0.95, border-color=#7A9D7E
```

### Keyframe 7 (520ms) - Row 3 Check Complete
```
File-Row-3:
  - Checkbox-BG: scale=1, background=rgba(122,157,126,0.15)
  - Checkmark-Icon: scale=1, opacity=1
  - Highlight-Sweep: x=0%, opacity=0.4
```

### Keyframe 8 (600ms) - All Complete
```
File-Row-3:
  - Highlight-Sweep: x=100%, opacity=0
  - Row-BG: background=rgba(122,157,126,0.08)

All Rows:
  - Checkmark visible, green tint on backgrounds
```

---

## Timing & Easing Reference

| Phase | Duration | Forma Easing Token | CSS Equivalent |
|-------|----------|-------------------|----------------|
| Checkbox Press | 60ms | `formaExit` | `cubic-bezier(0.55, 0, 1, 0.45)` |
| Checkmark Pop | 80ms | `formaSnap` | `elastic.out(1, 0.5)` |
| Highlight Sweep | 120ms | `formaReveal` | `cubic-bezier(0.16, 1, 0.3, 1)` |
| Stagger Delay | 200ms | - | - |

---

## Design Specifications

### Row Design
```
Width: 280px
Height: 48px
Corner Radius: 12px
Background: rgba(255,255,255,0.05)
Border: 1px solid rgba(255,255,255,0.08)
Padding: 8px 12px
Gap: 12px (between elements)

Checked State Background: rgba(122,157,126,0.08)
```

### Checkbox Design
```
Size: 24px x 24px
Border Radius: 50% (circle)
Border: 2px solid #5B7C99

Checked State:
  - Border: 2px solid #7A9D7E
  - Background: rgba(122,157,126,0.15)

Checkmark:
  - Size: 14px
  - Color: #7A9D7E
  - Stroke Width: 2.5px
  - Style: Rounded linecap
```

### Checkmark SVG Path
```svg
<svg width="14" height="14" viewBox="0 0 14 14">
  <path
    d="M2 7.5L5.5 11L12 3"
    stroke="#7A9D7E"
    stroke-width="2.5"
    stroke-linecap="round"
    stroke-linejoin="round"
    fill="none"
  />
</svg>
```

### Highlight Sweep Design
```
Width: 100%
Height: 100%
Background: linear-gradient(
  90deg,
  transparent 0%,
  rgba(122,157,126,0.25) 30%,
  rgba(139,166,136,0.4) 50%,
  rgba(122,157,126,0.25) 70%,
  transparent 100%
)
Blend Mode: Overlay
```

### Text Styles
```
File Name:
  - Color: #FAFAF8
  - Size: 14px
  - Weight: 500

Destination Label:
  - Color: rgba(250,250,248,0.6)
  - Size: 12px
  - Weight: 400
  - Style: Italic or with arrow prefix
```

### File Icon
```
Size: 20px x 20px
Color: rgba(250,250,248,0.7)
Style: Document outline
```

---

## Optional: Progress Indicator

If including a progress bar at the bottom:

```
Progress Bar:
  - Width: 100%
  - Height: 3px
  - Background: rgba(255,255,255,0.1)
  - Corner Radius: 1.5px

Progress Fill:
  - Background: linear-gradient(90deg, #5B7C99, #7A9D7E)
  - Width: 0% -> 33% -> 66% -> 100%
  - Animates with each checkmark completion
  - Easing: power2.out
```

---

## Export Settings

### Lottie Export
- Frame Rate: 60fps
- Resolution: 2x (640 x 400)
- Format: JSON (Lottie)
- Compression: Enabled

### GIF Fallback
- Frame Rate: 30fps
- Colors: 64 (simpler palette)
- Loop: Once, hold on final frame

### Video Export
- Format: WebM (VP9) + MP4 (H.264)
- Resolution: 640 x 400 @ 2x
- Duration: 600ms + 800ms hold

---

## Accessibility Notes

- Animation respects `prefers-reduced-motion`: Shows static completed state with all items checked
- Text alternative: "Three file items being approved with checkmarks in sequence"
- Checkboxes have sufficient size (24px) for touch targets
- Color is not the only indicator - checkmark icon provides shape differentiation
- Green (#7A9D7E) on dark background meets WCAG AA for UI elements

---

## Micro-interaction Details

### Haptic Feedback Correlation (for native implementation)
- Checkbox press: Light tap
- Checkmark appear: Medium impact
- All complete: Success notification

### Sound Design Hints (optional)
- Soft "tick" sound per checkmark
- Satisfying completion chime at end
- Keep sounds subtle and optional

---

## Implementation Checklist

- [ ] Create base Figma frame at 320x200
- [ ] Design file row component with all states
- [ ] Create checkbox with unchecked/checked variants
- [ ] Design checkmark with proper SVG path
- [ ] Create highlight sweep gradient layer
- [ ] Set up stagger timing (200ms intervals)
- [ ] Configure elastic easing for checkmark pop
- [ ] Add optional progress indicator
- [ ] Test the cascade timing feels satisfying
- [ ] Export Lottie JSON
- [ ] Create GIF fallback
- [ ] Test reduced-motion alternative

---

## Related Files

- Brand easing curves: `src/lib/animation/ease-curves.ts`
- Color tokens: `src/app/globals.css` (`:root` section)
- Component styles: `tailwind.config.ts` (Forma colors)
- Stagger timing reference: `formaStagger.cascade` = 0.08
