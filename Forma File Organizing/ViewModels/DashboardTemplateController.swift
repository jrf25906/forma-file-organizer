import Foundation
import SwiftUI
import SwiftData

/// Isolates template application and personality quiz logic from the main DashboardViewModel.
@MainActor
final class DashboardTemplateController {
    
    // Dependencies needed for template application
    private let modelContext: ModelContext
    private let ruleService: RuleService
    private let categoryService: CategoryService
    private let filterViewModel: FilterViewModel
    
    init(modelContext: ModelContext, filterViewModel: FilterViewModel) {
        self.modelContext = modelContext
        self.ruleService = RuleService(modelContext: modelContext)
        self.categoryService = CategoryService(modelContext: modelContext)
        self.filterViewModel = filterViewModel
    }

    /// Applies a single, global organization template (Legacy)
    func applyTemplate(_ template: OrganizationTemplate) {
        do {
            try ruleService.createRules(
                template.generateRules(),
                source: .template(name: template.displayName)
            )
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
        _ = personality

        // Collect required rules
        var allRulesToCreate: [Rule] = []
        let existingRules = (try? ruleService.fetchRules()) ?? []
        var existingRuleKeys = Set(existingRules.map(ruleSignature))

        for folder in OnboardingFolder.allCases {
            guard folderSelection.isSelected(folder) else { continue }
            guard let template = templateSelection.template(for: folder) else { continue }
            guard let category = try? upsertCategory(for: folder) else { continue }

            let templateRules = template.generateRules(baseDocumentsPath: folder.title)
            for rule in templateRules {
                rule.category = category

                let signature = ruleSignature(rule)
                guard !existingRuleKeys.contains(signature) else { continue }

                existingRuleKeys.insert(signature)
                allRulesToCreate.append(rule)
            }
        }

        do {
            guard !allRulesToCreate.isEmpty else {
                Log.info("Per-folder templates produced no new rules to apply", category: .general)
                return
            }

            try ruleService.createRules(
                allRulesToCreate,
                source: .template(name: "Per-folder templates")
            )
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
        modelContext _: ModelContext?
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
        applyPerFolderTemplates(
            folderSelection: defaultSelection,
            templateSelection: templateSelection,
            personality: nil
        )

        // Refresh folder service so sidebar updates
        BookmarkFolderService.shared.refresh()

        permissionState.showOnboarding = false
    }

    private func upsertCategory(for folder: OnboardingFolder) throws -> RuleCategory {
        let scope = categoryScope(for: folder)
        let existingCategories = try categoryService.fetchCategories()

        if let existing = existingCategories.first(where: { $0.name == folder.title }) {
            if existing.scope != scope ||
                existing.colorHex != folder.colorHex ||
                existing.iconName != folder.iconName ||
                !existing.isEnabled {
                try categoryService.updateCategory(
                    existing,
                    colorHex: folder.colorHex,
                    iconName: folder.iconName,
                    scope: scope,
                    isEnabled: true
                )
            }
            return existing
        }

        return try categoryService.createCategory(
            name: folder.title,
            colorHex: folder.colorHex,
            iconName: folder.iconName,
            scope: scope
        )
    }

    private func categoryScope(for folder: OnboardingFolder) -> CategoryScope {
        guard let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: folder.bookmarkKey) else {
            Log.warning("DashboardTemplateController: Missing bookmark for \(folder.title); rules will stay scoped but inactive until access is granted.", category: .bookmark)
            return .folders([])
        }

        let scopedFolder = CategoryScope.ScopedFolder(
            bookmark: bookmarkData,
            displayName: folder.title
        )
        return .folders([scopedFolder])
    }

    private func ruleSignature(_ rule: Rule) -> String {
        [
            rule.category?.name ?? "General",
            rule.name,
            rule.actionType.rawValue,
            rule.conditionsSummary,
            rule.destination?.displayName ?? "Trash"
        ].joined(separator: "|")
    }
}
