import SwiftUI
import SwiftData
import Combine

enum Route: Hashable {
    case category(FileTypeCategory)
    case allFiles
    case fileDetail(PersistentIdentifier) // Using PersistentIdentifier for SwiftData models
}

enum FileFilterChip: Hashable {
    case largeFiles
    case recent
    case flagged
    case fileType(FileTypeCategory)
}

enum NavigationSelection: Hashable {
    case home
    case desktop
    case downloads
    case documents
    case pictures
    case music
    case nestedFolder(base: BookmarkFolder.FolderType, relativePath: String, includeSubfolders: Bool)
    case rules  // View and manage all saved rules
    case analytics
    case category(FileTypeCategory)

    /// Maps a BookmarkFolder.FolderType to the corresponding NavigationSelection
    static func from(folderType: BookmarkFolder.FolderType) -> NavigationSelection {
        switch folderType {
        case .desktop: return .desktop
        case .downloads: return .downloads
        case .documents: return .documents
        case .pictures: return .pictures
        case .music: return .music
        }
    }

    /// Returns the BookmarkFolder.FolderType if this selection is a folder
    var folderType: BookmarkFolder.FolderType? {
        switch self {
        case .desktop: return .desktop
        case .downloads: return .downloads
        case .documents: return .documents
        case .pictures: return .pictures
        case .music: return .music
        case .nestedFolder(let base, _, _): return base
        default: return nil
        }
    }

    var nestedFolderScope: (relativePath: String, includeSubfolders: Bool)? {
        switch self {
        case .nestedFolder(_, let relativePath, let includeSubfolders):
            return (relativePath, includeSubfolders)
        default:
            return nil
        }
    }
}

final class NavigationViewModel: ObservableObject {
    @Published var selection: NavigationSelection = .home
    @Published var searchText: String = ""
    @Published var activeChips: Set<FileFilterChip> = []
    @Published var isShowingRuleEditor: Bool = false
    @Published var path: [Route] = []
    @Published var ruleEditorFileContext: FileItem?
    @Published var editingRule: Rule?
    @Published var ruleEditorSuggestedText: String?
    
    var selectedCategory: FileTypeCategory? {
        if case .category(let cat) = selection {
            return cat
        }
        return nil
    }
    
    // Helpers for view updates
    func navigate(to route: Route) {
        path.append(route)
    }
    
    func select(_ item: NavigationSelection) {
        selection = item
        searchText = ""
    }
}
