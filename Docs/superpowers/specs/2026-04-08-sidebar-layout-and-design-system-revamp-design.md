# Sidebar Layout + Design System Revamp

**Date:** 2026-04-08
**Status:** Approved
**Scope:** Sidebar IA cleanup, three-column layout fix, design system token maturity and consistency

## Overview

Two connected improvements: (1) fix the sidebar cramping when the right panel opens and simplify its information architecture, and (2) mature the design system from ~48% token adoption to comprehensive, enforced coverage with new token categories.

The visual direction is "native macOS with strong personality" — respects platform conventions but has its own voice through custom accent colors, distinctive surface treatments, and cohesive motion. Think between Things 3 and Raycast.

---

## Part 1: Sidebar Layout + IA Cleanup

### Problem

When the right panel opens, the three-column `NavigationSplitView` squeezes the sidebar because minimum column widths sum to 1180px against a 1200px minimum window width. The sidebar becomes the "victim column" since it has the smallest minimum.

Additionally, Smart Rules and Analytics are listed under a TOOLS section as navigation items but behave differently from folder locations — they hijack the center column with full-screen views (`RulesManagementView`, `ProductivityReportView`) and hide the right panel. Both features also exist as right-panel modes, creating redundant entry points with inconsistent behavior.

### Solution

#### 1a. Column Width Rebalancing

**DashboardView.swift changes:**

| Column | Current | Proposed |
|--------|---------|----------|
| Sidebar | min 220, ideal 260, max 320 | min 220, ideal 260, max 320 (unchanged) |
| Center | min 680, ideal 960 | min 560, ideal 960 |
| Right panel | min 280, ideal 340, max 420 | min 280, ideal 340, max 420 (unchanged) |
| Window minimum | 1200 x 600 | 1280 x 600 |

New minimum sum: 220 + 560 + 280 = 1060px, leaving 220px of headroom at the 1280px window minimum. The center column's file rows can gracefully compress below 680px — they already handle truncation via `text-overflow`.

**Files affected:**
- `Forma File Organizing/Views/DashboardView.swift` — column width modifiers, window min frame
- `Forma File Organizing/Forma_File_OrganizingApp.swift` — `MainWindowPresentation` default/minimum sizes
- `Forma File Organizing/DesignSystem/FormaSpacing.swift` — update `Window` constants

#### 1b. Demote Smart Rules and Analytics

Remove the TOOLS section. Smart Rules and Analytics become action buttons that open the right panel in the appropriate mode, rather than navigation destinations that hijack the center column.

**Behavioral changes:**
- Clicking "Smart Rules" in sidebar opens right panel in a **rules list mode** — a compact vertical list of all rules with edit/delete/reorder controls, similar to `RulesManagementView` but adapted for the right panel's narrower width (280-420px). Tapping a rule opens the existing inline rule editor. Center column stays on the current location's file list.
- Clicking "Analytics" in sidebar opens right panel in analytics mode (the existing `CompactAnalyticsPanel`). Center column stays on the current location's file list.
- `RulesManagementView` (full-screen) is replaced by the new compact right-panel rules list mode. `ProductivityReportView` (full-screen) is replaced by the existing `CompactAnalyticsPanel`.
- Deprecate `NavigationSelection.rules` and `NavigationSelection.analytics` with `@available(*, deprecated)` annotations. They remain compilable but are no longer reachable from the sidebar.
- The `showsInspectorColumn` logic in DashboardView simplifies — it no longer needs the `nav.selection != .analytics` special case.

**Files affected:**
- `Forma File Organizing/Views/SidebarView.swift` — remove TOOLS section, add Smart Rules/Analytics to ACTIONS
- `Forma File Organizing/Views/DashboardView.swift` — remove `RulesManagementView` and `ProductivityReportView` center column branches, simplify `showsInspectorColumn`
- `Forma File Organizing/ViewModels/NavigationViewModel.swift` — remove or deprecate `.rules` and `.analytics` selection cases
- `Forma File Organizing/ViewModels/DashboardViewModel.swift` — update `rightPanelMode` handling for new entry points

#### 1c. Sidebar Section Simplification

New sidebar structure:

```
[Search Bar]

LOCATIONS
  Desktop        18
  Downloads      39
  Documents
  Pictures
  Music

ACTIONS
  New Rule
  Add Folder
  Smart Rules
  Analytics

[Settings]  [?]
```

Two sections instead of three. LOCATIONS is purely navigational. ACTIONS is purely imperative — "do something." The sidebar's purpose becomes unambiguous: browse locations, trigger actions.

