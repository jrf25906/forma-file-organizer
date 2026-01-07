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
    case rules  // View and manage all saved rules
    case analytics
    case custom(CustomFolder)
    case category(FileTypeCategory)
}

final class NavigationViewModel: ObservableObject {
    @Published var selection: NavigationSelection = .home
    @Published var searchText: String = ""
    @Published var activeChips: Set<FileFilterChip> = []
    @Published var isShowingRuleEditor: Bool = false
    @Published var path: [Route] = []
    @Published var ruleEditorFileContext: FileItem?
    @Published var editingRule: Rule?
    
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
