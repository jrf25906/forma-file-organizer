import Foundation

/// Centralized utilities for handling special characters in filenames.
///
/// macOS allows almost any character in filenames except `:` (reserved for resource forks)
/// and `/` (path separator). This means filenames can contain:
/// - Unicode characters and emoji (🎉, 日本語, etc.)
/// - Brackets, parentheses, braces: `[test]`, `(copy)`, `{backup}`
/// - Quotes: `"document"`, `'notes'`
/// - Special symbols: `@`, `#`, `$`, `%`, `&`, `*`, `+`, `=`, etc.
/// - Whitespace variations: spaces, tabs, non-breaking spaces
/// - Control characters (though discouraged)
///
/// This utility provides safe handling for:
/// 1. Display (truncation, sanitization for UI)
/// 2. Rule pattern matching (escaping regex metacharacters)
/// 3. Logging (safe string interpolation)
/// 4. Comparison and sorting (Unicode normalization)
enum FilenameUtilities {

    // MARK: - Constants

    /// Maximum display length for filenames in compact UI contexts
    static let maxDisplayLength = 50

    /// Maximum display length for filenames in expanded/detail contexts
    static let maxDetailDisplayLength = 100

    /// Characters that are invalid in macOS filenames
    static let invalidMacOSChars = CharacterSet(charactersIn: ":/")

    /// Regex metacharacters that need escaping for literal string matching
    private static let regexMetacharacters = CharacterSet(charactersIn: "\\^$.|?*+()[]{}")

    // MARK: - Display Utilities

    /// Returns a display-safe version of the filename.
    ///
    /// This method:
    /// - Truncates to maxLength with ellipsis in the middle (preserving extension)
    /// - Normalizes Unicode to NFC form for consistent display
    /// - Replaces control characters with visible placeholders
    ///
    /// - Parameters:
    ///   - filename: The original filename
    ///   - maxLength: Maximum display length (default: 50)
    /// - Returns: A display-safe string
    static func displayName(_ filename: String, maxLength: Int = maxDisplayLength) -> String {
        // Normalize Unicode for consistent display
        let normalized = filename.precomposedStringWithCanonicalMapping

        // Replace control characters with visible placeholder
        let sanitized = normalized.unicodeScalars.map { scalar -> String in
            if scalar.properties.isWhitespace && scalar != " " {
                // Replace non-space whitespace (tabs, etc.) with regular space
                return " "
            } else if scalar.value < 32 && scalar != "\n" && scalar != "\r" && scalar != "\t" {
                // Replace control characters with replacement character
                return "␀"
            }
            return String(scalar)
        }.joined()

        // If already short enough, return as-is
        guard sanitized.count > maxLength else {
            return sanitized
        }

        // Smart truncation: preserve file extension
        let url = URL(fileURLWithPath: sanitized)
        let ext = url.pathExtension
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent

        if ext.isEmpty {
            // No extension - truncate in middle
            return truncateMiddle(sanitized, maxLength: maxLength)
        }

        // Reserve space for extension and ellipsis
        let extPart = ".\(ext)"
        let availableForName = maxLength - extPart.count - 1 // -1 for ellipsis

        if availableForName < 10 {
            // Extension too long, just truncate the whole thing
            return truncateMiddle(sanitized, maxLength: maxLength)
        }

        // Truncate name, keep extension
        let truncatedName = String(nameWithoutExt.prefix(availableForName)) + "…"
        return truncatedName + extPart
    }

    /// Truncates a string in the middle, preserving start and end.
    ///
    /// - Parameters:
    ///   - string: The string to truncate
    ///   - maxLength: Maximum length including ellipsis
    /// - Returns: Truncated string with "…" in the middle
    static func truncateMiddle(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }

        let halfLength = (maxLength - 1) / 2 // -1 for ellipsis
        let startIndex = string.index(string.startIndex, offsetBy: halfLength)
        let endIndex = string.index(string.endIndex, offsetBy: -halfLength)

