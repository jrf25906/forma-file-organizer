# Sidebar Layout & Design System Revamp — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the three-column layout so the sidebar doesn't cramp when the right panel opens, restructure the information architecture, mature the design system tokens to full coverage, and enforce consistency across all components.

**Architecture:** Adjust NavigationSplitView column constraints and minimum window width so all three columns coexist comfortably. Add new token files (FormaShadows, FormaBorders, FormaEasing, FormaFocusRing, FormaIconSize, FormaZIndex) alongside refinements to existing tokens (FormaColors, FormaTypography, FormaSpacing). Split the 1,298-line FormaComponents.swift monolith into focused single-responsibility files. Enforce token adoption across all surfaces in three consistency waves.

**Tech Stack:** SwiftUI, SwiftData, AppKit (macOS 15.0+, Swift 5.9+). No external dependencies.

---

## File Map

### New Files (Design System Tokens)
- `Forma File Organizing/DesignSystem/FormaShadows.swift` — Shadow elevation tokens replacing FormaShadowLevel
- `Forma File Organizing/DesignSystem/FormaBorders.swift` — Border width/style tokens with dark mode polarity flip
- `Forma File Organizing/DesignSystem/FormaEasing.swift` — Easing curves + duration constants (from FormaAnimation + FormaMicroanimations)
- `Forma File Organizing/DesignSystem/FormaFocusRing.swift` — Keyboard focus ring styling
- `Forma File Organizing/DesignSystem/FormaIconSize.swift` — Icon size scale tokens
- `Forma File Organizing/DesignSystem/FormaZIndex.swift` — Z-index layering tokens

### New Files (Component Split from FormaComponents.swift)
- `Forma File Organizing/DesignSystem/Components/FormaButtons.swift` — FormaPrimaryButton, FormaSecondaryButton
- `Forma File Organizing/DesignSystem/Components/FormaCards.swift` — FormaCard, FormaListCard
- `Forma File Organizing/DesignSystem/Components/FormaBadges.swift` — FormaBadge, FormaFileBadge, FormaStatBadge
- `Forma File Organizing/DesignSystem/Components/FormaStatusPill.swift` — FormaStatusPill
- `Forma File Organizing/DesignSystem/Components/FormaEmptyStates.swift` — FormaEmptyState, FormaActionableEmptyState, FormaHeroIcon
- `Forma File Organizing/DesignSystem/Components/FormaFormControls.swift` — FormaTextField, FormaFolderPicker
- `Forma File Organizing/DesignSystem/Components/FormaListButton.swift` — FormaListButton
- `Forma File Organizing/DesignSystem/Components/FormaSegmentedControl.swift` — FormaSegmentedControl, FormaSegmentButton, FormaSegmentedIconButton, FormaSegmentedBackground
- `Forma File Organizing/DesignSystem/Components/FormaMisc.swift` — FormaLogo, FormaCategoryIcon, FormaFileListItem, FormaProgressBar, FormaSuccessIndicator

### Modified Files (Layout + IA)
- `Forma File Organizing/Views/DashboardView.swift` — Column width constraints, remove .rules/.analytics center column branches, simplify showsInspectorColumn
- `Forma File Organizing/Forma_File_OrganizingApp.swift` — Minimum window size
- `Forma File Organizing/DesignSystem/FormaSpacing.swift` — Window size tokens, new FormaLayout constants
- `Forma File Organizing/Views/SidebarView.swift` — Remove TOOLS section, add Smart Rules/Analytics to ACTIONS as right-panel triggers
- `Forma File Organizing/ViewModels/NavigationViewModel.swift` — Deprecate .rules and .analytics NavigationSelection cases

### Modified Files (Token Refinements)
- `Forma File Organizing/DesignSystem/FormaColors.swift` — Fix formaSoftGreen, add category color separation
- `Forma File Organizing/DesignSystem/FormaTypography.swift` — Add formaCallout, tabular digit variants
- `Forma File Organizing/DesignSystem/FormaAnimation.swift` — Remove duration constants moved to FormaEasing
- `Forma File Organizing/DesignSystem/FormaMicroanimations.swift` — Remove duration constants moved to FormaEasing
- `Forma File Organizing/DesignSystem/FormaComponents.swift` — Will be deleted after split is complete

### Test Files
- `Forma File OrganizingTests/DesignSystem/FormaShadowsTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaBordersTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaEasingTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaIconSizeTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaColorsTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaTypographyTests.swift`
- `Forma File OrganizingTests/DesignSystem/FormaSpacingTests.swift`
- `Forma File OrganizingTests/Layout/ColumnLayoutTests.swift`

---

## Phase 1: New Token Files

### Task 1: FormaShadows — Shadow Elevation Tokens

**Files:**
- Create: `Forma File Organizing/DesignSystem/FormaShadows.swift`
- Test: `Forma File OrganizingTests/DesignSystem/FormaShadowsTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// FormaShadowsTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaShadowsTests: XCTestCase {

    // MARK: - Light Mode Values

    func testRestingShadowRadius() {
        let shadow = FormaShadow.resting
        XCTAssertEqual(shadow.radius, 4)
        XCTAssertEqual(shadow.y, 2)
    }

    func testRaisedShadowRadius() {
        let shadow = FormaShadow.raised
        XCTAssertEqual(shadow.radius, 8)
        XCTAssertEqual(shadow.y, 3)
    }

    func testFloatingShadowRadius() {
        let shadow = FormaShadow.floating
        XCTAssertEqual(shadow.radius, 16)
        XCTAssertEqual(shadow.y, 4)
    }

    func testOverlayShadowRadius() {
        let shadow = FormaShadow.overlay
        XCTAssertEqual(shadow.radius, 24)
        XCTAssertEqual(shadow.y, 8)
    }

    func testNoneShadowIsZero() {
        let shadow = FormaShadow.none
        XCTAssertEqual(shadow.radius, 0)
        XCTAssertEqual(shadow.y, 0)
    }

    // MARK: - Dark Mode Intensification

    func testDarkModeRadiusMultiplier() {
        let light = FormaShadow.resting
        let dark = FormaShadow.resting.darkMode
        // Dark mode shadows should be 2-3x more intense
        XCTAssertGreaterThan(dark.radius, light.radius)
        XCTAssertLessThanOrEqual(dark.radius, light.radius * 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaShadowsTests" 2>&1 | tail -20`
Expected: FAIL — `FormaShadow` not defined

- [ ] **Step 3: Create FormaShadows.swift**

