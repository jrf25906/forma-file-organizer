# Right Panel Redesign: Interactive Automation & Rich Suggestions

## Overview

Transform the right panel from a passive status display into an engaging productivity partner. The key changes elevate **Suggestions** as the primary focus while making **Automation** feel alive and controllable.

---

## Part 1: Automation Card → Interactive Status Bar

**Current State:** A full card with small 28x28 pause button, feels like a status monitor.

**Target State:** A slim, interactive status bar that feels like a productivity toggle.

### 1.1 Visual Pulse Animation (Timer Icon)

**File:** `Components/AutomationStatusWidget.swift`

Add a subtle breathing pulse to the clock icon when automation is active:

```swift
// New state for pulse animation
@State private var isPulsing: Bool = false

// Pulse effect on the status icon when scanning is active
.overlay {
    if engine.state.isRunning && !reduceMotion {
        Circle()
            .stroke(statusColor.opacity(0.4), lineWidth: 2)
            .scaleEffect(isPulsing ? 1.6 : 1.0)
            .opacity(isPulsing ? 0 : 0.6)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
    }
}
.onAppear { isPulsing = engine.state.isRunning }
.onChange(of: engine.state.isRunning) { isPulsing = $0 }
```

### 1.2 Full-Card Toggle Interaction

Make the entire card tappable to toggle automation (not just the small button):

```swift
// Wrap the card content in a Button or add .onTapGesture
.onTapGesture {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        if isPaused {
            engine.start()
        } else {
            engine.stop()
        }
    }
}
.contentShape(Rectangle()) // Ensure full area is tappable
```

### 1.3 "Scan Now" Button

Add a prominent action button that triggers an immediate scan:

```swift
// Add to AutomationEngine
func scanNow() async {
    // Bypass the scheduler and run immediately
    await performScan()
}

// In the widget, add a "Scan Now" button with satisfying feedback
Button {
    Task { await engine.scanNow() }
} label: {
    HStack(spacing: FormaSpacing.tight) {
        Image(systemName: "bolt.fill")
        Text("Scan Now")
    }
    .font(.formaSmallSemibold)
}
.buttonStyle(FormaPrimaryButtonStyle())
.disabled(engine.state.isRunning)
```

### 1.4 Slim Status Bar Layout

Restructure to a compact horizontal bar:

```
┌────────────────────────────────────────────────────────┐
│  🔄 (pulse) │ Scanning... or "Next in 4m"  │ [Scan Now] │ ⏸/▶ │
└────────────────────────────────────────────────────────┘
```

- Height: ~48pt (down from ~100pt)
- Icon: 24x24 with pulse ring
- Status text: Single line
- Actions: "Scan Now" button (when idle) + toggle button (40x40)

---

## Part 2: Suggestions Card → Primary Focus

**Current State:** Buried below automation, generic icons, hard-to-dismiss.

**Target State:** Rich, scrollable feed with file previews and inline actions.

### 2.1 Vertical Hierarchy (Card Heights)

**File:** `Views/DefaultPanelView.swift`

Restructure the panel layout:

```
┌─────────────────────────────────────┐
│  AUTOMATION STATUS BAR (slim, 48pt) │  ← Status bar at top
├─────────────────────────────────────┤
│                                     │
│  SUGGESTIONS (scrollable feed)      │  ← Primary focus
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Batch: 4 project files        │ │  ← Rich suggestion card
│  │ [file stack preview]          │ │
│  │ [Organize Together] [Dismiss] │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Pattern: Screenshots → ...    │ │
│  │ [Create Rule] [Dismiss]       │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ ...more suggestions...        │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │     [See 24 More Suggestions] │ │  ← Prominent button
│  └───────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### 2.2 Batch File Stack Preview

**New Component:** `Components/FileStackPreview.swift`

Replace generic icons with overlapping file thumbnails:

```swift
struct FileStackPreview: View {
    let files: [FileItem]
    let maxVisible: Int = 4

