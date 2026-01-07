# Forma - Changelog

All notable changes to Forma File Organizing App will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.5.1] - 2025-12-19

### Changed - Sidebar Visuals "Glass Slab"
- **Glass Slab Aesthetic**: Updated the sidebar to resemble a physical "slab of glass" (à la macOS Widgets) rather than a flat window backdrop.
  - **Material**: Switched from `.sidebar` to `.popover` for better separation from the wallpaper/background.
  - **Refraction**: Added a subtle white gradient overlay (12% to 4%) to create a volumetric lighting effect.
  - **Gradient Borders**: Replaced flat borders with a top-down white gradient stroke (50% to 10%) to simulate light catching the top edge of the glass.

## [1.5.0] - 2025-12-19

### Changed - Analytics & Insights Refactor
- **Center Panel Analytics**: Moved primary analytics views (Storage Breakdown, Trends, Usage Stats) to the centralized Dashboard view for better visibility.
  - **Usage Statistics**: "Files Organized", "Time Saved", etc. are now prominent at the top of the view.
  - **Split Charts**: Side-by-side layout for Storage Breakdown (Donut) and Storage Trends (Line) charts.
- **Right Panel Transformation**: Renamed "Analytics Overview" to "Opportunities".
  - **Focus on Action**: The right panel now strictly highlights actionable recommendations (e.g., "Review Duplicate Files") from the `StorageHealthScore`.
  - **Celebration State**: Added "All optimized!" state when no recommendations are present.
- **Removed Redundancy**: Eliminated duplicate charts and stats between the center and right panels.

## [1.4.0] - 2025-12-06

### Added - Automation Engine

#### Background Monitoring
- **AutomationEngine**: Singleton `@MainActor` class managing automated file organization
  - `AutomationState` observable class tracking: `isRunning`, `lastRunDate`, `statusMessage`, `nextScheduledRun`
  - Success/failed/skipped counts from last run
  - Graceful start/stop with `start()` and `stop()` methods
- **AutomationLifecycleModifier**: SwiftUI view modifier integrating with scene phase
  - Auto-starts engine when app becomes active
  - Auto-stops on background/inactive states
  - Applied to `MainContentView` for app-wide lifecycle management
- **Feature Flags**: Staged rollout via `FeatureFlagService`
  - `.backgroundMonitoring` - Master toggle for automation
  - `.autoOrganize` - Enable/disable auto-organize
  - `.automationReminders` - Control notification behavior

#### Scheduling & Policy
- **AutomationPolicy**: Pure struct defining automation decision logic
  - `shouldAutoOrganize(file:)` - Confidence + staleness checks
  - `calculateScanInterval(metrics:)` - Adaptive intervals (5-60 min based on backlog)
  - `shouldSendBacklogReminder(metrics:)` - Threshold-based notifications
- **FormaConfig.Automation**: Centralized configuration constants
  - `backlogThreshold`, `ageThresholdDays`, `minScanIntervalMinutes`, `maxScanIntervalMinutes`
  - ML confidence thresholds: `mlRuleConfidenceMinimum`, `mlAutoOrganizeConfidenceMinimum`
  - Notification cooldowns: `backlogReminderCooldownHours`, `errorNotificationCooldownMinutes`

#### Activity Logging
- **Extended ActivityLoggingService** with automation-specific methods:
  - `logAutomationScanCompleted(filesScanned:newPending:)`
  - `logAutoOrganizeBatch(successCount:failedCount:skippedCount:)`
  - `logAutomationError(type:message:)`
  - `logAutomationPaused(reason:)` and `logAutomationResumed()`
- **New ActivityItem types**:
  - `.automationScanCompleted`, `.automationAutoOrganized`
  - `.automationError`, `.automationPaused`, `.automationResumed`

#### Dashboard UI
- **AutomationStatusWidget**: Compact widget in right panel showing:
  - Current status (scanning, scheduled, or paused)
  - Status indicator dot with color-coded states (blue=running, green=scheduled, orange=paused)
  - Pause/resume toggle button
  - Expandable last-run statistics (organized/skipped/failed counts)
  - Hover effects and tap-to-expand interaction
- **DefaultPanelView Integration**: Automation widget conditionally displayed based on feature flags

