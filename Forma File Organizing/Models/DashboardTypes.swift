import Foundation

/// Represents different folder locations that can be scanned
enum FolderLocation: Equatable, Hashable {
    case home
    case desktop
    case downloads
    case documents
    case pictures
    case music
    case custom(CustomFolder)

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .desktop: return "Desktop"
        case .downloads: return "Downloads"
        case .documents: return "Documents"
        case .pictures: return "Pictures"
        case .music: return "Music"
        case .custom(let folder): return folder.name
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
        case .custom: return "folder.fill"
        }
    }

    static func == (lhs: FolderLocation, rhs: FolderLocation) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.desktop, .desktop), (.downloads, .downloads), (.documents, .documents), (.pictures, .pictures), (.music, .music):
            return true
        case (.custom(let lFolder), .custom(let rFolder)):
            return lFolder.id == rFolder.id
        default:
            return false
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
