# Implementation Brief: Forma Dashboard Phase 2 - Batch Operations & Efficiency

## Context
Phase 2 builds on the action-oriented foundation from Phase 1 by adding batch operations and efficiency features. Users who have many files to organize need the ability to process multiple files at once, with full undo support.

## Prerequisites
- Phase 1 completed (Filter tabs, card layout, keyboard shortcuts, basic undo)
- `FileActionCard` component exists
- `ToastNotification` system functional
- Basic keyboard shortcuts working

## Phase 2 Goals

Users should be able to:
1. Select multiple files using checkboxes
2. Perform bulk operations on selected files
3. Undo/redo multiple operations
4. Process files more efficiently than one-by-one

## New Features

### 1. Selection System

#### Checkbox UI (appears on card hover or when any item selected)

```swift
// Before selection:
┌────────────────────────────────────┐
│  🖼️ [Thumbnail]                    │  ← No checkbox
│  Screenshot.png                    │
│  PNG • 1.2 MB                      │
│  📁→ Documents/Screenshots         │
│  [✓ Organize] [✏️ Edit] [•••]     │
└────────────────────────────────────┘

// On hover OR when ≥1 file selected:
┌────────────────────────────────────┐
│ ☐ 🖼️ [Thumbnail]                  │  ← Checkbox appears
│   Screenshot.png                   │
│   PNG • 1.2 MB                     │
│   📁→ Documents/Screenshots        │
│   [✓ Organize] [✏️ Edit] [•••]    │
└────────────────────────────────────┘

// When selected:
┌────────────────────────────────────┐
│ ☑ 🖼️ [Thumbnail]                  │  ← Checked + highlight
│   Screenshot.png                   │  ← Card has subtle blue bg
│   PNG • 1.2 MB                     │
│   📁→ Documents/Screenshots        │
│   [Actions disabled while selected]│
└────────────────────────────────────┘
```

#### Selection Controls (top of content area)

```swift
// Add to top of file list, before cards:
┌─────────────────────────────────────────────────────────┐
│ Needs Review (23)           [☐ Select All] 🎴 📋 ⊞    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  File cards below...                                   │
```

**Implementation**:
```swift
// DashboardViewModel additions
@Published var selectedFileIDs: Set<String> = []
@Published var isSelectionMode: Bool = false

func toggleSelection(for file: FileItem)
func selectAll()
func deselectAll()
func isSelected(_ file: FileItem) -> Bool
```

### 2. Floating Action Bar

#### Appears when ≥1 file selected

```swift
// Sticky bar (stays visible while scrolling)
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    ┌────────────────────────────────┐  │
│                    │ 3 files selected               │  │
│                    │ [✓ Organize All] [✕ Skip All] │  │
│                    │ [✏️ Bulk Edit]   [Deselect]   │  │
│                    └────────────────────────────────┘  │
│                           ↑                            │
│                      Floating bar                      │
│                                                         │
│  ☑ Card 1...                                           │
│  ☑ Card 2...                                           │
│  ☐ Card 3...                                           │
│  ☑ Card 4...                                           │
└─────────────────────────────────────────────────────────┘
```

**Features**:
- Fixed position (stays visible during scroll)
- Shows selection count
- Context-aware buttons based on selected files
- Appears with slide-down animation
- Disappears when all files deselected

**Implementation**:
```swift
// New component
struct FloatingActionBar: View {
    let selectedCount: Int
    let onOrganizeAll: () -> Void
    let onSkipAll: () -> Void
    let onBulkEdit: () -> Void
    let onDeselect: () -> Void
    
    var body: some View {
        // Sticky bar with actions
    }
}
```

### 3. Bulk Operations

#### Organize All (when all selected have same destination)

```swift
// If all 3 selected files → "Documents/Screenshots":
[✓ Organize All (3)]

// Action:
- Move all files to suggested destination
- Show single toast: "3 files organized"
- Add single undo action: "Undo organize 3 files"
- Deselect all after completion
```

#### Skip All

```swift
[✕ Skip All]

// Action:
- Mark all selected files as skipped (status = .skipped)
- Show toast: "Skipped 3 files"
- Add undo action
- Deselect all
```

#### Bulk Edit (when selected files have different destinations)

