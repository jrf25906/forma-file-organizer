# Security Headers and Configuration

## macOS Sandbox Entitlements

Ensure your `*.entitlements` file has the minimal required permissions:

### ✅ RECOMMENDED: Secure Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- User-Selected File Access (Security-Scoped Bookmarks) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Network Access (if needed) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>

    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>

    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>

    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>

    <!-- Disable Dangerous Entitlements -->
    <key>com.apple.security.files.downloads.read-write</key>
    <false/>

    <key>com.apple.security.files.all</key>
    <false/>
</dict>
</plist>
```

### ❌ AVOID: Insecure Configuration

```xml
<!-- DO NOT USE THESE ENTITLEMENTS -->

<!-- Grants access to all files - too permissive -->
<key>com.apple.security.files.all</key>
<true/>

<!-- Grants automatic Downloads access - bypass user consent -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- Temporary exceptions - reduce sandbox protection -->
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/Users/</string>
</array>

<!-- Weakens code signing protection -->
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

## Info.plist Security Configuration

### Privacy Usage Descriptions

```xml
<!-- Required for accessing user-selected folders -->
<key>NSDesktopFolderUsageDescription</key>
<string>Forma needs access to organize files on your Desktop.</string>

<key>NSDownloadsFolderUsageDescription</key>
<string>Forma needs access to organize files in your Downloads folder.</string>

<key>NSDocumentsFolderUsageDescription</key>
<string>Forma needs access to organize files in your Documents folder.</string>

<!-- Add for other folders as needed -->
<key>NSPicturesFolderUsageDescription</key>
<string>Forma needs access to organize your Pictures.</string>

<key>NSMusicFolderUsageDescription</key>
<string>Forma needs access to organize your Music files.</string>
```

## Build Settings Security

### Code Signing Settings

```
ENABLE_HARDENED_RUNTIME = YES
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development / Apple Distribution
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

### Deployment Target

```
MACOSX_DEPLOYMENT_TARGET = 13.0  // Or latest supported
```

### Build Options

```
GCC_OPTIMIZATION_LEVEL = s  // Optimize for size in production
SWIFT_OPTIMIZATION_LEVEL = -O  // Full optimization
ENABLE_BITCODE = NO  // Not supported on macOS
STRIP_INSTALLED_PRODUCT = YES  // Strip symbols in release
COPY_PHASE_STRIP = YES
```

## Runtime Security Checks

### Bookmark Validation Constants

Add to your security configuration:

```swift
// FileSystemService.swift or SecurityConfig.swift

/// Security configuration for bookmark validation
struct SecurityConfig {
    /// Maximum allowed bookmark age before forced re-validation (in days)
    static let maxBookmarkAge: TimeInterval = 30 * 24 * 60 * 60

    /// Enable strict path validation
    static let strictPathValidation = true

    /// Enable security audit logging
    #if DEBUG
    static let enableSecurityLogging = true
    #else
    static let enableSecurityLogging = false
    #endif

    /// Allowed folder names for standard bookmarks
    static let allowedStandardFolders = [
        "Desktop",
        "Downloads",
        "Documents",
        "Pictures",
        "Music"
    ]

    /// Validate bookmark is within user home directory
    static func isPathSecure(_ path: String) -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(homeDir)
    }

    /// Log security event (debug builds only)
    static func logSecurityEvent(_ event: String, level: SecurityLevel = .warning) {
        #if DEBUG
        if enableSecurityLogging {
            let timestamp = Date().ISO8601Format()
            print("[\(timestamp)] [SECURITY-\(level.rawValue)] \(event)")
        }
        #endif
    }
}

enum SecurityLevel: String {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}
```

## UserDefaults Security

### Encryption for Sensitive Data

While bookmarks themselves are opaque data, consider additional protection:

```swift
import CryptoKit

class SecureBookmarkStorage {
    private let keychain = KeychainHelper.shared

    /// Store bookmark with integrity check
    func storeBookmark(_ data: Data, forKey key: String) throws {
        // Generate hash for integrity verification
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        // Store bookmark data
        UserDefaults.standard.set(data, forKey: key)

        // Store integrity hash separately
        UserDefaults.standard.set(hashString, forKey: "\(key)_hash")
    }

    /// Retrieve bookmark and verify integrity
    func retrieveBookmark(forKey key: String) throws -> Data? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let storedHash = UserDefaults.standard.string(forKey: "\(key)_hash") else {
            return nil
        }

        // Verify integrity
        let computedHash = SHA256.hash(data: data)
        let computedHashString = computedHash.compactMap { String(format: "%02x", $0) }.joined()