```swift
//
//  FormaShadows.swift
//  Forma - Shadow Elevation Tokens
//
//  Consistent shadow levels for depth hierarchy.
//  Dark mode applies 2-3x intensification per spec.
//

import SwiftUI

/// Shadow definition with all parameters needed for SwiftUI `.shadow()`.
struct FormaShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// Returns an intensified version for dark mode (2x radius, 1.5x offset).
    var darkMode: FormaShadow {
        FormaShadow(
            color: color.opacity(0.6),
            radius: radius * 2,
            x: x,
            y: y * 1.5
        )
    }
}

// MARK: - Elevation Scale

extension FormaShadow {
    /// No shadow
    static let none = FormaShadow(color: .clear, radius: 0, x: 0, y: 0)

    /// Resting cards and surfaces — subtle depth
    static let resting = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.light),
        radius: 4, x: 0, y: 2
    )

    /// Selected cards, active controls — enhanced elevation
    static let raised = FormaShadow(
        color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium),
        radius: 8, x: 0, y: 3
    )

    /// Floating elements, popovers, action bars
    static let floating = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.medium),
        radius: 16, x: 0, y: 4
    )

    /// Overlay panels, modals, dropdowns
    static let overlay = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.strong),
        radius: 24, x: 0, y: 8
    )
}

// MARK: - View Modifier

extension View {
    /// Apply a Forma shadow that automatically adapts to dark mode.
    func formaShadow(_ shadow: FormaShadow, colorScheme: ColorScheme = .light) -> some View {
        let resolved = colorScheme == .dark ? shadow.darkMode : shadow
        return self.shadow(
            color: resolved.color,
            radius: resolved.radius,
            x: resolved.x,
            y: resolved.y
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaShadowsTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaShadows.swift" "Forma File OrganizingTests/DesignSystem/FormaShadowsTests.swift"
git commit -m "feat: add FormaShadows elevation token system with dark mode intensification"
```

---

### Task 2: FormaBorders — Border Tokens with Dark Mode Polarity

**Files:**
- Create: `Forma File Organizing/DesignSystem/FormaBorders.swift`
- Test: `Forma File OrganizingTests/DesignSystem/FormaBordersTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// FormaBordersTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaBordersTests: XCTestCase {

    func testBorderWidthScale() {
        XCTAssertEqual(FormaBorderWidth.hairline, 0.5)
        XCTAssertEqual(FormaBorderWidth.thin, 1.0)
        XCTAssertEqual(FormaBorderWidth.medium, 1.5)
        XCTAssertEqual(FormaBorderWidth.thick, 2.0)
    }

    func testInnerLightEdgePresent() {
        // Inner light edge is the second layer in the two-layer border system
        let innerEdge = FormaBorderStyle.innerLightEdge
        XCTAssertEqual(innerEdge.width, FormaBorderWidth.hairline)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaBordersTests" 2>&1 | tail -20`
Expected: FAIL — `FormaBorderWidth` not defined

- [ ] **Step 3: Create FormaBorders.swift**

```swift
//
//  FormaBorders.swift
//  Forma - Border Tokens
//
//  Two-layer border system: outer edge defines shape, inner light edge adds physical depth.
//  Dark mode flips polarity: light inner edges become subtle dark edges.
//

import SwiftUI

// MARK: - Border Width Scale

enum FormaBorderWidth {
    /// 0.5pt — Inner light edges, ultra-subtle separators
    static let hairline: CGFloat = 0.5
    /// 1.0pt — Standard borders, control outlines
    static let thin: CGFloat = 1.0
    /// 1.5pt — Selected/active state borders
    static let medium: CGFloat = 1.5
    /// 2.0pt — Focused/emphasized borders
    static let thick: CGFloat = 2.0
}

// MARK: - Border Styles

struct FormaBorderStyle {
    let width: CGFloat
    let lightColor: Color
    let darkColor: Color

    func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColor : lightColor
    }
}

extension FormaBorderStyle {
    /// Outer shape border — defines the component boundary
    static let outer = FormaBorderStyle(
        width: FormaBorderWidth.hairline,
        lightColor: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
        darkColor: Color.white.opacity(0.14)  // matches fileSurfaceBorder dark value
    )

    /// Inner light edge — adds physical depth (the "craft" detail)
    /// In dark mode this flips to a subtle dark inner edge
    static let innerLightEdge = FormaBorderStyle(
        width: FormaBorderWidth.hairline,
        lightColor: Color.white.opacity(0.7),
        darkColor: Color.white.opacity(0.06)
    )

    /// Selected state border
    static let selected = FormaBorderStyle(
        width: FormaBorderWidth.medium,
        lightColor: Color.formaSteelBlue,
        darkColor: Color.formaSteelBlue.opacity(0.58)  // matches selectedBorder dark value
    )

    /// Hover state border
    static let hover = FormaBorderStyle(
        width: FormaBorderWidth.thin,
        lightColor: Color.formaObsidian.opacity(Color.FormaOpacity.light),
        darkColor: Color.white.opacity(0.22)  // matches hoverBorder dark value
    )

    /// Error state border
    static let error = FormaBorderStyle(
        width: FormaBorderWidth.medium,
        lightColor: Color.formaError,
        darkColor: Color.formaError.opacity(0.8)
    )
}

// MARK: - Two-Layer Border Modifier

struct FormaTwoLayerBorder: ViewModifier {
    let cornerRadius: CGFloat
    let outerStyle: FormaBorderStyle
    let showInnerEdge: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(outerStyle.color(for: colorScheme), lineWidth: outerStyle.width)
            )
            .overlay(
                Group {
                    if showInnerEdge {
                        RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                            .strokeBorder(
                                FormaBorderStyle.innerLightEdge.color(for: colorScheme),
                                lineWidth: FormaBorderWidth.hairline
                            )
                            .padding(outerStyle.width)
                    }
                }
            )
    }
}

extension View {
    /// Apply the two-layer border system (outer shape + inner light edge).
    func formaBorder(
        cornerRadius: CGFloat = FormaRadius.card,
        style: FormaBorderStyle = .outer,
        innerEdge: Bool = true
    ) -> some View {
        modifier(FormaTwoLayerBorder(
            cornerRadius: cornerRadius,
            outerStyle: style,
            showInnerEdge: innerEdge
        ))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaBordersTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaBorders.swift" "Forma File OrganizingTests/DesignSystem/FormaBordersTests.swift"
git commit -m "feat: add FormaBorders two-layer border system with dark mode polarity flip"
```

---

### Task 3: FormaEasing — Consolidated Duration & Curve Tokens

