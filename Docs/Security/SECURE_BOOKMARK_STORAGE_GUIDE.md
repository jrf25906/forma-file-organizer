# Secure Bookmark Storage Developer Guide

## Overview

Forma uses macOS Keychain to securely store security-scoped bookmarks. This guide explains how to properly use the `SecureBookmarkStore` class.

## Quick Start

### Saving a Bookmark

```swift
// Create bookmark data from URL
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Save to Keychain
try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: "MyBookmarkKey")
```

### Loading a Bookmark

```swift
// Load from Keychain
guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: "MyBookmarkKey") else {
    // Bookmark not found - request user to select folder
    return
}

// Resolve bookmark to URL
var isStale = false
let url = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)

if isStale {
    // Bookmark is stale - delete and request new access
    try? SecureBookmarkStore.deleteBookmark(forKey: "MyBookmarkKey")
}
```

### Deleting a Bookmark

```swift
// Delete from Keychain
try SecureBookmarkStore.deleteBookmark(forKey: "MyBookmarkKey")
```

## Key Concepts

### Why Keychain vs UserDefaults?

| Feature | UserDefaults | Keychain |
|---------|-------------|----------|
| Encryption | None | Hardware-backed (when available) |
| Access Control | Any process | App-specific |
| Tampering Protection | None | Built-in |
| Backup Security | Plaintext | Encrypted |
| Performance | Slightly faster | Fast enough |

### Keychain Security Features

1. **Encryption at Rest**
   - All data encrypted using device keys
   - Hardware-backed encryption on supported Macs (T2/Apple Silicon)

2. **Access Control**
   - Service identifier: `com.forma.bookmarks`
   - Only Forma can access these bookmarks
   - Code signing verification

3. **Data Protection Class**
   - `kSecAttrAccessibleAfterFirstUnlock`
   - Data accessible after first device unlock
   - Persists across reboots

## Security-Scoped Access for File Reading

Several services need to read file contents (not just metadata) from user-selected folders. In a sandboxed macOS app, this requires establishing security-scoped access before the file operation.

### Services Using Security-Scoped Access

| Service | Purpose | File Access Method |
|---------|---------|-------------------|
| **ThumbnailService** | Generate file previews | QuickLook thumbnail generation |
| **ContentSearchService** | Search file contents | `String(contentsOf:)` for text files |
| **DuplicateDetectionService** | Detect duplicate files | `FileManager.contents(atPath:)` for SHA-256 hashing |

### The Security Scope Pattern

All services follow the same pattern:

```swift
// 1. Helper to find the bookmark key for a file's parent monitored folder
private func findMonitoredFolderBookmarkKey(for path: String) -> String? {
    // Get real home directory (not sandboxed container path)
    let homeDir: String
    if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
        homeDir = String(cString: home)
    } else {
        homeDir = NSHomeDirectory()
    }

    // Check standard folders
    for (folderName, bookmarkKey) in sourceFolderBookmarks {
        let folderPath = "\(homeDir)/\(folderName)"
        if path.hasPrefix(folderPath) {
            return bookmarkKey
        }
    }

    // Check custom folder bookmarks
    let customFolderPrefix = "CustomFolder_"
    let keychainKeys = SecureBookmarkStore.listAllBookmarkKeys()
    for key in keychainKeys where key.hasPrefix(customFolderPrefix) {
        if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: key) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), path.hasPrefix(url.path) {
                return key
            }
        }
    }

    return nil
}

// 2. Establish security-scoped access for the file's parent folder
private func establishSecurityScope(for path: String) -> URL? {
    guard let bookmarkKey = findMonitoredFolderBookmarkKey(for: path) else {
        return nil
    }

    guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) else {
        return nil
    }

    var isStale = false
    guard let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    ) else {
        return nil
    }

    guard url.startAccessingSecurityScopedResource() else {
        return nil
    }

    return url
}

// 3. Release security-scoped access
private func releaseSecurityScope(for url: URL?) {
    url?.stopAccessingSecurityScopedResource()
}
```

### Usage in File Operations

```swift
func readFileContent(path: String) -> Data? {
    // Establish security scope before file access
    let scopeURL = establishSecurityScope(for: path)
    defer { releaseSecurityScope(for: scopeURL) }

    // Now file operations will work in sandboxed app
    return FileManager.default.contents(atPath: path)
}
```

