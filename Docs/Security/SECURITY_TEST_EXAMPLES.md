# Security Test Examples - Path Traversal Prevention

## Attack Vectors BLOCKED by Security Fixes

### 1. Directory Traversal Attacks (CWE-22)

#### Attack: Parent Directory Traversal
```swift
// ATTACK: Try to escape to /etc
let maliciousPath = "../../../../../../etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: ".." detected as path component
// Error: "Path traversal attempts are not allowed"
```

#### Attack: Current Directory Reference
```swift
// ATTACK: Use "." to bypass validation
let maliciousPath = "Pictures/./../../etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: "." detected as path component
// Error: "Path traversal attempts are not allowed"
```

### 2. Absolute Path Attacks

#### Attack: Direct Absolute Path
```swift
// ATTACK: Use absolute path to access system files
let maliciousPath = "/etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: Path starts with "/"
// Error: "Destination must be a relative path... Absolute paths are not allowed."
```

#### Attack: Tilde Expansion
```swift
// ATTACK: Use home directory shortcut
let maliciousPath = "~/../../etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: Path starts with "~"
// Error: "Destination must be a relative path... Absolute paths are not allowed."
```

#### Attack: Absolute-Like Path Without Leading Slash
```swift
// ATTACK: Craft path that looks absolute
let maliciousPath = "Users/victim/Documents/secrets.txt"

// RESULT: ✅ BLOCKED
// Reason: Path starts with "Users/"
// Error: "Invalid destination. Use relative paths like 'Pictures' or 'Documents/Work'."
```

```swift
// ATTACK: Access system files via Library
let maliciousPath = "Library/../../etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: Path starts with "Library/"
// Error: "Invalid destination. Use relative paths..."
```

### 3. Symlink Attacks (CWE-61)

#### Attack: Symlink to System Directory
```bash
# Setup: Attacker creates symlink
ln -s /System ~/Documents/evil_link

# ATTACK: Use symlink in destination
let maliciousPath = "Documents/evil_link/Library"

# RESULT: ✅ BLOCKED
# Reason: Canonical path resolves to /System/Library
# Error: "Destination path escapes home directory (possible symlink attack)"
```

#### Attack: Symlink Chain
```bash
# Setup: Chain of symlinks
ln -s /tmp ~/Documents/link1
ln -s /etc /tmp/link2

# ATTACK: Follow symlink chain
let maliciousPath = "Documents/link1/link2/passwd"

# RESULT: ✅ BLOCKED
# Reason: Canonical path resolves outside home directory
# Error: "Destination path escapes home directory (possible symlink attack)"
```

### 4. Null Byte Injection (CWE-158)

#### Attack: Null Byte Path Termination
```swift
// ATTACK: Use null byte to truncate path
let maliciousPath = "Pictures\0/../../etc/passwd"

// RESULT: ✅ BLOCKED
// Reason: Null byte detected in path
// Error: "Invalid characters in destination path"
```

#### Attack: Null Byte in Component
```swift
// ATTACK: Hide malicious component after null byte
let maliciousPath = "Documents/file\0.exe"

// RESULT: ✅ BLOCKED
// Reason: Null byte detected
// Error: "Invalid characters in destination path"
```

### 5. Reserved System Names

#### Attack: Access Trash Directly
```swift
// ATTACK: Write to system Trash
let maliciousPath = ".Trash/important_file"

// RESULT: ✅ BLOCKED
// Reason: ".Trash" is reserved
// Error: "'.Trash' is a reserved system folder name"
```

#### Attack: Access Spotlight Index
```swift
// ATTACK: Corrupt Spotlight index
let maliciousPath = ".Spotlight-V100/Store-V2/data"

// RESULT: ✅ BLOCKED
// Reason: ".Spotlight-V100" is reserved
// Error: "'.Spotlight-V100' is a reserved system folder name"
```

#### Attack: System Folders
```swift
// ATTACK: Access /System via relative path
let maliciousPath = "System/Library/secrets"

// RESULT: ✅ BLOCKED
// Reason: "System" is reserved AND starts with "System/"
// Error: "Invalid destination. Use relative paths..."
```

### 6. Path Length Attacks

#### Attack: Buffer Overflow via Long Path
```swift
// ATTACK: Exceed PATH_MAX (1024 chars)
let maliciousPath = String(repeating: "a/", count: 600)  // 1200 chars

// RESULT: ✅ BLOCKED
// Reason: Path length > 1024
// Error: "Destination path too long (max 1024 characters)"
```

#### Attack: Long Path Component
```swift
// ATTACK: Exceed NAME_MAX (255 chars)
let maliciousPath = "Pictures/" + String(repeating: "a", count: 300)

// RESULT: ✅ BLOCKED
// Reason: Component length > 255
// Error: "Path component '...' exceeds maximum length (255 characters)"
```

### 7. Invalid Character Attacks

#### Attack: Colon in Path
```swift
// ATTACK: Use macOS-invalid character
let maliciousPath = "Documents/file:stream"

// RESULT: ✅ BLOCKED
// Reason: ":" is invalid on macOS
// Error: "Invalid characters in destination path"
```