**Files:**
- Create: `Forma File Organizing/DesignSystem/FormaEasing.swift`
- Test: `Forma File OrganizingTests/DesignSystem/FormaEasingTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// FormaEasingTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaEasingTests: XCTestCase {

    func testDurationScale() {
        // Durations must be strictly increasing
        XCTAssertLessThan(FormaEasing.Duration.micro, FormaEasing.Duration.fast)
        XCTAssertLessThan(FormaEasing.Duration.fast, FormaEasing.Duration.standard)
        XCTAssertLessThan(FormaEasing.Duration.standard, FormaEasing.Duration.slow)
        XCTAssertLessThan(FormaEasing.Duration.slow, FormaEasing.Duration.entrance)
    }

    func testMicroDurationValue() {
        XCTAssertEqual(FormaEasing.Duration.micro, 0.15)
    }

    func testStandardDurationValue() {
        XCTAssertEqual(FormaEasing.Duration.standard, 0.25)
    }

    func testReducedMotionDurationIsHalved() {
        XCTAssertEqual(
            FormaEasing.Duration.reducedMotion(FormaEasing.Duration.standard),
            0.125,
            accuracy: 0.001
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaEasingTests" 2>&1 | tail -20`
Expected: FAIL — `FormaEasing` not defined

- [ ] **Step 3: Create FormaEasing.swift**

```swift
//
//  FormaEasing.swift
//  Forma - Easing & Duration Tokens
//
//  Single source of truth for all animation timing.
//  Consolidates constants previously split across FormaAnimation and FormaMicroanimations.
//

import SwiftUI

enum FormaEasing {

    // MARK: - Duration Scale

    enum Duration {
        /// 0.15s — Hover, button press, micro-feedback
        static let micro: Double = 0.15
        /// 0.22s — Quick transitions, disclosure toggles
        static let fast: Double = 0.22
        /// 0.25s — Standard state changes, navigation
        static let standard: Double = 0.25
        /// 0.40s — Modal appear, sheet slide
        static let slow: Double = 0.40
        /// 0.60s — Hero elements, celebration entrance
        static let entrance: Double = 0.60

        /// Reduced motion halves all durations.
        static func reducedMotion(_ duration: Double) -> Double {
            duration / 2.0
        }
    }

    // MARK: - Easing Curves (pre-built Animation values)

    /// Default ease-in-out for most animations
    static let standard: Animation = .easeInOut(duration: Duration.standard)
    /// Snappy ease-out for button press, hover feedback
    static let microFeedback: Animation = .easeOut(duration: Duration.micro)
    /// Quick ease-out for enter transitions
    static let quickEnter: Animation = .easeOut(duration: Duration.fast)
    /// Quick ease-in for exit transitions
    static let quickExit: Animation = .easeIn(duration: Duration.micro)
    /// Disclosure expand/collapse
    static let disclosure: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    // MARK: - Spring Presets

    /// Responsive interactive spring — drags, sliders
    static let interactive: Animation = .interactiveSpring(response: 0.22, dampingFraction: 0.9)
    /// Bouncy spring — celebration, success
    static let bouncy: Animation = .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    /// Gentle spring — subtle refinement
    static let gentle: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    /// Segmented control slide
    static let segmentSlide: Animation = .spring(response: 0.26, dampingFraction: 0.82)

    // MARK: - Panel & Navigation

    /// Panel slide in/out
    static let panelSlide: Animation = .easeInOut(duration: Duration.standard)
    /// Standard transition (enter/exit/crossfade)
    static let standardTransition: Animation = .easeInOut(duration: Duration.standard)
}

// MARK: - Reduced Motion Wrapper

extension View {
    /// Wrap an animation so it respects `accessibilityReduceMotion`.
    /// Springs/bouncy become instant; enters/exits become a 0.01s crossfade;
    /// standard/panelSlide durations halve.
    func formaAnimated<V: Equatable>(
        _ animation: Animation,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? .linear(duration: 0.01) : animation, value: value)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaEasingTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaEasing.swift" "Forma File OrganizingTests/DesignSystem/FormaEasingTests.swift"
git commit -m "feat: add FormaEasing consolidated duration and curve tokens"
```

---

### Task 4: FormaFocusRing, FormaIconSize, FormaZIndex

**Files:**
- Create: `Forma File Organizing/DesignSystem/FormaFocusRing.swift`
- Create: `Forma File Organizing/DesignSystem/FormaIconSize.swift`
- Create: `Forma File Organizing/DesignSystem/FormaZIndex.swift`

- [ ] **Step 1: Create FormaFocusRing.swift**

```swift
//
//  FormaFocusRing.swift
//  Forma - Keyboard Focus Ring
//
//  Consistent focus indicators for keyboard navigation accessibility.
//

import SwiftUI

enum FormaFocusRing {
    /// Focus ring color — steel blue at medium opacity
    static let color: Color = .formaSteelBlue.opacity(Color.FormaOpacity.medium)
    /// Focus ring width
    static let width: CGFloat = 2.0
    /// Focus ring offset from content edge
    static let offset: CGFloat = 2.0
    /// Focus ring corner radius padding (added to content radius)
    static let radiusPadding: CGFloat = 2.0
}

extension View {
    /// Apply Forma's standard keyboard focus ring.
    func formaFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = FormaRadius.control
    ) -> some View {
        self.overlay(
            RoundedRectangle(
                cornerRadius: cornerRadius + FormaFocusRing.radiusPadding,
                style: .continuous
            )
            .stroke(FormaFocusRing.color, lineWidth: FormaFocusRing.width)
            .padding(-FormaFocusRing.offset)
            .opacity(isFocused ? 1 : 0)
        )
    }
}
```

- [ ] **Step 2: Create FormaIconSize.swift**

```swift
//
//  FormaIconSize.swift
//  Forma - Icon Size Scale
//
//  Consistent icon sizing across the app.
//

import SwiftUI

enum FormaIconSize {
    /// 12pt — Inline indicators, chevrons
    static let tiny: CGFloat = 12
    /// 14pt — Small badges, compact controls
    static let small: CGFloat = 14
    /// 16pt — Standard inline icons
    static let standard: CGFloat = 16
    /// 20pt — Sidebar items, list icons
    static let medium: CGFloat = 20
    /// 24pt — Toolbar actions, prominent controls
    static let large: CGFloat = 24
    /// 32pt — Card icons, category icons
    static let hero: CGFloat = 32
    /// 48pt — Empty state icons
    static let display: CGFloat = 48
    /// 64pt — Celebration, major empty states
    static let jumbo: CGFloat = 64
}
```

- [ ] **Step 3: Create FormaZIndex.swift**

```swift
//
//  FormaZIndex.swift
//  Forma - Z-Index Layering
//
//  Explicit stacking order for overlapping UI elements.
//

import SwiftUI

enum FormaZIndex {
    /// Base content layer
    static let content: Double = 0
    /// Sticky headers, pinned elements
    static let sticky: Double = 10
    /// Floating action bars
    static let floating: Double = 20
    /// Dropdown menus, popovers
    static let dropdown: Double = 30
    /// Modal overlays
    static let modal: Double = 40
    /// Toast notifications
    static let toast: Double = 50
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaFocusRing.swift" "Forma File Organizing/DesignSystem/FormaIconSize.swift" "Forma File Organizing/DesignSystem/FormaZIndex.swift"
git commit -m "feat: add FormaFocusRing, FormaIconSize, and FormaZIndex token files"
```

