# Symlink Security - Quick Reference Card

## Overview

The Forma file organizer implements comprehensive symlink attack prevention using defense-in-depth security.

## Security Layers

### Layer 1: Scanning (FileSystemService.swift)
**Purpose**: Prevent symlinks from entering the file queue

```swift
// Check each file during scanning
let resourceValues = try fileURL.resourceValues(forKeys: [
    .isDirectoryKey,
    .isSymbolicLinkKey  // ← Detect symlinks
])

if resourceValues.isSymbolicLink == true {
    continue  // ← Skip symlinks entirely
}
```

### Layer 2: Operations (FileOperationsService.swift)
**Purpose**: Prevent symlink following during file moves

```swift
// Validate file before moving
let fd = open(path, O_RDONLY | O_NOFOLLOW)  // ← O_NOFOLLOW rejects symlinks

if fd < 0 && errno == ELOOP {
    // Symlink detected - fail securely
    throw FileOperationError.operationFailed("Source is a symbolic link")
}
```

## Why Two Layers?

1. **Scanning Layer**: User never sees symlinks in file list
2. **Operations Layer**: Prevents TOCTOU attacks where file becomes symlink after scanning

## Key Security Properties

| Property | Implementation | Protection |
|----------|---------------|------------|
| **Symlink Detection** | `.isSymbolicLinkKey` resource values | Identifies symlinks during scan |
| **Atomic Rejection** | `O_NOFOLLOW` flag | Kernel-level symlink rejection |
| **TOCTOU Prevention** | File descriptor validation | Race condition protection |
| **Type Enforcement** | `S_IFREG` check | Only regular files allowed |
| **Boundary Checking** | Home directory validation | Prevents directory escape |

## Attack Scenarios Prevented

### 1. Basic Symlink Attack
```bash
# Attacker creates symlink to system file
ln -s /etc/passwd ~/Desktop/invoice.pdf

# Defense: Skipped during scanning, rejected if attempted
```

### 2. TOCTOU Race Condition
```
Time    Attacker                 App
T0                               Check: file exists ✓
T1      Replace with symlink!
T2                               Move: FAILS with ELOOP ✓
```

### 3. Directory Escape
```bash
# Attacker creates symlink outside home directory
ln -s /var/log/system.log ~/Desktop/logs.txt

# Defense: Symlink skipped, target boundary validated
```

## Developer Guidelines

### When Adding File Operations

1. **Always** use `secureValidateFile()` before file operations
2. **Never** call `FileManager` move/copy without validation
3. **Check** file type with `S_IFREG` mask
4. **Validate** paths are within home directory

### Example: Safe File Operation

```swift
func myFileOperation(_ fileURL: URL) throws {
    // 1. Validate with O_NOFOLLOW
    let fd = try secureValidateFile(at: fileURL)
    defer { close(fd) }

    // 2. Now safe to operate on fileURL
    // The file descriptor ensures same file is used
    try fileManager.moveItem(at: fileURL, to: destination)
}
```

### Example: Safe Scanning

```swift
func scanFolder(_ folderURL: URL) throws -> [FileMetadata] {
    let contents = try fileManager.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [
            .isSymbolicLinkKey  // ← REQUIRED
        ],
        options: [.skipsHiddenFiles]
    )

    for fileURL in contents {
        let values = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])

        // ← REQUIRED CHECK
        if values.isSymbolicLink == true {
            continue  // Skip symlinks
        }

        // Safe to process
    }
}
```

## Testing

### Manual Test
```bash
# Create test symlink
cd ~/Desktop
ln -s /etc/passwd test_symlink.txt

# Run app
# Expected: Symlink should be skipped, logged in console

# Cleanup
rm ~/Desktop/test_symlink.txt
```

### Automated Test
```bash
# Run security test suite
swift test --filter SymlinkSecurityTests
```

## Security Headers

```swift
// SECURITY: Detect and skip symlinks (CWE-61)
if resourceValues.isSymbolicLink == true {
    #if DEBUG
    print("⚠️ SECURITY: Skipping symlink: \(fileURL.path)")
    #endif
    continue
}
```

## Common Mistakes to Avoid

❌ **DON'T**: Use `fileExists(atPath:)` alone
```swift
// INSECURE - TOCTOU race condition
if fileManager.fileExists(atPath: path) {
    try fileManager.moveItem(...)  // File might be replaced with symlink!
}
```

✅ **DO**: Use `secureValidateFile()` with file descriptor
```swift
// SECURE - Atomic validation
let fd = try secureValidateFile(at: url)
defer { close(fd) }
try fileManager.moveItem(...)
```

❌ **DON'T**: Forget to check `.isSymbolicLinkKey`
```swift
// INSECURE - Symlinks will be processed
let values = try url.resourceValues(forKeys: [.isDirectoryKey])
```

✅ **DO**: Always include symlink check
```swift
// SECURE - Symlinks detected
let values = try url.resourceValues(forKeys: [
    .isDirectoryKey,
    .isSymbolicLinkKey  // ← Required
])
```

## Hard Links vs Symlinks

**Hard Links** (Safe ✅):
- Multiple directory entries → same inode
- No separate file type
- Treated as regular files
- Cannot cross filesystem boundaries
- **Safe to move/organize**

**Symlinks** (Dangerous ⚠️):
- Separate file with S_IFLNK type
- Points to target path
- Can point anywhere (even outside home dir)
- **Must be rejected**

## errno Codes

| errno | Meaning | Action |
|-------|---------|--------|
| `ELOOP` | Too many symlinks / O_NOFOLLOW rejected symlink | Reject file |
| `ENOENT` | File not found | Normal error |
| `EACCES` | Permission denied | Normal error |

## Monitoring

### Security Events to Monitor

```
⚠️ SECURITY: Skipping symlink: <path>
🔴 SYMLINK ATTACK: Symlink escapes home directory!
🔴 SECURITY: Symlink attack detected at <path>
```

### Metrics

- Symlinks skipped per scan
- ELOOP errors per hour
- Non-regular files rejected

## References

- **OWASP**: A01:2021 - Broken Access Control
- **CWE**: CWE-61 - UNIX Symbolic Link Following
- **CERT**: FIO01-C - Be careful using functions that use file names for identification
- **Apple**: File System Programming Guide - Symbolic Links

## Quick Decision Tree

```
Is this a new file operation?
├─ Yes
│  ├─ Use secureValidateFile()
│  ├─ Check errno == ELOOP
│  └─ Validate with fstat()
└─ No
   └─ No changes needed

Is this a new scan operation?
├─ Yes
│  ├─ Include .isSymbolicLinkKey
│  ├─ Check isSymbolicLink == true
│  └─ Skip if symlink
└─ No
   └─ No changes needed
```

## Support

For questions or security concerns:
- Review: `Docs/Security/SECURITY_AUDIT_SYMLINK_PROTECTION.md`
- Tests: `/Forma File OrganizingTests/SymlinkSecurityTests.swift`
- Code: `/Services/FileSystemService.swift` (scanning)
- Code: `/Services/FileOperationsService.swift` (operations)