**Files affected:**
- `Forma File Organizing/Views/SidebarView.swift` — restructure body, remove `sidebarItem` calls for rules/analytics, add `SidebarActionRow` entries for Smart Rules/Analytics

---

## Part 2: Design System Token Maturity

### Current State

Token adoption is approximately 48% overall:
- Colors: 70% (highest)
- Opacity: 50%
- Spacing: 45%
- Radius: 40%
- Typography: 35% (lowest — 60+ hardcoded `.system(size:)` calls)

### 2a. New Token Categories

#### FormaShadows

A shadow scale mapped to elevation levels. Each level defines color (with light/dark mode variants), blur radius, and x/y offset.

```
none      — flat surfaces (sidebar rows, list items)
subtle    — light lift for cards at rest
medium    — hovered cards, floating elements
strong    — popovers, dropdowns
dramatic  — modals, sheets
```

Applied as a view modifier: `.formaShadow(.medium)`

**File:** `Forma File Organizing/DesignSystem/FormaShadows.swift` (new)

#### FormaElevation

Systematic surface layering that bundles background color + shadow + corner radius + optional border into composite levels.

```
base      — app background (no shadow, no border)
raised    — cards, panels (subtle shadow + formaCardBackground)
floating  — popovers, tooltips (medium shadow + brighter surface)
overlay   — modals, sheets (strong shadow + backdrop dim)
```

Applied as a composite modifier: `.formaElevation(.raised)`

**File:** `Forma File Organizing/DesignSystem/FormaElevation.swift` (new)

#### FormaBorders

Stroke width tokens for consistent border treatment across the app.

```
hairline  — 0.5px (separators, subtle dividers)
thin      — 1.0px (card borders, input fields)
medium    — 1.5px (focused states)
thick     — 2.0px (emphasis, active states)
```

**File:** `Forma File Organizing/DesignSystem/FormaBorders.swift` (new)

#### FormaIconSize

Frame dimensions for icon containers. Replaces hardcoded `.frame(width:height:)` values throughout the app.

```
micro     — 16px (inline indicators, badges)
small     — 20px (sidebar icons, compact contexts)
standard  — 24px (default icon size)
medium    — 32px (toolbar icons, list leading icons)
large     — 48px (feature icons, empty states)
hero      — 64px (onboarding, splash screens)
```

**File:** `Forma File Organizing/DesignSystem/FormaIconSize.swift` (new)

#### FormaZIndex

Layering order constants for overlays, preventing magic numbers like `.zIndex(99)`.

```
base          — 0 (default content)
raised        — 10 (floating cards, sticky headers)
dropdown      — 20 (dropdown menus, popovers)
overlay       — 30 (dimmed backdrop)
modal         — 40 (modal dialogs, sheets)
toast         — 50 (toast notifications)
tooltip       — 60 (tooltips, hover info)
```

**File:** `Forma File Organizing/DesignSystem/FormaZIndex.swift` (new)

#### FormaEasing

Standardized easing curves and spring configurations for cohesive motion feel. This consolidates all animation timing into one place — `FormaMicroanimations` retains its custom animated `ViewModifier` components (ValidationShakeModifier, ToggleRippleModifier, etc.) but its duration constants and the `interactiveSpring` config migrate here. `FormaMicroanimations` then imports from `FormaEasing` for its timing values.

```
standard      — easeInOut, for general transitions
enter         — easeOut, for elements appearing
exit          — easeIn, for elements disappearing
interactive   — interactiveSpring(response: 0.22, dampingFraction: 0.9)
bouncy        — spring(response: 0.35, dampingFraction: 0.7), for playful feedback
gentle        — spring(response: 0.5, dampingFraction: 0.85), for panel slides
```

**File:** `Forma File Organizing/DesignSystem/FormaEasing.swift` (new)

#### FormaFocusRing

Focus ring styling for keyboard navigation and accessibility.

```
color         — formaSteelBlue (matches app accent)
width         — 2px
offset        — 2px (outset from element edge)
cornerRadius  — inherits from element's corner radius + offset
```

Applied as: `.formaFocusRing()` view modifier that responds to `@FocusState`.

**File:** `Forma File Organizing/DesignSystem/FormaFocusRing.swift` (new)

### 2b. Existing Token Refinements

#### FormaColors — Tighten the Palette

**Label hierarchy consolidation:** Collapse 6 label colors to 4 clear tiers:
- `formaPrimary` (currently `formaLabel`)
- `formaSecondary` (consolidate `formaSecondaryLabel` + `formaSecondaryLabelHigh`)
- `formaTertiary` (consolidate `formaTertiaryLabel` + `formaTertiaryLabelHigh`)
- `formaQuaternary` (currently `formaQuaternaryLabel`)

