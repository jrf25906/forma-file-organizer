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

    var onShowToast: ((String, Bool) -> Void)?
    var onShowError: ((String) -> Void)?

    init(
        coordinator: FileOrganizationCoordinator,
        scanViewModel: FileScanViewModel,
        filterViewModel: FilterViewModel,
        selectionViewModel: SelectionViewModel,
        panelManager: PanelStateManager
    ) {
        self.coordinator = coordinator
        self.scanViewModel = scanViewModel
        self.filterViewModel = filterViewModel
        self.selectionViewModel = selectionViewModel
        self.panelManager = panelManager
    }

    // MARK: - Organization Status
    
    func isOrganizing(_ file: FileItem) -> Bool {
        coordinator.isOrganizing(file)
    }

    var organizingFilePaths: Set<String> {
        coordinator.organizingFilePaths
    }

    // MARK: - Actions

    func organizeFile(_ file: FileItem, context: ModelContext?) {
        guard file.destination != nil else { return }
        selectionViewModel.deselectAll()

        #if DEBUG
        let isTesting = CommandLine.arguments.contains("--uitesting") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTesting {
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
                onSuccess: { [weak self] _ in
                    guard let self else { return }
                    if let displayName = file.destination?.displayName {
                        self.panelManager.showCelebrationPanel(message: "Organized to \(displayName)")
                    }
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
