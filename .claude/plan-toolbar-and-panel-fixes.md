# UI Fixes Plan: Toolbar, Search, Right Panel Toggle, Duplicate Desktop

## Issues from Screenshot

### Issue 1: Right Panel Toggle Position
**Current**: Toggle button is in the window toolbar (near traffic lights)
**Expected**: Toggle should be on the LEFT side of the right panel content (like a collapse/expand button at the panel edge)

### Issue 2: Search Bar
**Current**: Search field appears statically in the right panel header area
**Expected**: Search should be an expandable button in the RIGHT corner of the window toolbar

### Issue 3: Right Panel Content Overlap
**Current**: Right panel content starts at the very top, overlapping with toolbar area
**Expected**: Right panel content should have top padding/offset to avoid toolbar interference

### Issue 4: Duplicate Desktop
**Current**: Two "Desktop" entries showing in the sidebar LOCATIONS
**Root Cause**: Likely duplicate entries in SwiftData (path is not unique in CustomFolder model)

---

## Fix 1: Right Panel Toggle Position

### Approach
Move the toggle button OUT of the window toolbar and INTO the right panel itself. Place it at the top-left corner of the right panel with a visual affordance.

### Implementation
1. Remove `toolbarContent` from DashboardView's `.toolbar {}`
2. Add toggle button to `RightPanelView` at top-left position
3. Pass `isRightPanelVisible` binding to RightPanelView
4. When panel is hidden, show a floating collapse button at the right edge of the window

### Files to Modify
- `DashboardView.swift` - Remove toolbar toggle, pass binding to RightPanelView
- `RightPanelView.swift` - Add toggle button at top-left

---

## Fix 2: Expandable Search Button

### Approach
Replace the `.searchable()` modifier with a custom expandable search button in the window toolbar.

### Implementation
1. Remove `.searchable()` modifier from DashboardView
2. Add a custom toolbar item with a search icon button
3. When clicked, expand to show a search field with animation
4. Bind to `nav.searchText`
5. Collapse back to icon when focus is lost and text is empty

### Visual Behavior
```
[Collapsed]        [Expanded]
    🔍         →   🔍 [Search files...]  ✕
```

### Files to Modify
- `DashboardView.swift` - Replace .searchable() with custom toolbar search
- May need new `ExpandableSearchField.swift` component

---

## Fix 3: Right Panel Top Padding

### Approach
Add top padding to RightPanelView content to account for window toolbar height.

### Implementation
1. Add `FormaSpacing.Toolbar.topOffset` or similar spacing at top of RightPanelView
2. Ensure this only applies when content could overlap with window chrome

### Files to Modify
- `RightPanelView.swift` - Add top spacing

---

## Fix 4: Duplicate Desktop Entries

### Root Cause Analysis
The `CustomFolder` model marks only `id` as unique (`@Attribute(.unique)`), but `path` is NOT unique. This allows multiple entries with the same path.

### Solution Options

**Option A: Database Cleanup + Path Uniqueness (Recommended)**
1. Add deduplication logic in `loadCustomFolders()` to filter out duplicates by path
2. Optionally: Add migration to clean existing duplicates
3. Future: Consider making `path` unique in the model

**Option B: Immediate Deduplication in loadCustomFolders()**
After fetching folders, deduplicate by path keeping the first (oldest) entry:
```swift
// Deduplicate by path (keep first entry)
var seenPaths = Set<String>()
fetchedFolders = fetchedFolders.filter { folder in
    if seenPaths.contains(folder.path) {
        return false
    }
    seenPaths.insert(folder.path)
    return true
}
```

### Files to Modify
- `DashboardViewModel.swift` - Add deduplication in `loadCustomFolders()`
- Optionally: `CustomFolder.swift` - Make path unique

---

## Implementation Sequence

### Phase 1: Fix Duplicate Desktop (Quick Fix)
1. Add path deduplication in `loadCustomFolders()`
2. Verify only one Desktop shows

### Phase 2: Right Panel Top Padding
1. Add top spacing to RightPanelView
2. Verify content doesn't overlap toolbar

### Phase 3: Move Toggle to Right Panel
1. Remove toolbar toggle from DashboardView
2. Add toggle to RightPanelView top-left
3. Handle collapsed state (floating button)

### Phase 4: Expandable Search
1. Remove .searchable() modifier
2. Create ExpandableSearchField component
3. Add to toolbar with proper positioning

---

## Visual Mockup (After Fixes)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 🔴🟡🟢  Forma                                                    [🔍]  │  ← Search icon (expandable) in right corner
├─────────────────────────────────────────────────────────────────────────┤
│ LOCATIONS    │  [Pending|All Files]  │  [Grid|List|Tile]   │ [◀️] Panel │
│ ├─ Desktop   │                                              │   Content  │
│ ├─ Downloads │  [File content area...]                      │   ...      │
│ └─ + Add     │                                              │            │
└─────────────────────────────────────────────────────────────────────────┘
                                                               ↑
                                                        Toggle at left edge
                                                        of right panel
```
