import Foundation

/// Represents the high-level origin/location of a file within the user's space.
///
/// This is intentionally simpler than `FolderLocation` and does not capture
/// specific `CustomFolder` instances so it can be safely used in value types
/// and SwiftData models.
enum FileLocationKind: String, Codable, Sendable {
    case home
    case desktop
    case downloads
    case documents
    case pictures
    case music
    case custom
    case unknown

    /// Human-readable display name for UI
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .desktop: return "Desktop"
        case .downloads: return "Downloads"
        case .documents: return "Documents"
        case .pictures: return "Pictures"
        case .music: return "Music"
        case .custom: return "Custom Folder"
        case .unknown: return "Unknown"
        }
    }
}
