# Apple Human Interface Guidelines — macOS Reference

Distilled, actionable guidance for building native macOS applications. This is a synthesis of key principles, not a reproduction of Apple's documentation.

---

## Core Design Principles

### Clarity
- Text is legible at every size. Icons are precise and lucid. Adornments are subtle and appropriate. A sharpened focus on functionality motivates the design.
- Use the system font (SF Pro) at standard sizes. Avoid decorative fonts for UI chrome.
- Prefer SF Symbols over custom icons — they align with text baselines automatically and adapt to accessibility sizes.

### Deference
- The UI helps people understand and interact with content but never competes with it.
- Translucent materials and vibrancy let the content behind hint through, providing context without distraction.
- Minimize chrome. Toolbars, sidebars, and controls should feel lightweight.

### Depth
- Distinct visual layers and realistic motion convey hierarchy and facilitate understanding.
- Use shadows and materials to establish elevation: base surfaces sit behind raised panels which sit behind overlays.
- Animations should communicate spatial relationships — a sheet slides down from the toolbar, a popover points to its anchor.

### Consistency
- The app should feel like it belongs on macOS. Use native controls, respect system conventions, and match established patterns.
- Keyboard shortcuts follow platform conventions (Cmd+C, Cmd+V, Cmd+Z, Cmd+,).
- Drag and drop works where users expect it.

---

## Window Anatomy

### Title Bar
- Displays the window title, proxy icon (for document-based apps), and traffic light buttons.
- The title bar can merge with the toolbar (unified style) or remain separate.
- Respect `.windowStyle(.titleBar)` for standard windows; use `.titlebarAppearsTransparent` only when the content should blend into the title area.

### Toolbar
- Sits below (or merged with) the title bar. Contains frequently used actions.
- Use `.toolbar` modifier with `ToolbarItem(placement:)` for proper positioning.
- Toolbar items should have tooltips and keyboard equivalents.
- Styles: `.automatic`, `.unified`, `.unifiedCompact`. Prefer `.unified` for most apps.

### Sidebar
- Standard navigation pattern. 240-280pt default width, collapsible.
- Use `NavigationSplitView` with `.navigationSplitViewColumnWidth()` to set sidebar width.
- Sidebar items use `Label` with SF Symbols. Tint icons to `.secondary` or use accent colors sparingly.
- Support selection highlighting with system accent color.

### Content Area
- The primary workspace. Scrollable content should use insets to avoid clipping at edges.
- Respect safe areas, especially when using transparent title bars.
- Empty states should include an icon, explanatory text, and an optional action.

### Bottom Bar / Status Bar
- Optional. Use for contextual information (item count, selection state, progress).
- Keep text small and secondary.

---

## Navigation Patterns

### Sidebar Navigation
- Primary navigation for multi-section apps. Each sidebar item reveals a different content view.
- Support keyboard navigation with arrow keys. Sidebar is focusable.
- Collapsing the sidebar should never break the app — content remains accessible.

