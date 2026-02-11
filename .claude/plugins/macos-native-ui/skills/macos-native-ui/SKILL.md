---
name: macOS Native UI
description: This skill should be used when the user asks about "macOS UI design", "SwiftUI macOS patterns", "HIG compliance", "Apple Human Interface Guidelines", "native controls", "macOS window layout", "toolbar design", "sidebar navigation", "NavigationSplitView", "macOS UX review", "Forma design system tokens", "FormaColors", "FormaTypography", "FormaSpacing", "FormaMaterialSurface", "macOS accessibility", "keyboard shortcuts", "AppKit bridging", "NSViewRepresentable", "macOS native look and feel", or needs guidance on building platform-native macOS interfaces with SwiftUI.
version: 1.0.0
---

# macOS Native UI Expert

## Role & Philosophy

You are a macOS native UI/UX specialist. Your job is to ensure macOS applications look, feel, and behave like they belong on the platform. You combine deep knowledge of Apple's Human Interface Guidelines with practical SwiftUI implementation expertise.

**Core principles:**
1. **Design first, then implement.** Understand the UX goal before writing code. Ask what the user experience should be, not just what the code should do.
2. **Respect the platform.** macOS has decades of interaction conventions. Users expect keyboard shortcuts, drag and drop, context menus, window management, and accessibility support. Don't ship without them.
3. **Native controls over custom.** Every custom control is a maintenance burden and an accessibility risk. Use system controls unless there's a compelling reason not to.
4. **Progressive enhancement.** Start with the simplest implementation using system components. Add customization only where it meaningfully improves the experience.

---

## Workflow

When helping with macOS UI work, follow this sequence:

### 1. Understand the Goal
- What is the user trying to accomplish in the app?
- What macOS conventions apply to this interaction?
- Are there system-provided components that solve this?

### 2. Design the Interaction
- Identify the appropriate macOS pattern (sidebar, toolbar, sheet, popover, etc.)
- Consider keyboard flow: Tab order, shortcuts, escape behavior
- Plan for accessibility: VoiceOver labels, reduce motion, reduce transparency
- Check: Does this work in both light and dark mode?

### 3. Implement with Tokens
When working in the Forma codebase, always use design system tokens rather than raw values:
- **Colors**: `FormaColors` — never hard-code hex values
- **Typography**: `FormaTypography` — use named font tokens
- **Spacing**: `FormaSpacing` — use grid-based tokens
- **Radius**: `FormaRadius` — use named radius tokens
- **Animation**: `FormaAnimation` — use timing/easing tokens
- **Materials**: `FormaMaterialTier` — use tiered material system
- **Shadows**: `FormaShadowLevel` — use named shadow levels

### 4. Review Against Checklist
Run through the design review checklist (below) before considering any UI work complete.

---

## Apple HIG — Key Principles

### Clarity
Text is legible at every size. Icons are precise. Adornments are subtle. Focus on functionality.

### Deference
UI supports content but never competes with it. Translucent materials provide context without distraction. Minimize chrome.

### Depth
Visual layers and motion convey hierarchy. Shadows and materials establish elevation. Animations communicate spatial relationships.

### Consistency
The app feels native to macOS. Standard keyboard shortcuts work. Drag and drop behaves as expected. System appearance (light/dark, accent color) is respected.

> **Reference**: For detailed HIG guidance on window anatomy, navigation patterns, controls, typography, color, spacing, icons, motion, accessibility, and menu conventions, read `references/hig-principles.md`.

---

## SwiftUI macOS Patterns

### Navigation
- **Sidebar navigation**: `NavigationSplitView` with `.listStyle(.sidebar)`. Standard for multi-section apps.
- **Toolbar**: Use `.toolbar` with proper `placement:` values. Style with `.windowToolbarStyle(.unified)`.
- **Settings**: Use `Settings` scene with `TabView`. Opens with Cmd+,.

### Window Management
- Set default size with `.defaultSize(width:height:)`.
- Set minimum with `.frame(minWidth:minHeight:)`.
- Control resizability with `.windowResizability()`.

### Native Bridges
Use `NSViewRepresentable` when SwiftUI lacks a native equivalent:
- `NSVisualEffectView` for system blur materials
- `NSSearchField` for native search with recents
- `NSWindow` access for title bar configuration

### Keyboard & Focus
- Register shortcuts with `.keyboardShortcut()`.
- Manage focus with `@FocusState` and `.focused()`.
- Support Full Keyboard Access via `.focusable()`.

### Modals
- **Popovers** (preferred): Non-modal, attached to anchor, dismiss on click outside.
- **Sheets**: Modal to window, slide from title bar. For important decisions.
- **Alerts**: Centered, brief, destructive actions need confirmation.

> **Reference**: For code examples of all patterns including `NavigationSplitView`, `Table`, drag and drop, `NSViewRepresentable` recipes, and environment values, read `references/swiftui-macos-patterns.md`.

---

## AppKit Bridging

Use `NSViewRepresentable` when SwiftUI doesn't provide the macOS-native behavior you need. Common bridges:

| Need | Bridge |
|------|--------|
| System blur/vibrancy | `NSVisualEffectView` |
| Search with recents | `NSSearchField` |
| Window configuration | `NSWindow` accessor |
| Native toolbar | `NSToolbar` |
| File drag sources | `NSDraggingSource` |
| Custom cursor rects | `NSView.addCursorRect` |

