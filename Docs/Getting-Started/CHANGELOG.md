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

### Added
- Smart Insight actions now deep-link into relevant views (large files, downloads, screenshots) and can prefill the rule editor.
- Category scope editor now includes a folder picker for scoped categories.
- Bulk operation progress overlay now supports cancellation.
- Grid view now shows confidence indicators alongside destination badges, with tooltips that include match reasons when available.
- `forma-website` now includes a first-party blog system (`/blog`, `/blog/[slug]`) backed by in-repo MDX content.
- `forma-website` now exposes AI-consumable routes: `/llms.txt`, `/for-agents`, `/openapi.json`, and read-only JSON APIs under `/api/public/*`.
- Added website-level tracking events (`download_click`, `newsletter_submit_success`, `support_contact_click`, `blog_cta_click`) with optional Plausible integration.
- Added `Scripts/signpost_harness_snapshot.sh` to automate debug harness execution, `xctrace` export, and p50/p95/p99 summary generation for signpost performance snapshots.

### Changed
- Consolidated marketing web code to `forma-website/` and removed legacy `website/` + `forma-marketing-site/` directories.
- `forma-website` now uses normal in-flow footer layout (no fixed negative-z reveal), and web metadata/sitemap/robots now target `https://formafiles.com`.
- `forma-website` metadata now includes expanded structured data (`SoftwareApplication`, `Organization`, `WebSite`, `FAQPage`) and keyword coverage for Mac file-organization intent.
- `forma-website` download CTAs now fall back to `/get-forma` (instead of `/support`) when the App Store URL is unset, and launch copy now consistently reflects one-time `$29` pricing and `macOS 15+`.
- `forma-website` robots and sitemap generation now include explicit AI/search crawler directives and stable last-modified handling for static/blog routes.
- `forma-website` hero/header spacing and anchor offsets were refined to prevent top overlap, and light-mode feature demos now use readable high-contrast surfaces.
- `forma-website` light-mode typography contrast and feature-demo default visibility were corrected, and hero spacing/scale were further tuned for cleaner first paint.
- `forma-website` theme parity was tightened by adding complementary light/dark component tokens for Mac window chrome, feature demos, file cards, before/after, newsletter, and legal/support content surfaces.
- `forma-website` mobile spacing rhythm was tightened between hero, feature, before/after, pricing, FAQ, and newsletter sections, and the mobile-menu scrim now uses theme-specific light/dark tokens.
- `forma-website` desktop feature handoff was refined by preventing feature-header/showcase overlap and tightening the Features→Before/After transition spacing.
- `forma-website` now includes a subtle theme-aware WebGL atmosphere shader overlay (grain + soft light drift + vignette) to add depth without heavy motion.
- `forma-website` header/footer branding now swaps to the inverse logo asset in dark mode for clearer contrast.
- `forma-website` header navigation now uses a compact pill state on scroll, and hash-based nav/brand links consistently resolve back to home sections from non-home pages.
- Documentation navigation was cleaned up by archiving superseded audits/plans/refactor summaries under `Docs/Archive` and updating internal cross-links.
- Learned patterns persist unified Destinations for bookmark-aware suggestions.
- ML destination predictions incorporate project clusters, real training counts, and bookmark-backed destinations when possible.
- Auto-organize eligibility now respects per-folder automation exclusions.
- Rules list now flags destinations missing folder access with a review filter, and Rule Editor offers a quick picker to resolve them.
- Bulk-review mode now prioritizes the floating action bar by hiding the right-panel primary organize CTA and de-emphasizing always-on row-level organize buttons.
- Inline Rule Builder now uses explicit "When" and "Then" sections with inline validation hints, a disabled-until-valid save action, and an always-visible impact preview.
- Smart Rules empty state now removes duplicate top-level actions and adds starter templates that open the editor with prefilled natural-language prompts.
- Analytics view now runs in a focus mode by hiding the right panel while the Analytics screen is active.
- Productivity Health now includes explicit no-data onboarding guidance with quick actions (scan folders, open pending queue, and create a first rule).
- Settings tabs now render inside a shared shell with unified spacing, surfaces, and background chrome to match the main app.
- File status language is now more consistent across card/list/grid, with compact status indicators and simplified rule-state labeling.
- List/grid interaction targets were increased and secondary text/chip contrast was raised for better accessibility in light and dark themes.
- Content search now runs its heavy scan work off the main actor and uses indexed path lookups in `DashboardViewModel` to avoid per-row linear searches.
- Folder scans now use prefetched URL resource keys and parallelized standard-folder scan tasks to reduce filesystem syscall overhead.
- Thumbnail loading now checks memory/disk caches before opening security scopes and skips redundant stale-metadata checks on disk-cache hits.
- Duplicate detection now reuses compiled regexes, streams file hashing in chunks, and uses bucketed near-name matching to reduce memory and comparison cost.
- The performance test plan now includes `OptimizationBenchmarksTests`, and those benchmarks enforce explicit regression budgets for optimized latency and speedup.
- Added a debug-only signpost harness launch path (`--perf-signpost-harness`) to capture repeatable `DashboardScanRefresh` and `DefaultPanelInsightRefresh` latency samples.
- `DashboardScanRefresh` now emits sub-phase signposts (`DashboardScanDiscovery`, `DashboardRuleEvaluation`, `DashboardClusterRefresh`, `DashboardPublish`) to isolate outlier paths.
- Signpost harness analysis now supports explicit warm-up windows (`FORMA_PERF_HARNESS_WARMUP`), emits separate warm-up/sample interval labels, and enforces one harness run per app launch to prevent overlapping captures.
- Default panel insights now reuse precomputed dashboard clusters, emit stable insight IDs, and avoid no-op state updates so dismissed quick actions stay dismissed and UI churn is reduced.
- Default panel insight refresh now enforces a strict single in-flight task policy under rapid updates; stale and cancelled refreshes are prevented from publishing UI state.
- Dashboard scans now publish lightweight phase text (`Preparing scan`, `Scanning folders`, `Analyzing clusters`, `Updating dashboard`) so long operations do not appear stalled.
- `InsightsService.generateInsights(...)` now exits early on cancellation and avoids recording successful completion metadata for cancelled runs.
- Content search now skips redundant reruns when the normalized query and scanned file snapshot are unchanged.
- Settings "Launch at Login" now syncs with macOS Login Items (`SMAppService`) and reports failures instead of failing silently.
- Dashboard startup scans now respect the "Auto-scan on Launch" setting, including post-onboarding auto-scan behavior.
- Menu bar Settings now uses the shared app settings opener instead of synthetic keyboard events.
- Dashboard window chrome now uses native `NavigationSplitView` columns (sidebar/content/inspector) instead of floating overlay panes.
- Restored layered vibrancy in the native split-view shell via pane-specific materials and a gradient-backed window surface.
- Unified segmented/toggle chrome across toolbar controls, category tabs, productivity period selector, and inspector automation controls using shared control-shell tokens.

