import Foundation
import SwiftUI
import SwiftData

/// Isolates template application and personality quiz logic from the main DashboardViewModel.
@MainActor
final class DashboardTemplateController {
    
    // Dependencies needed for template application
    private let ruleService: RuleService
    private let filterViewModel: FilterViewModel
    
    init(modelContext: ModelContext, filterViewModel: FilterViewModel) {
        self.ruleService = RuleService(modelContext: modelContext)
        self.filterViewModel = filterViewModel
    }

    /// Applies a single, global organization template (Legacy)
    func applyTemplate(_ template: OrganizationTemplate) {
        do {
            try ruleService.createRules(template.generateRules(), source: .quickSheet)
        } catch {
            Log.error("Failed to apply template: \(error.localizedDescription)", category: .general)
        }
    }

    /// Applies specific templates per folder based on user selection during onboarding
    func applyPerFolderTemplates(
        folderSelection: OnboardingFolderSelection,
        templateSelection: FolderTemplateSelection,
        personality: OrganizationPersonality?
    ) {
        // Collect required rules
        var allRulesToCreate: [Rule] = []

        for folder in OnboardingFolder.allCases {
            guard folderSelection.isSelected(folder) else { continue }
            guard let template = templateSelection.template(for: folder) else { continue }

            // Using the base document path as a default
            let templateRules = template.generateRules()
            allRulesToCreate.append(contentsOf: templateRules)
        }

        do {
            try ruleService.createRules(allRulesToCreate, source: .quickSheet)
            Log.info("Successfully applied per-folder templates", category: .general)
        } catch {
            Log.error("Failed to apply per-folder templates: \(error.localizedDescription)", category: .general)
        }
    }

    /// Completes the personality quiz and saves the preferences
    func completePersonalityQuiz(_ personality: OrganizationPersonality) {
        filterViewModel.applyPersonalityPreferences()
    }
    
    /// Completes onboarding, applying default templates
    func completeOnboarding(
        permissionState: DashboardPermissionState,
        modelContext: ModelContext?
    ) {
        permissionState.completeOnboarding()

        // Apply PARA template as default for all 5 folders
        let defaultSelection = OnboardingFolderSelection() // all true
        var templateSelection = FolderTemplateSelection()
        for folder in OnboardingFolder.allCases {
            templateSelection.setTemplate(.para, for: folder)
        }
        defaultSelection.save()
        templateSelection.save()

        // Apply per-folder template rules with PARA for all folders
        if let context = modelContext {
            applyPerFolderTemplates(
                folderSelection: defaultSelection,
                templateSelection: templateSelection,
                personality: nil
            )
        }

        // Refresh folder service so sidebar updates
        BookmarkFolderService.shared.refresh()

        permissionState.showOnboarding = false
    }
}
