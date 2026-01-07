# Dashboard Feature Documentation

## Overview

The Dashboard is the main interface of Forma, providing a comprehensive view of file organization status, storage analytics, and recent activity. Inspired by modern document management interfaces, it offers an intuitive three-column layout optimized for desktop file organization workflows.

## Architecture

### Three-Column Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Left Sidebar  │      Main Content Area       │  Right Sidebar  │
│   Navigation   │   Files & Analytics          │  Storage & Feed │
│    (240px)     │        (Flexible)            │     (280px)     │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Left Sidebar (SidebarView)

**Purpose**: Primary navigation and quick actions

**Elements**:
- **Search Field**: Compact search bar for quick file filtering
- **Navigation Menu**:
  - Locations: Home, Desktop, Downloads
  - Smart Rules: My Rules, Create Rule
- **Bottom Controls**:
  - Sidebar Toggle (Collapse/Expand)
  - Scan Files (Triggers manual file scan)

**Styling**:
- Width: 256px (expanded) / 72px (collapsed)
- Background: Regular Material (Native macOS blur)
- Layout: Anchored full-height, extends behind traffic lights
- Interaction: Hover states with Steel Blue accent

### 2. Main Content Area (MainContent)

**Purpose**: Primary content display with filtering and file management

#### Unified Toolbar (UnifiedToolbar)

**Location**: Top of content area

**Features**:
- **Mode Toggling**: Smooth morphing between "Review" and "All Files" modes
- **Filter Tabs**: Secondary filters (Recent, Large, Flagged)
- **View Controls**: Grid/List/Tile toggles
- **Responsive Design**: Collapses gracefully on smaller screens

#### Content States

**Loading State**:
- Circular progress indicator
- "Scanning Desktop..." message
- Displayed during initial file scan

**Empty State**:
- Large folder icon
- "No Files Found" message
- Helpful guidance text

**Error State**:
- Warning triangle icon
- Error message display
- "Try Again" button

**Loaded State** (has two sections):

##### Recent Files Section
- **Component**: `RecentFilesGrid`
- **Layout**: 4-column grid
- **Display**: Up to 8 most recently added files
- **Features**:
  - File thumbnails (for images)
  - File type icons
  - File size display
  - Category badges
  - "See All" link to view full list

##### All Files Section
- **Component**: `AllFilesSection`
- **Layout**: Vertical list with cards
- **Features**:
  - Filtered by selected category
  - File count display
  - Detailed file information
  - Status badges (Pending, Ready, Done, Skipped)

### 3. Right Panel (RightPanelView)

**Purpose**: Contextual intelligent copilot that adapts to user context

**Width**: 360px fixed

**Architecture**: Mode-based with four distinct states

#### Panel Modes

The right panel operates in one of four modes based on the current user context:

##### 1. Default Mode (DefaultPanelView)

**Displayed when**: No files selected, no active workflows

**Features**:
- **Organization Status Card**: Quick stats on pending/ready/done files
- **Quick Actions**: 
  - Scan Files
  - Organize All Ready
  - Create Rule
  - View All Rules
- **Smart Insights**: Top 3 contextual insights from InsightsService
  - Screenshot accumulation alerts (≥5 screenshots)
  - Downloads folder overload (≥15 files)
  - Large file detection (≥3 files >100MB)
  - Rule creation opportunities
  - Weekly cleanup reminders
  - Duplicate file warnings
- **Activity Feed**: Last 5 recent activities (compact view)
- **Storage Overview**: Collapsible storage breakdown by category

##### 2. Inspector Mode (FileInspectorView)

**Displayed when**: One or more files are selected

**Single File Mode**:
- **Preview**: Image/icon preview with file type badge
- **Metadata Card**: Name, type, size, creation date, location
- **Organization Section**:
  - Suggested destination (if available)
  - Rule name that matched
  - Action buttons: Organize, Skip, Delete
- **Similar Files**: Discover files with same extension/pattern

**Multi-File Mode** (2+ files selected):
- **Selection Summary**: Count, total size, file types
- **Preview Grid**: Up to 4 file previews
- **Pattern Detection**: Common extensions, size ranges, shared locations
- **Bulk Actions**: 
  - Organize Selected (only if all have same destination)
  - Skip All
  - Create Rule from Selection