### Fixed
- Treemap taps now navigate to the corresponding category view.
- Reduced repeated rule-scan warnings for unresolvable placeholder destinations.
- Current Task card organization percentage now updates in real time by using scan-session progress counts even when organized files are removed from the active list.
- `forma-website` pricing count-up now resolves correctly when users deep-link below the pricing section, preventing a stale `$0` label.
- `forma-website` feature/pricing/FAQ/newsletter reveal animations now force visible state when a section is already past its trigger (deep links and long screenshots), preventing hidden-content gaps.
- Shift-click range selection now works consistently across card/list/grid file views by using a shared selection anchor.
- Removed oversized translucent "lens" artifacts from split-view panes by avoiding full-bleed `glassEffect` and using pane-safe native material fallback while retaining layered vibrancy.
- Full-bleed pane surfaces now always prefer native fallback material, even when debug glass-force flags are enabled, preventing circular contour artifacts from returning.
- Analytics now keeps the left sidebar visible when the inspector column is hidden, preventing unintended sidebar collapse when switching views.
- Productivity period and category segmented controls now use corrected active tints and shared control-shell fills so selected states remain readable and visually consistent.
- Analytics refresh work is now cancellable and period-cached to avoid redundant recomputation and reduce energy/memory churn during rapid navigation.
- Main-screen Settings entry points now use native `SettingsLink` (sidebar, review toolbar, menu bar, and productivity insight actions) for consistent Settings-scene opening.
- File Inspector now wires previously inert actions: "Based on rule..." opens the matched rule editor, and the trash button now executes a confirmed move-to-trash flow.

### Removed - Deprecated APIs
- Removed legacy initializers for `FileItem` and `FileMetadata`.
- Removed deprecated `RuleService.addRule(_:)`.
- Removed deprecated error type aliases in `FileSystemService` and `FileOperationsService`.

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
