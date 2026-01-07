import Foundation

/// Centralized path validation utility for secure destination path checking.
///
/// Implements defense-in-depth security measures against:
/// - Path traversal attacks (CWE-22)
/// - Null byte injection (CWE-158)
/// - Symlink attacks (CWE-61)
/// - Reserved system names
/// - Path length limits (buffer overflow prevention)
///
/// OWASP Reference: A01:2021 – Broken Access Control
enum PathValidator {
    
    // MARK: - Constants
    
    /// macOS PATH_MAX limit
    static let maxPathLength = 1024
    
    /// macOS NAME_MAX limit
    static let maxComponentLength = 255
    
    /// Reserved macOS system folder names that should never be used as destinations
    static let reservedMacOSNames: Set<String> = [
        ".Trash", ".Spotlight-V100", ".DocumentRevisions-V100", ".TemporaryItems",
        ".fseventsd", ".VolumeIcon.icns", ".DS_Store", ".localized",
        ".file", ".hotfiles.btree", ".vol", "System", "Library", "Applications",
        "private", "bin", "sbin", "usr", "var", "tmp", "etc", "cores", "dev",
        ".PKInstallSandboxManager", ".PKInstallSandboxManager-SystemSoftware"
    ]
    
    // MARK: - Validation Errors
    
    enum ValidationError: LocalizedError {
        case empty
        case tooLong(length: Int)
        case componentTooLong(component: String, length: Int)
        case nullByteInjection
        case absolutePath
        case suspiciousPath(reason: String)
        case invalidCharacters(characters: String)
        case pathTraversal(component: String)
        case reservedName(name: String)
        case symlinkEscape
        