The "High" variants exist because the original values were too dim. Fix the base values so the workaround isn't needed. Deprecate the old names with availability annotations pointing to the replacements.

**Surface tint tokens:** Add subtle warm/cool tints for the "personality" layer:
- `formaSurfaceTintWarm` — very subtle warm wash (for cards, selected states)
- `formaSurfaceTintCool` — very subtle cool wash (for sidebar, tool areas)

These are applied at low opacity (2-5%) over existing surface colors to give Forma a distinctive feel without fighting the macOS platform.

**File:** `Forma File Organizing/DesignSystem/FormaColors.swift`

#### FormaTypography — Fill Gaps

- Add `formaCallout`: 15pt semibold — fills the gap between Body (13pt) and H3 (17pt) for section headers that aren't quite headings
- Add `formaTabular`: 13pt regular with `.monospacedDigit()` — for file sizes, counts, and other number-heavy contexts
- Add `formaTabularSmall`: 11pt regular with `.monospacedDigit()`

**File:** `Forma File Organizing/DesignSystem/FormaTypography.swift`

#### FormaSpacing — Add In-Between Value

- Add `compact`: 12px — between `tight` (8px) and `standard` (16px) for tighter UI areas like sidebar rows and right panel content where 16px is too generous but 8px is too cramped.

Updated scale: micro (4) → tight (8) → compact (12) → standard (16) → generous (24) → large (32) → extraLarge (48) → huge (64)

**File:** `Forma File Organizing/DesignSystem/FormaSpacing.swift`

#### FormaMicroanimations — Expand Duration Coverage

Add missing duration constants:
- `standardTransition`: 0.3s — page-level changes
- `modalPresentation`: 0.35s — sheet/modal appearance
- `panelSlide`: 0.25s — right panel open/close
- `contentFade`: 0.2s — content swaps within a container

**File:** `Forma File Organizing/DesignSystem/FormaMicroanimations.swift`

### 2c. Component-Level Composite Tokens

Create `ViewModifier` implementations that compose primitive tokens for high-frequency patterns. These prevent views from assembling 4-5 tokens every time they render a common element.

#### FormaCardStyle
Combines background + radius + shadow + border with hover/selected/default variants.
```swift
.formaCardStyle()                    // default
.formaCardStyle(.selected)           // selected state
.formaCardStyle(.interactive)        // responds to hover
```

#### FormaSidebarRowStyle
Combines padding + radius + background + hover/selected fills. Replaces the inline styling in `SidebarNativeRow`.

#### FormaButtonStyle
Primary, secondary, destructive variants combining typography + padding + background + radius + hover/pressed states.

#### FormaInputStyle
Border + radius + padding + background + focus ring for text fields and inputs.

**File:** `Forma File Organizing/DesignSystem/FormaComponentStyles.swift` (new)

### 2d. Component Layer Reorganization

The component layer is currently disorganized:

