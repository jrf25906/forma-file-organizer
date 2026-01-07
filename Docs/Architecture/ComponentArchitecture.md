# Component Architecture

**Version:** 1.0
**Last Updated:** December 2025
**Status:** Current Implementation

---

## Overview

Forma's component architecture follows SwiftUI best practices with a focus on:
- **Composition**: Small, reusable components that compose into larger features
- **Separation of Concerns**: Presentation separated from business logic
- **Progressive Disclosure**: Hover states reveal actions, reducing visual noise
- **Design System Integration**: All components use Forma design tokens
- **Accessibility**: Full keyboard navigation and VoiceOver support

### Component Patterns

**Container/Presentation Pattern**
- Container components manage state and callbacks
- Presentation components receive props and render UI
- Example: `FilterTabBar` (container) → `FilterTab` (presentation)

**Progressive Disclosure**
- Actions hidden until hover/focus
- Example: `FileGridItem` reveals quick actions on hover

**Subcomponent Organization**
- Complex components split into private subcomponents
- Marked with `// MARK: - SubcomponentName`
- Example: `FileGridItem` contains `GridThumbnail`, `GridDestinationBadge`, `HoverActionOverlay`, `GridActionButton`, `GridCheckbox`

---

## Component Inventory

### Total Count: 37 Components

#### By Category:
- **File Display:** 7 components
- **Filtering & Organization:** 5 components
- **Cards & Sections:** 5 components
- **UI Controls:** 6 components
- **Feedback & Status:** 5 components
- **Storage & Analytics:** 2 components
- **AI & Intelligence:** 3 components ✅ New
- **Animations:** 1 component
- **Utilities:** 3 components

---

# File Display Components

Components for displaying files in grid, list, and thumbnail views.

---

## FileGridItem

Premium grid tile with Apple-quality polish and progressive disclosure.

### Usage

