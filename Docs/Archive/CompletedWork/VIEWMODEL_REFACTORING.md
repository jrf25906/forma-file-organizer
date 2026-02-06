# DashboardViewModel Refactoring

## Overview

The original `DashboardViewModel` (1,864 lines, 28+ @Published properties) has been split into 5 focused ViewModels, each with a single, well-defined responsibility.

## New Architecture

```
DashboardViewModel (Coordinator)
├── FileScanViewModel          (File discovery & scanning)
├── FilterViewModel             (Filtering, search, view modes)
├── SelectionViewModel          (Multi-select, keyboard nav)
├── AnalyticsDashboardViewModel (Storage analytics, insights)
└── BulkOperationViewModel      (Batch operations, progress)
```

## ViewModels

### 1. FileScanViewModel
**File:** `/Forma File Organizing/ViewModels/FileScanViewModel.swift`

**Responsibility:** File discovery and real-time scanning

**Properties:**
- `@Published allFiles: [FileItem]` - All discovered files
- `@Published recentFiles: [FileItem]` - Last 8 files by modification date
- `@Published isScanning: Bool` - Scan in progress
- `@Published scanProgress: Double` - Progress (0.0 to 1.0)
- `@Published customFolders: [CustomFolder]` - Custom scan locations
- `@Published errorMessage: String?` - Scan errors

**Key Methods:**
- `scanFiles(context:rules:) async` - Scan Desktop, Downloads, custom folders
- `refresh(context:rules:) async` - Re-scan all folders
- `updateFile(_:)` - Update single file metadata
- `removeFile(at:)` - Remove file from list (post-organization)
- `loadCustomFolders(from:)` - Load custom scan locations from SwiftData

**Dependencies:**
- `FileSystemServiceProtocol` - File system access
- `FileScanPipelineProtocol` - Scanning pipeline
- `RuleEngine` - Rule evaluation

---

### 2. FilterViewModel
**File:** `/Forma File Organizing/ViewModels/FilterViewModel.swift`

**Responsibility:** Filtering, search, category selection, view modes

**Properties:**
- `@Published filteredFiles: [FileItem]` - Filtered results
- `@Published selectedCategory: FileTypeCategory` - Current category (All, Documents, Images, etc.)
- `@Published selectedFolder: FolderLocation` - Current folder (Home, Desktop, Downloads, etc.)
- `@Published searchText: String` - Search query
- `@Published selectedSecondaryFilter: SecondaryFilter` - Large Files, Recent, etc.
- `@Published reviewFilterMode: ReviewFilterMode` - Needs Review vs All
- `@Published groupingMode: FileGroupingService.GroupingMode` - Date, Type, etc.
- `@Published currentViewMode: ViewMode` - Card, List, or Grid
- Cached computed properties for performance

**Key Methods:**
- `updateSourceFiles(_:)` - Update source files and re-filter
- `applyFilterImmediately()` - Apply filters without debouncing
- `clearAllFilters()` - Reset all filters atomically
- `setViewMode(_:)` - Set view mode and persist preference
- `setContentMatchedPaths(_:)` - Update content search matches

**Dependencies:**
- `FileFilterManager` - Core filtering logic (existing coordinator)
- `@AppStorage` - View mode persistence

---

### 3. SelectionViewModel
**File:** `/Forma File Organizing/ViewModels/SelectionViewModel.swift`

**Responsibility:** Multi-select operations and keyboard navigation

**Properties:**
- `@Published selectedFileIDs: Set<String>` - Selected file paths
- `@Published isSelectionMode: Bool` - One or more files selected
- `@Published focusedFilePath: String?` - Keyboard-focused file
- `@Published isKeyboardNavigating: Bool` - Arrow keys active

**Key Methods:**
- `toggleSelection(for:)` - Toggle file selection
- `selectAll(visibleFiles:)` - Select all visible files
- `deselectAll()` - Clear selection
- `selectRange(from:to:in:)` - Shift+Click range selection
- `isSelected(_:)` - Check if file is selected
- `getSelectedFiles(from:)` - Get FileItem objects for selected IDs
- `focusNextFile(in:)` - Down Arrow
- `focusPreviousFile(in:)` - Up Arrow
- `getFocusedFile(in:)` - Get focused FileItem

**Dependencies:**
- `SelectionManager` - Core selection logic (existing coordinator)

---

### 4. AnalyticsDashboardViewModel
**File:** `/Forma File Organizing/ViewModels/AnalyticsDashboardViewModel.swift`

**Responsibility:** Storage analytics, insights, activity tracking