##### 3. Rule Builder Mode (InlineRuleBuilderView)

**Displayed when**: User clicks "Create Rule" from a file or panel

**Features**:
- **Compact Rule Editor**: Optimized for 360px width
- **Smart Initialization**: Pre-fills condition from file context
- **Multiple Conditions**: Add multiple conditions with AND/OR logic
- **Live Preview**: Shows count of files that match as user edits
- **Matched Files Display**: Lists up to 3 matched files with icons
- **Validation**: Real-time feedback on rule completeness
- **Folder Picker**: Integrated destination folder selection
- **Actions**: Save (creates and applies rule) or Cancel

**Context Awareness**:
- If opened from a .pdf file, suggests: Extension = "pdf"
- If opened from "Screenshot 2024-01-15.png", suggests: Name starts with "Screenshot"

**Multiple Condition Support**:
- Users can add multiple conditions by clicking the plus button after entering a condition
- Each condition displays as a removable card with type and value
- When 2+ conditions exist, a segmented control appears to select AND/OR logic
- AND logic: All conditions must match
- OR logic: At least one condition must match
- Live preview updates to show match count for compound conditions
- Backward compatible with legacy single-condition rules

##### 4. Celebration Mode (CelebrationView)

**Displayed when**: File operation completes successfully

**Features**:
- **Success Animation**: Checkmark with spring animation
- **Message**: Contextual success message (e.g., "3 files organized!")
- **Prominent Undo Button**: Large, accessible undo action
- **Auto-Dismiss**: Returns to previous mode after 5 seconds
- **What's Next**: Suggested next actions

**Accessibility**:
- Respects `accessibilityReduceMotion` setting
- Undo remains accessible after auto-dismiss via Command+Z

#### Mode Transitions

**State Management** (in DashboardViewModel):
```swift
enum RightPanelMode {
    case `default`
    case inspector([FileItem])
    case ruleBuilder(FileItem?)
    case celebration(String)
}

@Published private(set) var rightPanelMode: RightPanelMode = .default
```

**Transition Rules**:
1. **Default → Inspector**: Triggered when user selects one or more files
2. **Inspector → Default**: Triggered when selection is cleared
3. **Any → Rule Builder**: Triggered by "Create Rule" action
4. **Any → Celebration**: Triggered after successful file operation
5. **Celebration → Default**: Auto-dismiss after 5 seconds or manual return

**Priority Order** (when multiple triggers occur):
1. Celebration (highest priority - always shows)
2. Rule Builder (explicit user action)
3. Inspector (implicit from selection)
4. Default (fallback)

**Animation**:
```swift
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: rightPanelMode)
```

#### InsightsService

**Purpose**: Generates contextual, actionable insights from file patterns

**Pattern Detection Types**:
1. **Screenshot Accumulation**: Detects ≥5 screenshots in recent files
2. **Downloads Overload**: Alerts when ≥15 files in Downloads folder
3. **Large Files**: Identifies ≥3 files larger than 100MB
4. **Rule Opportunities**: Suggests rules after 3+ manual moves to same destination
5. **Weekly Summary**: Periodic cleanup reminders
6. **Duplicate Detection**: Finds files with identical names/sizes

**Insight Structure**:
```swift
struct FileInsight {
    let type: InsightType
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?
    let priority: Int  // Higher = more important
}
```

**Usage in DefaultPanelView**:
- Displays top 3 insights sorted by priority
- Each insight shows icon, title, message, and optional action button
- Icons are color-coded by insight type
- Insights update reactively as file state changes

#### Data Flow

**Selection-Driven Inspection**:
1. User clicks file card in main content area
2. `DashboardViewModel.toggleSelection(for:)` called
3. `selectedFileIDs` and `selectedFiles` updated
4. Computed property triggers: `rightPanelMode` → `.inspector(selectedFiles)`
5. `RightPanelView` observes mode change and renders `FileInspectorView`

**Rule Creation Flow**:
1. User clicks "Create Rule" in inspector or default panel
2. `DashboardViewModel.showRuleBuilderPanel(for:)` called with optional file context
3. `rightPanelMode` set to `.ruleBuilder(file)`
4. `InlineRuleBuilderView` initializes with file context (if provided)
5. User edits rule, preview updates live via RuleEngine
6. On save: rule created, files re-evaluated, panel returns to default