### Tab Navigation
- Use `TabView` sparingly. Tabs work for peer sections of equal weight (like Settings panes).
- macOS tabs sit at the top of the content area, not at the bottom (that's iOS).

### Hierarchical (Drill-Down)
- Use `NavigationStack` or `NavigationSplitView` with detail columns.
- Provide a back button or breadcrumb trail. Keyboard shortcut: Cmd+[ for back.

### Flat with Search
- For content-heavy views, rely on search + filters rather than deep hierarchy.
- `NSSearchField` bridge provides native macOS search behavior including recents.

---

## Controls

### Buttons
- Use system button styles: `.borderedProminent` for primary actions, `.bordered` for secondary, `.plain` for tertiary.
- Default button (Return key) should be visually prominent. Set with `.keyboardShortcut(.defaultAction)`.
- Destructive actions use red tint and require confirmation (alert or popover).

### Toggles and Checkboxes
- macOS uses checkboxes, not iOS-style toggles, for on/off states in forms.
- Use `Toggle(isOn:)` — SwiftUI renders the correct control for the platform.
- Group related checkboxes with a section header.

### Segmented Controls
- Use `Picker` with `.segmented` style for mutually exclusive options (2-5 items).
- Keep labels short. Icons + text or icons alone work well.

### Sliders
- Include min/max labels. Show the current value when precision matters.
- Use `.linear` for continuous ranges.

### Text Fields
- Use `.textFieldStyle(.roundedBorder)` for standard inputs.
- Provide placeholder text that describes expected input.
- Support Cmd+A (select all), Cmd+Z (undo), and standard text editing shortcuts.

### Popovers
- Preferred over modals for non-blocking secondary UI.
- Attach to the control that triggered them with `.popover(isPresented:)`.
- Arrow points to the anchor. Content is compact and focused.

---

## Typography

### System Font (SF Pro)
- macOS uses SF Pro as the default. It's designed for screen legibility.
- Standard text sizes: 11pt (small/metadata), 13pt (body), 15pt (emphasized), 17pt (subheading), 20pt (heading), 24pt (title).
- Use `Font.system()` with semantic styles: `.body`, `.headline`, `.title`, `.title2`, `.title3`, `.caption`, `.footnote`.

### Weight Hierarchy
- Use weight to establish hierarchy within the same size: `.regular` for body, `.semibold` for labels, `.bold` for emphasis.
- Avoid using more than 2-3 weights in a single view — it becomes noisy.

### Monospace
- Use `Font.system(.body, design: .monospaced)` for code, paths, and technical content.
- SF Mono is the system monospace font.

---

## Color and Materials

### Semantic Colors
- Prefer semantic colors over hard-coded values: `.primary`, `.secondary`, `.accentColor`.
- System colors adapt automatically to light/dark mode and increased contrast.
- Use `.tint()` for interactive elements, not background fills.

### Vibrancy and Translucency
- macOS sidebars and toolbars use translucent materials by default.
- `NSVisualEffectView` (or `.background(.ultraThinMaterial)`) provides system-standard blur.
- Materials adapt to the content behind them — this is a core macOS design language.

### Dark Mode
- Every custom color must have a light and dark variant.
- Test both appearances thoroughly. Pay attention to:
  - Borders and separators (may disappear in dark mode)
  - Shadow visibility (reduce shadow opacity in dark mode)
  - Image contrast (provide dark-mode asset variants where needed)

### Accent Color
- Respect the user's system accent color. Use `Color.accentColor` for interactive highlights.
- The user can change this in System Settings — never assume it's blue.

---

## Spacing and Layout

### Grid System
- Use an 8pt grid for spacing and sizing. Multiples: 4, 8, 16, 24, 32, 48.
- Consistent spacing creates visual rhythm and alignment.

### Margins
- Window content should have at least 20pt margins from edges.
- Sidebar items typically have 8-16pt horizontal padding.

### Grouping
- Related controls should be visually grouped with consistent internal spacing.
- Use whitespace (not boxes or dividers) as the primary grouping mechanism.
- Use `Section` in `Form` and `List` for standard grouping.

### Alignment
- Left-align labels and text. Right-align numeric values.
- Toolbar items center-align or trailing-align depending on function.

---

## Icons and SF Symbols

### SF Symbols
- Prefer SF Symbols for all standard actions. They match the system font metrics.
- Use rendering modes: `.monochrome` for toolbar icons, `.hierarchical` or `.multicolor` for content.
- Standard sizes: 13pt (inline), 16pt (list), 20pt+ (feature icons).

### Custom Icons
- Match SF Symbol weight and optical size when creating custom icons.
- Provide template images (single-color, tintable) for toolbar items.
- Include @2x and @3x variants for Retina displays.

---

## Motion and Animation

### Purpose
- Animation should communicate, not decorate. Every animation should answer: "What changed? Where did it come from? Where is it going?"
- Avoid gratuitous animation — it slows perceived performance and annoys power users.

### System Conventions
- Use `.animation(.default)` for standard state changes.
- Sheets slide down. Popovers fade in with a slight scale. Alerts appear centered with a quick scale-up.
- Navigation transitions use horizontal slides (push/pop).

### Accessibility
- Always respect `accessibilityReduceMotion`. When enabled:
  - Replace slides with fades
  - Reduce or eliminate bouncing/spring animations
  - Keep animations under 200ms

### Performance
- Animate transform properties (opacity, scale, offset) rather than layout changes.
- Use `.drawingGroup()` for complex view hierarchies that animate as a unit.

---

## Accessibility

### VoiceOver
- Every interactive element must have an accessibility label.
- Use `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityValue()`.
- Group related elements with `.accessibilityElement(children: .combine)`.

### Keyboard Navigation
- All interactive elements must be reachable via Tab key.
- Use `.focusable()` and `@FocusState` to manage focus.
- Provide keyboard shortcuts for frequent actions.
- Full Keyboard Access must work — test with it enabled.

### Dynamic Type
- Support larger text sizes. Use relative sizing rather than fixed pixel values.
- Test at the largest accessibility size.

### Reduce Motion, Reduce Transparency, Increase Contrast
- Query `@Environment(\.accessibilityReduceMotion)`, `@Environment(\.accessibilityReduceTransparency)`.
- Provide solid backgrounds when transparency is reduced.
- Increase border weight and contrast when high contrast is enabled.

---

## Menu Bar and Dock

### Menu Bar Menus
- Provide a full menu bar with standard menus (File, Edit, View, Window, Help).
- Include keyboard shortcuts for all menu items.
- Use `CommandGroup` and `CommandMenu` in the SwiftUI `App` struct.

### Context Menus
- Right-click context menus should be available on all interactive content.
- Include the most relevant actions (not everything from the menu bar).
- Use `.contextMenu` modifier.

### Dock
- The Dock icon represents the app. Badge it with `.badge()` for notifications.
- Support Dock menu with common actions via `NSApplication.delegate`.

---

## Settings (Preferences)

- Use `Settings` scene in SwiftUI for the preferences window.
- Organize with `TabView` — each tab is a category (General, Appearance, Advanced, etc.).
- Keyboard shortcut: Cmd+, must open preferences.
- Settings should take effect immediately (live preview) where possible.