```swift
// Opens modal:
┌────────────────────────────────────────┐
│  Edit Destination for 3 Files          │
├────────────────────────────────────────┤
│  Current suggestions:                  │
│  • Screenshot.png → Pictures           │
│  • Document.pdf → Documents            │
│  • Project.zip → Archives              │
│                                        │
│  Override with:                        │
│  [Documents ▼]                         │
│   ├─ Documents                         │
│   ├─ Downloads                         │
│   ├─ Desktop                           │
│   ├─ Pictures                          │
│   └─── (Recent folders)                │
│                                        │
│  Or create new folder:                 │
│  ~/Documents/[_________]               │
│  [📁 Browse...]                        │
│                                        │
│  ☐ Apply this rule to future files    │
│     matching these extensions          │
│                                        │
│           [Cancel]  [Move All (3)]     │
└────────────────────────────────────────┘

// "Apply this rule" checkbox:
- If checked, creates rules for each file type
- e.g., "PNG files → Pictures", "PDF files → Documents"
```

**Implementation**:
```swift
// DashboardViewModel
func organizeSelectedFiles()
func skipSelectedFiles()
func bulkEditDestination(_ destination: String, createRules: Bool)

// Validation:
- Check all selected files exist
- Verify destination is valid path
- Handle mixed file types gracefully
```

### 4. Enhanced Undo/Redo Stack

#### Multi-Operation Support

```swift
// Undo stack structure
struct OrganizationAction {
    let id: UUID
    let type: ActionType
    let files: [FileActionData]
    let timestamp: Date
    
    enum ActionType {
        case organize(destination: String)
        case skip
        case delete
        case bulkOrganize(destinations: [String: String]) // fileID: destination
    }
}

struct FileActionData {
    let fileID: String
    let originalPath: String
    let originalStatus: OrganizationStatus
    let originalSuggestedDestination: String?
}
```

#### Undo Stack UI Enhancement

```swift
// When Cmd+Z is pressed, show more detail in toast:
┌────────────────────────────────────┐
│ ↶ Undone: Organized 3 files       │
│   [Redo]                      [×]  │
└────────────────────────────────────┘

// Toast variations:
- Single file: "Undone: Moved Screenshot.png"
- Multiple: "Undone: Organized 3 files"
- Skip action: "Undone: Skipped 5 files"
- Redo: "Redone: Organized 3 files"
```

#### Undo Implementation

```swift
// DashboardViewModel additions
private var undoStack: [OrganizationAction] = []
private var redoStack: [OrganizationAction] = []
private let maxUndoStackSize = 20

func undoLastAction() {
    guard let action = undoStack.popLast() else { return }
    
    // Reverse the action
    switch action.type {
    case .organize(let destination):
        // Move files back from destination to original location
        reverseOrganize(action.files, from: destination)
    case .skip:
        // Unmark as skipped
        reverseSkip(action.files)
    case .bulkOrganize(let destinations):
        // Move each file back
        reverseBulkOrganize(action.files, destinations: destinations)
    }
    
    redoStack.append(action)
    showUndoToast(for: action)
}

func redoLastAction() {
    guard let action = redoStack.popLast() else { return }
    // Re-apply the action
    reapplyAction(action)
    undoStack.append(action)
    showRedoToast(for: action)
}
```

### 5. Keyboard Shortcuts (Additions)

```swift
// Selection
Cmd+A: Select all visible files
Cmd+D: Deselect all
Cmd+Click: Toggle individual selection
Shift+Click: Select range

// Batch operations (when files selected)
Cmd+Enter: Organize all selected
Cmd+Delete: Skip all selected
Cmd+E: Bulk edit destination

// Undo/Redo
Cmd+Z: Undo last action
Cmd+Shift+Z: Redo last action
```

### 6. Selection State Management

#### Persistence Rules

```swift
// Selection behavior:
- Selections clear when switching categories ❌
- Selections persist when switching secondary filters ✅
- Selections clear when toggling Needs Review/All Files ❌
- Selections clear after bulk operation ✅
```

**Why these rules**:
- Category switch = different context, clear selection
- Secondary filter = same files, different order, keep selection
- Needs Review toggle = different file set, clear selection
- After bulk operation = task complete, fresh start

#### Visual Feedback

```swift
// Selected card appearance:
- Background: Steel Blue at 5% opacity
- Border: 1px Steel Blue
- Checkbox: Filled with checkmark
- Actions: Disabled (grayed out)

// Hover state while in selection mode:
- Cursor: pointer
- Checkbox: Highlight on hover
- Entire card clickable (not just checkbox)
```

## Implementation Checklist

### Components to Create
- [ ] `SelectionCheckbox` - Checkbox component for cards
- [ ] `FloatingActionBar` - Sticky action bar
- [ ] `BulkEditSheet` - Modal for bulk destination editing
- [ ] `SelectAllButton` - Toggle for selecting all
- [ ] Enhanced `ToastNotification` - Support undo/redo messages