#### Undo Support
- **BulkMoveCommand**: Single undo entry for multi-file auto-organize operations
  - Preserves per-file original status for accurate rollback
  - Groups related moves into atomic undo units
- **MoveFileCommand**: Individual file move with full state preservation

### Testing
- **AutomationIntegrationTests**: 18 comprehensive tests covering:
  - Activity logging for all automation events
  - Undo entry creation and state preservation
  - AutomationMetrics conversion and backlog detection
  - Feature flag existence validation
  - Config threshold verification
  - Activity type icons and display names

---

## [Unreleased]

### Fixed - Scan Error Feedback & Undo/Redo
- Scan runs that complete with partial failures now surface notifications/toasts instead of failing silently.
- Undo/redo now uses the active ModelContext so file move actions can be reversed reliably.

### Added - Completion Celebration

#### "Inbox Zero" Celebration
- **CompletionCelebrationView**: Special celebration shown when user clears ALL pending files
  - Confetti animation with 30 particles in brand colors
  - Trophy icon with animated glow rings
  - Randomized encouraging messages ("Inbox zero, who?", "Look at you go!", etc.)
  - Stats badge showing files organized count
  - 10-second auto-dismiss (2x standard celebration)
  - Full accessibility support (respects `reduceMotion`)

#### Panel State Machine Updates
- **New `.completionCelebration(filesOrganized: Int)` mode** in RightPanelMode enum
- Detection logic in both batch organize and single-file organize flows
- Triggers when remaining pending/ready files count reaches zero

#### Files Added/Modified
- `CompletionCelebrationView.swift` (new) - Celebration view with confetti
- `PanelStateManager.swift` - Added completionCelebration mode
- `RightPanelView.swift` - Added case handling for new mode
- `DashboardViewModel.swift` - Added detection logic and wrapper method

### Added - Glass Material Tiers
- Introduced `FormaMaterialTier` and `FormaMaterialSurface` to standardize “Control Center-style” material hierarchy (base/raised/overlay), consistent rims, and active/inactive window styling.

### Changed - Center Pane Focus
- Added a top “tapered focus” overlay so cards blur in from the top and come into focus ~200–300pt down, with toolbar controls remaining crisp above.

### Fixed - Collapsed Sidebar Alignment
- Centered icon-only navigation and bottom controls when the left sidebar is collapsed.

### Changed - Sidebar Visual Style
- Updated the left sidebar to a rounded, inset frosted-glass panel (material + tint) with subtle border and elevation to better separate it from the backdrop.

### Fixed - Sidebar Location Filters
- Selecting a location (Desktop/Downloads/etc.) now updates the file tiles.

### Added - Advanced Rule Features
- **Rule Priority Ordering**: Rules now have a `sortOrder` property for explicit evaluation order
  - Lower values = higher priority (evaluated first)
  - First-match-wins semantics for deterministic behavior
  - `RuleService.fetchRulesByPriority()` returns rules in evaluation order
  - `RuleService.updateRulePriorities()` for bulk priority updates
- **Drag-to-Reorder UI**: RulesManagementView supports drag-and-drop rule reordering
  - Visual drag preview during reorder
  - Automatic priority recalculation on drop
  - Hint text explaining reorder functionality
- **Exclusion Conditions**: Rules can define "veto" conditions that prevent matches
  - New `exclusionConditions: [RuleCondition]` property on Rule model
  - If ANY exclusion condition matches, the rule does NOT apply
  - UI section in RuleEditorView for adding exception patterns
- **NOT Operator**: Negate any condition using `RuleCondition.not(...)`
  - Supports all condition types (extension, name, date, size, etc.)
  - UI toggle in RuleEditorView condition rows
  - Useful for exclusion patterns like "NOT .pdf"

### Fixed - Layout Consistency
- Center pane cards stay visually aligned between Pending and All Files
- Grid/List/Tile share a single centered content width and consistent gutters
- Grid row spacing restored for better scanability
- Floating action bar stays within center pane bounds
- Dashboard toolbar controls feel centered and intentional, with search returning to a native window toolbar field

### Changed - Swift 6 Readiness
- Swift 6 language mode builds cleanly with strict concurrency checks enabled

### Planned Features
- AI rule suggestions
- File preview capabilities
- Scheduled automatic organization
- iCloud folder support
- Content-based rule conditions
- Undo/redo for file operations
- Export/import rule sets
- Rule groups/categories

