# Bookmark Folder Architecture

## Overview

This document describes the simplified folder access architecture introduced in January 2025 to eliminate sync issues between Keychain bookmarks and SwiftData models.

## Problem: Dual Storage Caused Sync Issues

The original architecture stored folder information in two places:

1. **Keychain** (`SecureBookmarkStore`): Security-scoped bookmark data for macOS sandbox access
2. **SwiftData** (`CustomFolder`): Model with duplicate bookmark data plus metadata

This dual storage caused issues:
- Deleting SwiftData (e.g., during data reset) left orphaned Keychain bookmarks
- The sidebar showed empty because it read from SwiftData, not Keychain
- Bookmarks and CustomFolder could get out of sync during migrations

## Solution: Single Source of Truth

The new architecture makes **Keychain the single source of truth**:

```
┌─────────────────────────────────────────────────┐
│               BookmarkFolderService             │
│  (Observable - publishes folder availability)   │
└─────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│              SecureBookmarkStore                │
│  (Keychain - source of truth for access)        │
└─────────────────────────────────────────────────┘
```

### Key Components

#### `BookmarkFolder` (struct)
A simple value type representing a folder with access:
- **Not** a SwiftData model - no persistence
- Reads bookmark data directly from Keychain on demand
- Uses `UserDefaults` only for `isEnabled` toggle state

```swift
struct BookmarkFolder: Identifiable {
    let folderType: FolderType  // .desktop, .downloads, etc.

    var hasValidBookmark: Bool {
        SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) != nil
    }
}
```

#### `BookmarkFolderService` (ObservableObject)
Provides reactive updates to UI:
- `availableFolders: [BookmarkFolder]` - folders with valid bookmarks
- `enabledFolderLocations: [FolderLocation]` - for scan pipeline
- `refresh()` - call after permission changes

#### Removed: `CustomFolder` (SwiftData model)
The previous SwiftData model is deprecated. Components that need folder lists now use `BookmarkFolderService.shared.availableFolders`.

## Migration Notes

### For Existing Users
Existing Keychain bookmarks are preserved. The sidebar will automatically show folders that have valid bookmarks.

### For Developers

**Before:**
```swift
// OLD: Reading from SwiftData
dashboardViewModel.customFolders  // [CustomFolder]
```

**After:**
```swift
// NEW: Reading from Keychain via service
BookmarkFolderService.shared.availableFolders  // [BookmarkFolder]
```

**Navigation:**
```swift
// OLD
NavigationSelection.custom(customFolder)

// NEW
NavigationSelection.from(folderType: folder.folderType)
// Or directly: .desktop, .downloads, etc.
```

## Supported Folders

The architecture supports the five standard macOS user folders:
- Desktop
- Downloads
- Documents
- Pictures
- Music

These are defined in `BookmarkFolder.FolderType` and map to bookmark keys in `FormaConfig.Security`.

## File Locations

- `Models/BookmarkFolder.swift` - The struct definition
- `Services/BookmarkFolderService.swift` - The observable service
- `Models/DashboardTypes.swift` - `FolderLocation` enum (simplified)
- `ViewModels/NavigationViewModel.swift` - `NavigationSelection` (simplified)

## Benefits

1. **Single source of truth** - No more sync issues
2. **Simpler architecture** - No SwiftData complexity for folder state
3. **Resilient** - Keychain persists across data resets
4. **Observable** - SwiftUI updates automatically when folders change
