# Forma UI Guidelines

This document outlines the UI design standards for the Forma File Organizing app, ensuring compliance with macOS Human Interface Guidelines (HIG).

## Design Excellence Goal

**Forma is being built to win an Apple Design Award.**

This is not hyperbole—it's our quality bar. Every pixel, interaction, and animation is evaluated against the standard set by Apple Design Award winners. We're creating a showcase of what macOS applications can be when design excellence is prioritized equally with functionality.

### What This Means

- **Zero tolerance for "good enough"**: If it doesn't feel refined, it gets refined
- **Details matter**: Shadows, borders, hover states, spacing—everything contributes to the whole
- **Native mastery**: We use macOS materials (frosted glass, vibrancy) not as decoration but as intentional design choices
- **Subtle > Flashy**: Restraint and refinement over attention-seeking effects
- **User delight through craft**: The app should feel like it was made by someone who cares deeply

## Table of Contents
1. [Design System Overview](#design-system-overview)
2. [Apple Design Principles](#apple-design-principles)
3. [Typography](#typography)
4. [Spacing](#spacing)
5. [Colors](#colors)
6. [Visual Hierarchy & Depth](#visual-hierarchy--depth)
7. [Components](#components)
8. [Layout Standards](#layout-standards)
9. [Accessibility](#accessibility)
10. [macOS HIG Compliance](#macos-hig-compliance)

---

## Design System Overview

Forma uses a custom design system defined in `DesignSystem/DesignSystem.swift` that provides consistent colors, typography, spacing, and layout values across the entire application.

### Philosophy
- **Apple Design Award excellence**: Our quality bar for all design decisions
- **Native macOS feel** with modern polish
- **Consistency** across all views and components
- **Accessibility-first** design decisions
- **4-point grid system** for spacing
- **Refined subtlety** over flashy effects

---

## Apple Design Principles

Every UI decision follows Apple's core design principles:

### 1. Clarity
**Content is paramount.** The interface should never compete with the content for attention.

- Text is legible at every size with proper contrast
- Icons and symbols are precise and clearly communicate function
- Visual hierarchy guides the eye naturally through the interface
- Selection states are immediately obvious (gradient backgrounds, colored borders, enhanced shadows)

**Implementation:**
- File cards use layered visual feedback (background + border + shadow) for selection
- Action toolbar has clear hierarchy: one prominent action, secondary actions collapsed
- Typography scale creates clear information hierarchy

### 2. Deference
**The interface helps people understand and interact with content but never competes with it.**

- Subtle use of bezels, gradients, and translucency
- Minimal visual weight in UI chrome
- Content (files) always remains the focus
- Interactions are discoverable but not intrusive

**Implementation:**
- Frosted glass action bar with subtle gradient border instead of solid colored bar
- Hover actions appear gently, don't demand attention
- Card borders are present but understated (1px, 8% opacity)

### 3. Depth
**Visual layers and realistic motion convey hierarchy and impart vitality.**

- Distinct visual layers help establish hierarchy and impart vitality
- Realistic motion heightens the sense of depth
- Subtle shadows and blur create spatial relationships

**Implementation:**
- Selected cards "lift" with enhanced shadows (8px radius vs 4px)
- Frosted glass creates depth through translucency
- Proper elevation: cards feel like physical objects you can interact with
- Hover scale effect is subtle (1.005x, not 1.01x) for refined feel

### 4. Subtlety
**Refined interactions and visual details create delight without overwhelming.**

- Gentle animations that feel natural
- Gradients used purposefully, not decoratively
- Shadows are layered and realistic
- Color choices are restrained and meaningful

**Implementation:**
- Selection gradient: Steel Blue 12% → 8% (subtle, not heavy)
- Border transitions smoothly on selection (40% → 60% opacity)
- Shadow color changes to match selection state (black → steel blue tint)
- Animations use easeInOut with appropriate durations (0.15s for hovers)

---

## Typography

All typography follows a clear hierarchy using SF Pro (system default). Tokens are defined in `DesignSystem/FormaTypography.swift`.

### Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `formaHero` | 32pt | Bold | Landing pages, major headings |
| `formaH1` | 24pt | Semibold | Page titles |
| `formaH2` | 20pt | Semibold | Section headers |
| `formaH3` | 17pt | Regular | Subsection headers, icons |
| `formaBodyLarge` | 15pt | Regular | Large body text, buttons |
| `formaBody` | 13pt | Regular | Body text, labels |
| `formaCompact` | 12pt | Regular | Compact UI, toolbar icons |
| `formaSmall` | 11pt | Regular | Secondary text |
| `formaCaption` | 10pt | Regular | Metadata, section headers |

### Weight Variants

Each size has weight variants for flexibility:
- Regular (default)
- Medium (e.g., `.formaBodyMedium`, `.formaH3Medium`)
- Semibold (e.g., `.formaBodySemibold`, `.formaH3Semibold`)
- Bold (e.g., `.formaCaptionBold`, `.formaSmallBold`)

### Usage Example
```swift
// Using the Font extension
Text("Section Title")
    .font(.formaH2)
    .foregroundColor(.formaLabel)

// With weight variant
Text("Emphasized Text")
    .font(.formaBodySemibold)
```

---

## Spacing

Forma uses an **8-point grid system** for all spacing, ensuring visual rhythm and consistency.

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `micro` | 4px | Icon-to-text spacing |
| `tight` | 8px | Related elements |
| `standard` | 12px | Default gaps, list items |
| `large` | 16px | Layout padding |
| `generous` | 24px | Section spacing |
| `xl` | 32px | Major sections, page margins |
| `xxl` | 48px | Screen-level margins |

### Usage Example
```swift
VStack(spacing: DesignSystem.Spacing.standard) {
    // Content
}
.padding(DesignSystem.Spacing.generous)
```

---

## Visual Hierarchy & Depth

Creating proper depth and hierarchy is essential to Apple Design Award-level quality.

### Layer System

Our interface uses distinct layers to create depth:

1. **Background Layer**: `formaBoneWhite` - foundation
2. **Content Layer**: Cards with subtle borders (1px, 8% opacity)
3. **Interactive Layer**: Hover states with gentle lift (1.005x scale)
4. **Selected Layer**: Enhanced with gradient background + stronger border + colored shadow
5. **Floating Layer**: Action bar with frosted glass + prominent shadow

### Elevation Through Shadow

Different elements require different shadow treatments:

```swift
// Standard card (resting state)
.shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

// Selected card (elevated state)
.shadow(color: Color.formaSteelBlue.opacity(0.15), radius: 8, x: 0, y: 3)

// Primary action button (Apple Design Award refinement)
.shadow(color: Color.formaSage.opacity(0.15), radius: 4, x: 0, y: 2)

// Floating action bar (prominent elevation)
.shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 4)
```

**Key Principles:**
- Shadows increase with importance/interaction
- Y-offset creates realistic "lifting" effect
- Shadow color can match element state (steel blue for selected)
- Multiple shadow layers can be combined for depth
- **Restraint over drama**: 4px blur for buttons (not 8px), 0.15 opacity (not 0.3)
- **No gradients on buttons**: Use solid fills for professional polish

### Selection Visual Feedback

Selection uses **layered feedback** for maximum clarity:

1. **Background**: Gradient (Steel Blue 12% → 8%)
2. **Border**: 2px stroke at 60% opacity
3. **Shadow**: Colored shadow (Steel Blue 15%, 8px radius)
4. **Scale**: Optional subtle lift on hover (1.005x)

This multi-layered approach ensures selection is obvious without being jarring.

---

## Colors

### Semantic Color System

#### Base Palette
- **Obsidian** (`#1A1A1A`) - Primary dark color
- **Bone White** (`#FAFAF8`) - Primary light color
- **Steel Blue** (`#5B7C99`) - Primary brand color
- **Sage** (`#7A9D7E`) - Success/confirmation states

#### Functional Colors

| Purpose | Token | Usage |
|---------|-------|-------|
| Backgrounds | `background` | Main app background (cloud) |
| | `panelBackground` | Cards, panels (white) |
| Text | `textPrimary` | Main text (ink) |
| | `textSecondary` | Secondary text (slate) |
| | `textMuted` | Disabled/metadata (ash) |
| Borders | `border` | Dividers, outlines (ash) |
| Interactive | `steelBlue` | Primary actions |
| | `sage` | Success states |

#### Category Colors
- **Documents**: Steel Blue
- **Images**: Sage
- **Videos**: Clay
- **Audio**: Terracotta
- **Archives**: Amber

### Usage Example
```swift
Text("Hello")
    .foregroundColor(DesignSystem.Colors.textPrimary)
    .background(DesignSystem.Colors.panelBackground)
```

---

## Components

### Buttons

#### Button Heights (macOS HIG Compliant)

| Button Type | Height | Use Case |
|-------------|--------|----------|
| PrimaryButton | 32px | Standard action buttons |
| SecondaryButton | 32px | Secondary actions |
| IconButton | 32x32px | Icon-only buttons |
| PrimaryButtonStyle | ~40px | Toolbar/CTA buttons |
| SecondaryButtonStyle | ~42px | Toolbar secondary buttons |

#### Primary Button
```swift
PrimaryButton("Save", icon: "checkmark") {
    // Action
}
```
- **Height**: 32px
- **Style**: Filled with `steelBlue` background
- **Text**: White, semibold

#### Secondary Button
```swift
SecondaryButton("Cancel") {
    // Action
}
```
- **Height**: 32px
- **Style**: Outlined with 1px border
- **Text**: Primary color

#### Icon Button
```swift
IconButton(icon: "gear", accessibilityLabel: "Settings") {
    // Action
}
```
- **Size**: Minimum 32x32px
- **Required**: Accessibility label

### Corner Radius

**Apple Design Award Standard: Unified Hierarchy (12px / 6px)**

Forma uses a 2:1 corner radius system throughout the application for visual consistency and professional polish:

| Token | Value | Usage |
|-------|-------|-------|
| `cornerRadiusSmall` | 4px | **Deprecated** - Use 6px for nested elements |
| `cornerRadiusMedium` | 8px | **PRIMARY** - Standard buttons, inputs |
| `cornerRadiusLarge` | 12px | **PRIMARY** - Cards, panels, containers |
| `cornerRadiusNested` | 6px | **NESTED** - Icon backgrounds, internal buttons |
| `cornerRadiusXLarge` | 16px | **Deprecated** - Use 12px for consistency |

**Implementation Rules:**
- Primary surfaces (cards, suggestion cards): **12px**
- Standard interactive elements (Buttons, Inputs): **8px**
- Nested elements within cards (icon backgrounds): **6px**
- This creates clear visual hierarchy without competing radii
- Matches Apple's Music.app and Notes.app patterns

---

## Layout Standards

### Window Sizing
- **Minimum**: 1000x600px
- **Ideal**: 1200x800px
- **Title Bar**: Hidden (`.windowStyle(.hiddenTitleBar)`)

### Sidebar
- **Width (Expanded)**: 256px
- **Width (Collapsed)**: 72px
- **Background**: Regular Material (native macOS blur)
- **Search**: Integrated CompactSearchField at top

### Content Header
- **Height**: 64px (Unified Toolbar)
- **Horizontal Padding**: 32px

### Right Panel
- **Width**: 360px
- **Background**: White with 1px ash border

### List Rows
- **Vertical Padding**: 12px (standardized from 8px)
- **Icon Size**: 24x24px
- **Hover State**: Light gray background

---

## Accessibility

### Touch Targets
- **Minimum**: 32x32px for all interactive elements
- **Recommended**: 44x44px for primary actions

### Accessibility Labels
All icon-only buttons **MUST** have `.accessibilityLabel()`:

```swift
Button(action: { }) {
    Image(systemName: "gear")
}
.accessibilityLabel("Settings")
```

### Affected Components
- All IconButton instances
- Toggle buttons (sidebar, view mode)
- Action buttons in file rows
- Navigation items when sidebar collapsed

### Color Contrast
All text meets WCAG AA standards:
- Primary text on light: 15:1 contrast ratio
- Secondary text on light: 7:1 contrast ratio
- Interactive elements: Clear focus indicators

---

## macOS HIG Compliance

### Compliance Checklist

#### ✅ Window Management
- [x] Hidden title bar for modern appearance
- [x] Native Settings scene with Cmd+, support
- [x] Menu bar extra with system integration

#### ✅ Typography & Spacing
- [x] 4-point grid system
- [x] Clear type hierarchy
- [x] Consistent line heights

#### ✅ Buttons & Controls
- [x] Standard button heights (32px regular, 40-44px toolbar)
- [x] Minimum 32x32px touch targets
- [x] Native segmented controls for toggles
- [x] Proper hover and pressed states

#### ✅ Layout
- [x] Standard sidebar widths (256px/72px)
- [x] Proper content padding (32px)
- [x] Consistent corner radius values

#### ✅ Visual Elements
- [x] Icon sizes: 20-24px for lists, 64px for empty states
- [x] List row padding: 12px vertical
- [x] Modal backdrop opacity: 0.15
- [x] Menu bar width: 280px

#### ✅ Accessibility
- [x] All icon buttons have accessibility labels
- [x] Keyboard navigation support
- [x] VoiceOver compatibility
- [x] WCAG AA color contrast

---

## Implementation Reference

### File Structure
```
Forma File Organizing/
├── DesignSystem/
│   └── DesignSystem.swift          # Core design tokens
├── Components/
│   ├── Buttons.swift                # Button components
│   ├── Common.swift                 # Shared utilities
│   └── FileViews.swift              # File-related components
└── Views/
    ├── DashboardView.swift          # Main dashboard
    ├── SidebarView.swift            # Navigation sidebar
    ├── MainContentView.swift        # Content area
    └── RightPanelView.swift         # Storage/activity panel
```

### Recent Updates (macOS HIG Compliance - 2025)

#### Button Height Standardization
- `Buttons.swift`: All buttons now use consistent heights
- `IconButton`: Enforces minimum 32x32px touch targets

#### Spacing Improvements
- `FileRow.swift`: Increased vertical padding to 12px
- Better visual breathing room in lists

#### Icon Sizing
- `SidebarView.swift`: Increased icons from 17pt to 20pt
- `MainContentView.swift` & `Settings/SettingsView.swift`: Empty states now 64pt

#### Visual Polish
- `DashboardView.swift`: Modal backdrop reduced to 0.15 opacity
- `MenuBarView.swift`: Increased width to 280px
- `ReviewView.swift`: Native segmented control for view mode

#### Accessibility
- Added 15 accessibility labels across 7 files
- `IconButton` now requires accessibility labels
- Full VoiceOver support

---

## Best Practices

### DO ✅ (Apple Design Award Standards)
- Use design system tokens (never hardcode values)
- Maintain 4-point grid alignment
- Provide accessibility labels for all icons
- Follow semantic color naming
- Use native controls when possible
- Test with VoiceOver enabled
- **Layer visual feedback** (gradient + border + shadow, not just one)
- **Use frosted glass** for floating UI elements (native macOS material)
- **Keep hover effects subtle** (1.005x scale, gentle animations)
- **Question "good enough"** - does it feel refined?
- **Study Apple Design Award winners** for inspiration
- **Unify corner radii**: 12px for primary surfaces, 6px for nested elements
- **Use solid fills on buttons**: No gradients on CTAs - restraint = premium
- **Strengthen dividers**: 0.5 opacity minimum for structural separators
- **Background warnings**: Add tinted backgrounds to improve contrast (e.g., orange warnings)

### DON'T ❌ (Quality Compromises)
- Hardcode colors, spacing, or typography values
- Create buttons smaller than 32x32px
- Skip accessibility labels on icon buttons
- Use inconsistent corner radius values
- Ignore macOS platform conventions
- Forget to test keyboard navigation
- **Use flat single-color selection states** (needs depth)
- **Make hover effects too dramatic** (subtle > flashy)
- **Overcrowd the UI** (white space is intentional)
- **Settle for "it works"** when "it delights" is possible
- **Ignore the details** (shadows, borders, spacing all matter)
- **Mix corner radii carelessly** (8px, 10px, 12px, 16px creates visual noise)
- **Use button gradients** (reads as consumer-grade, not pro-tool)
- **Make dividers too faint** (<0.5 opacity disappears over materials)
- **Ignore WCAG AA** (all text must meet contrast requirements)

---

## Testing Checklist

Before releasing any UI changes:

- [ ] All buttons meet minimum height requirements
- [ ] Touch targets are at least 32x32px
- [ ] Spacing follows 4-point grid
- [ ] Colors use design system tokens
- [ ] Typography uses correct scale
- [ ] Accessibility labels are present
- [ ] VoiceOver navigation works correctly
- [ ] Keyboard shortcuts function properly
- [ ] Layout works at minimum window size (1000x600)
- [ ] Dark mode appearance (if applicable)

---

## Resources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SF Symbols Browser](https://developer.apple.com/sf-symbols/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/view-accessibility)

---

**Last Updated**: 2026-01-06
**Version**: 1.0
**Compliance**: macOS HIG + WCAG 2.1 AA