        var errorDescription: String? {
            switch self {
            case .empty:
                return "Destination path cannot be empty"
            case .tooLong(let length):
                return "Destination path too long (\(length) characters, max \(maxPathLength))"
            case .componentTooLong(let component, let length):
                return "Path component '\(component)' too long (\(length) characters, max \(maxComponentLength))"
            case .nullByteInjection:
                return "Invalid characters in destination path"
            case .absolutePath:
                return "Destination must be a relative path (e.g., 'Pictures' or 'Documents/Work'). Absolute paths are not allowed."
            case .suspiciousPath(let reason):
                return "Invalid destination: \(reason)"
            case .invalidCharacters(let chars):
                return "Invalid characters in path: \(chars)"
            case .pathTraversal(let component):
                return "Path traversal attempts are not allowed: \(component)"
            case .reservedName(let name):
                return "'\(name)' is a reserved system folder name"
            case .symlinkEscape:
                return "Destination path escapes home directory (possible symlink attack)"
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates a destination path with comprehensive security checks.
    ///
    /// - Parameter path: The raw destination path from user input or rules
    /// - Returns: A sanitized, validated path safe for use
    /// - Throws: `ValidationError` if the path is invalid or malicious
    static func validate(_ path: String) throws -> String {
        // 1. Trim whitespace and newlines
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Reject empty paths
        guard !trimmed.isEmpty else {
            throw ValidationError.empty
        }
        
        // 3. SECURITY: Check for null byte injection (CWE-158)
        guard !trimmed.contains("\0") else {
            #if DEBUG
            Log.error("SECURITY: Null byte injection attempt detected in path: \(path)", category: .security)
            #endif
            throw ValidationError.nullByteInjection
        }
        
        // 4. SECURITY: REJECT absolute paths outright (prevent directory escape)
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            #if DEBUG
            Log.error("SECURITY: Absolute path rejected: \(trimmed)", category: .security)
            #endif
            throw ValidationError.absolutePath
        }
        
        // 5. SECURITY: Reject paths that look like absolute paths without leading slash
        // e.g., "Users/username/..." or "Volumes/..." (common attack vector)
        if trimmed.hasPrefix("Users/") || trimmed.hasPrefix("Volumes/") ||
           trimmed.hasPrefix("System/") || trimmed.hasPrefix("Library/") {
            #if DEBUG
            Log.error("SECURITY: Suspicious absolute-like path rejected: \(trimmed)", category: .security)
            #endif
            throw ValidationError.suspiciousPath(reason: "Use relative paths like 'Pictures' or 'Documents/Work'.")
        }
        
        // 6. SECURITY: Check total path length (prevent buffer overflow-style attacks)
        guard trimmed.count <= maxPathLength else {
            throw ValidationError.tooLong(length: trimmed.count)
        }
        
        // 7. Split into components and validate each
        let components = trimmed.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            throw ValidationError.empty
        }
        
        for component in components {
            // 7a. Check component length (NAME_MAX)
            guard component.count <= maxComponentLength else {
                throw ValidationError.componentTooLong(component: component, length: component.count)
            }
            
            // 7b. SECURITY: REJECT directory traversal attempts (CWE-22)
            // Block ".." and "." as entire components (but allow ".hidden" folders)
            if component == ".." || component == "." {
                #if DEBUG
                Log.error("SECURITY: Path traversal attempt detected: \(component) in \(trimmed)", category: .security)
                #endif
                throw ValidationError.pathTraversal(component: component)
            }
            
            // 7c. SECURITY: Check for invalid macOS filename characters
            let invalidChars = CharacterSet(charactersIn: ":<>|\"\\0")
            if component.rangeOfCharacter(from: invalidChars) != nil {
                #if DEBUG
                Log.error("SECURITY: Invalid characters in path component: \(component)", category: .security)
                #endif
                throw ValidationError.invalidCharacters(characters: component)
            }
            
            // 7d. SECURITY: Check for reserved macOS system names
            if reservedMacOSNames.contains(component) || reservedMacOSNames.contains("." + component) {
                #if DEBUG
                Log.error("SECURITY: Reserved macOS system name rejected: \(component)", category: .security)
                #endif
                throw ValidationError.reservedName(name: component)
            }
        }
        
        // 8. Construct the full path relative to home directory
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let proposedURL = homeURL.appendingPathComponent(trimmed)
        
        // 9. SECURITY: Resolve symlinks and verify the canonical path stays within home directory
        // This prevents symlink-based directory traversal attacks (CWE-61)
        let standardizedURL = proposedURL.standardized
        let canonicalPath = standardizedURL.path
        
        // Verify the resolved path is still within the home directory
        let homeDir = homeURL.path
        guard canonicalPath.hasPrefix(homeDir) else {
            #if DEBUG
            Log.error("SECURITY: Symlink escape attempt detected. Proposed: \(proposedURL.path), Resolved: \(canonicalPath), Home: \(homeDir)", category: .security)
            #endif
            throw ValidationError.symlinkEscape
        }
        
        // 10. Return the sanitized relative path (not the canonical one, to preserve user intent)
        #if DEBUG
        Log.debug("SECURITY: Path validated successfully: \(trimmed), canonical: \(canonicalPath)", category: .security)
        #endif
        
        return trimmed
    }
    
    /// Quick validation check without throwing (returns Bool).
    ///
    /// Useful for UI validation where you just need to show/hide error states.
    ///
    /// - Parameter path: The path to validate
    /// - Returns: `true` if valid, `false` otherwise
    static func isValid(_ path: String) -> Bool {
        do {
            _ = try validate(path)
            return true
        } catch {
            return false
        }
    }
    
    /// Validates and returns validation error if invalid.
    ///
    /// Useful for showing specific error messages in UI.
    ///
    /// - Parameter path: The path to validate
    /// - Returns: `nil` if valid, or the specific validation error
    static func validationError(for path: String) -> ValidationError? {
        do {
            _ = try validate(path)
            return nil
        } catch let error as ValidationError {
            return error
        } catch {
            return .invalidCharacters(characters: "unknown")
        }
    }
}