```swift
FileGridItem(
    file: fileItem,
    isFocused: focusedFileID == fileItem.id,
    isSelected: selectedFiles.contains(fileItem.id),
    isSelectionMode: isSelectionMode,
    onToggleSelection: { toggleSelection(fileItem) },
    onOrganize: { organizeFile(fileItem) },
    onEdit: { editDestination(fileItem) },
    onSkip: { skipFile(fileItem) },
    onQuickLook: { quickLookFile(fileItem) }
)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `file` | `FileItem` | File to display |
| `isFocused` | `Bool` | Whether file has keyboard focus |
| `isSelected` | `Bool` | Whether file is selected |
| `isSelectionMode` | `Bool` | Whether bulk selection is active |

### Callbacks

| Callback | Description |
|----------|-------------|
| `onToggleSelection` | Toggle file selection state |
| `onOrganize` | Organize file to suggested destination |
| `onEdit` | Edit file's destination |
| `onSkip` | Skip this file |
| `onQuickLook` | Open Quick Look preview |

### States

**Default State:**
- White background (70% opacity)
- Subtle shadow
- Destination badge visible

**Hover State:**
- Brighter background (90% opacity)
- Increased shadow
- Quick action overlay appears
- Checkbox appears (if not already visible)
- Scale effect: 1.01x

**Selected State:**
- Steel blue gradient background
- Steel blue border
- Checkbox always visible
- Enhanced shadow

**Focused State:**
- Steel blue border (2px)
- Blue shadow
- Scale effect: 1.03x
- Highest z-index

### Subcomponents

#### GridThumbnail
- Category-based gradient background
- File type icon (36pt)
- Quick Look overlay on hover
- Shadow effects

#### GridDestinationBadge
- Capsule-shaped badge
- Shows destination folder name or "No Rule"
- Hidden when hovering (actions take priority)

#### HoverActionOverlay
- Frosted glass action bar
- Primary action: Organize (green)
- Secondary action: Skip
- Overflow menu with all actions

#### GridActionButton
- Circular buttons with icons
- Primary: colored background with shadow
- Secondary: material background
- Scale animation on hover (1.08x)

#### GridCheckbox
- Top-left corner positioning
- Circle with checkmark when selected
- Appears on: hover, selection mode, or when selected

### Design Tokens

- **Tile Width:** 160pt
- **Thumbnail Size:** 100pt
- **Corner Radius:** 16pt
- **Tile Height:** 200pt
- **Shadow Radius:** 4-12pt (state-dependent)

### Accessibility

- `.help()` modifiers for tooltips
- Keyboard focus support
- VoiceOver labels on all interactive elements
- Respects `.accessibilityReduceMotion`

---

## FileListRow

Compact list view with inline actions and metadata.

### Usage

```swift
FileListRow(
    file: fileItem,
    isFocused: focusedFileID == fileItem.id,
    isSelected: selectedFiles.contains(fileItem.id),
    isSelectionMode: isSelectionMode,
    onToggleSelection: { toggleSelection(fileItem) },
    onOrganize: { organizeFile(fileItem) },
    onEdit: { editDestination(fileItem) },
    onSkip: { skipFile(fileItem) },
    onQuickLook: { quickLookFile(fileItem) }
)
```

### Layout

```
[Checkbox] [Icon] [Name] [Size] [Modified Date] → [Destination] [Actions]
```

### Properties

Same as `FileGridItem` for consistency.

### States

**Default:**
- Transparent background
- Border: none

**Hover:**
- Light background
- Actions fade in from right
- Checkbox appears

**Selected:**
- Steel blue tint background
- Checkbox visible

**Focused:**
- Steel blue left border (3px)

### Subcomponents

#### ListFileIcon
- 32pt icon size
- Category color tint

#### ListActions
- Inline action buttons
- Fade in/out with hover
- Keyboard shortcuts shown in tooltips

---

## FileThumbnailView

High-quality thumbnail generation and caching.

### Usage

```swift
FileThumbnailView(
    file: fileItem,
    size: .medium
)
```

### Sizes

| Size | Dimensions | Use Case |
|------|-----------|----------|
| `.small` | 32x32 | List view icons |
| `.medium` | 64x64 | Grid tiles |
| `.large` | 128x128 | Inspector panel |
| `.xlarge` | 256x256 | Quick Look |

### Behavior

1. Checks cache for existing thumbnail
2. If not cached, generates on background thread
3. Shows placeholder while generating
4. Caches result for future use

### Supported File Types

- **Images:** PNG, JPG, HEIC, GIF (native preview)
- **PDFs:** First page rendered
- **Videos:** First frame extracted
- **Other:** File type icon with category color

---

## FileViews

Collection of file view utilities and helpers.

### Components

#### FileIconView
Category-based icon with color theming.

```swift
FileIconView(category: .documents, size: 32)
```

#### FileSizeLabel
Formatted file size (KB, MB, GB).

```swift
FileSizeLabel(bytes: file.sizeInBytes)
// Output: "2.4 MB"
```

#### FileModifiedDate
Relative timestamp or absolute date.

```swift
FileModifiedDate(date: file.modificationDate, style: .relative)
// Output: "2 hours ago" or "Jan 15, 2024"
```

---

## RecentFilesGrid

Grid layout for recent/active files with lazy loading.

### Usage

```swift
RecentFilesGrid(
    files: recentFiles,
    selectedFiles: $selectedFiles,
    focusedFile: $focusedFile,
    onOrganize: organizeFile,
    onEdit: editDestination,
    onSkip: skipFile
)
```

### Features

- Lazy grid with 3-5 columns (adaptive)
- Virtualized scrolling for performance
- Keyboard navigation with arrow keys
- Multi-selection with Shift/Cmd
- Sticky section headers

---

## HoverableThumbnail

Thumbnail with hover effects and Quick Look integration.

### Usage

```swift
HoverableThumbnail(
    file: fileItem,
    size: 100,
    onQuickLook: { showQuickLook(file) }
)
```

### Features

- Hover overlay with "Quick Look" label
- Material background on hover
- Smooth fade transition
- Keyboard activation (Space bar)

---

## ThumbnailPreviewPopup

Popover preview for file thumbnails.

### Usage

```swift
.thumbnailPreviewPopup(
    isPresented: $showingPreview,
    file: selectedFile
)
```

### Features

- Larger preview (256pt)
- File metadata overlay
- Click outside to dismiss
- Arrow key navigation to adjacent files

---

# Filtering & Organization Components

Components for filtering, searching, and organizing files.

---

## FilterTabBar

Category filter tabs with file counts.

### Usage

```swift
FilterTabBar(
    selectedCategory: $selectedCategory,
    categoryFileCounts: [
        .all: 42,
        .documents: 15,
        .images: 8
    ]
)
```

### Categories

- **All:** All file types
- **Documents:** PDFs, Word, Excel, text files
- **Images:** Photos, graphics, screenshots
- **Videos:** Movies, screen recordings
- **Audio:** Music, podcasts, voice memos
- **Archives:** ZIP, DMG, TAR files

### Features

- Badge shows file count per category
- Selected state: steel blue background, white text
- Unselected state: white background, steel blue border
- Smooth transition animation (0.2s ease-in-out)

---

## ActiveFiltersBar

Shows active filters with clear buttons.

### Usage

```swift
ActiveFiltersBar(
    activeFilters: activeFilters,
    onClear: clearFilter,
    onClearAll: clearAllFilters
)
```

### Filter Types

- **Category:** Documents, Images, etc.
- **Date Range:** "Last 7 days", "This month"
- **Size Range:** "< 1 MB", "1-10 MB", "> 10 MB"
- **Status:** Pending, Completed, Skipped
- **Rule:** Files matching specific rule

### Example

```
Active Filters: [Documents ×] [Last 7 days ×] [< 1 MB ×] [Clear All]
```

---

## SecondaryFilterTab

Additional filter options (date, size, status).

### Usage

```swift
SecondaryFilterTab(
    selectedDateRange: $dateRange,
    selectedSizeRange: $sizeRange,
    selectedStatus: $status
)
```

### Options

**Date Range:**
- Today
- Last 7 days
- Last 30 days
- This month
- Custom range

**Size Range:**
- < 100 KB
- 100 KB - 1 MB
- 1 MB - 10 MB
- 10 MB - 100 MB
- > 100 MB

**Status:**
- All
- Pending
- Completed
- Skipped

---

## FloatingActionBar

Bulk operation bar for selected files.

### Usage

```swift
FloatingActionBar(
    selectedCount: selectedFiles.count,
    hasDestinations: allHaveDestinations,
    onOrganizeAll: organizeSelected,
    onSkipAll: skipSelected,
    onClearSelection: clearSelection
)
```

### Layout

```
[Count Label] [Organize All] [Skip All] [More ▾] [Clear ×]
```

### Position

- Bottom center of screen
- 16pt from bottom edge
- Centered horizontally
- Frosted glass material
- Drop shadow for elevation

### Actions

- **Organize All:** Moves all selected files to destinations
- **Skip All:** Skips all selected files
- **More:** Additional actions (delete, export, etc.)
- **Clear:** Deselects all files

---

## ExpandableGlassActions

Expandable action menu with frosted glass effect.

### Usage

```swift
ExpandableGlassActions(
    isExpanded: $isExpanded,
    primaryAction: organizeAction,
    secondaryActions: [skipAction, editAction]
)
```

### States

**Collapsed:**
- Shows primary action button only
- Floating circle with icon

**Expanded:**
- Reveals all action buttons
- Horizontal layout with labels
- Smooth spring animation

---

# Cards & Sections Components

Reusable card and section layouts.

---

## ClusterCard

Card displaying detected project cluster.

### Usage

```swift
ClusterCard(
    cluster: projectCluster,
    onExpand: { expandCluster(cluster) },
    onDismiss: { dismissCluster(cluster) }
)
```

### Layout

```
[Icon] [Cluster Name]
       [Description]
       [Confidence Badge]
