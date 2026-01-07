# Forma Codebase Refactoring Plan

**Status:** Archived (historical)  
**Archived:** 2026-01  
**Superseded By:** [Development Guide](../../Development/DEVELOPMENT.md)

Generated: December 23, 2025
Last Updated: December 23, 2025

## Executive Summary

This plan addresses organizational debt accumulated as the codebase scaled to 183 Swift files. The core architecture is sound (no circular dependencies, proper layer separation), but several files have grown too large and code duplication has emerged.

**Estimated Impact**: ~2,000+ lines of code reduction through consolidation; significantly improved maintainability.

### Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Quick Wins | File moves, simple fixes | ✅ Complete |
| Phase 1 | Split DashboardViewModel | ✅ Complete |
| Phase 4 | Consolidate checkbox/thumbnail components | ✅ Complete |
| Phase 5 | Extract business logic from Models | ✅ Complete |
| Phase 6.1 | Consolidate rule editor components | ✅ Complete |
| Phase 2 | Extract OnboardingFlowView steps | ✅ Complete |
| Phase 3 | Split SettingsView sections | ✅ Complete |

**Lines Reduced So Far**: ~4,250+ lines through ViewModel decomposition, View modularization, and component consolidation

---

## Phase 1: Critical - Split DashboardViewModel (Priority: CRITICAL) ✅ COMPLETED

**Before**: `DashboardViewModel.swift` - 1,864 lines with 28 @Published properties

**After**: `DashboardViewModel.swift` - 867 lines as coordinator composing focused ViewModels

### Architecture Implemented:

DashboardViewModel now uses the **Coordinator Pattern**, composing 5 focused child ViewModels:

| File | Responsibility | Key Properties |
|------|----------------|----------------|
| `FileScanViewModel.swift` | Desktop/folder scanning, real-time updates | `allFiles`, `recentFiles`, `isScanning`, `scanProgress` |
| `FilterViewModel.swift` | Category/folder filtering, search | `searchText`, `activeChips`, `filteredFiles`, `selectedCategory` |
| `SelectionViewModel.swift` | Multi-select, keyboard navigation | `selectedFiles`, `focusedFile`, `lastSelectedIndex` |
| `AnalyticsDashboardViewModel.swift` | Storage stats, trends, health | `storageAnalytics`, `filteredStorageAnalytics`, `organizationScore` |
| `BulkOperationViewModel.swift` | Batch operations, progress | `bulkOperationProgress`, `isProcessingBulk`, `pendingOperations` |

### Additional Coordinators:
- `PanelStateManager` - Panel visibility and navigation state
- `FileOrganizationCoordinator` - File movement orchestration

### Key Implementation Details:
- [x] Child ViewModels use `@ObservedObject` pattern in parent
- [x] Parent forwards `objectWillChange` from children using Combine
- [x] Backward compatibility maintained - existing view bindings continue to work
- [x] Each ViewModel is independently testable

**Lines Reduced:** ~1,000 lines (1,864 → 867 in coordinator, logic distributed to focused ViewModels)

---

## Phase 2: Extract OnboardingFlowView Steps (Priority: HIGH) ✅ COMPLETED

**Before**: `OnboardingFlowView.swift` - 1,385 lines with 5 steps in one file

**After**: Modular step components with shared state

### Files Created:

```
Views/Onboarding/
├── OnboardingFlowView.swift        (237 lines - coordinator)
├── OnboardingState.swift           (shared state object)
├── WelcomeStepView.swift           (value proposition & excitement)
├── FolderSelectionStepView.swift   (folder picker)
├── PersonalityQuizStepView.swift   (personality assessment)
├── TemplateSelectionStepView.swift (per-folder templates)
├── OnboardingPreviewStepView.swift (final review)
├── OnboardingComponents.swift      (shared UI components)
├── ARCHITECTURE.md                 (architecture documentation)
└── README.md                       (usage guide)
```

### Key Implementation Details:
- [x] `OnboardingState` struct holds all flow state (folder selection, templates, personality)
- [x] Coordinator uses switch statement to route between step views
- [x] Each step receives only the bindings it needs
- [x] Navigation callbacks (`onContinue`, `onBack`) keep flow logic in coordinator
- [x] Shared components extracted to `OnboardingComponents.swift`

**Lines Reduced:** ~1,150 lines (1,385 → 237 in coordinator, logic distributed to step views)

---

## Phase 3: Split SettingsView Sections (Priority: HIGH) ✅ COMPLETED

**Before**: `SettingsView.swift` - 1,094 lines with 5+ sections

**After**: Modular section components with shared styling

### Files Created:

```
Views/Settings/
├── SettingsView.swift           (921 bytes - coordinator with TabView)
├── SettingsComponents.swift     (shared styling components)
├── GeneralSettingsSection.swift (appearance, shortcuts)
├── RulesManagerSection.swift    (rule listing, editing)
├── CustomFoldersSection.swift   (folder management)
├── SmartFeaturesSection.swift   (AI toggles, automation)
└── AboutSection.swift           (version, links)
```

