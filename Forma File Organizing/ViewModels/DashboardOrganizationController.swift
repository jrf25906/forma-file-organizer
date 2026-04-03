import Foundation
import SwiftData
import SwiftUI

/// Isolates individual file organization and tracking for the dashboard.
@MainActor
final class DashboardOrganizationController {

    private let coordinator: FileOrganizationCoordinator
    private let scanViewModel: FileScanViewModel
    private let filterViewModel: FilterViewModel
    private let selectionViewModel: SelectionViewModel
    private let panelManager: PanelStateManager
    private let appReviewEligibility: AppReviewEligibilityProviding
    private let usesTestingFastPath: Bool

    var onShowToast: ((String, Bool) -> Void)?
    var onShowError: ((String) -> Void)?
    var onShouldRequestReview: (() -> Void)?
    var onShowTrustedScopeRecommendation: ((TrustedAutomationScopeRecommendation) -> Void)?

    init(
        coordinator: FileOrganizationCoordinator,
        scanViewModel: FileScanViewModel,
        filterViewModel: FilterViewModel,
        selectionViewModel: SelectionViewModel,
        panelManager: PanelStateManager,
        appReviewEligibility: AppReviewEligibilityProviding = AppReviewEligibilityService(),
        usesTestingFastPath: Bool = DashboardOrganizationController.defaultUsesTestingFastPath()
    ) {
        self.coordinator = coordinator
        self.scanViewModel = scanViewModel
        self.filterViewModel = filterViewModel
        self.selectionViewModel = selectionViewModel
        self.panelManager = panelManager
        self.appReviewEligibility = appReviewEligibility
        self.usesTestingFastPath = usesTestingFastPath
    }

    // MARK: - Organization Status
    
    func isOrganizing(_ file: FileItem) -> Bool {
        coordinator.isOrganizing(file)
    }

    var organizingFilePaths: Set<String> {
        coordinator.organizingFilePaths
    }

    // MARK: - Actions

    func organizeFile(
        _ file: FileItem,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow
    ) {
        guard file.destination != nil else { return }
        selectionViewModel.deselectAll()

        #if DEBUG
        if usesTestingFastPath {
            file.status = .completed
            scanViewModel.removeFile(at: file.path)
            filterViewModel.updateSourceFiles(scanViewModel.allFiles)
            return
        }
        #endif

        Task { @MainActor [weak self] in
            guard let self else { return }

            await self.coordinator.organizeFile(
                file,
                context: context,
                sourceSurface: sourceSurface,
                onSuccess: { [weak self] action in
                    guard let self else { return }
                    self.handleSuccessfulOrganization(
                        file: file,
                        action: action,
                        context: context,
                        sourceSurface: sourceSurface
                    )
                },
                onError: { [weak self] error in
                    guard let self else { return }
                    self.onShowError?(error.localizedDescription)
                    self.onShowToast?(error.localizedDescription, false)
                }
            )

            // Update scan ViewModel
            self.scanViewModel.removeFile(at: file.path)
            self.filterViewModel.updateSourceFiles(self.scanViewModel.allFiles)
        }
    }

    private func handleSuccessfulOrganization(
        file: FileItem,
        action: FileOrganizationCoordinator.FileActionData,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface
    ) {
        if let displayName = file.destination?.displayName {
            panelManager.showCelebrationPanel(message: "Organized to \(displayName)")
        }

        if sourceSurface == .reviewFlow,
           FeatureFlagService.shared.isEnabled(.trustedAutomationScopes),
           let context,
           let snapshot = action.memorySnapshot,
           let recommendation = try? TrustedAutomationScopeService(modelContext: context).recommendedScope(for: snapshot) {
            onShowTrustedScopeRecommendation?(recommendation)
        }

        appReviewEligibility.recordSuccessfulOperation(count: 1)
        if appReviewEligibility.shouldRequestReview() {
            onShouldRequestReview?()
        }
    }

    #if DEBUG
    private static func defaultUsesTestingFastPath() -> Bool {
        CommandLine.arguments.contains("--uitesting") ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    #else
    private static func defaultUsesTestingFastPath() -> Bool { false }
    #endif

    func skipFile(_ file: FileItem) {
        file.status = .skipped
        filterViewModel.applyFilterImmediately()
    }

    func handleOrganizeAnimationComplete(for filePath: String) {
        coordinator.handleOrganizeAnimationComplete(for: filePath)
        withAnimation(.easeInOut(duration: 0.3)) {
            filterViewModel.applyFilterImmediately()
        }
    }
}
