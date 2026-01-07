# Forma Brand Assets Guide

**Last Updated:** January 2025
**Status:** Canonical assets defined

---

## Quick Reference

| Asset | Canonical File | Usage |
|-------|----------------|-------|
| **Logo Mark** | `Resources/Brand/logo-mark.svg` | In-app branding, about screens |
| **Logo (Asset Catalog)** | `Assets.xcassets/logo-mark.imageset/` | SwiftUI `Image("logo-mark")` |
| **App Icon** | `Assets.xcassets/AppIcon.appiconset/` | Dock, App Store, Finder |
| **Menu Bar Icon** | `Resources/Brand/menu-bar-icon.svg` | macOS menu bar |

---

## The Forma Logo: Pure Grid V2

The canonical Forma logo is a **3x3 grid of rounded squares** with a vertical opacity gradient, representing organized structure and hierarchy.

```
┌───┐ ┌───┐ ┌───┐   ← Row 1: 100% opacity
│   │ │   │ │   │
└───┘ └───┘ └───┘

┌───┐ ┌───┐ ┌───┐   ← Row 2: 70% opacity
│   │ │   │ │   │
└───┘ └───┘ └───┘

┌───┐ ┌───┐ ┌───┐   ← Row 3: 40% opacity
│   │ │   │ │   │
└───┘ └───┘ └───┘
```

### Design Specifications

- **Grid**: 3x3 squares with 16px gap
- **Square size**: 96x96px (at 512px canvas)
- **Corner radius**: 8px
- **Color**: Obsidian `#1A1A1A`
- **Opacity gradient**: 100% → 70% → 40% (top to bottom)

### Symbolism

- **Grid structure**: Organization, order, categorization
- **Opacity fade**: Depth, layers, hierarchy of importance
- **Rounded corners**: Modern, approachable, macOS-native

---

## File Locations

### Primary (Use These)

```
Forma File Organizing/
├── Resources/
│   └── Brand/
│       ├── logo-mark.svg          ← Canonical logo (512x512, dark fill)
│       ├── logo-mark-light.svg    ← Light variant (for dark backgrounds)
│       ├── logo-lockup.svg        ← Logo + wordmark
│       └── menu-bar-icon.svg      ← Menu bar template icon
│
└── Assets.xcassets/
    ├── logo-mark.imageset/        ← For SwiftUI Image()
    │   ├── Contents.json
    │   └── logo-mark.svg
    │
    └── AppIcon.appiconset/        ← macOS app icon (all sizes)
        ├── Contents.json
        └── icon_*.png             ← Required sizes: 16-1024px
```

### Marketing (Synced)

```
forma-marketing-site/public/
├── logo.svg                       ← Same as logo-mark.svg
├── logo-light.svg                 ← Inverted for dark backgrounds
└── logo-menubar.svg               ← Menu bar version
```

---

## Usage in Code

### SwiftUI

```swift
// Use the asset catalog version
Image("logo-mark")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 64, height: 64)
```

### NSImage (AppKit)

```swift
if let logo = NSImage(named: "logo-mark") {
    // Use logo
}
```

---

## App Icon Generation

The app icon (`AppIcon.appiconset`) requires PNG files at specific sizes for macOS:

| Size | Scale | Filename |
|------|-------|----------|
| 16x16 | 1x | icon_16x16.png |
| 16x16 | 2x | icon_16x16@2x.png (32px) |
| 32x32 | 1x | icon_32x32.png |
| 32x32 | 2x | icon_32x32@2x.png (64px) |
| 128x128 | 1x | icon_128x128.png |
| 128x128 | 2x | icon_128x128@2x.png (256px) |
| 256x256 | 1x | icon_256x256.png |
| 256x256 | 2x | icon_256x256@2x.png (512px) |
| 512x512 | 1x | icon_512x512.png |
| 512x512 | 2x | icon_512x512@2x.png (1024px) |

### Regenerating App Icons

To regenerate from the source SVG:

```bash
# Using sips (macOS built-in)
sips -z 1024 1024 logo-mark.svg --out icon_1024.png

# Then generate all sizes
for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size icon_1024.png --out "icon_${size}x${size}.png"
done
```

Or use a tool like [App Icon Generator](https://appicon.co/) with the 1024px source.

---

## Menu Bar Icon

The menu bar icon uses **template image** rendering so macOS automatically adapts it to light/dark mode.

**Specifications:**
- Size: 16x16px (template)
- Color: Single color (system handles inversion)
- Style: Simplified grid silhouette for legibility at small sizes

---

## Color Variants

### Dark Background (Default)

- Fill: `#1A1A1A` (Obsidian)
- Works on: Light backgrounds, white surfaces

### Light Background

- Fill: `#FAFAF8` (Bone White)
- Works on: Dark backgrounds, dark mode UI
- Files: `logo-mark-light.svg` (Brand folder), `logo-light.svg` (marketing site)

---

## Related Documentation

- **Brand Guidelines**: `Docs/Design/Forma-Brand-Guidelines.md`
- **Brand Overview**: `Docs/Design/BRAND-OVERVIEW.md`
- **Logo Design Brief**: `Docs/Design/LOGO_DESIGN_BRIEF.md`
- **Logo Exploration**: `forma-marketing-site/LOGO_EXPLORATION.md`

---

## Changelog

### January 2025
- Established Pure Grid V2 (3x3 grid) as canonical logo
- Updated `logo-mark.svg` in Brand folder and Asset Catalog
- Added `logo-mark-light.svg` for dark backgrounds
- Created this documentation
- **Cleaned up deprecated files:**
  - Deleted old `app-icon*.svg` variations from Brand folder
  - Deleted `logo-concept-*.svg`, `logo-grid-*.svg`, `logo-pure-grid-v1-v5.svg` from marketing site
  - Only canonical files remain to prevent confusion
