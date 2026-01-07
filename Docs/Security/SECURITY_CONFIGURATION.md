# Security Configuration Guide

This document describes the security parameters and configuration options for Forma File Organizing application.

## Rate Limiting Configuration

### Batch File Operations

Rate limiting is applied to batch file operations to prevent resource exhaustion and ensure system stability.

#### Parameters

| Parameter | Default Value | Description | Security Impact |
|-----------|--------------|-------------|-----------------|
| `maxBatchSize` | 1000 files | Maximum number of files to process in a single batch operation | Prevents CPU/disk exhaustion and UI freeze |
| `operationDelayNanoseconds` | 100,000,000 (100ms) | Delay between individual file operations | Prevents disk I/O saturation and thermal throttling |

#### Location

```
/Services/FileOperationsService.swift
```

```swift
// MARK: - Rate Limiting Configuration
private static let maxBatchSize = 1000
private static let operationDelayNanoseconds: UInt64 = 100_000_000 // 100ms
```

### Tuning Guidelines

#### When to Increase Limits

Consider increasing limits if:

1. **High-End Hardware:** Systems with 32GB+ RAM and NVMe SSD
2. **Server Environment:** Running on dedicated file processing servers
3. **Batch Processing:** Dedicated batch processing windows

**Example:**
```swift
// For high-end systems (adjust with caution)
private static let maxBatchSize = 2000
private static let operationDelayNanoseconds: UInt64 = 50_000_000 // 50ms
```

#### When to Decrease Limits

Consider decreasing limits if:

1. **Low-End Hardware:** Systems with 8GB RAM or slower HDDs
2. **Background Processing:** Running while user performs other tasks
3. **Thermal Constraints:** Laptops prone to thermal throttling

**Example:**
```swift
// For low-end systems or background processing
private static let maxBatchSize = 500
private static let operationDelayNanoseconds: UInt64 = 200_000_000 // 200ms
```

### Performance vs Security Trade-offs

| Configuration | Files/sec | Memory Usage | System Load | User Experience |
|--------------|-----------|--------------|-------------|-----------------|
| Aggressive (50ms, 2000) | 20/sec | High | High | Fast but may lag |
| Default (100ms, 1000) | 10/sec | Medium | Medium | Balanced |
| Conservative (200ms, 500) | 5/sec | Low | Low | Slow but stable |

**Recommendation:** Keep default values unless specific requirements dictate otherwise.

## Path Validation Configuration

### Maximum Path Lengths

| Parameter | Default Value | macOS Limit | Description |
|-----------|--------------|-------------|-------------|
| `maxPathLength` | 1024 | PATH_MAX (1024) | Maximum total path length |
| `maxComponentLength` | 255 | NAME_MAX (255) | Maximum filename/folder length |

**Location:** `/Services/FileOperationsService.swift`

```swift
private static let maxPathLength = 1024
private static let maxComponentLength = 255
```

**Security Note:** These limits prevent buffer overflow attacks and ensure compatibility with macOS filesystem limits.

### Reserved System Names

The following macOS system folders are blocked from use as destinations:

```swift
private static let reservedMacOSNames: Set<String> = [
    ".Trash", ".Spotlight-V100", ".DocumentRevisions-V100",
    ".TemporaryItems", ".fseventsd", ".VolumeIcon.icns",
    ".DS_Store", ".localized", ".file", ".hotfiles.btree",
    ".vol", "System", "Library", "Applications",
    "private", "bin", "sbin", "usr", "var", "tmp", "etc",
    "cores", "dev", ".PKInstallSandboxManager",
    ".PKInstallSandboxManager-SystemSoftware"
]
```

**Security Impact:** Prevents accidental or malicious writes to critical system directories.

## Security-Scoped Bookmarks

### Source Folder Bookmarks

Standard macOS folders that require security-scoped bookmarks when sandboxed:

```swift
let sourceFolderBookmarks: [String: String] = [
    "Desktop": "DesktopFolderBookmark",
    "Downloads": "DownloadsFolderBookmark",
    "Documents": "DocumentsFolderBookmark",
    "Pictures": "PicturesFolderBookmark",
    "Music": "MusicFolderBookmark"
]
```

### Bookmark Storage

Bookmarks are stored in `UserDefaults` with the following key pattern:

```
DestinationFolderBookmark_<FolderName>
```

**Example:**
- Desktop destination: `DestinationFolderBookmark_Desktop`
- Custom folder: `DestinationFolderBookmark_Work`

## TOCTOU Protection

### File Descriptor Management

Time-of-Check-Time-of-Use (TOCTOU) protection is implemented using file descriptors:

```swift
// Open file descriptor with O_NOFOLLOW to prevent symlink attacks
let fd = open(path, O_RDONLY | O_NOFOLLOW)
defer { close(fd) }

// Validate file using fstat() on the open descriptor
var fileStat = stat()
guard fstat(fd, &fileStat) == 0 else {
    throw FileOperationError.operationFailed("Cannot stat source file")
}
```

