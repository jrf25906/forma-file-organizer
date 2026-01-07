import Foundation
import SwiftUI

/// Presentation logic for FileItem display.
///
/// This service extracts UI-related computed properties from the FileItem model,
/// following the Presenter Pattern to keep models focused on data persistence.
///
/// ## Why This Exists
/// - **Separation of Concerns**: Models should be pure data containers
/// - **Testability**: Presentation logic is easier to unit test in isolation
/// - **SwiftData Performance**: Computed properties on @Model can trigger unnecessary updates
/// - **Reusability**: Same logic can be used for non-persisted FileMetadata
///
/// ## Usage
/// ```swift
/// // Instead of:
/// let icon = file.iconName
/// let color = file.ageDateColor
///
/// // Use:
/// let icon = FileItemPresenter.icon(for: file)
/// let color = FileItemPresenter.ageColor(for: file)
/// ```
enum FileItemPresenter {
    // MARK: - Age Thresholds

    /// 24 hours in seconds
    private static let freshThreshold: TimeInterval = 86_400

    /// 7 days in seconds
    private static let recentThreshold: TimeInterval = 604_800

    /// 30 days in seconds
    private static let oldThreshold: TimeInterval = 2_592_000

    // MARK: - Age Category

    /// Categorizes a file by its age relative to creation date.
    ///
    /// - Parameter file: The file to categorize
    /// - Returns: The age category (.fresh, .recent, .old, or .veryOld)
    static func ageCategory(for file: FileItem) -> FileItem.AgeCategory {
        ageCategory(creationDate: file.creationDate)
    }

    /// Categorizes a file by its age using just the creation date.
    /// Useful for non-persisted FileMetadata.
    ///
    /// - Parameter creationDate: The file's creation date
    /// - Returns: The age category
    static func ageCategory(creationDate: Date) -> FileItem.AgeCategory {
        let age = Date().timeIntervalSince(creationDate)
        if age < freshThreshold { return .fresh }
        if age < recentThreshold { return .recent }
        if age < oldThreshold { return .old }
        return .veryOld
    }

    // MARK: - Age Color

    /// Returns the appropriate color for displaying a file's age.
    ///
    /// Fresh and recent files use a neutral color, while older files
    /// use a warning orange to draw attention.
    ///
    /// - Parameter file: The file to get color for
    /// - Returns: The SwiftUI Color for the age display
    static func ageColor(for file: FileItem) -> Color {
        ageColor(creationDate: file.creationDate)
    }

    /// Returns the appropriate color for a file's age using just the creation date.
    ///
    /// - Parameter creationDate: The file's creation date
    /// - Returns: The SwiftUI Color for the age display
    static func ageColor(creationDate: Date) -> Color {
        let category = ageCategory(creationDate: creationDate)
        switch category {
        case .fresh, .recent:
            return .formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
        case .old, .veryOld:
            return .formaWarmOrange.opacity(Color.FormaOpacity.high)
        }
    }

    // MARK: - Size Color

    /// Returns the appropriate color for displaying a file's size.
    ///
    /// Small files use neutral colors, while larger files use
    /// increasingly prominent warning colors.
    ///
    /// - Parameter file: The file to get color for
    /// - Returns: The SwiftUI Color for the size display
    static func sizeColor(for file: FileItem) -> Color {
        sizeColor(sizeInBytes: file.sizeInBytes)
    }

    /// Returns the appropriate color for a file size.
    ///
    /// - Parameter sizeInBytes: The file size in bytes
    /// - Returns: The SwiftUI Color for the size display
    static func sizeColor(sizeInBytes: Int64) -> Color {
        let mb = Double(sizeInBytes) / 1_048_576

        if mb < 1 {
            return .formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
        }
        if mb < 10 {
            return .formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light)
        }
        if mb < 100 {
            return .formaWarmOrange.opacity(Color.FormaOpacity.prominent)
        }
        return .formaWarmOrange
    }

    // MARK: - Icon

    /// Returns the appropriate SF Symbol icon name for a file type.
    ///
    /// - Parameter file: The file to get icon for
    /// - Returns: The SF Symbol name
    static func icon(for file: FileItem) -> String {
        icon(forExtension: file.fileExtension)
    }

    /// Returns the appropriate SF Symbol icon name for a file extension.
    ///
    /// - Parameter extension: The file extension (without dot)
    /// - Returns: The SF Symbol name
    static func icon(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "pdf":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "heic", "gif", "webp", "tiff", "bmp":
            return "photo.fill"
        case "mov", "mp4", "avi", "mkv", "wmv", "flv", "m4v":
            return "film.fill"
        case "zip", "dmg", "pkg", "tar", "gz", "rar", "7z":
            return "archivebox.fill"
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "wma":
            return "music.note"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.stack.fill"
        case "txt", "rtf", "md":
            return "doc.plaintext.fill"
        case "html", "css", "js", "ts", "swift", "py", "rb", "go", "rs":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        default:
            return "doc.fill"
        }
    }

    // MARK: - Category

    /// Returns the file type category for a file.
    ///
    /// - Parameter file: The file to categorize
    /// - Returns: The FileTypeCategory
    static func category(for file: FileItem) -> FileTypeCategory {
        FileTypeCategory.category(for: file.fileExtension)
    }

    /// Returns the file type category for an extension.
    ///
    /// - Parameter extension: The file extension
    /// - Returns: The FileTypeCategory
    static func category(forExtension ext: String) -> FileTypeCategory {
        FileTypeCategory.category(for: ext)
    }
}