[5 files] [Expand →]
```

### Confidence Indicator

- **High (0.9-1.0):** Green badge, "Very likely"
- **Medium (0.7-0.9):** Blue badge, "Likely"
- **Low (< 0.7):** Gray badge, not shown to user

---

## RuleManagementCard

Card for creating/editing rules.

### Usage

```swift
RuleManagementCard(
    rule: rule,
    onEdit: { editRule(rule) },
    onToggle: { toggleRule(rule) },
    onDelete: { deleteRule(rule) }
)
```

### Layout

```
[📋 Rule Name]                    [Toggle Switch]
    Conditions: Extension is .pdf
    Destination: ~/Documents/PDFs
    Priority: 5

[Edit] [Delete]
```

---

## FormaSection

Standard section container with header and content.

### Usage

```swift
FormaSection(title: "Recent Files", icon: "clock") {
    // Content here
}
```

### Features

- Optional header icon
- Optional action button in header
- Collapsible content
- Rounded corners
- Subtle background

---

## CollapsibleSection

Section that can be expanded/collapsed.

### Usage

```swift
CollapsibleSection(
    title: "Advanced Options",
    isExpanded: $isExpanded
) {
    // Collapsible content
}
```

### Animation

- Smooth expand/collapse with spring animation
- Chevron rotates 90° when expanded
- Content fades in/out

---

## GroupHeader

Sticky header for grouped content.

### Usage

```swift
GroupHeader(
    title: "Today",
    count: 12,
    icon: "calendar"
)
```

### Features

- Sticky positioning in scroll views
- File count badge
- Optional icon
- Subtle divider line

---

# UI Controls Components

Interactive controls and inputs.

---

## Buttons

Collection of styled button components.

### Components

#### FormaPrimaryButton
```swift
FormaPrimaryButton(title: "Organize", icon: "checkmark") {
    organizeFiles()
}
```
- Steel blue background
- White text
- Rounded corners (8pt)
- Hover/press states

#### FormaSecondaryButton
```swift
FormaSecondaryButton(title: "Cancel") {
    cancel()
}
```
- Transparent background
- Steel blue border
- Steel blue text

#### FormaDestructiveButton
```swift
FormaDestructiveButton(title: "Delete", icon: "trash") {
    deleteFiles()
}
```
- Red background
- White text
- Warning confirmation

---

## SelectionCheckbox

Tri-state checkbox for selection.

### Usage

```swift
SelectionCheckbox(
    isSelected: isSelected,
    isIndeterminate: someSelected && !allSelected,
    onToggle: toggleSelection
)
```

### States

- **Unchecked:** Empty circle
- **Checked:** Blue circle with checkmark
- **Indeterminate:** Blue circle with dash

---

## ViewModeToggle

Toggle between grid and list views.

### Usage

```swift
ViewModeToggle(
    selectedMode: $viewMode
)
```

### Modes

- **Grid:** `square.grid.2x2`
- **List:** `list.bullet`

### Style

- Segmented control appearance
- Selected mode highlighted
- Icon-only (no labels)

---

## MorphingActionButton

Button that morphs between states with animation.

### Usage

```swift
MorphingActionButton(
    currentState: buttonState,
    onTap: performAction
)
```

### States

- **Idle:** "Organize" with arrow icon
- **Loading:** Spinner animation
- **Success:** Checkmark with bounce
- **Error:** X mark with shake

---

## CompactSearchField

Compact search field with instant results.

### Usage

```swift
CompactSearchField(
    searchText: $searchQuery,
    placeholder: "Search files..."
)
```

### Features

- Clear button when text present
- Keyboard shortcut: Cmd+F
- Debounced search (300ms)
- Cancel button on focus

---

## RuleButtonWithMenu

Button with dropdown menu for rule actions.

### Usage

```swift
RuleButtonWithMenu(
    rule: rule,
    onEdit: editRule,
    onDuplicate: duplicateRule,
    onDelete: deleteRule,
    onToggle: toggleRule
)
```

### Menu Items

- Edit Rule
- Duplicate
- Toggle Enabled/Disabled
- Delete

---

# Feedback & Status Components

Components for user feedback and status indication.

---

## ActivityFeed

Real-time feed of file organization activities.

### Usage

```swift
ActivityFeed(
    activities: recentActivities,
    onUndoActivity: undoActivity
)
```

### Activity Types

- **File Scanned:** "Found Report.pdf"
- **File Organized:** "Moved Report.pdf to Documents"
- **File Skipped:** "Skipped temp.txt"
- **Rule Applied:** "Applied 'PDFs to Documents'"
- **Cluster Detected:** "Found 5 related files"
- **Pattern Learned:** "Detected new pattern: .log → Logs/"

### Features

- Relative timestamps ("2 minutes ago")
- Undo button for recent actions
- Real-time updates with animation
- Scrollable list with sticky dates

---

## AllCaughtUpView

Empty state when no files need organization.

### Usage

```swift
AllCaughtUpView(
    onScanAgain: rescanFolders
)
```

### Layout

```
    ✓