**Celebration Flow**:
1. User organizes file(s) via `DashboardViewModel.organizeFile()` or `organizeSelectedFiles()`
2. After file operation succeeds, `showCelebrationPanel(message:)` called
3. `rightPanelMode` set to `.celebration(message)`
4. Timer set for 5-second auto-dismiss
5. `CelebrationView` renders with animation
6. After timeout or user action: `returnToDefaultPanel()` called

## Action-Oriented Card View (Phase 4)

### FileRow Component

**Purpose**: Primary file display component optimized for rapid organization

**Layout**: Vertical card with clear action hierarchy
- Top section: checkbox, thumbnail (52px), file metadata
- Action section: dynamic primary button + secondary action links

**Primary Action Logic**:
The card displays different primary actions based on file state:

1. **File has destination + ready status** → "Organize to [folder]" (green)
2. **File has destination + pending status** → "Review Destination" (blue)
3. **No destination** → "Create Rule" (blue)

**Secondary Actions**: Always visible below primary button
- Skip • Edit Destination • Quick Look
- Show keyboard shortcuts when focused

**Focus Indicator**: 2px blue border with smooth animation

### Keyboard Navigation

**Navigation Shortcuts**:
- `J` or `↓`: Next file
- `K` or `↑`: Previous file
- `Space`: Quick Look preview

**Action Shortcuts**:
- `Enter`: Execute primary action (organize/review/create rule)
- `Cmd+Enter`: Organize and advance to next file
- `S`: Skip file
- `E`: Edit destination
- `R`: Create rule from file

**Selection Shortcuts**:
- `Click`: Toggle file selection
- `Cmd+A`: Select all visible files
- `Cmd+D`: Deselect all
- `Shift+Click`: Range select

**View Mode Shortcuts**:
- `Cmd+1`: Grid view
- `Cmd+2`: List view
- `Cmd+3`: Card view (default)

**Other Shortcuts**:
- `Cmd+Z`: Undo last action
- `Cmd+Shift+Z`: Redo
- `?`: Show keyboard shortcuts help overlay
- `Esc`: Dismiss modals/help

### KeyboardShortcutsHelpView

**Component**: Modal overlay displaying all available shortcuts

**Trigger**: Press `?` key anywhere in the dashboard

**Layout**:
- Semi-transparent backdrop (dismissible on click)
- Centered card (600x650px)
- Shortcuts grouped by context:
  - Navigation
  - Actions
  - Selection
  - View
  - Other

**Key Cap Design**: Styled keyboard key representations (e.g., `Cmd`, `Enter`, `S`)

**Accessibility**: 
- Respects reduced motion preferences
- Dismissible with `Esc` or background click

### Keyboard Hints

**KeyboardHintBadge**: Small badges showing shortcuts inline

**Display Logic**:
- Only shown when `isKeyboardNavigating` is true
- Appears on focused card's primary button: "Organize [↵]"
- Shows on secondary actions: "Skip [S]", "Edit [E]", "Quick Look [Space]"

**Tracking**: `DashboardViewModel.isKeyboardNavigating` set to true when using J/K or arrow keys

### Focus Indicators Across Views

**Card View (FileRow)**:
- 2px solid blue border (`Color.formaSteelBlue`)
- Enhanced shadow
- Smooth animation (0.2s ease-in-out)

**List View (FileListRow)**:
- 4px left accent bar (`RoundedRectangle`)
- Subtle background tint
- Row striping for improved scanability (alternating backgrounds)

**Grid View (FileGridItem)**:
- 2px blue border around entire item
- 1.02 scale effect
- Smooth spring animation

### AllCaughtUpView Enhancement

**Displayed when**: Review mode empty (all files organized)

**Features**:
- Success checkmark with spring animation
- Daily stats badges (organized, skipped, rules created)
- Next action suggestions:
  - Scan for new files
  - Switch to All Files view
  - Review rules

**Animation**: Checkmark scales from 0.5 to 1.0 with spring physics

**Accessibility**: Respects `accessibilityReduceMotion`

## View Models

### DashboardViewModel

**Responsibilities**:
- File scanning coordination
- Category filtering
- Storage analytics calculation
- Activity tracking
- Rule management

