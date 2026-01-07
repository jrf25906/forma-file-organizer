import Foundation
import SwiftData
import SwiftUI

/// Defines where rules in a category apply.
///
/// Categories can either apply globally (to files from any location) or be scoped
/// to specific folders. Scoped categories enable use cases like "Work rules only
/// apply to files from ~/Work".
enum CategoryScope: Codable, Equatable, Hashable {
    /// Rules apply to files from any location
    case global

    /// Rules only apply to files from the specified folders
    /// - Parameter bookmarks: Security-scoped bookmark data for each watched folder
    case folders([ScopedFolder])

    /// Represents a folder in the category scope with its bookmark and display name
    struct ScopedFolder: Codable, Equatable, Hashable, Identifiable {
        var id: UUID = UUID()
        let bookmark: Data
        let displayName: String

        /// Creates a scoped folder from a URL by generating a security-scoped bookmark.
        ///
        /// - Parameter url: The folder URL (must be a directory)
        /// - Throws: If bookmark creation fails
        static func from(url: URL) throws -> ScopedFolder {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return ScopedFolder(bookmark: bookmarkData, displayName: url.lastPathComponent)
        }

        /// Resolves the bookmark to a URL.
        ///
        /// - Returns: The resolved URL, or nil if resolution fails
        func resolve() -> URL? {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return url
            } catch {
                Log.error("Failed to resolve scoped folder bookmark: \(error)", category: .bookmark)
                return nil
            }
        }
    }

    // MARK: - Properties

    /// Whether this scope is global (applies everywhere)
    var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    /// The folders in this scope, or empty array for global scope
    var scopedFolders: [ScopedFolder] {
        if case .folders(let folders) = self {
            return folders
        }
        return []
    }

    /// Human-readable description of the scope
    var displayDescription: String {
        switch self {
        case .global:
            return "All locations"
        case .folders(let folders):
            if folders.isEmpty {
                return "No folders selected"
            } else if folders.count == 1 {
                return folders[0].displayName
            } else {
                return "\(folders.count) folders"
            }
        }
    }

    // MARK: - Matching

    /// Checks if a file's source URL matches this scope.
    ///
    /// - Parameter fileURL: The source URL of the file being evaluated
    /// - Returns: True if the file's location matches this scope
    func matches(fileURL: URL) -> Bool {
        switch self {
        case .global:
            return true

        case .folders(let scopedFolders):
            let filePath = fileURL.standardizedFileURL.path

            for scopedFolder in scopedFolders {
                guard let folderURL = scopedFolder.resolve() else { continue }
                let folderPath = folderURL.standardizedFileURL.path

                // Check if file is inside this folder (or is the folder itself)
                if filePath.hasPrefix(folderPath) {
                    return true
                }
            }
            return false
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case folders
    }

    private enum ScopeType: String, Codable {
        case global
        case folders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScopeType.self, forKey: .type)

        switch type {
        case .global:
            self = .global

        case .folders:
            let folders = try container.decode([ScopedFolder].self, forKey: .folders)
            self = .folders(folders)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .global:
            try container.encode(ScopeType.global, forKey: .type)

        case .folders(let folders):
            try container.encode(ScopeType.folders, forKey: .type)
            try container.encode(folders, forKey: .folders)
        }
    }
}

/// A category for organizing rules with optional folder scoping.
///
/// Categories allow users to group rules by context (e.g., Work, Personal) and
/// optionally scope them to specific folders so rules only apply to files from
/// those locations.
///
/// ## Design
///
/// - Each rule belongs to exactly one category (or the default "General" category)
/// - Categories can be global (rules apply everywhere) or folder-scoped
/// - The "General" category is created automatically and cannot be deleted
/// - Categories have a sort order that affects rule evaluation priority
///
/// ## Example
///
/// ```swift
/// // Create a work category scoped to specific folders
/// let workCategory = RuleCategory(
///     name: "Work",
///     colorHex: "#3B82F6",
///     iconName: "briefcase.fill",
///     scope: .folders([workFolder, downloadsWorkFolder])
/// )
///
/// // Rules in this category will only evaluate files from those folders
/// ```
@Model
final class RuleCategory {
    /// Unique identifier for the category.
    @Attribute(.unique) var id: UUID

    /// Display name of the category (e.g., "Work", "Personal").
    var name: String

    /// Hex color string for UI display (e.g., "#3B82F6").
    var colorHex: String

    /// SF Symbol name for the category icon (e.g., "briefcase.fill").
    var iconName: String