All Caught Up!
Your files are organized.

[Scan Again]
```

### Variants

- **No Files:** "No files found"
- **All Organized:** "All caught up!"
- **No Rules:** "Create rules to get started"

---

## StatusIndicator

Color-coded status indicator.

### Usage

```swift
StatusIndicator(status: file.status)
```

### Statuses

- **Pending:** Yellow dot, "Pending"
- **Completed:** Green dot, "Organized"
- **Skipped:** Gray dot, "Skipped"
- **Error:** Red dot, "Error"

---

## Toast

Temporary notification with undo support.

### Usage

```swift
ToastHost(viewModel: dashboardViewModel) {
    // Main content
}
```

### Toast Types

**Success:**
```swift
viewModel.showToast(
    message: "3 files organized",
    canUndo: true,
    action: undoOrganization
)
```

**Error:**
```swift
viewModel.showToast(
    message: "Permission denied",
    isError: true
)
```

### Features

- Auto-dismiss after 4 seconds
- Manual dismiss with X button
- Undo button for reversible actions
- Slide in from bottom

---

## BulkOperationProgressView

Progress indicator for bulk operations.

### Usage

```swift
BulkOperationProgressView(
    current: completedCount,
    total: totalCount,
    operation: "Organizing"
)
```

### Layout

```
Organizing... 47/50
[████████████████░░] 94%