#### Attack: Pipe Character
```swift
// ATTACK: Command injection attempt
let maliciousPath = "Documents/file|command"

// RESULT: ✅ BLOCKED
// Reason: "|" is invalid character
// Error: "Invalid characters in destination path"
```

## Valid Paths (Security-Approved)

### Allowed: Standard Relative Paths
```swift
let validPath = "Pictures"
// RESULT: ✅ ALLOWED
// Reason: Simple, relative, no special characters
```

```swift
let validPath = "Documents/Work"
// RESULT: ✅ ALLOWED
// Reason: Valid nested path
```

```swift
let validPath = "Desktop/Projects/2024/January"
// RESULT: ✅ ALLOWED
// Reason: Valid deep nesting
```

### Allowed: Hidden Folders
```swift
let validPath = ".hidden_folder"
// RESULT: ✅ ALLOWED
// Reason: Hidden folders are OK (not "." or "..")
```

```swift
let validPath = "Documents/.config"
// RESULT: ✅ ALLOWED
// Reason: Hidden subfolders are OK
```

### Allowed: Spaces and Special Names
```swift
let validPath = "My Documents"
// RESULT: ✅ ALLOWED
// Reason: Spaces are valid
```

```swift
let validPath = "Projects (2024)"
// RESULT: ✅ ALLOWED
// Reason: Parentheses are valid
```

## Security Test Suite

### Unit Test Example
```swift
import XCTest
@testable import Forma_File_Organizing

class PathTraversalSecurityTests: XCTestCase {

    let service = FileOperationsService()

    func testRejectsDirectoryTraversal() throws {
        let maliciousPaths = [
            "../../etc/passwd",
            "../../../System",
            "Pictures/../../etc",
            "Documents/./../../private"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(
                try service.sanitizeDestinationPath(path),
                "Should reject path traversal: \(path)"
            ) { error in
                XCTAssertTrue(
                    error.localizedDescription.contains("traversal"),
                    "Error should mention traversal"
                )
            }
        }
    }

    func testRejectsAbsolutePaths() throws {
        let maliciousPaths = [
            "/etc/passwd",
            "~/Documents",
            "/tmp/malicious",
            "~root/secrets"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(
                try service.sanitizeDestinationPath(path),
                "Should reject absolute path: \(path)"
            ) { error in
                XCTAssertTrue(
                    error.localizedDescription.contains("absolute"),
                    "Error should mention absolute paths"
                )
            }
        }
    }

    func testRejectsNullByteInjection() throws {
        let maliciousPaths = [
            "Pictures\0/../../etc",
            "Documents/file\0.exe",
            "\0etc/passwd"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(
                try service.sanitizeDestinationPath(path),
                "Should reject null byte: \(path)"
            ) { error in
                XCTAssertTrue(
                    error.localizedDescription.contains("Invalid characters"),
                    "Error should mention invalid characters"
                )
            }
        }
    }

    func testRejectsReservedNames() throws {
        let maliciousPaths = [
            ".Trash/file",
            "System/Library",
            ".Spotlight-V100/data",
            "private/etc"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(
                try service.sanitizeDestinationPath(path),
                "Should reject reserved name: \(path)"
            ) { error in
                // Either reserved name error or suspicious path error
                let message = error.localizedDescription
                XCTAssertTrue(
                    message.contains("reserved") || message.contains("relative paths"),
                    "Error should mention reserved or relative paths"
                )
            }
        }
    }

    func testAllowsValidPaths() throws {
        let validPaths = [
            "Pictures",
            "Documents/Work",
            "Desktop/Projects/2024",
            ".hidden",
            "My Documents",
            "Projects (2024)"
        ]

        for path in validPaths {
            XCTAssertNoThrow(
                try service.sanitizeDestinationPath(path),
                "Should allow valid path: \(path)"
            )
        }
    }

    func testRejectsPathLengthLimits() throws {
        // Test path too long
        let longPath = String(repeating: "a/", count: 600)
        XCTAssertThrowsError(
            try service.sanitizeDestinationPath(longPath),
            "Should reject path exceeding 1024 chars"
        )

        // Test component too long
        let longComponent = "Pictures/" + String(repeating: "a", count: 300)
        XCTAssertThrowsError(
            try service.sanitizeDestinationPath(longComponent),
            "Should reject component exceeding 255 chars"
        )
    }
}
```

## Penetration Testing Checklist

- [ ] Test all attack vectors from this document
- [ ] Fuzz testing with random inputs
- [ ] Race condition testing (TOCTOU attacks)
- [ ] Symbolic link race conditions
- [ ] Case sensitivity edge cases
- [ ] Unicode normalization attacks
- [ ] Mixed encoding attacks
- [ ] Filesystem-specific edge cases
- [ ] Performance testing with extreme inputs
- [ ] Error message information leakage

---

**Last Updated:** 2025-11-30
**Security Level:** Defense in Depth
**Compliance:** OWASP Top 10, CWE Top 25