### Bookmark Key Convention

Standard monitored folders use these bookmark keys:

```swift
private let sourceFolderBookmarks: [String: String] = [
    "Desktop": "DesktopFolderBookmark",
    "Downloads": "DownloadsFolderBookmark",
    "Documents": "DocumentsFolderBookmark",
    "Pictures": "PicturesFolderBookmark",
    "Music": "MusicFolderBookmark"
]
```

Custom folders use the prefix `CustomFolder_` followed by a unique identifier.

### Why This Pattern is Needed

In a sandboxed macOS app:
1. **File scanning** (getting metadata) works through the folder's security-scoped bookmark
2. **File reading** (accessing contents) also requires the parent folder's security scope to be active
3. Without establishing scope, operations like `String(contentsOf:)` will fail with permission errors

The pattern ensures that when a service needs to read a file's contents, it:
1. Finds which monitored folder contains the file
2. Establishes security-scoped access to that folder
3. Performs the file operation
4. Releases the security scope (via `defer` to ensure cleanup)

---

## Best Practices

### 1. Always Validate Bookmarks After Loading

```swift
if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: key) {
    var isStale = false
    do {
        let url = try URL(resolvingBookmarkData: bookmarkData, ...)

        // IMPORTANT: Validate the resolved URL against the REAL home directory
        // (not the sandbox container path)
        let homeDir = realHomeDirectory()
        guard url.path.hasPrefix(homeDir.path) else {
            // Security violation - delete bookmark
            try? SecureBookmarkStore.deleteBookmark(forKey: key)
            throw SecurityError.invalidBookmark
        }

        // Use url...
    } catch {
        // Bookmark invalid - clean up
        try? SecureBookmarkStore.deleteBookmark(forKey: key)
    }
}
```

### Sandbox Home Directory Workaround

**IMPORTANT**: In sandboxed macOS apps, `FileManager.default.homeDirectoryForCurrentUser` returns the **sandbox container path** (e.g., `~/Library/Containers/com.yourteam.Forma-File-Organizing/Data`), NOT the actual user home directory (e.g., `/Users/username`).

This causes path validation to fail when comparing resolved bookmark paths against the "home directory" since bookmarks resolve to real paths like `/Users/username/Desktop`.

**Solution**: Use POSIX APIs to get the real home directory:

```swift
/// Returns the user's real home directory, not the sandbox container.
/// In sandboxed apps, FileManager.default.homeDirectoryForCurrentUser returns
/// the sandbox container (e.g., ~/Library/Containers/app.bundle.id/Data).
/// This function uses POSIX getpwuid() to get the real home directory.
private func realHomeDirectory() -> URL {
    if let pw = getpwuid(getuid()) {
        let homeDir = String(cString: pw.pointee.pw_dir)
        return URL(fileURLWithPath: homeDir)
    }
    // Fallback to standard method (shouldn't happen on macOS)
    return FileManager.default.homeDirectoryForCurrentUser
}
```

**Where this pattern is used:**
- `CustomFolderManager.swift` - for validating bookmark resolution
- `DashboardViewModel.swift` - for bookmark migration path validation

**Symptom if not used**: Bookmarks appear valid but path validation fails with "Security: Custom folder bookmark points outside home directory" because `/Users/username/Desktop` doesn't start with `~/Library/Containers/...`

### 2. Handle Migration Automatically

```swift
class MyService {
    init() {
        // Migrate on first launch
        migrateBookmarksToKeychain()
    }

    private func migrateBookmarksToKeychain() {
        let keys = ["DesktopBookmark", "DownloadsBookmark"]
        try? SecureBookmarkStore.migrateFromUserDefaults(keys: keys)
    }
}
```

### 3. Use Descriptive Key Names

```swift
// GOOD
private let desktopBookmarkKey = "DesktopFolderBookmark"
private let downloadsBookmarkKey = "DownloadsFolderBookmark"

// BAD
private let key1 = "bookmark1"
private let key2 = "bookmark2"
```

### 4. Clean Up Legacy Storage