**Properties:**
- `@Published storageAnalytics: StorageAnalytics` - Global storage metrics
- `@Published filteredStorageAnalytics: StorageAnalytics` - Current view metrics
- `@Published recentActivities: [ActivityItem]` - Last 10 activities
- `@Published detectedClusters: [ProjectCluster]` - Project clusters
- `@Published isDetectingClusters: Bool` - Detection in progress

**Key Methods:**
- `updateAnalytics(from:)` - Calculate analytics from all files
- `updateFilteredAnalytics(from:)` - Calculate for filtered view
- `refreshAnalytics(from:)` - Force recalculation
- `loadActivities(from:)` - Load from SwiftData
- `addActivity(_:context:)` - Log new activity
- `detectClusters(from:context:) async` - Detect project clusters
- `dismissCluster(_:context:)` - Dismiss cluster suggestion
- `createRuleFromPattern(_:context:)` - Convert learned pattern to rule

**Dependencies:**
- `StorageService` - Storage calculations
- `InsightsService` - Insights generation
- `ContextDetectionService` - Cluster detection
- `LearningService` - Pattern learning

---

### 5. BulkOperationViewModel
**File:** `/Forma File Organizing/ViewModels/BulkOperationViewModel.swift`

**Responsibility:** Batch file operations and progress tracking

**Properties:**
- `@Published bulkOperationProgress: Double` - Progress (0.0 to 1.0)
- `@Published isBulkOperationInProgress: Bool` - Operation active
- `@Published lastBatchFailedFiles: [FileItem]` - Failed files for retry
- `@Published showFailedFilesSheet: Bool` - Show retry UI
- `@Published showBulkEditSheet: Bool` - Show bulk edit UI

**Key Methods:**
- `organizeSelectedFiles(_:context:) async` - Organize selected files
- `organizeAllReadyFiles(_:context:) async` - Organize all ready files
- `skipSelectedFiles(_:)` - Skip selected files
- `skipAllPendingFiles(_:)` - Skip all pending
- `bulkEditDestination(_:createRules:files:context:)` - Bulk set destination
- `organizeCluster(_:destinationBase:allFiles:context:) async` - Organize project cluster
- `retryFailedFiles(context:) async` - Retry failed operations
- `dismissFailedFiles()` - Clear failed file list

**Callbacks:**
- `onOperationComplete: ((Int, Int) -> Void)?` - Success/failure counts
- `onShowErrorToast: ((String) -> Void)?` - Error feedback
- `onShowCelebration: ((String) -> Void)?` - Success celebration
- `onShowToast: ((String, Bool) -> Void)?` - General toast

**Dependencies:**
- `FileOrganizationCoordinator` - Core organization logic
- `FileOperationsService` - File operations
- `NotificationService` - System notifications

---

## Coordinator Pattern

### DashboardViewModel (Coordinator)
**File:** `/Forma File Organizing/ViewModels/DashboardViewModelRefactored.swift`

The new `DashboardViewModel` acts as a **coordinator** that composes the 5 focused ViewModels. It:

1. **Owns** the focused ViewModels as `@ObservedObject` properties
2. **Delegates** method calls to the appropriate ViewModel
3. **Forwards** `objectWillChange` events to trigger SwiftUI re-renders
4. **Coordinates** inter-ViewModel communication (e.g., scan completion triggers filter update)
5. **Maintains** backwards compatibility with existing Views

**Key Design Decisions:**

1. **Composition over Inheritance** - ViewModels are composed, not inherited
2. **Explicit Delegation** - Each method clearly delegates to the responsible ViewModel
3. **Preserved Public API** - Existing Views don't need changes (backwards compatible)
4. **Reactive Forwarding** - Combine publishers link ViewModels reactively
5. **Clear Boundaries** - Each ViewModel has a single, well-defined responsibility

---

## Migration Path

### Phase 1: Gradual Adoption (Current)
✅ New ViewModels created
✅ Coordinator ViewModel created
⏳ Original DashboardViewModel backed up as `DashboardViewModel.backup.swift`
⏳ Switch imports to use `DashboardViewModelRefactored`

### Phase 2: View Updates (Next)
- Update Views to use focused ViewModels directly
- Remove delegation layer from coordinator
- Test each view independently

### Phase 3: Cleanup (Final)
- Remove `DashboardViewModel.backup.swift`
- Rename `DashboardViewModelRefactored.swift` to `DashboardViewModel.swift`
- Update documentation

---

## Benefits

