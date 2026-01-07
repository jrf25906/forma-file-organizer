# Connections Demo Animation

## Animation: Project Files Connecting

**Purpose:** Showcase Forma's intelligent understanding of file relationships - how it recognizes that related files belong together.

**Emotional Goal:** Convey intelligence and understanding. The animation should feel like witnessing a moment of insight - scattered pieces coming together into meaningful order.

**Total Duration:** 800ms

---

## Visual Narrative

Three related project files (a PDF document, a Figma design file, and a JSON config) begin scattered apart. They gracefully drift toward each other, stacking into a neat cluster while connection lines draw between them, visualizing their relationship.

---

## Forma Color Palette Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `--forma-obsidian` | `#1A1A1A` | Background |
| `--forma-bone` | `#FAFAF8` | Text, file cards |
| `--forma-steel-blue` | `#5B7C99` | PDF file accent, connection lines |
| `--forma-sage` | `#7A9D7E` | Figma file accent, success glow |
| `--forma-warm-orange` | `#C97E66` | JSON file accent |
| `--forma-muted-blue` | `#6B8CA8` | Secondary connection lines |

---

## Figma Layer Structure

```
Frame: connections-demo (400 x 280)
├── Background
│   └── Rectangle (fill: #1A1A1A, corner-radius: 16)
│
├── Connection-Lines (draw on top of files when stacked)
│   ├── Line-PDF-to-Figma (stroke: #5B7C99, dashed)
│   ├── Line-Figma-to-JSON (stroke: #7A9D7E, dashed)
│   └── Line-JSON-to-PDF (stroke: #C97E66, dashed)
│
├── Files-Container
│   ├── File-PDF (initially top-left)
│   │   ├── Card-BG (glass effect)
│   │   ├── Icon-PDF (document icon, #5B7C99)
│   │   ├── File-Name ("Project-Brief.pdf")
│   │   └── Accent-Bar (left edge, #5B7C99)
│   │
│   ├── File-Figma (initially top-right)
│   │   ├── Card-BG (glass effect)
│   │   ├── Icon-Figma (figma icon, #7A9D7E)
│   │   ├── File-Name ("UI-Mockups.fig")
│   │   └── Accent-Bar (left edge, #7A9D7E)
│   │
│   └── File-JSON (initially bottom-center)
│       ├── Card-BG (glass effect)
│       ├── Icon-JSON (code icon, #C97E66)
│       ├── File-Name ("config.json")
│       └── Accent-Bar (left edge, #C97E66)
│
├── Cluster-Container (final stacked position, center)
│   └── Stack-Shadow (layered shadow effect)
│
└── Glow-Effects
    ├── Connection-Glow-1 (along line paths)
    ├── Connection-Glow-2
    └── Unified-Glow (center, when clustered)
```

---

## Keyframe Breakdown

### Phase 1: Scattered State (0ms - 50ms)

**Initial Positions (slight random rotation for organic feel):**

| File | Position | Rotation |
|------|----------|----------|
| PDF | x: -80, y: -40 | -3deg |
| Figma | x: 90, y: -30 | 4deg |
| JSON | x: 10, y: 60 | -2deg |

**Subtle Breathing Animation:**
- Each card has a micro-float effect
- Creates "alive" feeling before movement

### Phase 2: Recognition Pulse (50ms - 150ms)

**Connection Lines Begin Drawing:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `stroke-dashoffset` | 100% | 50% | `power2.out` |
| `opacity` | 0 | 0.5 | `power2.out` |

**Files React:**
- Subtle glow appears on each file's accent bar
- Scale pulse to 1.03 (recognition moment)

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `scale` | 1.0 | 1.03 | `power2.out` |
| `accent-glow` | 0 | 0.6 | `power2.out` |

### Phase 3: Drift Together (150ms - 500ms)

**PDF Card Movement:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | -80 | 0 | `power3.inOut` |
| `y` | -40 | -24 | `power3.inOut` |
| `rotation` | -3deg | 0deg | `power2.out` |
| `z-index` | 1 | 3 (top) | - |

**Figma Card Movement (50ms delay):**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | 90 | 6 | `power3.inOut` |
| `y` | -30 | -12 | `power3.inOut` |
| `rotation` | 4deg | 1deg | `power2.out` |
| `z-index` | 2 | 2 (middle) | - |

**JSON Card Movement (100ms delay):**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | 10 | 12 | `power3.inOut` |
| `y` | 60 | 0 | `power3.inOut` |
| `rotation` | -2deg | 2deg | `power2.out` |
| `z-index` | 3 | 1 (bottom) | - |

### Phase 4: Connection Lines Complete (400ms - 650ms)

**Line Drawing Animation:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `stroke-dashoffset` | 50% | 0% | `power2.out` |
| `opacity` | 0.5 | 0.8 | `power2.out` |

**Line Glow Effect:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `filter: blur` | 0px | 4px | `power2.out` |
| `opacity` | 0 | 0.4 | `power2.out` |

### Phase 5: Settle & Unify (650ms - 800ms)

**Stack Settle:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `all cards scale` | 1.0 | 0.98 | `back.out(1.4)` |
| `shadow depth` | 4px | 16px | `power2.out` |

**Unified Glow:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `opacity` | 0 | 0.5 | `power2.out` |
| `scale` | 0.8 | 1.0 | `power2.out` |
| `blur` | 20px | 40px | `power2.out` |

**Connection Lines Fade to Subtle:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `opacity` | 0.8 | 0.4 | `power2.out` |

---

## Magic Animator Configuration

