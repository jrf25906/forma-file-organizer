# Right Panel: Contextual Copilot Architecture

**Last Updated:** December 19, 2025

## Overview

The right panel is a **contextual workspace** that adapts to user actions, functioning as an intelligent copilot rather than a static dashboard. It has flexible width (320-420px, ideal 360px) and currently implements Default mode with a pinned header architecture. The panel is toggleable via Cmd+Option+0 and automatically hides on narrow windows (<1200px).

## Design Philosophy

### Adaptive Utility
Instead of showing the same information at all times, the panel displays what's **most relevant right now**:
- **File selected?** Show inspector with preview and actions
- **Nothing selected?** Show quick actions and insights  
- **Creating a rule?** Show inline rule builder
- **Just organized files?** Celebrate with undo option

### Key Principles
1. **Context over chrome** - Minimize passive information, maximize actionable content
2. **Anticipate needs** - Surface the right tools at the right time
3. **Reduce modal hopping** - Keep workflows in the main view
4. **Celebrate progress** - Positive reinforcement for completed tasks

## Architecture

### Panel Modes

```swift
enum RightPanelMode: Equatable {
    case `default`                              // Quick actions & insights
    case inspector([FileItem])                  // File details & organization tools
    case ruleBuilder(Rule?, FileItem?)          // Inline rule creation/editing
    case celebration(String)                    // Success state with undo
    case completionCelebration(filesOrganized: Int)  // All files cleared celebration
    case analytics                              // Compact analytics panel
}
```

### Mode Transitions

```
User Action              → Panel Mode              → Duration
───────────────────────────────────────────────────────────────────
Select file(s)           → .inspector              → Until deselected
Deselect all             → .default                → Persistent
Click "Create Rule"      → .ruleBuilder            → Until closed
Organize some files      → .celebration            → 5s auto-dismiss
Clear ALL pending files  → .completionCelebration  → 10s auto-dismiss
Open Analytics           → .analytics              → Until closed
```

### Component Structure

```
RightPanelView (Container)
├── DefaultPanelView (Mode: default) ✅ IMPLEMENTED
│   ├── PINNED HEADER (always visible)
│   │   ├── Greeting (warm, conversational)
│   │   ├── Progress Bar (subtle, 4px gradient)
│   │   └── Primary Action ("Organize N Files" button)
│   ├── Separator (1px subtle line)
│   └── SCROLLABLE CONTENT
│       ├── Secondary Actions (Create Rule, Review Files)
│       ├── Top Insight (single highest priority)
│       ├── "See more" link (if multiple insights)
│       └── Metrics Row (category counts)
│
├── FileInspectorView (Mode: inspector) 📋 PLANNED
│   ├── Quick Look Preview
│   ├── Metadata Card
│   ├── Organization Section
│   ├── Action Buttons
│   └── Similar Files
│
├── RuleBuilderPanelView (Mode: ruleBuilder) 📋 PLANNED
│   ├── Rule Editor Form
│   ├── Live Preview
│   └── Rule Suggestions
│
├── CelebrationView (Mode: celebration) ✅ IMPLEMENTED
│   ├── Success Animation
│   ├── Undo Button
│   └── Next Action Suggestion
│
├── CompletionCelebrationView (Mode: completionCelebration) ✅ IMPLEMENTED
│   ├── Confetti Animation Layer
│   ├── Trophy Icon with Glow Rings
│   ├── Encouraging Message (randomized)
│   ├── Stats Badge (files organized)
│   └── Continue Button
│
└── CompactAnalyticsPanel (Mode: analytics) ✅ IMPLEMENTED
    ├── Storage Chart
    ├── Health Score
    └── Time Saved Metrics
```

## Mode Details

### 1. Default Mode ✅ IMPLEMENTED

**When:** No files selected, no special context

**Architecture:** Two-tier pinned header + scrollable content

