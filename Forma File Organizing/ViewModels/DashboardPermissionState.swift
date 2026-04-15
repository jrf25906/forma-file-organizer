import Foundation
import Combine

/// Isolated permission and onboarding state for the dashboard.
@MainActor
final class DashboardPermissionState: ObservableObject {

    @Published var hasDesktopAccess: Bool = false
    @Published var hasDownloadsAccess: Bool = false
    @Published var hasDocumentsAccess: Bool = false
    @Published var hasPicturesAccess: Bool = false
    @Published var hasMusicAccess: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var permissionCancelledFolders: Set<FolderType> = []

    enum FolderType: Hashable {
        case desktop, downloads, documents, pictures, music

        var displayName: String {
            switch self {
            case .desktop: return "Desktop"
            case .downloads: return "Downloads"
            case .documents: return "Documents"
            case .pictures: return "Pictures"
            case .music: return "Music"
            }
        }

        var uiTestConfigurationKey: String {
            switch self {
            case .desktop: return "desktop"
            case .downloads: return "downloads"
            case .documents: return "documents"
            case .pictures: return "pictures"
            case .music: return "music"
            }
        }
    }

    enum PermissionResult {
        case granted
        case cancelled
        case error(String)
    }

    func checkPermissions(
        using fileSystemService: FileSystemServiceProtocol,
        defaults: UserDefaults = .standard,
        isUITesting: Bool = UITestFolderAccessConfiguration.isEnabled
    ) {
        #if DEBUG
        if isUITesting {
            applyUITestOverrides(defaults: defaults)
            return
        }
        #endif

        hasDesktopAccess = fileSystemService.hasDesktopAccess()
        hasDownloadsAccess = fileSystemService.hasDownloadsAccess()
        hasDocumentsAccess = fileSystemService.hasDocumentsAccess()
        hasPicturesAccess = fileSystemService.hasPicturesAccess()
        hasMusicAccess = fileSystemService.hasMusicAccess()

        showOnboarding = !defaults.bool(forKey: "hasCompletedOnboarding")
    }

    func requestAccess(
        for folderType: FolderType,
        using fileSystemService: FileSystemServiceProtocol
    ) async -> PermissionResult {
        permissionCancelledFolders.remove(folderType)

        do {
            let granted = try await {
                switch folderType {
                case .desktop: return try await fileSystemService.requestDesktopAccess()
                case .downloads: return try await fileSystemService.requestDownloadsAccess()
                case .documents: return try await fileSystemService.requestDocumentsAccess()
                case .pictures: return try await fileSystemService.requestPicturesAccess()
                case .music: return try await fileSystemService.requestMusicAccess()
                }
            }()

            if granted {
                guard hasVerifiedAccess(for: folderType, using: fileSystemService) else {
                    markAccessDenied(for: folderType)
                    return .error("Forma could not verify access to \(folderType.displayName). Please try selecting it again.")
                }

                markAccessGranted(for: folderType)
                return .granted
            }

            permissionCancelledFolders.insert(folderType)
            return .cancelled
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func completeOnboarding(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: "hasCompletedOnboarding")
        showOnboarding = false
    }

    private func markAccessGranted(for folderType: FolderType) {
        switch folderType {
        case .desktop: hasDesktopAccess = true
        case .downloads: hasDownloadsAccess = true
        case .documents: hasDocumentsAccess = true
        case .pictures: hasPicturesAccess = true
        case .music: hasMusicAccess = true
        }
    }

    private func markAccessDenied(for folderType: FolderType) {
        switch folderType {
        case .desktop: hasDesktopAccess = false
        case .downloads: hasDownloadsAccess = false
        case .documents: hasDocumentsAccess = false
        case .pictures: hasPicturesAccess = false
        case .music: hasMusicAccess = false
        }
    }

    private func hasVerifiedAccess(
        for folderType: FolderType,
        using fileSystemService: FileSystemServiceProtocol
    ) -> Bool {
        switch folderType {
        case .desktop:
            fileSystemService.hasDesktopAccess()
        case .downloads:
            fileSystemService.hasDownloadsAccess()
        case .documents:
            fileSystemService.hasDocumentsAccess()
        case .pictures:
            fileSystemService.hasPicturesAccess()
        case .music:
            fileSystemService.hasMusicAccess()
        }
    }

    private func applyUITestOverrides(defaults: UserDefaults) {
        let environment = ProcessInfo.processInfo.environment
        let showOnboardingOverride = environment[UITestFolderAccessConfiguration.showOnboardingEnvironmentKey]
        let accessibleFolders = UITestFolderAccessConfiguration.accessibleFolderNames(environment: environment)

        hasDesktopAccess = accessibleFolders.contains(FolderType.desktop.uiTestConfigurationKey)
        hasDownloadsAccess = accessibleFolders.contains(FolderType.downloads.uiTestConfigurationKey)
        hasDocumentsAccess = accessibleFolders.contains(FolderType.documents.uiTestConfigurationKey)
        hasPicturesAccess = accessibleFolders.contains(FolderType.pictures.uiTestConfigurationKey)
        hasMusicAccess = accessibleFolders.contains(FolderType.music.uiTestConfigurationKey)

        if let showOnboardingOverride {
            showOnboarding = showOnboardingOverride == "1"
        } else {
            showOnboarding = !defaults.bool(forKey: "hasCompletedOnboarding")
        }
    }
}
