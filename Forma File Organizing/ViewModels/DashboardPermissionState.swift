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
    }

    enum PermissionResult {
        case granted
        case cancelled
        case error(String)
    }

    func checkPermissions(
        using fileSystemService: FileSystemServiceProtocol,
        defaults: UserDefaults = .standard,
        isUITesting: Bool = CommandLine.arguments.contains("--uitesting")
    ) {
        #if DEBUG
        if isUITesting {
            hasDesktopAccess = true
            hasDownloadsAccess = true
            hasDocumentsAccess = true
            hasPicturesAccess = true
            hasMusicAccess = true
            showOnboarding = false
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
}