    /// Whether this category's rules are currently active.
    ///
    /// When disabled, all rules in this category are skipped during evaluation.
    var isEnabled: Bool

    /// Priority order for rule evaluation (lower values = higher priority).
    ///
    /// When a file could match rules from multiple categories (overlapping scopes),
    /// categories are evaluated in ascending sortOrder.
    var sortOrder: Int

    /// When the category was created.
    var creationDate: Date

    /// Whether this is the default "General" category.
    ///
    /// The default category cannot be deleted or renamed, and has global scope.
    var isDefault: Bool

    // MARK: - Scope Storage (SwiftData-compatible)

    /// Raw JSON storage for the scope. SwiftData cannot persist complex enums directly.
    private var scopeData: Data?

    /// The scope defining where this category's rules apply.
    var scope: CategoryScope {
        get {
            guard let data = scopeData else { return .global }
            do {
                return try JSONDecoder().decode(CategoryScope.self, from: data)
            } catch {
                Log.error("Failed to decode CategoryScope: \(error)", category: .pipeline)
                return .global
            }
        }
        set {
            do {
                scopeData = try JSONEncoder().encode(newValue)
            } catch {
                Log.error("Failed to encode CategoryScope: \(error)", category: .pipeline)
                scopeData = nil
            }
        }
    }

    // MARK: - Initialization

    /// Creates a new rule category.
    ///
    /// - Parameters:
    ///   - name: Display name of the category
    ///   - colorHex: Hex color string for UI (default: blue)
    ///   - iconName: SF Symbol name for icon (default: folder)
    ///   - scope: Where rules in this category apply (default: global)
    ///   - isEnabled: Whether the category is active (default: true)
    ///   - sortOrder: Priority for evaluation (default: 0)
    ///   - isDefault: Whether this is the default category (default: false)
    init(
        name: String,
        colorHex: String = "#3B82F6",
        iconName: String = "folder.fill",
        scope: CategoryScope = .global,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.creationDate = Date()
        self.isDefault = isDefault

        // Encode scope to data
        do {
            self.scopeData = try JSONEncoder().encode(scope)
        } catch {
            Log.error("Failed to encode initial CategoryScope: \(error)", category: .pipeline)
            self.scopeData = nil
        }
    }

    // MARK: - Computed Properties

    /// SwiftUI Color from the hex string.
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    /// Whether files from the given URL would be evaluated by rules in this category.
    func matches(fileURL: URL) -> Bool {
        guard isEnabled else { return false }
        return scope.matches(fileURL: fileURL)
    }
}

// MARK: - Default Category Factory

extension RuleCategory {
    /// Creates the default "General" category.
    ///
    /// This category:
    /// - Has global scope (applies to all files)
    /// - Cannot be deleted
    /// - Is where existing rules are migrated to
    static func createDefault() -> RuleCategory {
        RuleCategory(
            name: "General",
            colorHex: "#6B7280", // Gray
            iconName: "globe",
            scope: .global,
            isEnabled: true,
            sortOrder: 0,
            isDefault: true
        )
    }
}

// MARK: - Quick Start Presets

extension RuleCategory {
    /// Preset configurations for quick category creation.
    enum Preset: CaseIterable {
        case work
        case personal
        case archive
        case photos

        var name: String {
            switch self {
            case .work: return "Work"
            case .personal: return "Personal"
            case .archive: return "Archive"
            case .photos: return "Photos"
            }
        }

        var iconName: String {
            switch self {
            case .work: return "briefcase.fill"
            case .personal: return "house.fill"
            case .archive: return "archivebox.fill"
            case .photos: return "photo.fill"
            }
        }

        var colorHex: String {
            switch self {
            case .work: return "#3B82F6"     // Blue
            case .personal: return "#10B981" // Green
            case .archive: return "#F59E0B"  // Amber
            case .photos: return "#EC4899"   // Pink
            }
        }

        /// Creates a category from this preset.
        ///
        /// - Parameter sortOrder: The sort order for the new category
        /// - Returns: A new RuleCategory configured with preset values
        func createCategory(sortOrder: Int) -> RuleCategory {
            RuleCategory(
                name: name,
                colorHex: colorHex,
                iconName: iconName,
                scope: .global, // User will configure scope after creation
                isEnabled: true,
                sortOrder: sortOrder,
                isDefault: false
            )
        }
    }
}

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string.
    ///
    /// - Parameter hex: Hex color string (e.g., "#3B82F6" or "3B82F6")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    /// Converts the color to a hex string.
    var hexString: String {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
