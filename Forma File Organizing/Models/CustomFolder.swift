import Foundation
import SwiftData

@Model
final class CustomFolder {
    // MARK: - Validation Errors

    enum ValidationError: Error, LocalizedError {
        case emptyName
        case emptyPath
        case invalidPath

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Folder name cannot be empty"
            case .emptyPath:
                return "Folder path cannot be empty"
            case .invalidPath:
                return "Folder path is invalid"
            }
        }
    }

    // MARK: - Properties

    @Attribute(.unique) private(set) var id: UUID
    private(set) var name: String
    private(set) var path: String
    private(set) var bookmarkData: Data?
    private(set) var creationDate: Date

    /// Controls whether this folder is actively monitored
    /// This property remains publicly mutable for toggling
    var isEnabled: Bool

    // MARK: - Initialization

    init(name: String, path: String, bookmarkData: Data? = nil) throws {
        // Validate and sanitize name
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }

        // Validate path
        let trimmedPath = path.trimmingCharacters(in: .whitespaces)
        guard !trimmedPath.isEmpty else {
            throw ValidationError.emptyPath
        }

        // Additional path validation - ensure it looks like a valid path
        guard trimmedPath.hasPrefix("/") else {
            throw ValidationError.invalidPath
        }

        self.id = UUID()
        self.name = trimmedName
        self.path = trimmedPath
        self.bookmarkData = bookmarkData
        self.creationDate = Date()
        self.isEnabled = true
    }

    // MARK: - Controlled Mutation Methods

    /// Updates the security-scoped bookmark data for this folder
    /// - Parameter data: The new bookmark data, or nil to remove existing bookmark
    func updateBookmarkData(_ data: Data?) {
        self.bookmarkData = data
    }

    /// Updates the folder's display name
    /// - Parameter newName: The new name for the folder
    /// - Throws: ValidationError.emptyName if the new name is empty after trimming
    func updateName(_ newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyName
        }
        self.name = trimmed
    }

    /// Updates the folder's path
    /// - Parameter newPath: The new file system path for the folder
    /// - Throws: ValidationError if the new path is invalid
    func updatePath(_ newPath: String) throws {
        let trimmed = newPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyPath
        }
        guard trimmed.hasPrefix("/") else {
            throw ValidationError.invalidPath
        }
        self.path = trimmed
    }
}