**Security Benefits:**
- Prevents symlink race conditions (CWE-61)
- Ensures file validation applies to the actual file being moved
- Blocks attacks where file is swapped between check and operation

## Debug Logging

### Production Logging

Security-critical events are logged even in production builds:

```swift
// Always logged (not wrapped in #if DEBUG)
print("⚠️ Batch file operation limited: \(originalCount) files requested, processing \(maxBatchSize)")
print("⚠️ SECURITY: Batch size limited to \(maxBatchSize) files")
```

### Debug-Only Logging

Detailed security diagnostics are available in debug builds:

```swift
#if DEBUG
print("🔴 SECURITY: Null byte injection attempt detected")
print("🔴 SECURITY: Path traversal attempt detected")
print("🔴 SECURITY: Symlink attack detected")
print("✅ SECURITY: File validated successfully")
#endif
```

**Note:** Debug logging includes file paths and may contain sensitive information. Only enable in development environments.

## Security Monitoring

### Key Metrics to Monitor

1. **Batch Size Warnings**
   - Watch for frequent batch size limit warnings
   - May indicate misconfiguration or attack attempts

2. **Path Validation Failures**
   - Track rejected paths and attack patterns
   - Alert on path traversal attempts

3. **TOCTOU Violations**
   - Monitor symlink rejection rate
   - Investigate unexpected file descriptor failures

4. **Resource Usage**
   - Track memory growth during batch operations
   - Alert on excessive disk I/O

### Recommended Monitoring

```swift
// Future enhancement: Metrics collection
class SecurityMetrics {
    static var batchSizeLimitHits: Int = 0
    static var pathTraversalAttempts: Int = 0
    static var symlinkRejections: Int = 0
    static var toctouViolations: Int = 0

    static func recordBatchSizeLimit() {
        batchSizeLimitHits += 1
        if batchSizeLimitHits > 10 {
            // Alert: Frequent batch size limiting
        }
    }

    static func recordPathTraversal() {
        pathTraversalAttempts += 1
        // Alert: Potential attack
    }
}
```

## Incident Response

### If Rate Limiting is Triggered Frequently

1. **Investigate Source**
   - Check if legitimate large batches
   - Look for automation or scripts creating excessive files

2. **Tune Parameters**
   - Consider increasing limits for legitimate use cases
   - Or implement user-facing batch chunking

3. **Alert Users**
   - Add UI notification when batches are limited
   - Provide guidance on processing large sets

### If Path Traversal Detected

1. **Block Operation**
   - Operation is automatically blocked
   - Error message returned to user

2. **Log Event**
   - Full path and context logged
   - Timestamp and user action recorded

3. **Investigate**
   - Determine if user error or attack
   - Review rule configuration
   - Check for compromised rule definitions

### If TOCTOU Attack Detected

1. **Operation Fails**
   - File operation is prevented
   - Detailed error logged

2. **Alert**
   - Security team notification (if configured)
   - Log includes file path and descriptor info

3. **Review**
   - Check for malicious processes
   - Review system security posture
   - Verify no unauthorized access

## Compliance

### CWE Mappings

- **CWE-22:** Path Traversal (Mitigated by path validation)
- **CWE-61:** UNIX Symbolic Link Following (Mitigated by O_NOFOLLOW)
- **CWE-158:** Null Byte Injection (Mitigated by input validation)
- **CWE-367:** TOCTOU Race Condition (Mitigated by file descriptors)
- **CWE-400:** Resource Exhaustion (Mitigated by rate limiting)

### OWASP Top 10 2021

- **A01:2021 - Broken Access Control:** Addressed by bookmark validation
- **A03:2021 - Injection:** Addressed by path sanitization
- **A04:2021 - Insecure Design:** Addressed by rate limiting and TOCTOU protection

## Security Updates

### Version History

| Version | Date | Changes | Security Impact |
|---------|------|---------|-----------------|
| 1.1 | 2025-11-30 | Added rate limiting to batch operations | Prevents resource exhaustion (CWE-400) |
| 1.0 | 2025-11-29 | Initial security hardening | TOCTOU protection, path validation |

### Future Enhancements

1. **Adaptive Rate Limiting**
   - Adjust limits based on system resources
   - Scale with available memory/CPU

2. **User-Configurable Limits**
   - Allow power users to adjust limits
   - Provide presets (Conservative/Balanced/Aggressive)

3. **Progress Reporting**
   - Show progress for large batches
   - Allow cancellation mid-operation

4. **Metrics Dashboard**
   - Security event visualization
   - Performance monitoring
   - Anomaly detection

## Contact

For security concerns or questions about this configuration:

- Review documentation: `Docs/Security/SECURITY_AUDIT_*.md`
- Check test coverage: `Forma File OrganizingTests/*SecurityTests.swift`
- Report vulnerabilities: Follow responsible disclosure

---

**Last Updated:** 2025-11-30
**Document Version:** 1.1
**Reviewed By:** Security Auditor Agent