### ViewModels to Modify
- [ ] `DashboardViewModel`
  - [ ] Add `selectedFileIDs: Set<String>`
  - [ ] Add `isSelectionMode: Bool`
  - [ ] Add `undoStack: [OrganizationAction]`
  - [ ] Add `redoStack: [OrganizationAction]`

### Methods to Implement
```swift
// Selection
func toggleSelection(for file: FileItem)
func selectAll()
func deselectAll()
func selectRange(from: FileItem, to: FileItem)

// Bulk operations
func organizeSelectedFiles()
func skipSelectedFiles()
func bulkEditDestination(_ destination: String, createRules: Bool)

// Undo/Redo
func undoLastAction()
func redoLastAction()
func canUndo() -> Bool
func canRedo() -> Bool
func reverseOrganize(_ files: [FileActionData], from: String)
func reverseBulkOrganize(_ files: [FileActionData], destinations: [String: String])
```

### FileActionCard Modifications
- [ ] Add checkbox to card
- [ ] Add selection state styling
- [ ] Disable actions when selected
- [ ] Add click handler for entire card (in selection mode)
- [ ] Show/hide checkbox based on selection mode

## Testing Scenarios

### Selection
1. ✅ Click checkbox selects file
2. ✅ Cmd+A selects all visible
3. ✅ Shift+Click selects range
4. ✅ Selection clears on category change
5. ✅ Selection persists on secondary filter change

### Bulk Operations
6. ✅ Organize All moves all files to suggested destinations
7. ✅ Skip All marks all as skipped
8. ✅ Bulk Edit opens modal with correct file count
9. ✅ Bulk Edit with "Create Rules" creates appropriate rules
10. ✅ Selection clears after bulk operation

### Undo/Redo
11. ✅ Cmd+Z undoes last single operation
12. ✅ Cmd+Z undoes last bulk operation
13. ✅ Cmd+Shift+Z redoes operation
14. ✅ Undo stack limited to 20 operations
15. ✅ Files restored to original paths on undo
16. ✅ Toast shows correct undo/redo message

### Floating Action Bar
17. ✅ Bar appears when ≥1 file selected
18. ✅ Bar disappears when all deselected
19. ✅ Bar stays visible while scrolling
20. ✅ Selection count updates in real-time

## Edge Cases to Handle

### Mixed Destinations
```swift
// 3 files selected:
// - File1 → Documents
// - File2 → Documents  
// - File3 → Pictures

// "Organize All" should be disabled
// Only "Bulk Edit" and "Skip All" available
```

### Some Files Without Suggestions
```swift
// 3 files selected:
// - File1 → Documents
// - File2 → (no suggestion)
// - File3 → Pictures

// "Organize All" organizes only File1 and File3
// File2 remains unorganized
// Show toast: "Organized 2 of 3 files"
```

### Undo with Deleted Files
```swift
// If original file location no longer exists:
// - Show error toast
// - Remove from undo stack
// - Don't crash
```

### Selection During Refresh
```swift
// If user refreshes file list while files selected:
// - Clear selection
// - Hide floating action bar
// - Reset selection mode
```

## Success Criteria

Phase 2 complete when:
- ✅ User can select multiple files via checkbox
- ✅ Bulk operations work on all selected files
- ✅ Undo/redo handles both single and bulk operations
- ✅ Keyboard shortcuts for selection work correctly
- ✅ Floating action bar provides clear feedback
- ✅ Edge cases handled gracefully
- ✅ Performance remains smooth with 100+ files selected

## Performance Considerations

### Optimization Strategies
1. **Lazy rendering**: Only render visible checkboxes
2. **Debouncing**: Batch selection state updates
3. **Background threading**: File operations on background queue
4. **Progress feedback**: Show progress for bulk operations on >10 files

### Progress Indicator for Large Batches
```swift
// When organizing >10 files:
┌────────────────────────────────────┐
│ Organizing 47 files...             │
│ ████████████░░░░░░░░░░ 60%        │
│ (28 of 47)                         │
│                                    │
│ [Cancel]                           │
└────────────────────────────────────┘
```

## Notes
- Use `@State` for local selection state, `@Published` for shared state
- Animations should be subtle (0.2s duration)
- Test with 100+ files to verify performance
- Ensure undo stack doesn't cause memory leaks
- File operations should be atomic (all succeed or all fail)

---

**Start with selection system and floating action bar, then implement bulk operations. Add undo/redo enhancements last.**