---

## [1.1.0] - 2025-11-26

### Added - Visual & UX Polish
- **Anchored Sidebar**: Replaced floating sidebar with a native, full-height anchored sidebar for better hierarchy.
- **Unified Toolbar**: Implemented `UnifiedToolbar` with morphing "Review" / "All Files" modes and dynamic secondary filters.
- **Global Search**: Relocated search from window toolbar to the top of the Sidebar (`CompactSearchField`).
- **Refined UI**: Standardized on 8px corner radii for buttons and interactive elements.
- **Empty States**: Implemented consistent `FormaEmptyState` across views.
- **Consistent Actions**: Standardized `PrimaryButton` and `SecondaryButton` usage in `FileInspectorView` and `RulesManagementView`.

## [1.0.0] - 2025-01-19

### Added - Dashboard Feature

#### Main Dashboard View
- **Three-column layout** with navigation sidebar, main content area, and analytics sidebar
- **Left sidebar** with app navigation, quick actions, and settings access
- **Main content area** with dynamic file display and filtering
- **Right sidebar** with storage analytics and activity feed

#### Storage Analytics
- **Circular storage chart** with animated segmented rings showing storage breakdown by file type
- **Storage panel** displaying:
  - Total storage used across all tracked files
  - Percentage breakdown by category (Documents, Images, Videos, Audio, Archives)
  - File counts per category
  - Clickable category rows for quick filtering
- **Real-time calculation** with 60-second caching for performance
- **Color-coded categories** for easy visual identification

#### File Type Categorization
- **Six main categories**: All, Documents, Images, Videos, Audio, Archives
- **Comprehensive extension mapping** covering 50+ file types
- **Automatic categorization** based on file extension
- **Category-specific colors and icons**

#### Activity Feed
- **Real-time activity tracking** showing last 10 actions
- **Activity types tracked**: File Scanned, File Organized, File Skipped, Rule Created, Rule Applied, Rule Deleted
- **Color-coded icons** for each activity type
- **Relative timestamps** (e.g., "2m ago", "1h ago")

#### Data Models
- **FileTypeCategory enum** with extension mappings and visual properties
- **StorageAnalytics struct** for calculating storage statistics
- **ActivityItem model** for tracking user actions (SwiftData)
- **FileItem enhancements**: Added `sizeInBytes` and `category` computed property

#### Services
- **StorageService** (singleton) for storage analytics calculation and caching
- **Enhanced FileSystemService** with Downloads folder scanning support
- **Enhanced FileOperationsService** with activity tracking integration

### Changed - RuleEngine Refactoring

#### Protocol-Based Architecture
- **Refactored RuleEngine** to use protocol-based generics instead of concrete SwiftData types
- **Created protocols**: `Fileable` and `Ruleable` for flexible type abstraction
- **Enhanced testability**: Tests now use simple structs instead of SwiftData models
- **Improved performance**: Test execution time reduced to ~0ms (from several seconds)
- **Better separation**: Business logic fully decoupled from persistence layer

#### Testing Improvements
- **Created TestModels.swift** with `TestFileItem` and `TestRule` test doubles
- **Removed SwiftData dependencies** from RuleEngineTests
- **Eliminated MainActor requirements** in unit tests
- **All 8 RuleEngine tests passing** with instant execution

#### Documentation
- **Added RuleEngine-Architecture.md**: Comprehensive guide to protocol-based design
- **Updated API_REFERENCE.md**: New generic method signatures and protocol documentation
- **Enhanced inline docs**: Added architecture overview to RuleEngine.swift

#### App Structure
- **Main window now opens to Dashboard** instead of ReviewView
- **ReviewView accessible** via left sidebar navigation
- **Window size increased** to minimum 1200x800 for optimal dashboard layout
- **Schema updated** to include ActivityItem model

### Fixed
- Fixed `FetchDescriptor` syntax error (createdAt → creationDate)
- Fixed `StatusBadge` parameter mismatch
- Fixed `RuleEngine` unused variable warning
- Improved type safety with proper enum conversions

---

## [0.1.0] - 2025-01-18

### Added - MVP Release & Custom Rules

