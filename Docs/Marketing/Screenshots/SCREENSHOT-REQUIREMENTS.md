# Forma Press Kit: Screenshot Requirements

**Purpose**: Capture app screenshots for press kit, App Store, and marketing materials.
**Target**: Mid-January 2025 launch

---

## Required Screenshots (Priority Order)

### 1. Hero Shot — Main Window
**State**: Main window with files in queue, showing preview panel
**Why it matters**: First impression; demonstrates the "layer on top of Finder" concept
**Ideal content**: 5-8 files pending organization, one selected showing destination preview

### 2. Rule Builder
**State**: Rule creation interface with a natural-language rule being constructed
**Why it matters**: Shows the "declarative rules" value proposition
**Ideal content**: Rule like "Move screenshots older than 7 days to Screenshots/Archive"

### 3. Undo History Panel
**State**: Action history showing recent moves with rollback options
**Why it matters**: Core differentiator — full reversibility
**Ideal content**: 4-6 completed actions, clear "Undo" affordance

### 4. Preview Queue
**State**: Multiple files queued for organization, showing proposed destinations
**Why it matters**: Demonstrates "preview before commit" philosophy
**Ideal content**: Mix of file types (screenshots, PDFs, images) with folder destinations

### 5. Before/After Transform
**State**: Split or comparison showing messy files → organized structure
**Why it matters**: Proof of necessity — shows real value
**Example**: `Screenshot 2024-*.png` files → `Screenshots/2024-01/` folder

### 6. Menu Bar Integration
**State**: Menu bar icon with dropdown showing status
**Why it matters**: Shows unobtrusive, always-available nature

### 7. Empty State (Optional)
**State**: App with no files to organize
**Why it matters**: Shows polish and onboarding quality

---

## Screenshot Specifications

| Format | Dimensions | Use Case |
|--------|------------|----------|
| **App Store** | 2880 × 1800 (retina) or 1440 × 900 | Mac App Store listing |
| **Press Kit** | 1920 × 1200 minimum | Press/media use |
| **Hero** | 2560 × 1600 or higher | Website hero section |
| **Social** | 1200 × 630 (OG) | Social media sharing |

---

## Capture Instructions

1. **Clean window chrome**: Hide any debug indicators
2. **Sample data**: Use realistic but professional file names
3. **Window position**: Center on screen, no wallpaper distractions
4. **Light mode preferred**: For press kit consistency (dark mode as alternates)

### Quick Capture Command
```bash
# Window capture with shadow
screencapture -W -o ~/Desktop/forma-screenshot.png

# Window capture without shadow (cleaner for compositing)
screencapture -W -o -x ~/Desktop/forma-screenshot-noshadow.png
```

---

## File Naming Convention

```
forma-{screen}-{variant}-{date}.png

Examples:
forma-main-window-light-20250113.png
forma-rule-builder-light-20250113.png
forma-undo-history-dark-20250113.png
```

---

## Notes

- Ensure sample files don't contain sensitive information
- Consider preparing "demo data" folder for consistent screenshots
- Capture both light and dark mode for full press kit
