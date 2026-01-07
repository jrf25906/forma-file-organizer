# Natural Language Demo Animation

## Animation: Files Sliding to Archive Folder

**Purpose:** Demonstrate effortless, magical file organization through natural language commands.

**Emotional Goal:** Evoke a sense of wonder and delight - files move with intention, as if understanding the user's wishes.

**Total Duration:** 700ms

---

## Visual Narrative

Two screenshot files gracefully slide toward an Archive folder icon, fading as they approach. The folder materializes with a satisfying "+2 files" badge, confirming the action completed.

---

## Forma Color Palette Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `--forma-obsidian` | `#1A1A1A` | Background, shadows |
| `--forma-bone` | `#FAFAF8` | Text, file cards |
| `--forma-steel-blue` | `#5B7C99` | Folder accent, badges |
| `--forma-sage` | `#7A9D7E` | Success states, subtle glow |
| `--forma-warm-orange` | `#C97E66` | Highlight accents |

---

## Figma Layer Structure

```
Frame: natural-language-demo (360 x 240)
├── Background
│   └── Rectangle (fill: #1A1A1A, corner-radius: 16)
│
├── Files-Container
│   ├── File-Card-1
│   │   ├── Card-BG (glass effect, rgba(255,255,255,0.08))
│   │   ├── Thumbnail (placeholder image)
│   │   ├── File-Name ("Screenshot-2024-01...")
│   │   └── File-Meta ("PNG • 2.4 MB")
│   │
│   └── File-Card-2
│       ├── Card-BG (glass effect, rgba(255,255,255,0.08))
│       ├── Thumbnail (placeholder image)
│       ├── File-Name ("Screenshot-2024-01...")
│       └── File-Meta ("PNG • 1.8 MB")
│
├── Archive-Folder (initially hidden/scaled down)
│   ├── Folder-Icon (SF Symbol style, #5B7C99)
│   ├── Folder-Label ("Archive")
│   └── Badge-Container
│       ├── Badge-BG (pill shape, #7A9D7E)
│       └── Badge-Text ("+2 files", #FAFAF8)
│
└── Glow-Effects
    └── Destination-Glow (radial gradient, rgba(91,124,153,0.3))
```

---

## Keyframe Breakdown

### Phase 1: Anticipation (0ms - 100ms)

**File Cards:**
- Subtle scale up to 1.02
- Add gentle lift shadow
- Creates "ready to move" feeling

| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `scale` | 1.0 | 1.02 | `power2.out` |
| `box-shadow` | 0 4px 12px rgba(0,0,0,0.15) | 0 8px 24px rgba(0,0,0,0.25) | `power2.out` |

### Phase 2: Slide & Fade (100ms - 450ms)

**File Card 1 (leads):**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | 0 | -140px | `power3.inOut` |
| `opacity` | 1 | 0 | `power2.in` |
| `scale` | 1.02 | 0.85 | `power2.in` |

**File Card 2 (follows, 50ms delay):**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `x` | 0 | -120px | `power3.inOut` |
| `opacity` | 1 | 0 | `power2.in` |
| `scale` | 1.02 | 0.85 | `power2.in` |

### Phase 3: Folder Reveal (350ms - 550ms)

**Archive Folder:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `opacity` | 0 | 1 | `power2.out` |
| `scale` | 0.8 | 1.0 | `back.out(1.7)` |
| `y` | 15px | 0 | `back.out(1.7)` |

**Destination Glow:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `opacity` | 0 | 0.6 | `power2.out` |
| `scale` | 0.5 | 1.2 | `power2.out` |

### Phase 4: Badge Pop (500ms - 700ms)

**Badge Container:**
| Property | Start | End | Easing |
|----------|-------|-----|--------|
| `opacity` | 0 | 1 | `power2.out` |
| `scale` | 0.5 | 1.0 | `elastic.out(1, 0.5)` |
| `y` | 8px | 0 | `power2.out` |

---

## Magic Animator Configuration

### Keyframe 1 (0ms) - Initial State
```
Files-Container:
  - File-Card-1: opacity=1, x=0, y=0, scale=1
  - File-Card-2: opacity=1, x=0, y=60, scale=1

Archive-Folder:
  - opacity=0, scale=0.8, y=15

Badge-Container:
  - opacity=0, scale=0.5
```

