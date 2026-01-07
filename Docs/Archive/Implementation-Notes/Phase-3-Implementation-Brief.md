# Implementation Brief: Forma Dashboard Phase 3 - View Modes & Personalization

## Context
Phase 3 adds view customization and personalization features, allowing users to tailor the interface to their workflow preferences. Different file types benefit from different viewing modes (e.g., images work well in grid view, documents in list view).

## Prerequisites
- Phase 1 completed (Card layout, keyboard shortcuts, basic UI)
- Phase 2 completed (Batch operations, selection system)
- `FileActionCard` component working
- Selection and bulk operations functional

## Phase 3 Goals

Users should be able to:
1. Switch between Card, List, and Grid view modes
2. Set different view preferences per category
3. Use advanced keyboard shortcuts for navigation and efficiency
4. Have preferences persist across app sessions

## New Features

### 1. View Mode Toggle

#### Toggle UI (top-right of center panel)

```swift
// Three view modes:
┌─────────────────────────────────────────────────────────┐
│ [All][Documents][Images]...              🎴 📋 ⊞       │
│                                          Card List Grid │
├─────────────────────────────────────────────────────────┤
```

**Implementation**:
```swift
enum ViewMode: String, Codable, CaseIterable {
    case card = "🎴"
    case list = "📋"
    case grid = "⊞"
    
    var displayName: String {
        switch self {
        case .card: return "Card"
        case .list: return "List"
        case .grid: return "Grid"
        }
    }
}

struct ViewModeToggle: View {
    @Binding var selectedMode: ViewMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: { selectedMode = mode }) {
                    Text(mode.rawValue)
                        .font(.system(size: 16))
                }
                .buttonStyle(ViewModeButtonStyle(isSelected: mode == selectedMode))
            }
        }
    }
}
```

### 2. Card View (Default - Already Implemented in Phase 1)

```swift
// Features:
- 3 cards visible + partial 4th
- Large thumbnails/icons
- Full action buttons visible
- Best for: Mixed file types, detailed review

┌────────────────────────────────────┐
│  🖼️ [Large Thumbnail]              │
│  Filename.ext                      │
│  Type • Size • Time ago            │
│  📁→ Suggested/Destination         │
│  [✓ Organize] [✏️ Edit] [•••]     │
└────────────────────────────────────┘
```

### 3. List View (Compact & Information-Dense)

```swift
// Compact rows with key info:
┌─────────────────────────────────────────────────────────┐
│ ☐ 📄 Document.pdf       PDF • 2.4 MB  Documents  [•••] │
│ ☐ 🖼️ Screenshot.png     PNG • 1.2 MB  Pictures   [•••] │
│ ☐ 📦 Archive.zip        ZIP • 5.1 MB  Archives   [•••] │
│ ☐ 📊 Spreadsheet.xlsx   XLS • 890 KB  Documents  [•••] │
└─────────────────────────────────────────────────────────┘

// Row layout:
[☐] [Icon] [Name] [Type • Size] [Suggestion] [Actions]

// Features:
- See 10-15 files at once
- Quick scan of file names
- Sortable columns (future enhancement)
- Best for: Documents, large file counts
```

**Implementation**:
```swift
struct FileListRow: View {
    let file: FileItem
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.standard) {
            // Checkbox
            SelectionCheckbox(isSelected: isSelected, onToggle: onToggleSelection)
            
            // File icon (small)
            FileIcon(extension: file.fileExtension, size: .small)
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Typography.body)
                    .foregroundColor(Colors.obsidian)
                
                Text(file.fileMetadataString)
                    .font(Typography.small)
                    .foregroundColor(Colors.obsidian.opacity(0.6))
            }
            
            Spacer()
            
            // Suggestion badge
            if let destination = file.suggestedDestination {
                SuggestionBadge(destination: destination)
            }
            
            // Actions menu
            Menu {
                Button("Organize", action: onOrganize)
                Button("Edit Destination", action: onEdit)
                Button("Skip", action: onSkip)
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        .padding(Spacing.standard)
        .background(isSelected ? Colors.steelBlue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}
```

### 4. Grid View (Visual & Hover-Based)

```swift
// Compact grid for visual scanning:
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ 🖼️   │ │ 📄   │ │ 🖼️   │ │ 📦   │ │ 🖼️   │
│Screen│ │Doc.  │ │Form. │ │magic │ │Shot2 │
│ 1.2MB│ │2.4MB │ │194KB │ │662KB │ │1.1MB │
│  ↓   │ │  ↓   │ │  ↓   │ │  ↓   │ │  ↓   │
│Pictr │ │Docs  │ │Pics  │ │Archs │ │Pictr │
└──────┘ └──────┘ └──────┘ └──────┘ └──────┘

// On hover - show actions overlay:
┌──────────────┐
│ 🖼️ Screenshot│
│ 1.2 MB       │
│ ↓ Pictures   │
│              │
│ [✓]  [✏️] [✕]│  ← Overlay appears
└──────────────┘

// Features:
- See 15-20 files at once
- Visual thumbnails for images
- Quick action buttons on hover
- Best for: Images, visual files
```

