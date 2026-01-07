import SwiftUI
import SwiftData

// MARK: - Onboarding State

/// Centralized state management for the onboarding flow.
/// Shared between all step components to maintain consistency.
@Observable
class OnboardingState {
    var currentStep: OnboardingStep = .welcome
    var folderSelection = OnboardingFolderSelection()
    var personality: OrganizationPersonality?
    var templateSelection = FolderTemplateSelection()
    var isRequestingPermissions = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case folders = 1
        case quiz = 2
        case folderTemplates = 3
        case preview = 4

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .folders: return "Folders"
            case .quiz: return "Style"
            case .folderTemplates: return "Systems"
            case .preview: return "Preview"
            }
        }
    }

    var selectedFolders: [OnboardingFolder] {
        var folders: [OnboardingFolder] = []
        if folderSelection.desktop { folders.append(.desktop) }
        if folderSelection.downloads { folders.append(.downloads) }
        if folderSelection.documents { folders.append(.documents) }
        if folderSelection.pictures { folders.append(.pictures) }
        if folderSelection.music { folders.append(.music) }
        return folders
    }

    // MARK: - Navigation

    func advance(to step: OnboardingStep) {
        withAnimation { currentStep = step }
    }

    func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation { currentStep = previousStep }
    }
}

// MARK: - Folder Selection Model

/// Tracks which folders the user has selected for Forma to organize.
/// This drives both permission requests AND sidebar visibility.
struct OnboardingFolderSelection: Codable, Equatable {
    var desktop: Bool = false
    var downloads: Bool = false
    var documents: Bool = false
    var pictures: Bool = false
    var music: Bool = false

    var selectedCount: Int {
        [desktop, downloads, documents, pictures, music].filter { $0 }.count
    }

    var hasAnySelected: Bool {
        selectedCount > 0
    }

    /// Storage key for persisting folder selection
    static let storageKey = "onboardingFolderSelection"

    func save() {
        do {
            let encoded = try JSONEncoder().encode(self)
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        } catch {
            Log.warning("OnboardingFolderSelection: Failed to encode folder selection - \(error.localizedDescription)", category: .general)
        }
    }

    static func load() -> OnboardingFolderSelection {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return OnboardingFolderSelection()
        }

        do {
            let selection = try JSONDecoder().decode(OnboardingFolderSelection.self, from: data)
            return selection
        } catch {
            Log.warning("OnboardingFolderSelection: Failed to decode folder selection - \(error.localizedDescription)", category: .general)
            return OnboardingFolderSelection()
        }
    }
}

// MARK: - Folder Type Definition

enum OnboardingFolder: CaseIterable {
    case desktop, downloads, documents, pictures, music

    var title: String {
        switch self {
        case .desktop: return "Desktop"
        case .downloads: return "Downloads"
        case .documents: return "Documents"
        case .pictures: return "Pictures"
        case .music: return "Music"
        }
    }

    var color: Color {
        switch self {
        case .desktop: return .formaSteelBlue
        case .downloads: return .formaSage
        case .documents: return .formaMutedBlue
        case .pictures: return .formaWarmOrange
        case .music: return .formaSoftGreen
        }
    }

    /// Hex color string for category creation
    var colorHex: String {
        switch self {
        case .desktop: return "#5B7FA3"   // Steel Blue
        case .downloads: return "#8AA789" // Sage
        case .documents: return "#6B8CAD" // Muted Blue
        case .pictures: return "#D4915C"  // Warm Orange
        case .music: return "#7FB18A"     // Soft Green
        }
    }

    /// SF Symbol icon name for category creation
    var iconName: String {
        switch self {
        case .desktop: return "desktopcomputer"
        case .downloads: return "arrow.down.circle.fill"
        case .documents: return "doc.fill"
        case .pictures: return "photo.fill"
        case .music: return "music.note"
        }
    }

    /// Icons that "rise" on hover to show folder contents
    var contentIcons: [String] {
        switch self {
        case .desktop: return ["doc.text.fill", "photo.fill", "folder.fill"]
        case .downloads: return ["arrow.down.circle.fill", "doc.zipper", "app.gift.fill"]
        case .documents: return ["doc.fill", "doc.text.fill", "tablecells.fill"]
        case .pictures: return ["photo.fill", "camera.fill", "photo.stack.fill"]
        case .music: return ["opticaldisc.fill", "music.note", "waveform"]
        }
    }

    /// Bookmark key used to store security-scoped bookmark in Keychain
    var bookmarkKey: String {
        switch self {
        case .desktop: return FormaConfig.Security.desktopBookmarkKey
        case .downloads: return FormaConfig.Security.downloadsBookmarkKey
        case .documents: return FormaConfig.Security.documentsBookmarkKey
        case .pictures: return FormaConfig.Security.picturesBookmarkKey
        case .music: return FormaConfig.Security.musicBookmarkKey
        }
    }

    /// Standard macOS folder path
    var folderPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .desktop: return "\(home)/Desktop"
        case .downloads: return "\(home)/Downloads"
        case .documents: return "\(home)/Documents"
        case .pictures: return "\(home)/Pictures"
        case .music: return "\(home)/Music"
        }
    }
}