#### PINNED HEADER (Always Visible)
- **Greeting**: Warm, conversational tone
  - Time-based: "Good morning/afternoon/evening!"
  - With files: "Let's organize N files together"
  - Without files: "Everything's organized — nice work!"
  - Shows file count in bold rounded font
  
- **Progress Bar**: Subtle 4px gradient indicator
  - Colors: Steel Blue → Sage gradient
  - Shows organization progress (organized / total)
  - Always visible for at-a-glance status
  
- **Urgent Warning** (if applicable):
  - **Apple Design Award Refinement (Nov 26, 2025)**:
    - 13pt bold text (increased from 12pt semibold)
    - Orange tinted background (`.formaWarmOrange.opacity(0.12)`)
    - 6px corner radius with 10px horizontal, 6px vertical padding
    - Clock icon at 12pt semibold
    - Meets WCAG AA contrast requirements
  - "N urgent (over 30 days old)"
  - More prominent than previous design
  
- **Primary Action**: "Organize N Files" button
  - **Apple Design Award Refinement (Nov 26, 2025)**:
    - Solid `.formaSage` fill (no gradient)
    - Subtle shadow: `radius: 4, y: 2, opacity: 0.15`
    - 12px corner radius (standardized)
    - Restraint = premium polish
  - Always pinned - never scrolls out of view
  - Only shows when ready files exist

#### SCROLLABLE CONTENT
- **Secondary Actions**:
  - "Create Rule" (outlined button, Steel Blue)
    - **Apple Design Award Refinement**: 1pt stroke at 0.5 opacity (was 1.5pt at 0.3)
    - Maintains visibility on Retina displays over `.regularMaterial`
  - "Review Files" (text link with arrow)
    - **Apple Design Award Refinement**: 15pt medium (increased from 14pt)
    - Matches button hierarchy weight
  - Stacked vertically with clear hierarchy
  
- **Top Insight** (via `InsightsService`):
  - Single highest-priority suggestion (not 3)
  - **Apple Design Award Refinement (Nov 26, 2025)**:
    - Card: 12px corner radius (standardized from 16px)
    - Icon background: 6px corner radius (standardized from 10px)
    - Internal button: 6px corner radius (standardized from 10px)
    - Unified 12px/6px hierarchy throughout
  - Larger card with 44px icon
  - Clear CTA button
  - "See N more suggestions" link if multiple exist
  
- **Section Headers**:
  - **Apple Design Award Refinement**: 13pt semibold, 0.5 tracking (was 11pt, 1.0 tracking)
  - Color: `.formaSecondaryLabel` (was `.formaTertiaryLabel`)
  - Matches Apple's in-panel section header pattern
  
- **Metrics Row** (lightweight):
  - **Apple Design Award Refinement (Nov 26, 2025)**:
    - Native 1px divider lines between items (no dot separators)
    - 12pt regular text (increased from 11pt medium)
    - Proper spacing: `FormaSpacing.standard` between items
    - Divider: 24px top padding, 16px bottom padding
    - Matches Music.app footer pattern
  - Top 3 categories with counts
  - Format: "71 Images | 35 Documents | 18 Videos"
  - Text-only, no bars
  - Separator line above (0.5 opacity, was 0.3)

#### REMOVED COMPONENTS
- ❌ Recent Activity (redundant with main timeline)
- ❌ Storage breakdown (moved to Analytics view)
- ❌ Multiple suggestion cards (now shows only top 1)

### 2. Inspector Mode

**When:** User selects one or more files

**Single File:**
- Large Quick Look preview (images, PDFs, text)
- Editable filename
- Metadata (size, dates, location, type)
- Suggested destination with explanation
- "Why this suggestion?" (shows matching rule)
- Destination picker
- Action buttons: Organize (primary), Skip, Delete
- "Create Rule from This" link
- Similar files section (3 thumbnails)

**Multiple Files:**
- Selection summary ("5 files, 12.3 MB")
- Preview grid (thumbnails)
- Bulk actions: Organize All, Set Destination, Skip All
- Common pattern detection ("All are screenshots")
- Suggest creating bulk rule