**Custom Rules Feature**
- User-specific rule builder UI (RuleEditorView)
- Rule creation/editing interface with form validation
- Folder picker integration for destination selection
- Support for all 4 condition types (extension, contains, starts with, ends with)
- SwiftData persistence for rules
- Enable/disable rule toggles
- Rule management in Settings

**Quick Access Improvements**
- "+ Rule" button in ReviewView header for instant rule creation
- Settings gear icon in ReviewView for quick access
- Multiple entry points for creating rules
- Improved UX with fewer clicks to create rules

**File System Integration**
- Desktop folder scanning with security-scoped bookmarks
- File metadata reading (name, extension, size, creation date)
- FileManager integration for file operations
- Real Desktop/Downloads folder access

**Rule Engine**
- Built-in rules: Screenshots, PDFs, ZIP files
- Rule-based file matching (extension, name patterns)
- Extensible rule architecture for custom rules
- Protocol-based architecture for better testability

**File Operations**
- Move files with validation and error handling
- Auto-create destination directories
- Security-scoped bookmark system for destination folders
- Folder name validation
- Batch file move operations
- Comprehensive error handling

**User Interface**
- Main review interface with file list
- File status indicators (✓ Has rule, ⚠️ No rule)
- Individual file move actions (Accept, Skip)
- Batch "Organize All" operation
- Loading states with spinner
- Error and success message banners
- Empty state ("All clean!")
- Card view option for file review

**State Management**
- SwiftUI + Combine reactive architecture
- SwiftData persistence for files and rules
- @Published properties for UI updates
- Loading state tracking (idle, loading, loaded, error)
- File status tracking (pending, ready, completed, skipped)

**Permission System**
- Security-scoped bookmarks (no Full Disk Access required)
- Desktop folder permission on first launch
- Destination folder permissions on demand
- Folder selection validation
- "Reset All Permissions" functionality
- Clear permission error messages

**Design System**
- Monochromatic color palette (Obsidian, Bone White)
- Steel Blue accent color for actions
- SF Pro system font
- 8pt grid spacing system
- Light/dark mode support
- Forma brand identity implementation

**Documentation**
- SETUP.md - Installation and usage guide
- USER_RULES_GUIDE.md - Rules documentation
- ARCHITECTURE.md - System design and data flow
- API_REFERENCE.md - Service and API documentation
- DEVELOPMENT.md - Development workflow guide
- Forma-Design-Doc.md - Product vision and roadmap
- Forma-Brand-Guidelines.md - Visual design system

### Technical Details

**Frameworks:**
- SwiftUI for UI
- SwiftData for persistence
- Combine for reactive programming
- AppKit for file dialogs and menu bar

**Architecture:**
- MVVM pattern (Model-View-ViewModel)
- Service layer for business logic
- Repository pattern via SwiftData
- Async/await for file operations

**Entitlements:**
- com.apple.security.files.user-selected.read-write
- com.apple.security.files.bookmarks.app-scope

**Minimum Requirements:**
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later for development

### Known Limitations (0.1.0)
- No undo functionality
- No background file monitoring
- No duplicate detection
- No AI rule suggestions

---

## Future Roadmap

### v1.1.0 - Enhanced Organization
- AI-powered destination suggestions
- File preview on hover
- Drag-and-drop file organization
- Search within file lists
- Sortable columns (name, size, date)

### v1.2.0 - Analytics & Insights
- Storage trends over time
- Usage statistics and reports
- Duplicate file detection
- Smart organization suggestions

### v1.3.0 - Advanced Rules
- Conditional rules (if-then-else)
- File size-based rules
- Date-based rules
- Content-based rules (for text files)
- Rule priority and ordering

### v2.0.0 - Cloud & Sync
- iCloud folder support
- Cross-device rule syncing
- Cloud storage integration (Dropbox, Google Drive)
- Scheduled automatic organization
- Backup and restore

---

## Links

- **Project Repository:** [Internal]
- **Issue Tracker:** [Internal]
- **Documentation:** See `/Docs` folder
- **Design Docs:** `Docs/Forma-Design-Doc.md`
- **Brand Guidelines:** `Docs/Forma-Brand-Guidelines.md`

---

**Changelog Maintained By:** Development Team
**Last Updated:** December 19, 2025
**Format Version:** 1.0.0 (Keep a Changelog)