    var body: some View {
        ZStack {
            ForEach(Array(files.prefix(maxVisible).enumerated()), id: \.offset) { index, file in
                FileTypeIcon(for: file.fileType)
                    .frame(width: 32, height: 32)
                    .background(file.categoryColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(x: CGFloat(index) * 8, y: CGFloat(index) * -2)
                    .zIndex(Double(maxVisible - index))
            }
        }
        .frame(width: 56, height: 40, alignment: .leading)
    }
}
```

Visual result:
```
  ┌──┐
 ┌┤  │   4 overlapping file icons showing actual types
┌┤│  │   (PDF, DOC, IMG, etc.) creating a "stack" effect
│││  │
└┴┴──┘
```

### 2.3 Inline Dismiss Actions

**Files:** `Views/RuleSuggestionView.swift`, `Views/DefaultPanelView.swift`

Add dismiss (X) buttons to every suggestion card:

```swift
// In QuickActionCard header
HStack {
    // ... existing icon and text

    Spacer()

    // Dismiss button
    Button {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            onDismiss()
        }
    } label: {
        Image(systemName: "xmark")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(Color.formaObsidian.opacity(0.05))
            .clipShape(Circle())
    }
    .buttonStyle(.plain)
}
```

Update action button row:
```
┌──────────────────────────────────────┐
│ [Organize Together]     [Ignore ✕]   │
└──────────────────────────────────────┘
```

### 2.4 Prominent "See More" Button

Replace the subtle link with a full-width button:

```swift
// Replace "See N more" link with:
if remainingSuggestionCount > 0 {
    Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showAllSuggestions.toggle()
        }
    } label: {
        HStack {
            Image(systemName: showAllSuggestions ? "chevron.up" : "chevron.down")
            Text(showAllSuggestions ? "Show Less" : "See \(remainingSuggestionCount) More Suggestions")
            Spacer()
            Text("\(remainingSuggestionCount)")
                .font(.formaCaption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.formaSteelBlue.opacity(0.15))
                .clipShape(Capsule())
        }
        .font(.formaSmallSemibold)
        .foregroundStyle(Color.formaSteelBlue)
        .padding(FormaSpacing.standard)
        .background(Color.formaSteelBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
    }
    .buttonStyle(.plain)
}
```

### 2.5 Independent Scrollable Feed

Make the suggestions section a separately scrollable area:

```swift
// In DefaultPanelView, wrap suggestions in their own ScrollView
ScrollView {
    LazyVStack(spacing: FormaSpacing.standard) {
        ForEach(visibleSuggestions) { suggestion in
            SuggestionCard(suggestion: suggestion, onDismiss: { ... })
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }

        seeMoreButton
    }
    .padding(.horizontal, FormaLayout.Gutters.rightPanel)
}
.frame(maxHeight: .infinity) // Take remaining space
```

---

## Part 3: Unified Suggestion Model

### 3.1 New Suggestion Type Enum

**New File:** `Models/Suggestion.swift`

Create a unified model for all suggestion types:

```swift
enum SuggestionType: Identifiable {
    case batch(files: [FileItem], reason: String)
    case rule(pattern: LearnedPattern)
    case insight(FileInsight)
    case duplicate(group: DuplicateGroup)

    var id: String { ... }
    var priority: Int { ... }  // For sorting
    var icon: String { ... }
    var title: String { ... }
    var subtitle: String { ... }
}
```

### 3.2 Unified SuggestionCard

**New Component:** `Components/SuggestionCard.swift`

A single card component that renders differently based on type:

```swift
struct SuggestionCard: View {
    let suggestion: SuggestionType
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header with dismiss button
            headerView

            // Content varies by type
            switch suggestion {
                case .batch(let files, _):
                    FileStackPreview(files: files)
                case .rule(let pattern):
                    patternPreview(pattern)
                case .insight(let insight):
                    insightContent(insight)
                case .duplicate(let group):
                    duplicatePreview(group)
            }

            // Action buttons
            actionButtons
        }
        .padding(FormaSpacing.standard)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
    }
}
```

---

## Implementation Order

### Phase 1: Automation Status Bar (Files: 2)
1. Add pulse animation to AutomationStatusWidget
2. Make card tappable for toggle
3. Add "Scan Now" button + AutomationEngine method
4. Slim down layout to status bar style

### Phase 2: Suggestion Cards (Files: 4)
1. Create FileStackPreview component
2. Add dismiss buttons to existing cards
3. Update "See More" to prominent button
4. Make suggestions section independently scrollable

### Phase 3: Unified System (Files: 2)
1. Create Suggestion enum and model
2. Create unified SuggestionCard component
3. Refactor DefaultPanelView to use new system

---

## Files to Modify

| File | Changes |
|------|---------|
| `Components/AutomationStatusWidget.swift` | Pulse animation, full-card tap, slim layout, scan now button |
| `Services/AutomationEngine.swift` | Add `scanNow()` method |
| `Views/DefaultPanelView.swift` | Reorder sections, add scrollable feed |
| `Views/RuleSuggestionView.swift` | Add dismiss button to PatternCard |
| `Components/FileStackPreview.swift` | **NEW** - Overlapping file icons |
| `Components/SuggestionCard.swift` | **NEW** - Unified suggestion card |
| `Models/Suggestion.swift` | **NEW** - Unified suggestion model |

---

## Design Tokens to Use

```swift
// Spacing
FormaSpacing.tight = 8      // Within cards
FormaSpacing.standard = 16  // Between elements
FormaSpacing.generous = 24  // Section padding

// Radius
FormaRadius.small = 6       // File icons
FormaRadius.card = 12       // Cards

// Animation
.spring(response: 0.3, dampingFraction: 0.8)  // Card interactions
.easeInOut(duration: 1.5)                      // Pulse animation (repeating)

// Colors
Color.formaSage           // Active/success state
Color.formaSteelBlue      // Scanning/interactive
Color.formaWarmOrange     // Paused/warning
```

---

## Decision Points for User Input

1. **Pulse Style**: Subtle breathing ring vs. more pronounced glow effect?
2. **"Scan Now" Placement**: Inside the status bar or as a separate floating action?
3. **Suggestion Feed Behavior**: Independent scroll vs. part of main panel scroll?
4. **Dismiss Persistence**: Remember dismissed suggestions across sessions or reset?