### Key Implementation Details:
- [x] Coordinator uses TabView to switch between sections
- [x] Each section is independently testable
- [x] Shared styling extracted to `SettingsComponents.swift`
- [x] SmartFeaturesSection is the largest (22KB) - contains automation configuration

**Lines Reduced:** ~900 lines (1,094 → ~200 in coordinator, logic distributed to section views)

---

## Phase 4: Consolidate Duplicate Components (Priority: HIGH) ✅ COMPLETED

### New Shared Components Created:

```
Components/Shared/
├── FormaCheckbox.swift     (236 lines) - Unified checkbox with size/shape variants
├── FormaThumbnail.swift    (437 lines) - Unified thumbnail with display modes
└── FormaActionButton.swift (308 lines) - Unified action button with style variants
```

### 4.1 Unified Checkbox Component ✅

**Before** (4 duplicate implementations):
- `FileRow.swift` → PremiumCheckbox
- `FileListRow.swift` → CompactCheckbox
- `FileGridItem.swift` → GridCheckbox
- `SelectionCheckbox.swift` → SelectionCheckbox

**After**: Single `FormaCheckbox.swift` with:
- `Size` enum: `.compact` (18px), `.standard` (20px), `.large` (22px)
- `Shape` enum: `.rounded`, `.roundedSmall`, `.circle`
- Convenience initializers: `.premium()`, `.compact()`, `.grid()`, `.selection()`
- `SelectionCheckbox.swift` retained as legacy wrapper for backward compatibility

### 4.2 Unified Action Button ✅

**Before** (3 duplicate implementations):
- `FileRow.swift` → IconActionButton
- `FileListRow.swift` → CompactActionButton
- `FileGridItem.swift` → GridActionButton

**After**: Single `FormaActionButton.swift` with:
- `Style` enum: `.icon`, `.compact`, `.grid`
- Primary/secondary variations with different backgrounds and shadows
- Convenience initializers: `.icon()`, `.compact()`, `.grid()`

### 4.3 Unified Thumbnail Component ✅

**Before** (3 duplicate implementations with ~150 lines each):
- `FileRow.swift` → PremiumThumbnail + loadThumbnail()
- `FileListRow.swift` → CompactThumbnail + loadThumbnail()
- `FileGridItem.swift` → GridThumbnail + loadThumbnail()

**After**: Single `FormaThumbnail.swift` with:
- `DisplayMode` enum: `.premium` (84px), `.compact` (44px), `.grid` (120-130px)
- Shared thumbnail loading via ThumbnailService
- Mode-specific Quick Look overlays
- Category gradient backgrounds
- Convenience initializers: `.premium()`, `.compact()`, `.grid()`

### 4.4 Card Styling Utilities

**Status**: Deferred - the state-based background/border/shadow logic is tightly integrated with each component's specific needs. Extraction would add complexity without significant benefit.

### Key Changes:
- [x] All three file row components (FileRow, FileListRow, FileGridItem) now use unified shared components
- [x] Duplicate thumbnail loading logic consolidated (was ~450 lines, now ~330 lines in one place)
- [x] Animation and hover state logic unified across all variants
- [x] Legacy `SelectionCheckbox` wrapper maintained for backward compatibility

**Lines Eliminated:** ~700+ lines of duplicate component code consolidated into ~980 lines of shared components with enhanced functionality

---

## Phase 5: Extract Business Logic from Models (Priority: MEDIUM) ✅ COMPLETED

### 5.1 FileItem Cleanup ✅

**Created `Services/FileItemPresenter.swift`**:
- [x] `ageCategory` computed property → `FileItemPresenter.ageCategory(for:)`
- [x] `ageDateColor` computed property → `FileItemPresenter.ageColor(for:)`
- [x] `sizeColor` computed property → `FileItemPresenter.sizeColor(for:)` (was dead code - removed from model)
- [x] `iconName` computed property → `FileItemPresenter.icon(for:)` (model delegates to presenter)
- [x] Extended icon mapping to support 30+ file types (vs original 5)

**FileItem model cleanup**:
- Removed unused `ageDateColor`, `sizeColor`, `ageCategory` computed properties (dead code)
- Removed unused age threshold constants
- `iconName` now delegates to FileItemPresenter

### 5.2 LearnedPattern Cleanup ✅

**Created `Services/PatternAnalysisService.swift`** (unified service):
- [x] `toRule()` method → `PatternAnalysisService.convertToRule(_:)`
- [x] `updateTimeCategory()` → `PatternAnalysisService.updateTimeCategory(for:)`
- [x] `shouldSuggest` logic → `PatternAnalysisService.shouldSuggest(_:)`
- [x] `confidenceLevel` → `PatternAnalysisService.confidenceLevel(for:)`
- [x] `iconName` → `PatternAnalysisService.icon(for:)`
- [x] `conditionsDescription` → `PatternAnalysisService.conditionsDescription(for:)`
- [x] `negativePatternDescription` → `PatternAnalysisService.negativePatternDescription(for:)`
- [x] `timeCategoryDisplayName` → `PatternAnalysisService.displayName(for:)`