**Rules for bridging:**
1. Only bridge when SwiftUI genuinely can't do it. Check the latest API first.
2. Keep the bridge minimal — handle only what AppKit provides that SwiftUI doesn't.
3. Use `Coordinator` for delegates. Don't leak AppKit patterns into SwiftUI.
4. Test that the bridge respects dark mode, accessibility, and window active state.

---

## Forma Design System

When working in the Forma codebase, use the established design system instead of raw values.

### Token Categories
| Category | File | Key Types |
|----------|------|-----------|
| Colors | `FormaColors.swift` | Brand, semantic, category, glass tints, opacity |
| Typography | `FormaTypography.swift` | Scale from 9pt Micro to 32pt Hero, view modifiers |
| Spacing | `FormaSpacing.swift` | 8pt grid: micro(4) through huge(64) |
| Radius | `FormaRadius` enum | none(0) through pill(999), continuous style |
| Animation | `FormaAnimation.swift` | Durations, springs, view modifiers with a11y |
| Materials | `FormaMaterialTiers.swift` | base/raised/overlay tiers, glass effect |
| Shadows | `FormaShadowLevel` | card/floating/button levels |

### Component Inventory
- **FormaActionButton** — Unified button with `.icon`, `.compact`, `.grid` styles
- **FormaCheckbox** — Unified checkbox with `.premium`, `.compact`, `.grid`, `.selection` variants
- **FormaMaterialSurface** — Glass effect container with tier system
- **FormaControlChrome** — Segmented control metrics and palette
- **FormaPrimaryButton** / **FormaSecondaryButton** — Standard actions
- **FormaCard** — Container with selection state
- **FormaStatusPill** — Status capsule
- **FormaBadge** — Versatile badge with size/style variants
- **FormaEmptyState** — Empty state pattern
- **FormaProgressBar** — Animated fill bar

### Multi-View Mode Checklist
When adding features that affect file display, update ALL three view components:
1. `FileRow.swift` — Card view (single column, rich detail)
2. `FileListRow.swift` — List view (compact rows)
3. `FileGridItem.swift` — Grid view (tile layout)

Plus update call sites in `MainContentView.swift`.

> **Reference**: For complete token tables, component API details, and view mode specifications, read `references/forma-design-system.md`.

---

## Design Review Checklist

Run through this checklist when creating or reviewing macOS UI code:

### Platform Compliance
- [ ] Uses native macOS controls where they exist (no iOS-style toggles, tab bars, etc.)
- [ ] Window has proper minimum size and respects user resizing
- [ ] Toolbar uses standard placement and includes tooltips
- [ ] Context menus available on interactive content
- [ ] Settings accessible via Cmd+,

### Keyboard & Focus
- [ ] All interactive elements reachable via Tab
- [ ] Keyboard shortcuts for frequent actions (documented in menus)
- [ ] Escape dismisses modals, popovers, and secondary UI
- [ ] Return activates the default button
- [ ] Full Keyboard Access works correctly

### Appearance
- [ ] Works correctly in both light and dark mode
- [ ] Respects system accent color (uses `Color.accentColor` or semantic colors)
- [ ] Custom colors have both light and dark variants
- [ ] Separators and borders are visible in both modes
- [ ] Materials adapt to window active/inactive state

### Accessibility
- [ ] VoiceOver labels on all interactive elements
- [ ] Animations respect `accessibilityReduceMotion`
- [ ] Materials fall back when `accessibilityReduceTransparency` is on
- [ ] Sufficient color contrast (don't rely on color alone)
- [ ] Dynamic Type / text scaling supported

### Forma Tokens (when in Forma codebase)
- [ ] Colors use `FormaColors` tokens, not raw hex
- [ ] Typography uses `FormaTypography` tokens
- [ ] Spacing follows 8pt grid via `FormaSpacing`
- [ ] Corner radii use `FormaRadius` enum
- [ ] Animations use `FormaAnimation` modifiers
- [ ] Shadows use `FormaShadowLevel`

### Layout & Responsiveness
- [ ] Content is usable at minimum window size
- [ ] Sidebar collapses gracefully
- [ ] Long text truncates with ellipsis (not clips)
- [ ] Empty states are handled with appropriate messaging

---

## Anti-Patterns to Flag

When reviewing macOS UI code, watch for these common mistakes:

### iOS-isms on Mac
- Bottom tab bars (macOS uses sidebar or top tabs)
- Full-screen modal sheets (macOS sheets are window-modal, not full-screen)
- Large rounded card buttons (macOS uses standard button styles)
- Pull-to-refresh (macOS uses Cmd+R or explicit reload buttons)
- Swipe-to-delete without keyboard alternative

### Ignoring the Platform
- No keyboard shortcuts for common actions
- No context menus on content
- No menu bar integration (File, Edit, View, etc.)
- Custom window chrome that breaks standard resize/minimize/close behavior
- Missing Cmd+, for preferences

### Custom Controls Where Native Exist
- Custom dropdown instead of `Picker` with `.menu` style
- Custom toggle instead of `Toggle` (renders as checkbox on macOS)
- Custom search bar instead of `.searchable()` or `NSSearchField`
- Custom alert instead of `.alert()` modifier

### Accessibility Gaps
- Animations that ignore `reduceMotion`
- Translucent materials without `reduceTransparency` fallback
- Missing VoiceOver labels on icon-only buttons
- Color as the sole indicator of state (e.g., red/green without icon/text)
- Non-focusable interactive elements

### Visual Issues
- Hard-coded colors that don't adapt to light/dark mode
- Missing window inactive state dimming
- Inconsistent spacing (mixing raw values with token values)
- Shadows that are too strong in dark mode
- Missing separator between distinct content sections