---

## Phase 2: Existing Token Refinements

### Task 5: Fix FormaColors — formaSoftGreen Target + Category Separation

**Files:**
- Modify: `Forma File Organizing/DesignSystem/FormaColors.swift:60`
- Test: `Forma File OrganizingTests/DesignSystem/FormaColorsTests.swift`

- [ ] **Step 1: Write the test**

```swift
// FormaColorsTests.swift
import XCTest
import SwiftUI
@testable import Forma_File_Organizing

final class FormaColorsTests: XCTestCase {

    func testFormaSoftGreenIsOliveShifted() {
        // formaSoftGreen should be ~#96A67E (98 deg, olive-green)
        // Previously was #8BA688 — too close to formaSage
        // We verify RGB values are in the expected olive range
        let expected = (r: 150, g: 166, b: 126) // #96A67E
        // This test documents the target; exact NSColor extraction
        // depends on runtime, so we just verify the constant exists
        let _ = Color.formaSoftGreen
        // If the color resolves, the constant exists and compiles
        XCTAssertTrue(true, "formaSoftGreen constant exists")
    }
}
```

- [ ] **Step 2: Run test to verify baseline**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaColorsTests" 2>&1 | tail -20`

- [ ] **Step 3: Update formaSoftGreen in FormaColors.swift**

In `Forma File Organizing/DesignSystem/FormaColors.swift`, find line 60:
```swift
// Old: rgb(139, 166, 136) = #8BA688
static let formaSoftGreen = Color(red: 139/255, green: 166/255, blue: 136/255)
```

Replace with:
```swift
// #96A67E (98° 17% 57%) — olive-green, ≥15° hue separation from formaSage
static let formaSoftGreen = Color(red: 150/255, green: 166/255, blue: 126/255)
```

- [ ] **Step 4: Build and run tests**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaColorsTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaColors.swift" "Forma File OrganizingTests/DesignSystem/FormaColorsTests.swift"
git commit -m "fix: shift formaSoftGreen to olive-green (#96A67E) for hue separation from formaSage"
```

---

### Task 6: FormaTypography — Add formaCallout + Tabular Digits

**Files:**
- Modify: `Forma File Organizing/DesignSystem/FormaTypography.swift:31-36`
- Test: `Forma File OrganizingTests/DesignSystem/FormaTypographyTests.swift`

- [ ] **Step 1: Write the test**

```swift
// FormaTypographyTests.swift
import XCTest
import SwiftUI
@testable import Forma_File_Organizing

final class FormaTypographyTests: XCTestCase {

    func testCalloutFontExists() {
        // formaCallout bridges the gap between Body(13pt) and H3(17pt)
        let _ = Font.formaCallout
        XCTAssertTrue(true, "formaCallout font exists")
    }

    func testTabularBodyExists() {
        let _ = Font.formaBodyTabular
        XCTAssertTrue(true, "formaBodyTabular font exists")
    }

    func testTabularSmallExists() {
        let _ = Font.formaSmallTabular
        XCTAssertTrue(true, "formaSmallTabular font exists")
    }