### 3. Rule Builder Mode

**When:** User clicks "Create Rule" or "Create Rule from This"

**Components:**
- Rule name field
- Condition builder (dropdown selectors)
- Destination picker with folder browser
- "Test this rule" button
- Live preview: "Would match 12 files"
- Thumbnail grid of matched files
- "Apply to existing files?" checkbox
- Suggested rules based on current files
- Pre-built rule templates

### 4. Celebration Mode ✅ IMPLEMENTED

**When:** Files successfully organized (but pending files remain)

**Features:**
- Checkmark animation
- Success message: "Organized 5 files to Documents/Work"
- **Prominent undo button** (10s timer)
- "What's next?" suggestion
- Auto-dismisses to default after 5 seconds
- Can be manually dismissed

### 5. Completion Celebration Mode ✅ IMPLEMENTED

**When:** User clears ALL pending files (inbox zero achieved)

**Purpose:** Positive reinforcement for completing organization tasks - a "big win" celebration that acknowledges the accomplishment of clearing the entire backlog.

**Features:**
- **Confetti Animation**: 30 colorful particles falling with randomized:
  - Colors: Warm Orange, Sage, Steel Blue, Muted Blue
  - Sizes: 6-12px
  - Trajectories and rotations
  - Staggered delays for organic feel
- **Trophy Icon**: Party popper with animated glow rings
  - Three concentric gradient rings that scale in
  - Spring animation with 0.6s response
- **Encouraging Messages** (randomized):
  - "Inbox zero, who?"
  - "Look at you go!"
  - "Productivity champion!"
  - "Clean slate achieved!"
  - "You're on fire!"
  - "Organized perfection!"
- **Stats Badge**: Shows count of files organized
- **Continue Button**: Returns to default panel
- **Auto-dismiss**: 10 seconds (2x standard celebration)
- **Accessibility**: Respects `reduceMotion` preference

**Trigger Conditions:**
```swift
// After organizing, check if all pending/ready files are cleared
let remainingPendingFiles = allFiles.filter { $0.status == .pending || $0.status == .ready }
if remainingPendingFiles.isEmpty && successCount > 0 {
    showCompletionCelebrationPanel(filesOrganized: successCount)
}
```

**Files:**
- `CompletionCelebrationView.swift` - Main view with confetti animation
- `PanelStateManager.swift` - Panel mode enum and state management
- `DashboardViewModel.swift` - Trigger detection logic

### 6. Analytics Mode ✅ IMPLEMENTED

**When:** User opens analytics panel

**Features:**
- Compact storage chart visualization
- Health score display
- Files organized count
- Time saved metrics

## Data Flow

### State Management

```swift
// In DashboardViewModel
@Published var rightPanelMode: RightPanelMode = .default
@Published var selectedFileIDs: Set<String> = []

private func updateRightPanelMode() {
    let files = selectedFiles
    if !files.isEmpty {
        rightPanelMode = .inspector(files)
    } else if case .inspector = rightPanelMode {
        rightPanelMode = .default
    }
}
```

### Selection → Inspector Flow

1. User clicks file in main content area
2. `DashboardViewModel.toggleSelection(for:)` called
3. `selectedFileIDs` updated
4. `updateSelectionMode()` triggers `updateRightPanelMode()`
5. `rightPanelMode` → `.inspector([file])`
6. `RightPanelView` observes change
7. SwiftUI transitions to `FileInspectorView` with animation

### InsightsService Integration

```swift
// DefaultPanelView
@State private var insights: [FileInsight] = []

private func loadInsights() {
    insights = insightsService.generateInsights(
        from: dashboardViewModel.allFiles,
        activities: dashboardViewModel.recentActivities,
        rules: []
    )
}

// Refresh on data changes
.onChange(of: dashboardViewModel.allFiles) { loadInsights() }
.onChange(of: dashboardViewModel.recentActivities) { loadInsights() }
```

## InsightsService

