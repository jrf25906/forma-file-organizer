# Implementation Brief: Forma Dashboard Phase 1 - Action-Oriented File Organization

## Context
We're refactoring the Forma dashboard center panel to be action-oriented rather than passive. The app's primary purpose is to help users organize desktop files, so the UI should emphasize **files that need action** rather than just displaying a chronological list.

## Current State Issues
- Center panel shows chronological file list (too passive)
- No clear call-to-action for organizing files
- Category filters are in wrong location (left sidebar instead of center)
- Missing visual hierarchy for files needing attention
- No keyboard shortcuts for rapid file processing

## Design Decisions Made

### Layout Structure
```
LEFT SIDEBAR          CENTER PANEL                           RIGHT SIDEBAR
───────────          ─────────────────────────────────      ──────────────
Locations:           [All][Documents][Images][Videos]...    Storage Chart
• Desktop            ───────────────────────────────────    
• Downloads          [Recent][Large Files][Flagged]         Activity Feed
• Documents          ───────────────────────────────────
• Pictures           [ Needs Review (23) | All Files (156) ]
• Music              
                     📋 Files ready to organize
                     ┌────────────────────────────────┐
                     │ Action-focused file cards      │
                     └────────────────────────────────┘
```

### Key Changes
1. **Category tabs** move from left sidebar to top of center panel
2. **Secondary filter tabs** (Recent, Large Files, Flagged) stay below categories
3. **Needs Review / All Files toggle** added as segmented control
4. **Card-based layout** (3 cards visible + partial 4th for scroll affordance)
5. **Context-aware action buttons** based on whether file has suggestion

## Phase 1 Requirements

### 1. Filter Tab System (Top of Center Panel)

#### Category Tabs (Primary Filter)
```swift
// 6 categories with file counts
[All (156)] [Documents (35)] [Images (25)] [Videos (20)] [Audio (12)] [Archives (8)]

// Features:
- Active state: Steel Blue accent color
- Badge showing file count per category
- Smooth transition on category change
```

#### Secondary Filter Tabs
```swift
// Below category tabs
[Recent] [Large Files] [Flagged]

// Implementation:
- Works within selected category
- Recent: Show files sorted by date added
- Large Files: Show files > 10MB
- Flagged: Show user-marked files (future feature)
```

#### Needs Review Toggle (Segmented Control)
```swift
// Below secondary tabs
┌─────────────────┬─────────────────┐
│ Needs Review 23 │   All Files 156 │
└─────────────────┴─────────────────┘

// Logic:
- Needs Review: Files where suggestedDestination == nil
- All Files: All files in current category
- Done files (status == .done) hidden by default
```

### 2. Card-Based File Display

#### Card Layout (3 visible + partial 4th)
```swift
// Each card shows:
┌────────────────────────────────────┐
│  [Thumbnail/Icon - Clickable]      │  ← Click for Quick Look
│  Filename.ext                      │
│  Type • Size • Time ago            │
│                                    │
│  📁→ Suggested/Destination         │  ← Only if has suggestion
│  OR                                │
│  ⚠️ No matching rules              │  ← If no suggestion
│                                    │
│  [Context-aware buttons]           │
└────────────────────────────────────┘
```

#### Context-Aware Action Buttons

**When file HAS suggestion:**
```swift
┌─────────────────────────────────────┐
│  📁→ Documents/Screenshots          │
│                                     │
│  [✓ Organize]  [✏️ Edit]  [•••]   │
└─────────────────────────────────────┘

// Overflow menu (•••):
├─ ✕ Skip this file
├─ 📋 View matching rule
└─ 🔄 Refresh suggestion
```

**When file has NO suggestion:**
```swift
┌─────────────────────────────────────┐
│  ⚠️ No matching rules               │
│                                     │
│  [➕ Create Rule]  [✏️ Manual] [•••]│
└─────────────────────────────────────┘

// Overflow menu (•••):
└─ ✕ Skip this file

// "Create Rule" should:
// - Open rule creation modal
// - Pre-fill with file's extension as condition
// - Pre-populate suggested destination if possible
```

### 3. Quick Look Integration

```swift
// Thumbnail/Icon click behavior:
- Click thumbnail → Opens macOS Quick Look
- Show eye icon (👁️) overlay on hover
- No separate Preview button needed

// Use NSWorkspace or QLPreviewPanel
// Example:
QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
```

### 4. Keyboard Shortcuts (Critical for Flow)

```swift
// Navigation
↓/↑ or J/K: Next/Previous file (focus)
Tab: Cycle through cards

// Actions (on focused card)
Enter/Return: Organize file
Space: Quick Look preview
E: Edit destination
S: Skip file
R: View/edit rule
Cmd+Enter: Organize and move to next

// Undo
Cmd+Z: Undo last organization
Cmd+Shift+Z: Redo

// Implement using:
.keyboardShortcut() modifier
.onKeyPress() for single keys
```