        guard computedHashString == storedHash else {
            // Integrity check failed - possible tampering
            SecurityConfig.logSecurityEvent(
                "Bookmark integrity check failed for key: \(key)",
                level: .critical
            )
            throw SecurityError.integrityCheckFailed
        }

        return data
    }
}

enum SecurityError: Error {
    case integrityCheckFailed
}
```

## Network Security (if applicable)

### App Transport Security

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Require secure connections -->
    <key>NSAllowsArbitraryLoads</key>
    <false/>

    <!-- Enable Certificate Transparency -->
    <key>NSRequiresCertificateTransparency</key>
    <true/>

    <!-- Minimum TLS Version -->
    <key>NSExceptionMinimumTLSVersion</key>
    <string>TLSv1.3</string>
</dict>
```

## Security Monitoring

### Audit Logging Configuration

```swift
class SecurityAuditLogger {
    static let shared = SecurityAuditLogger()

    private let auditLogKey = "SecurityAuditLog"
    private let maxLogEntries = 1000

    struct AuditEntry: Codable {
        let timestamp: Date
        let event: String
        let severity: SecurityLevel
        let details: [String: String]
    }

    func log(event: String, severity: SecurityLevel, details: [String: String] = [:]) {
        let entry = AuditEntry(
            timestamp: Date(),
            event: event,
            severity: severity,
            details: details
        )

        var entries = getAuditLog()
        entries.append(entry)

        // Keep only recent entries
        if entries.count > maxLogEntries {
            entries = Array(entries.suffix(maxLogEntries))
        }

        saveAuditLog(entries)

        #if DEBUG
        print("[AUDIT] \(severity.rawValue): \(event)")
        if !details.isEmpty {
            print("        Details: \(details)")
        }
        #endif
    }

    private func getAuditLog() -> [AuditEntry] {
        guard let data = UserDefaults.standard.data(forKey: auditLogKey),
              let entries = try? JSONDecoder().decode([AuditEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveAuditLog(_ entries: [AuditEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: auditLogKey)
        }
    }

    /// Export audit log for security review
    func exportAuditLog() -> String {
        let entries = getAuditLog()
        let lines = entries.map { entry in
            let details = entry.details.isEmpty ? "" : " | \(entry.details)"
            return "[\(entry.timestamp.ISO8601Format())] [\(entry.severity.rawValue)] \(entry.event)\(details)"
        }
        return lines.joined(separator: "\n")
    }
}
```

### Usage in Validation Code

```swift
// In FileSystemService.swift

guard url.path.hasPrefix(homeDir.path) else {
    UserDefaults.standard.removeObject(forKey: bookmarkKey)

    // Log security event
    SecurityAuditLogger.shared.log(
        event: "Bookmark validation failed - outside home directory",
        severity: .critical,
        details: [
            "bookmarkKey": bookmarkKey,
            "attemptedPath": url.path,
            "homeDirectory": homeDir.path
        ]
    )

    throw FileSystemError.permissionDenied
}
```

## Recommended Security Headers Checklist

- [x] App Sandbox enabled
- [x] User-selected file access only (not blanket file access)
- [x] Hardened runtime enabled
- [x] No dangerous entitlements (files.all, temporary-exception)
- [x] Code signing configured
- [x] Privacy usage descriptions added
- [x] Bookmark validation implemented
- [x] Security audit logging configured
- [ ] Certificate pinning (if using network)
- [ ] Keychain for sensitive data
- [ ] App Transport Security configured
- [ ] Strip symbols in release builds

## Testing Security Configuration

### Validate Entitlements

```bash
# Check entitlements of built app
codesign -d --entitlements - /path/to/Forma.app

# Verify code signature
codesign --verify --deep --strict --verbose=2 /path/to/Forma.app

# Check hardened runtime
codesign -dvvv /path/to/Forma.app | grep -i runtime
```

### Test Sandbox Restrictions

```bash
# App should NOT have access to these locations without user consent:
# - /etc
# - /var
# - /System
# - /Users (other users)
# - ~/.ssh
# - System preferences files

# Test with sample code:
# let testPath = "/etc/hosts"
# let canRead = FileManager.default.isReadableFile(atPath: testPath)
# // Should return false in sandboxed app
```

## Security Review Schedule

- **Weekly:** Review security audit logs
- **Monthly:** Update dependencies for security patches
- **Quarterly:** Full security audit of file system operations
- **Annually:** Third-party security assessment

---

**Last Updated:** 2025-11-30
**Review By:** 2026-01-30