```swift
func resetBookmark(key: String) {
    // Delete from Keychain
    try? SecureBookmarkStore.deleteBookmark(forKey: key)

    // Also clean up legacy UserDefaults
    UserDefaults.standard.removeObject(forKey: key)
}
```

## Error Handling

### Common Errors

```swift
do {
    try SecureBookmarkStore.saveBookmark(data, forKey: key)
} catch SecureBookmarkStore.BookmarkStoreError.saveFailed(let status) {
    print("Keychain save failed with status: \(status)")
    // Handle error - possibly show user alert
} catch {
    print("Unexpected error: \(error)")
}
```

### Error Types

- `saveFailed(OSStatus)` - Failed to save to Keychain
- `loadFailed(OSStatus)` - Failed to load from Keychain
- `deleteFailed(OSStatus)` - Failed to delete from Keychain
- `migrationFailed(String)` - Migration from UserDefaults failed

### OSStatus Codes

Common Keychain status codes:
- `errSecSuccess` (0) - Operation successful
- `errSecItemNotFound` (-25300) - Item doesn't exist
- `errSecDuplicateItem` (-25299) - Item already exists
- `errSecParam` (-50) - Invalid parameters

## Migration Guide

### Migrating Existing Code

#### Before (Insecure)

```swift
// Save
UserDefaults.standard.set(bookmarkData, forKey: "MyKey")

// Load
let bookmarkData = UserDefaults.standard.data(forKey: "MyKey")

// Delete
UserDefaults.standard.removeObject(forKey: "MyKey")
```

#### After (Secure)

```swift
// Save
try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: "MyKey")

// Load
let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: "MyKey")

// Delete
try SecureBookmarkStore.deleteBookmark(forKey: "MyKey")
```

### Automatic Migration

The `SecureBookmarkStore` includes automatic migration:

```swift
let keys = ["BookmarkKey1", "BookmarkKey2"]
try SecureBookmarkStore.migrateFromUserDefaults(keys: keys)
```

This will:
1. Check if bookmark already in Keychain (skip if so)
2. Load from UserDefaults
3. Validate bookmark data
4. Save to Keychain
5. Remove from UserDefaults
6. Log progress (debug builds only)

## Debugging

### Enable Debug Logging

Debug logging is automatically enabled in DEBUG builds:

```swift
#if DEBUG
print("✅ SecureBookmarkStore: Successfully saved bookmark for key 'DesktopBookmark'")
#endif
```

### List All Stored Bookmarks

```swift
let allKeys = SecureBookmarkStore.listAllBookmarkKeys()
print("Stored bookmarks: \(allKeys)")
```

### Verify Migration

```swift
// After migration, verify UserDefaults is empty
let keys = ["DesktopBookmark", "DownloadsBookmark"]
for key in keys {
    if UserDefaults.standard.data(forKey: key) != nil {
        print("⚠️ Migration incomplete for key: \(key)")
    }
}
```

### Check Keychain Directly

Using Terminal:

```bash
# List all Forma bookmarks
security dump-keychain -d login.keychain-db | grep "com.forma.bookmarks"

# Count bookmark items
security dump-keychain login.keychain-db | grep "com.forma.bookmarks" | wc -l
```

## Testing

### Unit Tests

```swift
func testBookmarkSaveAndLoad() throws {
    let testData = "TestData".data(using: .utf8)!
    let testKey = "TestKey"

    // Clean up
    try? SecureBookmarkStore.deleteBookmark(forKey: testKey)

    // Save
    try SecureBookmarkStore.saveBookmark(testData, forKey: testKey)

    // Load
    let loadedData = SecureBookmarkStore.loadBookmark(forKey: testKey)

    // Verify
    XCTAssertEqual(loadedData, testData)

    // Clean up
    try? SecureBookmarkStore.deleteBookmark(forKey: testKey)
}
```

### Integration Tests

```swift
func testRealBookmarkFlow() throws {
    let desktopURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop")

    // Create bookmark
    let bookmarkData = try desktopURL.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )

    // Save to Keychain
    try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: "TestDesktop")

    // Load from Keychain
    let loadedData = SecureBookmarkStore.loadBookmark(forKey: "TestDesktop")
    XCTAssertNotNil(loadedData)

    // Resolve
    var isStale = false
    let resolvedURL = try URL(
        resolvingBookmarkData: loadedData!,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    XCTAssertEqual(resolvedURL.path, desktopURL.path)
    XCTAssertFalse(isStale)

    // Clean up
    try SecureBookmarkStore.deleteBookmark(forKey: "TestDesktop")
}
```