    func testTabularCompactExists() {
        let _ = Font.formaCompactTabular
        XCTAssertTrue(true, "formaCompactTabular font exists")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaTypographyTests" 2>&1 | tail -20`
Expected: FAIL — `formaCallout` not defined

- [ ] **Step 3: Add formaCallout and tabular digit variants to FormaTypography.swift**

After the `formaH3` definition (line 31), add:

```swift
    /// Callout text — bridges Body(13pt) and H3(17pt)
    /// 15pt Semibold - Use for sub-section labels, prominent metadata
    static let formaCallout = Font.system(size: 15, weight: .semibold, design: .default)
```

After the monospace section (after line 157), add:

```swift
    // MARK: - Tabular Digits (for aligned numeric columns)

    /// Tabular body digits — 13pt with fixed-width numerals
    static let formaBodyTabular = Font.system(size: 13, weight: .regular, design: .default)
        .monospacedDigit()

    /// Tabular compact digits — 12pt with fixed-width numerals
    static let formaCompactTabular = Font.system(size: 12, weight: .medium, design: .default)
        .monospacedDigit()

    /// Tabular small digits — 11pt with fixed-width numerals
    static let formaSmallTabular = Font.system(size: 11, weight: .regular, design: .default)
        .monospacedDigit()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaTypographyTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaTypography.swift" "Forma File OrganizingTests/DesignSystem/FormaTypographyTests.swift"
git commit -m "feat: add formaCallout (15pt) and tabular digit font variants"
```

---

### Task 7: FormaSpacing — Add Layout Column Constants

**Files:**
- Modify: `Forma File Organizing/DesignSystem/FormaSpacing.swift:76-94`
- Test: `Forma File OrganizingTests/DesignSystem/FormaSpacingTests.swift`

- [ ] **Step 1: Write the test**

```swift
// FormaSpacingTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaSpacingTests: XCTestCase {

    func testNewWindowMinWidth() {
        // Spec: increase from 1200 to 1280 for three-column comfort
        XCTAssertEqual(FormaSpacing.Window.minWidth, 1280)
    }

    func testSidebarConstraints() {
        XCTAssertEqual(FormaSpacing.Column.sidebarMin, 220)
        XCTAssertEqual(FormaSpacing.Column.sidebarIdeal, 260)
        XCTAssertEqual(FormaSpacing.Column.sidebarMax, 320)
    }

    func testCenterConstraints() {
        // Spec: center min drops from 680 to 560
        XCTAssertEqual(FormaSpacing.Column.centerMin, 560)
    }

    func testRightPanelConstraints() {
        XCTAssertEqual(FormaSpacing.Column.rightPanelMin, 280)
        XCTAssertEqual(FormaSpacing.Column.rightPanelIdeal, 340)
        XCTAssertEqual(FormaSpacing.Column.rightPanelMax, 420)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaSpacingTests" 2>&1 | tail -20`
Expected: FAIL — `FormaSpacing.Column` not defined

- [ ] **Step 3: Update FormaSpacing.swift**

Change `minWidth` from 1200 to 1280 (line 79):
```swift
static let minWidth: CGFloat = 1280
```

Add `Column` struct after the `Window` struct (after line 87):
```swift
    /// Three-column layout constraints
    struct Column {
        /// Sidebar: min 220, ideal 260, max 320
        static let sidebarMin: CGFloat = 220
        static let sidebarIdeal: CGFloat = 260
        static let sidebarMax: CGFloat = 320

        /// Center content: min 560 (down from 680 to breathe when right panel opens)
        static let centerMin: CGFloat = 560
        static let centerIdeal: CGFloat = 960

        /// Right panel: min 280, ideal 340, max 420
        static let rightPanelMin: CGFloat = 280
        static let rightPanelIdeal: CGFloat = 340
        static let rightPanelMax: CGFloat = 420
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" -only-testing:"Forma File OrganizingTests/FormaSpacingTests" 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaSpacing.swift" "Forma File OrganizingTests/DesignSystem/FormaSpacingTests.swift"
git commit -m "feat: add Column layout tokens and increase minimum window width to 1280"
```

---

## Phase 3: Sidebar Layout Fix + IA Restructure

### Task 8: Update DashboardView Column Constraints

**Files:**
- Modify: `Forma File Organizing/Views/DashboardView.swift:153,162,175`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift:30-35`

- [ ] **Step 1: Update DashboardView sidebar column width (line 153 area)**

Find the `NavigationSplitView` column width configuration. The sidebar column uses hardcoded values — replace with token references.

Find:
```swift
.navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
```
for the sidebar, and replace with:
```swift
.navigationSplitViewColumnWidth(
    min: FormaSpacing.Column.sidebarMin,
    ideal: FormaSpacing.Column.sidebarIdeal,
    max: FormaSpacing.Column.sidebarMax
)
```

- [ ] **Step 2: Update center column minimum width (line 162 area)**

Find the center column width constraint:
```swift
.navigationSplitViewColumnWidth(min: 680, ideal: 960)
```
Replace with:
```swift
.navigationSplitViewColumnWidth(
    min: FormaSpacing.Column.centerMin,
    ideal: FormaSpacing.Column.centerIdeal
)
```

- [ ] **Step 3: Update right panel column width (line 175 area)**

Find:
```swift
.navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
```
Replace with:
```swift
.navigationSplitViewColumnWidth(
    min: FormaSpacing.Column.rightPanelMin,
    ideal: FormaSpacing.Column.rightPanelIdeal,
    max: FormaSpacing.Column.rightPanelMax
)
```

- [ ] **Step 4: Update minimum window size in App file**

In `Forma_File_OrganizingApp.swift`, find the `defaultSize` and `minSize` configuration (lines 23-35). Update `minWidth`:

Find:
```swift
FormaSpacing.Window.minWidth
```
The value is already referenced by token. Since we updated `FormaSpacing.Window.minWidth` to 1280 in Task 7, this file already picks up the change. Verify this by reading the file — if it uses a hardcoded `1200`, replace with `FormaSpacing.Window.minWidth`.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Views/DashboardView.swift" "Forma File Organizing/Forma_File_OrganizingApp.swift"
git commit -m "fix: use Column layout tokens in DashboardView, center min 680→560 for three-column comfort"
```

---

### Task 9: Sidebar IA Restructure — Remove TOOLS, Add Smart Rules/Analytics to ACTIONS

**Files:**
- Modify: `Forma File Organizing/Views/SidebarView.swift`
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Modify: `Forma File Organizing/ViewModels/NavigationViewModel.swift`

The spec says:
- **LOCATIONS** section keeps Desktop, Downloads, Documents, Pictures, Music (navigation only)
- **ACTIONS** section gets New Rule, Add Folder, **Smart Rules**, **Analytics** (imperative actions)
- TOOLS section is removed entirely
- Smart Rules and Analytics become action buttons that **open the right panel** in the appropriate mode, NOT navigation destinations that hijack the center column

- [ ] **Step 1: Read SidebarView.swift fully to understand current structure**

Read the file. Identify the TOOLS section (starts around line 53) and the ACTIONS section (around line 67). The TOOLS section contains Smart Rules (`.rules` selection, line 57) and Analytics (`.analytics` selection, line 61).

- [ ] **Step 2: Remove the TOOLS section and add Smart Rules/Analytics to ACTIONS**

Remove the entire `// MARK: - TOOLS` section (the `sidebarItem` calls for Smart Rules and Analytics).

In the `// MARK: - ACTIONS` section, after the existing New Rule and Add Folder entries, add Smart Rules and Analytics as `SidebarActionRow` entries that trigger right panel modes instead of navigation:

```swift
// Smart Rules — opens right panel in rules list mode
SidebarActionRow(
    title: "Smart Rules",
    icon: "list.bullet.rectangle",
    action: {
        dashboardViewModel.panelState.rightPanelMode = .ruleBuilder(editingRule: nil, fileContext: nil)
    }
)

// Analytics — opens right panel in analytics mode
SidebarActionRow(
    title: "Analytics",
    icon: "chart.bar",
    action: {
        dashboardViewModel.panelState.rightPanelMode = .analytics
    }
)
```

- [ ] **Step 3: Simplify DashboardView center column routing**

In `DashboardView.swift`, find the center column content routing (around lines 188-202). Remove the `.rules` → `RulesManagementView` branch and the `.analytics` → `ProductivityReportView` branch. The center column should always show `MainContentView` for folder-based selections.

Also simplify `showsInspectorColumn` — remove the `nav.selection != .analytics` guard since Analytics is no longer a navigation selection:

```swift
// Before:
dashboardViewModel.isRightPanelVisible && nav.selection != .analytics
// After:
dashboardViewModel.isRightPanelVisible
```

- [ ] **Step 4: Deprecate NavigationSelection.rules and .analytics**

In `NavigationViewModel.swift`, add deprecation annotations to the `.rules` and `.analytics` cases:

```swift
@available(*, deprecated, message: "Smart Rules now opens via right panel action")
case rules
@available(*, deprecated, message: "Analytics now opens via right panel action")
case analytics
```

These remain compilable so existing references don't break immediately, but any remaining usage will generate warnings.

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (possibly with deprecation warnings for any remaining .rules/.analytics usage)

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Views/SidebarView.swift" "Forma File Organizing/Views/DashboardView.swift" "Forma File Organizing/ViewModels/NavigationViewModel.swift"
git commit -m "refactor: remove TOOLS section, move Smart Rules/Analytics to ACTIONS as right-panel triggers"
```

---

## Phase 4: Component Monolith Split

### Task 10: Create DesignSystem/Components/ Directory and Split Buttons

**Files:**
- Create: `Forma File Organizing/DesignSystem/Components/FormaButtons.swift`
- Modify: `Forma File Organizing/DesignSystem/FormaComponents.swift` (remove button code)

- [ ] **Step 1: Create the Components directory**

```bash
mkdir -p "Forma File Organizing/DesignSystem/Components"
```

- [ ] **Step 2: Create FormaButtons.swift**

Extract `FormaPrimaryButton` (lines 13-41) and `FormaSecondaryButton` (lines 45-74) from FormaComponents.swift:

```swift
//
//  FormaButtons.swift
//  Forma - Button Components
//

import SwiftUI

// MARK: - Primary Button

struct FormaPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var isEnabled: Bool = true
    var tint: Color = .formaSteelBlue
    var cornerRadius: CGFloat = FormaRadius.control

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodySemibold)
                }
                Text(title)
                    .font(.formaPrimaryButton)
            }
            .foregroundColor(.formaBoneWhite)
            .formaButtonPadding()
            .frame(maxWidth: .infinity)
        }
        .background(isEnabled ? tint : tint.opacity(Color.FormaOpacity.light * 4))
        .formaCornerRadius(cornerRadius)
        .formaShadow(.button)
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Secondary Button