**Implementation**:
```swift
struct FileGridItem: View {
    let file: FileItem
    let isSelected: Bool
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            VStack(spacing: Spacing.tight) {
                // Thumbnail or icon
                if file.category == .images {
                    FileThumbnail(path: file.path)
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                } else {
                    FileIcon(extension: file.fileExtension, size: .large)
                        .frame(width: 120, height: 120)
                }
                
                // File name (truncated)
                Text(file.name)
                    .font(Typography.small)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                // File size
                Text(file.sizeString)
                    .font(.system(size: 10))
                    .foregroundColor(Colors.obsidian.opacity(0.5))
                
                // Suggestion indicator
                if let destination = file.suggestedDestination {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8))
                        Text(destination.lastPathComponent)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .foregroundColor(Colors.steelBlue)
                }
            }
            .padding(Spacing.tight)
            .frame(width: 140, height: 180)
            .background(isSelected ? Colors.steelBlue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            
            // Hover overlay with actions
            if isHovering && !isSelected {
                VStack {
                    Spacer()
                    HStack(spacing: Spacing.tight) {
                        Button(action: { /* organize */ }) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Button(action: { /* edit */ }) {
                            Image(systemName: "pencil.circle.fill")
                        }
                        Button(action: { /* skip */ }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .padding(Spacing.tight)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(Spacing.tight)
                }
            }
            
            // Selection checkbox (top-left corner)
            if isSelected || isHovering {
                VStack {
                    HStack {
                        SelectionCheckbox(isSelected: isSelected, onToggle: { /* toggle */ })
                            .padding(Spacing.tight)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
```

### 5. Per-Category View Preferences

#### Storage & Smart Defaults

```swift
// Store preferences per category using AppStorage
@AppStorage("viewMode.all") var allViewMode: ViewMode = .card
@AppStorage("viewMode.documents") var documentsViewMode: ViewMode = .list
@AppStorage("viewMode.images") var imagesViewMode: ViewMode = .grid
@AppStorage("viewMode.videos") var videosViewMode: ViewMode = .card
@AppStorage("viewMode.audio") var audioViewMode: ViewMode = .list
@AppStorage("viewMode.archives") var archivesViewMode: ViewMode = .list

// ViewModel property that auto-updates based on category
var currentViewMode: ViewMode {
    switch selectedCategory {
    case .all: return allViewMode
    case .documents: return documentsViewMode
    case .images: return imagesViewMode
    case .videos: return videosViewMode
    case .audio: return audioViewMode
    case .archives: return archivesViewMode
    }
}
```

#### Smart Defaults Rationale

| Category  | Default | Reason |
|-----------|---------|--------|
| All       | Card    | Mixed types need detailed view |
| Documents | List    | Text-heavy, names matter more than visuals |
| Images    | Grid    | Visual preview is primary concern |
| Videos    | Card    | Balance of preview + metadata |
| Audio     | List    | Metadata-focused (title, artist, duration) |
| Archives  | List    | File names and sizes matter most |

#### View Change Feedback

```swift
// When view mode changes, show brief toast:
┌──────────────────┐
│ Grid View • Images│
└──────────────────┘
    ↓
Auto-dismiss after 1.5s
```

### 6. Advanced Keyboard Shortcuts

#### View Mode Shortcuts
```swift
// Switch views
Cmd+1: Card view
Cmd+2: List view
Cmd+3: Grid view

// Category shortcuts
Cmd+Shift+1: All files
Cmd+Shift+2: Documents
Cmd+Shift+3: Images
Cmd+Shift+4: Videos
Cmd+Shift+5: Audio
Cmd+Shift+6: Archives
```

#### Advanced Navigation
```swift
// File navigation (works in all views)
J or ↓: Next file
K or ↑: Previous file
G then G: Jump to first file
Shift+G: Jump to last file
Cmd+F: Focus search (future enhancement)

// Quick actions on focused file
O: Organize
E: Edit destination
S: Skip
Space: Quick Look
R: View/edit rule
```

#### Multi-Selection Advanced
```swift
// Visual selection (Vim-style)
V: Enter visual selection mode
J/K: Extend selection up/down
Esc: Exit visual selection mode
```

### 7. View Transition Animations

```swift
// Smooth transitions between view modes
struct ViewModeTransition: ViewModifier {
    let mode: ViewMode
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
            .animation(.easeInOut(duration: 0.2), value: mode)
    }
}

// Usage in main content:
Group {
    switch currentViewMode {
    case .card:
        CardView()
    case .list:
        ListView()
    case .grid:
        GridView()
    }
}
.modifier(ViewModeTransition(mode: currentViewMode))
```

## Implementation Checklist

### Components to Create
- [ ] `ViewModeToggle` - Three-state toggle button
- [ ] `FileListRow` - Compact list row component
- [ ] `FileGridItem` - Grid item with hover overlay
- [ ] `ViewModeButtonStyle` - Button style for toggle
- [ ] `FileThumbnail` - Image thumbnail generator (for images)
- [ ] `SuggestionBadge` - Small destination indicator

