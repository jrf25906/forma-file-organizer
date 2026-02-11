# Forma Design System — Quick Reference

Token and component reference for the Forma file organizer app. All values sourced from the `DesignSystem/` directory.

---

## Color Tokens (FormaColors.swift)

### Brand Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `formaObsidian` | #1A1A1A | Primary dark, text, dark mode backgrounds |
| `formaBoneWhite` | #FAFAF8 | Primary light, light mode backgrounds |
| `formaSteelBlue` | #5B7C99 | Interactive accent, primary actions, links |
| `formaSage` | #7A9D7E | Success accent, confirmations |

### Category Colors
| Token | Hex | Category |
|-------|-----|----------|
| `formaMutedBlue` | #6B8CA8 | Documents/Text files |
| `formaWarmOrange` | #C97E66 | Media/Images |
| `formaSoftGreen` | #8BA688 | Downloads/Archives |

### Semantic Colors (auto dark/light)
- `formaBackground` — Window background
- `formaControlBackground` — Control backgrounds
- `formaTextBackground` — Text field backgrounds
- `formaCardBackground` — Card backgrounds
- `formaLabel` — Primary text
- `formaSecondaryLabel` — Secondary text
- `formaTertiaryLabel` — Metadata/timestamps
- `formaSecondaryLabelHigh` — Secondary text (extra contrast for glass)
- `formaTertiaryLabelHigh` — Tertiary text (extra contrast)
- `formaQuaternaryLabel` — Placeholder text
- `formaSeparator` — Borders and dividers
- `formaSuccess` / `formaWarning` / `formaError` / `formaInfo` — Status colors

### Glass Tints (macOS 26.0+)
`glassBlue`, `glassGreen`, `glassOrange`, `glassMutedBlue`, `glassSoftGreen`

### Opacity System (Color.FormaOpacity)
| Token | Value | Usage |
|-------|-------|-------|
| `ultraSubtle` | 0.02 | Barely visible tints |
| `subtle` | 0.05 | Light backgrounds, hover states |
| `light` | 0.10 | Glass effects |
| `medium` | 0.20 | Borders and dividers |
| `overlay` | 0.30 | Modal backgrounds |
| `strong` | 0.50 | Active states |
| `high` | 0.70 | Near-solid elements |
| `prominent` | 0.80 | High emphasis overlays |

---

## Typography (FormaTypography.swift)

### Scale
| Token | Size/Weight | Usage |
|-------|-------------|-------|
| `formaHero` | 32pt Bold | Welcome screens |
| `formaH1` | 24pt Semibold | Screen headers |
| `formaH2` | 20pt Semibold | Section divisions |
| `formaH3` | 17pt Semibold | Subsection headers |
| `formaBodyLarge` | 15pt Regular | Emphasized body |
| `formaBody` | 13pt Regular | Standard UI text |
| `formaBodyMedium` | 13pt Medium | Slightly emphasized |
| `formaBodySemibold` | 13pt Semibold | Inline labels |
| `formaCompact` | 12pt Regular | Compact elements |
| `formaCompactMedium` | 12pt Medium | Compact emphasized |
| `formaCompactSemibold` | 12pt Semibold | Compact labels |
| `formaSmall` | 11pt Regular | Timestamps, counts |
| `formaSmallMedium` | 11pt Medium | Emphasized metadata |
| `formaSmallSemibold` | 11pt Semibold | Small labels |
| `formaCaption` | 10pt Regular | Fine print |
| `formaCaptionSemibold` | 10pt Semibold | Small badges |
| `formaMicro` | 9pt Medium | Tiny indicators |

### Display Fonts (Libre Baskerville — Onboarding)
- `formaDisplayHero` — 34pt Italic
- `formaDisplayHeading` — 24pt Italic
- `formaDisplaySubheading` — 20pt Bold

### Monospace
- `formaMono` — 13pt SF Mono Regular
- `formaMonoSmall` — 11pt SF Mono Regular

### View Modifiers
`formaHeroStyle()`, `formaH1Style()`, `formaH2Style()`, `formaH3Style()`, `formaBodyStyle()`, `formaSecondaryStyle()`, `formaMetadataStyle()`, `formaMonoStyle()`

---

## Spacing (FormaSpacing.swift)

### 8pt Grid
| Token | Value | Usage |
|-------|-------|-------|
| `micro` | 4px | Icon-to-text, tight |
| `tight` | 8px | Related elements |
| `standard` | 16px | Default spacing |
| `generous` | 24px | Between sections |
| `large` | 32px | Major breaks |
| `extraLarge` | 48px | Screen margins |
| `huge` | 64px | Hero sections |

### Component-Specific
- `Button.vertical` / `.horizontal` — 8 / 16
- `Card.all` — 16
- `Form.fieldSpacing` / `.sectionSpacing` — 16 / 32
- `Screen.minMargin` — 24
- `Window.minWidth` / `.minHeight` — 600 / 400
- `Window.preferredWidth` / `.preferredHeight` — 1400 / 970

### Spacing Modifiers
`formaPadding()` (16), `formaPaddingTight()` (8), `formaPaddingGenerous()` (24), `formaButtonPadding()`, `formaCardPadding()`, `formaVerticalSpacing()` (16/2)

---

## Corner Radius (FormaRadius)

| Token | Value | Usage |
|-------|-------|-------|
| `none` | 0 | Sharp corners |
| `micro` | 4 | Badges, tags |
| `small` | 6 | Small controls |
| `control` | 8 | Text fields, buttons |
| `card` | 12 | Cards, panels, sheets |
| `large` | 16 | Large cards |
| `pill` | 999 | Fully rounded |