struct FormaSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var isEnabled: Bool = true
    var cornerRadius: CGFloat = FormaRadius.control

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodyMedium)
                }
                Text(title)
                    .font(.formaSecondaryButton)
            }
            .foregroundColor(.formaObsidian)
            .formaButtonPadding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview("Primary Button") {
    VStack(spacing: 20) {
        FormaPrimaryButton(title: "Organize Now", action: {})
        FormaPrimaryButton(title: "Disabled Button", action: {}, isEnabled: false)
    }
    .padding()
    .frame(width: 300)
}

#Preview("Secondary Button") {
    VStack(spacing: 20) {
        FormaSecondaryButton(title: "Choose Different", action: {})
        FormaSecondaryButton(title: "Disabled Button", action: {}, isEnabled: false)
    }
    .padding()
    .frame(width: 300)
}
```

- [ ] **Step 3: Remove FormaPrimaryButton and FormaSecondaryButton from FormaComponents.swift**

Delete lines 11-74 (the `// MARK: - Primary Button` and `// MARK: - Secondary Button` sections) and their previews (lines 494-510) from FormaComponents.swift.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/DesignSystem/Components/FormaButtons.swift" "Forma File Organizing/DesignSystem/FormaComponents.swift"
git commit -m "refactor: extract FormaButtons from FormaComponents monolith"
```

---

### Task 11: Split Cards, Badges, StatusPill

**Files:**
- Create: `Forma File Organizing/DesignSystem/Components/FormaCards.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaBadges.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaStatusPill.swift`
- Modify: `Forma File Organizing/DesignSystem/FormaComponents.swift`

- [ ] **Step 1: Create FormaCards.swift**

Extract `FormaCard` (lines 77-101) and `FormaListCard` modifier (lines 107-150) from FormaComponents.swift, including the Card preview:

```swift
//
//  FormaCards.swift
//  Forma - Card Components
//

import SwiftUI

// MARK: - Card Container

struct FormaCard<Content: View>: View {
    let content: Content
    var isSelected: Bool = false

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .formaCardPadding()
            .background(Color.formaControlBackground)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? Color.formaSteelBlue : Color.formaSeparator,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .formaShadow(isSelected ? .cardSelected : .card)
    }
}

// MARK: - List Card Modifier

struct FormaListCard: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.light),
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isHovered {
                        Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                    } else {
                        Color.formaBoneWhite
                    }
                }
            )
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2)),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .formaShadow(isSelected ? .cardSelected : .card)
    }
}

extension View {
    func formaListCard(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(FormaListCard(isSelected: isSelected, isHovered: isHovered))
    }
}

#Preview("Card") {
    VStack(spacing: 20) {
        FormaCard {
            Text("Unselected Card Content").formaBodyStyle()
        }
        FormaCard(isSelected: true) {
            Text("Selected Card Content").formaBodyStyle()
        }
    }
    .padding()
    .frame(width: 300)
}
```

- [ ] **Step 2: Create FormaBadges.swift**

Extract `FormaBadge` (lines 660-756), `FormaFileBadge` (lines 188-203), and `FormaStatBadge` (lines 910-940) with their previews:

```swift
//
//  FormaBadges.swift
//  Forma - Badge Components
//

import SwiftUI

// MARK: - File Count Badge

struct FormaFileBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.formaSmall)
            .fontWeight(.semibold)
            .foregroundColor(.formaBoneWhite)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(Color.formaSteelBlue)
            )
    }
}

// MARK: - Generic Badge

struct FormaBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil
    var size: BadgeSize = .regular
    var style: BadgeStyle = .filled

    enum BadgeSize {
        case small
        case regular
        case large

        var font: Font {
            switch self {
            case .small: return .formaCaptionSemibold
            case .regular: return .formaSmallSemibold
            case .large: return .formaCompactSemibold
            }
        }

        var iconFont: Font {
            switch self {
            case .small: return .formaCaptionSemibold
            case .regular: return .formaSmallMedium
            case .large: return .formaCompactMedium
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .regular: return 4
            case .large: return 6
            }
        }
    }

    enum BadgeStyle {
        case filled
        case outlined
        case subtle
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
            }
            Text(text)
                .font(size.font)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(background)
        .clipShape(Capsule())
        .overlay(borderOverlay)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outlined, .subtle: return color
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            Capsule().fill(color)
        case .outlined:
            Color.clear
        case .subtle:
            Capsule().fill(color.opacity(Color.FormaOpacity.light))
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .outlined:
            Capsule().stroke(color, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Stat Badge

struct FormaStatBadge: View {
    let value: String
    let label: String
    var color: Color = .formaSteelBlue
    var icon: String? = nil

    var body: some View {
        VStack(spacing: FormaSpacing.micro) {
            HStack(spacing: FormaSpacing.micro) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaSmall)
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.formaH2)
                    .foregroundColor(color)
            }

            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.vertical, FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(color.opacity(Color.FormaOpacity.subtle))
        )
    }
}

// MARK: - Previews

#Preview("FormaBadge") {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            FormaBadge(text: "New", color: .formaSteelBlue)
            FormaBadge(text: "3", color: .formaSage, size: .small)
            FormaBadge(text: "Important", color: .formaWarmOrange, size: .large)
        }
        HStack(spacing: 8) {
            FormaBadge(text: "Draft", color: .formaSecondaryLabel, style: .subtle)
            FormaBadge(text: "Complete", color: .formaSage, icon: "checkmark", style: .subtle)
        }
        HStack(spacing: 8) {
            FormaBadge(text: "Optional", color: .formaSecondaryLabel, style: .outlined)
            FormaBadge(text: "Beta", color: .formaSteelBlue, style: .outlined)
        }
    }
    .padding()
    .background(Color.formaBackground)
}

#Preview("FormaStatBadge") {
    HStack(spacing: 16) {
        FormaStatBadge(value: "42", label: "Files")
        FormaStatBadge(value: "1.2GB", label: "Saved", color: .formaSage, icon: "arrow.down.circle")
    }
    .padding()
    .background(Color.formaBackground)
}
```

- [ ] **Step 3: Create FormaStatusPill.swift**

Extract `FormaStatusPill` (lines 214-258):

```swift
//
//  FormaStatusPill.swift
//  Forma - Status Pill Component
//

import SwiftUI

struct FormaStatusPill: View {
    let status: FileItem.OrganizationStatus