[Cancel]
```

### Features

- Linear progress bar
- Percentage calculation
- Cancel button
- Estimated time remaining (optional)

---

# Storage & Analytics Components

Components for storage visualization and analytics.

---

## StorageChart

Visual breakdown of storage usage by category.

### Usage

```swift
StorageChart(
    categoryUsage: [
        .documents: 2.4 * 1_000_000_000,  // 2.4 GB
        .images: 1.8 * 1_000_000_000,     // 1.8 GB
        .videos: 5.2 * 1_000_000_000      // 5.2 GB
    ],
    totalStorage: 9.4 * 1_000_000_000
)
```

### Chart Types

- **Donut Chart:** Percentage breakdown
- **Bar Chart:** Category comparison
- **Timeline:** Storage over time

### Features

- Interactive hover states
- Legend with colors
- Formatted sizes (GB, MB, KB)

---

## StoragePanel

Panel showing storage stats and recommendations.

### Usage

```swift
StoragePanel(
    usedSpace: usedBytes,
    totalSpace: totalBytes,
    recommendations: storageRecommendations
)
```

### Recommendations

- "Archive old files to free 2.1 GB"
- "Delete duplicates to save 450 MB"
- "Compress videos to save 1.8 GB"

---

# Animation Components

---

## OrganizeAnimations

Collection of organization-themed animations.

### Animations

#### FileFlowAnimation
Files flowing from source to destination.

```swift
FileFlowAnimation(
    from: sourceRect,
    to: destinationRect,
    fileIcon: "doc.fill"
)
```

#### SuccessCheckmark
Animated checkmark on success.

```swift
SuccessCheckmark(size: 64)
```

#### PulseRing
Expanding ring effect.

```swift
PulseRing(color: .formaSage, size: 100)
```

---

# AI & Intelligence Components

AI-powered views for pattern learning, duplicate detection, and project clustering.

---

## AIInsightsView

Dashboard panel displaying AI-discovered insights and learned patterns.

### Usage

```swift
AIInsightsView(
    patterns: learnedPatterns,
    clusters: projectClusters,
    duplicates: duplicateGroups,
    onDismissPattern: { pattern in dismissPattern(pattern) },
    onCreateRule: { pattern in createRuleFromPattern(pattern) }
)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `patterns` | `[LearnedPattern]` | AI-discovered organization patterns |
| `clusters` | `[ProjectCluster]` | Detected project/client file groups |
| `duplicates` | `[DuplicateGroup]` | Detected duplicate file groups |

