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
    @available(*, deprecated, message: "Smart Rules now opens via right panel action")
    case rules  // View and manage all saved rules
    @available(*, deprecated, message: "Analytics now opens via right panel action")
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
    @Published var ruleDraftSession: RuleDraftSession? {
        didSet {
            syncLegacyRuleEditorState(with: ruleDraftSession)
        }
    }
    
    var selectedCategory: FileTypeCategory? {
        if case .category(let cat) = selection {
            return cat
        }
        return nil
    }

    var hasActiveRuleDraft: Bool {
        ruleDraftSession != nil
    }
    
    // Helpers for view updates
    func navigate(to route: Route) {
        path.append(route)
    }
    
    func select(_ item: NavigationSelection) {
        selection = item
        searchText = ""
    }

    func beginRuleDraft(
        editingRule: Rule? = nil,
        fileContext: FileItem? = nil,
        suggestedNaturalLanguageText: String? = nil,
        presentation: RuleDraftPresentation,
        returnTarget: RuleDraftReturnTarget = .none
    ) {
        let source: RuleDraftSource
        let formState: RuleFormState

        if let editingRule {
            source = .editExisting
            formState = RuleFormState(from: editingRule)
        } else if let fileContext {
            source = .newFromFile
            formState = RuleFormState(from: fileContext)
        } else if let suggestedNaturalLanguageText, !suggestedNaturalLanguageText.isEmpty {
            source = .suggestedPrompt
            formState = RuleFormState()
        } else {
            source = .genericNew
            formState = RuleFormState()
        }

        ruleDraftSession = RuleDraftSession(
            formState: formState,
            editingRule: editingRule,
            fileContext: fileContext,
            suggestedNaturalLanguageText: suggestedNaturalLanguageText,
            presentation: presentation,
            returnTarget: returnTarget,
            source: source
        )
    }

    func openRuleEditor(
        editingRule: Rule? = nil,
        fileContext: FileItem? = nil,
        suggestedNaturalLanguageText: String? = nil,
        returnTarget: RuleDraftReturnTarget = .none
    ) {
        beginRuleDraft(
            editingRule: editingRule,
            fileContext: fileContext,
            suggestedNaturalLanguageText: suggestedNaturalLanguageText,
            presentation: .modal,
            returnTarget: returnTarget
        )
    }

    func openRuleBuilderPanel(
        editingRule: Rule? = nil,
        fileContext: FileItem? = nil,
        suggestedNaturalLanguageText: String? = nil,
        returnTarget: RuleDraftReturnTarget = .defaultPanel
    ) {
        beginRuleDraft(
            editingRule: editingRule,
            fileContext: fileContext,
            suggestedNaturalLanguageText: suggestedNaturalLanguageText,
            presentation: .panel,
            returnTarget: returnTarget
        )
    }

    func presentRuleDraftModal() {
        guard var session = ruleDraftSession else { return }
        session.presentation = .modal
        ruleDraftSession = session
    }

    func presentRuleDraftPanel() {
        guard var session = ruleDraftSession else { return }
        session.presentation = .panel
        ruleDraftSession = session
    }

    func clearRuleDraft() {
        ruleDraftSession = nil
    }

    func discardRuleDraft() {
        clearRuleDraft()
    }

    func updateRuleDraftFormState(_ formState: RuleFormState) {
        guard var session = ruleDraftSession else { return }
        session.formState = formState
        ruleDraftSession = session
    }

    private func syncLegacyRuleEditorState(with session: RuleDraftSession?) {
        editingRule = session?.editingRule
        ruleEditorFileContext = session?.fileContext
        ruleEditorSuggestedText = session?.suggestedNaturalLanguageText
        isShowingRuleEditor = session?.presentation == .modal
    }
}