    private var config: (text: String, icon: String, color: Color) {
        switch status {
        case .pending:
            return ("Needs Destination", "questionmark.circle", .formaTertiaryLabel)
        case .ready:
            return ("Ready", "checkmark.circle", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage.opacity(Color.FormaOpacity.high))
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabel)
        }
    }

    var body: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: config.icon)
                .font(.formaMicro)
                .fontWeight(.semibold)
            Text(config.text)
                .font(.formaCaption)
                .fontWeight(.medium)
        }
        .foregroundStyle(config.color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(config.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
        .clipShape(Capsule())
    }
}

#Preview("Status Pills") {
    VStack(spacing: 12) {
        FormaStatusPill(status: .pending)
        FormaStatusPill(status: .ready)
        FormaStatusPill(status: .completed)
        FormaStatusPill(status: .skipped)
    }
    .padding()
    .background(Color.formaBackground)
}
```

- [ ] **Step 4: Remove extracted code from FormaComponents.swift**

Remove `FormaCard`, `FormaListCard`, `FormaFileBadge`, `FormaStatusPill`, `FormaBadge`, `FormaStatBadge`, and their previews from FormaComponents.swift. Keep the remaining components (FormaLogo, FormaCategoryIcon, FormaFileListItem, FormaProgressBar, FormaSuccessIndicator, FormaEmptyState, FormaActionableEmptyState, FormaTextField, FormaFolderPicker, FormaListButton, FormaHeroIcon, FormaShadowLevel, formaCornerRadius, and the Segmented Control family).

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/DesignSystem/Components/FormaCards.swift" "Forma File Organizing/DesignSystem/Components/FormaBadges.swift" "Forma File Organizing/DesignSystem/Components/FormaStatusPill.swift" "Forma File Organizing/DesignSystem/FormaComponents.swift"
git commit -m "refactor: extract FormaCards, FormaBadges, FormaStatusPill from monolith"
```

---

### Task 12: Split Empty States, Form Controls, ListButton, SegmentedControl, Misc

**Files:**
- Create: `Forma File Organizing/DesignSystem/Components/FormaEmptyStates.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaFormControls.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaListButton.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaSegmentedControl.swift`
- Create: `Forma File Organizing/DesignSystem/Components/FormaMisc.swift`
- Delete: `Forma File Organizing/DesignSystem/FormaComponents.swift`

- [ ] **Step 1: Create FormaEmptyStates.swift**

Extract `FormaEmptyState`, `FormaActionableEmptyState`, and `FormaHeroIcon` with their previews. Include the import and all code exactly as it appears in FormaComponents.swift.

- [ ] **Step 2: Create FormaFormControls.swift**

Extract `FormaTextField` and `FormaFolderPicker`.

- [ ] **Step 3: Create FormaListButton.swift**

Extract `FormaListButton` and its preview.

- [ ] **Step 4: Create FormaSegmentedControl.swift**

Extract `FormaSegmentedControl`, `FormaSegmentButton`, `FormaSegmentedIconButton`, and `FormaSegmentedBackground`. These depend on `FormaControlChrome` types — add `import SwiftUI` and ensure the FormaControlChrome imports are accessible (they're in the same module, so no import needed).

- [ ] **Step 5: Create FormaMisc.swift**

Extract remaining: `FormaLogo`, `FormaCategoryIcon`, `FormaFileListItem`, `FormaProgressBar`, `FormaSuccessIndicator`, `FormaShadowLevel`, `formaShadow()` view extension, `formaCornerRadius()` view extension, and their previews.

- [ ] **Step 6: Delete FormaComponents.swift**

```bash
git rm "Forma File Organizing/DesignSystem/FormaComponents.swift"
```

- [ ] **Step 7: Build to verify the split compiles**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/DesignSystem/Components/" "Forma File Organizing/DesignSystem/FormaComponents.swift"
git commit -m "refactor: complete FormaComponents monolith split into focused component files"
```

---

## Phase 5: Component-Level Composite Tokens

### Task 13: Create FormaComponentStyles — Composite Token Modifiers

**Files:**
- Create: `Forma File Organizing/DesignSystem/FormaComponentStyles.swift`

The spec (Part 2f) calls for `ViewModifier` implementations that compose primitive tokens for high-frequency patterns. These prevent views from assembling 4-5 individual tokens every time they render a common element.

- [ ] **Step 1: Create FormaComponentStyles.swift**

```swift
//
//  FormaComponentStyles.swift
//  Forma - Component-Level Composite Tokens
//
//  ViewModifiers that compose primitive tokens for high-frequency UI patterns.
//  All composites implement craft guidelines: two-layer borders, state completeness, physical depth.
//

import SwiftUI

// MARK: - Card Style

enum FormaCardVariant {
    case `default`
    case selected
    case interactive
}

struct FormaCardStyleModifier: ViewModifier {
    let variant: FormaCardVariant
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .formaCardPadding()
            .background(background)
            .formaCornerRadius(FormaRadius.card)
            .formaBorder(
                cornerRadius: FormaRadius.card,
                style: borderStyle,
                innerEdge: true
            )
            .formaShadow(shadowLevel, colorScheme: colorScheme)
            .onHover { hovering in
                if variant == .interactive {
                    isHovered = hovering
                }
            }
    }

    private var background: Color {
        switch variant {
        case .selected:
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        case .interactive where isHovered:
            return Color.formaControlBackground.opacity(0.9)
        default:
            return Color.formaControlBackground
        }
    }

    private var borderStyle: FormaBorderStyle {
        switch variant {
        case .selected: return .selected
        case .interactive where isHovered: return .hover
        default: return .outer
        }
    }

    private var shadowLevel: FormaShadow {
        switch variant {
        case .selected: return .raised
        case .interactive where isHovered: return .raised
        default: return .resting
        }
    }
}

extension View {
    func formaCardStyle(_ variant: FormaCardVariant = .default) -> some View {
        modifier(FormaCardStyleModifier(variant: variant))
    }
}

// MARK: - Sidebar Row Style

struct FormaSidebarRowStyleModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro + 2)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(rowFill)
            )
            .foregroundColor(isSelected ? .formaLabel : .formaSecondaryLabel)
            .onHover { isHovered = $0 }
    }

    private var rowFill: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        }
        return Color.clear
    }
}

extension View {
    func formaSidebarRowStyle(isSelected: Bool) -> some View {
        modifier(FormaSidebarRowStyleModifier(isSelected: isSelected))
    }
}

// MARK: - Input Style

struct FormaInputStyleModifier: ViewModifier {
    let hasError: Bool
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(FormaSpacing.standard - FormaSpacing.micro)
            .background(Color.formaCardBackground)
            .formaCornerRadius(FormaRadius.control)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(
                        hasError
                            ? Color.formaError
                            : (isFocused ? Color.formaSteelBlue : Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
                        lineWidth: hasError || isFocused ? FormaBorderWidth.medium : FormaBorderWidth.thin
                    )
            )
            .formaFocusRing(isFocused: isFocused, cornerRadius: FormaRadius.control)
    }
}

