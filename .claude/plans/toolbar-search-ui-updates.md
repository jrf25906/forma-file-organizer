# Plan: Native macOS Toolbar Search & Right Panel Toggle

## Overview
Update the toolbar to match native macOS patterns:
1. **Expandable Search Field** - Finder-style search that expands on click
2. **Right Panel Toggle** - Xcode-style positioning in top-right corner

---

## Current State Analysis

### Search Field (DashboardView.swift:56-68)
- **Current**: Fixed-width (180px) always-visible TextField with custom styling
- **Placement**: `.automatic` - appears in center-left of toolbar
- **Issue**: Doesn't match Finder's expandable search behavior

### Right Panel Toggle (DashboardView.swift:71-82)
- **Current**: Uses `.primaryAction` placement with `sidebar.right` icon
- **Placement**: Should be far-right, but may not match Xcode exactly
- **Keyboard Shortcut**: `⌘⌥0` (correct)

---

## Implementation Plan

### Phase 1: Expandable Search Field (Finder-style)

#### Option A: Native NSSearchToolbarItem (Recommended)
Use `NSViewRepresentable` to wrap `NSSearchField` with toolbar integration for authentic macOS behavior.

**Files to create:**
- `Components/ExpandableSearchField.swift` - NSViewRepresentable wrapper

**Files to modify:**
- `DashboardView.swift` - Replace current search ToolbarItem

**Behavior:**
1. **Collapsed state**: Shows as compact search icon button
2. **Expanded state**: Animates to full search field (like Finder)
3. **Auto-collapse**: When losing focus with empty text
4. **Maintain expanded**: When search text is present

#### Option B: Pure SwiftUI Custom Implementation
Create a custom expandable search using SwiftUI animations.

**Trade-offs:**
| Aspect | Option A (NSSearchToolbarItem) | Option B (Pure SwiftUI) |
|--------|-------------------------------|------------------------|
| Native feel | Exact Finder behavior | Close approximation |
| Complexity | Medium (AppKit bridging) | Medium (animation logic) |
| Consistency | Perfect macOS integration | May differ slightly |
| Maintainability | Relies on AppKit APIs | Pure SwiftUI |

**Recommendation**: Option A for authentic Finder behavior

---

### Phase 2: Right Panel Toggle Positioning

#### Verify/Adjust Placement
The toggle should be in the **exact** top-right corner like Xcode's Inspector toggle.

**Current placement**: `.primaryAction`
**Required**: May need `.confirmationAction` or custom positioning

**Investigation needed:**
- Check if `.primaryAction` already matches Xcode positioning
- If not, explore `.confirmationAction` or `.navigation` placements
- Consider using `ToolbarItemGroup` for precise control

---

### Phase 3: Enhanced Search Functionality

#### Current Search Flow
```
TextField → nav.searchText → FilterManager → visibleFiles (filename only)
```

#### Enhanced Search Flow
```
SearchField → SearchService → [Filename + Content Search] → visibleFiles + highlights
```

**Files to create:**
- `Services/ContentSearchService.swift` - File content indexing & search

**Files to modify:**
- `FilterManager.swift` - Integrate content search results
- `MainContentView.swift` - Highlight matching content in results

**Content Search Approach:**
1. **Spotlight Integration** (NSMetadataQuery) - Use macOS Spotlight for content search
2. **Fallback**: Direct file content scanning for non-indexed files

**Result Display:**
- Inline in current view (as requested)
- Visual indicator showing match type (filename vs content)
- Snippet preview for content matches

---

## Detailed File Changes

### 1. New: `ExpandableSearchField.swift`
```swift
// Location: Forma File Organizing/Components/ExpandableSearchField.swift

struct ExpandableSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isExpanded: Bool
    var onSubmit: () -> Void

    // Wraps NSSearchField with expansion animation
    // Mimics Finder toolbar search behavior
}
```

### 2. Modify: `DashboardView.swift`

**Remove** (Lines 56-68):
- Current custom search HStack in ToolbarItem

**Add**:
- ExpandableSearchField with `.automatic` placement
- Binding to `nav.searchText`
- State for `isSearchExpanded`

**Adjust** (Lines 71-82):
- Verify right panel toggle placement matches Xcode
- Consider `ToolbarItemGroup(placement: .primaryAction)` for grouping

### 3. New: `ContentSearchService.swift`
```swift
// Location: Forma File Organizing/Services/ContentSearchService.swift

@MainActor
final class ContentSearchService: ObservableObject {
    func search(query: String, in files: [FileItem]) async -> [SearchResult]

    struct SearchResult {
        let file: FileItem
        let matchType: MatchType // .filename, .content, .both
        let contentSnippet: String?
        let matchRanges: [Range<String.Index>]
    }
}
```

### 4. Modify: `FilterManager.swift`
- Integrate ContentSearchService results
- Combine filename and content matches
- Maintain existing debounce logic

---

## Testing Checklist

### Search Field
- [ ] Collapsed: Shows as icon button matching Finder
- [ ] Click expands with smooth animation
- [ ] Typing keeps field expanded
- [ ] Clear text + lose focus → collapses
- [ ] Keyboard shortcut (⌘F) focuses search
- [ ] Escape key clears and collapses

### Right Panel Toggle
- [ ] Position matches Xcode's Inspector toggle exactly
- [ ] Icon: `sidebar.right` (filled when panel visible)
- [ ] Animation: Spring animation on toggle
- [ ] Keyboard shortcut: ⌘⌥0 works

### Content Search
- [ ] Filename matches appear instantly
- [ ] Content matches appear (may have slight delay)
- [ ] Results show match type indicator
- [ ] Content snippets show relevant context
- [ ] Performance acceptable for large file sets

---

## Implementation Order

1. **Phase 1A**: Create ExpandableSearchField component
2. **Phase 1B**: Integrate into DashboardView toolbar
3. **Phase 2**: Verify/fix right panel toggle positioning
4. **Phase 3A**: Create ContentSearchService
5. **Phase 3B**: Integrate content search with FilterManager
6. **Phase 3C**: Add match type indicators to file list

---

## Decisions (Confirmed)

1. **Search keyboard shortcut**: ✅ `⌘F` focuses the search field

2. **Content search scope**:
   - ✅ All files in current view
   - ✅ Use Spotlight metadata when available (NSMetadataQuery)
   - Fallback to direct content scan for non-indexed files

3. **Search result indication**:
   - ✅ Badge/icon indicating match type (filename vs content)
   - ✅ Snippet preview in file row for content matches

4. **Performance strategy**:
   - File size limit: Skip content scan for files > 10MB
   - Show "Searching content..." indicator for > 50 files
   - Debounce content search (300ms after typing stops)
   - Cancel previous search when new query starts
   - Prioritize Spotlight results (faster) over direct file scan
