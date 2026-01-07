# DestinationResolver Architecture

## Overview

The `DestinationResolver` service handles automatic resolution of placeholder destinations in Forma. It enables the app to create subfolders within user-permitted parent folders, solving the sandboxing limitation where rules with path-based destinations couldn't access folders without explicit user selection.

## Problem Statement

### The Placeholder Destination Challenge

In macOS sandboxed apps, file access requires security-scoped bookmarks. Forma uses a `Destination` enum to represent where files should be moved:

```swift
enum Destination: Codable, Equatable, Hashable {
    case trash
    case folder(bookmark: Data, displayName: String)
}
```

However, several features created "placeholder" destinations with empty bookmarks:

```swift
// Placeholder destination - has displayName but empty bookmark
Destination.folder(bookmark: Data(), displayName: "Pictures/Screenshots")
```

These placeholders were useful for:
- **Default rules** (seeded during onboarding)
- **Template rules** (from OrganizationTemplate)
- **Natural language rules** (parsed from user input)
- **AI-suggested destinations** (from LearningService)
- **Bulk operations** (user-typed paths)

But when file operations attempted to use these, they would fail because `destination.bookmarkData` returned `nil` for empty bookmarks.

### Root Cause

```
┌─────────────────────────────────────────────────────────────────┐
│  USER TYPES: "Pictures/Screenshots"                             │
│                    │                                            │
│                    ▼                                            │
│  Destination.folder(bookmark: Data(), displayName: "...")      │
│                    │                                            │
│                    ▼                                            │
│  FileOperationsService.moveFile()                              │
│                    │                                            │
│                    ▼                                            │
│  guard let bookmarkData = destination.bookmarkData else {      │
│      throw FormaError.operation(.notReady("No bookmark data")) │ ❌
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Solution: DestinationResolver

### Key Insight

If the user has granted access to a parent folder (e.g., `~/Pictures`), the app can:
1. Create subfolders within that parent (`~/Pictures/Screenshots`)
2. Generate a new bookmark for the created subfolder
3. Replace the placeholder with a real destination

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   DestinationResolver                           │
│                                                                 │
│  ┌─────────────┐    ┌──────────────────┐    ┌───────────────┐ │
│  │ Parse Path  │ ───▶│ Find Accessible  │ ───▶│ Create Subfolder │
│  │ Components  │    │ Parent Bookmark  │    │ & New Bookmark│ │
│  └─────────────┘    └──────────────────┘    └───────────────┘ │
│                                                                 │
│  Input: Destination.folder(bookmark: Data(), "Pictures/Screenshots")│
│  Output: Destination.folder(bookmark: <valid>, "Screenshots")  │
└─────────────────────────────────────────────────────────────────┘
```

### Resolution Flow

```swift
func resolve(_ destination: Destination) -> Destination? {
    // 1. Only process placeholder destinations (empty bookmark)
    guard case .folder(let bookmark, let displayName) = destination,
          bookmark.isEmpty else { return nil }

    // 2. Parse "Pictures/Screenshots" → ["Pictures", "Screenshots"]
    let components = displayName.components(separatedBy: "/")

    // 3. Find accessible parent (e.g., "Pictures" has a stored bookmark)
    guard let (parentURL, remaining) = findAccessibleParent(components) else {
        return nil
    }

    // 4. Build target path: parentURL + "Screenshots"
    var targetURL = parentURL
    for component in remaining {
        targetURL = targetURL.appendingPathComponent(component)
    }

    // 5. Create directory using parent's security scope
    try createDirectoryIfNeeded(at: targetURL, accessingParent: parentURL)

    // 6. Generate new bookmark for the created folder
    return try Destination.folder(from: targetURL)
}
```

### Integration Points

#### 1. RuleEngine (Primary Integration)

When evaluating rules, RuleEngine attempts resolution before skipping rules with placeholder destinations:

```swift
// In RuleEngine.evaluateFile()
if !ruleDestination.isTrash && ruleDestination.bookmarkData == nil {
    let cacheKey = ruleDestination.displayName

    // Check cache first (performance optimization)
    if let cachedDestination = resolvedDestinationCache[cacheKey] {
        file.destination = cachedDestination
    }
    // Try to resolve placeholder
    else if let resolved = destinationResolver.resolve(ruleDestination) {
        resolvedDestinationCache[cacheKey] = resolved
        file.destination = resolved
        Log.info("RuleEngine: Auto-resolved '\(ruleDestination.displayName)'", category: .pipeline)
    }
    // Skip rule if unresolvable
    else {
        Log.warning("RuleEngine: Unresolvable placeholder destination", category: .pipeline)
        continue
    }
}
```

#### 2. FileOperationsService (Fallback Integration)

As a safety net, FileOperationsService also attempts resolution before failing:

```swift
// In FileOperationsService.moveFile()
if effectiveBookmarkData == nil {
    if let resolved = destinationResolver.resolve(destination) {
        effectiveDestination = resolved
        effectiveBookmarkData = resolved.bookmarkData
        fileItem.destination = resolved  // Persist for future
        Log.info("FileOperationsService: Auto-resolved placeholder", category: .fileOperations)
    } else {
        throw FormaError.operation(.notReady("Destination requires folder access"))
    }
}
```

