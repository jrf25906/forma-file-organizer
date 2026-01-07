# Forma Design System

**Version:** 2.0
**Last Updated:** December 2025
**Status:** Production-Ready

A comprehensive design system for Forma, built for Apple Design Award quality. All tokens and components are derived from Brand Guidelines v2.0 and follow macOS Human Interface Guidelines.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Components](#components)
6. [Animations](#animations)
7. [Microanimations](#microanimations)
8. [Liquid Glass (macOS 26.0+)](#liquid-glass-macos-260)
9. [Accessibility](#accessibility)
10. [Usage Guidelines](#usage-guidelines)

---

## Design Principles

### Precise, Refined, Confident

Forma's design system embodies three core principles:

- **Precise**: 8pt grid system, consistent spacing tokens, exact color values
- **Refined**: Premium materials, continuous corner radii, subtle animations
- **Confident**: Clear hierarchy, purposeful interactions, professional polish

### Apple Design Award Standards

Every component is designed to meet Apple Design Award criteria:
- Native macOS patterns and behaviors
- Accessibility built-in (VoiceOver, Reduce Motion, High Contrast)
- Performance-optimized (60fps animations, efficient rendering)
- Premium materials (glass effects, depth, shadows)

---

## Color System

**File:** `DesignSystem/FormaColors.swift`

### Primary Brand Colors

| Color | HEX | RGB | Usage |
|-------|-----|-----|-------|
| **Obsidian** | `#1A1A1A` | 26, 26, 26 | Primary text, dark backgrounds, icon fills |
| **Bone White** | `#FAFAF8` | 250, 250, 248 | Light backgrounds, text on dark surfaces |

```swift
Color.formaObsidian
Color.formaBoneWhite
```

### Accent Colors

| Color | HEX | RGB | Usage |
|-------|-----|-----|-------|
| **Steel Blue** | `#5B7C99` | 91, 124, 153 | Primary actions, interactive elements, links, selections |
| **Sage** | `#7A9D7E` | 122, 157, 126 | Success states, confirmations, positive feedback |

```swift
Color.formaSteelBlue
Color.formaSage
```

### Category Colors

Derived from logo, used for file type categorization:

| Category | Color | HEX | RGB |
|----------|-------|-----|-----|
| **Documents** | Muted Blue | `#6B8CA8` | 107, 140, 168 |
| **Media** | Warm Orange | `#C97E66` | 201, 126, 102 |
| **Downloads** | Soft Green | `#8BA688` | 139, 166, 136 |

```swift
Color.formaMutedBlue    // Documents
Color.formaWarmOrange   // Media
Color.formaSoftGreen    // Downloads
```

### Semantic System Colors

Automatically adapt to light/dark mode:

```swift
// Backgrounds
Color.formaBackground           // Main window background
Color.formaControlBackground    // Buttons, cards
Color.formaTextBackground       // Text fields
Color.formaCardBackground       // Slightly off-white cards

// Text
Color.formaLabel                // Primary text
Color.formaSecondaryLabel       // Dimmed text
Color.formaTertiaryLabel        // Metadata, timestamps
Color.formaQuaternaryLabel      // Placeholder text

// UI Elements
Color.formaSeparator            // Borders, dividers
```

### State Colors

```swift
Color.formaSuccess   // #34C759 (light), #30D158 (dark)
Color.formaWarning   // #FF9500 (light), #FF9F0A (dark)
Color.formaError     // #FF3B30 (light), #FF453A (dark)
Color.formaInfo      // #007AFF (light), #0A84FF (dark)
```

### Opacity Tokens

**Eliminates 30+ hardcoded opacity values for visual consistency:**

```swift
Color.FormaOpacity.subtle      // 0.05 - Ghost buttons, very light overlays
Color.FormaOpacity.light       // 0.10 - Hover states, glass tints, light borders
Color.FormaOpacity.medium      // 0.20 - Card borders, dividers, disabled states
Color.FormaOpacity.strong      // 0.50 - Selected borders, active overlays
Color.FormaOpacity.prominent   // 0.80 - Modal backdrops, strong overlays
```

**Usage Example:**
```swift
.background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
)
```

### Liquid Glass Tints (macOS 26.0+)

Pre-configured glass tints for brand consistency:

```swift
Color.glassBlue        // Steel Blue 45% - Primary interactive elements
Color.glassGreen       // Sage 35% - Success states
Color.glassOrange      // Warm Orange 35% - Media highlights
Color.glassMutedBlue   // Muted Blue 35% - Documents
Color.glassSoftGreen   // Soft Green 35% - Downloads
```

### Gradient Backdrops

For subtle backgrounds that enhance glass visibility:

```swift
Color.gradientBackdropColors
// [Steel Blue, Sage, Warm Orange, Muted Blue]
```

### AppKit Compatibility

All colors available as NSColor for AppKit integration:

```swift
NSColor.formaObsidian
NSColor.formaSteelBlue
// ... etc
```

---

## Typography

**File:** `DesignSystem/FormaTypography.swift`

### Type Scale (SF Pro)

All sizes follow Brand Guidelines v2.0:

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| **Hero** | 32pt | Bold | Welcome screens, large displays |
| **H1** | 24pt | Semibold | Primary screen headers |
| **H2** | 20pt | Semibold | Major section divisions |
| **H3** | 17pt | Semibold | Subsection headers |
| **Body Large** | 15pt | Regular | Emphasized body content |
| **Body** | 13pt | Regular | Most UI text, descriptions, list items |
| **Compact** | 12pt | Regular | Compact UI elements |
| **Small** | 11pt | Regular | Metadata, timestamps, file counts |
| **Caption** | 10pt | Regular | Fine print, tertiary information |

### Font Tokens

```swift
// Headers
.formaHero       // 32pt Bold
.formaH1         // 24pt Semibold
.formaH2         // 20pt Semibold
.formaH3         // 17pt Semibold

// Body
.formaBodyLarge     // 15pt Regular
.formaBody          // 13pt Regular
.formaBodyMedium    // 13pt Medium
.formaBodySemibold  // 13pt Semibold
.formaBodyBold      // 13pt Bold

// Compact
.formaCompact           // 12pt Regular
.formaCompactMedium     // 12pt Medium
.formaCompactSemibold   // 12pt Semibold

// Small
.formaSmall             // 11pt Regular
.formaSmallMedium       // 11pt Medium
.formaSmallSemibold     // 11pt Semibold

// Caption
.formaCaption           // 10pt Regular
.formaCaptionSemibold   // 10pt Semibold
.formaCaptionBold       // 10pt Bold

// Monospace (Technical)
.formaMono          // 13pt SF Mono Regular
.formaMonoSmall     // 11pt SF Mono Regular
```

### Menu Bar & Buttons

```swift
.formaMenuTitle        // 13pt Semibold
.formaMenuItem         // 13pt Regular
.formaMenuMetadata     // 11pt Regular
.formaPrimaryButton    // 13pt Semibold
.formaSecondaryButton  // 13pt Regular
```

### Text Style Modifiers

Convenience modifiers that apply font + color:

```swift
.formaHeroStyle()       // Hero + formaLabel
.formaH1Style()         // H1 + formaLabel
.formaH2Style()         // H2 + formaLabel
.formaH3Style()         // H3 + formaLabel
.formaBodyStyle()       // Body + formaLabel
.formaSecondaryStyle()  // Body + formaSecondaryLabel
.formaMetadataStyle()   // Small + formaTertiaryLabel
.formaMonoStyle()       // Mono + formaSecondaryLabel
```

**Usage Example:**
```swift
Text("Dashboard")
    .formaH1Style()

Text("Organize 47 files")
    .formaBodyStyle()

Text("Last updated 5m ago")
    .formaMetadataStyle()
```

### Line Height & Spacing

```swift
// Line Height Multipliers
FormaTextStyle.LineHeight.tight        // 1.2x - Headers
FormaTextStyle.LineHeight.normal       // 1.5x - Body text
FormaTextStyle.LineHeight.comfortable  // 1.6x - Long-form text

// Paragraph Spacing
FormaTextStyle.ParagraphSpacing.betweenParagraphs  // 16pt (1em)
FormaTextStyle.ParagraphSpacing.betweenSections    // 32pt (2em)

// Line Length
FormaTextStyle.LineLength.optimal   // 50-75 characters
FormaTextStyle.LineLength.maximum   // 90 characters
```

---

## Spacing & Layout

**File:** `DesignSystem/FormaSpacing.swift`

### 8pt Grid System

All spacing values are multiples of 8 for visual rhythm:

| Token | Value | Usage |
|-------|-------|-------|
| **micro** | 4px | Icon to text, very tight relationships |
| **tight** | 8px | Related elements, compact layouts |
| **standard** | 16px | Default spacing (most common) |
| **generous** | 24px | Between sections, comfortable layouts |
| **large** | 32px | Major section breaks |
| **extraLarge** | 48px | Screen margins, major divisions |
| **huge** | 64px | Empty states, hero sections |

```swift
FormaSpacing.micro         // 4
FormaSpacing.tight         // 8
FormaSpacing.standard      // 16
FormaSpacing.generous      // 24
FormaSpacing.large         // 32
FormaSpacing.extraLarge    // 48
FormaSpacing.huge          // 64
```

### Component-Specific Padding

```swift
// Buttons
FormaSpacing.Button.vertical      // 8px
FormaSpacing.Button.horizontal    // 16px

// Cards
FormaSpacing.Card.all             // 16px

// Forms
FormaSpacing.Form.fieldSpacing    // 16px
FormaSpacing.Form.sectionSpacing  // 32px

// Screens
FormaSpacing.Screen.minMargin           // 24px
FormaSpacing.Screen.contentWidth        // 480-600px
FormaSpacing.Screen.multiColumnWidth    // 800-1000px

// Windows
FormaSpacing.Window.minWidth            // 600px
FormaSpacing.Window.minHeight           // 400px
FormaSpacing.Window.preferredWidth      // 800px
FormaSpacing.Window.preferredHeight     // 600px
```

### Spacing Modifiers

```swift
.formaPadding()            // 16px all sides (standard)
.formaPaddingTight()       // 8px all sides
.formaPaddingGenerous()    // 24px all sides
.formaButtonPadding()      // 8px vertical, 16px horizontal
.formaCardPadding()        // 16px all sides
.formaVerticalSpacing()    // 8px vertical (standard/2)
```

**Usage Example:**
```swift
VStack(spacing: FormaSpacing.standard) {
    Text("Title")
        .formaH2Style()

    Text("Description")
        .formaBodyStyle()
}
.formaPadding()
```

### Corner Radius Tokens

Uses continuous corner style for premium feel:

| Token | Value | Usage |
|-------|-------|-------|
| **none** | 0px | Sharp corners |
| **micro** | 4px | Small badges, tags, inline elements |
| **small** | 6px | Badges, small controls |
| **control** | 8px | Text fields, small buttons, chips |
| **card** | 12px | Cards, panels, sheets, modals |
| **large** | 16px | Large cards, prominent containers |
| **pill** | 999px | Fully rounded pills, floating bars |

```swift
FormaRadius.micro      // 4
FormaRadius.small      // 6
FormaRadius.control    // 8
FormaRadius.card       // 12
FormaRadius.large      // 16
FormaRadius.pill       // 999
```

### Radius Modifiers

All use `.continuous` style automatically:

```swift
.formaCardRadius()      // 12px continuous
.formaControlRadius()   // 8px continuous
.formaPillRadius()      // 999px continuous
.formaRadius(10)        // Custom radius with continuous style
.formaCornerRadius(12)  // Same as formaRadius
```

### Layout Helpers

```swift
// Create vertical spacing
FormaLayout.verticalSpacer(.standard)    // 16px height
FormaLayout.verticalSpacer(.generous)    // 24px height

// Create horizontal spacing
FormaLayout.horizontalSpacer(.tight)     // 8px width
FormaLayout.horizontalSpacer(.large)     // 32px width
```

---

## Components

**File:** `DesignSystem/FormaComponents.swift`

### Buttons

#### FormaPrimaryButton

Primary action button with Steel Blue background:

```swift
FormaPrimaryButton(
    title: "Organize Now",
    icon: "checkmark",      // Optional SF Symbol
    action: { /* action */ },
    isEnabled: true         // Optional, default true
)
```

**Features:**
- White text on Steel Blue background
- Automatic disabled state (40% opacity)
- 8px vertical × 16px horizontal padding
- 8px corner radius (continuous)
- Subtle shadow for depth

#### FormaSecondaryButton

Secondary action button with stroke border:

```swift
FormaSecondaryButton(
    title: "Cancel",
    icon: "xmark",          // Optional
    action: { /* action */ },
    isEnabled: true
)
```

**Features:**
- Obsidian text on clear background
- 1px stroke border (20% opacity)
- Same padding and radius as primary

### Cards

#### FormaCard

Standard card container with optional selection state:

```swift
FormaCard(isSelected: false) {
    VStack(alignment: .leading) {
        Text("Card Title")
            .formaH3Style()
        Text("Card content goes here")
            .formaBodyStyle()
    }
}
```

**Features:**
- 16px padding all sides
- 12px corner radius (continuous)
- 1px border (separator color, or Steel Blue when selected)
- Subtle shadow (enhanced when selected)

#### FormaListCard

Lighter-weight card for dense list views:

```swift
Text("List Item")
    .padding(16)
    .formaListCard(isSelected: isSelected, isHovered: isHovered)
```

**Features:**
- Maintains visual consistency with FormaCard
- Subtle gradient on selection
- Hover state support
- Optimized for list performance

### Progress & Indicators

#### FormaProgressBar

Linear progress indicator:

```swift
FormaProgressBar(progress: 0.65) // 0.0 to 1.0
```

**Features:**
- 2px height
- Steel Blue fill
- Animated transitions (0.2s easeInOut)

#### FormaSuccessIndicator

Success checkmark icon:

```swift
FormaSuccessIndicator()
```

**Features:**
- 48pt checkmark.circle.fill
- Sage green color
- Use for success states

### Badges

#### FormaFileBadge

File count badge:

```swift
FormaFileBadge(count: 42)
```

**Features:**
- Pill shape (capsule)
- Steel Blue background
- White text, 11pt semibold
- Horizontal padding: 8px, Vertical: 4px

### Logo

#### FormaLogo

Brand logo with configurable size:

```swift
FormaLogo(style: .mark, height: 32)
```

**Styles:**
- `.mark` - Geometric icon only
- `.lockup` - Icon + "Forma" wordmark (not implemented)

### Icons

#### FormaCategoryIcon

File category icon with color:

```swift
FormaCategoryIcon(category: .documents, size: 24)
```

**Features:**
- Automatic icon selection based on category
- Category-specific color
- SF Symbol rendering

### List Items

#### FormaFileListItem

Complete file list row:

```swift
FormaFileListItem(
    fileName: "invoice-2024.pdf",
    fileCategory: .documents,
    destination: "Documents/Finance/Invoices",
    isSelected: true,
    onSelect: { /* action */ }
)
```

**Features:**
- Category icon (32pt)
- File name (body style)
- Destination with arrow (metadata style)
- Selection indicator
- 16px padding
- Subtle background on selection

### States

#### FormaEmptyState

Empty state placeholder:

```swift
FormaEmptyState(
    title: "No Files to Organize",
    message: "Your Desktop is clean!",
    actionTitle: "Scan Now",
    action: { /* action */ }
)
```

**Features:**
- Large icon (64pt)
- Title (H2 style)
- Message (secondary style)
- Optional action button
- Centered layout, max width 400px

#### FormaLoadingSpinner

Loading state:

```swift
FormaLoadingSpinner(message: "Scanning files...")
```

**Features:**
- Circular progress indicator (1.2× scale)
- Message below (secondary style)
- 24px padding

#### FormaSuccessMessage

Success confirmation:

```swift
FormaSuccessMessage(
    title: "All Done!",
    message: "47 files organized",
    buttonTitle: "View Results",
    action: { /* action */ }
)
```

**Features:**
- Success indicator (48pt checkmark)
- Title (H1 style)
- Message (secondary style)
- Primary button (max width 200px)
- Centered layout

### Shadows

Standardized shadow system eliminates inconsistent shadows:

```swift
enum FormaShadowLevel {
    case card           // Subtle depth
    case cardSelected   // Enhanced elevation
    case floating       // Prominent elevation (action bars, popovers)
    case button         // Button depth
    case none           // No shadow
}

// Usage
.formaShadow(.card)
.formaShadow(.cardSelected)
.formaShadow(.floating)
```

**Shadow Values:**
- **card**: `black 8%, radius 4, y: 2`
- **cardSelected**: `Steel Blue 15%, radius 8, y: 3`
- **floating**: `black 15%, radius 16, y: 4`
- **button**: `black 12%, radius 4, y: 2`

---

## Animations

**File:** `DesignSystem/FormaAnimation.swift`

### Standard Timings

| Duration | Value | Usage |
|----------|-------|-------|
| **microDuration** | 150ms | Hover, button press, quick feedback |
| **standardDuration** | 250ms | Navigation, state changes, most animations |
| **largeDuration** | 400ms | Modal appear, sheet slide, major changes |
| **disclosureDuration** | 200ms | Expand/collapse actions |
| **premiumDuration** | 300ms | Hero elements, important state changes |

```swift
FormaAnimation.microDuration       // 0.15
FormaAnimation.standardDuration    // 0.25
FormaAnimation.largeDuration       // 0.40
FormaAnimation.disclosureDuration  // 0.20
FormaAnimation.premiumDuration     // 0.30
```

### Easing Curves

```swift
// Default easing (ease-in-out) - Most animations
FormaAnimation.defaultEasing       // .easeInOut(duration: 0.25)

// Button press (ease-out) - Instant feedback
FormaAnimation.buttonEasing        // .easeOut(duration: 0.15)

// Menu appear (ease-out) - Snappy feel
FormaAnimation.menuEasing          // .easeOut(duration: 0.15)

// Modal dismiss (ease-in) - Fade away
FormaAnimation.dismissEasing       // .easeIn(duration: 0.25)

// Spring animation (use sparingly)
FormaAnimation.springEasing        // .spring(response: 0.3, dampingFraction: 0.8)

// Premium spring - Bouncy, delightful
FormaAnimation.premiumSpring       // .spring(response: 0.4, dampingFraction: 0.75)

// Gentle spring - Subtle, refined
FormaAnimation.gentleSpring        // .spring(response: 0.35, dampingFraction: 0.85)

// Interactive spring - Responsive
FormaAnimation.responsiveSpring    // .interactiveSpring(response: 0.25, dampingFraction: 0.7)
```

### Specific Animations

Pre-configured animations for common use cases:

```swift
FormaAnimation.buttonPress         // Button scale to 0.95
FormaAnimation.progressFill        // Linear progress
FormaAnimation.successAppear       // Success state reveal
FormaAnimation.cardHover           // Card hover effect
FormaAnimation.selectionToggle     // Selection state
FormaAnimation.disclosure          // Expand/collapse
FormaAnimation.circularProgress    // Circular spinner
```

### View Modifiers with Accessibility

All animation modifiers respect Reduce Motion:

```swift
// Standard animation
.formaAnimation(value: isVisible, reduceMotion: reduceMotion)

// Button animation
.formaButtonAnimation(value: isPressed, reduceMotion: reduceMotion)

// Spring animation (use sparingly)
.formaSpringAnimation(value: isExpanded, reduceMotion: reduceMotion)
```

### Button Style

Animated button style with press effect:

```swift
Button("Press Me") { /* action */ }
    .buttonStyle(.formaAnimated)
```

**Features:**
- Scales to 0.95 on press
- 150ms ease-out animation
- Respects Reduce Motion

### Transitions

```swift
// Slide transition (navigation)
.transition(.formaSlide)

// Fade transition (simple)
.transition(.formaFade)

// Scale transition (modals)
.transition(.formaScale)
```

### Animated Components

#### AnimatedProgressBar

Progress bar with smooth animation:

```swift
@State private var progress: Double = 0.0

AnimatedProgressBar(progress: $progress)
    .frame(height: 2)
```

#### AnimatedSuccessView

Success checkmark with scale animation:

```swift
AnimatedSuccessView()
```

**Features:**
- Scales from 0.5 to 1.0
- Fades from 0 to 1
- 400ms ease-out animation
- Respects Reduce Motion

#### AccessibleLoadingSpinner

Loading spinner with accessibility:

```swift
AccessibleLoadingSpinner(message: "Scanning files...")
```

**Features:**
- Animated spinner (normal)
- Static hourglass (reduced motion)
- Automatic detection

### Hover Effects

#### Basic Hover

```swift
.formaHoverEffect(scale: 1.02, opacity: 0.9)
```

**Features:**
- Subtle scale increase
- Slight opacity change
- 150ms ease-out animation

#### Premium Card Hover

```swift
.premiumCardHover(scale: true, shadow: true, brightness: true)
```

**Features:**
- 1.5% scale increase
- Shadow enhancement (6px → 12px radius)
- 2% brightness boost
- Spring animation (0.25s response, 0.8 damping)

### Press Effect

```swift
.formaPressEffect()
```

**Features:**
- Scales to 0.96 on press
- -5% brightness on press
- Responds to DragGesture
- 150ms ease-out animation

### Special Effects

#### Bounce Effect

For celebrations and success states:

```swift
.formaBounce(trigger: isSuccessful)
```

**Features:**
- Scales to 1.1 briefly
- Premium spring animation
- Auto-resets after 150ms

#### Pulse Effect

For attention and loading:

```swift
.formaPulse(isActive: isLoading)
```

**Features:**
- Opacity pulses 1.0 ↔ 0.7
- 800ms ease-in-out
- Continuous loop while active

#### Shimmer Effect

For skeleton loading states:

```swift
.formaShimmer(isActive: isLoading)
```

**Features:**
- White gradient sweep
- 1.5s linear animation
- Continuous loop

#### Slide In Effect

For staggered reveals:

```swift
.formaSlideIn(from: .bottom, delay: 0.1)
```

**Features:**
- Slides from edge with fade
- 30px offset (horizontal), 20px (vertical)
- Gentle spring animation
- Configurable delay

### Staggered Animation

Helper for sequential reveals:

```swift
let delay = View.staggerDelay(for: index, baseDelay: 0, stagger: 0.05)

MyView()
    .formaSlideIn(from: .bottom, delay: delay)
```

---

## Microanimations

**File:** `DesignSystem/FormaMicroanimations.swift`

Focused micro-interactions for Create Rule and Settings screens.

### Animation Constants

```swift
FormaAnimation.microInteraction    // 0.15s - Most micro-interactions
FormaAnimation.quickTransition     // 0.22s - Quick state changes
FormaAnimation.shakeDuration       // 0.18s - Validation shake
FormaAnimation.interactiveSpring   // .interactiveSpring(0.22, 0.9)
FormaAnimation.quickEnter          // .easeOut(0.22)
FormaAnimation.quickExit           // .easeIn(0.15)
```

### Validation Shake

Horizontal shake for invalid input:

```swift
TextField("Email", text: $email)
    .validationShake(trigger: isInvalid)
```

**Features:**
- 3 oscillations over 180ms
- ±3px amplitude
- Linear timing for each oscillation
- Respects Reduce Motion

### Toggle Ripple

Ripple effect for toggle switches:

```swift
Toggle("Enable", isOn: $isEnabled)
    .toggleRipple(trigger: isEnabled)
```

**Features:**
- Circular ripple from center
- Scales 0.01 → 1.2
- Fades from 1 → 0
- 350ms ease-out

### Hover Lift

macOS hover with elevation:

```swift
MyButton()
    .hoverLift(scale: 1.01, shadowRadius: 6)
```

**Features:**
- Scale increase on hover
- Shadow enhancement
- Quick enter animation (220ms)
- Automatic onHover detection

### Expandable Row

Expand/collapse with height animation:

```swift
struct ExpandableRowModifier: ViewModifier {
    let isExpanded: Bool
    let contentHeight: CGFloat
}
```

**Features:**
- Animates height 0 ↔ contentHeight
- Fades opacity 0 ↔ 1
- Interactive spring
- Linear fallback for Reduce Motion

### Checkmark Draw

Animated checkmark path:

```swift
CheckmarkDrawView(color: .formaSage, size: 16)
```

**Features:**
- Two-segment path (start → middle → end)
- 250ms ease-out
- 2pt stroke, round caps
- Appears on view load

### Progress Ring

Circular progress indicator:

```swift
ProgressRingView(progress: 0.65, lineWidth: 2, color: .formaSteelBlue)
```

**Features:**
- Circular trim from 0 to progress
- Rotated -90° (starts at top)
- Round line caps
- Smooth animation

### Morphing Button

Button that morphs between states:

```swift
enum ButtonMorphState {
    case normal      // Icon + text
    case loading     // Progress ring
    case success     // Animated checkmark
    case error       // X mark
}

MorphingButtonContent(
    state: buttonState,
    title: "Save Rule",
    iconColor: .formaSteelBlue
)
```

**Features:**
- Seamless state transitions
- Loading ring animates 0 → 0.9
- Success checkmark springs in
- Quick enter/exit animations

### Floating Label TextField

Material Design-style floating label:

```swift
FloatingLabelTextField(
    label: "Email",
    placeholder: "you@example.com",
    text: $email
)
```

**Features:**
- Label floats up when focused or filled
- Font size transition (13pt → 11pt)
- Color change (secondary → Steel Blue)
- 220ms ease-out animation
- 20px vertical offset

### Condition Row Container

Staggered reveal for rule conditions:

```swift
ConditionRowContainer(isVisible: true) {
    MyConditionRow()
}
```

**Features:**
- 4px horizontal offset on appear
- Fades from 0 → 1
- Interactive spring animation
- Instant for Reduce Motion

### Swappable Icon

Icon swap with spring:

```swift
SwappableIconView(systemName: "checkmark", color: .formaSage)
```

**Features:**
- Scales 0.8 → 1.0 on appear
- Spring animation (0.2s, 0.7 damping)
- Force recreation via `.id(systemName)`

### Permission Status

Animated permission indicator:

```swift
enum Status {
    case pending   // Rotating dashed ring + pulsing center
    case granted   // Ring completes, then checkmark
    case error     // Exclamation triangle + shake
}

PermissionStatusView(status: .pending)
```

**Features:**
- **Pending**: Rotating dashed ring (2s linear loop), pulsing center dot (1s ease-in-out)
- **Granted**: Ring completion (300ms) → checkmark draw
- **Error**: Triangle with validation shake

---

## Liquid Glass (macOS 26.0+)

**File:** `DesignSystem/LiquidGlassComponents.swift`

Requires macOS 26.0+ with automatic fallback to materials.

### Material Tiers (Control Center Cues)

**File:** `DesignSystem/FormaMaterialTiers.swift`

To achieve a “Control Center-like” hierarchy without private APIs, Forma uses a small set of public, reusable tiers:

- `base`: foundational surfaces (panels and scaffolding)
- `raised`: elevated surfaces (grouped controls)
- `overlay`: floating surfaces (toolbar pills, floating action bar)

Each tier includes:
- Consistent “rim” treatment (inner highlight + outer shadow line)
- Automatic active/inactive window styling via `controlActiveState`
- Accessibility fallback for “Reduce Transparency”

**Usage**

```swift
// Background surface
.background {
    FormaMaterialSurface(tier: .overlay, cornerRadius: 30, tint: .formaSteelBlue)
}

// Or as a view modifier
.formaMaterialTier(.raised, cornerRadius: 20, tint: .formaSteelBlue)
```

### LiquidGlassBubble

Morphing glass bubble for selections and highlights:

```swift
LiquidGlassBubble(
    tintColor: .formaSteelBlue.opacity(0.35),
    cornerRadius: 12
)
```

**Features:**
- Uses `.glassEffect(.regular.tint())` on macOS 26.0+
- Fallback: `.ultraThinMaterial` with stroke overlay
- Continuous corner radius

### MorphingGlassContainer

Container for coordinated glass transitions:

```swift
@available(macOS 26.0, *)
MorphingGlassContainer(spacing: 0) {
    // Multiple glass elements
}
```

**Features:**
- Wraps `GlassEffectContainer`
- Enables smooth morphing between elements
- Configurable spacing

### GlassPillButton

Pill-shaped button for toolbars:

```swift
@Namespace var glassNamespace

GlassPillButton(
    icon: "checkmark",
    label: "All",
    isActive: true,
    namespace: glassNamespace,
    glassID: "tab-all",
    action: { /* action */ }
)
```

**Features:**
- Capsule shape
- Active: Steel Blue glass background, white text, medium weight
- Inactive: Clear background, secondary text, regular weight
- Fallback: Solid Steel Blue fill
- 6px icon-to-text spacing
- 12px horizontal × 6px vertical padding

### GlassCapsuleIndicator

Morphing capsule for tab navigation:

```swift
GlassCapsuleIndicator(tintColor: .formaSteelBlue.opacity(0.35))
```

**Features:**
- Capsule shape
- Glass effect with custom tint
- Fallback: Material with stroke overlay

### View Modifiers

#### formaGlassEffect

Apply glass with automatic fallback:

```swift
.formaGlassEffect(tint: .formaSteelBlue.opacity(0.35))
```

**macOS 26.0+:**
- Uses `.glassEffect(.regular.tint())`

**Older macOS:**
- Uses `.ultraThinMaterial`
- Adds 1px white stroke (20% opacity)
- 12px corner radius

#### formaMorphingGlass

Glass with ID for smooth transitions:

```swift
@available(macOS 26.0, *)
@Namespace var namespace

.formaMorphingGlass(
    id: "my-glass-element",
    in: namespace,
    tint: .formaSteelBlue.opacity(0.35)
)
```

### Accessibility Helper

Check if glass effects are available:

```swift
if shouldUseLiquidGlass {
    // Use glass components
} else {
    // Use fallback materials
}
```

---

## Accessibility

### Reduce Motion Support

**Every animated component checks `@Environment(\.accessibilityReduceMotion)`:**

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

if reduceMotion {
    // Instant state change
} else {
    withAnimation(FormaAnimation.defaultEasing) {
        // Animated transition
    }
}
```

**Animation Fallbacks:**
- Animations: `nil` or `.linear(duration: 0.12)`
- Transitions: Instant
- Springs: Linear
- Loops: Static states

### VoiceOver

- All interactive elements have accessibility labels
- Semantic roles (button, image, etc.)
- State announcements (selected, expanded, etc.)

### High Contrast

- Semantic colors automatically adapt
- Sufficient contrast ratios (WCAG AA)
- Border thickness increases in high contrast

### Keyboard Navigation

- Full keyboard support via SwiftUI
- Focus rings automatically visible
- Logical tab order

### Dynamic Type

- All text uses semantic font styles
- Scales with system text size
- Layouts adapt to larger text

---

## Usage Guidelines

### Color Usage

✅ **Do:**
- Use semantic colors (formaLabel, formaControlBackground) for automatic dark mode
- Apply opacity tokens for consistency
- Use category colors for file type categorization
- Apply state colors for feedback (success, error, warning)

❌ **Don't:**
- Hardcode RGB values
- Use arbitrary opacity values
- Mix brand colors without purpose
- Override system colors for text/backgrounds

### Typography

✅ **Do:**
- Use font tokens (.formaBody, .formaH1, etc.)
- Apply style modifiers (.formaBodyStyle())
- Maintain type scale hierarchy
- Use monospace for technical content

❌ **Don't:**
- Create custom font sizes
- Use hardcoded font weights
- Ignore line height recommendations
- Mix multiple type scales

### Spacing

✅ **Do:**
- Stick to 8pt grid (micro, tight, standard, generous, etc.)
- Use spacing modifiers (.formaPadding())
- Apply component-specific padding
- Follow screen margin guidelines

❌ **Don't:**
- Use arbitrary spacing values
- Break the 8pt grid
- Hardcode padding/margins
- Ignore responsive spacing

### Animations

✅ **Do:**
- Use standard timing constants
- Apply easing curves appropriately
- Check Reduce Motion
- Test performance (60fps)
- Use spring animations sparingly

❌ **Don't:**
- Create custom durations
- Ignore accessibility
- Overuse animations
- Chain too many animations
- Use jarring easing curves

### Components

✅ **Do:**
- Use pre-built components when available
- Maintain consistent hover/press states
- Apply proper shadows
- Use continuous corner radii

❌ **Don't:**
- Recreate existing components
- Ignore interaction states
- Hardcode shadows or corners
- Break component contracts

---

## Related Documentation

- [Component Architecture](../Architecture/ComponentArchitecture.md) - Reusable UI component catalog
- [UI Guidelines](UI-GUIDELINES.md) - UI implementation patterns and conventions
- [Dashboard Architecture](../Architecture/DASHBOARD.md) - Main interface design
- [Right Panel Architecture](../Architecture/RIGHT_PANEL.md) - Contextual copilot panel design
- [Onboarding Flow](Forma-Onboarding-Flow.md) - Onboarding screens and transitions

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.0** | December 2025 | Comprehensive design system documentation |
| **1.0** | November 2025 | Initial Brand Guidelines v2.0 implementation |

---

**Document Version:** 2.0
**Generated:** December 2025
**Maintained by:** Forma Design Team

## Glass Slab Pattern

**Added in v1.5.1**

Inspired by native macOS widgets, the "Glass Slab" pattern creates a distinct, volumetric object that sits above the background rather than blending into it.

### Characteristics

- **Material**: `.popover` (Thicker, lighter than `.sidebar`)
- **Refraction**: White `LinearGradient` overlay (Top 12% → Bottom 4%) simulating light diffusion.
- **Border**: `LinearGradient` stroke (White 50% → 10%) highlights the top edge where light hits.

### Usage

Use for permanent sidebars or floating panels that need to feel like physical objects.

```swift
// Implementation Reference
ZStack {
    VisualEffectView(material: .popover, blendingMode: .withinWindow)
    
    // Refraction
    LinearGradient(
        colors: [.white.opacity(0.12), .white.opacity(0.04)],
        startPoint: .top, endPoint: .bottom
    ).blendMode(.overlay)
}
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
            LinearGradient(
                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                startPoint: .top, endPoint: .bottom
            ), lineWidth: 1
        )
)
```