### ViewModels to Modify
- [ ] `DashboardViewModel`
  - [ ] Add `currentViewMode: ViewMode` computed property
  - [ ] Add `setViewMode(_:for:)` method
  - [ ] Add keyboard shortcut handlers
  - [ ] Add view mode state management

### Services to Create/Modify
- [ ] `ThumbnailService` - Generate thumbnails for images
- [ ] `KeyboardShortcutManager` - Centralized shortcut handling

### Storage
- [ ] Add `@AppStorage` properties for each category view mode
- [ ] Add preference sync logic

## Testing Scenarios

### View Mode Switching
1. ✅ Click toggle switches view mode immediately
2. ✅ Cmd+1/2/3 switches between modes
3. ✅ View mode persists on app restart
4. ✅ Smooth transition animation between modes
5. ✅ Selection state preserved during view switch

### Per-Category Preferences
6. ✅ Switching category loads that category's preferred view
7. ✅ Changing view in one category doesn't affect others
8. ✅ Smart defaults load on first launch
9. ✅ Preferences saved immediately on change

### List View
10. ✅ Shows 10-15 files without scrolling
11. ✅ All columns aligned properly
12. ✅ Actions menu works from each row
13. ✅ Selection checkbox appears on hover
14. ✅ Quick Look works on icon click

### Grid View
15. ✅ Image thumbnails load and display correctly
16. ✅ Hover overlay shows action buttons
17. ✅ Actions work from hover overlay
18. ✅ Grid maintains aspect ratio
19. ✅ Selection checkbox visible when needed

### Keyboard Shortcuts
20. ✅ Cmd+1/2/3 switches views
21. ✅ Cmd+Shift+1-6 switches categories
22. ✅ J/K navigation works in all views
23. ✅ O/E/S shortcuts work on focused file
24. ✅ Visual selection mode works (V, J/K, Esc)

## Performance Considerations

### Thumbnail Generation
```swift
// Generate thumbnails asynchronously
class ThumbnailService {
    private let cache = NSCache<NSString, NSImage>()
    
    func thumbnail(for path: String, size: CGSize) async -> NSImage? {
        // Check cache first
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        
        // Generate thumbnail on background thread
        return await Task.detached {
            guard let image = NSImage(contentsOfFile: path) else {
                return nil
            }
            
            let thumbnail = image.resized(to: size)
            self.cache.setObject(thumbnail, forKey: path as NSString)
            return thumbnail
        }.value
    }
}
```

### Grid View Optimization
- Use `LazyVGrid` instead of `VGrid`
- Limit thumbnail cache to 100 images
- Load thumbnails only for visible items
- Placeholder images while loading

### List View Optimization
- Use `LazyVStack` for large file counts
- Virtualize rows (only render visible)
- Debounce scroll events

## Accessibility

### VoiceOver Support
```swift
// List row
.accessibilityElement(children: .combine)
.accessibilityLabel("\(file.name), \(file.fileExtension), \(file.sizeString)")
.accessibilityHint("Double tap to organize to \(file.suggestedDestination ?? "unknown destination")")

// Grid item
.accessibilityElement(children: .combine)
.accessibilityLabel("Image: \(file.name)")
.accessibilityHint("Double tap to show actions")

// View mode toggle
.accessibilityLabel("View mode: \(currentViewMode.displayName)")
.accessibilityHint("Switch between card, list, and grid views")
```

### Keyboard Navigation
- All elements focusable via Tab
- Focus indicator clearly visible
- Shortcuts work without mouse

## Success Criteria

Phase 3 complete when:
- ✅ All three view modes functional and polished
- ✅ Per-category preferences save and load correctly
- ✅ Keyboard shortcuts work in all views
- ✅ Transitions smooth and performant
- ✅ Thumbnails load efficiently (no UI blocking)
- ✅ Selection system works across all views
- ✅ Preferences persist across app launches
- ✅ Smart defaults improve user experience

## Edge Cases

### View Mode with No Files
```swift
// Show appropriate empty state for each view
Card: Large empty state with icon
List: "No files in this category"
Grid: Grid of placeholder boxes
```

### Mixed File Types in Grid
```swift
// Images: Show thumbnail
// Non-images: Show appropriate icon
// Large files: Show file type icon, not thumbnail
```

### Very Long Filenames
```swift
// Card: Truncate middle with ...
// List: Truncate with tooltip on hover
// Grid: Truncate with ellipsis
```

## Future Enhancements (Phase 4+)

### Saved Views
- Save custom filter combinations
- Name and recall saved views
- Share view configurations

### Column Customization
- Reorder columns in list view
- Show/hide specific columns
- Sortable columns

### View Mode Per Location
- Different preferences for Desktop vs Downloads
- Workspace-based preferences

## Notes
- View mode should feel instant (< 200ms transition)
- Thumbnail generation must not block UI
- Keyboard shortcuts should be discoverable (help menu)
- Test with 1000+ files to verify performance
- Consider adding view mode tutorial on first launch

---

**Start with view mode toggle and list view, then add grid view. Implement keyboard shortcuts incrementally. Add thumbnail generation last (with placeholders initially).**