### Pattern Detection Logic

**Screenshot Accumulation:**
- Threshold: ≥5 files with "screenshot" in name
- Priority: 8
- Action: "Create Rule"
- Icon: camera.viewfinder

**Downloads Overload:**
- Threshold: ≥15 files in /Downloads/
- Priority: 7
- Action: "Review Now"
- Icon: arrow.down.circle

**Large Files:**
- Threshold: ≥3 files >100MB each
- Priority: 9 (high)
- Shows total size
- Action: "Review Files"
- Icon: externaldrive.fill

**Rule Opportunities:**
- Threshold: ≥3 files same extension moved to same destination this week
- Priority: 10 (highest - clear automation opportunity)
- Message: "You've moved 5 PDF files to Documents/Work - create a rule?"
- Action: "Create Rule"
- Icon: wand.and.stars

**Weekly Summary:**
- Shows organized file count this week
- Priority: 2 (informational)
- Icon: chart.line.uptrend.xyaxis

**Duplicate Detection:**
- Threshold: ≥3 pairs of files with same name
- Priority: 5
- Action: "Review"
- Icon: doc.on.doc

### Insight Struct

```swift
struct FileInsight: Identifiable, Equatable {
    let id: UUID
    let message: String              // Display text
    let actionLabel: String?         // Button text (optional)
    let action: (() -> Void)?        // Button action (optional)
    let priority: Int                // Sort order (higher = first)
    let iconName: String             // SF Symbol name
}
```

## Animations & Transitions

### Mode Switching

```swift
@Namespace private var panelTransition

var body: some View {
    Group {
        switch rightPanelMode {
        case .default:
            DefaultPanelView()
                .matchedGeometryEffect(id: "panel", in: panelTransition)
        case .inspector(let files):
            FileInspectorView(files: files)
                .matchedGeometryEffect(id: "panel", in: panelTransition)
        // ...
        }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: rightPanelMode)
}
```

**Timing:**
- Mode transitions: 0.4s spring animation
- Celebration auto-dismiss: 5s delay
- Smooth, fluid feel - never jarring

### Accessibility

- All animations respect `@Environment(\\.accessibilityReduceMotion)`
- Proper VoiceOver labels on all interactive elements
- Keyboard navigation support (Tab, Space, Return)
- High contrast mode support via semantic colors

## Apple Design Award Refinements (November 26, 2025)

### Design Review Results
The right sidebar underwent a comprehensive design review against Apple Design Award standards. The following refinements were implemented to achieve award-winning quality:

#### 1. Corner Radius Consistency (12px / 6px Hierarchy)
**Problem**: Visual noise from competing corner radii (8px, 10px, 12px, 16px)

**Solution**: Standardized 2:1 radius system
- **Primary surfaces**: 12px (cards, buttons)
- **Nested elements**: 6px (icon backgrounds, internal buttons)
- **Result**: Clear visual hierarchy without competing geometries

**Files Modified**: `DefaultPanelView.swift`
- TopInsightCard container: 16px → 12px (line 476)
- Icon background: 10px → 6px (line 435)
- Internal action button: 10px → 6px (line 468)
- Primary action button: Maintained at 12px
- Secondary action button: Maintained at 12px

#### 2. Button Polish (Solid Fills, Subtle Shadows)
**Problem**: Gradient fills and prominent shadows read as consumer-grade, not pro-tool

**Solution**: Restraint-focused refinements
- **Organize button**: Gradient removed → solid `.formaSage` fill
- **Shadow**: `radius: 8, y: 4, opacity: 0.3` → `radius: 4, y: 2, opacity: 0.15`
- **Result**: Premium polish through restraint

**Files Modified**: `DefaultPanelView.swift` (lines 170-174)

#### 3. Divider Opacity Strengthening
**Problem**: 0.3 opacity dividers imperceptible over `.regularMaterial`