### Known Folder Mappings

The resolver knows about standard macOS folders and their bookmark keys:

```swift
private static let folderBookmarkKeys: [String: String] = [
    "Desktop": FormaConfig.Security.desktopBookmarkKey,
    "Downloads": FormaConfig.Security.downloadsBookmarkKey,
    "Documents": FormaConfig.Security.documentsBookmarkKey,
    "Pictures": FormaConfig.Security.picturesBookmarkKey,
    "Music": FormaConfig.Security.musicBookmarkKey
]
```

### Resolution Examples

| Placeholder | Parent Bookmark | Resolution |
|-------------|-----------------|------------|
| `Pictures/Screenshots` | `~/Pictures` | Creates `~/Pictures/Screenshots`, returns valid bookmark |
| `Documents/Work/2024` | `~/Documents` | Creates nested structure, returns valid bookmark |
| `Archive/Old` | None found | Returns `nil` (unresolvable) |
| `Projects` (no parent) | None found | Returns `nil` (unresolvable) |

## Performance Optimization: Caching

RuleEngine maintains a cache to avoid repeated resolution attempts:

```swift
private var resolvedDestinationCache: [String: Destination] = [:]
```

**Why caching matters:**
- Resolution involves file system operations (directory creation)
- The same placeholder may appear in multiple rules
- Cache key is the displayName (e.g., "Pictures/Screenshots")
- Cache is per-session (cleared on app restart)

## Security Considerations

### What DestinationResolver CAN Do

- Create subfolders within already-bookmarked parent folders
- Generate valid security-scoped bookmarks for created folders
- Work within the user's existing permission grants

### What DestinationResolver CANNOT Do

- Access folders outside the sandbox without user permission
- Create folders in arbitrary locations
- Bypass macOS sandboxing restrictions
- Work with placeholder destinations that have no accessible parent

### Security Flow

```
User grants access to ~/Pictures via folder picker
            │
            ▼
SecureBookmarkStore saves bookmark for "Pictures"
            │
            ▼
Rule created: "Move screenshots to Pictures/Screenshots"
            │
            ▼
DestinationResolver finds "Pictures" bookmark exists
            │
            ▼
Creates ~/Pictures/Screenshots using parent's security scope
            │
            ▼
Generates new bookmark for Screenshots folder
            │
            ▼
File operations use the new valid bookmark
```

## Error Handling

### Resolution Failures

Resolution can fail for several reasons:

1. **No accessible parent** - The first path component doesn't have a stored bookmark
2. **Directory creation fails** - Permissions, disk space, or path issues
3. **Bookmark creation fails** - System-level bookmark generation errors

### Graceful Degradation

When resolution fails:
- **RuleEngine**: Skips the rule and logs a warning
- **FileOperationsService**: Throws descriptive error for UI handling

```swift
// User-friendly error message
throw FormaError.operation(.notReady(
    "Destination '\(destination.displayName)' requires folder access - " +
    "please select the folder in Settings"
))
```

## Testing

### Unit Testing

```swift
func testResolverWithValidParent() throws {
    // Setup: Store a bookmark for Pictures
    let picturesURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures")
    let bookmark = try picturesURL.bookmarkData(options: .withSecurityScope)
    SecureBookmarkStore.saveBookmark(bookmark, forKey: "PicturesFolderBookmark")

    // Test
    let resolver = DestinationResolver()
    let placeholder = Destination.folder(bookmark: Data(), displayName: "Pictures/Screenshots")
    let resolved = resolver.resolve(placeholder)

    // Verify
    XCTAssertNotNil(resolved)
    XCTAssertNotNil(resolved?.bookmarkData)
    XCTAssertEqual(resolved?.displayName, "Screenshots")
}

func testResolverWithNoParent() {
    let resolver = DestinationResolver()
    let placeholder = Destination.folder(bookmark: Data(), displayName: "NonExistent/Folder")
    let resolved = resolver.resolve(placeholder)

    XCTAssertNil(resolved)  // Should fail gracefully
}
```

## File References

- **DestinationResolver**: `/Services/DestinationResolver.swift`
- **Destination Model**: `/Models/Destination.swift`
- **RuleEngine Integration**: `/Services/RuleEngine.swift`
- **FileOperationsService Integration**: `/Services/FileOperationsService.swift`
- **SecureBookmarkStore**: `/Services/SecureBookmarkStore.swift`

## Related Documentation

- [RuleEngine Architecture](RuleEngine-Architecture.md) - How rules are evaluated
- [File Operations Audit](File-Operations-Audit.md) - File operation security
- [Security Checklist](../Security/SECURITY_CHECKLIST_BOOKMARK_HANDLING.md) - Bookmark security

## Summary

DestinationResolver bridges the gap between user-friendly path-based destination input and macOS sandbox security requirements. By leveraging existing parent folder permissions, it enables automatic subfolder creation while maintaining security compliance. The integration at both RuleEngine and FileOperationsService levels ensures comprehensive coverage with graceful fallback behavior.

---

*Last updated: December 2024*