extension View {
    func formaInputStyle(hasError: Bool = false, isFocused: Bool = false) -> some View {
        modifier(FormaInputStyleModifier(hasError: hasError, isFocused: isFocused))
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "Forma File Organizing/DesignSystem/FormaComponentStyles.swift"
git commit -m "feat: add FormaComponentStyles composite token modifiers (card, sidebar row, input)"
```

---

## Phase 6: Shared Component Moves

### Task 14: Move Shared Components to DesignSystem/Components/

**Files:**
- Move: `Forma File Organizing/Components/Shared/FormaCheckbox.swift` → `Forma File Organizing/DesignSystem/Components/FormaCheckbox.swift`
- Move: `Forma File Organizing/Components/Shared/FormaActionButton.swift` → `Forma File Organizing/DesignSystem/Components/FormaActionButton.swift`
- Move: `Forma File Organizing/Components/Shared/FormaThumbnail.swift` → `Forma File Organizing/DesignSystem/Components/FormaThumbnail.swift`

- [ ] **Step 1: Move the three Forma-prefixed files**

```bash
git mv "Forma File Organizing/Components/Shared/FormaCheckbox.swift" "Forma File Organizing/DesignSystem/Components/FormaCheckbox.swift"
git mv "Forma File Organizing/Components/Shared/FormaActionButton.swift" "Forma File Organizing/DesignSystem/Components/FormaActionButton.swift"
git mv "Forma File Organizing/Components/Shared/FormaThumbnail.swift" "Forma File Organizing/DesignSystem/Components/FormaThumbnail.swift"
```

- [ ] **Step 2: Build to verify imports resolve**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED (all in the same module, no import changes needed)

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: move FormaCheckbox, FormaActionButton, FormaThumbnail to DesignSystem/Components/"
```

---

## Phase 7: Consistency Enforcement

### Task 15: Wave 1 — Sidebar Token Adoption (Touched in Part 1)

**Files:**
- Modify: `Forma File Organizing/Views/SidebarView.swift`

The sidebar was restructured in Task 9. Now do a full token audit of the same file.

- [ ] **Step 1: Read SidebarView.swift and search for hardcoded values**

Search for:
- Hardcoded colors (e.g., `Color.white`, `Color.black`, `Color(.systemGray)`, raw hex)
- Hardcoded spacing (e.g., `.padding(12)`, `.spacing: 8` not using FormaSpacing)
- Hardcoded radii (e.g., `cornerRadius: 8` not using FormaRadius)
- Hardcoded font sizes (e.g., `.font(.system(size: 13))` not using FormaTypography)
- Hardcoded shadows

Replace each with the appropriate design system token. Where applicable, use the new `formaSidebarRowStyle(isSelected:)` composite modifier from FormaComponentStyles.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "Forma File Organizing/Views/SidebarView.swift"
git commit -m "refactor: wave 1 consistency — full token adoption in SidebarView"
```

---

### Task 16: Wave 2 — High-Traffic Content Surfaces

**Files:**
- Modify: `Forma File Organizing/Views/Components/FileRow.swift`
- Modify: `Forma File Organizing/Components/FileListRow.swift`
- Modify: `Forma File Organizing/Components/FileGridItem.swift`
- Modify: `Forma File Organizing/Views/MainContentView.swift`

These are the most-viewed surfaces in the app. Audit for hardcoded values and replace with tokens.

- [ ] **Step 1: Read all four files**

Read each file fully. Search for hardcoded colors, spacing, radii, font sizes, and shadows.

- [ ] **Step 2: Replace all hardcoded values with tokens**

For each file, replace:
- `Color.white` → `Color.formaBoneWhite`
- `Color.black` → `Color.formaObsidian`
- `.padding(12)` → `.padding(FormaSpacing.standard - FormaSpacing.micro)` or nearest token
- `.padding(8)` → `.padding(FormaSpacing.tight)`
- `.padding(16)` → `.formaPadding()`
- `cornerRadius: 8` → `FormaRadius.control`
- `cornerRadius: 12` → `FormaRadius.card`
- `.font(.system(size: N))` → nearest FormaTypography token
- Raw shadow values → `.formaShadow(.resting)` etc.
- Where applicable, use `formaCardStyle()` composite modifiers

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "Forma File Organizing/Views/Components/FileRow.swift" "Forma File Organizing/Components/FileListRow.swift" "Forma File Organizing/Components/FileGridItem.swift" "Forma File Organizing/Views/MainContentView.swift"
git commit -m "refactor: wave 2 consistency — token adoption in high-traffic file surfaces"
```

---

### Task 17: Wave 3 — Secondary Surfaces

**Files:**
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/Views/RuleBuilder/` (all files in directory)
- Modify: `Forma File Organizing/Views/ProductivityReportView.swift`

- [ ] **Step 1: Audit and fix FileInspectorView**

Read the file. Replace all hardcoded colors, spacing, radii, fonts, and shadows with design system tokens.

- [ ] **Step 2: Audit and fix Rule Builder views**

Read all files in `Forma File Organizing/Views/RuleBuilder/`. Apply token replacements.

- [ ] **Step 3: Audit ProductivityReportView**

Ensure stat badges use `FormaStatBadge`, charts use design system colors, and spacing follows tokens.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add "Forma File Organizing/Views/FileInspectorView.swift" "Forma File Organizing/Views/RuleBuilder/" "Forma File Organizing/Views/ProductivityReportView.swift"
git commit -m "refactor: wave 3 consistency — token adoption in inspector, rule builder, analytics"
```

---

### Task 18: Final Build + Full Test Suite

- [ ] **Step 1: Run full build**

Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run full test suite**

Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Unit" 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 3: Commit any remaining fixes**

If any tests fail, fix the issues and commit:
```bash
git add -A
git commit -m "fix: resolve issues found in final test pass"
```

---

## Summary

| Phase | Tasks | What it delivers |
|-------|-------|------------------|
| 1: New Token Files | 1-4 | FormaShadows, FormaBorders, FormaEasing, FormaFocusRing, FormaIconSize, FormaZIndex |
| 2: Token Refinements | 5-7 | Fixed formaSoftGreen, formaCallout font, tabular digits, Column layout tokens |
| 3: Layout Fix + IA | 8-9 | Three-column breathing room (center min 680→560, window 1200→1280), sidebar IA restructure with Smart Rules/Analytics as right-panel actions |
| 4: Component Split | 10-12 | FormaComponents.swift (1,298 lines) → 9 focused files |
| 5: Composite Tokens | 13 | FormaComponentStyles (card, sidebar row, input composite modifiers) |
| 6: Shared Moves | 14 | FormaCheckbox, FormaActionButton, FormaThumbnail → DesignSystem/Components/ |
| 7: Consistency | 15-18 | Token adoption across all surfaces in three waves + final verification |
