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
    private let workflowExecution: WorkflowExecutionClient

    var onShowToast: ((String, Bool) -> Void)?
    var onShowError: ((String) -> Void)?
    var onShouldRequestReview: (() -> Void)?
    var onShowTrustedScopeRecommendation: ((TrustedAutomationScopeRecommendation) -> Void)?
    var onDidOrganizeFile: ((String) -> Void)?

    init(
        coordinator: FileOrganizationCoordinator,
        scanViewModel: FileScanViewModel,
        filterViewModel: FilterViewModel,
        selectionViewModel: SelectionViewModel,
        panelManager: PanelStateManager,
        appReviewEligibility: AppReviewEligibilityProviding = AppReviewEligibilityService(),
        usesTestingFastPath: Bool = DashboardOrganizationController.defaultUsesTestingFastPath(),
        workflowExecution: WorkflowExecutionClient = .live
    ) {
        self.coordinator = coordinator
        self.scanViewModel = scanViewModel
        self.filterViewModel = filterViewModel
        self.selectionViewModel = selectionViewModel
        self.panelManager = panelManager
        self.appReviewEligibility = appReviewEligibility
        self.usesTestingFastPath = usesTestingFastPath
        self.workflowExecution = workflowExecution
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
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow,
        workflowTemplateID: String? = nil
    ) {
        guard file.destination != nil else { return }
        if FeatureFlagService.shared.isEnabled(.workflowEngineV2) {
            organizeFileWithWorkflowEngine(
                file,
                context: context,
                sourceSurface: sourceSurface,
                workflowTemplateID: workflowTemplateID
            )
            return
        }

        selectionViewModel.deselectAll()

        #if DEBUG
        if usesTestingFastPath {
            file.status = .completed
            scanViewModel.removeFile(at: file.path)
            filterViewModel.updateSourceFiles(scanViewModel.allFiles)
            onDidOrganizeFile?(file.path)
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
            self.onDidOrganizeFile?(file.path)
        }
    }

    private func organizeFileWithWorkflowEngine(
        _ file: FileItem,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface,
        workflowTemplateID: String?
    ) {
        guard let template = WorkflowTemplateCatalog.template(for: workflowTemplateID) else {
            let message = "Choose a built-in workflow template before organizing with Workflow Engine v2."
            onShowError?(message)
            onShowToast?(message, false)
            return
        }

        guard let context else {
            let message = "Workflow Engine v2 needs a model context before it can run."
            onShowError?(message)
            onShowToast?(message, false)
            return
        }

        selectionViewModel.deselectAll()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let memorySnapshot = self.makeWorkflowMemorySnapshot(for: file)
            let executionRequest = WorkflowExecutionRequest(
                templateID: template.id,
                invocationContext: .inspector
            )

            do {
                let plan = self.workflowExecution.plan(executionRequest, [file])
                _ = try await self.workflowExecution.run(
                    executionRequest,
                    plan,
                    [file],
                    context
                )
                file.status = .completed
                self.handleSuccessfulOrganization(
                    file: file,
                    action: FileOrganizationCoordinator.FileActionData(
                        filePath: file.path,
                        originalPath: file.path,
                        originalStatus: .ready,
                        originalSuggestedDestination: file.originalSuggestedDestination?.displayName,
                        destinationPath: file.path,
                        memorySnapshot: memorySnapshot
                    ),
                    context: context,
                    sourceSurface: sourceSurface,
                    celebrationStyle: .workflowExecution,
                    shouldRecordPersonalMemoryDecision: true
                )
                self.scanViewModel.removeFile(at: file.path)
                self.filterViewModel.updateSourceFiles(self.scanViewModel.allFiles)
                self.onDidOrganizeFile?(file.path)
            } catch {
                self.onShowError?(error.localizedDescription)
                self.onShowToast?(error.localizedDescription, false)
            }
        }
    }

    private func handleSuccessfulOrganization(
        file: FileItem,
        action: FileOrganizationCoordinator.FileActionData,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface,
        celebrationStyle: PanelStateManager.CelebrationStyle = .batchUndo,
        shouldRecordPersonalMemoryDecision: Bool = false
    ) {
        if let displayName = file.destination?.displayName {
            panelManager.showCelebrationPanel(
                message: "Organized to \(displayName)",
                style: celebrationStyle
            )
        }

        if shouldRecordPersonalMemoryDecision,
           let context,
           let snapshot = action.memorySnapshot {
            recordPersonalMemoryDecision(
                snapshot: snapshot,
                sourceSurface: sourceSurface,
                context: context
            )
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

    private func makeWorkflowMemorySnapshot(for file: FileItem) -> OrganizationMemorySnapshot? {
        guard FeatureFlagService.shared.isEnabled(.patternLearning),
              let chosenDestination = file.destination else {
            return nil
        }

        return OrganizationMemorySnapshot(
            fileName: file.name,
            fileExtension: file.fileExtension,
            fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
            sourceLocation: file.location,
            scanRootPath: file.scanRootPath,
            relativeParentPath: file.relativeParentPath,
            suggestionSource: explicitSuggestionSource(for: file),
            suggestedDestination: file.originalSuggestedDestination,
            chosenDestination: chosenDestination,
            confidenceScore: file.confidenceScore,
            matchedRuleID: file.matchedRuleID
        )
    }

    private func explicitSuggestionSource(for file: FileItem) -> SuggestionSource? {
        if file.matchedRuleID != nil {
            return .rule
        }

        guard let raw = file.suggestionSourceRaw else {
            return nil
        }

        return SuggestionSource(rawValue: raw)
    }

    private func recordPersonalMemoryDecision(
        snapshot: OrganizationMemorySnapshot,
        sourceSurface: PersonalMemorySourceSurface,
        context: ModelContext
    ) {
        do {
            _ = try PersonalMemoryService(modelContext: context).recordDecision(
                fileName: snapshot.fileName,
                fileExtension: snapshot.fileExtension,
                fileTypeCategory: snapshot.fileTypeCategory,
                sourceLocation: snapshot.sourceLocation,
                scanRootPath: snapshot.scanRootPath,
                relativeParentPath: snapshot.relativeParentPath,
                sourceSurface: sourceSurface,
                suggestionSource: snapshot.suggestionSource,
                suggestedDestination: snapshot.suggestedDestination,
                chosenDestination: snapshot.chosenDestination,
                confidenceScore: snapshot.confidenceScore,
                matchedRuleID: snapshot.matchedRuleID
            )
        } catch {
            Log.error("Failed to record personal memory decision: \(error.localizedDescription)", category: .analytics)
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

    func skipFile(_ file: FileItem, context: ModelContext?) {
        let didSkip = coordinator.skipFile(file, context: context)
        guard didSkip else { return }
        filterViewModel.applyFilterImmediately()
    }

    func handleOrganizeAnimationComplete(for filePath: String) {
        coordinator.handleOrganizeAnimationComplete(for: filePath)
        withAnimation(.easeInOut(duration: 0.3)) {
            filterViewModel.applyFilterImmediately()
        }
    }
}
