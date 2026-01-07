# Security Checklist: Bookmark Handling

## Overview
This checklist ensures secure handling of security-scoped bookmarks to prevent unauthorized file system access.

**OWASP Reference:** A01:2021 - Broken Access Control

## Mandatory Security Checks

### When Resolving Any Bookmark

Every bookmark resolution MUST include these validations:

#### 1. Staleness Check
```swift
var isStale = false
let url = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)

guard !isStale else {
    // Invalidate stale bookmark
    throw error
}
```

#### 2. Home Directory Boundary Check (CRITICAL)
```swift
let homeDir = FileManager.default.homeDirectoryForCurrentUser
guard url.path.hasPrefix(homeDir.path) else {
    // SECURITY: Bookmark points outside home directory
    UserDefaults.standard.removeObject(forKey: bookmarkKey)
    throw FileSystemError.permissionDenied
}
```

**WHY:** Prevents access to:
- System folders (`/etc`, `/var`, `/System`)
- Other user directories (`/Users/otheruser`)
- Sensitive locations (`/private`, `/Library`)

#### 3. Expected Path Validation

For **Standard Folders** (Desktop, Downloads, etc.):
```swift
guard url.lastPathComponent.lowercased() == folderName.lowercased() else {
    // SECURITY: Folder name mismatch
    UserDefaults.standard.removeObject(forKey: bookmarkKey)
    throw FileSystemError.permissionDenied
}
```

For **Custom Folders**:
```swift
guard resolvedURL.path == expectedURL.path else {
    // SECURITY: Path mismatch
    throw FileSystemError.scanFailed("Bookmark verification failed")
}
```

**WHY:** Prevents bookmark substitution attacks

#### 4. Automatic Invalidation

ALWAYS remove suspicious bookmarks:
```swift
// On validation failure
UserDefaults.standard.removeObject(forKey: bookmarkKey)
```

**WHY:** Prevents repeated exploitation attempts

## Implementation Patterns

### ✅ CORRECT: Secure Bookmark Resolution

```swift
private func getFolderURL(folderName: String, bookmarkKey: String) async throws -> URL {
    if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard !isStale else {
                throw error
            }

            // ✅ SECURITY: Validate folder name
            guard url.lastPathComponent.lowercased() == folderName.lowercased() else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                throw FileSystemError.permissionDenied
            }

            // ✅ SECURITY: Validate within home directory
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            guard url.path.hasPrefix(homeDir.path) else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                throw FileSystemError.permissionDenied
            }

            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            throw error
        }
    }

    return try await requestAccess(...)
}
```

### ❌ INCORRECT: Insecure Bookmark Resolution

```swift
// ❌ VULNERABLE CODE - DO NOT USE
private func getFolderURL(bookmarkKey: String) throws -> URL {
    guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
        throw error
    }

    var isStale = false
    let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    // ❌ NO VALIDATION - SECURITY VULNERABILITY
    return url
}
```

## Code Review Checklist

When reviewing code that handles bookmarks:

- [ ] Does it check if bookmark is stale?
- [ ] Does it validate resolved path is within home directory?
- [ ] Does it validate folder name matches expected (for standard folders)?
- [ ] Does it validate exact path matches (for custom folders)?
- [ ] Does it invalidate suspicious bookmarks?
- [ ] Does it avoid information leakage in error messages?
- [ ] Does it handle errors securely (fail closed, not open)?
- [ ] Are security-scoped resources properly released (defer/finally)?

## Security Testing Requirements

### Unit Tests Required

1. **Valid Bookmark Test**
   - Verify legitimate bookmarks work correctly

2. **Home Directory Boundary Test**
   - Verify rejection of bookmarks outside home directory
   - Test cases: `/etc`, `/var/log`, `/System`, `/Users/otheruser`

3. **Folder Name Mismatch Test**
   - Verify rejection when bookmark folder name doesn't match key

4. **Path Verification Test**
   - Verify custom folder bookmarks match expected paths

5. **Automatic Invalidation Test**
   - Verify suspicious bookmarks are removed from UserDefaults

6. **Path Traversal Test**
   - Verify `../` sequences don't escape home directory

7. **Symlink Test**
   - Verify symlinks to sensitive folders are caught

8. **Error Handling Test**
   - Verify no sensitive path information in error messages

### Manual Security Testing

```bash
# 1. Create legitimate bookmark
# - Grant Desktop access via app UI
# - Verify bookmark stored in UserDefaults

# 2. Attempt bookmark tampering
defaults read com.forma.app DesktopFolderBookmark > /tmp/backup.plist

# Create bookmark to sensitive folder (requires dev tools)
# Attempt to inject via defaults write

# 3. Verify app rejects tampered bookmark
# - Launch app
# - Check logs for security warnings
# - Verify access denied
# - Verify bookmark invalidated
```

## Common Vulnerabilities to Avoid

### 1. Missing Home Directory Check
```swift
// ❌ VULNERABLE
let url = try resolveBookmark(bookmarkData)
return url  // No boundary validation
```

### 2. Trusting UserDefaults Data
```swift
// ❌ VULNERABLE - Assumes UserDefaults is trustworthy
let bookmarkData = UserDefaults.standard.data(forKey: key)!
let url = try resolveBookmark(bookmarkData)
// No validation that bookmark hasn't been tampered with
```

### 3. Insufficient Error Handling
```swift
// ❌ VULNERABLE - Fails open
do {
    return try resolveBookmark(bookmarkData)
} catch {
    return defaultURL  // Bypasses security on error
}
```

### 4. Information Leakage
```swift
// ❌ VULNERABLE - Leaks sensitive paths
catch {
    throw Error("Failed to access \(url.path)")  // Reveals actual path
}
```

## Security Headers Configuration

For sandboxed macOS apps, ensure `*.entitlements` includes:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<!-- Only request access to specific directories -->
<!-- Do NOT use com.apple.security.temporary-exception.files.absolute-path.read-write -->
```

## Incident Response

If bookmark validation bypass is suspected:

1. **Immediate Actions**
   - Review UserDefaults for suspicious bookmark data
   - Check logs for validation failures
   - Invalidate all bookmarks: `resetAllAccess()`

2. **Investigation**
   - Review audit logs for unauthorized access attempts
   - Check for malware or local privilege escalation
   - Verify app binary integrity

3. **Remediation**
   - Force re-authentication for all folders
   - Update to patched version
   - Review file system operations for unauthorized changes

## References

- **OWASP Top 10 2021:** A01 - Broken Access Control
- **OWASP ASVS 4.0:** V4.1 (Access Control), V4.2 (Operation Level)
- **CWE-22:** Improper Limitation of a Pathname to a Restricted Directory
- **CWE-284:** Improper Access Control
- **Apple Security:** [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- **Apple Security:** [Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/url/2143023-bookmarkdata)

## Version History

- **v1.0** (2025-11-30): Initial security checklist for bookmark validation fix
