import Foundation

/// Represents different folder locations that can be scanned.
///
/// These correspond to the standard macOS user folders that Forma can organize.
/// Each case maps to a `BookmarkFolder.FolderType` for bookmark management.
enum FolderLocation: Equatable, Hashable, CaseIterable {
    case home
    case desktop
    case downloads
    case documents
    case pictures
    case music

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .desktop: return "Desktop"
        case .downloads: return "Downloads"
        case .documents: return "Documents"
        case .pictures: return "Pictures"
        case .music: return "Music"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .desktop: return "desktopcomputer"
        case .downloads: return "arrow.down.circle"
        case .documents: return "doc.fill"
        case .pictures: return "photo.fill"
        case .music: return "music.note"
        }
    }

    /// Maps to the corresponding BookmarkFolder.FolderType (nil for .home)
    var bookmarkFolderType: BookmarkFolder.FolderType? {
        switch self {
        case .home: return nil
        case .desktop: return .desktop
        case .downloads: return .downloads
        case .documents: return .documents
        case .pictures: return .pictures
        case .music: return .music
        }
    }

    /// Creates a FolderLocation from a BookmarkFolder.FolderType
    static func from(bookmarkFolderType: BookmarkFolder.FolderType) -> FolderLocation {
        switch bookmarkFolderType {
        case .desktop: return .desktop
        case .downloads: return .downloads
        case .documents: return .documents
        case .pictures: return .pictures
        case .music: return .music
        }
    }
}

/// Secondary filter options for file display
enum SecondaryFilter: Hashable, Sendable {
    case none
    case recent
    case largeFiles
    case flagged
}

/// Filter mode for review view
enum ReviewFilterMode: Hashable, Sendable {
    case needsReview
    case all
}