        return String(string[..<startIndex]) + "…" + String(string[endIndex...])
    }

    // MARK: - Pattern Matching Utilities

    /// Escapes a string for safe use in regex pattern matching.
    ///
    /// When users create rules with conditions like "nameContains",
    /// they expect literal matching. A filename like "file[1].txt" should
    /// match "file[1]" literally, not as a regex character class.
    ///
    /// - Parameter literal: The literal string to escape
    /// - Returns: A regex-safe escaped string
    static func escapeForRegex(_ literal: String) -> String {
        var escaped = ""
        for char in literal {
            if String(char).rangeOfCharacter(from: regexMetacharacters) != nil {
                escaped.append("\\")
            }
            escaped.append(char)
        }
        return escaped
    }

    /// Performs case-insensitive literal string matching.
    ///
    /// This is preferred over regex for user-defined rule patterns
    /// because it handles special characters correctly without escaping.
    ///
    /// - Parameters:
    ///   - filename: The filename to search in
    ///   - pattern: The pattern to search for
    /// - Returns: True if filename contains pattern (case-insensitive)
    static func containsLiteral(_ filename: String, pattern: String) -> Bool {
        // Normalize both strings for consistent comparison
        let normalizedFilename = filename.precomposedStringWithCanonicalMapping.lowercased()
        let normalizedPattern = pattern.precomposedStringWithCanonicalMapping.lowercased()

        return normalizedFilename.contains(normalizedPattern)
    }

    /// Checks if filename starts with pattern (case-insensitive, Unicode-normalized).
    static func startsWithLiteral(_ filename: String, prefix: String) -> Bool {
        let normalizedFilename = filename.precomposedStringWithCanonicalMapping.lowercased()
        let normalizedPrefix = prefix.precomposedStringWithCanonicalMapping.lowercased()

        return normalizedFilename.hasPrefix(normalizedPrefix)
    }

    /// Checks if filename ends with pattern (case-insensitive, Unicode-normalized).
    static func endsWithLiteral(_ filename: String, suffix: String) -> Bool {
        let normalizedFilename = filename.precomposedStringWithCanonicalMapping.lowercased()
        let normalizedSuffix = suffix.precomposedStringWithCanonicalMapping.lowercased()

        return normalizedFilename.hasSuffix(normalizedSuffix)
    }

    // MARK: - Logging Utilities

    /// Returns a log-safe version of the filename.
    ///
    /// Prevents issues with:
    /// - Format specifiers (%s, %d, etc.)
    /// - Newlines that break log parsing
    /// - Very long names that flood logs
    ///
    /// - Parameter filename: The original filename
    /// - Returns: A log-safe string (max 100 chars)
    static func logSafe(_ filename: String) -> String {
        // Replace potential format specifiers
        var safe = filename.replacingOccurrences(of: "%", with: "%%")

        // Replace newlines and carriage returns
        safe = safe.replacingOccurrences(of: "\n", with: "\\n")
        safe = safe.replacingOccurrences(of: "\r", with: "\\r")

        // Truncate if too long
        if safe.count > maxDetailDisplayLength {
            safe = truncateMiddle(safe, maxLength: maxDetailDisplayLength)
        }

        return safe
    }

    // MARK: - Validation Utilities

    /// Checks if a filename contains only valid macOS filename characters.
    ///
    /// - Parameter filename: The filename to validate
    /// - Returns: True if valid, false if contains `:` or `/`
    static func isValidMacOSFilename(_ filename: String) -> Bool {
        return filename.rangeOfCharacter(from: invalidMacOSChars) == nil && !filename.isEmpty
    }

    /// Returns a sanitized filename safe for macOS.
    ///
    /// Replaces invalid characters with underscores.
    ///
    /// - Parameter filename: The original filename
    /// - Returns: A sanitized filename
    static func sanitizeForMacOS(_ filename: String) -> String {
        guard !filename.isEmpty else { return "unnamed" }

        var sanitized = filename

        // Replace colons (reserved in macOS for resource forks)
        sanitized = sanitized.replacingOccurrences(of: ":", with: "_")

        // Replace forward slashes (path separator)
        sanitized = sanitized.replacingOccurrences(of: "/", with: "_")

        // Trim leading/trailing whitespace and dots
        sanitized = sanitized.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))

        // Ensure non-empty
        if sanitized.isEmpty {
            return "unnamed"
        }

        return sanitized
    }

    // MARK: - Comparison Utilities

    /// Compares two filenames with proper Unicode normalization.
    ///
    /// This ensures that filenames like "café" (composed) and "café" (decomposed)
    /// are treated as equal when comparing or sorting.
    ///
    /// - Parameters:
    ///   - lhs: First filename
    ///   - rhs: Second filename
    /// - Returns: True if filenames are equivalent
    static func areEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        return lhs.precomposedStringWithCanonicalMapping == rhs.precomposedStringWithCanonicalMapping
    }

    /// Returns a normalized filename for consistent sorting and comparison.
    ///
    /// - Parameter filename: The original filename
    /// - Returns: NFC-normalized lowercase string
    static func normalizedForComparison(_ filename: String) -> String {
        return filename.precomposedStringWithCanonicalMapping.lowercased()
    }
}