**LearnedPattern model cleanup**:
- All computed properties now delegate to PatternAnalysisService
- Backward compatibility maintained (same API, different implementation)
- Model reduced from ~455 lines to ~355 lines

### 5.3 SwiftData Enum Workaround

**Status**: Deferred - current raw string storage pattern works reliably

---

## Phase 6: Additional Refactoring (Priority: LOW) ✅ PARTIALLY COMPLETED

### 6.1 Consolidate Duplicate Rule Editor Components ✅

**Before:**
- `RuleEditorView.swift`: 1,561 lines
- `InlineRuleBuilderView.swift`: 1,556 lines
- Duplicate structs: `RuleFormState`, `InlineRuleFormState`, `CreateCategoryPopover`, `InlineCreateCategoryPopover`, `CategoryPill`, `InlineCategoryPill`

**After:**
- `RuleEditorView.swift`: 1,293 lines (-268 lines, -17%)
- `InlineRuleBuilderView.swift`: 1,291 lines (-265 lines, -17%)

**New Shared Components Created:**

```
Views/Components/
├── RuleFormState.swift      (208 lines) - Unified form state for rule editing
│   ├── RuleFormState struct - All form properties consolidated
│   └── RuleConditionDisplay enum - Shared condition display helpers
│
└── CategoryComponents.swift (214 lines) - Shared category UI components
    ├── CreateCategoryPopover - Popover for creating new categories
    └── CategoryPill - Pill button for category selection (with textFont variant)
```

**Key Changes:**
- [x] Created unified `RuleFormState` struct replacing both `RuleFormState` and `InlineRuleFormState`
- [x] Added `RuleConditionDisplay` enum with `displayName()`, `placeholder()`, and `hint()` helpers
- [x] Created shared `CreateCategoryPopover` (100% identical code was duplicated)
- [x] Created shared `CategoryPill` with `textFont` parameter for style variants
- [x] Updated `RuleEditorView` to use shared components
- [x] Updated `InlineRuleBuilderView` to use shared components
- [x] Build verified successfully

**Lines Eliminated:** ~530 lines of duplicate code consolidated into ~420 lines of shared components

### 6.2 Naming Standardization
**Status**: Deferred - Current naming is consistent enough; changes would require widespread import updates

### 6.3 Folder Cleanup ✅ PARTIALLY COMPLETE
- [x] Delete empty `/Design/` folder
- [x] Move `OpenSettingsEnvironment.swift` to `/Configuration/`
- [ ] Consolidate `/Views/Components/` into `/Components/` (deferred - view-specific vs shared components distinction is useful)

---

## Quick Wins (Immediate)

1. [x] Delete empty `/Design/` folder
2. [x] Move `FileOperationCoordinator.swift` to `/Coordinators/`
3. [x] Fix unsafe `[0]` array access in `DestinationPredictionService.swift:226`
4. [x] Move `OpenSettingsEnvironment.swift` to `/Configuration/`

---

## Success Metrics

| Metric | Before | Current | Target | Status |
|--------|--------|---------|--------|--------|
| Largest ViewModel | 1,864 lines | 867 lines | <500 lines | 🟡 Improved (-53%) |
| Largest View file | 1,560 lines | 1,293 lines | <400 lines | 🟡 Improved (-17%) |
| Duplicate form state structs | 2 | 1 | 1 | ✅ Complete |
| Duplicate category components | 4 | 2 | 2 | ✅ Complete |
| Duplicate checkbox implementations | 4 | 1 | 1 | ✅ Complete (Phase 4) |
| Duplicate thumbnail implementations | 3 | 1 | 1 | ✅ Complete (Phase 4) |
| Duplicate action button implementations | 3 | 1 | 1 | ✅ Complete (Phase 4) |
| Business logic in Models | ~15 methods | 0 | 0 | ✅ Complete |
| ViewModel composition | Monolithic | 5 focused VMs | Modular | ✅ Complete (Phase 1) |
| OnboardingFlowView modular | 1,385 lines | 237 lines | <200 lines | ✅ Complete (Phase 2) |
| SettingsView modular | 1,094 lines | ~200 lines | <200 lines | ✅ Complete (Phase 3) |

---

## Implementation Order

1. **Quick Wins** - Same day (file moves, simple fixes)
2. **Phase 4** - Component consolidation (low risk, high reward)
3. **Phase 1** - DashboardViewModel split (high impact)
4. **Phase 2 & 3** - View splits (medium complexity)
5. **Phase 5** - Model cleanup (requires careful testing)
6. **Phase 6** - Polish and naming (lowest priority)