### Callbacks

| Callback | Description |
|----------|-------------|
| `onDismissPattern` | Dismiss a learned pattern suggestion |
| `onCreateRule` | Create a rule from a learned pattern |
| `onViewCluster` | Navigate to project cluster details |
| `onResolveDuplicates` | Open duplicate resolution workflow |

### Features
- **Pattern Cards**: Shows learned patterns with confidence scores
- **Cluster Preview**: Summarizes detected project groups
- **Duplicate Summary**: Shows potential space savings
- **Empty States**: Helpful guidance when no insights available

---

## DuplicateGroupsView

Displays detected duplicate file groups with resolution actions.

### Usage

```swift
DuplicateGroupsView(
    groups: duplicateGroups,
    onKeepFile: { file, group in keepFile(file, in: group) },
    onRemoveFile: { file, group in removeFile(file, in: group) },
    onDismissGroup: { group in dismissGroup(group) }
)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `groups` | `[DuplicateGroup]` | Detected duplicate groups |

### Callbacks

| Callback | Description |
|----------|-------------|
| `onKeepFile` | Mark file as the one to keep |
| `onRemoveFile` | Mark file for removal |
| `onDismissGroup` | Dismiss/ignore this duplicate group |

### Subcomponents
- **TypeBadge**: Colored badge for duplicate type (exact, version, near)
- **DuplicateGroupCard**: Expandable card showing group details
- **DuplicateFileRow**: Individual file row with keep/remove actions

### States
- **With Duplicates**: Shows summary card and expandable group list
- **Empty State**: "No duplicates found" with checkmark

---

## ProjectClusterView

Displays detected project/client file clusters with organization actions.

### Usage

```swift
ProjectClusterView(
    clusters: projectClusters,
    onOrganizeCluster: { cluster in organizeCluster(cluster) },
    onDismissCluster: { cluster in dismissCluster(cluster) },
    onEditDestination: { cluster in editClusterDestination(cluster) }
)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `clusters` | `[ProjectCluster]` | Detected project clusters |

### Callbacks

| Callback | Description |
|----------|-------------|
| `onOrganizeCluster` | Move all cluster files to suggested folder |
| `onDismissCluster` | Dismiss this cluster suggestion |
| `onEditDestination` | Change the suggested destination folder |

### Cluster Types Display
- **Project Code**: Shows detected project prefix (e.g., "ClientABC_")
- **Temporal**: Shows time window for session clustering
- **Name Similarity**: Shows common naming pattern
- **Date Stamp**: Shows detected date pattern

### Features
- Expandable cluster cards
- File preview within each cluster
- Confidence indicator
- Suggested folder path
- Bulk organize action

---

# Utility Components

---

## Common

Shared utility views and modifiers.

### Components

#### Divider
```swift
FormaDivider(orientation: .horizontal)
```

#### Spacer
```swift
FormaVerticalSpacer(height: .standard)  // 12pt
FormaHorizontalSpacer(width: .generous) // 24pt
```

#### Card Background
```swift
.formaCardBackground()
```

---

## DashboardKeyboardShortcuts

Keyboard shortcut definitions for dashboard.

### Shortcuts

| Key | Modifier | Action |
|-----|----------|--------|
| `⏎` | - | Organize focused file |
| `Space` | - | Quick Look |
| `⌘A` | - | Select all |
| `⌘D` | - | Deselect all |
| `←→↑↓` | - | Navigate files |
| `⇧←→↑↓` | - | Extend selection |
| `⌘F` | - | Focus search |
| `/` | - | Filter files |
| `⌘,` | - | Open settings |

---

## KeyboardHintBadge