### 5. Toast Notifications & Undo

```swift
// Toast appears bottom-right after action
┌────────────────────────────────────┐
│ ✓ Screenshot moved to Pictures    │
│   [Undo]                      [×]  │
└────────────────────────────────────┘

// Features:
- Auto-dismiss after 5 seconds
- Click [Undo] to reverse action
- Cmd+Z also triggers undo
- Support undo stack (last 10 operations)
- Show file name + destination in message
```

### 6. Edit Destination Flow

```swift
// When user clicks [✏️ Edit]:
┌────────────────────────────────────┐
│  Edit Destination                  │
├────────────────────────────────────┤
│  Current: Documents/Screenshots    │
│                                    │
│  Move to:                          │
│  [Documents ▼]                     │
│   ├─ Recent folders shown          │
│   ├─ Downloads                     │
│   └─ Desktop                       │
│                                    │
│  Or create new folder:             │
│  [_________________] [Browse...]   │
│                                    │
│         [Cancel]  [Save]           │
└────────────────────────────────────┘
```

## Files to Reference

Based on uploaded architecture docs:

### Existing Files
- `ARCHITECTURE.md` - Protocol-based RuleEngine design
- `DASHBOARD.md` - Current dashboard documentation
- `RuleEngine-Architecture.md` - File/Rule protocols

### Key Models
- `FileItem` - SwiftData model (conforms to `Fileable`)
- `Rule` - SwiftData model (conforms to `Ruleable`)
- `FileTypeCategory` enum - Category definitions
- `OrganizationStatus` - Pending, Ready, Done, Skipped

### Services
- `RuleEngine` - Uses protocol-based generics
- `StorageService` - Analytics and filtering
- `FileSystemService` - File scanning

## Implementation Checklist

### New Components to Create
- [ ] `FilterTabBar` - Category tabs with counts
- [ ] `SecondaryFilterTabs` - Recent/Large/Flagged
- [ ] `NeedsReviewToggle` - Segmented control
- [ ] `FileActionCard` - Card view with context-aware buttons
- [ ] `ToastNotification` - Bottom-right notification
- [ ] `EditDestinationSheet` - Modal for editing destination
- [ ] `KeyboardShortcutHandler` - Centralized shortcut management

### ViewModels to Modify
- [ ] `DashboardViewModel` - Add filtering logic for Needs Review
- [ ] Add `selectedSecondaryFilter` property
- [ ] Add `showAllFiles` vs `showNeedsReview` state
- [ ] Add `undoStack: [OrganizationAction]`

### Methods to Implement
```swift
// DashboardViewModel
func organizeFile(_ file: FileItem, to: String)
func skipFile(_ file: FileItem)
func editDestination(_ file: FileItem, to: String)
func undoLastAction()
func createRuleFromFile(_ file: FileItem)
func showQuickLook(for file: FileItem)
func filterForNeedsReview() -> [FileItem]
func applySecondaryFilter(_ filter: SecondaryFilter)
```

## Design System Values

Use existing constants:
```swift
// Colors
Colors.steelBlue // Accent/Active state
Colors.obsidian // Primary text
Colors.boneWhite // Background

// Spacing
Spacing.tight // 8pt
Spacing.standard // 12pt
Spacing.generous // 16pt

// Typography
Typography.h2 // Section headers
Typography.body // Card content
Typography.small // Metadata
```

## Testing Scenarios

After implementation, verify:
1. ✅ Category tabs filter files correctly
2. ✅ Needs Review shows only files with no suggestion
3. ✅ Click thumbnail opens Quick Look
4. ✅ Enter key organizes focused card
5. ✅ Cmd+Z undoes last organization
6. ✅ Toast appears and auto-dismisses
7. ✅ Edit destination modal works
8. ✅ Create Rule pre-fills file extension
9. ✅ Keyboard shortcuts work as specified
10. ✅ Done files hidden by default

## Success Criteria

Phase 1 complete when:
- ✅ User can see at-a-glance which files need organizing
- ✅ Primary action (Organize) is one click/keystroke away
- ✅ Can process files rapidly with keyboard
- ✅ Mistakes are easily undoable
- ✅ No file gets "lost" - clear path for every scenario
- ✅ Interface feels responsive and action-oriented

## Notes
- Maintain protocol-based architecture (don't break Fileable/Ruleable)
- Keep SwiftData operations on @MainActor
- Use existing StorageAnalytics caching (60-second cache)
- Preserve three-column layout (240px left, 280px right)

---

**Start with FilterTabBar and NeedsReviewToggle, then build out FileActionCard component. Test keyboard shortcuts early since they're critical to the workflow.**
