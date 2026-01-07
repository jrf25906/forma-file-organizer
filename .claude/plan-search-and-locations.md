# UI Changes Plan: Search Box & Location Ordering

## Current State Summary

### Search Box
- **Location**: Top of `SidebarView.swift` (line 29)
- **Component**: `CompactSearchField` with dynamic placeholder ("Search {count} files...")
- **Behavior**: Static always-visible field; collapses to icon-only when sidebar collapses
- **State flow**: Binds to `nav.searchText` → `DashboardViewModel.updateSearchText()` → `FileFilterManager`

### Locations Section
- **Location**: `SidebarView.swift` lines 37-51
- **Data source**: `dashboardViewModel.customFolders`
- **Current ordering**: Sorted by `creationDate` ascending (oldest first)
- **Model**: `CustomFolder` with id, name, path, bookmarkData, creationDate, isEnabled

### Toolbar
- **Location**: `UnifiedToolbar.swift`, placed in `MainContentView.swift` line 120
- **Current contents**: Mode toggles (Pending/All), View types (Grid/List/Tile), Grouping controls
- **Responsive**: Has compression levels for different widths (none/medium/compact)

---

## Change 1: Move Search to Toolbar

### Rationale
Search doesn't warrant permanent sidebar real estate. Moving it to the toolbar:
- Saves vertical space in sidebar for locations
- Matches macOS conventions (toolbar search fields)
- Can expand/collapse on demand

### Chosen Approach: macOS Window Toolbar

Place search in the **native macOS window toolbar** (top bar near window controls):
- Use `.searchable(text:placement:)` SwiftUI modifier with `.toolbar` placement
- Native macOS look and feel
- Automatically handles Cmd+F focus
- Appears in the window's title bar area, not the content toolbar

### Files to Modify
1. `SidebarView.swift` - Remove CompactSearchField
2. `MainContentView.swift` or `Forma_File_OrganizingApp.swift` - Add `.searchable()` modifier
3. `CompactSearchField.swift` - Can be removed (no longer needed)

---

## Change 2: Location Ordering Strategy

### Current Problem
Locations are ordered by creation date (oldest first). This may not match user mental models or usage patterns.

### Ordering Philosophy Options

**Option A: Fixed Semantic Order (Recommended)**
Group locations by type with a logical hierarchy:
```
LOCATIONS
├── System Folders (if added)
│   ├── Desktop
│   ├── Downloads
│   ├── Documents
│   ├── Pictures
│   ├── Music
│   └── Movies
└── Custom Folders
    └── [alphabetical or by creation date]
```

Benefits:
- Predictable, learnable
- Matches Finder's sidebar convention
- System folders always accessible at top

**Option B: User-Adjustable Order (Drag & Drop)**
- Store `sortOrder: Int` on CustomFolder model
- Enable drag-to-reorder in sidebar
- Persist order across sessions

Benefits:
- User control
- Personal workflow optimization

Drawbacks:
- More complex implementation
- Requires model migration
- Users may not care enough to customize

**Option C: Smart/Usage-Based Order**
- Track folder access frequency
- Auto-sort by most recently/frequently used
- Optional "pin" feature for favorites

Benefits:
- Adapts to workflow automatically

Drawbacks:
- Unpredictable for users
- May feel "magic" in a bad way

### Recommendation: Option A (Fixed Semantic) with Future Option B

Start with a thoughtful fixed order:
1. **System-recognized paths** (Desktop, Downloads, Documents, Pictures, Music, Movies) appear first in that canonical order
2. **Custom folders** appear below, sorted alphabetically by name

This is simple, predictable, and matches user expectations. We can add drag-to-reorder in a future version if users request it.

### Implementation
1. Modify `loadCustomFolders()` in `DashboardViewModel.swift`
2. Add a sorting function that:
   - Checks folder path against known system paths
   - Assigns priority based on path type
   - Falls back to alphabetical for custom folders

---

## Decisions Made

- **Search placement**: macOS window toolbar (native `.searchable()`)
- **Location order**: Fixed semantic (system folders first, then custom alphabetically)
- **System folder priority**: Desktop → Downloads → Documents → Pictures → Music → Movies
- **Custom folder sort**: Alphabetical by name

---

## Implementation Sequence

### Phase 1: Search to macOS Toolbar
1. Add `.searchable(text: $nav.searchText, placement: .toolbar)` to NavigationSplitView
2. Remove `CompactSearchField` from `SidebarView`
3. Delete `CompactSearchField.swift` (no longer needed)
4. Verify Cmd+F works automatically (built into .searchable)

### Phase 2: Location Ordering
1. Create `folderSortPriority(for path: String) -> Int` utility
2. Modify `loadCustomFolders()` to use new sort logic
3. Test with various folder combinations

---

## Visual Mockup (ASCII)

### Window After Change
```
┌─────────────────────────────────────────────────────────────────────────┐
│ 🔴🟡🟢  Forma                              [🔍 Search...]              │  ← macOS window toolbar
├─────────────────────────────────────────────────────────────────────────┤
│ LOCATIONS    │  [Pending|All Files]  │  [Grid|List|Tile] | [Group ▼]   │
│ ├─ Desktop   │                                                          │
│ ├─ Downloads │  [File content area...]                                  │
│ └─ + Add     │                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Sidebar After Change (Locations Section)
```
LOCATIONS
├── Desktop          (if added - system priority 1)
├── Downloads        (if added - system priority 2)
├── Documents        (if added - system priority 3)
├── Pictures         (if added - system priority 4)
├── My Projects      (custom - alphabetical)
├── Work Files       (custom - alphabetical)
└── + Add Location
```