### Before Refactoring
- ❌ 1,864 lines in a single file
- ❌ 28+ @Published properties
- ❌ Violates Single Responsibility Principle
- ❌ Hard to test in isolation
- ❌ Difficult to understand and maintain
- ❌ High cognitive load

### After Refactoring
- ✅ 5 focused ViewModels (<300 lines each)
- ✅ Clear separation of concerns
- ✅ Easy to test in isolation
- ✅ Each file has a single responsibility
- ✅ Reduced cognitive load
- ✅ Enables parallel development
- ✅ Backwards compatible (no View changes needed)

---

## Testing Strategy

Each ViewModel can now be tested independently:

```swift
// FileScanViewModel Tests
func testScanFiles() async {
    let mockPipeline = MockFileScanPipeline()
    let viewModel = FileScanViewModel(fileScanPipeline: mockPipeline)

    await viewModel.scanFiles(context: context, rules: [])

    XCTAssertTrue(viewModel.allFiles.count > 0)
    XCTAssertFalse(viewModel.isScanning)
}

// FilterViewModel Tests
func testCategoryFilter() {
    let viewModel = FilterViewModel()
    viewModel.updateSourceFiles(mockFiles)

    viewModel.selectedCategory = .documents

    XCTAssertEqual(viewModel.filteredFiles.count, 5)
}

// SelectionViewModel Tests
func testMultiSelect() {
    let viewModel = SelectionViewModel()

    viewModel.toggleSelection(for: file1)
    viewModel.toggleSelection(for: file2)

    XCTAssertEqual(viewModel.selectionCount, 2)
    XCTAssertTrue(viewModel.isSelectionMode)
}
```

---

## File Locations

```
Forma File Organizing/ViewModels/
├── DashboardViewModel.backup.swift       # Original (1,864 lines)
├── DashboardViewModelRefactored.swift    # New Coordinator
├── FileScanViewModel.swift               # Scanning
├── FilterViewModel.swift                 # Filtering
├── SelectionViewModel.swift              # Selection
├── AnalyticsDashboardViewModel.swift     # Analytics
└── BulkOperationViewModel.swift          # Bulk Ops
```

---

## Architectural Decision Records (ADRs)

### ADR-001: Split DashboardViewModel into Focused ViewModels

**Context:** DashboardViewModel has grown to 1,864 lines with 28+ @Published properties, violating Single Responsibility Principle.

**Decision:** Split into 5 focused ViewModels with clear boundaries:
1. FileScanViewModel - File discovery
2. FilterViewModel - Filtering & search
3. SelectionViewModel - Multi-select & navigation
4. AnalyticsDashboardViewModel - Analytics & insights
5. BulkOperationViewModel - Batch operations

**Rationale:**
- Each ViewModel has a single, well-defined responsibility
- Easier to test in isolation
- Reduces cognitive load (each file <300 lines)
- Enables parallel development
- Maintains existing coordinator pattern (FileFilterManager, SelectionManager)

**Consequences:**
- ✅ Improved maintainability
- ✅ Better testability
- ✅ Clearer architecture
- ⚠️ Requires coordination between ViewModels
- ⚠️ More files to manage

---

### ADR-002: Use Composition over Inheritance

**Context:** Need to coordinate multiple focused ViewModels.

**Decision:** Use composition pattern with explicit delegation in coordinator ViewModel.

**Rationale:**
- Composition is more flexible than inheritance
- Clear ownership and lifecycle management
- Easy to mock/replace ViewModels for testing
- Matches existing Swift/SwiftUI patterns

**Consequences:**
- ✅ Flexible architecture
- ✅ Easy testing
- ✅ Clear boundaries
- ⚠️ More boilerplate (delegation methods)

---

### ADR-003: Preserve Public API for Backwards Compatibility

**Context:** Many existing Views depend on DashboardViewModel.

**Decision:** Preserve public API in coordinator ViewModel via delegation.

**Rationale:**
- Zero-cost migration (no View changes needed)
- Gradual adoption possible
- Reduces risk

**Consequences:**
- ✅ No breaking changes
- ✅ Gradual migration path
- ⚠️ Temporary delegation overhead

---

## Next Steps

1. **Test the new architecture** - Write unit tests for each ViewModel
2. **Update Views gradually** - Migrate Views to use focused ViewModels directly
3. **Remove delegation** - Once all Views are updated, remove delegation layer
4. **Performance testing** - Verify no performance regression
5. **Documentation** - Update code comments and documentation
6. **Delete backup** - Remove `DashboardViewModel.backup.swift` once migration is complete

---

## Author
Created: 2025-12-23
Refactored by: Claude (Sonnet 4.5)