### Keyframe 1 (0ms) - Scattered
```
File-PDF:
  - x=-80, y=-40, rotation=-3deg, scale=1

File-Figma:
  - x=90, y=-30, rotation=4deg, scale=1

File-JSON:
  - x=10, y=60, rotation=-2deg, scale=1

Connection-Lines:
  - All: opacity=0, stroke-dashoffset=100%
```

### Keyframe 2 (100ms) - Recognition
```
File-PDF, File-Figma, File-JSON:
  - scale=1.03
  - accent-glow=0.6

Connection-Lines:
  - opacity=0.3, stroke-dashoffset=70%
```

### Keyframe 3 (350ms) - Mid-Drift
```
File-PDF:
  - x=-30, y=-30, rotation=-1deg

File-Figma:
  - x=35, y=-20, rotation=2deg

File-JSON:
  - x=10, y=20, rotation=0deg

Connection-Lines:
  - opacity=0.5, stroke-dashoffset=30%
```

### Keyframe 4 (550ms) - Clustered
```
File-PDF:
  - x=0, y=-24, rotation=0deg, z=3

File-Figma:
  - x=6, y=-12, rotation=1deg, z=2

File-JSON:
  - x=12, y=0, rotation=2deg, z=1

Connection-Lines:
  - opacity=0.8, stroke-dashoffset=0%
```

### Keyframe 5 (800ms) - Settled
```
All Files:
  - scale=0.98
  - shadow=deep

Connection-Lines:
  - opacity=0.4

Unified-Glow:
  - opacity=0.5, scale=1
```

---

## Timing & Easing Reference

| Phase | Duration | Forma Easing Token | CSS Equivalent |
|-------|----------|-------------------|----------------|
| Recognition Pulse | 100ms | `formaMagnetic` | `cubic-bezier(0.33, 1, 0.68, 1)` |
| Drift Together | 350ms | `formaReveal` | `cubic-bezier(0.16, 1, 0.3, 1)` |
| Line Drawing | 250ms | `formaReveal` | `cubic-bezier(0.16, 1, 0.3, 1)` |
| Settle | 150ms | `formaSettle` | `cubic-bezier(0.34, 1.56, 0.64, 1)` |

---

## Design Specifications

### File Card Design
```
Width: 120px
Height: 44px
Corner Radius: 10px
Background: linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.03))
Border: 1px solid rgba(255,255,255,0.1)
Shadow: 0 4px 12px rgba(0,0,0,0.15)

Accent Bar:
  - Width: 3px
  - Height: 100%
  - Position: Left edge
  - Corner Radius: 10px 0 0 10px (matches card left corners)

Icon: 24x24px
Text: #FAFAF8, 12px, font-weight: 500, truncate
```

### File Type Colors
```
PDF:    #5B7C99 (Steel Blue)
Figma:  #7A9D7E (Sage)
JSON:   #C97E66 (Warm Orange)
```

### Connection Line Design
```
Stroke Width: 2px
Stroke Style: Dashed (8px dash, 6px gap)
Stroke Linecap: Round
Opacity: 0.4 (settled state)

Glow Layer:
  - Same path
  - Stroke Width: 6px
  - Blur: 4px
  - Opacity: 0.3
```

### Stacked Cards Offset
```
Card 1 (bottom): x=12, y=0, rotation=2deg
Card 2 (middle): x=6, y=-12, rotation=1deg
Card 3 (top):    x=0, y=-24, rotation=0deg

Stack Shadow:
  - 0 8px 32px rgba(0,0,0,0.25)
  - 0 2px 8px rgba(0,0,0,0.15)
```

---

## Connection Line Paths

### Curved Bezier Paths (not straight lines)

**PDF to Figma:**
```svg
<path d="M [pdf-center] C [control1] [control2] [figma-center]" />
```
- Gentle arc curving upward
- Creates elegant flow

**Figma to JSON:**
```svg
<path d="M [figma-center] C [control1] [control2] [json-center]" />
```
- Curves downward to the right

**JSON to PDF:**
```svg
<path d="M [json-center] C [control1] [control2] [pdf-center]" />
```
- Completes the triangle, curves left

---

## Export Settings

### Lottie Export
- Frame Rate: 60fps
- Resolution: 2x (800 x 560)
- Format: JSON (Lottie)
- Compression: Enabled
- Preserve stroke-dasharray animation

### GIF Fallback
- Frame Rate: 30fps
- Colors: 128
- Loop: Once, then hold

### Video Export
- Format: WebM (VP9) + MP4 (H.264)
- Resolution: 800 x 560 @ 2x
- Duration: 800ms + 1200ms hold

---

## Accessibility Notes

- Animation respects `prefers-reduced-motion`: Shows static clustered state with visible connection lines
- Text alternative: "Three related project files (PDF, Figma, JSON) connect and stack together"
- Connection lines use sufficient opacity (0.4+) against dark background
- Each file type has distinct color coding for differentiation

---

## Implementation Checklist

- [ ] Create base Figma frame at 400x280
- [ ] Design three file card variants with accent bars
- [ ] Create curved Bezier path connection lines
- [ ] Set up stroke-dashoffset animation for line drawing
- [ ] Configure z-index changes during stacking
- [ ] Add glow layers for connection lines
- [ ] Set up Magic Animator keyframes
- [ ] Test timing feels like "moment of insight"
- [ ] Export Lottie JSON
- [ ] Create GIF fallback
- [ ] Test reduced-motion alternative

---

## Related Files

- Brand easing curves: `src/lib/animation/ease-curves.ts`
- Color tokens: `src/app/globals.css` (`:root` section)
- Component styles: `tailwind.config.ts` (Forma colors)