**Published Properties**:
```swift
@Published var allFiles: [FileItem] = []
@Published var filteredFiles: [FileItem] = []
@Published var selectedCategory: FileTypeCategory = .all
@Published var storageAnalytics: StorageAnalytics = .empty
@Published var recentFiles: [FileItem] = []
@Published var recentActivities: [ActivityItem] = []
@Published var isLoading = false
@Published var errorMessage: String?
```

**Key Methods**:
- `scanFiles()`: Scans Desktop and Downloads folders
- `selectCategory(_:)`: Updates filter and refreshes view
- `loadRules(from:)`: Loads enabled rules from SwiftData
- `loadActivities(from:)`: Fetches recent activities
- `refresh()`: Re-scans all files

## Data Flow

### Initial Load Sequence

1. **App Launch** → `DashboardView.onAppear()`
2. **Load Rules** → `viewModel.loadRules(from: modelContext)`
3. **Load Activities** → `viewModel.loadActivities(from: modelContext)`
4. **Scan Files** → `viewModel.scanFiles()`
   - Scan Desktop folder
   - Scan Downloads folder
   - Apply rules to get suggestions
   - Update analytics
   - Update recent files

### Filtering Flow

1. **User Selects Category** → `FilterTabBar` or `StoragePanel`
2. **Update Selection** → `viewModel.selectCategory(category)`
3. **Apply Filter** → `StorageService.filterFiles()`
4. **Update View** → `filteredFiles` published property triggers re-render

### Storage Analytics Flow

1. **Files Loaded** → `updateAnalytics()` called
2. **Calculate Totals** → `StorageService.calculateAnalytics()`
3. **Group by Category** → Sum bytes per FileTypeCategory
4. **Calculate Percentages** → `analytics.percentageForCategory()`
5. **Cache Results** → 60-second validity period
6. **Update UI** → `StorageChart` and `StoragePanel` re-render

## Storage Analytics Details

### Calculation Logic

```swift
struct StorageAnalytics {
    let totalBytes: Int64
    let categoryBreakdown: [FileTypeCategory: Int64]
    let fileCount: Int
    let categoryFileCounts: [FileTypeCategory: Int]

    func percentageForCategory(_ category: FileTypeCategory) -> Double {
        guard totalBytes > 0 else { return 0 }
        let categoryBytes = sizeForCategory(category)
        return (Double(categoryBytes) / Double(totalBytes)) * 100
    }
}
```

### Caching Strategy

**Purpose**: Avoid expensive recalculations on every UI update

**Implementation**:
```swift
private var cachedAnalytics: StorageAnalytics?
private var lastCacheTime: Date?

func getAnalytics(from files: [FileItem], forceRefresh: Bool = false) -> StorageAnalytics {
    if !forceRefresh,
       let cached = cachedAnalytics,
       let cacheTime = lastCacheTime,
       Date().timeIntervalSince(cacheTime) < 60 {
        return cached
    }

    let fresh = calculateAnalytics(from: files)
    cachedAnalytics = fresh
    lastCacheTime = Date()
    return fresh
}
```

## File Type Categorization

### FileTypeCategory Enum

**Categories**:
- `.all` - All files (meta-category)
- `.documents` - Office docs, PDFs, text files
- `.images` - Photos, graphics, design files
- `.videos` - Video files
- `.audio` - Music and audio files
- `.archives` - Compressed and package files

### Extension Mapping

Each category has a comprehensive list of file extensions:

```swift
var extensions: [String] {
    switch self {
    case .documents:
        return ["pdf", "doc", "docx", "txt", "rtf", "pages",
                "xls", "xlsx", "csv", "ppt", "pptx", "keynote"]
    case .images:
        return ["jpg", "jpeg", "png", "heic", "gif", "svg",
                "psd", "ai", "raw", "cr2", "nef"]
    // ... etc
    }
}
```

### Category Detection

```swift
static func category(for fileExtension: String) -> FileTypeCategory {
    let ext = fileExtension.lowercased()
    for category in allCases where category != .all {
        if category.extensions.contains(ext) {
            return category
        }
    }
    return .documents // Default fallback
}
```

## UI Patterns

### State-Based Rendering

The dashboard uses SwiftUI's state-driven rendering:

```swift
Group {
    switch viewModel.loadingState {
    case .idle, .loading:
        ReviewLoadingStateView()
    case .error:
        EmptyStateView()
    case .loaded:
        if viewModel.files.isEmpty {
            EmptyStateView()
        } else {
            // Content views
        }
    }
}
```

### Responsive Layout

**Minimum Window Size**: 1200x800

**Breakpoints**:
- Left sidebar: 240px (fixed)
- Right sidebar: 280px (fixed)
- Main content: Flexible (minimum ~680px)

## Performance Optimizations

### 1. Lazy Loading

```swift
LazyVStack(spacing: Spacing.tight) {
    ForEach(files, id: \.path) { file in
        FileListRow(file: file)
    }
}
```

### 2. Analytics Caching

60-second cache prevents recalculation on every UI update.

### 3. Computed Properties

File categories are computed on-demand rather than stored:

```swift
var category: FileTypeCategory {
    FileTypeCategory.category(for: fileExtension)
}
```

### 4. Mock Data for Previews

Development mode uses mock data to avoid file system access:

```swift
#if DEBUG
if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
    loadMockData()
}
#endif
```

## Styling & Design

### Color Palette

**Primary**:
- Bone White: Background (#F8F7F4)
- Obsidian: Primary text (#2C2C2C)
- Steel Blue: Accent color (#4A7C99)

**Category Colors**:
- Documents: Steel Blue (#4A7C99)
- Images: Sage (#8FA68E)
- Videos: Clay (#A67C6D)
- Audio: Terracotta (#C97B63)
- Archives: Amber (#D9A95A)

### Typography

- **H1**: 24pt, Semi-bold (Main headings)
- **H2**: 18pt, Semi-bold (Section headers)
- **Body**: 14pt, Regular (Primary text)
- **Small**: 12pt, Regular (Secondary text)

### Spacing Scale

- **Micro**: 4pt (Tight elements)
- **Tight**: 8pt (Related items)
- **Standard**: 12pt (Default spacing)
- **Generous**: 16pt (Section spacing)
- **XL**: 24pt (Major sections)

## Testing Considerations

### Unit Tests

**Recommended test coverage**:
- `StorageAnalytics.calculate()` - Ensure correct byte summation
- `FileTypeCategory.category(for:)` - Extension mapping accuracy
- `StorageService.filterFiles()` - Correct filtering logic
- `DashboardViewModel.selectCategory()` - State updates

### Integration Tests

- File scanning with mock FileSystemService
- Rule evaluation with test rules
- Activity tracking persistence

### UI Tests

- Category filter interaction
- Storage chart rendering
- Navigation between views

## Accessibility

**Implemented**:
- Semantic labels for all interactive elements
- Color contrast ratios meet WCAG AA standards
- Keyboard navigation support

**Future Enhancements**:
- VoiceOver descriptions for charts
- Reduced motion preferences
- Dynamic type support

## Known Limitations

1. **Storage Chart**: Limited to 6 categories (no overflow handling)
2. **Activity Feed**: Shows only last 10 activities
3. **Recent Files**: Limited to 8 files
4. **Analytics Caching**: Not persisted across app launches

## Future Enhancements

### Phase 2
- [ ] Search and filtering within categories
- [ ] Sortable file lists (by name, size, date)
- [ ] File preview on hover
- [ ] Drag-and-drop file organization

### Phase 3
- [ ] Storage trends over time (charts)
- [ ] Smart suggestions based on patterns
- [ ] Duplicate file detection
- [ ] Bulk rule application

### Phase 4
- [ ] Export storage reports
- [ ] Custom category creation
- [ ] Advanced analytics dashboard
- [ ] Cloud storage integration

---

## Related Documentation

- [RIGHT_PANEL.md](./RIGHT_PANEL.md) - Contextual copilot architecture (right panel modes, inspector, insights)
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall system architecture
- [RuleEngine-Architecture.md](./RuleEngine-Architecture.md) - Rule evaluation system
- [ComponentArchitecture.md](./ComponentArchitecture.md) - Reusable UI components
- [../Design/DesignSystem.md](../Design/DesignSystem.md) - Design tokens and styling
- [../Roadmap/V2-Cloud-Storage-Integration.md](../Roadmap/V2-Cloud-Storage-Integration.md) - Cloud storage roadmap