Modifiers: `formaCardRadius()`, `formaControlRadius()`, `formaPillRadius()`, `formaRadius(_ r:)` — all use `.continuous` style.

---

## Animation (FormaAnimation.swift)

### Durations
| Token | Value | Usage |
|-------|-------|-------|
| `microDuration` | 0.15s | Hover, press |
| `standardDuration` | 0.25s | State changes |
| `disclosureDuration` | 0.20s | Expand/collapse |
| `premiumDuration` | 0.30s | Hero elements |
| `largeDuration` | 0.40s | Modal appear |

### Easing Curves
- `defaultEasing` — `.easeInOut(0.25s)`
- `buttonEasing` — `.easeOut(0.15s)`
- `springEasing` — `.spring(response: 0.3, dampingFraction: 0.8)`
- `premiumSpring` — `.spring(response: 0.4, dampingFraction: 0.75)`
- `gentleSpring` — `.spring(response: 0.35, dampingFraction: 0.85)`
- `responsiveSpring` — `.interactiveSpring(response: 0.25, dampingFraction: 0.7)`

### Animation Modifiers
- `formaAnimation(value:, reduceMotion:)` — Standard with accessibility
- `formaButtonAnimation(value:)` — Button press
- `formaSpringAnimation(value:)` — Spring with accessibility
- `formaHoverEffect(scale:, opacity:)` — Subtle hover
- `premiumCardHover(scale:, shadow:, brightness:)` — Premium card hover
- `formaPressEffect()` — Press-down
- `formaBounce(trigger:)` — Bounce on trigger
- `formaPulse(isActive:)` — Gentle pulse
- `formaShimmer(isActive:)` — Shimmer loading
- `formaSlideIn(from:, delay:)` — Slide in from edge

### Transitions
`.formaSlide`, `.formaFade`, `.formaScale`

---

## Materials (FormaMaterialTiers.swift)

### Tiers (FormaMaterialTier enum)
| Tier | Usage | Specular | Shadow |
|------|-------|----------|--------|
| `base` | Background surfaces | 0.4 (light) | Subtle |
| `raised` | Floating elements | 0.6 (medium) | Elevated |
| `overlay` | Modals | 1.0 (strong) | Prominent |

### FormaMaterialSurface
```swift
FormaMaterialSurface(tier: .raised, cornerRadius: FormaRadius.card, tint: .glassBlue) {
    ContentView()
}
```
- Glass effect on macOS 26.0+, VisualEffectView fallback
- Specular rim overlay
- Respects `reduceTransparency`

Modifier: `.formaMaterialTier(_ tier:, cornerRadius:, tint:)`

---

## Shadows (FormaShadowLevel)

| Level | Radius | Y-Offset | Color |
|-------|--------|----------|-------|
| `card` | 4 | 2 | obsidian @ 0.10 |
| `cardSelected` | 8 | 3 | steelBlue @ 0.20 |
| `floating` | 16 | 4 | obsidian @ 0.20 |
| `button` | 4 | 2 | obsidian @ 0.10 |
| `none` | — | — | — |

Usage: `.formaShadow(.card)`

---

## Key Components

### FormaActionButton (Components/Shared/)
Styles: `.icon` (32x32), `.compact` (28x28), `.grid` (32x32)
```swift
FormaActionButton.icon(icon: "arrow.right", color: .formaSteelBlue, tooltip: "Move", action: move)
FormaActionButton.compact(icon: "trash", color: .formaError, tooltip: "Delete", action: delete)
FormaActionButton.grid(icon: "eye", color: .formaSteelBlue, isPrimary: true, tooltip: "Preview", action: preview)
```

### FormaCheckbox (Components/Shared/)
Sizes: `.compact` (18), `.standard` (20), `.large` (22)
```swift
FormaCheckbox.premium(isSelected: $selected, isVisible: isHovered, action: toggle)
FormaCheckbox.compact(isSelected: $selected, action: toggle)
FormaCheckbox.grid(isSelected: $selected, action: toggle)  // Circle shape
```

### FormaMaterialSurface
See Materials section above.

### FormaControlChrome (DesignSystem/)
Segmented control metrics and palette. Container radius 8, selected 6, height 24.

### Other Components
- `FormaPrimaryButton` / `FormaSecondaryButton` — Standard buttons
- `FormaCard` — Generic card container with selection state
- `FormaProgressBar` — 2pt animated fill bar
- `FormaStatusPill` — Status capsule (pending/ready/completed/skipped)
- `FormaBadge` — Versatile badge (small/regular/large, filled/outlined/subtle)
- `FormaEmptyState` — Empty state with icon, text, optional action
- `FormaStatBadge` — Metric display (value + label)
- `FormaHeroIcon` — Large icons for empty states
- `FormaListButton` — Navigation list items with hover/chevron

---

## Multi-View Mode Checklist

When implementing features that affect file display, update ALL three components:

| Component | View Mode | File |
|-----------|-----------|------|
| `FileRow` | Card view | `Views/Components/FileRow.swift` |
| `FileListRow` | List view | `Components/FileListRow.swift` |
| `FileGridItem` | Grid view | `Components/FileGridItem.swift` |

Each supports density variants (`.tight`, `.balanced`, `.spacious`) and shares:
- Category accent rail (2pt)
- FormaCheckbox selection
- FormaStatusPill indicator
- Action callbacks
- Search match badge
- FormaThumbnail variants (`.premium`, `.compact`, `.grid`)

Update call sites in `MainContentView.swift` (`cardView`, `listView`, `gridView`).