- **`FormaComponents.swift`** is a 1,276-line monolith with 20+ components — needs to be split into individual files.
- **`Components/` directory** has 80+ files, most not Forma-prefixed, with no clear boundary between reusable primitives and app-specific feature components.
- **`Components/Shared/`** is inconsistently populated — some generic components are Forma-prefixed, others aren't.
- **DesignSystem/** has additional components scattered across FormaControlChrome.swift, FormaAnimation.swift, and FormaShaderEffects.swift.

#### Two tiers of components

**Design system components** — Forma-prefixed, generic, reusable, no business logic. These are the primary consumers of design tokens. They live in `DesignSystem/Components/` as individual files.

Existing (extracted from FormaComponents.swift):
- `FormaPrimaryButton`, `FormaSecondaryButton` → combine into `FormaButton.swift` with style variants
- `FormaCard.swift` (FormaCard, FormaListCard)
- `FormaTextField.swift`
- `FormaProgressBar.swift`
- `FormaStatusPill.swift` (FormaStatusPill, FormaFileBadge, FormaBadge, FormaStatBadge)
- `FormaEmptyState.swift` (FormaEmptyState, FormaActionableEmptyState)
- `FormaSegmentedControl.swift` (FormaSegmentedControl, FormaSegmentButton, FormaSegmentedIconButton, FormaSegmentedBackground)
- `FormaLogo.swift`
- `FormaCategoryIcon.swift`
- `FormaHeroIcon.swift`
- `FormaFolderPicker.swift`
- `FormaListButton.swift`
- `FormaFileListItem.swift`

Promoted from Components/ (generic primitives that should be design system components):
- `StatusIndicator` → `FormaStatusIndicator.swift`
- `CollapsibleSection` → `FormaCollapsibleSection.swift`
- `Toast` → `FormaToast.swift`

**Feature components** — app-specific UI, no prefix, stays in `Components/`. These compose Forma design system components and should not hardcode design tokens directly. Examples: RulePreviewCard, FileListRow, ActivityFeed, WorkflowRunDetailSheet.

#### The split

1. Create `DesignSystem/Components/` directory
2. Extract each component from `FormaComponents.swift` into its own file
3. Move FormaCheckbox, FormaActionButton, FormaThumbnail from `Components/Shared/` to `DesignSystem/Components/`
4. Promote generic primitives from `Components/` to `DesignSystem/Components/` with Forma prefix
5. Delete `FormaComponents.swift` once empty
6. Remove `Components/Shared/` once empty (its contents have moved to DesignSystem/Components/)

**Files affected:**
- `DesignSystem/FormaComponents.swift` — deleted (split into individual files)
- `DesignSystem/Components/*.swift` — ~18 new individual component files
- `Components/Shared/*` — contents moved to DesignSystem/Components/
- `Components/StatusIndicator.swift`, `Components/CollapsibleSection.swift`, `Components/Toast.swift` — promoted and renamed

---

## Part 3: Consistency Enforcement

### Approach

Pragmatic, not dogmatic. No build-time linting yet — the token system is still maturing.

### Priority File Remediation

Fix files in order of user-facing impact:

**Wave 1 — Sidebar work (touched as part of Part 1):**
- `SidebarView.swift` (10 hardcoded instances)
- `SidebarNativeRow` and `SidebarActionRow` (8 instances)

**Wave 2 — High-traffic content surfaces:**
- `MainContentView.swift` (~8 instances)
- `FileRow.swift` / `FileListRow.swift` / `FileGridItem.swift` (~6 each)
- `DefaultPanelView.swift` (~10 instances)

**Wave 3 — Secondary surfaces:**
- `InlineRuleBuilderView.swift` (9 instances)
- `FailedFilesSheet.swift` (7 instances)
- `ReportPDFView.swift` (12 instances — lowest priority, PDF export)

### Rules

- **Files we touch get fully converted.** No mixing old and new hardcoded values in the same file.
- **No bulk find-and-replace.** Each file needs context-aware conversion (a hardcoded `13pt` might map to `.formaBody` or `.formaCompactMedium` depending on usage).
- **No changes to files we're not otherwise touching.** This rides alongside feature work, not a codebase-wide cleanup.
- **Deprecate, don't delete.** Old token names (e.g., `formaSecondaryLabelHigh`) get `@available(*, deprecated, renamed:)` annotations pointing to replacements, so existing code migrates gradually.

---

## Files Summary

### New files
- `DesignSystem/FormaShadows.swift`
- `DesignSystem/FormaElevation.swift`
- `DesignSystem/FormaBorders.swift`
- `DesignSystem/FormaIconSize.swift`
- `DesignSystem/FormaZIndex.swift`
- `DesignSystem/FormaEasing.swift`
- `DesignSystem/FormaFocusRing.swift`
- `DesignSystem/FormaComponentStyles.swift`
- `DesignSystem/Components/` — ~18 individual component files extracted from FormaComponents.swift + promoted from Components/Shared/

### Modified files
- `DesignSystem/FormaColors.swift` — label consolidation, surface tints
- `DesignSystem/FormaTypography.swift` — callout, tabular variants
- `DesignSystem/FormaSpacing.swift` — compact value, window constants
- `DesignSystem/FormaMicroanimations.swift` — expanded durations
- `Views/DashboardView.swift` — column widths, center column branches, window size
- `Views/SidebarView.swift` — IA restructure, token adoption
- `ViewModels/NavigationViewModel.swift` — remove/deprecate rules/analytics selections
- `ViewModels/DashboardViewModel.swift` — right panel mode updates
- `Forma_File_OrganizingApp.swift` — window presentation sizes
- `Components/StatusIndicator.swift`, `Components/CollapsibleSection.swift`, `Components/Toast.swift` — promoted to DesignSystem/Components/ with Forma prefix
- Wave 2/3 files as listed in consistency enforcement

### Removed/deprecated
- `DesignSystem/FormaComponents.swift` — deleted (split into individual files in DesignSystem/Components/)
- `Components/Shared/` — contents moved to DesignSystem/Components/
- `RulesManagementView` as center-column state (functionality consolidated to right panel)
- `ProductivityReportView` as center-column state (functionality consolidated to right panel)
- `formaSecondaryLabelHigh`, `formaTertiaryLabelHigh` color tokens (deprecated, replaced by updated base values)
- `NavigationSelection.rules`, `NavigationSelection.analytics` (deprecated)