Visual hint showing keyboard shortcut.

### Usage

```swift
KeyboardHintBadge(key: "⏎")
KeyboardHintBadge(key: "⌘F")
```

### Style

- Rounded rectangle
- Monospace font
- Subtle shadow
- Positioned near action

---

## BulkEditSheet

Sheet for editing multiple files at once.

### Usage

```swift
.sheet(isPresented: $showingBulkEdit) {
    BulkEditSheet(
        files: selectedFiles,
        onApply: applyBulkChanges
    )
}
```

### Features

- Set destination for all
- Apply rule to all
- Change category
- Add tags (future)

---

# Component Design Patterns

## State Management

**Local State:**
```swift
@State private var isHovered = false
@State private var isExpanded = false
```

**Bindings:**
```swift
@Binding var selectedCategory: FileTypeCategory
@Binding var searchText: String
```

**Environment:**
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.modelContext) private var modelContext
```

**Observed Objects:**
```swift
@ObservedObject var viewModel: DashboardViewModel
```

---

## Callbacks

**Simple Actions:**
```swift
let onTap: () -> Void
let onDismiss: () -> Void
```

**With Parameters:**
```swift
let onFileSelected: (FileItem) -> Void
let onRuleApplied: (Rule, FileItem) -> Void
```

**Optional Callbacks:**
```swift
let onUndo: (() -> Void)?
```

---

## Computed Properties

**Styling:**
```swift
private var backgroundColor: Color {
    isSelected ? .formaSteelBlue : .white
}
```

**Conditional Display:**
```swift
private var shouldShowActions: Bool {
    isHovered && !isSelectionMode
}
```

---

## Animations

**Implicit Animations:**
```swift
.animation(.easeInOut(duration: 0.2), value: isSelected)
```

**Explicit Animations:**
```swift
withAnimation(.spring(response: 0.3)) {
    isExpanded.toggle()
}
```

**Reduce Motion:**
```swift
.animation(reduceMotion ? .none : .spring(), value: isFocused)
```

---

## Accessibility

**Labels:**
```swift
.accessibilityLabel("Organize file")
.accessibilityHint("Moves file to suggested destination")
```

**Actions:**
```swift
.accessibilityAddTraits(.isButton)
.accessibilityAction { performAction() }
```

**Grouping:**
```swift
.accessibilityElement(children: .combine)
```

---

## Performance

**Lazy Loading:**
```swift
LazyVGrid(columns: columns) {
    ForEach(files) { file in
        FileGridItem(file: file)
    }
}
```

**Conditional Rendering:**
```swift
if isHovered {
    HoverActionsView()
}
```

**View Identity:**
```swift
.id("\(file.path)-\(isSelected)")
```

---

# Testing Components

## Preview Providers

All components include Xcode preview providers:

```swift
#Preview {
    FileGridItem(
        file: FileItem.preview,
        isFocused: false,
        isSelected: false,
        isSelectionMode: false,
        onToggleSelection: {},
        onOrganize: {},
        onEdit: {},
        onSkip: {},
        onQuickLook: {}
    )
    .padding()
}
```

## Component Testing Checklist

- [ ] Default state renders correctly
- [ ] Hover state shows appropriate feedback
- [ ] Selected state has clear visual distinction
- [ ] Keyboard navigation works
- [ ] Callbacks trigger correctly
- [ ] Animations respect reduce motion
- [ ] VoiceOver announces correctly
- [ ] Handles missing data gracefully
- [ ] Performs well with large datasets

---

## Related Documentation

- [Design System](../Design/DesignSystem.md) - Design tokens, colors, typography, and spacing
- [UI Guidelines](../Design/UI-GUIDELINES.md) - UI implementation patterns
- [Dashboard Architecture](DASHBOARD.md) - Main interface component composition
- [Right Panel Architecture](RIGHT_PANEL.md) - Contextual copilot panel components
- [Onboarding Flow](../Design/Forma-Onboarding-Flow.md) - Onboarding component usage

---

**Document Version:** 1.0
**Last Updated:** December 2025
**Component Count:** 34
**Next Review:** When new components are added
