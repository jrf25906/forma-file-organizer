# Forma - System Architecture

**Version:** 2.0
**Last Updated:** 2026-01-06
**Status:** Current Implementation

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Layer Details](#layer-details)
   - [Presentation Layer](#presentation-layer)
   - [ViewModel Layer](#viewmodel-layer)
   - [Service Layer](#service-layer)
   - [Model Layer](#model-layer)
4. [Component Relationships](#component-relationships)
5. [Data Flow](#data-flow)
6. [State Management](#state-management)
7. [Permission System](#permission-system)
8. [Feature Architecture](#feature-architecture)
9. [Technology Stack](#technology-stack)
10. [Design Patterns](#design-patterns)

---

## System Overview

Forma is a native macOS application built with SwiftUI and SwiftData that automates file organization through a rule-based system. The architecture follows MVVM (Model-View-ViewModel) pattern with clear separation of concerns.

### Core Principles

1. **Security-First**: Uses security-scoped bookmarks for folder access
2. **User Control**: All file operations require explicit permission
3. **Reactive UI**: SwiftUI with Combine for state management
4. **Persistent State**: SwiftData for rules and file tracking
5. **Service Layer**: Business logic isolated from UI

### High-Level Flow

```
User → UI (Views) → ViewModel → Services → File System
                      ↓
                   SwiftData (Persistence)
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  MenuBarView │  │  ReviewView  │  │ SettingsView │         │
│  │              │  │              │  │              │         │
│  │ - Show badge │  │ - File list  │  │ - Rule mgmt  │         │
│  │ - Scan now   │  │ - Organize   │  │ - Prefs      │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                  │
│         └──────────────────┼──────────────────┘                  │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                     VIEW MODEL LAYER                             │
├────────────────────────────┼─────────────────────────────────────┤
│                            │                                     │
│                    ┌───────▼──────────┐                          │
│                    │  ReviewViewModel │                          │
│                    │                  │                          │
│                    │ @Published       │                          │
│                    │ - files          │                          │
│                    │ - loadingState   │                          │
│                    │ - errorMessage   │                          │
│                    │                  │                          │
│                    │ Methods:         │                          │
│                    │ - scanDesktop()  │                          │
│                    │ - moveFile()     │                          │
│                    │ - moveAllFiles() │                          │
│                    └─────┬─────┬──────┘                          │
│                          │     │                                 │
└──────────────────────────┼─────┼─────────────────────────────────┘
                           │     │
┌──────────────────────────┼─────┼─────────────────────────────────┐
│                     SERVICE LAYER                                │
├──────────────────────────┼─────┼─────────────────────────────────┤
│                          │     │                                 │
│  ┌───────────────────────▼┐   ┌▼──────────────────────────┐     │
│  │ FileSystemService      │   │ FileOperationsService     │     │
│  │                        │   │                           │     │
│  │ - scanDesktop()        │   │ - moveFile()              │     │
│  │ - getDesktopURL()      │   │ - moveFiles()             │     │
│  │ - requestAccess()      │   │ - ensureDestinationAccess()│    │
│  │ - scanDirectory()      │   │ - requestDestinationAccess()│   │
│  └────────────────────────┘   └───────────────────────────┘     │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ RuleEngine                                                │  │
│  │                                                           │  │
│  │ - evaluateFile()    → Match file against rules           │  │
│  │ - evaluateFiles()   → Batch evaluation                   │  │
│  │ - matches()         → Condition checking                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                                │
┌───────────────────────────────┼──────────────────────────────────┐
│                        MODEL LAYER                               │
├───────────────────────────────┼──────────────────────────────────┤
│                               │                                  │
│  ┌──────────────┐      ┌──────▼─────┐                           │
│  │   FileItem   │      │    Rule    │                           │
│  │              │      │            │                           │
│  │ @Model       │      │ @Model     │                           │
│  │ - name       │      │ - name     │                           │
│  │ - path       │      │ - condType │                           │
│  │ - extension  │      │ - condVal  │                           │
│  │ - size       │      │ - action   │                           │
│  │ - createdAt  │      │ - destPath │                           │
│  │ - suggested  │      │ - enabled  │                           │
│  │ - status     │      │            │                           │
│  └──────────────┘      └────────────┘                           │
│                                                                  │
│                    ┌────────────────┐                            │
│                    │  ModelContext  │                            │
│                    │   (SwiftData)  │                            │
│                    └────────────────┘                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                                │
┌───────────────────────────────┼──────────────────────────────────┐
│                     SYSTEM LAYER                                 │
├───────────────────────────────┼──────────────────────────────────┤
│                               │                                  │
│  ┌────────────────────────────▼───────────────────────────────┐ │
│  │           macOS File System & Security                     │ │
│  │                                                            │ │
│  │  • FileManager              • NSOpenPanel                 │ │
│  │  • Security-scoped URLs     • UserDefaults (bookmarks)    │ │
│  │  • File operations          • Directory monitoring        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Layer Details

### Presentation Layer

Forma uses a **three-panel dashboard** as its primary interface, replacing the earlier single-view approach.

#### Main Views

| View | Purpose | Key Features |
|------|---------|--------------|
| **DashboardView** | Main three-panel layout | Sidebar + MainContent + RightPanel |
| **SidebarView** | Left navigation panel | Folders, filters, activity feed |
| **MainContentView** | Center content area | File list, grid/list view modes, bulk actions |
| **RightPanelView** | Context-aware right panel | File inspector, rule builder, insights |
| **OnboardingFlowView** | 5-step first-time setup (modular) | `Views/Onboarding/` - Coordinator + step views |
| **PersonalityQuizView** | 3-question assessment | Determines organization personality |
| **RulesManagementView** | Rule configuration | Create, edit, delete rules |
| **SettingsView** | App preferences (modular) | `Views/Settings/` - TabView coordinator + sections |
| **FileInspectorView** | File details panel | Metadata, preview, quick actions |
| **ReviewView** | File review interface | Preview changes before organizing |
| **ProjectClusterView** | Related file detection | Group files by project |
| **RuleSuggestionView** | AI-powered rule creation | Suggested rules based on patterns |
| **InlineRuleBuilderView** | Quick rule creation | Create rules from file context |
| **TemplateSelectionView** | Organization system picker | 8 pre-built templates |
| **MenuBarView** | macOS menu bar extra | Quick access, badge count |

#### Modular View Architectures

Large views have been decomposed into modular structures for maintainability:

**Onboarding Flow (`Views/Onboarding/`):**
```
OnboardingFlowView.swift        (coordinator)
├── OnboardingState.swift       (shared @Observable state)
├── WelcomeStepView.swift       (value proposition)
├── FolderSelectionStepView.swift (folder picker)
├── PersonalityQuizStepView.swift (personality assessment)
├── TemplateSelectionStepView.swift (per-folder templates)
├── OnboardingPreviewStepView.swift (final review)
├── OnboardingComponents.swift  (shared UI components)
└── ARCHITECTURE.md             (local architecture docs)
```

**Settings (`Views/Settings/`):**
```
SettingsView.swift              (coordinator with TabView)
├── SettingsComponents.swift    (shared styling)
├── GeneralSettingsSection.swift (appearance, shortcuts)
├── RulesManagerSection.swift   (rule listing, editing)
├── CustomFoldersSection.swift  (folder management)
├── SmartFeaturesSection.swift  (AI toggles, automation)
└── AboutSection.swift          (version, links)
```

**Shared Components (`Views/Components/` & `Components/Shared/`):**
```
Views/Components/
├── RuleFormState.swift         (unified rule form state)
└── CategoryComponents.swift    (CreateCategoryPopover, CategoryPill)

Components/Shared/
├── FormaCheckbox.swift         (unified checkbox with variants)
├── FormaThumbnail.swift        (unified thumbnail with modes)
└── FormaActionButton.swift     (unified action button styles)
```

#### Reusable Components (33 total)

See [ComponentArchitecture.md](../Architecture/ComponentArchitecture.md) for full details.

Key components:
- **FileGridItem**, **FileListRow** - File display cards
- **FloatingActionBar** - Bulk operation controls
- **FilterTabBar** - File filtering tabs
- **ActivityFeed** - Real-time activity timeline
- **StorageChart** - Storage visualization
- **Toast** - Notification system

---

### ViewModel Layer

ViewModels orchestrate business logic and manage UI state. The dashboard uses a **Coordinator Pattern** where the main ViewModel composes focused child ViewModels for better separation of concerns and testability.

#### DashboardViewModel (Coordinator)

**Role:** Main application state coordinator that composes specialized ViewModels

**Architecture Pattern:** Coordinator Pattern with ViewModel Composition

```
┌─────────────────────────────────────────────────────────────────┐
│                     DashboardViewModel                          │
│                     (Coordinator)                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │ FileScanVM     │  │ FilterVM       │  │ SelectionVM      │  │
│  │                │  │                │  │                  │  │
│  │ - allFiles     │  │ - searchText   │  │ - selectedFiles  │  │
│  │ - recentFiles  │  │ - activeChips  │  │ - focusedFile    │  │
│  │ - isScanning   │  │ - filteredFiles│  │ - lastSelectedIdx│  │
│  │ - scanProgress │  │ - selectedCat  │  │                  │  │
│  └────────────────┘  └────────────────┘  └──────────────────┘  │
│                                                                 │
│  ┌────────────────────────────┐  ┌──────────────────────────┐  │
│  │ AnalyticsDashboardVM       │  │ BulkOperationVM          │  │
│  │                            │  │                          │  │
│  │ - storageAnalytics         │  │ - bulkOperationProgress  │  │
│  │ - filteredStorageAnalytics │  │ - isProcessingBulk       │  │
│  │ - organizationScore        │  │ - pendingOperations      │  │
│  └────────────────────────────┘  └──────────────────────────┘  │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Additional Coordinators:                                   │ │
│  │ - PanelStateManager (panel visibility, navigation)         │ │
│  │ - FileOrganizationCoordinator (file movement)              │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Key Responsibilities:**
- Composes and coordinates child ViewModels
- Forwards `objectWillChange` from children via Combine
- Manages permissions state and onboarding
- Handles content search across files
- Initializes services and coordinates inter-VM communication

**Child ViewModels:**

| ViewModel | Responsibility | Key Properties |
|-----------|----------------|----------------|
| `FileScanViewModel` | File discovery, scanning | `allFiles`, `recentFiles`, `isScanning`, `scanProgress` |
| `FilterViewModel` | Filtering, search, view modes | `searchText`, `activeChips`, `filteredFiles`, `selectedCategory` |
| `SelectionViewModel` | Multi-select, keyboard nav | `selectedFiles`, `focusedFile`, `lastSelectedIndex` |
| `AnalyticsDashboardViewModel` | Storage stats, insights | `storageAnalytics`, `organizationScore` |
| `BulkOperationViewModel` | Batch operations | `bulkOperationProgress`, `isProcessingBulk` |

**Coordinator Pattern Implementation:**
```swift
@MainActor
class DashboardViewModel: ObservableObject {
    // Child ViewModels
    @ObservedObject private(set) var scanViewModel: FileScanViewModel
    @ObservedObject private(set) var filterViewModel: FilterViewModel
    @ObservedObject private(set) var selectionViewModel: SelectionViewModel
    @ObservedObject private(set) var analyticsViewModel: AnalyticsDashboardViewModel
    @ObservedObject private(set) var bulkOperationViewModel: BulkOperationViewModel

    // Forward objectWillChange from children
    private func setupViewModelForwarding() {
        scanViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        // ... similar for other child ViewModels
    }
}
```

**Key Methods:**
- `scanFiles(context:)` - Delegates to FileScanViewModel
- `organizeSelected()` - Delegates to BulkOperationViewModel
- `applyTemplate(_ template:)` - Apply organization template rules
- `undoLastOperation()` - Undo file move
- `requestFolderAccess(_ folder:)` - Request permission for folder

---

#### ReviewViewModel

**Role:** File review and organization workflow

**Key Responsibilities:**
- Scans source folders (Desktop, Downloads, etc.)
- Evaluates files against active rules
- Manages file move operations
- Tracks operation status (loading, success, error)

**Published Properties:**
```swift
@Published var files: [FileItem]
@Published var loadingState: LoadingState
@Published var errorMessage: String?
@Published var successMessage: String?
```

**Key Methods:**
- `scanDesktop()` - Scan Desktop folder
- `moveFile(_ file:)` - Move single file
- `moveAllFiles()` - Batch move all ready files

---

### Service Layer

18 services handle all business logic, isolated from UI concerns.

#### Core Services

##### 1. FileSystemService
**Purpose:** File scanning and access management

**Key Methods:**
- `scanDesktop() async throws -> [FileItem]`
- `scanDirectory(at: URL) async throws -> [FileItem]`
- `requestAccess(to: URL) async throws -> URL`
- `getDesktopURL() throws -> URL`

**Responsibilities:**
- Security-scoped bookmark resolution
- Directory scanning with FileManager
- File metadata extraction (size, dates, extension)
- Permission validation

---

##### 2. RuleEngine
**Purpose:** Rule evaluation and file matching

**Key Methods:**
- `evaluateFile(_ file:, rules:) -> FileItem`
- `evaluateFiles(_ files:, rules:) -> [FileItem]`
- `matches(file:, rule:) -> Bool`

**Matching Logic:**
```swift
switch rule.conditionType {
case .fileExtension:
    return file.fileExtension == rule.conditionValue
case .nameContains:
    return file.name.localizedCaseInsensitiveContains(rule.conditionValue)
case .nameMatches:
    return file.name == rule.conditionValue
case .sizeGreaterThan:
    return file.size > Int64(rule.conditionValue) ?? 0
case .olderThan:
    return file.createdAt < Date().addingTimeInterval(-days)
}
```

---

##### 3. FileOperationsService
**Purpose:** File move operations with permission handling

**Key Methods:**
- `moveFile(_ file:) async throws -> MoveResult`
- `moveFiles(_ files:) async throws -> [MoveResult]`
- `secureMoveOnDisk(from: to:) throws`

**Security Flow:**
1. Parse destination path (e.g., "Documents/Finance")
2. Resolve top-level folder ("Documents")
3. Check for saved bookmark
4. Request access if needed (NSOpenPanel)
5. Validate folder selection
6. Start security-scoped access
7. Create subdirectories
8. Move file with FileManager
9. Stop security-scoped access

---

##### 4. SecureBookmarkStore
**Purpose:** Centralized security-scoped bookmark management

**Key Methods:**
- `saveBookmark(for: URL, key: String) throws`
- `resolveBookmark(for key: String) throws -> URL?`
- `hasBookmark(for key: String) -> Bool`
- `removeBookmark(for key: String)`
- `listAllBookmarks() -> [String]`

**Storage:**
- Uses UserDefaults for persistence
- Keys: `"DesktopFolderBookmark"`, `"DestinationFolderBookmark_Documents"`, etc.
- Handles stale bookmark errors
- Validates bookmark data integrity

---

##### 5. CustomFolderManager
**Purpose:** Multi-folder configuration and management

**Key Methods:**
- `addFolder(_ folder: CustomFolder)`
- `removeFolder(_ folder: CustomFolder)`
- `updateFolder(_ folder: CustomFolder)`
- `getFolders() -> [CustomFolder]`

**Supported Folders:**
- Desktop, Downloads, Documents, Pictures, Music
- Custom user-selected folders
- Per-folder enable/disable state
- Individual bookmark management

---

##### 6. RuleService
**Purpose:** Rule CRUD operations

**Key Methods:**
- `createRule(_ rule: Rule) throws`
- `updateRule(_ rule: Rule) throws`
- `deleteRule(_ rule: Rule) throws`
- `getActiveRules() -> [Rule]`
- `toggleRule(_ rule: Rule) throws`

**Rule Validation:**
- Ensures valid condition/action types
- Validates destination paths
- Prevents duplicate rules
- Checks for conflicting rules

---

##### 7. UndoCommand (Protocol-Based)
**Purpose:** Undo/redo system for file operations

**Commands:**
- `MoveFileCommand` - Single file move
- `SkipFileCommand` - Mark file as skipped
- `BulkMoveCommand` - Batch file operations

**Command Pattern:**
```swift
protocol UndoableCommand {
    var id: UUID { get }
    var timestamp: Date { get }
    func execute(context: ModelContext?) async throws
    func undo(context: ModelContext?) throws
    var description: String { get }
}
```

**Storage:**
- Stores lightweight deltas (IDs and paths, not full objects)
- Supports file path changes
- Restores original status and suggestions

---

##### 8. NotificationService
**Purpose:** User notification system

**Key Methods:**
- `sendNotification(title:, body:)`
- `requestAuthorization()`
- `schedulePendingNotification()`

**Notification Types:**
- File organization complete
- Rule suggestions available
- Scan finished
- Error alerts

---

##### 9. ContextDetectionService ✅ Enhanced
**Purpose:** AI-powered project detection and file relationship analysis

**Key Methods:**
- `detectProjects(from files: [FileItem]) -> [ProjectCluster]`
- `detectByPrefix(_ files:) -> [ProjectCluster]` — Common naming prefixes (e.g., "ClientABC_")
- `detectByPattern(_ files:) -> [ProjectCluster]` — Regex patterns (JIRA-123, P-1024, dates)
- `detectByTiming(_ files:) -> [ProjectCluster]` — Temporal clustering of related files

**Detection Features:**
- **Prefix Detection:** Groups files with common prefixes (before `_`, `-`, or space)
- **Pattern Matching:** Regex patterns for tickets, project codes, dates
- **Temporal Clustering:** Files modified within sessions grouped together
- **ClusterType enum:** `.projectCode`, `.temporal`, `.nameSimilarity`, `.dateStamp`

**ProjectCluster Model:**
```swift
@Model class ProjectCluster {
    var projectName: String
    var suggestedFolderName: String
    var files: [String]            // File paths
    var clusterType: ClusterType
    var confidence: Double
}
```

---

##### 10. LearningService ✅ Enhanced
**Purpose:** AI-powered pattern learning from user behavior with multi-condition support

**Key Methods:**
- `recordUserAction(_ file:, action:, destination:)` — Records approvals/rejections
- `learnPatterns() -> [LearnedPattern]` — Analyzes history to find patterns
- `learnTemporalPatterns() -> [LearnedPattern]` — Detects time-based behaviors
- `learnNegativePatterns() -> [LearnedPattern]` — Anti-patterns from rejections
- `suggestRulesFromPatterns() -> [Rule]` — Generates rules from learned patterns

**Pattern Condition Types:**
```swift
enum PatternCondition: Codable, Hashable {
    case fileExtension(String)
    case nameContains(String)
    case namePrefix(String)
    case sizeGreaterThan(Int64)
    case sizeLessThan(Int64)
    case sourceFolder(String)
    case dayOfWeek(Int)
    case timeOfDay(hour: Int, minute: Int)
}
```

**Temporal Pattern Detection:**
- **Work hours detection:** Patterns during 9-5 vs. evening/weekend
- **Day-of-week analysis:** Weekly file organization habits
- **Session clustering:** Groups of actions within time windows

**Negative Pattern Learning:**
- Tracks rejected suggestions to avoid repeating mistakes
- Anti-pattern confidence increases with repeated rejections
- Prevents suggesting rules that contradict user preferences

**Learning Mechanisms:**
- Tracks manual file moves
- Identifies naming patterns
- Suggests rules based on history
- Adapts to user preferences

---

##### 11. InsightsService
**Purpose:** Analytics and insights generation

**Key Methods:**
- `getStorageBreakdown() -> StorageInsight`
- `getOrganizationPatterns() -> [OrganizationInsight]`
- `getProductivityInsights() -> [ProductivityInsight]`

**Insights Types:**
- Storage by category (Documents, Images, etc.)
- Most organized folders
- File organization velocity
- Time saved estimates

---

##### 12. AnalyticsService
**Purpose:** Storage trending, health scoring, and report generation

**Concurrency Model:**
- **Detached Tasks:** All heavy aggregation (snapshots, trends) runs on detached background tasks to avoid main thread blocking.
- **ModelContainer:** Accepts `ModelContainer` to create isolated `ModelContext`s for background work.

**Key Methods:**
- `recordDailySnapshotIfNeeded(container:)` — Background daily snapshot
- `loadAnalyticsSummary(for:container:)` — Aggregates trends, usage, and health
- `generateProductivityHealthReport(for:container:)` — Full report generation

---

##### 13. ThumbnailService
**Purpose:** File preview and thumbnail generation

**Security:** Uses security-scoped bookmark access for QuickLook thumbnail generation

**Key Methods:**
- `generateThumbnail(for: URL) async -> NSImage?`
- `getCachedThumbnail(for: String) -> NSImage?`
- `clearThumbnailCache()`

**Thumbnail Generation:**
- QuickLook integration for previews (requires security-scoped access)
- Image file thumbnail caching
- Document preview generation
- Fallback to file type icons

---

##### 14. StorageService
**Purpose:** Storage analytics and disk usage

**Key Methods:**
- `calculateFolderSize(_ url: URL) -> Int64`
- `getStorageBreakdown() -> StorageBreakdown`
- `getDiskSpace() -> DiskSpace`

**Analytics:**
- Per-folder size calculation
- File type distribution
- Storage trends over time
- Cleanup recommendations

---

##### 15. DuplicateDetectionService ✅ Enhanced
**Purpose:** AI-powered duplicate detection with version series and near-duplicate support

**Security:** Uses security-scoped bookmark access for file content reading (SHA-256 hashing)

**Key Methods:**
- `detectDuplicates(in files: [FileItem]) -> [DuplicateGroup]` — Main detection entry point
- `detectExactDuplicates(_ files:) -> [DuplicateGroup]` — SHA-256 hash matching
- `detectVersionSeries(_ files:) -> [DuplicateGroup]` — Finds v1, v2, FINAL variants
- `detectNearDuplicates(_ files:) -> [DuplicateGroup]` — Levenshtein similarity analysis
- `calculateSHA256(_ url:) -> String?` — File hash computation (security-scoped)
- `levenshteinDistance(_ s1:, _ s2:) -> Int` — String similarity metric

**Duplicate Types:**
```swift
enum DuplicateType {
    case exactDuplicate    // Identical file content (SHA-256 match)
    case versionSeries     // Same file with version markers (v1, FINAL, etc.)
    case nearDuplicate     // Similar filenames (Levenshtein distance < threshold)
}
```

**DuplicateGroup Model:**
```swift
struct DuplicateGroup: Identifiable {
    let id: UUID
    let files: [FileItem]
    let type: DuplicateType
    let description: String
    let potentialSpaceSavings: Int64
    let suggestedAction: SuggestedAction  // .keepNewest, .keepLargest, .review
}
```

**Detection Features:**
- **Exact Matching:** SHA-256 hash comparison for identical content
- **Version Series:** Regex patterns for version markers (v1, v2, FINAL, copy, backup)
- **Near Duplicates:** Levenshtein distance < 3 characters difference
- **Space Savings:** Calculates potential disk savings per group
- **Smart Suggestions:** Recommends which file to keep based on recency/size

---

##### 16. ContentSearchService
**Purpose:** Search file contents using Spotlight metadata and direct file reading

**Security:** Uses security-scoped bookmark access for reading text file contents

**Key Methods:**
- `search(query: String, in files: [FileItem]) async -> [SearchResult]` — Main search entry point
- `cancelSearch()` — Cancel current search operation
- `result(for: FileItem) -> SearchResult?` — Lookup result for specific file
- `hasMatch(for: FileItem) -> Bool` — Quick check for match existence

**Search Types:**
```swift
enum MatchType: Equatable, Hashable {
    case filename    // Matched in filename only
    case content     // Matched in file content only
    case both        // Matched in both filename and content
}
```

**Search Features:**
- **Filename Matching:** Case-insensitive substring matching
- **Content Matching:** Direct text file reading (security-scoped)
- **Progress Tracking:** Published search state with progress (0.0 to 1.0)
- **Cancellation:** Supports cancelling long-running searches
- **Snippet Generation:** Creates context snippets around matches

**Searchable File Types:**
- Plain text: txt, md, csv, json, xml, yaml
- Code files: swift, py, js, ts, html, css, java, c, cpp
- Documents: pdf, doc, docx, xls, xlsx (via Spotlight)

---

##### 17. FileScanPipeline
**Purpose:** Optimized file scanning pipeline

**Key Methods:**
- `scanWithProgress(url: URL, progress: (Double) -> Void) async -> [FileItem]`
- `cancelScan()`

**Features:**
- Batch processing
- Progress reporting
- Cancellation support
- Background scanning

---

##### 18. FileOperationCoordinator
**Purpose:** Coordinates complex multi-file operations

**Key Methods:**
- `coordinateBatchMove(_ files:) async -> [MoveResult]`
- `handleConflicts(_ conflicts:) async -> ConflictResolution`

**Coordination:**
- Batch operation sequencing
- Conflict resolution
- Error recovery
- Progress aggregation

---

##### 19. FileGroupingService
**Purpose:** Intelligent file grouping and clustering

**Key Methods:**
- `groupByProject(_ files:) -> [ProjectCluster]`
- `groupByDate(_ files:) -> [DateGroup]`
- `groupByType(_ files:) -> [TypeGroup]`

**Grouping Strategies:**
- Project detection (shared naming patterns)
- Temporal grouping (creation date)
- Type-based categorization
- Relationship analysis

---

### Model Layer

SwiftData models and supporting types define the data structure.

#### Core Models

##### 1. FileItem
**Purpose:** Represents a file with organization metadata

```swift
@Model
final class FileItem {
    @Attribute(.unique) var path: String
    var name: String
    var fileExtension: String
    var size: Int64
    var createdAt: Date
    var modifiedAt: Date
    var suggestedDestination: String?
    var status: OrganizationStatus
    var category: FileCategory

    enum OrganizationStatus: String, Codable {
        case pending       // No rule matched
        case ready         // Has suggestion
        case completed     // Already moved
        case skipped       // User skipped
        case inProgress    // Currently moving
    }

    enum FileCategory: String, Codable {
        case document, image, video, audio, archive, other
    }
}
```

---

##### 2. Rule
**Purpose:** Organization rule definition

```swift
@Model
final class Rule {
    var name: String
    var conditionType: ConditionType
    var conditionValue: String
    var actionType: ActionType
    var destinationFolder: String
    var isEnabled: Bool
    var priority: Int
    var createdAt: Date

    enum ConditionType: String, Codable {
        case fileExtension
        case nameContains
        case nameMatches
        case sizeGreaterThan
        case olderThan
        case createdAfter
    }

    enum ActionType: String, Codable {
        case move
        case copy
        case tag
    }
}
```

---

##### 3. OrganizationTemplate
**Purpose:** Pre-built organization system definitions

```swift
enum OrganizationTemplate: String, Codable, CaseIterable {
    case para              // Projects, Areas, Resources, Archives
    case johnnyDecimal     // Decimal categorization system
    case creativeProf      // Project-based for designers
    case minimal           // Simple shallow hierarchy
    case academic          // Research and study organization
    case chronological     // Date-based archives
    case student           // Course and assignment organization
    case custom            // User-defined

    var displayName: String
    var description: String
    var targetPersona: String
    var iconName: String
    var folderStructure: [String]

    func generateRules(baseDocumentsPath: String) -> [Rule]
}
```

See [OrganizationTemplates.md](../Features/OrganizationTemplates.md) for complete template documentation.

---

##### 4. OrganizationPersonality
**Purpose:** User's organizational style profile

```swift
struct OrganizationPersonality: Codable, Equatable {
    var organizationStyle: OrganizationStyle   // Piler or Filer
    var thinkingStyle: ThinkingStyle           // Visual or Hierarchical
    var mentalModel: MentalModel               // Project/Time/Topic-Based

    // Computed preferences
    var suggestedTemplate: OrganizationTemplate
    var suggestedFolderDepth: Int
    var preferredViewMode: String              // "grid" or "list"
    var suggestionsFrequency: SuggestionsFrequency

    enum OrganizationStyle: String, Codable {
        case piler  // Visual, surface-level
        case filer  // Structured, hierarchical
    }

    enum ThinkingStyle: String, Codable {
        case visual        // Everything visible
        case hierarchical  // Nested structures
    }

    enum MentalModel: String, Codable {
        case projectBased
        case timeBased
        case topicBased
    }
}
```

See [PersonalitySystem.md](../Features/PersonalitySystem.md) for complete personality documentation.

---

##### 5. ProjectCluster
**Purpose:** Related files grouped as a project

```swift
@Model
final class ProjectCluster {
    var name: String
    var files: [FileItem]
    var detectedAt: Date
    var confidence: Double
    var suggestedDestination: String?

    // Detection signals
    var commonPrefix: String?
    var dateRange: DateInterval?
    var sharedKeywords: [String]
}
```

**Project Detection:**
- Shared naming patterns ("ProjectX_design", "ProjectX_draft")
- Temporal proximity (files created within days)
- Keyword analysis
- File type relationships (PSD + PNG + PDF)

---

##### 6. LearnedPattern ✅ Enhanced
**Purpose:** AI-discovered organization patterns with multi-condition support

```swift
@Model
final class LearnedPattern {
    var id: UUID
    var conditions: [PatternCondition]  // Multi-condition support
    var destination: String
    var confidence: Double
    var occurrences: Int
    var lastSeen: Date
    var isActive: Bool
    var isNegative: Bool                 // Anti-pattern from rejections
    var patternType: PatternType         // .extension, .temporal, .compound, .negative
}

enum PatternCondition: Codable, Hashable {
    case fileExtension(String)
    case nameContains(String)
    case namePrefix(String)
    case sizeGreaterThan(Int64)
    case sizeLessThan(Int64)
    case sourceFolder(String)
    case dayOfWeek(Int)
    case timeOfDay(hour: Int, minute: Int)
}
```

**Pattern Learning:**
- User manually moves files matching pattern
- System detects pattern after N occurrences
- Multi-condition patterns for complex behaviors
- Temporal patterns detect time-based habits
- Negative patterns prevent repeated mistakes
- Suggests rule creation with confidence scoring

---

##### 7. ActivityItem
**Purpose:** Activity feed timeline entry

```swift
@Model
final class ActivityItem {
    var timestamp: Date
    var type: ActivityType
    var description: String
    var fileCount: Int
    var isUndoable: Bool

    enum ActivityType: String, Codable {
        case filesMoved
        case rulesApplied
        case templateApplied
        case folderScanned
        case filesSkipped
    }
}
```

**Activity Feed:**
- Real-time operation tracking
- Undo support for recent operations
- Filterable timeline
- Persistent history

---

##### 8. CustomFolder
**Purpose:** User-configured source folder

```swift
@Model
final class CustomFolder {
    var name: String
    var path: String
    var isEnabled: Bool
    var bookmarkKey: String
    var addedAt: Date
    var lastScanned: Date?

    // Predefined folders
    static let desktop: CustomFolder
    static let downloads: CustomFolder
    static let documents: CustomFolder
    static let pictures: CustomFolder
    static let music: CustomFolder
}
```

---

##### 9. BookmarkMigrationState
**Purpose:** Tracks bookmark migration status

```swift
struct BookmarkMigrationState: Codable {
    var hasAttemptedMigration: Bool
    var migratedBookmarks: [String]
    var failedBookmarks: [String]
    var migrationDate: Date?
}
```

---

## Component Relationships

### Views → ViewModel

**ReviewView** observes **ReviewViewModel**:
```swift
@ObservedObject var viewModel: ReviewViewModel

// View updates automatically when viewModel publishes changes
viewModel.files        → Drives file list UI
viewModel.loadingState → Shows loading spinner
viewModel.errorMessage → Displays error banner
```

**Interaction:**
```
User clicks "Organize" → ReviewView calls viewModel.moveFile()
                      → ViewModel updates @Published properties
                      → View auto-refreshes via Combine
```

### ViewModel → Services

**ReviewViewModel** orchestrates three services:

1. **FileSystemService**: Scans Desktop folder
   ```swift
   let files = try await fileSystemService.scanDesktop()
   ```

2. **RuleEngine**: Evaluates files against rules
   ```swift
   let evaluatedFiles = ruleEngine.evaluateFiles(files, rules: rules)
   ```

3. **FileOperationsService**: Moves files to destinations
   ```swift
   let result = try await fileOperationsService.moveFile(file)
   ```

### Services → Models

Services operate on model objects:

**FileSystemService** creates **FileItem** models:
```swift
let fileItem = FileItem(
    name: filename,
    path: filepath,
    fileExtension: extension,
    // ... other properties
)
```

**RuleEngine** reads **Rule** models:
```swift
func evaluateFile(_ file: FileItem, rules: [Rule]) -> FileItem {
    // Match file against rule conditions
}
```

### Models → SwiftData

**FileItem** and **Rule** are persisted:
```swift
@Model
final class FileItem {
    @Attribute(.unique) var path: String
    var status: FileStatus
    // ... other properties
}

// ViewModel inserts/updates via ModelContext
context.insert(fileItem)
try? context.save()
```

---

## Data Flow

### 1. Scan & Match Flow

```
User clicks "Scan & Review"
    │
    ▼
ReviewView calls viewModel.scanDesktop()
    │
    ▼
ReviewViewModel.scanDesktop() async {
    │
    ├─► FileSystemService.scanDesktop()
    │       │
    │       ├─► Check for saved Desktop bookmark
    │       ├─► Request access if needed (NSOpenPanel)
    │       ├─► Start security-scoped access
    │       ├─► Scan directory with FileManager
    │       ├─► Create FileItem models
    │       └─► Return [FileItem]
    │
    ├─► Fetch active Rules from SwiftData
    │
    ├─► RuleEngine.evaluateFiles(files, rules)
    │       │
    │       └─► For each file:
    │               ├─► Check against each rule
    │               ├─► Set suggestedDestination if match
    │               └─► Set status (.ready or .pending)
    │
    ├─► Update viewModel.files (triggers UI update)
    │
    └─► Save FileItems to SwiftData
}
    │
    ▼
ReviewView displays file list with suggestions
```

### 2. Move File Flow

```
User clicks checkmark on file
    │
    ▼
ReviewView calls viewModel.moveFile(fileItem)
    │
    ▼
ReviewViewModel.moveFile(fileItem) async {
    │
    ├─► FileOperationsService.moveFile(fileItem)
    │       │
    │       ├─► Parse destination path
    │       │   Example: "Documents/Finance/Invoices"
    │       │   → topLevel: "Documents"
    │       │   → subPath: "Finance/Invoices"
    │       │
    │       ├─► ensureDestinationAccess("Documents")
    │       │       │
    │       │       ├─► Check for saved bookmark
    │       │       ├─► If none, requestDestinationAccess()
    │       │       │       │
    │       │       │       ├─► NSOpenPanel with message
    │       │       │       ├─► Validate folder selection
    │       │       │       ├─► Save security-scoped bookmark
    │       │       │       └─► Return URL
    │       │       │
    │       │       └─► Return resolved URL
    │       │
    │       ├─► Start security-scoped access
    │       ├─► Create subdirectories if needed
    │       ├─► Check for conflicts
    │       ├─► FileManager.moveItem()
    │       └─► Stop security-scoped access
    │
    ├─► Update fileItem.status = .completed
    ├─► Remove from viewModel.files (triggers UI update)
    └─► Show success message
}
    │
    ▼
ReviewView removes file from list with animation
```

### 3. Batch Move Flow

```
User clicks "Organize All"
    │
    ▼
ReviewViewModel.moveAllFiles() async {
    │
    ├─► Filter files with suggestions
    ├─► FileOperationsService.moveFiles(filesToMove)
    │       │
    │       └─► For each file:
    │               ├─► moveFile(file) [reuses single flow]
    │               ├─► Collect MoveResult
    │               └─► Continue on error
    │
    ├─► Count successes vs failures
    ├─► Update UI for successful moves
    └─► Show summary message
}
```

---

## State Management

### ViewModel State

**ReviewViewModel** manages application state:

```swift
@Published var files: [FileItem] = []
@Published var loadingState: LoadingState = .idle
@Published var errorMessage: String?
@Published var successMessage: String?

enum LoadingState {
    case idle      // Nothing happening
    case loading   // Scanning in progress
    case loaded    // Scan complete
    case error     // Scan failed
}
```

### State Transitions

```
App Launch
    │
    ▼
.idle → User clicks "Scan"
    │
    ▼
.loading (spinner shows)
    │
    ├─► Success → .loaded (files display)
    │
    └─► Failure → .error (error banner shows)
        │
        └─► User clicks "Try Again" → .loading
```

### SwiftData Persistence

**Models persist across app launches:**

```swift
@Model
final class FileItem {
    var status: FileStatus

    enum FileStatus: String, Codable {
        case pending   // No rule matched
        case ready     // Has suggestion
        case completed // Already moved
        case skipped   // User skipped
    }
}

// Status persists in SwiftData
// On app restart, completed files don't reappear
```

### Bookmark Persistence

**UserDefaults stores security-scoped bookmarks:**

```swift
// Desktop bookmark
UserDefaults.standard.set(bookmarkData, forKey: "DesktopFolderBookmark")

// Destination bookmarks (keyed by folder name)
UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_Documents")
UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_Pictures")
```

**Bookmark Lifecycle:**
```
First access → User selects folder → Bookmark saved
Next access → Bookmark loaded → No prompt needed
Stale/Invalid → User prompted again → New bookmark saved
```

---

## Permission System

### Security-Scoped Bookmark Architecture

Forma uses **security-scoped bookmarks** instead of Full Disk Access for:
- Better user experience (works from Xcode)
- More granular permissions (only selected folders)
- Easier revocation (reset button)

### Two-Tier Permission Model

**Tier 1: Source Folder (Desktop)**
```
Purpose: Read files to organize
When: First app launch or after reset
How: NSOpenPanel pre-selects ~/Desktop
Storage: UserDefaults key "DesktopFolderBookmark"
Lifetime: Permanent until reset
```

**Tier 2: Destination Folders (Documents, Pictures, etc.)**
```
Purpose: Write organized files
When: First time moving to each folder
How: NSOpenPanel requests specific folder
Storage: UserDefaults key "DestinationFolderBookmark_[FolderName]"
Lifetime: Permanent until reset
Validation: Folder name must match requested
```

### Permission Flow

```
┌─────────────────────────────────────────────────────────┐
│  App Launch                                             │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Check Desktop Bookmark                                 │
│  ├─ Found + Valid → Use it                              │
│  └─ Missing/Stale → Request access                      │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  NSOpenPanel: "Grant access to Desktop"                 │
│  User selects ~/Desktop                                 │
│  Save security-scoped bookmark                          │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Start Security-Scoped Access                           │
│  url.startAccessingSecurityScopedResource()             │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Scan Files                                             │
│  (Read permission active)                               │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stop Security-Scoped Access                            │
│  url.stopAccessingSecurityScopedResource()              │
└─────────────────────────────────────────────────────────┘

                        (Later...)

┌─────────────────────────────────────────────────────────┐
│  User Moves File to "Documents/Finance"                 │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Check Documents Bookmark                               │
│  ├─ Found → Use it                                      │
│  └─ Missing → Request access                            │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  NSOpenPanel: "Select your Documents folder"           │
│  User selects ~/Documents                               │
│  Validate: folder name = "Documents" ✓                  │
│  Save bookmark                                          │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Start Security-Scoped Access                           │
│  Create "Finance" subdirectory if needed                │
│  Move file                                              │
│  Stop Security-Scoped Access                            │
└─────────────────────────────────────────────────────────┘
```

### Folder Validation

**Why Validation Matters:**
Prevents users from accidentally granting wrong permissions.

**Validation Logic:**
```swift
let selectedFolder = selectedURL.lastPathComponent
let requestedFolder = folderName

if selectedFolder.lowercased() != requestedFolder.lowercased() {
    // Show error: "You selected 'Downloads' but Forma needs 'Documents'"
    throw FileOperationError.operationFailed("Wrong folder")
}

// ✅ Validation passed
```

**User Experience:**
```
Request: "Please select your Documents folder"
User selects: ~/Downloads
Result: ❌ Error alert with explanation
        → "Try Again" button

User selects: ~/Documents
Result: ✅ Bookmark saved, file moves
```

---

## Feature Architecture

### Organization Templates

**8 pre-built templates** that generate rules and folder structures automatically.

#### Template System Flow

```
User selects template → Template.generateRules() → RuleService creates rules
                                                  ↓
                                        Rules applied to files
                                                  ↓
                                        Suggestions appear in UI
```

#### Template Components

| Component | Role |
|-----------|------|
| `OrganizationTemplate` | Enum with 8 templates |
| `OrganizationTemplate+Rules.swift` | Rule generation methods |
| `RuleService` | Persists generated rules |
| `TemplateSelectionView` | UI for template picker |

#### Templates Overview

| Template | Rules Generated | Folder Depth | Target User |
|----------|----------------|--------------|-------------|
| PARA | 10 rules | 2-3 levels | Knowledge workers |
| Johnny Decimal | 13 rules | 3-4 levels | Systematic organizers |
| Creative Professional | 11 rules | 3 levels | Designers, creatives |
| Minimal | 7 rules | 1-2 levels | Pilers, simple systems |
| Academic & Research | 14 rules | 3-4 levels | Students, researchers |
| Chronological | 7 rules | 2-3 levels | Archival, time-based |
| Student | 14 rules | 3 levels | Students, coursework |
| Custom | 0 rules | User-defined | Advanced users |

See [OrganizationTemplates.md](../Features/OrganizationTemplates.md) for detailed documentation.

---

### Personality System

**Adaptive intelligence** that customizes Forma based on how users naturally organize.

#### Personality Architecture

```
PersonalityQuizView (3 questions)
        ↓
calculatePersonality()
        ↓
OrganizationPersonality (3 dimensions)
        ↓
Computed Properties:
  - suggestedTemplate
  - preferredViewMode
  - suggestedFolderDepth
  - suggestionsFrequency
        ↓
DashboardViewModel applies preferences
```

#### Personality Dimensions

**3-dimensional profile:**

1. **OrganizationStyle**: Piler (visual) vs Filer (hierarchical)
2. **ThinkingStyle**: Visual (flat) vs Hierarchical (nested)
3. **MentalModel**: Project-Based vs Time-Based vs Topic-Based

#### Personality → System Adaptations

| Personality | Template | View Mode | Folder Depth |
|-------------|----------|-----------|--------------|
| Piler + Visual + Project | Minimal | Grid | 2 |
| Filer + Hierarchical + Topic | Johnny Decimal | List | 5 |
| Filer + Visual + Project | Creative Prof | List | 3 |
| Filer + Hierarchical + Time | Chronological | List | 3 |

#### Integration Points

- **OnboardingFlowView**: Quiz is Step 3 of 5
- **TemplateSelectionView**: Pre-selects `personality.suggestedTemplate`
- **FilterViewModel**: Applies `personality.preferredViewMode`
- **RuleSuggestionService**: Adjusts frequency based on `suggestionsFrequency`

See [PersonalitySystem.md](../Features/PersonalitySystem.md) for detailed documentation.

---

### Project Clustering

**Intelligent detection** of related files that belong together.

#### Clustering Architecture

```
FileGroupingService.groupByProject(files)
        ↓
Analyze naming patterns, dates, types
        ↓
Create ProjectCluster models
        ↓
Suggest destination folder
        ↓
ProjectClusterView displays groups
```

#### Detection Signals

| Signal | Example | Weight |
|--------|---------|--------|
| **Common Prefix** | "Website_design.psd", "Website_logo.png" | High |
| **Temporal Proximity** | Files created within 3 days | Medium |
| **Shared Keywords** | "proposal", "draft", "final" in names | Medium |
| **Type Relationships** | PSD + PNG + PDF (design workflow) | Low |

#### Clustering Flow

1. User scans folder with 100 files
2. `FileGroupingService` detects 3 project clusters
3. Clusters appear in **ProjectClusterView**
4. User can:
   - Accept suggested destination
   - Modify destination
   - Ungroup files
   - Create rule from pattern

#### Model Structure

```swift
ProjectCluster {
    name: "Website Redesign Project"
    files: [FileItem] (15 files)
    confidence: 0.85
    suggestedDestination: "Documents/Projects/Website Redesign"
    commonPrefix: "Website_"
    dateRange: 2024-11-15 to 2024-11-18
    sharedKeywords: ["website", "redesign", "mockup"]
}
```

---

### Dashboard Architecture

**Three-panel layout** is the primary interface.

#### Layout Structure

```
┌──────────────────────────────────────────────────────────┐
│                    DashboardView                         │
├──────────┬────────────────────────────┬──────────────────┤
│          │                            │                  │
│ Sidebar  │      MainContentView       │   RightPanel     │
│          │                            │                  │
│ - Folders│ ┌────────────────────────┐ │ Context-aware:   │
│ - Filters│ │  FilterTabBar          │ │                  │
│ - Activity│└────────────────────────┘ │ - FileInspector  │
│          │                            │ - RuleBuilder    │
│          │ ┌────────────────────────┐ │ - Insights       │
│          │ │                        │ │ - ProjectCluster │
│          │ │   File List            │ │                  │
│          │ │   (Grid or List)       │ │                  │
│          │ │                        │ │                  │
│          │ └────────────────────────┘ │                  │
│          │                            │                  │
│          │ ┌────────────────────────┐ │                  │
│          │ │  FloatingActionBar     │ │                  │
│          │ └────────────────────────┘ │                  │
└──────────┴────────────────────────────┴──────────────────┘
```

#### Panel Responsibilities

**Sidebar (Left):**
- Folder navigation (Desktop, Downloads, etc.)
- Filter tabs (All, Ready, Pending, Skipped)
- Activity feed (Recent operations)
- Storage analytics

**MainContent (Center):**
- FilterTabBar for file categorization
- File list (Grid or List view)
- FloatingActionBar for bulk actions
- Selection controls

**RightPanel (Context-Aware):**
- **No selection**: Dashboard overview, insights
- **Single file selected**: FileInspectorView
- **Multiple files selected**: Bulk actions, rule builder
- **Project cluster**: ProjectClusterView

#### View Mode Switching

```swift
// DashboardViewModel
@Published var viewMode: ViewMode = .list

enum ViewMode {
    case grid   // Visual grid layout
    case list   // Detailed list with metadata
}

// Personality-aware default:
let personality = OrganizationPersonality.load()
viewMode = personality?.preferredViewMode == "grid" ? .grid : .list
```

---

### Activity Feed

**Real-time timeline** of file operations with undo support.

#### Activity Architecture

```
File Operation
        ↓
ActivityItem created
        ↓
Saved to SwiftData
        ↓
DashboardViewModel.activityItems updated
        ↓
Sidebar ActivityFeed displays item
        ↓
User can click "Undo" (if isUndoable)
```

#### ActivityItem Types

| Type | Description | Undoable? |
|------|-------------|-----------|
| `filesMoved` | Files organized to destination | ✅ Yes |
| `rulesApplied` | Template rules applied | ❌ No |
| `templateApplied` | Organization template selected | ❌ No |
| `folderScanned` | Folder scanned for files | ❌ No |
| `filesSkipped` | Files marked as skipped | ✅ Yes |

#### Undo System Integration

Activity feed items link to `UndoCommand` instances:

```swift
ActivityItem {
    type: .filesMoved
    description: "Moved 5 invoices to Documents/Finance"
    fileCount: 5
    isUndoable: true
}

// Associated UndoCommand
BulkMoveCommand {
    operations: [(fileID, fromPath, toPath, originalStatus), ...]
}
```

User clicks "Undo" → `BulkMoveCommand.undo()` → Files restored → ActivityItem updated

---

### Insights & Analytics

**Dashboard intelligence** providing organization insights.

#### Insights Architecture

```
InsightsService
        ↓
Analyzes FileItem history
        ↓
Generates insights:
  - Storage breakdown
  - Organization patterns
  - Productivity metrics
        ↓
RightPanel displays insights
```

#### Insight Types

**1. Storage Insights**
```swift
StorageInsight {
    category: .documents
    sizeBytes: 12_500_000_000  // 12.5 GB
    fileCount: 3,482
    percentage: 35.2
}
```

**2. Organization Insights**
```swift
OrganizationInsight {
    pattern: "Most active in Documents/Finance"
    frequency: .daily
    lastOccurrence: Date()
}
```

**3. Productivity Insights**
```swift
ProductivityInsight {
    metric: "Time saved this week"
    value: "2.5 hours"
    calculation: filesOrganized × avgTimePerFile
}
```

#### Visualization Components

- **StorageChart**: Pie chart of storage by category
- **OrganizationHeatmap**: Most organized folders
- **ProductivityTrend**: Organization velocity over time

---

### Undo/Redo System

**Command pattern** for reversible file operations.

#### Command Architecture

```
File Operation
        ↓
Create UndoableCommand
        ↓
Execute command
        ↓
Store command in history
        ↓
User clicks "Undo"
        ↓
command.undo(context)
```

#### Command Types

**MoveFileCommand:**
```swift
let command = MoveFileCommand(
    id: UUID(),
    timestamp: Date(),
    fileID: file.path,
    fromPath: "/Users/me/Desktop/invoice.pdf",
    toPath: "/Users/me/Documents/Finance/invoice.pdf",
    originalStatus: .ready,
    suggestedDestination: "Documents/Finance"
)
```

**Undo flow:**
```swift
func undo(context: ModelContext?) throws {
    // Move file back
    FileManager.moveItem(from: toPath, to: fromPath)

    // Restore FileItem state
    file.status = originalStatus
    file.suggestedDestination = suggestedDestination

    context?.save()
}
```

#### Lightweight Storage

Commands store **only deltas**, not full objects:
- File ID (path)
- From/To paths
- Original status
- Suggested destination

This prevents memory bloat and stale data issues.

---

## Technology Stack

### Frameworks

**SwiftUI**
- Declarative UI framework
- Reactive updates via Combine
- Native macOS components

**SwiftData**
- Modern Core Data replacement
- Type-safe data persistence
- Automatic schema migration

**Combine**
- Reactive programming
- @Published property observers
- Async/await integration

**AppKit**
- Menu bar integration (NSStatusBar)
- File system dialogs (NSOpenPanel)
- Native macOS features

**Foundation**
- FileManager (file operations)
- URL (path handling)
- UserDefaults (bookmark storage)

### Development Tools

- **Xcode 15+**: IDE and compiler
- **Swift 5.9+**: Programming language
- **Git**: Version control

### Entitlements

Required for security-scoped bookmarks:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

---

## Design Patterns

### MVVM (Model-View-ViewModel)

**Model**: Data structures (FileItem, Rule)
```swift
@Model
final class FileItem {
    var name: String
    var path: String
    // ...
}
```

**View**: SwiftUI views (ReviewView, SettingsView)
```swift
struct ReviewView: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        // UI driven by viewModel state
    }
}
```

**ViewModel**: Business logic and state (ReviewViewModel)
```swift
@MainActor
class ReviewViewModel: ObservableObject {
    @Published var files: [FileItem] = []

    func scanDesktop() async {
        // Orchestrate services
    }
}
```

### Service Layer Pattern

Business logic isolated in dedicated services:

```swift
// FileSystemService: File scanning
// RuleEngine: Rule evaluation
// FileOperationsService: File moves

// ViewModel coordinates services:
let files = try await fileSystemService.scanDesktop()
let evaluated = ruleEngine.evaluateFiles(files, rules: rules)
let result = try await fileOperationsService.moveFile(file)
```

**Benefits:**
- Testable (mock services in tests)
- Reusable (services used by multiple ViewModels)
- Maintainable (changes isolated to service)

### Repository Pattern (via SwiftData)

**ModelContext** acts as repository:
```swift
// Insert
context.insert(fileItem)

// Query
let descriptor = FetchDescriptor<Rule>(
    predicate: #Predicate { $0.isEnabled }
)
let rules = try context.fetch(descriptor)

// Update (automatic tracking)
fileItem.status = .completed

// Save
try context.save()
```

### Error Handling Pattern

**Typed errors** for better debugging:

```swift
enum FileSystemError: LocalizedError {
    case permissionDenied
    case directoryNotFound
    case scanFailed(String)
    case userCancelled

    var errorDescription: String? {
        // User-friendly messages
    }
}

// Usage:
do {
    try await scanDesktop()
} catch let error as FileSystemError {
    errorMessage = error.localizedDescription
}
```

### Async/Await Pattern

**Modern concurrency** for file operations:

```swift
func scanDesktop() async throws -> [FileItem] {
    // Async work on background thread
    let files = try await fileSystemService.scanDesktop()

    // Return to main thread
    await MainActor.run {
        self.files = files
    }
}
```

### Security-Scoped Resource Pattern

**Proper lifecycle management:**

```swift
guard url.startAccessingSecurityScopedResource() else {
    throw error
}

defer {
    url.stopAccessingSecurityScopedResource()
}

// Do file operations
try fileManager.moveItem(at: source, to: destination)
```

---

## Future Architecture Considerations

### Custom Rule Builder

**New Components:**
```
RuleBuilderView → RuleBuilderViewModel → RuleValidationService
                                       → RuleService (CRUD)
```

### Background File Monitoring

**New Components:**
```
FileMonitorService (using FSEvents)
    │
    └─► Watches Desktop/Downloads
        └─► Notifies ReviewViewModel of changes
```

### Multi-Folder Support

**Architecture Change:**
```
Current:  Single Desktop scan
Future:   Multiple source folders (Desktop, Downloads, Documents)
          SourceFolderManager to coordinate multiple scans
```

### AI Rule Suggestions

**New Components:**
```
AIRuleSuggestionService
    │
    ├─► Analyzes file patterns
    ├─► Uses Core ML model
    └─► Suggests rules to ReviewViewModel
```

---

### Cloud Storage Integration (v2.0)

> **Full documentation:** [V2-Cloud-Storage-Integration.md](../Roadmap/V2-Cloud-Storage-Integration.md)

**New Service Layer:**
```
CloudStorageService (Coordinator)
    │
    ├─► LocalStorageProvider (refactored FileSystemService)
    ├─► iCloudDriveProvider (NSFileCoordinator-based)
    ├─► DropboxProvider (OAuth + REST API)
    ├─► GoogleDriveProvider (OAuth + REST API)
    └─► OneDriveProvider (Microsoft Graph API)
```

**Protocol Abstraction:**
```swift
protocol CloudStorageProtocol {
    var provider: CloudProvider { get }
    func scanDirectory(at path: String) async throws -> [CloudFileMetadata]
    func moveFile(from: String, to: String) async throws
    func downloadFile(at: String, to: URL) async throws
    func uploadFile(from: URL, to: String) async throws
}
```

**Model Extensions:**
```swift
// Extended Destination enum
enum Destination: Codable {
    case trash
    case folder(bookmark: Data, displayName: String)
    case cloudFolder(provider: CloudProvider, cloudPath: String, displayName: String)
}

// Cloud provider identification
enum CloudProvider: String, Codable {
    case local, iCloud, dropbox, googleDrive, oneDrive
}
```

**Key Architectural Decisions:**
- iCloud uses native `NSFileCoordinator` (no SDK needed)
- Third-party clouds use OAuth 2.0 with tokens stored in Keychain
- `SecureBookmarkStore` pattern extended for cloud auth tokens
- Cross-cloud moves go through local temp storage
- `UndoCommand` extended with `sourceProvider` and `destProvider`

**Integration Points:**
- `CustomFolder` gains optional `cloudProvider` property
- `Rule` model supports cloud destinations
- `DashboardViewModel.scanFiles()` aggregates from all providers
- `ActivityItem` tracks cloud operations

---

## Performance Considerations

### File Scanning

**Current:** Sequential scan of Desktop folder
**Optimization:** Batch processing for large directories

```swift
// Future: Paginated scanning
func scanDesktop(limit: Int = 100, offset: Int = 0) async throws -> [FileItem]
```

### Rule Evaluation

**Current:** O(n × m) where n = files, m = rules
**Optimization:** Early exit on first match

```swift
for rule in rules {
    if matches(file: file, rule: rule) {
        return updatedFile  // ✓ Stop checking other rules
    }
}
```

### SwiftData Queries

**Current:** Fetch all rules on each scan
**Optimization:** Cache active rules

```swift
private var cachedRules: [Rule]?

func getActiveRules() async throws -> [Rule] {
    if let cached = cachedRules { return cached }
    let rules = try context.fetch(descriptor)
    cachedRules = rules
    return rules
}
```

---

## Debugging & Logging

### Console Output

Forma logs key operations:

```
📂 Requesting access to: Documents
✅ Access granted to: /Users/username/Documents
✅ Folder validation passed: Documents matches Documents
✅ Bookmark saved for Documents
📁 Moving file: invoice.pdf
📂 From: /Users/username/Desktop
📂 To: /Users/username/Documents/Finance/Invoices
✅ File moved successfully
```

### Error States

```
❌ Permission denied for: /path/to/folder
⚠️ User selected wrong folder: Downloads instead of Documents
❌ Move failed: File not found
```

### Logging Locations

- **Xcode Console**: Real-time during development
- **System Console**: Released app logs
- **SwiftData**: Persistent error tracking (future)

---

## See Also

### Architecture
- [Dashboard Architecture](DASHBOARD.md) - Main interface component design
- [Right Panel Architecture](RIGHT_PANEL.md) - Contextual copilot panel
- [Component Architecture](ComponentArchitecture.md) - Reusable UI components
- [Rule Engine Architecture](RuleEngine-Architecture.md) - Rule evaluation system

### Audits & Analysis
- [Codebase Audit](../CODEBASE_AUDIT.md) - Full codebase review
- [Performance Audit](../PERFORMANCE_AUDIT.md) - Performance analysis
- [UX/UI Analysis](../UX-UI-ANALYSIS.md) - User experience review
- [Security Audits](../Security/README.md) - Security documentation

### Design & Features
- [Design System](../Design/DesignSystem.md) - Visual design tokens
- [Feature Documentation](../Features/README.md) - Feature specifications
- [Documentation Index](../INDEX.md) - Master navigation

---

**Document Version:** 2.1
**Last Updated:** 2026-01-06
**Architecture Updates:** ViewModel Coordinator Pattern, Modular Views (Onboarding/Settings), Shared Components
**Next Review:** After next major feature release