### Keyframe 2 (100ms) - Anticipation
```
Files-Container:
  - File-Card-1: scale=1.02, shadow=elevated
  - File-Card-2: scale=1.02, shadow=elevated
```

### Keyframe 3 (350ms) - Mid-Slide
```
Files-Container:
  - File-Card-1: opacity=0.3, x=-80, scale=0.92
  - File-Card-2: opacity=0.5, x=-60, scale=0.95

Archive-Folder:
  - opacity=0.5, scale=0.9
```

### Keyframe 4 (500ms) - Files Gone, Folder Revealed
```
Files-Container:
  - File-Card-1: opacity=0, x=-140, scale=0.85
  - File-Card-2: opacity=0, x=-120, scale=0.85

Archive-Folder:
  - opacity=1, scale=1, y=0

Destination-Glow:
  - opacity=0.6
```

### Keyframe 5 (700ms) - Final State
```
Archive-Folder:
  - opacity=1, scale=1

Badge-Container:
  - opacity=1, scale=1

Destination-Glow:
  - opacity=0.3 (settled)
```

---

## Timing & Easing Reference

| Phase | Duration | Forma Easing Token | CSS Equivalent |
|-------|----------|-------------------|----------------|
| Anticipation | 100ms | `formaMagnetic` | `cubic-bezier(0.33, 1, 0.68, 1)` |
| Slide | 350ms | `formaExit` | `cubic-bezier(0.55, 0, 1, 0.45)` |
| Folder Reveal | 200ms | `formaSettle` | `cubic-bezier(0.34, 1.56, 0.64, 1)` |
| Badge Pop | 200ms | `formaSnap` | `elastic.out(1, 0.5)` |

---

## Design Specifications

### File Card Design
```
Width: 140px
Height: 52px
Corner Radius: 12px
Background: linear-gradient(135deg, rgba(255,255,255,0.08), rgba(255,255,255,0.03))
Border: 1px solid rgba(255,255,255,0.1)
Shadow: 0 4px 12px rgba(0,0,0,0.15)

Thumbnail: 36x36px, corner-radius: 8px
Text Primary: #FAFAF8, 13px, font-weight: 500
Text Secondary: rgba(250,250,248,0.6), 11px
```

### Folder Icon Design
```
Size: 48x48px
Color: #5B7C99
Style: SF Symbol "folder.fill" or equivalent
Glow: 0 0 20px rgba(91,124,153,0.4)
```

### Badge Design
```
Height: 22px
Padding: 0 10px
Corner Radius: 11px (pill)
Background: #7A9D7E
Text: #FAFAF8, 12px, font-weight: 600
```

---

## Export Settings

### Lottie Export
- Frame Rate: 60fps
- Resolution: 2x (720 x 480)
- Format: JSON (Lottie)
- Compression: Enabled

### GIF Fallback
- Frame Rate: 30fps
- Colors: 128
- Loop: Once, then hold on final frame

### Video Export
- Format: WebM (VP9) + MP4 (H.264)
- Resolution: 720 x 480 @ 2x
- Duration: 700ms + 1000ms hold

---

## Accessibility Notes

- Animation respects `prefers-reduced-motion`: Shows static before/after states
- Provide text alternative: "Two screenshot files organized into Archive folder"
- Ensure sufficient color contrast for all text elements
- Badge color (#7A9D7E) on dark background meets WCAG AA

---

## Implementation Checklist

- [ ] Create base Figma frame at 360x240
- [ ] Design file card components with glass effect
- [ ] Create archive folder with badge variant
- [ ] Set up layer naming for Magic Animator
- [ ] Configure keyframes in Magic Animator timeline
- [ ] Test easing curves match Forma brand feel
- [ ] Export Lottie JSON
- [ ] Create GIF fallback for email/legacy
- [ ] Test reduced-motion alternative

---

## Related Files

- Brand easing curves: `src/lib/animation/ease-curves.ts`
- Color tokens: `src/app/globals.css` (`:root` section)
- Component styles: `tailwind.config.ts` (Forma colors)