**Solution**: Increased to 0.5 opacity minimum
- **Header separator**: 0.3 → 0.5 (line 34)
- **Metrics divider**: Maintained at 0.5
- **Result**: Structurally visible while maintaining subtlety

**Files Modified**: `DefaultPanelView.swift`

#### 4. Urgent Files Warning Accessibility
**Problem**: Orange text (#C97E66) failed WCAG AA contrast (~3.2:1)

**Solution**: Multi-pronged accessibility fix
- **Font**: 12pt semibold → 13pt bold
- **Background**: Added `.formaWarmOrange.opacity(0.12)` tinted container
- **Corner radius**: 6px (nested element standard)
- **Padding**: 10px horizontal, 6px vertical
- **Result**: Passes WCAG AA with improved legibility

**Files Modified**: `DefaultPanelView.swift` (lines 90-102)

#### 5. Secondary Button Stroke Enhancement
**Problem**: 1.5pt stroke at 0.3 opacity disappeared on Retina displays

**Solution**: Apple's outlined button standard
- **Stroke**: `1.5pt at 0.3 opacity` → `1pt at 0.5 opacity`
- **Result**: Maintains visibility over materials

**Files Modified**: `DefaultPanelView.swift` (line 202)

#### 6. Typography Hierarchy Refinement
**Problem**: Section headers too timid (11pt, tertiary color)

**Solution**: Apple's in-panel header pattern
- **Font**: 11pt → 13pt semibold
- **Tracking**: 1.0 → 0.5
- **Color**: `.formaTertiaryLabel` → `.formaSecondaryLabel`
- **Result**: Proper hierarchy weight

**Files Modified**: `DefaultPanelView.swift` (lines 232-235)

#### 7. Review Files Link Weight
**Problem**: 14pt text felt lightweight for actionable element

**Solution**: Increased to 15pt to match button hierarchy

**Files Modified**: `DefaultPanelView.swift` (line 215)

#### 8. Metrics Row Native Redesign
**Problem**: Web-pattern dot separators, 11pt text too small

**Solution**: Native macOS pattern (Music.app footer)
- **Separators**: Dot characters ("·") → 1px native dividers
- **Font**: 11pt medium → 12pt regular
- **Spacing**: Consistent `FormaSpacing.standard` between items
- **Divider padding**: 24px top, 16px bottom (was asymmetric)
- **Result**: Matches Apple's native patterns

**Files Modified**: `DefaultPanelView.swift` (lines 274-298)

### Quality Bar Achievement
These refinements elevate the sidebar from "good indie app" to "could ship with macOS" quality:
- ✅ **Clarity**: Unified corner radii, proper contrast, clear hierarchy
- ✅ **Simplicity**: Removed decorative gradients, reduced visual noise
- ✅ **Consistency**: 12px/6px radius system throughout
- ✅ **Accessibility**: WCAG AA compliant with proper backgrounds
- ✅ **Aesthetic Integrity**: Restraint-focused polish

### Documentation Updates
- `UI-GUIDELINES.md`: Added corner radius hierarchy, shadow refinements, new best practices
- `RIGHT_PANEL.md`: Documented all refinements with rationale and file references

---

## Implementation Status

### ✅ Phase 1 Complete (November 26, 2025)
- [x] RightPanelMode enum with Equatable conformance
- [x] Mode state in DashboardViewModel
- [x] Automatic inspector mode on selection
- [x] InsightsService with full pattern detection
- [x] **DefaultPanelView fully redesigned and implemented**
- [x] **Pinned header architecture (greeting + progress + primary action)**
- [x] **Scrollable content section (secondary actions + top insight + metrics)**
- [x] **Panel toggle via Cmd+Option+0 keyboard shortcut**
- [x] **Responsive behavior (auto-hide when window < 1200px)**
- [x] **Flexible width constraints (320-420px, ideal 360px)**
- [x] **Toolbar toggle button with sidebar.right icon**
- [x] **Smooth slide-out animations**
- [x] Comprehensive unit tests for InsightsService
- [x] **Apple Design Award refinements (corner radii, shadows, typography)**

### ✅ Phase 2 Complete (November 26, 2025)
- [x] **FileInspectorView component (single + multi-file modes)**
- [x] **Apple Design Award refinements applied**
  - [x] Unified 12px/6px corner radius system
  - [x] Section headers: 13pt semibold, 0.5 tracking
  - [x] Card borders: 0.5 opacity (subtle definition)
  - [x] Quick Look button: Proper visual affordance
  - [x] "Create Rule" actions: Outlined button treatment
  - [x] Inspector title: 17pt medium (proper hierarchy)
- [x] Quick Look preview integration
- [x] Metadata display with dynamic labels
- [x] Organization suggestions with rule explanations
- [x] Similar files detection and selection
- [x] Multi-file bulk actions
- [x] Pattern detection (screenshots, same extension, etc.)

### ✅ Phase 3 Complete (December 2025)
- [x] **Celebration mode view** - Standard celebration for batch organize
- [x] **Completion celebration view** - "Inbox zero" celebration with confetti
- [x] **RightPanelView container** with mode switching animations
- [x] **Analytics panel** - Compact analytics in right panel

### 📋 Phase 4 Planned
- [ ] Inline rule builder mode
- [ ] Similar files discovery
- [ ] Pattern-based rule suggestions
- [ ] Multi-file inspector enhancements

### 🎨 Phase 5 Polish
- [ ] Refined animations
- [ ] Skeleton loaders
- [ ] Edge case handling
- [ ] Accessibility audit

## Testing Strategy

### Unit Tests
- `InsightsServiceTests.swift`: 13 test cases covering:
  - Screenshot pattern detection
  - Downloads accumulation
  - Large files alerts
  - Rule opportunity detection
  - Activity summaries
  - Duplicate detection
  - Priority sorting

### Integration Tests
- Panel mode transitions based on selection state
- Insights refresh on data changes
- Quick actions trigger correct ViewModel methods

### UI Tests
- Mode switching animations
- Accessibility compliance
- Keyboard navigation
- Reduced motion support

## Panel Controls

### Toggle Visibility
- **Keyboard Shortcut**: Cmd+Option+0 (⌘⌥0)
- **Toolbar Button**: Sidebar.right icon in top-right
- **State**: `isRightPanelVisible` in DashboardView
- **Animation**: Spring (response: 0.3s, damping: 0.8)
- **Transition**: `.move(edge: .trailing).combined(with: .opacity)`

### Responsive Behavior
- **Auto-hide threshold**: Window width < 1200px
- **Manual override**: User can always toggle via Cmd+Option+0
- **Layout reflow**: Main content automatically fills available space
- **Sidebar priority**: Left sidebar collapses first before hiding right panel

### Width Constraints
- **Minimum**: 320px
- **Ideal**: 360px
- **Maximum**: 420px
- **Behavior**: Flexes within range based on window size

## Performance Considerations

1. **Insights calculation**: Cached, only recalculates when source data changes
2. **Pinned header**: Separate from ScrollView for consistent rendering
3. **Independent scrolling**: Three scroll regions (sidebar, main content, right panel)
4. **Animation performance**: Hardware-accelerated spring curves
5. **Reduced motion**: All animations respect accessibility settings

## Future Enhancements

### Phase 5+
- Drag & drop files to inspector to review
- Inline file renaming
- Tag support in metadata
- Custom insight rules (user-defined thresholds)
- Export insights as reports
- ML-based destination predictions
- Integration with Shortcuts.app

## Related Documentation

- [DASHBOARD.md](./DASHBOARD.md) - Main dashboard architecture
- [RuleEngine-Architecture.md](./RuleEngine-Architecture.md) - Rule system design
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall system architecture
- [DEVELOPMENT.md](../Development/DEVELOPMENT.md) - Development workflows

---

**Created:** November 24, 2025
**Author:** System Architecture
**Status:** Implementation in progress (Phases 1-3 complete)