## Security Checklist

When working with bookmarks, always:

- ✅ Store bookmarks in Keychain (not UserDefaults)
- ✅ Validate resolved URLs against expected paths
- ✅ Check for bookmark staleness
- ✅ Verify paths are within home directory
- ✅ Clean up invalid bookmarks immediately
- ✅ Handle migration from legacy storage
- ✅ Use descriptive key names
- ✅ Test error handling paths
- ✅ Log security-relevant events (debug only)
- ✅ Never log bookmark data contents

## Performance Considerations

### Keychain Performance

- **Read**: ~0.1-0.5ms per operation
- **Write**: ~0.5-2ms per operation
- **Delete**: ~0.5-1ms per operation

### Optimization Tips

1. **Cache Bookmark Data**
   ```swift
   private var cachedBookmark: Data?

   func getBookmark() -> Data? {
       if cachedBookmark == nil {
           cachedBookmark = SecureBookmarkStore.loadBookmark(forKey: key)
       }
       return cachedBookmark
   }
   ```

2. **Batch Operations**
   ```swift
   // Instead of multiple saves:
   let bookmarks = [("key1", data1), ("key2", data2), ("key3", data3)]
   for (key, data) in bookmarks {
       try SecureBookmarkStore.saveBookmark(data, forKey: key)
   }
   ```

3. **Lazy Loading**
   ```swift
   lazy var desktopBookmark: Data? = {
       SecureBookmarkStore.loadBookmark(forKey: "DesktopBookmark")
   }()
   ```

## Troubleshooting

### Issue: Migration Not Working

**Symptoms:** Bookmarks still in UserDefaults after migration

**Solution:**
```swift
// Check if migration is being called
print("Starting migration...")
try SecureBookmarkStore.migrateFromUserDefaults(keys: keys)
print("Migration complete")

// Verify bookmarks in Keychain
let keychainKeys = SecureBookmarkStore.listAllBookmarkKeys()
print("Keychain contains: \(keychainKeys)")
```

### Issue: Bookmark Not Found After Restart

**Symptoms:** `loadBookmark()` returns nil after app restart

**Solution:**
```swift
// Verify bookmark is actually saved
if let data = SecureBookmarkStore.loadBookmark(forKey: key) {
    print("Bookmark found: \(data.count) bytes")
} else {
    print("Bookmark not found - may need to re-grant access")
}
```

### Issue: Access Denied Error

**Symptoms:** Keychain operations fail with errSecAuthFailed

**Solution:**
- Ensure app is properly code-signed
- Check that service identifier matches
- Verify no sandbox restrictions preventing Keychain access

## FAQ

**Q: Can other apps access my bookmarks?**
A: No. Keychain items are isolated by app signature and service identifier.

**Q: Are bookmarks encrypted?**
A: Yes. Keychain provides hardware-backed encryption on supported Macs.

**Q: What happens if I delete the app?**
A: Keychain items are removed when the app is deleted.

**Q: Do bookmarks sync via iCloud?**
A: No. Our bookmarks use the local Keychain, not iCloud Keychain.

**Q: How do I reset all bookmarks for testing?**
A: Use `try SecureBookmarkStore.deleteAllBookmarks()`

**Q: Can I store other sensitive data?**
A: Yes, but consider the 100KB limit per item and use appropriate keys.

## References

- [SecureBookmarkStore Source Code](../../Forma%20File%20Organizing/Services/SecureBookmarkStore.swift)
- [FileSystemService Source Code](../../Forma%20File%20Organizing/Services/FileSystemService.swift)
- [Security Audit Report](./SECURITY_AUDIT_BOOKMARK_STORAGE.md)
- [Apple Keychain Services Guide](https://developer.apple.com/documentation/security/keychain_services)
- [OWASP Secure Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)

---

**Last Updated:** December 19, 2025
**Maintainer:** Security Team
